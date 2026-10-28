[English](HOWTO.en.md) | **Español**

# Cómo agregar y cambiar cosas

Guía corta. Todas las rutas son desde `game/`. Regla general: el contenido son `.tres` en `data/` (un archivo por tipo, se edita en el inspector) y el comportamiento son escenas y nodos en `scenes/<dominio>/`. Nada de `match tag` en código. Cada carpeta tiene su `README.md`.

## Una criatura

Para una criatura que no existe en el original, andá directo a «Crear una criatura propia desde Blender». Estos pasos son para las del catálogo.

1. Duplicá un hermano en `data/catalog/creatures/` (por ejemplo `sylph.tres`) y llamalo con el nombre de tu criatura (`mi_bicho.tres`). El `tag` queda vacío: el id es el nombre del archivo.
2. En el inspector: `tag`, `display_name`, `model` (el tag del modelo de `assets/original/models/<model>.glb`), vida, velocidad, resistencias, el grupo `Abilities` y las animaciones.
3. El tamaño del cuerpo va en la escena `scenes/units/bodies/<tag>.tscn` (`BodyFrame`: `Bounds/Capsule`, `Bounds/Footprint` y los marcadores `Sockets/`, entre ellos `Reach`). Si el modelo ya lo usa otra criatura, ya existe.
4. La escena del modelo es `scenes/bodies/models/<model>.tscn`. Si falta, hornéala: **Project > Tools > Sacrifice: Hornear modelos que faltan** (o `tools/bake/bake_body_scenes.gd`). Solo escribe los que faltan; lo que ya editaste no se pisa. Ahí se cambia qué clip toca cada rol (`AnimationTree`).
5. Para que el jugador la pueda convocar, ponela en el libro del dios: `data/gods/<dios>.tres` → `book` → `creatures` (y una línea en `unlocks` con el nivel de mago en que entra).
6. Las habilidades: en el grupo `Abilities` arrastrás el `.tres` de `data/catalog/abilities/` a `ranged_attack`, `active_ability` y `on_damage`, y las nubes o golpes con efecto de `data/death_clouds/` y `data/passives/` a `passives`; la lógica de cada una es un nodo en `scenes/units/abilities/`.

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
   Escribe tres archivos y **no pisa ninguno que exista** (`--force` rehace los tres): `scenes/bodies/models/<tag>.tscn` (el modelo con su `AnimationTree` y el evento del golpe), `scenes/units/bodies/<tag>.tscn` y `<tag>_look.tscn` (el cuerpo con la cápsula, la huella y los sockets medidos del mesh, y su apariencia) y `data/catalog/creatures/<tag>.tres` (stats de `data/templates/creature.tres` más los datos de los clips). Además dibuja el **icono del HUD** (libro y selección): si existe `assets/custom/icons/<tag>.png` lo usa tal cual (nunca lo pisa; es tuyo, 32×32), si no lo renderiza del modelo (pose de idle, cámara sobre su caja, disco oscuro con aro dorado) y lo guarda ahí. Dibujar necesita ventana: desde el plugin se abre sola un instante; por consola, quitá `--headless` (`--resolution 256x256`) o corré después `$G --path . --script res://tools/bake/creature_icon.gd -- <tag>` (`--force` lo rehace). También podés asignar una textura al campo `icon` de la criatura en el inspector (gana a todo). `--icon` lo redibuja en `new_creature.gd`; `--no-icon` lo salta. Imprime qué clip tomó cada rol y cuáles no usó.
4. **Ajustar en el inspector.** Stats, costo de maná y almas, `display_name` en el `.tres` de la criatura; tamaño en la escena del cuerpo (arrastrá `Sockets/Reach`: es hasta dónde llega el golpe). Qué clip toca cada rol: la biblioteca `<tag>_clips.tres` del modelo (nodo `Clips` de su escena; un estado del `AnimationTree` reproduce la animación de su rol, y la duración sale de la animación); el cuadro del golpe: el marcador `hit` de esa animación (y la llamada `attack` de su pista de métodos). Si tocaste roles o el golpe, **Project > Tools > Sacrifice: Sincronizar criatura con su modelo…** (o `new_creature.gd -- <tag> --sync`) vuelve a leer la escena y actualiza los tiempos que usan las reglas (golpe, disparo, aturdimiento, vuelo); tus stats no se tocan.
5. **Ponerla en un libro**: `data/gods/<dios>.tres` → `book` → `creatures` (arrastrá el `.tres`) y una línea en `unlocks` con el nivel de mago.
6. **Sonidos** (opcional): dejá `death_1.wav`, `swing_1.wav`… en `assets/custom/sounds/creatures/<tag>/` antes del paso 3, o después con «Hornear sonidos». Ver «Sonidos propios».

