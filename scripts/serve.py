#!/usr/bin/env python3
"""Start or restart the local Jekyll server."""

import subprocess
import signal
import sys
import os

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def kill_existing():
    """Kill any running Jekyll serve processes."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "jekyll serve"],
            capture_output=True, text=True
        )
        if result.stdout.strip():
            subprocess.run(["pkill", "-f", "jekyll serve"], check=False)
            print("Stopped existing Jekyll server.")
            import time
            time.sleep(1)
    except Exception:
        pass

def main():
    kill_existing()
    print(f"Starting Jekyll server in {PROJECT_DIR}")
    print("http://127.0.0.1:4000/return-to-consciousness/")
    print("Press Ctrl+C to stop.\n")

    try:
        proc = subprocess.Popen(
            ["bundle", "exec", "jekyll", "serve"],
            cwd=PROJECT_DIR
        )
        proc.wait()
    except KeyboardInterrupt:
        proc.send_signal(signal.SIGTERM)
        proc.wait()
        print("\nServer stopped.")

if __name__ == "__main__":
    main()
