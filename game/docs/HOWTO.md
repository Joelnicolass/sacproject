# Cómo agregar y cambiar cosas

Guía corta. Todas las rutas son desde `game/`. Regla general: el contenido son `.tres` en `data/` (un archivo por tipo, se edita en el inspector) y el comportamiento son escenas y nodos en `scenes/<dominio>/`. Nada de `match tag` en código. Cada carpeta tiene su `README.md`.

Después de cualquier cambio de contenido, corré el validador (último apartado).

## Una criatura

Para una criatura que no existe en el original, andá directo a «Crear una criatura propia desde Blender». Estos pasos son para las del catálogo.

1. Duplicá un hermano en `data/catalog/creatures/` (por ejemplo `ahcr.tres`) y llamalo `<tag>.tres`. El nombre del archivo es el `tag`.
2. En el inspector: `tag`, `display_name`, `god`, `model` (el tag del modelo de `assets/original/models/<model>.glb`), vida, velocidad, resistencias, `ability_tags` y las animaciones.
3. El tamaño del cuerpo va en `data/catalog/body_sizes/<model>.tres` (`BodySize`: caja, `height`, `radius`, `reach`). Si el modelo ya lo usa otra criatura, ya existe.
4. La escena del modelo es `scenes/bodies/models/<model>.tscn`. Si falta, hornéala: **Project > Tools > Sacrifice: Hornear modelos que faltan** (o `tools/bake/bake_body_scenes.gd`). Solo escribe los que faltan; lo que ya editaste no se pisa. Ahí se cambia qué clip toca cada rol (`AnimationTree`).
5. Para que el jugador la pueda convocar, ponela en el libro del dios: `data/gods/<dios>.tres` → `book` → `creatures` (y una línea en `unlocks` con el nivel de mago en que entra).
6. Las habilidades: `ability_tags` apunta a `data/catalog/abilities/`; la lógica de cada una es un nodo en `scenes/units/abilities/`.

## Crear una criatura propia desde Blender

Un enemigo o personaje nuevo no necesita nada del juego original (ni `index.json` ni los WAD): sale de un `.glb`.

1. **Modelar y animar.** Una armature con el mesh skinneado y **una acción por animación**, nombradas por rol (mayúsculas, separadores y el `.001` de Blender no importan):
   `idle` (obligatoria), `run` (o `walk`), `attack`, `shoot`, `cast`, `hit`, `death`, `fly`, `takeoff`, `land`, `hover`, `knock`, `get_up`. Un rol sin clip se resuelve solo (`walk`→`run`, `shoot`→`attack`, `hit` y lo que falte→`idle`; sin `death` el cuerpo cae con un Tween).
   El **momento del golpe** va en el nombre: `attack_at45` = al 45 % del clip, `attack_f18` = en el cuadro 18; sin marca es la mitad (50 %). (Blender no exporta marcadores a glTF.) Hacé que mire hacia **-Y** en Blender (queda hacia +Z, como el juego) y que los pies estén en Z = 0.
2. **Exportar** a `game/assets/custom/models/<tag>.glb` (File > Export > glTF 2.0, formato GLB, *Animation* > modo **Actions**; el nombre del archivo es el `tag`: minúsculas, sin espacios). Abrí el proyecto en el editor una vez (o `$G --headless --path . --import`) para que Godot lo importe. Ejemplo completo: `tools/blender/make_test_creature.py`.
3. **Crear la criatura**: **Project > Tools > Sacrifice: Nueva criatura desde modelo…** y elegí el `.glb`; o por consola:
   ```bash
   $G --headless --path . --script res://tools/bake/new_creature.gd -- <tag> --name="Nombre" --god=pyro
   ```
   Escribe tres archivos y **no pisa ninguno que exista** (`--force` rehace los tres): `scenes/bodies/models/<tag>.tscn` (el modelo con su `AnimationTree` y el evento del golpe), `data/catalog/body_sizes/<tag>.tres` (caja, alto, radio y alcance medidos del mesh) y `data/catalog/creatures/<tag>.tres` (stats de `data/templates/creature.tres` más los datos de los clips). Imprime qué clip tomó cada rol y cuáles no usó.