## Sonidos propios

No necesitan nada del juego original. Funcionan para cualquier criatura (también una tuya de Blender), mago o set.

1. **Dejá los archivos** (`.ogg` o `.wav`) en `assets/custom/sounds/creatures/<nombre>/<evento>[_n].ogg`. Por ejemplo, `assets/custom/sounds/creatures/mibicho/death_1.wav` y `swing_1.wav`. Cada archivo del mismo evento es una variante (`death_1`, `death_2`…), y el juego elige una al azar.
2. **Nombres de evento** (son los campos de `SoundSet`, `scenes/audio/sound_set.gd`):
   - Criatura: `summon` (al invocarla; vacío usa el de todas), `swing` (golpe), `shoot` (disparo; un `swing` sin `shoot` suena también al disparar), `damaged` (recibe daño), `death`, `selected` (la elegís), `ack` (acusa moverse), `attack_ack` (acusa atacar), `annoyed` (la elegiste muchas veces).
   - Mago: `incantation` (lanza), `damaged`, `death`, `ghost` (se levanta como fantasma).
   - `selected`, `ack`, `attack_ack`, `annoyed` e `incantation` van al bus `Voice`; el resto, a `SFX`. Un nombre que no es un campo se salta y la herramienta avisa.
3. **Crear el set:** **Project > Tools > Sacrifice: Nueva criatura desde modelo…** escribe `data/audio/creatures/<nombre>.tres` (los archivos de la carpeta en sus campos; sobre el set de golpes `melee/fist.tres`) y lo asigna al campo `Sounds` de la criatura. No pisa uno que exista: `--force` lo rehace y pierde lo que editaste. Sin carpeta de sonidos el set queda vacío: arrastrá los archivos a sus campos.
4. **Revisar:** abrí el `.tres` en el inspector. Hay un cue por evento, y ▶ en un stream lo toca. Ahí se ajustan volumen, `cooldown_s` y `max_voices`.

Más detalle (sonidos de FX, música y ambiente por dios): `data/audio/README.md`.

## Un hechizo

Un hechizo son dos cosas: el dato y, si tiene procedimiento propio, una escena.

1. **Dato.** Duplicá un `SpellType` de `data/catalog/spells/` como `<tag>.tres` (maná, alcance, enfriamiento, tiempo de lanzamiento, daño). Ponelo en `book` → `spells` del dios (o `structures` si es una estructura).
2. **Acción.** Si el hechizo hace algo más que el lanzamiento común, creá una escena en `scenes/spells/actions/` con un script que extienda `SpellAction` (para un golpe a un cuerpo bajo el cursor, un `SpellTarget` embebido y `aim_at_body`). Completá `tag` (el del `SpellType`), `pick` (suelo, criatura propia, alma, edificio propio) y `prompt` en el inspector; el editor avisa si falta algo.
3. **Registro.** Instanciá la escena como hijo de `Caster/Actions` en `scenes/wizards/wizard_body.tscn`. Sacar el nodo apaga el hechizo («No implementado» en el libro).
4. Los efectos visuales se piden por nombre a `FxBus` (ver «Un FX»).

## Un dios

1. Duplicá `data/gods/pyro.tres` como `<dios>.tres` (`GodType`): `tag`, `display_name`, `sort_order`, y los `.tres` de tema (`data/themes`), look (`data/look`) y FX de lanzamiento (`data/fx`).
2. `ai_profile`: un `AiProfile` de `data/ai/` (duplicá `profile_pyro.tres`).
3. `book`: un `GodBook` con `creatures`, `spells`, `structures` y `unlocks`. Son referencias a los `.tres` de `data/catalog/`: agregar algo al libro es arrastrarlo a la lista.
4. El selector de personaje y el catálogo lo levantan solos (`GameData`).

