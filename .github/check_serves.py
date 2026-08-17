"""Start the board, confirm it answers, stop it. Used by CI on both platforms.

A board that imports cleanly can still fail to serve, and the PowerShell version
of this check only ran on Windows. Written in Python so one file covers both
runners rather than two that drift apart.
"""

from __future__ import annotations

import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

PORT = 5099
ROOT = Path(__file__).resolve().parent.parent
DEADLINE = 40


def get(path: str) -> str:
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}{path}", timeout=3) as response:
        if response.status != 200:
            raise RuntimeError(f"{path} answered {response.status}")
        return response.read().decode("utf-8", "replace")


def main() -> int:
    env = dict(os.environ)
    # Somewhere writable that is not the checkout, so this also exercises the
    # override a container relies on.
    env["WIZZO_STATE_DIR"] = str(ROOT / ".ci-state")
    # No games on a runner. Saying so explicitly means the check tests the empty
    # state rather than whatever the runner image happens to contain.
    env.update({"BMS_PATH": "off", "DCS_PATH": "off", "IL2_PATH": "off"})

    proc = subprocess.Popen(
        [sys.executable, "wizzo.py", "--host", "127.0.0.1", "--port", str(PORT), "--no-update"],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        for _ in range(DEADLINE):
            if proc.poll() is not None:
                print("the board exited before it served:")
                print(proc.stdout.read() if proc.stdout else "(no output)")
                return 1
            try:
                get("/api/paths")
            except (urllib.error.URLError, OSError, RuntimeError):
                time.sleep(1)
                continue
            print("served /api/paths")
            page = get("/")
            if "Wizzo" not in page:
                print("the page rendered without its own name in it")
                return 1
            print("served the page")
            return 0

        print(f"the board never answered on port {PORT} within {DEADLINE}s")
        return 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())