4. **Ajustar en el inspector.** Stats, costo de maná y almas, `display_name` en el `.tres` de la criatura; tamaño en el `body_sizes` (`reach` es hasta dónde llega el golpe). Qué clip toca cada rol: los estados del `AnimationTree` de la escena del modelo (si cambiás el clip de un estado, poné su `timeline_length` en los segundos del clip nuevo); el cuadro del golpe: la tecla `attack` de la animación del reproductor `Events`. Si tocaste roles o el golpe, **Project > Tools > Sacrifice: Sincronizar criatura con su modelo…** (o `new_creature.gd -- <tag> --sync`) vuelve a leer la escena y actualiza los tiempos que usan las reglas (golpe, disparo, aturdimiento, vuelo); tus stats no se tocan.
5. **Ponerla en un libro**: `data/gods/<dios>.tres` → `book` → `creatures` (arrastrá el `.tres`) y una línea en `unlocks` con el nivel de mago. Corré el validador: `CATALOG PASS` (también avisa si un clip nombrado no existe en el `.glb`).

Prueba de punta a punta (criatura de Blender, convocada, camina, pega en el golpe y muere): `$G --headless --fixed-fps 60 --path . res://debug/units/custom_creature.tscn` imprime `CUSTOM_CREATURE PASS`.

## Un hechizo

Un hechizo son dos cosas: el dato y, si tiene procedimiento propio, una escena.

1. **Dato.** Duplicá un `SpellType` de `data/catalog/spells/` como `<tag>.tres` (maná, alcance, enfriamiento, tiempo de lanzamiento, daño). Ponelo en `book` → `spells` del dios (o `structures` si es una estructura).
2. **Acción.** Si el hechizo hace algo más que el lanzamiento común, creá una escena en `scenes/spells/actions/` con un script que extienda `SpellAction` (o `AimedAction` para un golpe a un cuerpo bajo el cursor). Completá `tag` (el del `SpellType`), `pick` (suelo, criatura propia, alma, edificio propio) y `prompt` en el inspector; el editor avisa si falta algo.
3. **Registro.** Instanciá la escena como hijo de `Caster/Actions` en `scenes/wizards/wizard_body.tscn`. Sacar el nodo apaga el hechizo («No implementado» en el libro).
4. Los efectos visuales se piden por nombre a `FxBus` (ver «Un FX»).

## Un dios

1. Duplicá `data/gods/pyro.tres` como `<dios>.tres` (`GodType`): `tag`, `display_name`, `sort_order`, y los `.tres` de tema (`data/themes`), look (`data/look`) y FX de lanzamiento (`data/fx`).
2. `ai_profile`: un `AiProfile` de `data/ai/` (duplicá `profile_pyro.tres`).
3. `book`: un `GodBook` con `creatures`, `spells`, `structures` y `unlocks`. Son referencias a los `.tres` de `data/catalog/`: agregar algo al libro es arrastrarlo a la lista.
4. El selector de personaje y el catálogo lo levantan solos (`GameData`).

## Un edificio

- **Tipo.** `data/catalog/buildings/<tag>.tres` (`BuildingType`: componentes, vida máxima, si da refugio). Se hornea desde los datos originales con `tools/bake/bake_catalog.gd`; uno nuevo se puede duplicar a mano.
- **En el mapa.** Instanciá `scenes/map/map_building.tscn` bajo los edificios de la escena del mapa y arrastrá el `.tres` a `building`. Movelo y rotalo con el gizmo: el transform es la verdad y el modelo se ve en el editor. Con `max_health` 0 es indestructible.
- **Como hechizo de estructura** (el Manalith): es un `SpellType` en `structures` del libro más una acción en `Caster/Actions`; el cuerpo es `scenes/structures/structure.tscn`.

