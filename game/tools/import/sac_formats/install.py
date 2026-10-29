"""Where the ORIGINAL Sacrifice install is. The WAD files are read from there and never copied or versioned.

Playing the port does NOT need it (the assets are already in assets/original/). Only the tools that read the original need it.

Resolution order (the first one that is set wins; there is no personal default):
  1. env SAC_INSTALL   the folder with the WADs (the game's `data/`)        [SAC_MAPS: the folder with the .scp, optional]
  2. env SAC_ROOT      the game's root folder, the one holding `data/` and `maps/`
  3. tools/import/local.cfg   (git-ignored; copy local.cfg.example)  with the same keys, one `KEY=value` per line
  4. the editor setting sacrifice/original_install_path (the Sacrifice plugin passes it as SAC_INSTALL)
If none gives a valid folder the tool prints a message and exits with status 2.
"""

import os
import sys
from pathlib import Path

NEEDS_ORIGINAL = "Needs the original game installed (SAC_INSTALL)."
# A couple of WADs every real install has; the folder is valid when it holds all of them.
KNOWN_WADS = ("spells.wad", "models.wad", "main.wad")
LOCAL_CFG = Path(__file__).resolve().parents[1] / "local.cfg"

MESSAGE = """\
ERROR: the original Sacrifice game was not found.

This tool reads the files of the ORIGINAL installed game (it is NOT in the repository: it is the
commercial game, and the .wad files are neither versioned nor copied). Playing the port does NOT need it;
only importing or regenerating assets from the original does.

It needs the folder that holds the .wad files (for example spells.wad, models.wad, main.wad) and, beside it,
the maps/ folder with the .scp files. It is usually called "data" inside the install folder. Typical places (examples):
  Windows, GOG:           C:\\GOG Games\\Sacrifice\\data
  Windows, Steam:         C:\\Program Files (x86)\\Steam\\steamapps\\common\\Sacrifice\\data
  macOS/Linux with Wine:  ~/.wine/drive_c/GOG Games/Sacrifice/data
  macOS with CrossOver:   ~/Library/Application Support/CrossOver/Bottles/<bottle>/drive_c/GOG Games/Sacrifice/data
  Or a copy made by hand: ~/games/Sacrifice/data

How to point to it (any of the three):
  1) environment variable:  export SAC_INSTALL="/path/to/Sacrifice/data"
                            (or SAC_ROOT="/path/to/Sacrifice", the folder that holds data/ and maps/)
  2) local file:            copy tools/import/local.cfg.example to tools/import/local.cfg and fill in SAC_INSTALL=
  3) Godot editor:          Editor > Editor Settings > sacrifice > original_install_path (the Sacrifice plugin passes it)
"""


def _read_cfg(path: Path) -> dict:
    values = {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return values
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = os.path.expanduser(value.strip().strip('"').strip("'"))
    return values


def _candidates() -> list:
    """(source, data folder, maps folder or None) in resolution order; only the ones that are set."""
    out = []
    cfg = _read_cfg(LOCAL_CFG)
    env = os.environ
    for source, get in (("environment variable", lambda k: env.get(k, "")), ("local.cfg", lambda k: cfg.get(k, ""))):
        maps = get("SAC_MAPS") or None
        if get("SAC_INSTALL"):
            out.append((source + " SAC_INSTALL", Path(os.path.expanduser(get("SAC_INSTALL"))), maps))
        elif get("SAC_ROOT"):
            root = Path(os.path.expanduser(get("SAC_ROOT")))
            out.append((source + " SAC_ROOT", root / "data", maps or str(root / "maps")))
    return out


def valid_install(path: Path) -> bool:
    return path.is_dir() and all((path / wad).is_file() for wad in KNOWN_WADS)


def explain_and_exit(detail: str = "") -> None:
    sys.stderr.write(MESSAGE)
    if detail:
        sys.stderr.write("\n" + detail + "\n")
    sys.exit(2)


def _resolve():
    cands = _candidates()
    if not cands:
        explain_and_exit()
    tried = []
    for source, data, maps in cands:
        if valid_install(data):
            return data, Path(maps) if maps else data.parent / "maps"
        tried.append("  %s = %s  (lacks %s)" % (source, data, ", ".join(KNOWN_WADS)))
    explain_and_exit("What was tried and is not valid:\n" + "\n".join(tried))


def require_maps() -> None:
    """For the tools that read the .scp files: MAPS must hold them."""
    if not (MAPS.is_dir() and any(MAPS.glob("*.scp"))):
        explain_and_exit("The maps folder (%s) does not exist or has no .scp files.\n"
                         "It must sit beside data/ (the maps/ folder), or point to it with SAC_MAPS=/path/to/maps." % MAPS)


if any(a in ("-h", "--help") for a in sys.argv[1:]):
    # --help never needs the install: print the tool's own docstring after the notice.
    main_doc = (getattr(sys.modules.get("__main__"), "__doc__", None) or "").strip()
    print((main_doc if main_doc.startswith("Needs") else NEEDS_ORIGINAL + "\n\n" + main_doc) + "\n\n" + "How to point to the folder: see tools/import/local.cfg.example "
          "(SAC_INSTALL / SAC_ROOT / local.cfg / editor setting).")
    sys.exit(0)

INSTALL, MAPS = _resolve()
