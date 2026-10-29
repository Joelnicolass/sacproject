"""SAMP (one sound of sounds.wad / sfx_english.wad) and the PCM16 WAV the tools write from it.

Layout (measured on an install): a 32-byte header (payload size u32 at 12, bits u16 at 16, sample rate u32 at 20),
then either raw PCM16 mono or a RIFF/WAVE file holding IMA ADPCM mono. The IMA ADPCM decoder follows the public IMA/DVI
specification (step and index tables, 4-byte block header: predictor i16, step index u8, reserved u8; low nibble first).
"""

import struct

HEADER_SIZE = 32

# IMA ADPCM tables (public specification).
INDEX_TABLE = (-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8)
STEP_TABLE = (
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060,
    1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
    7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
)


class Sound:
    """Decoded mono PCM16: `pcm` little-endian bytes, `rate` Hz, `codec` "pcm" or "ima_adpcm" (what the SAMP held)."""

    def __init__(self, pcm: bytes, rate: int, codec: str):
        self.pcm = pcm
        self.rate = rate
        self.codec = codec

    @property
    def frames(self) -> int:
        return len(self.pcm) // 2


def _riff_chunks(data: bytes) -> dict:
    """{chunk id: payload} of a RIFF/WAVE file (first of each id)."""
    chunks = {}
    offset = 12
    while offset + 8 <= len(data):
        cid = data[offset:offset + 4]
        size = struct.unpack_from("<I", data, offset + 4)[0]
        body = data[offset + 8: offset + 8 + size]
        chunks.setdefault(cid, body)
        offset += 8 + size + (size & 1)
    return chunks


def decode_ima_block(block: bytes) -> list:
    """The samples of one mono IMA ADPCM block: the header sample, then two per byte (low nibble first)."""
    if len(block) < 4:
        return []
    predictor = struct.unpack_from("<h", block, 0)[0]
    index = min(max(block[2], 0), 88)
    out = [predictor]
    for byte in block[4:]:
        for nibble in (byte & 0x0F, byte >> 4):
            step = STEP_TABLE[index]
            diff = step >> 3
            if nibble & 4:
                diff += step
            if nibble & 2:
                diff += step >> 1
            if nibble & 1:
                diff += step >> 2
            predictor = predictor - diff if nibble & 8 else predictor + diff
            predictor = min(max(predictor, -32768), 32767)
            index = min(max(index + INDEX_TABLE[nibble], 0), 88)
            out.append(predictor)
    return out


def decode_wav(data: bytes) -> Sound:
    chunks = _riff_chunks(data)
    fmt = chunks.get(b"fmt ")
    body = chunks.get(b"data", b"")
    if fmt is None or len(fmt) < 16:
        raise ValueError("RIFF without fmt")
    tag, channels, rate, _byte_rate, block_align, bits = struct.unpack_from("<HHIIHH", fmt, 0)
    if channels != 1:
        raise ValueError("RIFF with %d channels" % channels)
    if tag == 1 and bits == 16:
        return Sound(bytes(body[: len(body) // 2 * 2]), rate, "pcm")
    if tag != 0x11:
        raise ValueError("RIFF format tag %#x" % tag)
    samples = []
    for start in range(0, len(body), block_align):
        samples.extend(decode_ima_block(body[start: start + block_align]))
    # The fact chunk (when present) gives the real length; the last block may be padded.
    fact = chunks.get(b"fact")
    if fact and len(fact) >= 4:
        total = struct.unpack_from("<I", fact, 0)[0]
        if 0 < total <= len(samples):
            samples = samples[:total]
    return Sound(struct.pack("<%dh" % len(samples), *samples), rate, "ima_adpcm")


def decode_samp(raw: bytes) -> Sound:
    if len(raw) < HEADER_SIZE:
        raise ValueError("SAMP shorter than its header")
    size = struct.unpack_from("<I", raw, 12)[0]
    rate = struct.unpack_from("<I", raw, 20)[0] or 22050
    payload = raw[HEADER_SIZE:]
    if payload[:4] in (b"RIFF", b"WAVE"):
        return decode_wav(payload)
    pcm = payload[:size] if size <= len(payload) else payload
    return Sound(bytes(pcm[: len(pcm) // 2 * 2]), rate, "pcm")


def wav_bytes(sound: Sound) -> bytes:
    """A canonical 44-byte-header PCM16 mono WAV (deterministic: same sound, same bytes)."""
    data = sound.pcm
    header = b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE"
    header += b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, sound.rate, sound.rate * 2, 2, 16)
    header += b"data" + struct.pack("<I", len(data))
    return header + data