## Un NPC

1. Instanciá `scenes/map/npc_spawn.tscn` bajo `NpcSpawns` de la escena del mapa.
2. Arrastrá la criatura (`data/catalog/creatures/<tag>.tres`) a `creature` y poné `side`. La posición del marcador es donde nace; el giro del transform es hacia dónde mira.
3. `MapPopulation` los convierte en unidades al empezar la partida (en el servidor o en solitario).

## Un FX

- **Partículas.** Un `ParticleType` en `data/fx/<nombre>.tres` (atlas, cuadros, tamaño, vida, gravedad, cantidad). Se toca con `FxBus.play("<nombre>", posición)`; el nombre es el del archivo.
- **Rayo.** Un `BeamType` en `data/fx/beams/` y `FxBus.play_beam(...)`.
- **Algo con forma propia** (anillos, púas, portal): una packed scene en `scenes/fx/` con su shader, y `FxBus.play_scene(ruta, posición, parámetros)`. Un efecto, una escena, un shader.
- Luces del efecto: `data/fx/lights/`.

## Un mapa

Un mapa es una carpeta `scenes/map/maps/<tag>/` con su `map.tscn` (raíz `MapRoot`), su `MapDefinition` `<tag>.tres`, el `layout.tscn` (edificios, plantas, NPC) y el `nav.res`; sus datos del original van en `assets/original/maps/<tag>/`. `data/maps/map_catalog.tres` lo lista y `--map=<tag>` lo elige. Más en `scenes/map/README.md`.

**Importar uno del original** (RFC-050; la lista de los 31 con asientos y tamaño: `python3 tools/import/import_map.py --list`). Desde `game/`. **Requiere el juego original instalado** (`SAC_INSTALL`, ver «Configurar rutas» abajo): `import_map.py` e `import_themes.py` lo leen; `scaffold_map.py` no. `G` es el binario de Godot y `<Nombre>` el del `.scp` sin el `(N)`, por ejemplo `Peaks` o `WinterWonder` (el tag sale solo: `winter_wonder`).

```bash
G="${GODOT_BIN:-godot}"   # ver «Configurar rutas» abajo
python3 tools/import/import_map.py --map=<Nombre> --terrain-bin=/tmp/<tag>.bin   # tiles, luz, ntts, widgets + el bin del terreno
python3 tools/import/scaffold_map.py --map=<Nombre>                              # sides, MapDefinition, map.tscn, catálogo
python3 tools/import/import_themes.py                                            # suma los ids de baldosa del mapa a los atlas de los otros dioses
bash agent/harness/godot_run.sh $G --headless --path . --script res://tools/bake/import_terrain.gd -- --map=<tag> --bin=/tmp/<tag>.bin
bash agent/harness/godot_run.sh $G --headless --path . --import                  # importa tiles.png (lo lee el glb)
bash agent/harness/godot_run.sh $G --headless --path . --script res://tools/bake/terrain_glb_export.gd -- --map=<tag> --force
bash agent/harness/godot_run.sh $G --headless --path . --script res://tools/bake/bake_map_layout.gd -- --map=<tag> --force
bash agent/harness/godot_run.sh $G --headless --path . --import                  # una vez más: terrain.glb y layout.tscn
bash agent/harness/godot_run.sh $G --headless --path . res://tools/bake/bake_nav.tscn -- --map=<tag>
bash agent/harness/godot_run.sh $G --headless --path . res://tools/bake/bake_nav.tscn -- --map=<tag> --check   # dos veces
bash agent/harness/godot_run.sh $G --headless --path . res://tools/audit/check_map_starts.tscn -- --map=<tag>  # los inicios caen en tierra y en una misma región
bash agent/runs/run_050_maps.sh <tag>                                            # humo: IA contra IA 0,5 min
```

