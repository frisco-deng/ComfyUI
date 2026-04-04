#!/usr/bin/env python3
from __future__ import annotations

import sys


def main() -> int:
    try:
        import cv2
    except Exception as exc:
        print(f"Failed to import cv2: {type(exc).__name__}: {exc}")
        return 1

    failures: list[str] = []
    module_path = getattr(cv2, "__file__", None)
    version = getattr(cv2, "__version__", None)

    if not module_path:
        failures.append("cv2.__file__ is missing")
    if not version:
        failures.append("cv2.__version__ is missing")
    if not hasattr(cv2, "setNumThreads"):
        failures.append("cv2.setNumThreads is missing")

    if failures:
        print("OpenCV sanity check failed.")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print(f"OpenCV sanity check passed: {module_path} ({version})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
