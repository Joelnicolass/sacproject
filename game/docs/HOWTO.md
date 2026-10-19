# Cómo agregar y cambiar cosas

Guía corta. Todas las rutas son desde `game/`. Regla general: el contenido son `.tres` en `data/` (un archivo por tipo, se edita en el inspector) y el comportamiento son escenas y nodos en `scenes/<dominio>/`. Nada de `match tag` en código. Cada carpeta tiene su `README.md`.

Después de cualquier cambio de contenido, corré el validador (último apartado).

## Una criatura

1. Duplicá un hermano en `data/catalog/creatures/` (por ejemplo `ahcr.tres`) y llamalo `<tag>.tres`. El nombre del archivo es el `tag`.
2. En el inspector: `tag`, `display_name`, `god`, `model` (el tag del modelo de `assets/original/models/<model>.glb`), vida, velocidad, resistencias, `ability_tags` y las animaciones.
3. El tamaño del cuerpo va en `data/catalog/body_sizes/<model>.tres` (`BodySize`: caja, `height`, `radius`, `reach`). Si el modelo ya lo usa otra criatura, ya existe.
4. La escena del modelo es `scenes/bodies/models/<model>.tscn`. Si falta, hornéala: **Project > Tools > Sacrifice: Hornear modelos que faltan** (o `tools/bake/bake_body_scenes.gd`). Solo escribe los que faltan; lo que ya editaste no se pisa. Ahí se cambia qué clip toca cada rol (`AnimationTree`).
5. Para que el jugador la pueda convocar, ponela en el libro del dios: `data/gods/<dios>.tres` → `book` → `creatures` (y una línea en `unlocks` con el nivel de mago en que entra).
6. Las habilidades: `ability_tags` apunta a `data/catalog/abilities/`; la lógica de cada una es un nodo en `scenes/units/abilities/`.

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

Pendiente: lo está dejando listo el RFC-044 (separar `high_noon.tscn` en partida y mapa). Cuando cierre, esta sección dice qué escena duplicar, qué nodos lleva (terreno, edificios, `NpcSpawns`, navegación) y cómo se hornea el navmesh. Mientras tanto: `rfcs/RFC-044-*.md` y `scenes/map/README.md`.

## Cambiar el balance

- **Una criatura, un hechizo, un mago, un edificio:** abrí su `.tres` en `data/catalog/<tipo>/` y cambiá el número en el inspector. No hay JSON ni tabla aparte; el juego lee el archivo.
- **Reglas de la partida** (duración, fuego amigo, topes): `data/match_rules.tres` (`MatchRules`).
- **IA y dificultad:** `data/ai/`.
- **Calidad gráfica:** `data/look/quality_*.tres`.
- No se muta un `.tres` en runtime. Después de tocar números, el banco de determinismo va a cambiar de huella a propósito: `agent/det_baseline.txt` es la línea base: regrabala solo si el cambio de balance es lo que querías (`agent/README.md`).

## Correr las pruebas y el validador

Todo se corre desde `game/` y de a un Godot por vez (la cola es `agent/harness/godot_run.sh`).

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot

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
