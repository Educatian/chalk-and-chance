"""Read-only check of the server_log archive in R2 against D1. Prints PASS or FAIL per check.

usage: python -I tools/logs/verify_archive.py [--wrangler "npx wrangler"]

For every object in server_log/manifest.json (bucket name from cloudflare/wrangler.toml):
  - it downloads and gunzips the object; the sha256 and row count match the manifest;
  - the ids are strictly increasing and match the manifest's first_id / last_id;
  - the chunks follow each other (no overlap) and the manifest cursor is the last chunk's last id;
  - against D1 (SELECT only): every archived row still in D1 is identical, column for column;
    every D1 row in the object's id range is in the object (nothing skipped); rows no longer
    in D1 are counted as pruned (expected 0 while all rows are younger than LOG_KEEP_MONTHS).
It writes nothing anywhere: only `wrangler r2 object get --pipe` and `wrangler d1 execute` SELECTs.
Exit code 0 = all checks pass.
"""
import argparse
import gzip
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_logs import CF, config  # noqa: E402  (same folder; -I does not add it)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--wrangler", default="npx wrangler")
    a = ap.parse_args(argv)
    wrangler = shlex.split(a.wrangler)
    wrangler[0] = shutil.which(wrangler[0]) or wrangler[0]
    bucket, db = config()

    def run(*cmd):
        return subprocess.run(wrangler + list(cmd), cwd=CF, check=True, capture_output=True).stdout

    def r2(key):
        return run("r2", "object", "get", "%s/%s" % (bucket, key), "--remote", "--pipe")

    def d1(sql):
        return json.loads(run("d1", "execute", db, "--remote", "--json", "--command", sql))[0]["results"]

    results = []

    def check(name, ok, detail=""):
        results.append(ok)
        print("%s  %s%s" % ("PASS" if ok else "FAIL", name, ("  (" + detail + ")") if detail else ""))

    manifest = json.loads(r2("server_log/manifest.json"))
    objs = manifest.get("objects", [])
    print("bucket %s, %d objects, cursor %s" % (bucket, len(objs), manifest.get("cursor")))
    check("manifest has objects", len(objs) > 0)
    check("cursor = last object's last_id", bool(objs) and manifest["cursor"] == objs[-1]["last_id"])
    check("chunks do not overlap", all(objs[i]["first_id"] > objs[i - 1]["last_id"] for i in range(1, len(objs))))
    pruned_total = 0
    for o in objs:
        text = gzip.decompress(r2(o["key"]))
        rows = [json.loads(line) for line in text.decode("utf8").splitlines() if line]
        ids = [r["id"] for r in rows]
        check("%s sha256" % o["key"], hashlib.sha256(text).hexdigest() == o["sha256"])
        check("%s rows = %d" % (o["key"], o["rows"]), len(rows) == o["rows"], "found %d" % len(rows))
        check("%s ids %s..%s" % (o["key"], o["first_id"], o["last_id"]),
              ids == sorted(set(ids)) and ids[:1] == [o["first_id"]] and ids[-1:] == [o["last_id"]])
        live = {r["id"]: r for r in d1("SELECT * FROM server_log WHERE id BETWEEN %d AND %d ORDER BY id"
                                       % (int(o["first_id"]), int(o["last_id"])))}
        archived = {r["id"]: r for r in rows}
        diff = [i for i in ids if i in live and live[i] != archived[i]]
        check("%s rows identical to D1" % o["key"], not diff, "differ: %s" % diff[:5] if diff else "")
        skipped = sorted(set(live) - set(archived))
        check("%s no D1 row skipped" % o["key"], not skipped, "missing: %s" % skipped[:5] if skipped else "")
        pruned_total += sum(1 for i in ids if i not in live)
    check("nothing pruned from D1", pruned_total == 0, "%d archived rows no longer in D1" % pruned_total)
    print("RESULT: %s (%d/%d checks)" % ("PASS" if all(results) else "FAIL", sum(results), len(results)))
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
