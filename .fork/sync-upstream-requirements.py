#!/usr/bin/env python3
from __future__ import annotations

import pathlib


BEGIN_MARKER = "  # BEGIN upstream-managed core dependencies"
END_MARKER = "  # END upstream-managed core dependencies"


def render_block(items: list[str]) -> str:
    rendered = [BEGIN_MARKER]
    rendered.extend(f'  "{item}",' for item in items)
    rendered.append(END_MARKER)
    return "\n".join(rendered)


def replace_block(text: str, begin_marker: str, end_marker: str, replacement: str) -> str:
    start = text.index(begin_marker)
    end = text.index(end_marker, start) + len(end_marker)
    return text[:start] + replacement + text[end:]


def main() -> int:
    repo_dir = pathlib.Path(__file__).resolve().parents[1]
    requirements_path = repo_dir / "requirements.txt"
    pyproject_path = repo_dir / "pyproject.toml"

    requirements = []
    for raw_line in requirements_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        requirements.append(line)

    updated = replace_block(
        pyproject_path.read_text(encoding="utf-8"),
        BEGIN_MARKER,
        END_MARKER,
        render_block(requirements),
    )
    pyproject_path.write_text(updated, encoding="utf-8")

    print(f"Synchronized {len(requirements)} upstream requirements into pyproject.toml.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
