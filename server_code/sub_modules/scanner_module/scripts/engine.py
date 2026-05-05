import os

ENGINE_ENABLED = os.getenv("ENGINE_ENABLED", "1").strip() != "0"

_backend = None
_load_error: str | None = None

if ENGINE_ENABLED:
    try:
        import vx_engine as _backend
        _backend._load()
    except Exception as _e:
        _load_error = str(_e)
        _backend = None


def is_available() -> bool:
    return ENGINE_ENABLED and _backend is not None


def load_error() -> str | None:
    return _load_error


def scan(apk_path: str) -> dict | None:
    if not is_available():
        return None
    return _backend.scan(apk_path)