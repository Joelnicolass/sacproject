"""RFC-067 P6: splits scenes/bodies/materials/*.tres into the materials still without a normal map, foliage vs the rest,
and writes one path per line to <out>/foliage.txt and <out>/default.txt (for tools/bake/bake_relief.gd).

    python3 -I agent/harness/relief_batch_lists.py <game dir> <out dir>

Foliage = flora plants (`<TAG>_plant*`) plus the props whose texture is mostly leaves (FOLIAGE_PROPS, picked by looking at
their albedos). A material that already has `normal_enabled = true` is left out of both lists (the pilots).
"""
import sys
from pathlib import Path

# Tree and leafy props (albedo mostly leaves, needles or petals), by owner tag.
FOLIAGE_PROPS = {"cat6", "pcbs", "pct1", "pct2", "pct4", "pct5", "pct6", "pct7", "pct8", "pct9", "plm1", "ptre", "puav",
                 "sfc1", "spfl", "st1a", "stt1"}


def is_foliage(name: str) -> bool:
    if "_plant" in name:
        return True
    return name.endswith("_cutout.tres") and name.split("_")[0] in FOLIAGE_PROPS


def main() -> None:
    game, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    lists = {"foliage": [], "default": []}
    skipped = 0
    for path in sorted((game / "scenes/bodies/materials").glob("*.tres")):
        if "normal_enabled = true" in path.read_text():
            skipped += 1
            continue
        lists["foliage" if is_foliage(path.name) else "default"].append("res://scenes/bodies/materials/" + path.name)
    for key, paths in lists.items():
        (out / (key + ".txt")).write_text("\n".join(paths) + "\n")
        print("%s: %d" % (key, len(paths)))
    print("already with a normal map: %d" % skipped)


if __name__ == "__main__":
    main()
