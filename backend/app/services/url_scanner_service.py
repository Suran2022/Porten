"""Local rule-based URL reputation scanner (lite profile).

Detection layers, cheapest first:

1. Dangerous schemes (javascript/data/vbscript) are always malicious.
2. Literal IP hosts are matched against private, loopback, link-local and
   cloud metadata ranges -- these are never legitimate chat links and are
   the primary SSRF payload shape.
3. Domain blocklist and short-link domains (built-in seed list, extended
   by reputation records in standard/advanced profiles).
4. Heuristics: credential-in-authority, punycode look-alikes, non-standard
   ports, sensitive query parameters.

Anything not matched is reported safe; uncertain links are handled by the
asynchronous reputation lookup added in later profiles.
"""
import ipaddress
import re
from typing import Optional
from urllib.parse import parse_qs, unquote, urlsplit

from app.schemas.security import UrlVerdict, UrlVerdictLevel

_DANGEROUS_SCHEMES = {"javascript", "data", "vbscript", "file"}

# Short-link and known abuse-heavy domains (seed list; versioned rules
# replace this in later profiles).
_BLOCKED_DOMAINS = {
    "bit.ly",
    "tinyurl.com",
    "t.cn",
    "dwz.cn",
    "suo.im",
    "url.cn",
}

_SUSPICIOUS_TLDS = {".zip", ".mov", ".xyz"}

_SENSITIVE_QUERY_KEYS = {"password", "passwd", "token", "secret", "key", "session"}

_PRIVATE_NETWORKS = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("0.0.0.0/8"),
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("fe80::/10"),
]

_IPV4_RE = re.compile(r"^\d{1,3}(?:\.\d{1,3}){3}$")


class LocalRuleUrlScanner:
    """URL scanner backed by local rules only (lite profile)."""

    def scan(self, url: str) -> UrlVerdict:
        """Return the reputation verdict for a single URL."""
        verdict = self._scan(url)
        if verdict is not None:
            return verdict
        return UrlVerdict(url=url, level=UrlVerdictLevel.SAFE)

    def _scan(self, url: str) -> Optional[UrlVerdict]:
        try:
            # Unquote once so percent-encoded schemes/hosts are still caught.
            decoded = unquote(url).strip()
            parts = urlsplit(decoded)
        except ValueError:
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason="malformed url",
            )

        scheme = (parts.scheme or "").lower()
        host = (parts.hostname or "").lower()

        if scheme in _DANGEROUS_SCHEMES:
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.MALICIOUS,
                reason=f"dangerous scheme: {scheme}",
            )

        if not host:
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason="missing host",
            )

        # Literal IP hosts: private/metadata ranges are SSRF payloads,
        # public IPs are rare in chat but still worth flagging as suspicious.
        if _IPV4_RE.match(host) or ":" in host:
            ip_verdict = self._check_ip_literal(host)
            if ip_verdict is not None:
                return ip_verdict

        if host in _BLOCKED_DOMAINS or any(
            host.endswith(f".{domain}") for domain in _BLOCKED_DOMAINS
        ):
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.MALICIOUS,
                reason="blocked domain",
            )

        # Credential-in-authority: http://trusted.com@evil.com/ tricks users
        # into trusting the visible domain while the real host is evil.com.
        authority = decoded.split("//", 1)[-1].split("/", 1)[0]
        if "@" in authority:
                return UrlVerdict(
                    url=url,
                    level=UrlVerdictLevel.MALICIOUS,
                    reason="credentials in authority",
                )

        if host.startswith("xn--"):
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason="punycode look-alike domain",
            )

        if any(host.endswith(tld) for tld in _SUSPICIOUS_TLDS):
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason="abuse-prone tld",
            )

        try:
            port = parts.port
        except ValueError:
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason="invalid port",
            )
        if port is not None and port not in (80, 443):
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason=f"non-standard port: {port}",
            )

        query_keys = {k.lower() for k in parse_qs(parts.query).keys()}
        if query_keys & _SENSITIVE_QUERY_KEYS:
            return UrlVerdict(
                url=url,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason="sensitive query parameters",
            )

        return None

    @staticmethod
    def _check_ip_literal(host: str) -> Optional[UrlVerdict]:
        """Flag IP literals, escalating private/metadata ranges to malicious."""
        host_clean = host.strip("[]")
        try:
            ip = ipaddress.ip_address(host_clean)
        except ValueError:
            return UrlVerdict(
                url=host,
                level=UrlVerdictLevel.SUSPICIOUS,
                reason="unparseable ip literal",
            )

        for network in _PRIVATE_NETWORKS:
            if ip in network:
                return UrlVerdict(
                    url=host,
                    level=UrlVerdictLevel.MALICIOUS,
                    reason=f"private/metadata address: {host_clean}",
                )
        return UrlVerdict(
            url=host,
            level=UrlVerdictLevel.SUSPICIOUS,
            reason="bare ip host",
        )


class CachedUrlScanner:
    """Local rules first, then reputation lookup (standard profile).

    A malicious local verdict (dangerous scheme, private address) is
    final and never overridden by reputation. For everything else a
    known reputation verdict wins, which lets manual review correct
    heuristic false positives (safe) or escalate hosts the local rules
    do not cover (suspicious/malicious).
    """

    def __init__(self, local_scanner: LocalRuleUrlScanner, intel_service) -> None:
        self._local = local_scanner
        self._intel = intel_service

    def scan(self, url: str) -> UrlVerdict:
        """Return the reputation verdict for a single URL."""
        verdict = self._local.scan(url)
        if verdict.level == UrlVerdictLevel.MALICIOUS:
            return verdict

        host = self._host_of(url)
        if not host:
            return verdict

        reputation = self._intel.get_reputation(host)
        if reputation is not None:
            return reputation
        return verdict

    @staticmethod
    def _host_of(url: str) -> str:
        """Best-effort host extraction; empty when not determinable."""
        try:
            parts = urlsplit(unquote(url).strip())
        except ValueError:
            return ""
        return (parts.hostname or "").lower()
