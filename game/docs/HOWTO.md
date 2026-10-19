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
   **Variantes de golpe:** hasta tres clips de ataque, `attack`, `attack2`, `attack3` (o `attack_a`, `attack_b`, `attack_c`), cada uno con su propia marca (`attack2_at60`). El juego elige al azar entre `attack` y `attack2` en cada golpe; `attack3` es el golpe hacia abajo (contra un blanco mucho más bajo). Cada golpe reproduce su propio clip y pega en su propio momento. Con solo `attack3` y sin `attack2`, el segundo del par repite `attack`.
   El **momento del golpe** va en el nombre: `attack_at45` = al 45 % del clip, `attack_f18` = en el cuadro 18; sin marca es la mitad (50 %). (Blender no exporta marcadores a glTF.) Hacé que mire hacia **-Y** en Blender (queda hacia +Z, como el juego) y que los pies estén en Z = 0.
2. **Exportar** a `game/assets/custom/models/<tag>.glb` (File > Export > glTF 2.0, formato GLB, *Animation* > modo **Actions**; el nombre del archivo es el `tag`: minúsculas, sin espacios). Abrí el proyecto en el editor una vez (o `$G --headless --path . --import`) para que Godot lo importe. Ejemplo completo: `tools/blender/make_test_creature.py`.
3. **Crear la criatura**: **Project > Tools > Sacrifice: Nueva criatura desde modelo…** y elegí el `.glb`; o por consola:
   ```bash
   $G --headless --path . --script res://tools/bake/new_creature.gd -- <tag> --name="Nombre" --god=pyro
   ```
   Escribe tres archivos y **no pisa ninguno que exista** (`--force` rehace los tres): `scenes/bodies/models/<tag>.tscn` (el modelo con su `AnimationTree` y el evento del golpe), `data/catalog/body_sizes/<tag>.tres` (caja, alto, radio y alcance medidos del mesh) y `data/catalog/creatures/<tag>.tres` (stats de `data/templates/creature.tres` más los datos de los clips). Además dibuja el **icono del HUD** (libro y selección): si existe `assets/custom/icons/<tag>.png` lo usa tal cual (nunca lo pisa; es tuyo, 32×32), si no lo renderiza del modelo (pose de idle, cámara sobre su caja, disco oscuro con aro dorado) y lo guarda ahí. Dibujar necesita ventana: desde el plugin se abre sola un instante; por consola, quitá `--headless` (`--resolution 256x256`) o corré después `$G --path . --script res://tools/bake/creature_icon.gd -- <tag>` (`--force` lo rehace). También podés asignar una textura al campo `icon` de la criatura en el inspector (gana a todo). `--icon` lo redibuja en `new_creature.gd`; `--no-icon` lo salta. Imprime qué clip tomó cada rol y cuáles no usó.
4. **Ajustar en el inspector.** Stats, costo de maná y almas, `display_name` en el `.tres` de la criatura; tamaño en el `body_sizes` (`reach` es hasta dónde llega el golpe). Qué clip toca cada rol: los estados del `AnimationTree` de la escena del modelo (si cambiás el clip de un estado, poné su `timeline_length` en los segundos del clip nuevo); el cuadro del golpe: la tecla `attack` de la animación del reproductor `Events`. Si tocaste roles o el golpe, **Project > Tools > Sacrifice: Sincronizar criatura con su modelo…** (o `new_creature.gd -- <tag> --sync`) vuelve a leer la escena y actualiza los tiempos que usan las reglas (golpe, disparo, aturdimiento, vuelo); tus stats no se tocan.
5. **Ponerla en un libro**: `data/gods/<dios>.tres` → `book` → `creatures` (arrastrá el `.tres`) y una línea en `unlocks` con el nivel de mago. Corré el validador: `CATALOG PASS` (también avisa si un clip nombrado no existe en el `.glb`).

Prueba de punta a punta (criatura de Blender, convocada, camina, pega en el golpe y muere): `$G --headless --fixed-fps 600 --path . res://debug/units/custom_creature.tscn` imprime `CUSTOM_CREATURE PASS` (cuenta qué variante de golpe usó cada swing y cuándo cayó, y mira el icono).

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

**Importar uno del original** (RFC-050; la lista de los 31 con asientos y tamaño: `python3 tools/import/import_map.py --list`). Desde `game/`, con la instalación local; `G` es el binario de Godot y `<Nombre>` el del `.scp` sin el `(N)`, por ejemplo `Peaks` o `WinterWonder` (el tag sale solo: `winter_wonder`).

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
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
