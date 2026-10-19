"""Where the original's installation is. The WAD files are read from there and never copied or versioned."""

import os
from pathlib import Path

INSTALL = Path(os.environ.get("SAC_INSTALL", "/Users/joelsartori/Downloads/sacgame/Sacrifice/data"))
MAPS = Path(os.environ.get("SAC_MAPS", str(INSTALL.parent / "maps")))
