"""Off-screen (headless Chromium) driver for a local web export. Nothing may leave the
machine: every request to a host other than 127.0.0.1/localhost is aborted at the
browser and recorded. The run exits 3 if any such request was attempted (use
--expect-blocked to invert that when proving a release build still calls its API).

usage: python -I tools/qa/web_run.py OUTDIR steps.json [WxH] [--expect-blocked]
env:   CC_URL (page to open, must be local), CC_BOOT (seconds to wait after load)
       CC_ALLOW + CC_ALLOW_MAX: one exact URL that may be POSTed to, at most N times (bounded
       hosted check; calls recorded to OUTDIR/hosted_calls.json); all else non-local aborted
steps: ["click",x,y] ["key","Enter"] ["hold","ArrowDown",ms] ["wait",s] ["shot",name]
       ["burst",name,count,interval_ms] ["eval","js"]
       ["press","Button text"]   press a visible button (debug web builds; English or shown text)
       ["expect","marker",s]     wait up to s (default 12) until the current scene path or a
                                 visible text contains marker; otherwise exit 4 and save
                                 nothing more, so a wrong screen never becomes a "shot"
       ["key_until","o","marker",n] press the key until the marker shows (a toast may have toggled it)
       ["expect_not","marker"]   exit 4 if marker is visible now ("a|b" = either marker)
"""
import json
import os
import sys
import time
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright

LOCAL = {"127.0.0.1", "localhost", "::1"}


def main():
    sys.stdout.reconfigure(encoding="utf8", errors="replace")   # Korean markers in the log
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    expect_blocked = "--expect-blocked" in sys.argv
    out, steps = args[0], json.load(open(args[1], encoding="utf8"))
    w, h = (int(v) for v in (args[2] if len(args) > 2 else "1280x720").split("x"))
    url = os.environ.get("CC_URL", "")
    if urlparse(url).hostname not in LOCAL:
        raise SystemExit("CC_URL must be a local page (127.0.0.1/localhost): %r" % url)
    boot = float(os.environ.get("CC_BOOT", "14"))
    blocked = []
    t0 = time.time()

    def log(s):
        print("[%7.2fs] %s" % (time.time() - t0, s), flush=True)

    # Bounded hosted check (opt-in): CC_ALLOW names ONE exact URL (e.g. the Worker's /turn)
    # that may be called, at most CC_ALLOW_MAX POSTs; each call is fetched here, timed and
    # recorded to OUTDIR/hosted_calls.json. Everything else non-local is still aborted.
    allow = os.environ.get("CC_ALLOW", "")
    allow_max = int(os.environ.get("CC_ALLOW_MAX", "0"))
    calls = []

    def guard(route):
        req = route.request
        host = urlparse(req.url).hostname or ""
        if host in LOCAL or req.url.startswith(("data:", "blob:")):
            route.continue_()
            return
        if allow and req.url.split("?")[0] == allow and req.method == "OPTIONS":
            route.continue_()          # CORS preflight only, no model call
            return
        if allow and req.url.split("?")[0] == allow and req.method == "POST" and len(calls) < allow_max:
            rec = {"utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "request": json.loads(req.post_data or "{}")}
            t1 = time.time()
            try:
                resp = route.fetch(timeout=60000)
                rec["latency_ms"] = int((time.time() - t1) * 1000)
                rec["status"] = resp.status
                body = resp.text()
                try:
                    rec["response"] = json.loads(body)
                except ValueError:
                    rec["response_text"] = body[:2000]
                route.fulfill(response=resp)
            except Exception as e:      # noqa: BLE001 - recorded, never retried
                rec["latency_ms"] = int((time.time() - t1) * 1000)
                rec["error"] = str(e)[:300]
                route.abort()
            calls.append(rec)
            log("HOSTED call %d/%d %s %dms" % (len(calls), allow_max, req.url, rec["latency_ms"]))
            json.dump(calls, open("%s/hosted_calls.json" % out, "w", encoding="utf8"), ensure_ascii=False, indent=1)
            return
        blocked.append((req.method, req.url))
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
                time.sleep(0.5)   # the probe republishes every 0.4 s: an expect must not read pre-key state
            elif op == "key_until":   # ["key_until","o","marker",tries]: toggle until the marker shows
                for _ in range(st[3] if len(st) > 3 else 3):
                    s = json.loads(pg.evaluate("JSON.stringify(window.__cc_state || {})"))
                    if any(m in s.get("text", "") for m in st[2].split("|")):
                        break
                    pg.keyboard.press(st[1])
                    time.sleep(0.9)
            elif op == "hold":
                pg.keyboard.down(st[1])
                time.sleep(st[2] / 1000)
                pg.keyboard.up(st[1])
            elif op == "wait":
                pg.wait_for_timeout(st[1] * 1000)   # keeps Playwright pumping events (routes are handled on time)
            elif op == "press":
                pg.evaluate("t => window.cc_press && window.cc_press(t)", st[1])
                time.sleep(0.6)
                if not pg.evaluate("window.__cc_pressed === true"):
                    log("PRESS FAIL %r: no visible button with that text" % st[1])
                    b.close()
                    print("NETWORK blocked=%d hosts=%s" % (len(blocked), sorted({urlparse(u).hostname for _, u in blocked})))
                    sys.exit(3 if blocked else 4)
            elif op in ("expect", "expect_not"):
                state = lambda: pg.evaluate("JSON.stringify(window.__cc_state || {})")
                # "a|b" passes on either marker
                has = lambda: (lambda s: any(m in s.get("scene", "") or m in s.get("text", "")
                                             for m in st[1].split("|")))(json.loads(state()))
                if op == "expect":
                    end = time.time() + (st[2] if len(st) > 2 else 12)
                    while not has() and time.time() < end:
                        time.sleep(0.4)
                ok = has() if op == "expect" else not has()
                if not ok:
                    log("EXPECT FAIL %s %r" % (op, st[1]))
                    open("%s/expect_fail.txt" % out, "w", encoding="utf8").write(state())
                    b.close()
                    print("NETWORK blocked=%d hosts=%s" % (len(blocked), sorted({urlparse(u).hostname for _, u in blocked})))
                    sys.exit(3 if blocked else 4)
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
