#!/usr/bin/env python3
"""Established-session liveness watch for IDR-P5 and IDR-P7.

Neither property is satisfied by a new connection being refused. Both turn on when
the session that was ALREADY carrying traffic stops carrying it. That is a different
instant from the policy record updating, and on a live transfer it is the one that
bounds exposure.

This holds one established connection open, writes a small payload on a fixed
interval, and records the timestamp of the last byte that actually made it. When the
path closes it reports the last-success instant so it can be differenced against the
moment the condition became observable.

Usage: session_watch.py <host> <port> [--interval 0.2] [--max 300] [--out DIR]
Exit 0 = session ended (expected for P5/P7). Exit 2 = never established.
"""
import argparse, json, socket, sys, time
from datetime import datetime, timezone

def iso(t): return datetime.fromtimestamp(t, timezone.utc).isoformat().replace("+00:00", "Z")

ap = argparse.ArgumentParser()
ap.add_argument("host"); ap.add_argument("port", type=int)
ap.add_argument("--interval", type=float, default=0.2)
ap.add_argument("--max", type=float, default=300.0)
ap.add_argument("--out", default=".")
a = ap.parse_args()

rec = {"target": f"{a.host}:{a.port}", "interval_seconds": a.interval,
       "probe": "periodic write on one established TCP session"}

try:
    s = socket.create_connection((a.host, a.port), timeout=5)
    s.settimeout(5)
except OSError as e:
    rec.update(established=False, error=str(e))
    print(json.dumps(rec, indent=2)); sys.exit(2)

t0 = time.time()
rec["established_at"] = iso(t0)
last_ok = t0
n = 0
reason = "max duration reached"
while time.time() - t0 < a.max:
    try:
        s.sendall(b"GET / HTTP/1.0\r\nHost: idr\r\n\r\n" if n == 0 else b"\x00")
        last_ok = time.time(); n += 1
    except OSError as e:
        reason = f"write failed: {e}"; break
    time.sleep(a.interval)
try: s.close()
except OSError: pass

rec.update(last_byte_at=iso(last_ok), writes_succeeded=n,
           session_seconds=round(last_ok - t0, 3), ended_because=reason)
out = f"{a.out}/session_watch.json"
with open(out, "w") as f: json.dump(rec, f, indent=2)
print(json.dumps(rec, indent=2))
print(f"\nlast_byte_at is the instant to difference against the condition timestamp.\nwritten: {out}", file=sys.stderr)
