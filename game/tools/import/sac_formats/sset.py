"""SSET (a sound set of sounds.wad): which SAMPs answer each sound type of an emitter.

Layout: a 4-character name, u32 entry count, then per entry a 4-character type, u32 n and n SAMP names
(the variants). Like every 4-character tag of the WADs the characters are stored reversed; they are returned as people
read them (the WAD file names): type "Xdie", sample "zdi1".
"""

import struct


def _tag(raw: bytes, offset: int) -> str:
    return raw[offset: offset + 4][::-1].decode("latin1").rstrip("\x00")


def decode_sset(raw: bytes) -> list:
    """[(type, [sample names])] in file order. A type may repeat; callers merge."""
    if len(raw) < 8:
        raise ValueError("SSET shorter than its header")
    count = struct.unpack_from("<I", raw, 4)[0]
    offset = 8
    entries = []
    for _ in range(count):
        if offset + 8 > len(raw):
            raise ValueError("SSET truncated")
        kind = _tag(raw, offset)
        n = struct.unpack_from("<I", raw, offset + 4)[0]
        offset += 8
        if offset + 4 * n > len(raw):
            raise ValueError("SSET truncated")
        entries.append((kind, [_tag(raw, offset + 4 * i) for i in range(n)]))
        offset += 4 * n
    return entries
