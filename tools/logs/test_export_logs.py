"""Self-check for export_logs.py with a fake wrangler (no network, no account).
Run: python -I tools/logs/test_export_logs.py"""
import gzip
import hashlib
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FAKE = '''import os, shutil, sys
a = sys.argv[1:]
r2 = os.environ["FAKE_R2"]
if a[:3] == ["r2", "object", "get"]:
    src = os.path.join(r2, *a[3].split("/", 1)[1].split("/"))
    if "--pipe" in a:
        sys.stdout.buffer.write(open(src, "rb").read())
    else:
        shutil.copy(src, a[a.index("--file") + 1])
elif a[:2] == ["d1", "export"]:
    open(a[a.index("--output") + 1], "w").write("-- dump of " + a[2])
'''


def put(r2, key, data):
    p = os.path.join(r2, *key.split("/"))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "wb").write(data)


with tempfile.TemporaryDirectory() as tmp:
    r2, target = os.path.join(tmp, "r2"), os.path.join(tmp, "box")
    os.makedirs(target)
    fake = os.path.join(tmp, "fake_wrangler.py")
    open(fake, "w").write(FAKE)
    text = b'{"id":1}\n{"id":2}\n'
    key = "server_log/2027-02/1-2.ndjson.gz"
    put(r2, key, gzip.compress(text))
    put(r2, "server_log/manifest.json", json.dumps({"cursor": 2, "objects": [
        {"key": key, "rows": 2, "sha256": hashlib.sha256(text).hexdigest()}]}).encode())
    cmd = [sys.executable, "-I", os.path.join(HERE, "export_logs.py"), target, "--d1-snapshot",
           "--wrangler", "%s -I %s" % (sys.executable.replace("\\", "/"), fake.replace("\\", "/"))]
    env = {**os.environ, "FAKE_R2": r2}
    out = subprocess.run(cmd, env=env, capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    assert "1 downloaded" in out.stdout, out.stdout
    assert os.path.exists(os.path.join(target, "server_log", "2027-02", "1-2.ndjson.gz"))
    assert os.listdir(os.path.join(target, "d1"))[0].startswith("chalk_db_")
    out = subprocess.run(cmd, env=env, capture_output=True, text=True)          # re-run: nothing new
    assert "0 downloaded, 1 already present" in out.stdout, out.stdout
    put(r2, key, gzip.compress(b'{"id":1}\n'))                                   # corrupt source
    os.remove(os.path.join(target, "server_log", "2027-02", "1-2.ndjson.gz"))
    out = subprocess.run(cmd, env=env, capture_output=True, text=True)
    assert out.returncode != 0 and "verification failed" in (out.stderr + out.stdout)
    assert not os.path.exists(os.path.join(target, "server_log", "2027-02", "1-2.ndjson.gz"))
    assert not any(f.endswith(".part") for _, _, fs in os.walk(target) for f in fs)
print("export_logs self-check: ok")
