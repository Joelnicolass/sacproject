#!/usr/bin/env python3
"""Compares two dumps of debug/map/ground_dump.gd bit by bit (heights as raw 64-bit floats, is_on_ground as bytes).

Usage: python3 debug/map/ground_dump_compare.py <before.json> <after.json>
Exit code 0 when every map is identical, 1 otherwise. Prints one line per map and the first differing points.
"""
import base64
import json
import struct
import sys


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    before, after = load(sys.argv[1]), load(sys.argv[2])
    ok = True
    if before.get("points") != after.get("points") or before.get("seed") != after.get("seed"):
        print("FAIL: the dumps were taken with different points or seed")
        return 1
    if set(before["maps"]) != set(after["maps"]):
        print("FAIL: different maps: %s vs %s" % (sorted(before["maps"]), sorted(after["maps"])))
        return 1
    total = 0
    for tag in sorted(before["maps"]):
        a, b = before["maps"][tag], after["maps"][tag]
        if not a.get("ok") or not b.get("ok"):
            print("FAIL %-16s a map did not load (before ok=%s, after ok=%s)" % (tag, a.get("ok"), b.get("ok")))
            ok = False
            continue
        ha, hb = base64.b64decode(a["heights"]), base64.b64decode(b["heights"])
        ga, gb = base64.b64decode(a["on_ground"]), base64.b64decode(b["on_ground"])
        bad = [i for i in range(len(ga)) if ha[i * 8:i * 8 + 8] != hb[i * 8:i * 8 + 8] or ga[i] != gb[i]]
        lowest = struct.pack("<d", float(a["lowest"])) == struct.pack("<d", float(b["lowest"]))
        total += len(ga)
        line = "%-4s %-16s %d points, land %d/%d, %d different%s" % (
            "OK" if not bad and lowest else "FAIL", tag, len(ga), a["land_points"], b["land_points"], len(bad), "" if lowest else ", lowest differs")
        print(line)
        for i in bad[:5]:
            print("     point %d: before %s on=%d, after %s on=%d" % (
                i, struct.unpack("<d", ha[i * 8:i * 8 + 8])[0], ga[i], struct.unpack("<d", hb[i * 8:i * 8 + 8])[0], gb[i]))
        ok = ok and not bad and lowest
    print("GROUND SURFACE %s (%d points)" % ("PASS" if ok else "FAIL", total))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
