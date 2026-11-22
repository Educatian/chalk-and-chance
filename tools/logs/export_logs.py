"""Copy the server_log archive from R2 to a folder off Cloudflare (e.g. the owner's Box).

usage: python -I tools/logs/export_logs.py TARGET_FOLDER [--d1-snapshot] [--wrangler "npx wrangler"]

- Reads the bucket name and D1 database name from cloudflare/wrangler.toml (the single place
  they are set), fetches server_log/manifest.json, then downloads every archive object that is
  not already in TARGET_FOLDER, verifies it (gunzip + sha256 + row count from the manifest) and
  only then moves it into place. Existing verified files are skipped, so it can be re-run.
- --d1-snapshot also writes a full SQL export of the live D1 database (all tables, including the
  play telemetry) to TARGET_FOLDER/d1/<db>_<UTC>.sql.
- Writes only inside TARGET_FOLDER. Needs wrangler logged in to the account.
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
import time
import tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CF = os.path.join(ROOT, "cloudflare")


def config():
    with open(os.path.join(CF, "wrangler.toml"), "rb") as f:
        cfg = tomllib.load(f)
    bucket = next(b["bucket_name"] for b in cfg.get("r2_buckets", []) if b.get("binding") == "LOG_BUCKET")
    db = next(d["database_name"] for d in cfg.get("d1_databases", []) if d.get("binding") == "DB")
    return bucket, db


def verify(path, entry):
    with open(path, "rb") as f:
        text = gzip.decompress(f.read())
    return hashlib.sha256(text).hexdigest() == entry["sha256"] and text.count(b"\n") == entry["rows"]


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("target")
    ap.add_argument("--d1-snapshot", action="store_true")
    ap.add_argument("--wrangler", default="npx wrangler")
    a = ap.parse_args(argv)
    wrangler = shlex.split(a.wrangler)
    wrangler[0] = shutil.which(wrangler[0]) or wrangler[0]   # npx -> npx.cmd on Windows
    target = os.path.abspath(a.target)
    if not os.path.isdir(target):
        raise SystemExit("target folder does not exist: %s" % target)
    bucket, db = config()
    run = lambda *cmd, **kw: subprocess.run(wrangler + list(cmd), cwd=CF, check=True, **kw)  # noqa: E731

    manifest = json.loads(run("r2", "object", "get", "%s/server_log/manifest.json" % bucket, "--remote", "--pipe",
                              capture_output=True).stdout)
    got, skipped = 0, 0
    for entry in manifest["objects"]:
        dest = os.path.join(target, *entry["key"].split("/"))
        if os.path.exists(dest) and verify(dest, entry):
            skipped += 1
            continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        tmp = dest + ".part"
        run("r2", "object", "get", "%s/%s" % (bucket, entry["key"]), "--remote", "--file", tmp)
        if not verify(tmp, entry):
            os.remove(tmp)
            raise SystemExit("verification failed: %s (nothing kept)" % entry["key"])
        os.replace(tmp, dest)
        got += 1
    with open(os.path.join(target, "server_log", "manifest.json"), "w", encoding="utf8") as f:
        json.dump(manifest, f, indent=1)
    print("server_log: %d downloaded, %d already present, cursor %s" % (got, skipped, manifest["cursor"]))

    if a.d1_snapshot:
        os.makedirs(os.path.join(target, "d1"), exist_ok=True)
        out = os.path.join(target, "d1", "%s_%s.sql" % (db, time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())))
        run("d1", "export", db, "--remote", "--output", out)
        print("d1 snapshot: %s" % out)


if __name__ == "__main__":
    main(sys.argv[1:])
