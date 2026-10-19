#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

The particle atlases and their catalog (sacobject.d SacParticle / SacSoul): which TXTR of which WAD folder, and the
per-type numbers (size, energy, delay, gravity, lifetime) the game reads from fx.json.

Data and helpers only; tools/import/import_ui.py writes assets/original/fx/ with them. The TXTR is read by tools/sac_formats.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats import txtr as _txtr  # noqa: E402

UPDATE_FPS = 60
UPDATE_ANIM_FACTOR = 2

# (wad, folder, TXTR tag) as in sacobject.d loadTXTR paths.
ATLASES = {
    "cstj": ("charlie.wad", "Bloo.WAD!/Jame.FLDR/tex.FLDR"),
    "cstl": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    "glo2": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "spd6": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "rock": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "dirt": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "blud": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "spir": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "flao": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "wrth": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    "prth": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    "dust": ("shawn.wad", "shwn.WAD!/jams.FLDR/text.FLDR"),
    "jspk": ("shawn.wad", "shwn.WAD!/jams.FLDR/text.FLDR"),  # F151: the Rhinok's spikes (SacSpike, sacobject.d:2984-2988)
    # Sac Doctor carry (RFC-020c): blue rim/rope, blue and red vortex layers, needle sparks
    # (renderer.d:222-239, sacobject.d:4030-4054, 1479-1484).
    "ltn2": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "vtx1": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "vtx2": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "vtx3": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "cst0": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    # F149: Freeze shards (sacobject.d:1485-1490, Stratos txtr).
    "shrd": ("charlie.wad", "Bloo.WAD!/Stra.FLDR/txtr.FLDR"),
    # F124: the Gnome's hit and gun flame, the Styx's sparks, the Warmonger's hit (030m-b) (sacobject.d:1521-1525,
    # 1630-1641, 4268-4273; sacengine's tex_ZERO_ folder is tex here).
    "gsqb": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    "gmfl": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    "styx": ("charlie.wad", "Bloo.WAD!/Char.FLDR/tex.FLDR"),
    "wsqb": ("charlie.wad", "Bloo.WAD!/Pyro.FLDR/txtr.FLDR"),
    # Guardian tether beam (RFC-021b): SacGuardianTether.loadTexture, sacobject.d:4466.
    "grdn": ("charlie.wad", "Bloo.WAD!/Misc.FLDR/txtr.FLDR"),
    # Teleport rings (RFC-021c): SacBlueRing.loadTexture, sacobject.d:2147.
    "brng": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    # Manafount jet and Manalith column (RFC-019c): sacobject.d:1393-1400.
    "elec": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "fb_g": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    # Death clouds (RFC-030g): steam (goc@), poison (cen@), rainbow (tum@), sacobject.d:1612-1716.
    "stem": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    "pois": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "prbw": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    # Fire on a burning body and the flame of a fire shot (RFC-030l): sacobject.d:1413-1424.
    "firy": ("main.wad", "MAIN.WAD!/bits.FLDR"),
}

