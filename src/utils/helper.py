from pathlib import Path

import yaml

_DEFAULT_CONFIG = Path(__file__).resolve().parent.parent / "config.yml"


def load_config(path: str | Path | None = None) -> dict:
    config_path = Path(path) if path is not None else _DEFAULT_CONFIG
    with open(config_path, "r") as f:
        return yaml.safe_load(f)
