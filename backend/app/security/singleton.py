"""Security capability singleton accessor."""

from typing import Optional

from app.security.factory import SecurityCapabilities, build_security_capabilities

_capabilities: Optional[SecurityCapabilities] = None


def get_security_capabilities() -> SecurityCapabilities:
    """Return the process-wide security capabilities singleton.

    Built once on first use so in-memory state (rate-limit windows,
    blocklists) is shared across requests and across the middleware and
    router layers.
    """
    global _capabilities
    if _capabilities is None:
        _capabilities = build_security_capabilities()
    return _capabilities
