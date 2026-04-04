#!/usr/bin/env python3
from __future__ import annotations

import importlib
import pathlib
import re
import tomllib


IMPORT_NAME_OVERRIDES = {
    "color-matcher": "color_matcher",
    "gitpython": "git",
    "huggingface-hub": "huggingface_hub",
    "imageio-ffmpeg": "imageio_ffmpeg",
    "matrix-nio": "nio",
    "pygithub": "github",
    "scikit-image": "skimage",
    "segment-anything": "segment_anything",
    "typing-extensions": "typing_extensions",
}


def canonicalize(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def extract_name(spec: str) -> str:
    cleaned = spec.split(";", 1)[0].strip()
    match = re.match(r"([A-Za-z0-9_.-]+)", cleaned)
    if not match:
        raise ValueError(f"Unable to parse dependency name from: {spec!r}")
    return canonicalize(match.group(1))


def import_name_for(package_name: str) -> str:
    if package_name in IMPORT_NAME_OVERRIDES:
        return IMPORT_NAME_OVERRIDES[package_name]
    return package_name.replace("-", "_")


def main() -> int:
    repo_dir = pathlib.Path(__file__).resolve().parents[1]
    pyproject = tomllib.loads((repo_dir / "pyproject.toml").read_text(encoding="utf-8"))
    custom_node_specs = pyproject.get("dependency-groups", {}).get("custom_nodes", [])

    failures: list[tuple[str, str, Exception]] = []
    successes: list[tuple[str, str]] = []
    for spec in custom_node_specs:
        package_name = extract_name(spec)
        module_name = import_name_for(package_name)
        try:
            module = importlib.import_module(module_name)
        except Exception as exc:
            failures.append((package_name, module_name, exc))
            continue

        module_path = getattr(module, "__file__", None)
        successes.append((module_name, str(module_path)))

    for module_name, module_path in successes:
        print(f"OK {module_name} {module_path}")

    if failures:
        print("Missing custom-node imports:")
        for package_name, module_name, exc in failures:
            print(f" - {package_name} -> {module_name}: {type(exc).__name__}: {exc}")
        return 1

    print("Custom-node import health looks good.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
