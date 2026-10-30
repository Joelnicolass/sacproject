#!/usr/bin/env python3
"""Rewrite ext_resource paths inside a binary Godot .res (format 4/5), fixing the lengths and the internal-resource offsets.
Usage: patch_res.py FILE OLD NEW [OLD NEW ...]   (binary resources keep script paths that move_map.py cannot rewrite)."""
import struct, sys


def patch(path, pairs):
    d = bytearray(open(path, 'rb').read())
    p = 4
    def u32(): 
        nonlocal p; v = struct.unpack_from('<I', d, p)[0]; p += 4; return v
    def u64():
        nonlocal p; v = struct.unpack_from('<Q', d, p)[0]; p += 8; return v
    def s():
        nonlocal p; n = u32(); v = bytes(d[p:p + n - 1]); p += n; return v
    assert d[:4] == b'RSRC'
    u32(); u32(); u32(); u32(); fmt = u32()
    s()
    meta_pos = p; meta = u64()
    flags = u32(); u64()
    if flags & 8: s()
    for _ in range(11): u32()
    for _ in range(u32()): s()
    ext = []
    for _ in range(u32()):
        t = s(); ps = p; pv = s(); pe = p; u64(); ext.append((ps, pe, pv))
    int_count_pos = p; n_int = u32()
    int_offsets = []
    for _ in range(n_int):
        s(); int_offsets.append(p); u64()
    delta_total = 0
    # patch from the last occurrence to the first so earlier positions stay valid
    edits = []
    for ps, pe, pv in ext:
        for old, new in pairs:
            if pv.decode() == old:
                edits.append((ps, pe, new))
    for ps, pe, new in sorted(edits, reverse=True):
        nb = new.encode()
        d[ps:pe] = struct.pack('<I', len(nb) + 1) + nb + b'\0'
        delta = len(nb) - (pe - ps - 5)
        delta_total += delta
        # every offset stored after this point shifts
        for q in int_offsets:
            if q > ps:
                pass
    # offsets: recompute positions after edits is complex; apply the total delta to every internal offset and metadata
    # (all ext entries precede the internal table, which precedes the data, so every offset moves by delta_total)
    q = 0
    p2 = 0
    # re-walk to locate the offsets in the patched file
    p = 4
    u32(); u32(); u32(); u32(); u32(); s()
    meta_pos = p; meta = u64()
    if meta:
        struct.pack_into('<Q', d, meta_pos, meta + delta_total)
    flags = u32(); u64()
    if flags & 8: s()
    for _ in range(11): u32()
    for _ in range(u32()): s()
    for _ in range(u32()):
        s(); s(); u64()
    for _ in range(u32()):
        s(); v = struct.unpack_from('<Q', d, p)[0]; struct.pack_into('<Q', d, p, v + delta_total); p += 8
    open(path, 'wb').write(d)
    print(path, 'patched, delta', delta_total)


if __name__ == '__main__':
    a = sys.argv[1:]
    patch(a[0], list(zip(a[1::2], a[2::2])))
