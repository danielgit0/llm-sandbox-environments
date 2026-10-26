#!/usr/bin/env python3
"""Convert ACP embedded-resource prompt blocks to text before DSH ACP."""

from __future__ import annotations

import json
import signal
import subprocess
import sys
import threading


def normalize(message: object) -> object:
    """Rewrite resource blocks in one ACP JSON-RPC message."""
    if not isinstance(message, dict) or message.get("method") != "session/prompt":
        return message

    params = message.get("params")
    if not isinstance(params, dict) or not isinstance(params.get("prompt"), list):
        return message

    changed = False
    prompt = []
    for block in params["prompt"]:
        if isinstance(block, dict) and block.get("type") == "resource":
            changed = True
            resource = block.get("resource")
            resource = resource if isinstance(resource, dict) else {}
            uri = resource.get("uri", "unknown")
            text = resource.get("text")
            if not isinstance(text, str):
                text = ""
            prompt.append(
                {
                    "type": "text",
                    "text": f"\n[embedded resource: {uri}]\n{text}\n",
                }
            )
        else:
            prompt.append(block)

    if not changed:
        return message

    new_params = dict(params)
    new_params["prompt"] = prompt
    new_message = dict(message)
    new_message["params"] = new_params
    return new_message


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: acp-normalize.py COMMAND [ARG...]", file=sys.stderr)
        return 2

    child = subprocess.Popen(
        sys.argv[1:],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )

    def stop(_signum: int, _frame: object) -> None:
        child.terminate()

    signal.signal(signal.SIGTERM, stop)

    def pump_input() -> None:
        try:
            for line in sys.stdin.buffer:
                stripped = line.strip()
                if not stripped:
                    child.stdin.write(line)
                    child.stdin.flush()
                    continue
                try:
                    message = json.loads(stripped)
                except json.JSONDecodeError:
                    child.stdin.write(line)
                    child.stdin.flush()
                    continue
                encoded = json.dumps(
                    normalize(message), separators=(",", ":"), ensure_ascii=False
                ).encode()
                child.stdin.write(encoded + b"\n")
                child.stdin.flush()
        except (BrokenPipeError, OSError):
            pass
        finally:
            try:
                child.stdin.close()
            except (BrokenPipeError, OSError):
                pass

    def pump_output() -> None:
        try:
            for line in child.stdout:
                sys.stdout.buffer.write(line)
                sys.stdout.buffer.flush()
        except (BrokenPipeError, OSError):
            pass

    input_thread = threading.Thread(target=pump_input, daemon=True)
    output_thread = threading.Thread(target=pump_output, daemon=True)
    input_thread.start()
    output_thread.start()

    returncode = child.wait()
    output_thread.join(timeout=1)
    return returncode


if __name__ == "__main__":
    sys.exit(main())