## Un edificio

- **Tipo.** `data/buildings/<nombre>.tres` (`BuildingType`: nombre, vida máxima, si da refugio y la ruina). La escena del mismo nombre en `scenes/structures/buildings/` es el edificio que se arrastra al mapa (raíz `MapBuilding`, partes guardadas bajo `Visuals`). Uno nuevo se hace duplicando un `.tres` y su escena; «Ajustar a las partes» (en la raíz) mide la caja que encierra las partes, que también se arrastra con los tiradores de `Collision`.
- **En el mapa.** Arrastrá `scenes/structures/buildings/<nombre>.tscn` bajo `Buildings` en la escena del mapa. Movelo y rotalo con el gizmo: el transform es la verdad y el modelo se ve en el editor; con «Hijos editables» ves y movés las partes de esa instancia. Con `max_health` 0 es indestructible.
- **Como hechizo de estructura** (Manalith, Shrine): el `SpellType` va en `structures` del libro y una fila `GodStructure` (hechizo + escena) en `GodType.structures`; la acción es un `StructureAction` con ese `tag` bajo `Caster/Actions`; el edificio es una escena de `buildings/` que instancia `towers/tower.tscn` (o `shrine_tower.tscn`) y se agrega a `StructureSpawner.scenes` en `match.tscn`.

## Un NPC

1. Instanciá `scenes/map/npc_spawn.tscn` bajo `Npcs` de la escena del mapa.
2. Arrastrá la criatura (`data/catalog/creatures/<tag>.tres`) a `creature` y poné `side` (el bando sin jugador: los asientos son los bandos 0..N-1). La posición del marcador es donde nace; el giro del transform es hacia dónde mira; en el editor ves un fantasma de la criatura.
3. `MapPopulation` los convierte en unidades al empezar la partida (en el servidor o en solitario).

## Un FX

- **Partículas.** Un `ParticleType` en `data/fx/<nombre>.tres` (atlas, cuadros, tamaño, vida, gravedad, cantidad). Se toca con `FxBus.play("<nombre>", posición)`; el nombre es el del archivo.
- **Rayo.** Un `BeamType` en `data/fx/beams/` y `FxBus.play_beam(...)`.
- **Algo con forma propia** (anillos, púas, portal): una packed scene en `scenes/fx/` con su shader, y `FxBus.play_scene(ruta, posición, parámetros)`. Un efecto, una escena, un shader.
- Luces del efecto: `data/fx/lights/`.

## Un mapa

Un mapa es una carpeta `scenes/map/maps/<tag>/` con su `map.tscn` (raíz `MapRoot`), su `MapDefinition` `<tag>.tres` (escena, terreno, luz y navmesh, tipados) y el `nav.res`; los edificios y los NPC son nodos de `map.tscn` (`Buildings`, `Npcs`); sus datos del original van en `assets/original/maps/<tag>/`. `MapCatalog` encuentra la carpeta sola y `--map=<tag>` la elige. Más en `scenes/map/README.md`.

**Importar uno del original** (RFC-050; la lista de los 31 con asientos y tamaño: `python3 tools/import/import_map.py --list`). Desde `game/`. **Requiere el juego original instalado** (`SAC_INSTALL`, ver «Configurar rutas» abajo): `import_map.py` y `bake_ground_roles.py` lo leen; `scaffold_map.py` no. `G` es el binario de Godot y `<Nombre>` el del `.scp` sin el `(N)`, por ejemplo `Peaks` o `WinterWonder` (el tag sale solo: `winter_wonder`).

