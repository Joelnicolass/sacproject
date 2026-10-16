#!/usr/bin/env python3
"""Grass bench metrics (022e4c, RFC-022e section 12.5/12.6).

usage: python3 -I grass_bench_metrics.py <bench_dir> [--base <baseline_dir>] [--label <name>]

Reads what agent/fixtures/grass_bench.gd saved in <bench_dir>: <view>_{A,B,A2,C}.png, sweep_NN_{A,B}.png,
bench.json (camera of every shot, primitives, radius), height_r.f32 (baked height map) and zone_data.png.
The masks are computed here with the SAME math the bench documents: a ray per pixel (4 px grid) marched
against the baked height map, slope by the central difference over 2.5 m of grass_bake.gdshader,
horizontal distance to the camera; R = hillside (>= 18 deg), G = plain (<= 6 deg); the wizard box, the sky
and the map zones without grass (zone_data.b = 0) are excluded.
Writes metrics.json and bench_<view>.png (A | B | |A-B| x4 | mask with the isolated blades in red) and
prints PASS/FAIL per criterion of the contract (section 12.6).
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HILL_DEG = 18.0
PLAIN_DEG = 6.0
RING_M = 5.0
MIN_RING_PX = 150
BLADE_DL = 6.0           # |L_A - L_B| over 255
BLADE_DE = 8.0           # RGB distance over 255
ISO_MAX_PX = 12
ISO_RING_PX = 3
ISO_RING_DENSITY = 0.20
MAP_M = 2560.0
TEXEL_M = 2.5
STEP_PX = 4


def load_rgb(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)


def lum(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def blade_mask(a, b):
    d = np.abs(a - b)
    dl = np.abs(lum(a) - lum(b))
    de = np.sqrt((d ** 2).sum(-1))
    return (dl > BLADE_DL) | (de > BLADE_DE)


class Terrain:
    def __init__(self, d):
        self.h = np.fromfile(d / "height_r.f32", dtype=np.float32).reshape(1024, 1024).astype(np.float64)
        zone = Image.open(d / "zone_data.png").convert("RGBA")
        self.zone_b = np.asarray(zone, dtype=np.float64)[..., 2] / 255.0

    def height(self, x, z):
        return ndi.map_coordinates(self.h, [z / TEXEL_M - 0.5, x / TEXEL_M - 0.5], order=1, mode="nearest")

    def slope_deg(self, x, z):
        hx = self.height(x + TEXEL_M, z) - self.height(x - TEXEL_M, z)
        hz = self.height(x, z + TEXEL_M) - self.height(x, z - TEXEL_M)
        return np.degrees(np.arctan(np.hypot(hx, hz) / (2.0 * TEXEL_M)))

    def zone(self, x, z):
        return ndi.map_coordinates(self.zone_b, [z / TEXEL_M - 0.5, x / TEXEL_M - 0.5], order=1, mode="nearest")


def geometry(terrain, cam, size):
    """(hit, dist, slope, zone_b) at full resolution, by marching a ray per 4 px cell."""
    w, h = size
    xs = np.arange(STEP_PX // 2, w, STEP_PX)
    ys = np.arange(STEP_PX // 2, h, STEP_PX)
    px, py = np.meshgrid(xs, ys)
    eye = np.array(cam["eye"])
    fwd, right, up = (np.array(cam[k]) for k in ("forward", "right", "up"))
    tan_half = math.tan(math.radians(cam["fov"]) * 0.5)
    nx = (px / w) * 2.0 - 1.0
    ny = 1.0 - (py / h) * 2.0
    dirs = fwd[None, None, :] + right[None, None, :] * (nx * tan_half * w / h)[..., None] + up[None, None, :] * (ny * tan_half)[..., None]
    dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)
    d = dirs.reshape(-1, 3)
    n = d.shape[0]
    hit = np.zeros(n, dtype=bool)
    t_lo = np.zeros(n)
    t_hi = np.zeros(n)
    prev_t = 0.3
    t = 0.3
    while t < 170.0:
        p = eye[None, :] + d * t
        below = (p[:, 1] < terrain.height(p[:, 0], p[:, 2])) & ~hit
        t_lo[below] = prev_t
        t_hi[below] = t
        hit |= below
        prev_t = t
        t += 0.4 if t < 60.0 else 1.0
    lo, hi = t_lo.copy(), t_hi.copy()
    for _ in range(10):
        mid = (lo + hi) * 0.5
        p = eye[None, :] + d * mid[:, None]
        under = p[:, 1] < terrain.height(p[:, 0], p[:, 2])
        hi = np.where(under, mid, hi)
        lo = np.where(under, lo, mid)
    p = eye[None, :] + d * hi[:, None]
    dist = np.hypot(p[:, 0] - eye[0], p[:, 2] - eye[2])
    slope = terrain.slope_deg(p[:, 0], p[:, 2])
    zone = terrain.zone(p[:, 0], p[:, 2])
    inside = (p[:, 0] > 0) & (p[:, 2] > 0) & (p[:, 0] < MAP_M) & (p[:, 2] < MAP_M)
    hit &= inside
    gh, gw = px.shape

    def up_(a):
        return np.repeat(np.repeat(a.reshape(gh, gw), STEP_PX, axis=0), STEP_PX, axis=1)[:h, :w]

    return up_(hit), up_(dist), up_(slope), up_(zone)


def regions(geo, cam, size):
    hit, dist, slope, zone = geo
    w, h = size
    box = cam["wizard_box"]
    keep = hit & (zone > 0.05)
    x0, y0, x1, y1 = (int(box[0]), int(box[1]), int(math.ceil(box[2])), int(math.ceil(box[3])))
    keep[max(y0, 0):max(y1, 0), max(x0, 0):max(x1, 0)] = False
    hill = keep & (slope >= HILL_DEG)
    plain = keep & (slope <= PLAIN_DEG)
    return hill, plain, keep


VISIBLE_DL = 16.0        # a loose blade counts as "visible" if its peak |dL| is over this (about 6 % of 255)


def isolated_blades(blade, region, dl=None):
    """Boolean mask of the blade pixels that belong to a small component (<= 12 px) with almost no
    blade in the 3 px around it: loose blades over smooth ground."""
    lab, count = ndi.label(blade, structure=np.ones((3, 3)))
    if count == 0:
        return np.zeros_like(blade), np.zeros_like(blade)
    sizes = ndi.sum(blade, lab, index=np.arange(1, count + 1))
    out = np.zeros_like(blade)
    vis = np.zeros_like(blade)
    small = np.where(sizes <= ISO_MAX_PX)[0] + 1
    objs = ndi.find_objects(lab)
    hh, ww = blade.shape
    for k in small:
        sl = objs[k - 1]
        y0, y1 = max(sl[0].start - ISO_RING_PX, 0), min(sl[0].stop + ISO_RING_PX, hh)
        x0, x1 = max(sl[1].start - ISO_RING_PX, 0), min(sl[1].stop + ISO_RING_PX, ww)
        own = lab[y0:y1, x0:x1] == k
        if not (region[y0:y1, x0:x1] & own).any():
            continue
        ring = ndi.binary_dilation(own, structure=np.ones((3, 3)), iterations=ISO_RING_PX) & ~own
        if ring.sum() == 0:
            continue
        density = (blade[y0:y1, x0:x1] & ring).sum() / ring.sum()
        if density < ISO_RING_DENSITY:
            out[y0:y1, x0:x1] |= own
            if dl is not None and dl[y0:y1, x0:x1][own].max() >= VISIBLE_DL:
                vis[y0:y1, x0:x1] |= own
    return out, vis


def max_hole(blade, region):
    inner = ndi.binary_erosion(region, structure=np.ones((3, 3)))
    holes = inner & ~blade
    lab, count = ndi.label(holes, structure=np.ones((3, 3)))
    if count == 0:
        return 0
    return int(np.bincount(lab.ravel())[1:].max())


def blur_hf(l):
    return l - ndi.gaussian_filter(l, 1.5)


def ring_table(la, lb, hfa, hfb, blade, iso, region, dist, radius, name):
    rings = []
    edges = np.arange(5.0, radius + RING_M, RING_M)
    for lo in edges:
        sel = region & (dist >= lo) & (dist < lo + RING_M)
        n = int(sel.sum())
        if n < MIN_RING_PX:
            continue
        rings.append({
            "from_m": float(lo), "pixels": n,
            "coverage": float(blade[sel].mean()),
            "max_hole_px": max_hole(blade, sel),
            "isolated_per_10k": float(iso[sel].sum() / max(n, 1) * 10000.0 / 3.0),  # ~3 px per loose blade
            "hf": float(max(hfa[sel].std() - hfb[sel].std(), 0.0)),
            "L_A": float(la[sel].mean()), "L_B": float(lb[sel].mean())})
    return rings


def isolated_components(iso, region):
    lab, count = ndi.label(iso, structure=np.ones((3, 3)))
    return int(count)


def analyse(d, label, cam, terrain, size, info):
    a, b = load_rgb(d / f"{label}_A.png"), load_rgb(d / f"{label}_B.png")
    la, lb = lum(a), lum(b)
    blade = blade_mask(a, b)
    geo = geometry(terrain, cam, size)
    hill, plain, keep = regions(geo, cam, size)
    dist = geo[1]
    radius = info["radius_m"] * info["fade_end"]
    hfa, hfb = blur_hf(la), blur_hf(lb)
    iso, iso_vis = isolated_blades(blade, keep, np.abs(la - lb))
    out = {"geo": geo, "hill": hill, "plain": plain, "keep": keep, "blade": blade, "iso": iso, "iso_vis": iso_vis, "A": a, "B": b}
    res = {}
    for name, region in (("hill", hill), ("plain", plain), ("grass", keep)):
        inside = region & (dist <= radius)
        n = int(inside.sum())
        comps = 0
        comps_vis = 0
        if n:
            lab, count = ndi.label(iso & inside, structure=np.ones((3, 3)))
            comps = int(count)
            lab, count = ndi.label(iso_vis & inside, structure=np.ones((3, 3)))
            comps_vis = int(count)
        res[name] = {
            "pixels": n,
            "isolated_components": comps,
            "isolated_per_10k": float(comps * 10000.0 / n) if n >= MIN_RING_PX else 0.0,
            "isolated_visible_per_10k": float(comps_vis * 10000.0 / n) if n >= MIN_RING_PX else 0.0,
            "rings": ring_table(la, lb, hfa, hfb, blade, iso, region, dist, radius, name)}
    return res, out


def sheet(path, o):
    a, b = o["A"], o["B"]
    diff = np.clip(np.abs(lum(a) - lum(b)) * 4.0, 0, 255)
    h, w = diff.shape
    mask = np.zeros((h, w, 3))
    mask[o["hill"]] = (220, 120, 40)
    mask[o["plain"]] = (50, 160, 80)
    mask[o["blade"] & o["keep"]] = mask[o["blade"] & o["keep"]] * 0.5 + 100
    mask[ndi.binary_dilation(o["iso"], iterations=3) & o["keep"]] = (255, 0, 0)
    mask[o["iso"]] = (255, 255, 0)
    tiles = [a, b, np.stack([diff] * 3, -1), mask]
    s = Image.new("RGB", (w * 2, h * 2))
    for i, t in enumerate(tiles):
        s.paste(Image.fromarray(np.clip(t, 0, 255).astype(np.uint8)), ((i % 2) * w, (i // 2) * h))
    s.save(path)


def main():
    d = Path(sys.argv[1])
    base = Path(sys.argv[sys.argv.index("--base") + 1]) if "--base" in sys.argv else None
    info = json.loads((d / "bench.json").read_text())
    size = tuple(info["size"])
    terrain = Terrain(d)
    radius = info["radius_m"] * info["fade_end"]
    near_r = info["near_radius_m"]
    mid_fade = (info["fade_start"] + 1.0) * 0.5 * radius       # nominal height >= 50 % up to here
    out = {"preset": info["preset"], "radius_eff_m": radius, "near_radius_m": near_r, "visible_to_m": mid_fade, "views": {}, "sweep": [], "criteria": {}, "prims": info["prims"]}
    crit = out["criteria"]
    detail = {k: {} for k in ("0", "1", "2", "3", "4", "5", "6", "7", "8")}
    ok = {k: True for k in detail}
    views = info["views"]

    # ---- per view ----
    keep_sheets = {}
    for label in views:
        cam = info["shots"][label]
        res, o = analyse(d, label, cam, terrain, size, info)
        out["views"][label] = {k: v for k, v in res.items()}
        keep_sheets[label] = o
        sheet(d / f"bench_{label}.png", o)
        # 0: bench valid (A vs A2 outside the wizard box)
        a2 = load_rgb(d / f"{label}_A2.png")
        mask_out = np.ones(o["blade"].shape, dtype=bool)
        bx = cam["wizard_box"]
        mask_out[max(int(bx[1]), 0):max(int(math.ceil(bx[3])), 0), max(int(bx[0]), 0):max(int(math.ceil(bx[2])), 0)] = False
        mean_diff = float((np.abs(lum(o["A"]) - lum(a2))[mask_out].mean()) / 255.0)
        distinct = float(blade_mask(o["A"], a2)[mask_out].mean())
        good = mean_diff <= 0.001 and distinct <= 0.0002
        ok["0"] &= good
        detail["0"][label] = {"mean_diff": mean_diff, "distinct_px": distinct, "pass": good}
        # 1: continuous hillside (zone visible)
        if label != "plain_p":
            rings = [r for r in res["hill"]["rings"] if 10.0 <= r["from_m"] and r["from_m"] + RING_M <= mid_fade]
            if rings:
                good = all(r["coverage"] >= 0.85 and r["max_hole_px"] <= 64 for r in rings)
                ok["1"] &= good
                detail["1"][label] = {"pass": good, "rings": [(r["from_m"], round(r["coverage"], 3), r["max_hole_px"]) for r in rings]}
            else:
                detail["1"][label] = {"pass": None, "note": "no hillside rings with enough pixels"}
        # 2: no loose blades (hill and plain, up to the radius)
        for name in ("hill", "plain"):
            r = res[name]
            if r["pixels"] >= MIN_RING_PX:
                good = r["isolated_per_10k"] <= 1.0
                ok["2"] &= good
                detail["2"][f"{label}.{name}"] = {"pass": good, "per_10k": round(r["isolated_per_10k"], 3), "components": r["isolated_components"], "visible_per_10k": round(r["isolated_visible_per_10k"], 3), "pixels": r["pixels"]}
        # 3: fine detail falls with distance
        g = res["grass"]["rings"]
        sel = [r for r in g if r["from_m"] >= near_r - RING_M * 0.5]
        if len(sel) >= 3:
            mono = True
            worst = 0.0
            for p, q in zip(sel, sel[1:]):
                limit = p["hf"] * 1.05 + 0.05
                if q["hf"] > limit:
                    mono = False
                    worst = max(worst, q["hf"] - limit)
            last = sel[-1]["hf"] <= 0.10 * sel[0]["hf"] + 0.05
            cov = True
            for p, q in zip(g, g[1:]):
                if q["from_m"] <= mid_fade and p["coverage"] > 0.0 and (p["coverage"] - q["coverage"]) / p["coverage"] > 0.10:
                    cov = False
            good = mono and last and cov
            ok["3"] &= good
            detail["3"][label] = {"pass": good, "monotone": mono, "last_le_10pct": last, "coverage_no_drop": cov, "hf": [(r["from_m"], round(r["hf"], 2), round(r["coverage"], 2)) for r in sel]}
        # 5: no dark band
        for name in ("plain", "hill"):
            rings = res[name]["rings"]
            if len(rings) < 2:
                continue
            drop = max((r["L_B"] - r["L_A"]) / max(r["L_B"], 1.0) for r in rings)
            jumps = [abs(q["L_A"] - p["L_A"]) / max(p["L_A"], 1.0) for p, q in zip(rings, rings[1:])]
            jump_ab = [abs((q["L_A"] - q["L_B"]) - (p["L_A"] - p["L_B"])) / max(p["L_B"], 1.0) for p, q in zip(rings, rings[1:])]
            good = drop <= 0.04 and max(jumps) <= 0.04
            ok["5"] &= good
            detail["5"][f"{label}.{name}"] = {"pass": good, "worst_drop": round(drop, 4), "worst_jump_LA": round(max(jumps), 4), "worst_jump_AminusB": round(max(jump_ab), 4)}
        # 7: prims
        pr = info["prims"].get(label)
        if pr:
            detail["7"][label] = {"A": pr["A"], "B": pr["B"], "grass_prims": pr["A"] - pr["B"]}
        # 4: plain regression against the baseline
        if base is not None and label in ("plain_p", "hill_game") and (base / f"{label}_A.png").exists():
            ba = lum(load_rgb(base / f"{label}_A.png"))
            sel_px = o["plain"] & (o["geo"][1] >= 8.0) & (o["geo"][1] <= 25.0)
            if sel_px.sum() >= MIN_RING_PX:
                diff = float(np.abs(lum(o["A"]) - ba)[sel_px].mean() / 255.0)
                good = diff <= 0.01
                ok["4"] &= good
                detail["4"][label] = {"plain_diff": round(diff, 5), "pass": good, "pixels": int(sel_px.sum())}

    # 7 against the baseline
    if base is not None and (base / "bench.json").exists():
        binfo = json.loads((base / "bench.json").read_text())
        for label in views:
            pb = binfo["prims"].get(label)
            pn = info["prims"].get(label)
            if pb and pn:
                gb = pb["A"] - pb["B"]
                gn = pn["A"] - pn["B"]
                good = gn <= gb * 1.10
                ok["7"] &= good
                detail["7"][label].update({"base_grass_prims": gb, "ratio": round(gn / max(gb, 1), 3), "pass": good})

    # 8: R2 does not thin out in low: criterion 2 on the rts view
    if info["preset"] == "low" and "rts" in views:
        for name in ("hill", "plain"):
            r = out["views"]["rts"][name]
            if r["pixels"] >= MIN_RING_PX and r["isolated_per_10k"] > 1.0:
                ok["8"] = False
        detail["8"]["rts"] = {n: out["views"]["rts"][n]["isolated_per_10k"] for n in ("hill", "plain")}
    else:
        ok["8"] = None

    # ---- sweep ----
    prev_mean = None
    for i in range(int(info["sweep_steps"])):
        label = f"sweep_{i:02d}"
        if label not in info["shots"]:
            continue
        cam = info["shots"][label]
        res, o = analyse(d, label, cam, terrain, size, info)
        frame_ok = True
        rings = [r for r in res["hill"]["rings"] if 10.0 <= r["from_m"] and r["from_m"] + RING_M <= mid_fade]
        if rings and not all(r["coverage"] >= 0.85 and r["max_hole_px"] <= 64 for r in rings):
            frame_ok = False
        for name in ("hill", "plain"):
            r = res[name]
            if r["pixels"] >= MIN_RING_PX and r["isolated_per_10k"] > 1.0:
                frame_ok = False
        gp = o["plain"]
        mean_ab = float((lum(o["A"]) - lum(o["B"]))[gp].mean() / 255.0) if gp.sum() >= MIN_RING_PX else None
        jump = abs(mean_ab - prev_mean) if (mean_ab is not None and prev_mean is not None) else 0.0
        if jump > 0.015:
            frame_ok = False
        if mean_ab is not None:
            prev_mean = mean_ab
        ok["6"] &= frame_ok
        out["sweep"].append({"frame": i, "pass": frame_ok, "hill_cov": [round(r["coverage"], 3) for r in rings], "hill_hole": [r["max_hole_px"] for r in rings],
                             "iso_hill": round(res["hill"]["isolated_per_10k"], 3), "iso_plain": round(res["plain"]["isolated_per_10k"], 3),
                             "plain_mean_AminusB": mean_ab, "jump": jump})
        if i in (0, int(info["sweep_steps"]) // 2, int(info["sweep_steps"]) - 1):
            sheet(d / f"bench_{label}.png", o)
    detail["6"] = {"frames": len(out["sweep"]), "failed": [s["frame"] for s in out["sweep"] if not s["pass"]]}
    if not out["sweep"]:
        ok["6"] = None

    names = {"0": "bench valid", "1": "hillside continuous", "2": "no loose blades", "3": "fine detail falls with distance", "4": "plain no regression",
             "5": "no dark band", "6": "no pop (sweep)", "7": "cost (prims vs base)", "8": "R2 does not thin out (low)"}
    if base is None:
        ok["4"] = None
        ok["7"] = None
    for k in sorted(detail):
        crit[k] = {"name": names[k], "pass": ok[k], "detail": detail[k]}
    (d / "metrics.json").write_text(json.dumps(out, indent=1, default=float))
    for k in sorted(crit):
        state = "N/A" if crit[k]["pass"] is None else ("PASS" if crit[k]["pass"] else "FAIL")
        print(f"{k} {crit[k]['name']}: {state}")


if __name__ == "__main__":
    main()
