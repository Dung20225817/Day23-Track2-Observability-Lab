#!/usr/bin/env python3
"""Trigger an alert by killing the app, wait for it to fire, then restore."""

import subprocess
import time
import sys

def run(cmd, check=False):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"ERROR: {' '.join(cmd)!r} failed: {result.stderr.strip()}")
        sys.exit(1)
    return result.stdout.strip()

def count_active_alerts():
    result = subprocess.run(
        "curl -fsS http://localhost:9093/api/v2/alerts",
        shell=True, capture_output=True, text=True
    )
    if result.returncode != 0:
        return 0
    return result.stdout.count('"state":"active"')

print("Step 1: kill app container")
run("docker stop day23-app")

print("Step 2: wait 90s for ServiceDown alert to fire")
for i in range(1, 19):
    time.sleep(5)
    alerts = count_active_alerts()
    if alerts > 0:
        print(f"  alert fired (after {i*5}s)")
        break
    print(f"  no alert yet ({i*5}s)")

print("Step 3: restart app")
run("docker start day23-app")

print("Step 4: wait 90s for alert to resolve")
for i in range(1, 19):
    time.sleep(5)
    alerts = count_active_alerts()
    if alerts == 0:
        print("  alert resolved")
        print("Done.")
        sys.exit(0)

print("alert did not resolve within 90s")
sys.exit(1)