# sacobject.d: width/height, energy, delay, gravity per ParticleType.
# lifetime_frames is the per-particle lifetime used by the spawn site in state.d.
PARTICLES = {
    "cast_james": dict(txtr="cstj", n_u=4, n_v=4, width=1.0, height=1.0, energy=2.0, delay=1, gravity=False, lifetime_frames=31),
    "cast_persephone": dict(txtr="cstl", n_u=4, n_v=4, width=1.0, height=1.0, energy=5.0, delay=1, gravity=False, lifetime_frames=31),
    "heal": dict(txtr="glo2", n_u=4, n_v=4, width=1.0, height=1.0, energy=4.0, delay=1, gravity=False, lifetime_frames=32),
    "speedup": dict(txtr="spd6", n_u=4, n_v=4, width=1.0, height=1.0, energy=4.0, delay=2, gravity=False, lifetime_frames=64),
    "rock": dict(txtr="rock", n_u=4, n_v=4, width=1.0, height=1.0, energy=1.0, delay=1, gravity=True, lifetime_frames=95),
    "dirt": dict(txtr="dirt", n_u=4, n_v=4, width=1.0, height=1.0, energy=1.0, delay=2, gravity=False, lifetime_frames=63),
    "blood": dict(txtr="blud", n_u=4, n_v=4, width=0.75, height=0.75, energy=8.0, delay=4, gravity=True, lifetime_frames=127),
    "hover_blood": dict(txtr="blud", n_u=4, n_v=4, width=0.75, height=0.75, energy=8.0, delay=2, gravity=False, lifetime_frames=63),
    "soul": dict(txtr="spir", n_u=4, n_v=4, width=1.0, height=1.6, energy=1.0, delay=1, gravity=False, lifetime_frames=0),
    "dust": dict(txtr="dust", n_u=4, n_v=4, width=1.0, height=1.0, energy=1.0, delay=1, gravity=False, lifetime_frames=31),
    # flao is a 3x3 atlas drawn with 252.5/256 of each cell (makeSpriteMeshes).
    "wrath_cast": dict(txtr="flao", n_u=3, n_v=3, width=1.0, height=1.0, energy=7.5, delay=1, gravity=False, lifetime_frames=31),
    "wrath_explosion1": dict(txtr="flao", n_u=3, n_v=3, width=1.0, height=1.0, energy=7.5, delay=1, gravity=False, lifetime_frames=31),
    "wrath_explosion2": dict(txtr="wrth", n_u=4, n_v=4, width=1.0, height=1.0, energy=20.0, delay=1, gravity=False, lifetime_frames=63),
    "wrath_particle": dict(txtr="prth", n_u=4, n_v=4, width=0.3, height=0.3, energy=5.0, delay=1, gravity=True, lifetime_frames=63),
    # Sac Doctor: needle sparks (sacobject.d:1479-1484: 1x1, energy 3, lifetime 31 + U(0..31) ticks).
    "needle": dict(txtr="cst0", n_u=4, n_v=4, width=1.0, height=1.0, energy=3.0, delay=1, gravity=False, lifetime_frames=46),
    # Red vortex droplets (sacobject.d:1503-1508: vtx2, 1x1, energy 3, delay 2).
    # Teleport ring: 4x4 atlas on a flat 28x28 mesh scaled by 0.08 (sacobject.d:2145-2158, renderer.d:1749-1756).
    "teleport_ring": dict(txtr="brng", n_u=4, n_v=4, width=2.24, height=2.24, energy=20.0, delay=4, gravity=False, lifetime_frames=48),
    # Manafount: 4x4 elec, 6x6 m, gravity on; lifetime up to 5 * numFrames(32) ticks (state.d:27769-27792).
    "manafount": dict(txtr="elec", n_u=4, n_v=4, width=6.0, height=6.0, energy=20.0, delay=1, gravity=True, lifetime_frames=160),
    # Manalith: 3x3 fb_g, 12x12 m, no gravity; lifetime up to 5 * numFrames(18) ticks (state.d:27793-27811).
    "manalith": dict(txtr="fb_g", n_u=3, n_v=3, width=12.0, height=12.0, energy=20.0, delay=1, gravity=False, lifetime_frames=90),
    # Death clouds (RFC-030g): steam 2x2 energy 0.25 (lifetime 63, state.d:25226), poison 1x1 energy 1 delay 2
    # (lifetime 95..127, state.d:25248), rainbow 1x1 energy 5 delay 2 gravity (lifetime 63, state.d:25689).
    "steam": dict(txtr="stem", n_u=4, n_v=4, width=2.0, height=2.0, energy=0.25, delay=1, gravity=False, lifetime_frames=63),
    "poison": dict(txtr="pois", n_u=4, n_v=4, width=1.0, height=1.0, energy=1.0, delay=2, gravity=False, lifetime_frames=127),
    "rainbow": dict(txtr="prbw", n_u=4, n_v=4, width=1.0, height=1.0, energy=5.0, delay=2, gravity=True, lifetime_frames=63),
    # Fire (RFC-030l): firy 4x4, 1x1 m, energy 8, delay 2 (sacobject.d:1419-1424, 1793); lifetime up to numFrames
    # (spawnFireParticles, state.d:15093-15110). The original adds it (energy 8); over the snow that only reaches white, so
    # the port draws firy_a (the same glow as a straight-alpha overlay, glow_to_alpha) with blend_mix and energy 1.
    "fire": dict(txtr="firy_a", n_u=4, n_v=4, width=1.0, height=1.0, energy=1.0, delay=2, gravity=False, lifetime_frames=63),
    # F149: the Silverback's breath (ParticleType.freeze, sacobject.d:1479-1484: cst0 1x1, energy 3; lifetime
    # cast(int)(60·40/36) = 66, state.d:24816-24828), drawn as cst0_a with blend_mix like the fire (additive over the
    # snow only reaches white), and the thaw's shards (ParticleType.shard, 1485-1490: shrd, gravity; 31, 17605).
    "freeze": dict(txtr="cst0_a", n_u=4, n_v=4, width=1.0, height=1.0, energy=1.0, delay=1, gravity=False, lifetime_frames=66),
    "shard": dict(txtr="shrd", n_u=4, n_v=4, width=1.0, height=1.0, energy=1.0, delay=1, gravity=True, lifetime_frames=31),
    # F124: gnomeHit (sacobject.d:1630-1635, 1788: gsqb 0.5x0.5, energy 5, delay 2, gravity; 200 of lifetime 63,
    # animateGnomeHit state.d:11710-11722), warmongerHit (1636-1641, 1789: wsqb, delay 1, lifetime 31, animateWarmongerHit state.d:11821-11831; 030m-b) and styxSpark
    # (1521-1525, 1782: styx 1x1 atlas, 1x1 m, energy 15, delay 2, no gravity; 192 of lifetime 15..95, 24137-24152).
    # The original adds them; over the snow that only reaches white, so (like the fire) the port draws gsqb_a, wsqb_a and styx_a
    # (glow_to_alpha) with blend_mix and energy 1.
    "gnome_hit": dict(txtr="gsqb_a", n_u=4, n_v=4, width=0.5, height=0.5, energy=1.0, delay=2, gravity=True, lifetime_frames=63),
    "warmonger_hit": dict(txtr="wsqb_a", n_u=4, n_v=4, width=0.5, height=0.5, energy=1.0, delay=1, gravity=True, lifetime_frames=31),
    "styx_spark": dict(txtr="styx_a", n_u=1, n_v=1, width=1.0, height=1.0, energy=1.0, delay=2, gravity=False, lifetime_frames=95),
    "red_vortex_droplet": dict(txtr="vtx2", n_u=4, n_v=4, width=1.0, height=1.0, energy=3.0, delay=2, gravity=False, lifetime_frames=64),
}