Después de importar, `map.tscn` y `<tag>.tres` se editan a mano (la escena es la verdad). Ojo con `--force`: pisa lo editado. Las plantas de un mapa que no es de James quedan vacías hasta tener los modelos de sus widgets. `room_selectable = false` en la definición lo saca de las salas.

**Hacer uno a mano:** copiá `scenes/map/maps/test_flat/` y armá el terreno en Blender (`terrain.glb`).

## Cambiar el balance

- **Una criatura, un hechizo, un mago, un edificio:** abrí su `.tres` en `data/catalog/<tipo>/` y cambiá el número en el inspector. No hay JSON ni tabla aparte; el juego lee el archivo.
- **Reglas de la partida** (duración, fuego amigo, topes): `data/match_rules.tres` (`MatchRules`).
- **IA y dificultad:** `data/ai/`.
- **Calidad gráfica:** `data/look/quality_*.tres`.
- No se muta un `.tres` en runtime. Después de tocar números, el banco de determinismo va a cambiar de huella a propósito: `agent/det_baseline.txt` es la línea base: regrabala solo si el cambio de balance es lo que querías (`agent/README.md`).

## Correr las pruebas y el validador

Todo se corre desde `game/` y de a un Godot por vez (la cola es `agent/harness/godot_run.sh`).

```bash
G="${GODOT_BIN:-godot}"   # ver «Configurar rutas» abajo

# Validador del catálogo: imprime CATALOG PASS o CATALOG FAIL con el archivo que falla
bash agent/harness/godot_run.sh $G --headless --path . --script res://debug/suite/catalog_cases.gd

# Reglas, sin ventana
bash agent/harness/godot_run.sh $G --headless --fixed-fps 600 --path . res://debug/suite/rules_suite.tscn

# Banco de determinismo rápido, contra agent/det_baseline.txt
bash agent/run_determinism.sh quick --no-window
```

Desde el editor, **Project > Tools > Sacrifice** corre el validador, re-hornea el navmesh y hornea los modelos que faltan, y muestra la salida en un diálogo. El minimapa tiene un botón «Re-hornear minimapa» en el inspector de `MinimapTerrainBake`.

Los horneados por consola (sin `--force` no pisan lo editado a mano):

```bash
$G --headless --path . --script res://tools/bake/bake_body_scenes.gd        # solo los que faltan
$G --headless --path . --script res://tools/bake/bake_body_scenes.gd -- --force   # rehace todos (pisa tus cambios)
$G --headless --path . res://tools/bake/bake_nav.tscn                      # navmesh
```

Una prueba nueva va en `debug/<dominio>/` (y en `agent/det_cases.txt` si es un caso del banco).

## Herramientas que necesitan el juego original

Las rutas son relativas a `game/`.

