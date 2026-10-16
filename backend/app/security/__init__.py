"""Security capability layer.

Exposes the capability protocols and the profile-based factory used to
assemble the active security implementation set.

Re-exports resolve lazily (PEP 562): importing a leaf submodule such
as :mod:`app.security.protocols` must not drag in the factory and every
service implementation behind it, because the services themselves
depend on the protocols -- an eager package import would close an
import cycle (``field_encryption_service`` -> ``protocols`` ->
``__init__`` -> ``factory`` -> ``field_encryption_service``).
"""

import importlib
from typing import Any

# Maps each re-exported name to the submodule that defines it.
_LAZY_EXPORTS = {
    "BehaviorAnalyzer": "app.security.protocols",
    "ContentModerator": "app.security.protocols",
    "EdgeBlocklist": "app.security.protocols",
    "EventQueuePublisher": "app.security.protocols",
    "FieldEncryptor": "app.security.protocols",
    "FileSanitizer": "app.security.protocols",
    "KeyProvider": "app.security.protocols",
    "RateLimiter": "app.security.protocols",
    "SecurityEventSink": "app.security.protocols",
    "UrlFetchSandbox": "app.security.protocols",
    "UrlScanner": "app.security.protocols",
    "WafRuleProvider": "app.security.protocols",
    "SecurityCapabilities": "app.security.factory",
    "build_security_capabilities": "app.security.factory",
    "get_security_capabilities": "app.security.singleton",
}

__all__ = list(_LAZY_EXPORTS)


def __getattr__(name: str) -> Any:
    """Resolve a re-exported capability name on first access."""
    module_name = _LAZY_EXPORTS.get(name)
    if module_name is None:
        raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
    return getattr(importlib.import_module(module_name), name)
