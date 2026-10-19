# tools/

Herramientas de desarrollo, nunca parte del juego (el export las excluye).
- `import/`: Python que lee los datos originales y escribe `assets/original/` (`import_*.py`, `export_*.py`, `sac_formats/`). **Requiere el juego original instalado (`SAC_INSTALL`)**, salvo `scaffold_map.py`, `classify_ground_tiles.py` y `sample_grass_palette.py`; ver `import/local.cfg.example` y «Herramientas que necesitan el juego original» en `docs/HOWTO.md`.
- `bake/`: scripts de Godot que hornean datos (cuerpos, catalogo, navegacion, layout, terreno). No necesitan el juego original (usan lo ya importado en `assets/original`).
- `audit/`: chequeos (esqueletos, iconos, transforms del layout; `check_original_assets.sh` SI requiere el juego original).
- `material/`: Material Maker por consola.
- `deploy/`: unidad systemd del servidor de salas.
- `move_map/` y `move_map.py`: el mudador de rutas del RFC-048.
- `skeletal_post_import.gd` y `terrain_import.gd` quedan en la raiz: los nombran los `.import` de `assets/`.

Agregar uno: en la carpeta que corresponda; los `.py` calculan `ROOT` con `Path(__file__).resolve().parents[2]`, los `.sh` con `dirname "$0")/../..`.