| Herramienta | ¿Necesita el original? | Qué produce |
|---|---|---|
| Jugar (F5), `godot --path game`, el servidor de salas | **No** | Nada: los assets ya están en `game/assets/original/` (LFS) |
| Pruebas: `agent/run_determinism.sh`, `rules_suite`, `agent/runs/*.sh`, flows de AgentKit | **No** | PASS/FAIL, capturas en `agent/out/` |
| `tools/import/export_stats.py` | **Sí** | `assets/original/data/*.json` (estadísticas de criaturas, hechizos, magos, edificios) |
| `tools/import/export_skeletal.py` | **Sí** | `assets/original/models/*.glb` + `index.json` (esqueleto y animaciones) |
| `tools/import/export_skeletal_reference.py` | **Sí** | OBJ de referencia en `agent/out/skeletal_ref/` (no se versiona) |
| `tools/import/import_textures.py` | **Sí** | `assets/original/textures/*.png` |
| `tools/import/import_props.py` | **Sí** | `assets/original/props/*.glb` (edificios y plantas) |
| `tools/import/import_themes.py` | **Sí** | `assets/original/themes/<dios>/` (suelo, cielo, luz) |
| `tools/import/import_ui.py` | **Sí** | `assets/original/ui/` y `assets/original/fx/` (HUD, iconos, cursores, partículas) |
| `tools/import/import_map.py` (incluye `--list`) | **Sí** | `assets/original/maps/<tag>/` (tiles, luz, entidades, terreno) |
| `tools/audit/check_original_assets.sh` | **Sí** | Paridad de `assets/original/` con el original (`ASSETS PARITY PASS/FAIL`) |
| `tools/import/scaffold_map.py` | No: usa lo que ya dejó `import_map.py` | `sides.tres`, `MapDefinition`, `map.tscn`, entrada del catálogo |
| `tools/import/classify_ground_tiles.py`, `sample_grass_palette.py` | No: usan `assets/original/` | `high_noon_tiles.tres`, paleta de pasto propuesta |
| `tools/bake/*` (navmesh, catálogo, `bake_body_scenes`, `new_creature`, terreno) | No: `bake_body_scenes` usa los `.glb` y `index.json` del repo; `import_terrain.gd` lee el `.bin` que escribe `import_map.py` | Escenas, `.tres` y navmesh |
| Menú **Project > Tools > Sacrifice** | Solo «Listar mapas del original» (lleva «(requiere juego original)» en el menú) | Salida en un diálogo |

Estas herramientas leen los `.wad` y los `.scp` del juego instalado; **el original no viene en el repo** (es el juego comercial). Si falta, imprimen un mensaje en español que explica qué carpeta hace falta y cómo indicarla, y terminan con error. Todas empiezan su encabezado y su `--help` con «Requiere el juego original instalado (SAC_INSTALL)» o con «No necesita el juego original».

### Configurar rutas

**El juego original** (solo para las herramientas de la tabla de arriba). Hace falta la carpeta que contiene los `.wad` (por ejemplo `spells.wad`, `models.wad`, `main.wad`), normalmente llamada `data`, con la carpeta `maps/` (los `.scp`) al lado. Se busca en este orden, sin ninguna ruta por defecto:

1. Variable de entorno `SAC_INSTALL` (la carpeta con los `.wad`) o `SAC_ROOT` (la raíz del juego, la que tiene `data/` y `maps/`). `SAC_MAPS` es opcional si `maps/` está en otro lado.
2. Archivo `game/tools/import/local.cfg` (no se versiona): copiá `local.cfg.example` y completá `SAC_INSTALL=`.
3. Desde el editor de Godot: **Editor > Editor Settings > sacrifice > original_install_path**. El plugin «Sacrifice» la pasa como `SAC_INSTALL` a los procesos que lanza.

Lugares típicos de la instalación: GOG en Windows (`C:\GOG Games\Sacrifice\data`), Steam en Windows (`...\steamapps\common\Sacrifice\data`), y en macOS o Linux la carpeta `drive_c/.../Sacrifice/data` dentro del prefijo de Wine o de la botella de CrossOver. Se valida que la carpeta tenga `spells.wad`, `models.wad` y `main.wad`.

```bash
export SAC_INSTALL="/ruta/a/Sacrifice/data"
cd game && python3 tools/import/import_map.py --list
```

**Godot y Blender** (los scripts de `game/agent/` y `game/tools/`). Todos leen `agent/harness/env.sh`, que calcula la raíz del proyecto desde su propia ubicación y elige:

- `GODOT_BIN`: la variable de entorno si está; si no, `godot` del `PATH`; si no, el de macOS (`/Applications/Godot.app/Contents/MacOS/Godot`).
- `BLENDER_BIN`: la variable de entorno si está; si no, `blender` del `PATH`; si no, el de macOS (`/Applications/Blender.app/Contents/MacOS/Blender`).

```bash
export GODOT_BIN="/ruta/a/Godot_v4.7.2"   # opcional si godot está en el PATH
export BLENDER_BIN="/ruta/a/blender"      # solo para tools/blender/ y la criatura propia desde Blender
```
