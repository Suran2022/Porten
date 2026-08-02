"""Smoke tests for basic import and app instantiation."""


def test_import_app():
    """Ensure the FastAPI app can be imported without errors."""
    from app.main import app

    assert app is not None
