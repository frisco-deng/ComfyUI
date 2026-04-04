#!/usr/bin/env python3
from __future__ import annotations

import os
import pathlib
import re
import tomllib


BEGIN_MARKER = "    # BEGIN custom-nodes-managed dependency group"
END_MARKER = "    # END custom-nodes-managed dependency group"

MANDATORY_SPECS = [
    "GitPython",
    "PyGithub",
    "matrix-nio",
    "huggingface-hub",
    "typer",
    "rich",
    "typing-extensions",
    "toml",
    "chardet<6",
    "black",
    "ultralytics>=8.3.162",
    "imageio-ffmpeg",
    "gguf>=0.13.0",
    "segment-anything",
    "scikit-image",
    "piexif",
    "dill",
    "matplotlib",
    "mss",
    "color-matcher",
]

NAME_OVERRIDES = {
    "color_matcher": "color-matcher",
    "huggingface_hub": "huggingface-hub",
    "imageio_ffmpeg": "imageio-ffmpeg",
    "opencv-contrib-python-headless": "opencv-contrib-python",
    "opencv-python": "opencv-contrib-python",
    "opencv-python-headless": "opencv-contrib-python",
    "pygithub": "PyGithub",
    "pyopengl": "PyOpenGL",
    "typing_extensions": "typing-extensions",
    "cupy-wheel": "cupy-cuda13x",
}

SKIP_PACKAGES = {
    "protobuf",
}

VCS_PREFIXES = ("git+", "hg+", "svn+", "bzr+")


def canonicalize(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def parse_name_and_rest(spec: str) -> tuple[str, str]:
    cleaned = spec.split(";", 1)[0].strip()
    match = re.match(r"([A-Za-z0-9_.-]+)(.*)", cleaned)
    if not match:
        raise ValueError(f"Unable to parse dependency name from: {spec!r}")
    return match.group(1), match.group(2).strip()


def normalize_spec(spec: str) -> tuple[str, str]:
    name, rest = parse_name_and_rest(spec)
    override_name = NAME_OVERRIDES.get(canonicalize(name), name)
    canonical_name = canonicalize(override_name)
    normalized = override_name if not rest else f"{override_name}{rest}"
    return canonical_name, normalized


def spec_priority(spec: str) -> tuple[int, int, int]:
    _, rest = parse_name_and_rest(spec)
    has_constraint = int(any(op in rest for op in ("<", ">", "=", "~", "@")))
    direct_ref = int("@" in rest or "://" in rest)
    return direct_ref, has_constraint, len(spec)


def render_block(items: list[str]) -> str:
    rendered = [BEGIN_MARKER]
    rendered.extend(f'    "{item}",' for item in items)
    rendered.append(END_MARKER)
    return "\n".join(rendered)


def replace_block(text: str, begin_marker: str, end_marker: str, replacement: str) -> str:
    start = text.index(begin_marker)
    end = text.index(end_marker, start) + len(end_marker)
    return text[:start] + replacement + text[end:]


def main() -> int:
    repo_dir = pathlib.Path(__file__).resolve().parents[1]
    runtime_dir = pathlib.Path(os.environ.get("COMFYUI_RUNTIME_DIR", repo_dir.parent / "ComfyUI-runtime")).resolve()
    custom_nodes_dir = runtime_dir / "custom_nodes"
    pyproject_path = repo_dir / "pyproject.toml"

    if not custom_nodes_dir.is_dir():
        raise SystemExit(f"Custom nodes directory does not exist: {custom_nodes_dir}")

    pyproject = tomllib.loads(pyproject_path.read_text(encoding="utf-8"))
    core_dependencies = pyproject.get("project", {}).get("dependencies", [])
    core_names = {
        normalize_spec(spec)[0]
        for spec in core_dependencies
    }

    chosen_specs: dict[str, str] = {}
    skipped_sources: list[str] = []

    for requirements_path in sorted(custom_nodes_dir.glob("*/requirements*.txt")):
        for raw_line in requirements_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            lowered = line.lower()
            if lowered.startswith(VCS_PREFIXES) or "://" in lowered:
                skipped_sources.append(f"{requirements_path.relative_to(runtime_dir)} -> {line}")
                continue

            canonical_name, normalized_spec = normalize_spec(line)
            if canonical_name in SKIP_PACKAGES or canonical_name in core_names:
                continue

            current = chosen_specs.get(canonical_name)
            if current is None or spec_priority(normalized_spec) > spec_priority(current):
                chosen_specs[canonical_name] = normalized_spec

    for spec in MANDATORY_SPECS:
        canonical_name, normalized_spec = normalize_spec(spec)
        if canonical_name not in SKIP_PACKAGES and canonical_name not in core_names:
            chosen_specs[canonical_name] = normalized_spec

    rendered_specs = [chosen_specs[name] for name in sorted(chosen_specs)]
    updated = replace_block(
        pyproject_path.read_text(encoding="utf-8"),
        BEGIN_MARKER,
        END_MARKER,
        render_block(rendered_specs),
    )
    pyproject_path.write_text(updated, encoding="utf-8")

    print(f"Synchronized {len(rendered_specs)} custom-node dependencies into pyproject.toml.")
    if skipped_sources:
        print("Skipped VCS/direct-url custom-node requirements:")
        for item in skipped_sources:
            print(f" - {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
