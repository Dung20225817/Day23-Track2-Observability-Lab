#!/usr/bin/env python3
"""Pre-pull all Docker images so the first `make up` doesn't take 10 minutes."""

import subprocess
import sys

IMAGES = [
    "prom/prometheus:v2.55.0",
    "prom/alertmanager:v0.27.0",
    "grafana/grafana:11.3.0",
    "grafana/loki:3.3.0",
    "jaegertracing/all-in-one:1.62.0",
    "otel/opentelemetry-collector-contrib:0.114.0",
]

def pull(img):
    result = subprocess.run(
        ["docker", "pull", "--quiet", img],
        capture_output=True
    )
    if result.returncode != 0:
        print(f"  FAILED: {img} — {result.stderr.decode().strip()}")
        return False
    return True

def main():
    print(f"Pre-pulling {len(IMAGES)} images (the FastAPI app builds locally)...")
    failed = []
    for img in IMAGES:
        print(f"  pulling: {img}")
        if not pull(img):
            failed.append(img)
    if failed:
        print(f"Failed to pull: {failed}")
        return 1
    print("All images cached.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