```bash
G="${GODOT_BIN:-godot}"   # ver «Configurar rutas» abajo
python3 tools/import/import_map.py --map=<Nombre>                                # luz, ntts, widgets
python3 tools/import/scaffold_map.py --map=<Nombre>                              # MapDefinition, map.tscn (inicios con su WizardSpot, una instancia de terrain.tscn), heights.png plano, nav.res vacío
python3 -I tools/import/bake_ground_roles.py                                     # ground_roles.png: qué suelo (abierto, tierra, roca, camino) hay en cada celda
$G --headless --path . --script res://tools/terrain/heights_from_original.gd -- --map=<tag> --scp="<archivo .scp>"   # el suelo del original: heights.png + void.png
$G --headless --path . --import                  # importa heights.png, ground_roles.png y light.png
$G --headless --path . res://tools/bake/bake_nav.tscn -- --map=<tag>
$G --headless --path . res://tools/bake/bake_nav.tscn -- --map=<tag> --check   # dos veces
$G --headless --path . res://tools/audit/check_map.tscn -- --map=<tag>  # asientos, objetos sobre tierra, bases a nivel, caminos altar->manantial (sin --map: todos)
```

Después de importar, `map.tscn` y `<tag>.tres` se editan a mano (la escena es la verdad). Ojo con `--force`: pisa lo editado. Las plantas de un mapa que no es de James quedan vacías hasta tener los modelos de sus widgets. `room_selectable = false` en la definición lo saca de las salas.

**El suelo de un mapa** (plan 062): `bake_ground_roles.py` lee las baldosas del `.scp` en la tierra del propio mapa y escribe `ground_roles.png` (R abierto, G tierra, B roca, A camino); cada dios lo viste con su `GodGround` (`data/look/<dios>.tres`), en cualquier mapa. Un `.scp` fuera de la carpeta (el tutorial) se pasa con `--scp="Tutorial/(tu02).scp" --tag=tutorial_valley`; `--no-npcs` deja `Npcs` vacío y `--not-playable` pone `playable = false` (ni salas ni menús lo ofrecen; `--map=<tag>` y las escenas de debug sí lo abren). Las plantas: `scaffold_map.py --map=<Nombre> --wire-flora` escribe un PNG de densidad por especie (`scenes/map/maps/<tag>/flora/`) y cuelga un `FloraLayer` por especie de un nodo `Vegetation` del map.tscn (importá el proyecto una vez después); los PNG se pintan a mano, o sumá un `VegetationPatch`.

**Hacer uno a mano** (ejemplo: `test_flat4`, el mapa de prueba de 4 asientos, en `scenes/map/maps/test_flat4/`):

1. Copiá la carpeta de un mapa parecido (`test_flat/` o `test_flat4/`) a `scenes/map/maps/<tag>/`. El suelo es el `heights.png` (16 bits, valor × 0,1 m) y el `void.png` (blanco = vacío) de la carpeta: pintalos en cualquier editor de imágenes o en Blender (`tools/README.md`); la instancia `Terrain` del `map.tscn` apunta a ese `heights.png`.
2. En `map.tscn`, un `PlayerStart` por asiento bajo `MapProps/Starts` (`Start1`…`Start4`, con `slot` 1..N sin repetir) y su altar; mové el `WizardSpot` de cada inicio con el gizmo (ahí aparece el mago y hacia dónde mira); los manantiales bajo `MapProps/Founts`. Un edificio se arrastra bajo `Buildings`. En `test_flat4`, los asientos 1 y 2 están del mismo lado y 3 y 4 enfrente, porque el `2v2` junta 1+2 contra 3+4.
3. Los bandos salen de los nodos: cada `PlayerStart` es un asiento (`slot`; `team` mayor que 0 aliada a los asientos que lo comparten, 0 = enemigo de todos) y cada `side` de un `NpcSpawn` un bando sin jugador. Los equipos de un modo los pone el modo.
4. `<tag>.tres` (`MapDefinition`): `tag`, `display_name`, `map_scene`, `terrain`, `nav` (y `light` si tiene) arrastrados desde el inspector, y `player_starts` (= cantidad de `PlayerStart`). `room_selectable = false` si es solo de prueba (las salas lo ofrecen con `--room-test-maps`).
5. No hay lista que editar (`MapCatalog` recorre la carpeta). Horneá el navmesh (botón «Hornear navmesh» de `NavRegion`) y corré `tools/audit/check_map.tscn -- --map=<tag>` (asientos, objetos sobre tierra, bases a nivel, caminos).

Un mapa solo aparece en un modo si tiene un inicio por asiento: High Noon (2) ofrece `1v1`; `winter_wonder` y `test_flat4` (4) ofrecen también `2v2`, `ffa3` y `ffa4`.

