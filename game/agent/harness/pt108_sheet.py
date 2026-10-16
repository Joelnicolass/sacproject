"""Playtest F108: one sheet per biome (walk sequence, 360 turn at game zoom, 360 at max zoom, RTS / horizon of look_gallery).
usage: python3 -I pt108_sheet.py  (reads agent/out/pt108, writes agent/out/pt108/sheet_<god>.png)"""
import os
from PIL import Image, ImageDraw
OUT = "/Users/joelsartori/Development/sacproject/game/agent/out/pt108"
W, H = 426, 240

def row(paths, label):
    ims = [p for p in paths if os.path.exists(p)]
    r = Image.new("RGB", (W * 5, H + 18), (20, 20, 20))
    ImageDraw.Draw(r).text((4, 2), label, fill=(255, 255, 255))
    for i, p in enumerate(ims[:5]):
        r.paste(Image.open(p).convert("RGB").resize((W, H)), (i * W, 18))
    return r

for g in ["james", "stratos", "charnel", "persephone", "pyro"]:
    rows = []
    wd = f"{OUT}/walk_{g}"
    seq = sorted(f for f in os.listdir(wd) if f.startswith("seq") and f.endswith(".png")) if os.path.isdir(wd) else []
    pick = seq[1::2][:5] if len(seq) > 5 else seq
    rows.append(row([f"{wd}/{f}" for f in pick], f"{g}: caminata move_forward (cada 0.8 s)"))
    ld = f"{OUT}/look_{g}"
    rows.append(row([f"{ld}/{g}_t{a}.png" for a in (0, 90, 180, 270, 360)], f"{g}: giro 360 turn_right, zoom de juego"))
    rows.append(row([f"{ld}/{g}_zmax_{a}.png" for a in (0, 90, 180, 270, 360)], f"{g}: zoom_out maximo + giro 360"))
    rows.append(row([f"{OUT}/gallery/rts_{g}.png", f"{OUT}/gallery/horizonte_{g}.png",
                     f"{OUT}/hotswap/hot_{g}.png", f"{OUT}/gallery_onoff/rts_{g}_on.png", f"{OUT}/gallery_onoff/rts_{g}_off.png"],
                    f"{g}: look_gallery rts | horizonte | hotswap | rts pasto ON | rts pasto OFF (KP4)"))
    s = Image.new("RGB", (W * 5, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        s.paste(r, (0, y)); y += r.height
    s.save(f"{OUT}/sheet_{g}.png")
    print("sheet", g, len(seq), "seq frames")
