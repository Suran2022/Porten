"""SSRF-hardened URL fetch sandbox (design doc §5.5).

The sandbox fetches untrusted chat links (link previews, asynchronous
content analysis) without letting them reach internal services. Three
implementations behind one protocol:

* ``LocalIsolationSandbox`` -- in-process fetcher with an injected
  ``SsrfPolicy``: scheme allowlist, full DNS-result validation, IP
  pinning (anti DNS-rebinding), per-hop redirect re-validation, and
  size/timeout/redirect caps. No external dependencies.
* ``RemoteSandboxClient`` -- delegates fetching to a cluster-side
  sandbox (advanced profile). Unreachable or erroring sandboxes report
  ``sandbox_unavailable`` instead of raising, so callers fail open.
* ``DisabledSandbox`` -- no-op stub for profiles without the capability.

Every implementation returns a ``FetchResult`` and never raises for
network-level failures, so a sandbox outage can never block business
traffic.
"""

import ipaddress
import logging
import socket
import ssl
import time
from dataclasses import dataclass, field
from http.client import HTTPConnection
from typing import Optional, Tuple
from urllib.parse import urljoin, urlsplit

import httpx

from app.config import get_settings
from app.schemas.security import FetchResult

logger = logging.getLogger(__name__)

# Networks a sandboxed fetch must never reach: RFC1918 private space,
# loopback, link-local (incl. the 169.254.169.254 cloud metadata
# endpoint), CGNAT, benchmarking/reserved/documentation ranges and the
# IPv6 equivalents, plus transition mechanisms that can embed a private
# IPv4 address (IPv4-mapped, NAT64, 6to4, Teredo).
_DEFAULT_BLOCKED_NETWORKS: Tuple = (
    ipaddress.ip_network("0.0.0.0/8"),          # "this" network
    ipaddress.ip_network("10.0.0.0/8"),         # private
    ipaddress.ip_network("100.64.0.0/10"),      # CGNAT
    ipaddress.ip_network("127.0.0.0/8"),        # loopback
    ipaddress.ip_network("169.254.0.0/16"),     # link-local + metadata
    ipaddress.ip_network("172.16.0.0/12"),      # private
    ipaddress.ip_network("192.0.0.0/24"),       # IETF protocol assignments
    ipaddress.ip_network("192.0.2.0/24"),       # documentation
    ipaddress.ip_network("192.168.0.0/16"),     # private
    ipaddress.ip_network("198.18.0.0/15"),      # benchmarking
    ipaddress.ip_network("198.51.100.0/24"),    # documentation
    ipaddress.ip_network("203.0.113.0/24"),     # documentation
    ipaddress.ip_network("224.0.0.0/4"),        # multicast
    ipaddress.ip_network("240.0.0.0/4"),        # reserved
    ipaddress.ip_network("::/128"),             # unspecified
    ipaddress.ip_network("::1/128"),            # loopback
    ipaddress.ip_network("::ffff:0:0/96"),      # IPv4-mapped
    ipaddress.ip_network("64:ff9b::/96"),       # NAT64
    ipaddress.ip_network("2002::/16"),          # 6to4
    ipaddress.ip_network("2001::/32"),          # Teredo
    ipaddress.ip_network("fc00::/7"),           # unique local
    ipaddress.ip_network("fe80::/10"),          # link-local
    ipaddress.ip_network("ff00::/8"),           # multicast
)

_DEFAULT_ALLOWED_SCHEMES = frozenset({"http", "https"})

_CHUNK_SIZE = 65536


class SsrfError(Exception):
    """Raised internally when a fetch is refused by the SSRF policy."""


