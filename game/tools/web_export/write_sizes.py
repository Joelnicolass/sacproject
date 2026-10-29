"""Writes index.sizes.json next to a web export: the raw size of each file the page downloads,
for a loader whose host serves them compressed without a useful Content-Length.

python3 tools/web_export/write_sizes.py build/web
"""
import json
import sys
from pathlib import Path

folder = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
sizes = {
    path.name: path.stat().st_size
    for path in sorted(folder.glob("index.*"))
    if path.suffix in (".pck", ".wasm", ".js") and path.name != "index.sizes.json"
}
(folder / "index.sizes.json").write_text(json.dumps(sizes, indent=2) + "\n")
print(json.dumps(sizes))
