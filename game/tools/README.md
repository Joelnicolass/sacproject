# tools/

Herramientas de desarrollo, nunca parte del juego (el export las excluye).
- `import/`: Python que lee los datos originales y escribe `assets/original/` (`import_*.py`, `export_*.py`, `sac_formats/`).
- `bake/`: scripts de Godot que hornean datos (cuerpos, catalogo, navegacion, layout, terreno).
- `audit/`: chequeos (esqueletos, iconos, transforms del layout, `check_original_assets.sh`).
- `material/`: Material Maker por consola.
- `deploy/`: unidad systemd del servidor de salas.
- `move_map/` y `move_map.py`: el mudador de rutas del RFC-048.
- `skeletal_post_import.gd` y `terrain_import.gd` quedan en la raiz: los nombran los `.import` de `assets/`.

Agregar uno: en la carpeta que corresponda; los `.py` calculan `ROOT` con `Path(__file__).resolve().parents[2]`, los `.sh` con `dirname "$0")/../..`.
