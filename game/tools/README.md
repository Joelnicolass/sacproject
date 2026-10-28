# tools/

Herramientas de desarrollo, nunca parte del juego (el export las excluye).
- `import/`: Python que lee los datos originales y escribe `assets/original/` (`import_*.py`, `export_*.py`, `sac_formats/`). **Requiere el juego original instalado (`SAC_INSTALL`)**, salvo `scaffold_map.py`, `sample_grass_palette.py`, `measure_ground.py` y `check_ground_roles.py`; ver `import/local.cfg.example` y «Herramientas que necesitan el juego original» en `docs/HOWTO.md`.
- `bake/`: scripts de Godot que hornean datos (cuerpos, catalogo, navegacion, layout, terreno). No necesitan el juego original (usan lo ya importado en `assets/original`).
- `audit/`: chequeos (esqueletos, iconos, transforms del layout; `check_original_assets.sh` SI requiere el juego original). `check_map.tscn -- [--map=<tag>]` valida un mapa o todos: los asientos, que inicios, altares, manantiales y edificios esten sobre tierra, que cada `GroundFootprint` este a nivel (dispersion <= 0,5 m, sin vacios) y que cada altar llegue caminando a cada manantial por el `nav.res`; imprime `CHECK MAP <tag> PASS/FAIL` y sale con 0 o 1. La logica de un mapa es `map_checks.gd` (la usan tambien `terrain_cli --validate` y el boton «Validar mapa» del Terrain).
- `migrate/`: Python portable (sin Godot ni el juego original) que cambia datos del repo. `rename_resources.py` renombra `.tres` a nombres humanos con `git mv` y reescribe cada referencia (ensayo por defecto, `--apply` escribe, falla si queda una ruta vieja); `--from-display-name <carpeta> --with <carpeta compañera>`.
- `deploy/`: guía de despliegue en VPS, planeada para el futuro (el servidor de salas que describe se retiró).
- `material/`: Material Maker por consola.
- `move_map/` y `move_map.py`: el mudador de rutas del RFC-048.
- `skeletal_post_import.gd` queda en la raiz: lo nombran los `.import` de `assets/`.
- `terrain/heights_from_original.gd` (requiere el juego original): escribe el `heights.png` y el `void.png` de un mapa del original, la unica fuente de su suelo.
- `terrain/terrain_cli.tscn` (no necesita el juego original): los botones del inspector de `Terrain` sin editor. `"$GODOT" --headless --path game res://tools/terrain/terrain_cli.tscn -- --map=<tag> (--to-blend | --from-blend [--force] | --flat=<m> | --flatten-bases | --validate)`; `--scene=<res://...tscn>` en lugar de `--map` sirve para cualquier escena de mapa y `--out=<carpeta>` escribe `--flat`/`--flatten-bases` en otro lado. Escribe imagenes pero no las importa: despues, `--import`. `--to-blend`/`--from-blend` necesitan Blender (`BLENDER` o el PATH).
- `blender/`: scripts de Blender por consola (`make_test_creature.py`; el terreno, abajo).
  - **Terreno en Blender** (plan 063D S4, no necesita el juego original). Desde `game/`, con `BLENDER_BIN` (o `blender` en el PATH):
    - Ida, imágenes del mapa → `.blend`: `"$BLENDER_BIN" --background --python tools/blender/terrain_make_blend.py -- --map=scenes/map/maps/<tag>` (o `--flat=<m>` para un suelo plano nuevo). Escribe `scenes/map/maps/<tag>/terrain_work/terrain.blend` (ignorada por git y por Godot). Abrilo en Blender y seguí el texto «README» de adentro: solo mover en Z, no agregar ni borrar vértices, pintar el grupo «void» para hacer huecos.
    - Vuelta, `.blend` → imágenes: `"$BLENDER_BIN" --background scenes/map/maps/<tag>/terrain_work/terrain.blend --python tools/blender/terrain_export_images.py -- --out=scenes/map/maps/<tag>`. Reescribe `heights.png`, `void.png` y `ground_roles.png`. Si algo no cumple las reglas, o las imágenes cambiaron desde la ida (`--force` lo salta), sale con 1, dice por qué y no escribe nada.

Agregar uno: en la carpeta que corresponda; los `.py` calculan `ROOT` con `Path(__file__).resolve().parents[2]`, los `.sh` con `dirname "$0")/../..`.
