#!/usr/bin/env python3
"""
Merge two SearXNG settings.yml files.

Usage:
    python3 merge_settings.py <base_settings.yml> <overrides.yml> [output.yml]

The only key that actually gets merged is `server.secret_key` — everything else
in the override file is ignored; only its secret key is carried over into the base.
"""

import sys
import yaml


def load_yaml(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f) or {}


def merge(base: dict, override: dict) -> dict:
    merged = dict(base)
    override_server = override.get("server", {})

    # Only carry over secret_key from the override
    if "secret_key" in override_server:
        merged.setdefault("server", {})["secret_key"] = override_server["secret_key"]

    return merged


def main() -> None:
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print(f"Usage: {sys.argv[0]} <base.yml> <override.yml> [output.yml]")
        sys.exit(1)

    base_path = sys.argv[1]
    override_path = sys.argv[2]
    output_path = sys.argv[3] if len(sys.argv) == 4 else base_path

    base = load_yaml(base_path)
    override = load_yaml(override_path)

    merged = merge(base, override)

    with open(output_path, "w") as f:
        yaml.dump(merged, f, default_flow_style=False, sort_keys=False)

    print(f"Merged settings written to: {output_path}")


if __name__ == "__main__":
    main()
