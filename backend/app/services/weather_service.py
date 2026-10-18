"""Weather capability service with a pluggable provider architecture.

The trip reminder text embeds origin/destination weather, whose data
source is a third-party API (key provided later). To keep the business
code free of vendor specifics:

* :class:`WeatherProvider` is the capability protocol consumed by
  :mod:`app.services.trip_service`;
* :class:`HttpWeatherProvider` is a configuration-driven generic REST
  client (URL template + dotted response paths), so switching vendors
  only requires configuration changes, not code changes;
* :class:`NullWeatherProvider` is the no-source fallback: reminders then
  only contain the departure countdown.

Configuration lives in ``Settings`` (``weather_*`` keys); an unset URL
template selects the null provider.
"""

import logging
from dataclasses import dataclass
from typing import Any, Optional, Protocol, runtime_checkable

from app.config import get_settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class WeatherInfo:
    """Current weather for a single city."""

    city: str
    text: str
    temperature: Optional[float] = None


@runtime_checkable
class WeatherProvider(Protocol):
    """Current-weather lookup capability for a city name."""

    def current(self, city: str) -> Optional[WeatherInfo]:
        """Return the current weather, or None when unavailable."""
        ...


class NullWeatherProvider:
    """Fallback provider used when no weather API is configured."""

    def current(self, city: str) -> Optional[WeatherInfo]:
        return None


def _pluck(payload: Any, path: str) -> Any:
    """Read a dotted path (e.g. ``now.temp``) out of nested dicts."""
    node = payload
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    return node


class HttpWeatherProvider:
    """Configuration-driven REST weather client.

    The request URL is built from ``weather_url_template`` with
    ``{city}`` / ``{key}`` placeholders; the response is parsed with the
    dotted paths ``weather_text_path`` / ``weather_temp_path``. No vendor
    specifics are hard-coded, so a different provider only needs new
    configuration values.
    """

    def __init__(
        self,
        url_template: str,
        api_key: str,
        text_path: str,
        temp_path: str,
        timeout_seconds: float,
    ) -> None:
        self._url_template = url_template
        self._api_key = api_key
        self._text_path = text_path
        self._temp_path = temp_path
        self._timeout_seconds = timeout_seconds

    def current(self, city: str) -> Optional[WeatherInfo]:
        if not city:
            return None
        url = self._url_template.format(city=city, key=self._api_key)
        try:
            import httpx

            response = httpx.get(url, timeout=self._timeout_seconds)
            response.raise_for_status()
            payload = response.json()
        except Exception:
            # Fail-open: a weather outage never breaks the reminder.
            logger.warning("weather lookup failed for %s", city, exc_info=True)
            return None

        text = _pluck(payload, self._text_path)
        if text is None:
            return None
        temperature = _pluck(payload, self._temp_path)
        try:
            temperature = float(temperature) if temperature is not None else None
        except (TypeError, ValueError):
            temperature = None
        return WeatherInfo(city=city, text=str(text), temperature=temperature)


_provider: Optional[WeatherProvider] = None


def get_weather_provider() -> WeatherProvider:
    """Return the process-wide weather provider singleton.

    Built once on first use; an unset base URL yields the null provider.
    """
    global _provider
    if _provider is None:
        settings = get_settings()
        if settings.weather_url_template and settings.weather_api_key:
            _provider = HttpWeatherProvider(
                url_template=settings.weather_url_template,
                api_key=settings.weather_api_key,
                text_path=settings.weather_text_path,
                temp_path=settings.weather_temp_path,
                timeout_seconds=weather_timeout(),
            )
        else:
            _provider = NullWeatherProvider()
    return _provider


def weather_timeout() -> float:
    """Return the configured weather request timeout in seconds."""
    return get_settings().weather_timeout_seconds