## Un modo

Un modo (cuántos asientos, de qué equipo es cada uno, cómo se gana) es un `GameMode` `.tres` en `data/modes/`. No lleva código.

1. Duplicá uno parecido (por ejemplo `2v2.tres`) y llamalo `<tag>.tres`.
2. En el inspector: `tag` (el de `--mode=<tag>` y de la sala), `display_name` (una clave de `data/i18n/strings.csv`, como `MODE_2V2`; agregá la tuya con su texto), `team_of_seat` (el equipo de cada asiento, el 1 primero: `[0,1]` es 1 contra 1, `[0,0,1,1]` es 2 contra 2, `[0,1,2]` tres contra todos; los equipos van de 0 sin huecos) y `room_selectable`.
3. Sumalo a `modes` en `data/modes/mode_catalog.tres`.
4. Si ningún mapa tiene inicios para todos los asientos del modo, las pantallas no lo ofrecen.

Para probarlo sin pantallas: `--map=test_flat4 --mode=<tag>`.

## Jugar 2 contra 2

Hace falta un mapa de 4 asientos: `winter_wonder`, o `test_flat4` para probar.

- **Solo, contra la IA:** en el boot elegí el modo «2 contra 2» y el mapa, y pulsá «Contra la IA». La IA juega tu aliado y los dos rivales (su dios sale del selector «Dios de la IA»). En un build de debug el boot ofrece también los mapas de prueba.
- **En una sala online:** A pulsa «Salas online» → «Crear sala», elige modo «2 contra 2» y el mapa, y pasa el código. Los otros tres entran con «Unirse» y el código. Online son solo personas: para jugar con IA, usá «Servidor local».
- **Servidor de salas (apagado, para un VPS futuro):** prendé `room_server_enabled` en el inspector de `scenes/core/flow/sacrifice_flow.tscn` y levantalo con `$G --headless --path . res://scenes/net/room_server.tscn -- --room-server --lobby-config=res://data/net/lobby_config_local.tres --room-test-maps`. Con el interruptor prendido, «Salas online» abre su lobby (salas con asientos de IA, «Listo» y vuelta a la sala) en vez de las salas de jugadores.
- **Servidor local:** en «Servidor local» → «Crear servidor local», elegí modo y mapa y, por cada asiento que no es el tuyo, una persona o una IA. Cada asiento de persona tiene su código: pasale a cada uno el suyo, con la dirección y el puerto.

## Cambiar el balance

- **Una criatura, un hechizo, un mago, un edificio:** abrí su `.tres` en `data/catalog/<tipo>/` y cambiá el número en el inspector. No hay JSON ni tabla aparte; el juego lee el archivo.
- **Reglas de la partida** (duración, fuego amigo, topes): `data/match_rules.tres` (`MatchRules`).
- **IA y dificultad:** `data/ai/`.
- **Calidad gráfica:** `data/look/quality_*.tres`.
- No se muta un `.tres` en runtime.

## Relieve (mapas PBR) de un modelo

Cada textura de un modelo es un material en `scenes/bodies/materials/<owner>_<label>.tres` (un `StandardMaterial3D`, compartido por todos los modelos que la usan). Su relieve es un normal map en `assets/surfaces/<owner>/<file>_normal.png` (Git LFS), asignado en el slot **Normal Map** del material. Es opcional: un material sin normal map se ve como antes. Desde la RFC-067 todos los materiales lo tienen, salvo `pct6_M000_cutout`. La copia de piedra (StoneLook) y la de construcción (BuildReveal) conservan el relieve.