ADDITIVE = {"cast_james", "cast_persephone", "heal", "speedup", "soul", "wrath_cast", "wrath_explosion1", "wrath_explosion2", "wrath_particle", "needle", "red_vortex_droplet", "teleport_ring", "manafount", "manalith", "steam", "rainbow"}
GRAVITY = 15.0


def glow_to_alpha(rgba: bytes, gain: float) -> bytes:
    """An additive glow on black as a straight-alpha overlay (RFC-030l): the hue at full brightness, alpha = brightness · gain.
    Drawn with blend_mix it keeps its color over a bright ground (snow), where adding light can only reach white."""
    out = bytearray(len(rgba))
    for i in range(0, len(rgba), 4):
        r, g, b = rgba[i], rgba[i + 1], rgba[i + 2]
        peak = max(r, g, b)
        if peak == 0:
            continue
        out[i : i + 4] = bytes((r * 255 // peak, g * 255 // peak, b * 255 // peak, min(255, int(peak * gain))))
    return bytes(out)


# Atlases also written as a straight-alpha overlay: tag -> (png name, gain).
OVERLAYS = {"firy": ("firy_a", 3.0), "cst0": ("cst0_a", 3.0), "gsqb": ("gsqb_a", 3.0), "wsqb": ("wsqb_a", 3.0), "styx": ("styx_a", 6.0), "gmfl": ("gmfl_a", 2.0)}


def atlas_images(files: dict, folder: str, tag: str):
    """{png stem: (width, height, RGBA)} of an atlas and of its straight-alpha overlay, None if the TXTR is missing."""
    found = _txtr.flat_texture(files, folder, tag)
    if found is None:
        return None
    width, height, rgba = found
    out = {tag: (width, height, rgba)}
    if tag in OVERLAYS:
        name, gain = OVERLAYS[tag]
        out[name] = (width, height, glow_to_alpha(rgba, gain))
    return out


def catalog(png_of: dict) -> dict:
    """fx.json: the PARTICLES whose atlas was read. png_of maps an atlas stem (cstj, firy_a...) to the path the game loads."""
    out = {}
    for name, p in PARTICLES.items():
        png = png_of.get(p["txtr"])
        if png is None:
            continue
        frame_s = p["delay"] * UPDATE_ANIM_FACTOR / UPDATE_FPS
        out[name] = {
            "png": png,
            "txtr": p["txtr"],
            "n_u": p["n_u"],
            "n_v": p["n_v"],
            "width": p["width"],
            "height": p["height"],
            "energy": p["energy"],
            "delay": p["delay"],
            "frame_s": round(frame_s, 5),
            "gravity": GRAVITY if p["gravity"] else 0.0,
            "lifetime_s": round(p["lifetime_frames"] / UPDATE_FPS, 5),
            "additive": name in ADDITIVE,
        }
    out["soul"]["frames_blue"] = [0, 7]
    out["soul"]["frames_red"] = [8, 15]
    return out
