"""Take screenshots of all observability dashboards for submission."""
from __future__ import annotations

import asyncio
import time
from pathlib import Path

from playwright.async_api import async_playwright

OUT = Path(__file__).parent.parent / "submission" / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)

BASE = "http://localhost"

DASHBOARDS = [
    # (url, filename, wait_seconds)
    (f"{BASE}:3000/d/day23-ai-overview",          "dashboard-overview.png",       8),
    (f"{BASE}:3000/d/day23-slo",                  "slo-burn-rate.png",            8),
    (f"{BASE}:3000/d/day23-cost-tokens",           "cost-and-tokens.png",          5),
    (f"{BASE}:3000/d/day23-cross-day",            "cross-day-dashboard.png",       5),
    (f"{BASE}:16686/trace/",                       "jaeger-trace.png",             8),
]


async def screenshot(url: str, filename: str, wait: int) -> None:
    path = OUT / filename
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={"width": 1920, "height": 1080})
        await page.goto(url, wait_until="networkidle", timeout=30000)
        await asyncio.sleep(wait)  # let panels render
        await page.screenshot(path=path, full_page=False)
        print(f"  saved: {path}")
        await browser.close()


async def main() -> None:
    print(f"Screenshots will be saved to: {OUT}")
    for url, filename, wait in DASHBOARDS:
        print(f"Capturing: {filename}")
        try:
            await screenshot(url, filename, wait)
        except Exception as exc:
            print(f"  ERROR: {exc}")


if __name__ == "__main__":
    asyncio.run(main())