- **Ver o ajustar uno.** Abrí el material en el inspector (o el override de superficie de la malla en `scenes/bodies/models/<modelo>.tscn`). `normal_scale` lo suaviza o lo invierte (valor negativo). Para sacarlo, limpiá el slot Normal Map, o usá el botón Quitar.
- **Generar uno.** Arriba del inspector, en la sección «Relieve desde albedo», mové los knobs (la vista previa muestra el resultado), pulsá Generar y guardá con Ctrl+S. Escribe el PNG que falte, lo importa y lo asigna en un solo Ctrl+Z. Un PNG que ya existe se usa tal cual; «Sobrescribir» lo rehace y pierde lo que hayas retocado.
- **Muchos a la vez.** Usá **Project > Tools > «Generar relieve…»** (carpeta o selección, con «Saltear existentes»). Por consola son dos pasos, porque un PNG nuevo se asigna recién después de importarlo:
  ```bash
  $G --headless --path . --script res://tools/bake/bake_relief.gd -- res://scenes/bodies/materials/ --recipe=res://addons/surface_maps/recipes/default.tres
  $G --headless --path . --import
  $G --headless --path . --script res://tools/bake/bake_relief.gd -- res://scenes/bodies/materials/ --recipe=res://addons/surface_maps/recipes/default.tres
  ```
- **Recetas.** Hay dos en `addons/surface_maps/recipes/`. `default.tres` usa los valores de NormalMap-Online (strength 2,5, level 7, smoothing 0, sin paso alto, solo normal). `foliage.tres` agrega smoothing 1 para hojas finas, que con la receta por defecto se ven moteadas. Se usa en las plantas `<TAG>_plant*` y en los props de árboles y hojas.
- **Retocar.** El PNG es la fuente: editalo en Krita o en cualquier editor de imágenes y Godot lo reimporta. La receta con que se generó no se guarda.

## PBR desde Blender

Un modelo propio no necesita el generador: el `.glb` trae sus mapas.

1. En Blender conectá los mapas al **Principled BSDF**: Base Color, Normal (con un nodo *Normal Map*, espacio tangente), Roughness y Metallic (un ORM: R oclusión, G rugosidad, B metal), y Emission si hace falta. No pases el umbral de glow 1,0 (VISUAL: nada de brillo plástico).
2. Exportá a `assets/custom/models/<tag>.glb` (glTF 2.0). Si el `.glb` no trae tangentes, Godot las genera al importar (`meshes/ensure_tangents=true`). Godot convierte cada material en un `StandardMaterial3D` con sus mapas, y `tools/bake/new_creature.gd` no los pisa.
3. Si exportaste solo el color, generá el relieve sobre la textura extraída con la sección «Relieve desde albedo» del inspector. El mapa queda al lado del albedo, no en `assets/surfaces/`.

## Correr el lint y los horneados

Todo se corre desde `game/` y de a un Godot por vez.

```bash
G="${GODOT_BIN:-godot}"   # ver «Configurar rutas» abajo

# Lint de convenciones (grep/awk, sin Godot, ~1 s; falla si un conteo sube sobre tools/lint/baseline.txt)
bash tools/lint/conventions.sh
```

Desde el editor, **Project > Tools > Sacrifice** re-hornea el navmesh y hornea los modelos que faltan, y muestra la salida en un diálogo. El minimapa tiene un botón «Re-hornear minimapa» en el inspector de `MinimapTerrainBake`.

Los horneados por consola (sin `--force` no pisan lo editado a mano):

```bash
$G --headless --path . --script res://tools/bake/bake_body_scenes.gd        # solo los que faltan
$G --headless --path . --script res://tools/bake/bake_body_scenes.gd -- --force   # rehace todos (pisa tus cambios)
$G --headless --path . res://tools/bake/bake_nav.tscn                      # navmesh
```

Las pruebas son descartables: un flow o harness de AgentKit se regenera en `agent/` cuando hace falta y no se versiona.

## Herramientas que necesitan el juego original

Las rutas son relativas a `game/`.

