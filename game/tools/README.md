# tools/

Herramientas de desarrollo, nunca parte del juego (el export las excluye).
- `import/`: Python que lee los datos originales y escribe `assets/original/` (`import_*.py`, `export_*.py`, `sac_formats/`). **Requiere el juego original instalado (`SAC_INSTALL`)**, salvo `scaffold_map.py`, `classify_ground_tiles.py` y `sample_grass_palette.py`; ver `import/local.cfg.example` y «Herramientas que necesitan el juego original» en `docs/HOWTO.md`.
- `bake/`: scripts de Godot que hornean datos (cuerpos, catalogo, navegacion, layout, terreno). No necesitan el juego original (usan lo ya importado en `assets/original`).
- `audit/`: chequeos (esqueletos, iconos, transforms del layout; `check_original_assets.sh` SI requiere el juego original). `check_map.tscn -- [--map=<tag>]` valida un mapa o todos: los asientos, que inicios, altares, manantiales y edificios esten sobre tierra, que cada `GroundFootprint` este a nivel (dispersion <= 0,5 m, sin vacios) y que cada altar llegue caminando a cada manantial por el `nav.res`; imprime `CHECK MAP <tag> PASS/FAIL` y sale con 0 o 1.
- `migrate/`: Python portable (sin Godot ni el juego original) que cambia datos del repo. `rename_resources.py` renombra `.tres` a nombres humanos con `git mv` y reescribe cada referencia (ensayo por defecto, `--apply` escribe, falla si queda una ruta vieja); `--from-display-name <carpeta> --with <carpeta compañera>`.
- `material/`: Material Maker por consola.
- `deploy/`: unidad systemd del servidor de salas.
- `move_map/` y `move_map.py`: el mudador de rutas del RFC-048.
- `skeletal_post_import.gd` y `terrain_import.gd` quedan en la raiz: los nombran los `.import` de `assets/`.
- `blender/`: scripts de Blender por consola (`make_test_creature.py`).

Agregar uno: en la carpeta que corresponda; los `.py` calculan `ROOT` con `Path(__file__).resolve().parents[2]`, los `.sh` con `dirname "$0")/../..`.