@dataclass(frozen=True)
class SsrfPolicy:
    """Injection point for the sandbox fetch policy.

    Defaults are deny-by-default for anything non-public. Pass
    ``blocked_networks=()`` (and a custom scheme set) only in tests
    that exercise the fetch mechanics against a local server.
    """

    allowed_schemes: frozenset = field(default=_DEFAULT_ALLOWED_SCHEMES)
    blocked_networks: Optional[Tuple] = None
    allow_redirects: bool = True
    max_redirects: int = 3
    max_bytes: int = 524288
    timeout_seconds: float = 5.0

    def __post_init__(self) -> None:
        if self.blocked_networks is None:
            object.__setattr__(
                self, "blocked_networks", _DEFAULT_BLOCKED_NETWORKS
            )

    def is_blocked_ip(self, ip: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
        """Return True when the address must not be reached."""
        candidates = [ip]
        # Transition formats can embed a private IPv4 address inside an
        # otherwise public IPv6 one; validate the embedded address too.
        if isinstance(ip, ipaddress.IPv6Address):
            for attr in ("ipv4_mapped", "sixtofour", "teredo"):
                embedded = getattr(ip, attr, None)
                if embedded is not None:
                    candidates.append(embedded)
        for candidate in candidates:
            for network in self.blocked_networks:
                if candidate.version == network.version and candidate in network:
                    return True
        return False


class LocalIsolationSandbox:
    """In-process fetcher enforcing an :class:`SsrfPolicy`.

    Hardening measures, in order:

    1. Scheme allowlist (http/https) -- blocks file:, data:, gopher: etc.
    2. Full getaddrinfo result validation -- a single private answer
       refuses the fetch, defeating DNS answers that mix public and
       private records.
    3. IP pinning -- the connection is opened against the validated
       address and the original hostname travels in the Host header,
       so a re-resolved (rebound) address is never contacted.
    4. Per-hop redirect re-validation -- every Location target passes
       the full policy again, capped at ``max_redirects``.
    5. Response size cap (``max_bytes``) with a truncation flag, plus
       connect/read timeouts and an overall deadline.
    """

    def __init__(self, policy: Optional[SsrfPolicy] = None) -> None:
        settings = get_settings()
        self._policy = policy or SsrfPolicy(
            max_redirects=settings.security_url_fetch_max_redirects,
            max_bytes=settings.security_url_fetch_max_bytes,
            timeout_seconds=settings.security_url_fetch_timeout_seconds,
        )

    def fetch(self, url: str) -> FetchResult:
        """Fetch a URL under the policy. Never raises."""
        try:
            return self._fetch(url)
        except SsrfError as exc:
            return FetchResult(ok=False, error=str(exc), final_url=url)
        except Exception:
            logger.warning("sandbox fetch failed for %s", url, exc_info=True)
            return FetchResult(ok=False, error="fetch_failed", final_url=url)

    def _fetch(self, url: str) -> FetchResult:
        current_url = url
        deadline = time.monotonic() + self._policy.timeout_seconds
        for hop in range(self._policy.max_redirects + 1):
            scheme, hostname, port, path = self._parse(current_url)
            pinned_ip = self._resolve_and_validate(hostname, port)
            response, connection = self._request(
                scheme, hostname, port, path, pinned_ip, deadline
            )
            try:
                location = response.getheader("Location")
                if response.status in (301, 302, 303, 307, 308) and location:
                    response.read()
                    if not self._policy.allow_redirects:
                        return FetchResult(
                            ok=False,
                            error="redirect_not_allowed",
                            final_url=current_url,
                            status_code=response.status,
                        )
                    if hop == self._policy.max_redirects:
                        return FetchResult(
                            ok=False,
                            error="too_many_redirects",
                            final_url=current_url,
                            status_code=response.status,
                        )
                    current_url = urljoin(current_url, location)
                    continue
                return self._read_response(response, current_url)
            finally:
                connection.close()
        return FetchResult(ok=False, error="too_many_redirects", final_url=url)

    def _parse(self, url: str) -> Tuple[str, str, int, str]:
        """Validate the scheme and split the URL into fetch parts."""
        try:
            parts = urlsplit(url)
        except ValueError as exc:
            raise SsrfError(f"malformed_url: {exc}") from exc
        scheme = (parts.scheme or "").lower()
        if scheme not in self._policy.allowed_schemes:
            raise SsrfError(f"blocked_scheme: {scheme or 'missing'}")
        hostname = (parts.hostname or "").lower()
        if not hostname:
            raise SsrfError("missing_host")
        try:
            port = parts.port
        except ValueError as exc:
            raise SsrfError(f"invalid_port: {exc}") from exc
        if port is None:
            port = 443 if scheme == "https" else 80
        path = parts.path or "/"
        if parts.query:
            path = f"{path}?{parts.query}"
        return scheme, hostname, port, path

    def _resolve_and_validate(self, hostname: str, port: int) -> str:
        """Resolve the host and return a validated address to pin.

        Every answer must be public; one private answer refuses the
        whole fetch (no "first public wins" bypass).
        """
        try:
            answers = socket.getaddrinfo(
                hostname, port, socket.AF_UNSPEC, socket.SOCK_STREAM
            )
        except socket.gaierror as exc:
            raise SsrfError(f"dns_failed: {exc}") from exc
        if not answers:
            raise SsrfError("dns_empty")

        for answer in answers:
            raw_ip = answer[4][0]
            try:
                ip = ipaddress.ip_address(raw_ip)
            except ValueError as exc:
                raise SsrfError(f"unparseable_address: {raw_ip}") from exc
            if self._policy.is_blocked_ip(ip):
                raise SsrfError(f"ssrf_blocked: {raw_ip}")
        return answers[0][4][0]

    def _request(
        self,
        scheme: str,
        hostname: str,
        port: int,
        path: str,
        pinned_ip: str,
        deadline: float,
    ) -> Tuple:
        """Open a connection pinned to the validated address."""
        remaining = max(deadline - time.monotonic(), 0.1)
        sock = socket.create_connection((pinned_ip, port), timeout=remaining)
        if scheme == "https":
            context = ssl.create_default_context()
            # server_hostname keeps certificate validation bound to the
            # original hostname while the TCP connection stays pinned.
            sock = context.wrap_socket(sock, server_hostname=hostname)
        connection = HTTPConnection(
            host=hostname, port=port, timeout=self._policy.timeout_seconds
        )
        connection.sock = sock
        try:
            connection.request(
                "GET",
                path,
                headers={
                    "Accept": "*/*",
                    "Connection": "close",
                    "User-Agent": "PortenSecuritySandbox/1",
                },
            )
            response = connection.getresponse()
        except Exception:
            connection.close()
            raise
        return response, connection

    def _read_response(self, response, final_url: str) -> FetchResult:
        """Read the body under the size cap, flagging truncation."""
        body = bytearray()
        truncated = False
        limit = self._policy.max_bytes
        while True:
            chunk = response.read(min(_CHUNK_SIZE, limit - len(body) + 1))
            if not chunk:
                break
            body.extend(chunk)
            if len(body) > limit:
                truncated = True
                break
        return FetchResult(
            ok=True,
            final_url=final_url,
            status_code=response.status,
            content_type=response.getheader("Content-Type"),
            body=bytes(body[:limit]),
            truncated=truncated,
        )


class RemoteSandboxClient:
    """Client for a cluster-side fetch sandbox (advanced profile).

    Any unreachable sandbox, non-200 answer or malformed payload is
    reported as ``sandbox_unavailable``; the caller (typically the URL
    scanner) treats that as "no dynamic conclusion" and fails open.
    """

    def __init__(
        self,
        client: Optional[httpx.Client] = None,
        timeout_seconds: Optional[float] = None,
    ) -> None:
        settings = get_settings()
        self._base_url = settings.security_sandbox_url.rstrip("/")
        self._timeout = (
            timeout_seconds
            if timeout_seconds is not None
            else settings.security_url_fetch_timeout_seconds
        )
        self._client = client or httpx.Client(timeout=self._timeout)

    def fetch(self, url: str) -> FetchResult:
        """Delegate the fetch to the remote sandbox. Never raises."""
        try:
            response = self._client.post(
                f"{self._base_url}/fetch", json={"url": url}
            )
            if response.status_code != 200:
                return FetchResult(ok=False, error="sandbox_unavailable")
            payload = response.json()
            return FetchResult(
                ok=bool(payload.get("ok")),
                final_url=str(payload.get("final_url", "")),
                status_code=payload.get("status_code"),
                content_type=payload.get("content_type"),
                body=_decode_body(payload.get("body", "")),
                truncated=bool(payload.get("truncated", False)),
                error=payload.get("error"),
            )
        except Exception:
            logger.warning("remote sandbox fetch failed for %s", url, exc_info=True)
            return FetchResult(ok=False, error="sandbox_unavailable")


class DisabledSandbox:
    """Stub sandbox for profiles without fetch capability (lite/standard)."""

    def fetch(self, url: str) -> FetchResult:
        """Report the capability as unavailable; callers fail open."""
        return FetchResult(ok=False, error="sandbox_disabled", final_url=url)


def _decode_body(value) -> bytes:
    """Decode a remote sandbox body (base64 string or raw string)."""
    if isinstance(value, bytes):
        return value
    if not isinstance(value, str):
        return b""
    import base64
    import binascii

    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError):
        return value.encode("utf-8")


def build_url_fetch_sandbox(profile: Optional[str] = None):
    """Assemble the URL fetch sandbox for the given profile.

    advanced: remote sandbox when ``security_sandbox_url`` is set, else
    the local isolation sandbox when explicitly enabled, else disabled.
    lite/standard: disabled (capability reserved for advanced).
    """
    profile = profile or get_settings().security_profile
    if profile != "advanced":
        return DisabledSandbox()

    settings = get_settings()
    if settings.security_sandbox_url:
        return RemoteSandboxClient()
    if settings.security_url_fetch_enabled:
        return LocalIsolationSandbox()
    return DisabledSandbox()
