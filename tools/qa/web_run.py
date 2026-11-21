"""Off-screen (headless Chromium) driver for a local web export. Nothing may leave the
machine: every request to a host other than 127.0.0.1/localhost is aborted at the
browser and recorded. The run exits 3 if any such request was attempted (use
--expect-blocked to invert that when proving a release build still calls its API).

usage: python -I tools/qa/web_run.py OUTDIR steps.json [WxH] [--expect-blocked]
env:   CC_URL (page to open, must be local), CC_BOOT (seconds to wait after load)
steps: ["click",x,y] ["key","Enter"] ["hold","ArrowDown",ms] ["wait",s] ["shot",name]
       ["burst",name,count,interval_ms] ["eval","js"]
"""
import json
import os
import sys
import time
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright

LOCAL = {"127.0.0.1", "localhost", "::1"}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    expect_blocked = "--expect-blocked" in sys.argv
    out, steps = args[0], json.load(open(args[1]))
    w, h = (int(v) for v in (args[2] if len(args) > 2 else "1280x720").split("x"))
    url = os.environ.get("CC_URL", "")
    if urlparse(url).hostname not in LOCAL:
        raise SystemExit("CC_URL must be a local page (127.0.0.1/localhost): %r" % url)
    boot = float(os.environ.get("CC_BOOT", "14"))
    blocked = []
    t0 = time.time()

    def log(s):
        print("[%7.2fs] %s" % (time.time() - t0, s), flush=True)

    def guard(route):
        host = urlparse(route.request.url).hostname or ""
        if host in LOCAL or route.request.url.startswith(("data:", "blob:")):
            route.continue_()
        else:
            blocked.append((route.request.method, route.request.url))
            route.abort()

    with sync_playwright() as p:
        b = p.chromium.launch(headless=True, args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        ctx = b.new_context(viewport={"width": w, "height": h})
        ctx.route("**/*", guard)
        pg = ctx.new_page()
        pg.on("console", lambda m: log("console: " + m.text[:160]) if ("error" in m.text.lower() or "warn" in m.text.lower()) else None)
        pg.goto(url, wait_until="load", timeout=90000)
        time.sleep(boot)
        for st in steps:
            op = st[0]
            if op == "click":
                pg.mouse.click(st[1], st[2])
            elif op == "key":
                pg.keyboard.press(st[1])
            elif op == "hold":
                pg.keyboard.down(st[1])
                time.sleep(st[2] / 1000)
                pg.keyboard.up(st[1])
            elif op == "wait":
                time.sleep(st[1])
            elif op == "eval":
                log("eval: " + str(pg.evaluate(st[1])))
            elif op == "shot":
                pg.screenshot(path="%s/%s.png" % (out, st[1]))
            elif op == "burst":
                for i in range(st[2]):
                    pg.screenshot(path="%s/%s_%02d.png" % (out, st[1], i))
                    time.sleep(st[3] / 1000)
            log(" ".join(str(x) for x in st))
        b.close()
    hosts = sorted({urlparse(u).hostname for _, u in blocked})
    print("NETWORK blocked=%d hosts=%s" % (len(blocked), hosts))
    for m, u in blocked[:10]:
        print("NETWORK blocked %s %s" % (m, u))
    if expect_blocked:
        sys.exit(0 if blocked else 3)
    sys.exit(3 if blocked else 0)


if __name__ == "__main__":
    main()