| Herramienta | ¿Necesita el original? | Qué produce |
|---|---|---|
| Jugar (F5), `godot --path game` | **No** | Nada: los assets ya están en `game/assets/original/` (LFS) |
| Flows y capturas descartables de AgentKit | **No** | PASS/FAIL y capturas, no se versionan |
| `tools/import/export_stats.py` | **Sí** | `assets/original/data/*.json` (estadísticas de criaturas, hechizos, magos, edificios) |
| `tools/import/export_skeletal.py` | **Sí** | `assets/original/models/*.glb` + `index.json` (esqueleto y animaciones) |
| `tools/import/export_skeletal_reference.py` | **Sí** | OBJ de referencia en la carpeta temporal del sistema (`--out` para cambiarla) |
| `tools/import/import_textures.py` | **Sí** | `assets/original/textures/*.png` |
| `tools/import/import_props.py` | **Sí** | `assets/original/props/*.glb` (edificios y plantas) |
| `tools/import/import_themes.py` | **Sí** | `assets/original/themes/<dios>/` (cielo, sol, borde) |
| `tools/import/bake_role_sheets.py` (`--measure`) | **Sí** | `assets/original/themes/<dios>/roles/` (las hojas de los 4 suelos del dios) |
| `tools/import/import_ui.py` | **Sí** | `assets/original/ui/` y `assets/original/fx/` (HUD, iconos, cursores, partículas) |
| `tools/import/import_map.py` (incluye `--list`) | **Sí** | `assets/original/maps/<tag>/` (luz, entidades) |
| `tools/import/import_audio.py` | **Sí** | `assets/original/audio/` (efectos WAV, voces Ogg o WAV sin ffmpeg, música MP3) + `index.json`. Ya está en el repo (LFS) |
| `tools/audit/check_original_assets.sh` | **Sí** | Paridad de `assets/original/` con el original (`ASSETS PARITY PASS/FAIL`) |
| `tools/import/scaffold_map.py` | No: usa lo que ya dejó `import_map.py` | `MapDefinition`, `map.tscn`, `nav.res` vacío |
| `tools/import/sample_grass_palette.py` | No: usa `assets/original/themes/<dios>/roles/` | paleta de pasto propuesta |
| `tools/bake/*` (navmesh, catálogo, `bake_body_scenes`, `new_creature`) | No: `bake_body_scenes` usa los `.glb` y `index.json` del repo | Escenas, `.tres` y navmesh |
| `tools/terrain/heights_from_original.gd` | **Sí** (lee el `.scp`) | `scenes/map/maps/<tag>/heights.png` + `void.png`, el suelo de un mapa del original |
| Menú **Project > Tools > Sacrifice** | Solo «Listar mapas del original» e «Importar audio del original» (llevan «(requiere juego original)» en el menú) | Salida en un diálogo |

Estas herramientas leen los `.wad` y los `.scp` del juego instalado; **el original no viene en el repo** (es el juego comercial). Si falta, imprimen un mensaje en español que explica qué carpeta hace falta y cómo indicarla, y terminan con error. Todas empiezan su encabezado y su `--help` con «Requiere el juego original instalado (SAC_INSTALL)» o con «No necesita el juego original».

### Importar el audio del original

Casi nadie lo necesita: el audio ya importado está en el repo por Git LFS (`assets/original/audio/`: efectos WAV, voces Ogg, música MP3), con sus sets horneados en `data/audio/`. Solo se vuelve a correr si cambia el importador.

1. Necesita el juego original instalado. Indicá la carpeta con los `.wad` como en «Configurar rutas»: `SAC_INSTALL`, `tools/import/local.cfg` o **Editor Settings > sacrifice > original_install_path**.
2. **Project > Tools > Sacrifice: Importar audio del original** (o `python3 tools/import/import_audio.py`; `--check` muestra qué cambiaría sin escribir).
3. Las voces se comprimen a Ogg con ffmpeg. Sin ffmpeg en el `PATH`, avisa y las guarda en WAV (pesan unas cuatro veces más). `--codec=wav` las pide en WAV a propósito.
4. Después, «Hornear sonidos» escribe los sets que falten. El horneado ya no necesita el original: lee `assets/original/audio/index.json`.

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

**Godot y Blender** (los scripts de `game/tools/`). Eligen:

- `GODOT_BIN`: la variable de entorno si está; si no, `godot` del `PATH`; si no, el de macOS (`/Applications/Godot.app/Contents/MacOS/Godot`).
- `BLENDER_BIN`: la variable de entorno si está; si no, `blender` del `PATH`; si no, el de macOS (`/Applications/Blender.app/Contents/MacOS/Blender`).

```bash
export GODOT_BIN="/ruta/a/Godot_v4.7.2"   # opcional si godot está en el PATH
export BLENDER_BIN="/ruta/a/blender"      # solo para tools/blender/ y la criatura propia desde Blender
```
