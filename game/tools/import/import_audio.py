#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Import the original's audio to assets/original/audio/ (RFC-052 052b, F361):
  sfx/<folder>/<file>.wav            every SAMP of data/sounds.wad (combat, spells, ambience, menu); always PCM16 WAV
  voice/<folder>/<file>.<codec>      the SAMPs of data/local/sfx_english.wad that a skirmish SSET names (creatures, wizards,
                                     advisor); the rest (campaign lines) is skipped. English only.
  music/<slug>.mp3                   every data/music/*.mp3, a byte copy
  index.json                         SSET name -> type -> [file], creature/wizard tag -> SSETs, SAMP name -> file

  python3 tools/import/import_audio.py                  # write (voices as Ogg Vorbis through ffmpeg)
  python3 tools/import/import_audio.py --codec=wav      # voices as PCM16 WAV (no ffmpeg); --codec=mp3 as MP3 mono 56 kbps
  python3 tools/import/import_audio.py --check          # report what would change, write nothing
  python3 tools/import/import_audio.py --out=DIR        # write under DIR/audio instead of assets/original/audio

Deterministic and idempotent: a second run with the same codec writes nothing. index.json records the source hash of each
file, so a compressed file is not re-encoded when its source did not change. Files of an earlier run that this run no longer
produces (another codec) are removed with their .import; no other .import is ever touched (Godot writes them).
--codec=ogg|mp3 needs ffmpeg in PATH (only for whoever imports: the files are versioned). Without it, voices fall back to WAV.

File names: SAMP names that differ only in case live in the same folder (TRA1 / tra1), and macOS and Windows see them as one
file. Every capital letter is written as `_` + lower case (`TRA1` -> `_t_r_a1`), the rule of OriginalAssets.icon_file.

Formats: tools/import/sac_formats/samp.py (SAMP, IMA ADPCM) and sset.py (SSET). The sets each creature and wizard uses are
read from spells.wad: CRE8 meleeSSET (offset 160) and creatureSSET (164), swapped when creatureSSET is the generic melee
set "fist" (peasants); WIZD wizardSSET (160), meleeSSET1 (164), meleeSSET2 (168). "cre8" means none. Tags as
export_stats.py: a creature is its WAD name reversed, a wizard its WAD name.
"""

import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats import samp, sset  # noqa: E402
from sac_formats.install import INSTALL  # noqa: E402
from sac_formats.wad import walk  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original")) / "audio"
SFX_WAD = "sounds.wad"
VOICE_WAD = "local/sfx_english.wad"
MUSIC_DIR = "music"
CODECS = ("wav", "ogg", "mp3")
# Voices (168 MB as WAV) default to Ogg Vorbis: ~42 MB, gapless. MP3 adds ~50 ms of encoder delay at the start.
DEFAULT_CODEC = "ogg"
# ffmpeg arguments per voice codec (mono 22050 Hz in, as the SAMPs). bitexact: no encoder version in the file.
ENCODE = {
    # ffmpeg's native Vorbis encoder only takes 2 channels: the mono voice is written to both (libvorbis is not assumed).
    "ogg": ["-c:a", "vorbis", "-strict", "-2", "-q:a", "4", "-ac", "2"],
    "mp3": ["-c:a", "libmp3lame", "-b:a", "56k", "-ac", "1"],
}
NO_SET = ("", "cre8")
GENERIC_MELEE = "fist"
# Two folders hold flp1..flp5 (comn and pyro); sacengine binds flp5 to comn. A name in several folders prefers this one.
PREFERRED_FOLDER = "comn"
INDEX_VERSION = 1


def file_stem(name: str) -> str:
    """Case-safe file name of a SAMP or folder name (OriginalAssets.icon_file without the extension)."""
    return "".join("_" + c.lower() if c != c.lower() else c for c in name).replace("/", "_")


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def tag_at(raw: bytes, offset: int) -> str:
    return raw[offset: offset + 4][::-1].decode("latin1").rstrip("\x00")


def read_samples(wad_path: Path) -> dict:
    """{SAMP name: [(folder, raw)]}; folder is the last WAD folder without .FLDR."""
    out = {}
    for odir, name, ext, raw in walk(wad_path.read_bytes()):
        if ext == "SAMP":
            folder = odir.split("/")[-1].removesuffix(".FLDR")
            out.setdefault(name, []).append((folder, raw))
    return out


def read_sets(wad_path: Path) -> dict:
    """{SSET name: {type: [SAMP names]}} (a repeated type appends its variants)."""
    out = {}
    for _odir, name, ext, raw in walk(wad_path.read_bytes()):
        if ext == "SSET":
            types = out.setdefault(name, {})
            for kind, names in sset.decode_sset(raw):
                types.setdefault(kind, []).extend(n for n in names if n not in types.get(kind, []))
    return out


def read_users(spells_wad: Path) -> tuple:
    """({creature tag: [SSET names]}, {wizard tag: [SSET names]}), first the voice set, then the melee ones."""
    creatures, wizards = {}, {}
    for _odir, name, ext, raw in walk(spells_wad.read_bytes()):
        if ext == "CRE8":
            melee, own = tag_at(raw, 160), tag_at(raw, 164)
            if own == GENERIC_MELEE:
                own, melee = melee, own
            sets = [s for s in (own, melee) if s not in NO_SET]
            creatures[name[::-1]] = sets
        elif ext == "WIZD":
            sets = [s for s in (tag_at(raw, 160), tag_at(raw, 164), tag_at(raw, 168)) if s not in NO_SET]
            wizards[name] = list(dict.fromkeys(sets))
    return creatures, wizards


def pick(entries: list) -> tuple:
    """The (folder, raw) of a name found in several folders: PREFERRED_FOLDER, else the first by folder name."""
    for entry in entries:
        if entry[0] == PREFERRED_FOLDER:
            return entry
    return sorted(entries, key=lambda e: e[0])[0]


def encode(wav: bytes, codec: str) -> bytes:
    if codec == "wav":
        return wav
    cmd = ["ffmpeg", "-v", "error", "-f", "wav", "-i", "pipe:0", "-map_metadata", "-1", "-fflags", "+bitexact",
           "-flags:a", "+bitexact"] + ENCODE[codec] + ["-f", "ogg" if codec == "ogg" else "mp3", "pipe:1"]
    done = subprocess.run(cmd, input=wav, capture_output=True, check=False)
    if done.returncode != 0 or not done.stdout:
        raise RuntimeError("ffmpeg (%s): %s" % (codec, done.stderr.decode(errors="replace").strip()[:300]))
    return done.stdout


class Writer:
    def __init__(self, check: bool, manifest: dict):
        self.check = check
        self.old = manifest
        self.manifest = {}
        self.written = 0
        self.kept = 0
        self.bytes = {}

    def put(self, rel: str, source: bytes, make, family: str) -> None:
        """Writes OUT/rel from `make()` unless the file exists and was made from the same source."""
        digest = hashlib.sha1(source).hexdigest()[:16]
        self.manifest[rel] = digest
        path = OUT / rel
        if path.exists() and self.old.get(rel) == digest:
            self.kept += 1
        else:
            data = make()
            if path.exists() and path.read_bytes() == data:
                self.kept += 1
            else:
                self.written += 1
                if not self.check:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(data)
        self.bytes[family] = self.bytes.get(family, 0) + (path.stat().st_size if path.exists() else 0)

    def put_text(self, rel: str, text: str) -> None:
        path = OUT / rel
        data = text.encode("utf-8")
        if path.exists() and path.read_bytes() == data:
            self.kept += 1
            return
        self.written += 1
        if not self.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)


def prune(produced: set, check: bool) -> int:
    """Removes media files under OUT this run did not produce (an earlier codec), and their .import."""
    removed = 0
    for family in ("sfx", "voice", "music"):
        for path in sorted((OUT / family).rglob("*")) if (OUT / family).is_dir() else []:
            if path.suffix not in (".wav", ".ogg", ".mp3") or path.relative_to(OUT).as_posix() in produced:
                continue
            removed += 1
            if not check:
                path.unlink()
                sidecar = path.with_name(path.name + ".import")
                if sidecar.exists():
                    sidecar.unlink()
    return removed


def main() -> None:
    codec = str(ARGS.get("--codec", DEFAULT_CODEC))
    if codec not in CODECS:
        sys.stderr.write("ERROR: --codec debe ser wav, ogg o mp3 (recibí %s).\n" % codec)
        sys.exit(1)
    if codec != "wav" and shutil.which("ffmpeg") is None:
        print("AVISO: no encuentro ffmpeg en el PATH; las voces se escriben en WAV (sin comprimir). Instalá ffmpeg y volvé "
              "a correr con --codec=%s para comprimirlas." % codec)
        codec = "wav"
    check = "--check" in ARGS
    for rel in (SFX_WAD, VOICE_WAD):
        if not (INSTALL / rel).is_file():
            sys.stderr.write("ERROR: falta %s en %s (el audio del original; solo se usa el inglés).\n" % (rel, INSTALL))
            sys.exit(2)
    old_index = {}
    if (OUT / "index.json").is_file():
        try:
            old_index = json.loads((OUT / "index.json").read_text(encoding="utf-8"))
        except ValueError:
            old_index = {}
    writer = Writer(check, old_index.get("files", {}) if old_index.get("voice_codec") == codec else
                    {k: v for k, v in old_index.get("files", {}).items() if not k.startswith("voice/")})

    sfx = read_samples(INSTALL / SFX_WAD)
    voice = read_samples(INSTALL / VOICE_WAD)
    sets = read_sets(INSTALL / SFX_WAD)
    creatures, wizards = read_users(INSTALL / "spells.wad")

    # Voices: only the SAMPs a skirmish set names (creature, wizard and advisor sets, plus the world and UI sets).
    skirmish_sets = {s for group in (creatures, wizards) for names in group.values() for s in names}
    skirmish_sets |= {"spel", "advi", "ifac"} & set(sets)
    wanted_voices = {n for s in skirmish_sets for names in sets[s].values() for n in names if n in voice}

    files = {}   # SAMP name -> rel path
    produced = set()
    voice_codecs = {"pcm": 0, "ima_adpcm": 0}
    # Every copy is written (flp1..5 live in comn and pyro); a set's name resolves to pick()'s copy.
    for name in sorted(sfx):
        for folder, raw in sfx[name]:
            rel = "sfx/%s/%s.wav" % (file_stem(folder), file_stem(name))
            writer.put(rel, raw, lambda raw=raw: samp.wav_bytes(samp.decode_samp(raw)), "sfx")
            produced.add(rel)
        files[name] = "sfx/%s/%s.wav" % (file_stem(pick(sfx[name])[0]), file_stem(name))
    skipped_voices = 0
    skipped_bytes = 0
    shadowed = []
    for name in sorted(voice):
        if name not in wanted_voices:
            skipped_voices += len(voice[name])
            skipped_bytes += sum(len(r) for _f, r in voice[name])
            continue
        for folder, raw in voice[name]:
            voice_codecs[samp.decode_samp(raw).codec] += 1
            rel = "voice/%s/%s.%s" % (file_stem(folder), file_stem(name), codec)
            writer.put(rel, raw + codec.encode(), lambda raw=raw: encode(samp.wav_bytes(samp.decode_samp(raw)), codec),
                       "voice")
            produced.add(rel)
        if name in files:
            shadowed.append(name)   # the SFX copy wins, as the original's single name index would pick one
            continue
        files[name] = "voice/%s/%s.%s" % (file_stem(pick(voice[name])[0]), file_stem(name), codec)
    music = {}
    music_dir = INSTALL / MUSIC_DIR
    for path in sorted(music_dir.glob("*.mp3")) if music_dir.is_dir() else []:
        rel = "music/%s.mp3" % slug(path.stem)
        raw = path.read_bytes()
        writer.put(rel, raw, lambda raw=raw: raw, "music")
        music[slug(path.stem)] = rel
        produced.add(rel)

    missing = set()
    index_sets = {}
    for set_name in sorted(sets):
        types = {}
        for kind in sorted(sets[set_name]):
            resolved = [files[n] for n in sets[set_name][kind] if n in files]
            missing |= {n for n in sets[set_name][kind] if n not in files and n not in voice}
            if resolved:
                types[kind] = resolved
        index_sets[set_name] = types
    index = {
        "version": INDEX_VERSION,
        "voice_codec": codec,
        "sets": index_sets,
        "creatures": {t: creatures[t] for t in sorted(creatures)},
        "wizards": {t: wizards[t] for t in sorted(wizards)},
        "samples": {n: files[n] for n in sorted(files)},
        "music": {k: music[k] for k in sorted(music)},
        "files": {k: writer.manifest[k] for k in sorted(writer.manifest)},
    }
    writer.put_text("index.json", json.dumps(index, indent=1, sort_keys=False) + "\n")
    removed = prune(produced | {"index.json"}, check)

    mb = {k: round(v / 1e6, 1) for k, v in sorted(writer.bytes.items())}
    print("audio: sfx %d, voice %d (%s; source %s), music %d" % (
        sum(1 for r in produced if r.startswith("sfx/")), sum(1 for r in produced if r.startswith("voice/")), codec,
        ", ".join("%s %d" % kv for kv in voice_codecs.items()), len(music)))
    print("audio: skipped %d voice SAMPs no skirmish set names (%.1f MB in the WAD)" % (skipped_voices, skipped_bytes / 1e6))
    print("audio: MB %s" % mb)
    if shadowed:
        print("audio: voice names also in sounds.wad (sets use the SFX copy):", shadowed[:20], len(shadowed))
    if missing:
        print("audio: names a set uses that no WAD has:", sorted(missing)[:20])
    print("audio: %d written, %d unchanged, %d removed%s" % (writer.written, writer.kept, removed, " [check]" if check else ""))


if __name__ == "__main__":
    main()
