#!/usr/bin/env python3
"""Validate JSONC files that use full-line // comments.

OpenCode reads workspace/opencode.json; the .jsonc file is a reference. This
check catches syntax errors in that reference without pulling in a JSONC
dependency. Inline comments are intentionally not supported.
"""
import json
import sys


def main(paths: list[str]) -> int:
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            body = "".join(
                line for line in handle if not line.lstrip().startswith("//")
            )
        json.loads(body)
        print(f"ok: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
