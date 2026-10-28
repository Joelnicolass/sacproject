# RFC-018 — Mapa visible y editable en el editor

Plan del tech lead. Arquitectura estándar, MP online con dedicado: no cambian. Pedido: «que el mapa sea visible, y que eventualmente todo sea visible desde el editor: mapa; dónde inician los jugadores; dónde están las fuentes; dónde están los poblados con NPC. Para que el technical artist los pueda modificar cómodamente».

## 0. Hallazgos sobre High Noon (verificados)

Leí el NTTS de `(2) High Noon.scp` de la instalación local con el mismo `extract` que usan los exportadores. Formato: `sacengine/source/ntts.d:8-16` (tipos), `19-31` (Structure), `78-90` (Creature), `110-124` (Widgets).

| Qué | Cantidad | Detalle |
|---|---|---|
| Entidades NTTS | 113 | 76 estructuras, 32 criaturas, 5 listas de widgets. Sin magos, sin almas, sin marcadores. |
| Altares `jaal` | 2 | (1500, 1570) bando 0 y (1040, 980) bando 1. |
| Manantiales `jfnt` | **5** | (1270, 1270) centro, (1520, 1450), (1080, 1490), (1450, 1070), (1030, 1110). Bando 31 (neutral). |
| Refugios de campesinos | 11 | 5 `jhut` + 6 `jwg1`. Son los BLDG con la marca `shelter` (`bldg.d:11`, `sacobject.d:968-969`; cabecera `0xa0c0` en `jamesmod.wad`). |
| Otras estructuras | 58 | `jcc1-4` (31), `bld1-3` (12), `bon1/2/4/5/6` (10), `jeg1-3` (5). Sin marca de refugio. Un componente cada una. |
| Campesinos `zepe` (Farmer, `nttData.d:133, 519`) | 26 | Bando 2. En 5 grupos, uno por manantial: 10 en el centro, 5, 5, 3 y 3. |
| Criaturas neutrales `raeb` (Taurock, `nttData.d:786`) | 6 | Bando 3. |
| Widgets `JAW1-5` | 720 | 312 + 228 + 172 + 3 + 5. |

**Qué fuente respalda cada dato**

| Dato | Fuente |
|---|---|
| Cantidades, tags, posiciones, bandos e ids de la tabla | **Juego original**: NTTS dentro de `maps/(2) High Noon.scp` de la instalación local, leído en esta sesión. sacengine solo aporta el formato (`ntts.d`). |
| Qué BLDG es refugio | **Juego original**: cabecera de cada `.BLDG` en `data/jamesmod.wad` (`bild.FLDR`), bit 15. El significado del bit sale de sacengine (`bldg.d:11`, que lo marca «TODO: correct?»). |
| `zepe` = Farmer, `raeb` = Taurock, modelos `epez` / `eber` | sacengine (`nttData.d`) y `cache/data/creatures.json`, que sale de `spells.wad` del original. |
| Regla del refugio a 50 m, punto de aparición del mago, unidades de los ángulos, `mapCreatures` | Solo sacengine (reimplementación). No lo contrasté con el ejecutable. |
| Estado del port, bug de los pilares | Código de `game/` y una corrida headless de Godot 4.7.2. |

No usé REA ni el snapshot de Ghidra: los datos del mapa salen directo de los archivos del original y no quedó ninguna duda de conteo. Lo único que REA podría confirmar es el significado del bit `shelter`; solo importa cuando haya lógica de campesinos, que está fuera de alcance.

- **No existe la entidad «poblado».** En sacengine un poblado es lo que resulta de refugios más campesinos cerca: el campesino busca un refugio a menos de 50 m (`state.d:13610, 13733-13734`). En High Noon son 5 grupos, uno alrededor de cada manantial.
- **Dónde nace el mago:** no viene del mapa. Se calcula: a 15 m del altar de su bando, hacia el manantial más cercano, mirándolo (`state.d:2357-2388`). Las criaturas del mapa se colocan por defecto (`mapCreatures=true`, `options.d:101`, `state.d:31437-31440`).
- **Ángulos:** estructuras en grados (`state.d:31232`), criaturas en radianes (`31310`), widgets en radianes aunque parezcan grados (`31350-31354`).
- **Qué exporta hoy el port:** solo `export_high_noon_widgets.py` lee el NTTS y se queda con el tipo 8192 (línea 30). `export_high_noon_terrain.py` saca alturas y paredes, `export_high_noon_look.py` atlas, luz y roster, `export_bodies.py` los SAXS de magos y criaturas. **Nadie exporta estructuras ni criaturas del mapa.**
- **Posiciones del port:** `Slot0` (1500, 1570) y `Slot1` (1040, 980) son las originales. Sus `Fount` dan (1520, 1450) y (1030, 1110): originales, y son el manantial más cercano a cada altar. **Faltan 3 de los 5 manantiales**, incluido el del centro. No hay poblados, campesinos ni Taurocks.
- **Diferencias que ya existen y este RFC no toca:** el mago nace a 30 m (`wizard_spawner.gd:10`), no a 15. El look es de Persephone sobre un mapa de James: `pcfn`, `alba/alpi/alto` y plantas `PC*` en lugar de `jfnt`, `jaal` y `JAW*`. En `cache/baked` hay 71 props, todos de Persephone; ningún edificio de James está horneado.
- **Bug encontrado (no es del editor):** `body_visual.gd:22-24` pisa la posición y la rotación del propio nodo. Probado en headless: en `props/altar.tscn` los cuatro `Pillar` (guardados en ±20) terminan en (0, 0, 0) sin giro. Las colisiones siguen en ±20. Hoy el altar se dibuja con los pilares apilados en el centro. Se corrige en 018a, porque es lo primero que va a ver el TA.
- **Editor:** `BodyLibrary` es un autoload sin `@tool`, así que en el editor es `Nil` (`body_visual.gd:20`). Por eso hoy ningún `BodyVisual` se ve en el editor.

## 1. Objetivo y criterios de aceptación

Cinco sub-cortes. Cada uno se aprueba y se prueba por separado. Propongo numerarlos F47–F51 en `FEATURES.md`.

### 018a (F47) — Los modelos se ven en el editor
- Abrir `props/altar.tscn`, `props/manafount.tscn` y `props/plant.tscn` en el editor muestra el modelo horneado. La consola no imprime `SCRIPT ERROR`.
- El altar muestra 4 pilares en las esquinas, en el editor y en la partida.
- `model` en el inspector es una lista desplegable con los tags de `cache/baked`.
- Guardar cualquiera de esas escenas con Ctrl+S no cambia el archivo (`git diff` vacío): ni malla ni pose quedan guardadas.
- Sin `cache/`, el editor muestra el relleno (cápsula) y el aviso del inspector, sin error.

### 018b (F48) — Inicios y manantiales como nodos de la escena
- En `high_noon.tscn` abierta en el editor se ven, sobre el terreno: 2 inicios (altar completo, mago fantasma en el punto de aparición, cartel «Jugador 1» / «Jugador 2») y los 5 manantiales con su modelo.
- Mover un inicio o un manantial con el gizmo lo deja apoyado en el suelo. Duplicar o borrar un manantial funciona sin tocar scripts ni JSON.
- Un inicio sin manantial asignado, o dos inicios con el mismo número, avisan en el inspector.
- En la partida: el mago nace en el mismo punto que hoy; los 5 manantiales dan maná en el servidor; el altar da maná solo a su dueño. Solo, dedicado y dos clientes imprimen `mundo listo` sin `ERROR`.

### 018c (F49) — Poblados, campesinos y criaturas neutrales
- Un importador de un solo uso crea en la escena los 11 refugios, las 58 estructuras restantes, los 26 campesinos y los 6 Taurocks, agrupados en 5 poblados (`Villages/<nombre>`) más `Decor` y `Creatures`.
- Cada uno es un nodo real: se mueve, duplica y borra con el gizmo; mover el nodo del poblado mueve todo el grupo.
- Campesinos y Taurocks se ven con su modelo (`epez`, `eber`), quietos. Los edificios usan el modelo que diga la tabla de importación, o el relleno con aviso si no hay.
- La partida sigue arrancando igual en solo, dedicado y clientes. Los NPC no hacen nada (ver fuera de alcance).

### 018d (F50) — Vegetación editable
- La vegetación se ve en el editor y en la partida como `MultiMesh` (un nodo por modelo), alimentada por `cache/high_noon_widgets.json`. Ningún `.tscn` guarda las 720 posiciones.
- El TA puede: tapar una zona con un nodo máscara (radio en el inspector), agregar plantas sueltas como nodos `plant.tscn`, y cambiar qué modelos dibuja cada tag.
- Las zonas despejadas alrededor de altares y manantiales pasan a ser máscaras visibles, no números en un script.

### 018e (F51) — El mapa en su propia escena
- `scenes/maps/high_noon_map.tscn` contiene terreno, inicios, manantiales, poblados, criaturas, decorado y vegetación. `high_noon.tscn` la instancia y se queda con reglas, spawners, cámara y HUD.
- El TA abre solo la escena del mapa. Las 23 escenas de `debug/` siguen abriendo.

Criterio común a todos: `high_noon.tscn` y la escena del mapa pesan menos de 100 KB y ningún `.tscn`/`.tres` contiene datos del original (ver verificación).

## 2. Escena de prueba

**No hay escena debug nueva.** El criterio se ve en la propia escena del mapa abierta en el editor (`scenes/world/high_noon.tscn`; desde 018e, `scenes/maps/high_noon_map.tscn`) y en las packed de `props/`. No hay acción de InputMap: es un corte de editor.

Regresión de runtime con lo que ya existe:
- `scenes/world/high_noon.tscn` con F6 (solo).
- `debug/mana_fount.tscn` (F22): el mago arranca fuera de rango y entra al manantial con `move_forward`.
- `debug/hole_edge.tscn` (se adapta en 018b, ver árbol).
- Dedicado + dos clientes a `127.0.0.1`.

Verificación headless de que no se guardan datos originales (comandos, sin archivo nuevo):

```sh
# 1. Sin arrays, mallas, imágenes ni referencias al caché en escenas y recursos
grep -rlE "PackedByteArray|PackedVector3Array|PackedFloat32Array|ArrayMesh|ImageTexture|res://cache/" \
  game/scenes game/data --include='*.tscn' --include='*.tres'      # salida vacía
# 2. Tamaño
wc -c game/scenes/world/high_noon.tscn game/scenes/maps/*.tscn      # < 100000 cada una
# 3. La escena corre sin pantalla
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game res://scenes/world/high_noon.tscn --quit-after 120   # «mundo listo», sin ERROR
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -- --dedicated                                       # puerto listo, sin ERROR
# 4. Después de Ctrl+S en el editor
git diff --stat -- game/scenes     # solo los cambios hechos a mano
```

## 3. Árbol de archivos

```text
game/
├── tools/
│   ├── export_high_noon_entities.py      NUEVO 018c  NTTS → cache/high_noon_entities.json
│   └── import_map_entities.gd            NUEVO 018c  EditorScript de un solo uso
├── data/maps/
│   └── high_noon_import.tres             NUEVO 018c  tag → escena y modelo
├── scenes/data/
│   └── map_import_table.gd               NUEVO 018c  Resource
├── scenes/world/
│   ├── body_catalog.gd                   NUEVO 018a  class_name BodyCatalog, estático
│   ├── body_library.gd                   MOD   018a  queda como fachada
│   ├── body_visual.gd                    MOD   018a
│   ├── map_props.gd                      MOD   018b (sin slots) · 018d (sin widgets) · se va en 018e
│   ├── high_noon.tscn                    MOD   018b, c, d, e
│   ├── high_noon.gd                      MOD   018e  inyecta reglas y terreno
│   ├── theme_applier.gd                  MOD   018e  ruta del terreno
│   ├── components/
│   │   └── ground_snap.gd                NUEVO 018b  @tool
│   ├── props/
│   │   ├── altar.tscn                    MOD   018a  pivotes de los pilares
│   │   ├── manafount.tscn                MOD   018b  + GroundSnap
│   │   ├── player_start.tscn / .gd       NUEVO 018b  @tool
│   │   ├── map_structure.tscn / .gd      NUEVO 018c
│   │   ├── widget_field.tscn / .gd       NUEVO 018d  @tool
│   │   └── widget_mask.gd                NUEVO 018d  @tool
│   ├── npcs/
│   │   └── map_npc.tscn / .gd            NUEVO 018c
│   └── wizard/wizard_spawner.gd          MOD   018b
├── scenes/maps/
│   ├── high_noon_map.tscn                NUEVO 018e  la rama del mapa, extraída
│   └── game_map.gd                       NUEVO 018e  reemplaza a map_props.gd
└── debug/
    └── hole_edge.tscn                    MOD   018b (y 018e: ruta)
```

Árbol de la rama del mapa al terminar 018d (dentro de `high_noon.tscn`; en 018e pasa a ser la escena del mapa):

```text
MapProps (Node3D, map_props.gd)
├── Starts
│   ├── Start1 (player_start.tscn, slot = 1, faces → Founts/FountEast)
│   │   ├── Altar (altar.tscn)
│   │   ├── Preview (solo editor: mago fantasma + Label3D «Jugador 1»)
│   │   └── GroundSnap
│   └── Start2
├── Founts
│   └── FountCenter, FountEast, … (manafount.tscn ×5)
├── Villages
│   └── VillageCenter (Node3D sin script) → map_structure ×N, map_npc ×N
├── Creatures   → map_npc ×6
├── Decor       → map_structure ×58
└── Widgets (widget_field.tscn) → WidgetMask ×N, plantas sueltas
```

## 4. Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `body_catalog.gd` (nuevo) | Leer `cache/baked/*.json`, cachear mallas y dar la pose de un modelo. Funciones estáticas, sin árbol. | Helper `class_name` | Tiene que funcionar en el editor, donde no hay autoloads. Un autoload `@tool` depende de reiniciar el editor. |
| `body_library.gd` (mod) | Autoload que delega en `BodyCatalog`. | Autoload | Lo usan 14 scripts; migrarlos es otro corte. |
| `body_visual.gd` (mod) | Mostrar un modelo por tag en su `MeshInstance3D`. No guarda malla ni pose. | Nodo `@tool` | Es la única pieza que pinta un modelo horneado; todos los props la reusan. |
| `altar.tscn` (mod) | Altar: 6 visuales, colisión, `ManaSource`. Cada pilar pasa a `Pillar1 (Node3D) > Visual (BodyVisual)`. | Packed | `BodyVisual` es dueño de su transform (la pose). La colocación va en el padre. |
| `player_start.tscn` + `.gd` (nuevo) | Un inicio: número de slot, altar de ese slot, punto y giro donde aparece el mago (`spawn_spot()`), vista previa en el editor. | Packed `@tool` | El spawner no debe saber de altares ni manantiales; el altar no debe saber de slots de aparición. Mover el inicio mueve altar y punto juntos. |
| `ground_snap.gd` (nuevo) | Apoyar a su padre en el suelo: en el editor cuando se mueve, en runtime una vez en `_ready`. | Componente `@tool` | Lo usan 4 escenas (inicio, manantial, estructura, NPC). Se apaga quitando el hijo. Reemplaza el `_drop` con rayo de `map_props.gd`. |
| `manafount.tscn` (mod) | Manantial. Solo suma el hijo `GroundSnap`. | Packed | — |
| `wizard_spawner.gd` (mod) | Un mago por slot, en `spawn_spot()` del inicio con ese número. | `MpSlotSpawner` | Deja de calcular la geometría: la pide al inicio. |
| `map_props.gd` (mod) | 018b: pasar `rules` a los `ManaSource` del mapa en `_enter_tree`. Deja de instanciar altares y manantiales. 018d: deja de crear plantas. | Nodo | Las escenas debug cambian `rules` en la raíz; alguien tiene que bajarlas antes del `_ready` de los hijos. |
| `export_high_noon_entities.py` (nuevo) | NTTS → `cache/high_noon_entities.json` (estructuras y criaturas: tag, x, z, giro, bando, id). | Tool Python | El de widgets tiene otro formato y lo lee el runtime. |
| `map_import_table.gd` + `high_noon_import.tres` (nuevo) | Tabla tag del mapa → packed scene y modelo a dibujar. | Resource | Otro mapa u otro look es otro `.tres`, no un `match` en el importador. |
| `import_map_entities.gd` (nuevo) | Crear en la escena abierta los nodos que falten, con la tabla y el JSON del caché. Una sola vez. | `EditorScript` | No es runtime ni vive en la escena. Después, la escena es la fuente de verdad. |
| `map_structure.tscn` + `.gd` (nuevo) | Edificio u objeto fijo del mapa: visual, colisión del tamaño del modelo, `tag`, `shelter`. | Packed | `structures/structure.tscn` es lo que construye un jugador: lo crea un spawner, tiene vida y maná. Otro ciclo de vida. |
| `map_npc.tscn` + `.gd` (nuevo) | NPC del mapa: visual, `creature_tag`, `side`, grupo `map_npc`. Sin lógica. | Packed | `units/unit.tscn` trae órdenes, combate y réplica. Convertir el NPC en unidad es otro RFC. |
| `widget_field.tscn` + `.gd` (nuevo) | Leer los widgets del caché y armar un `MultiMeshInstance3D` por modelo, salteando agujeros y máscaras. No guarda nada. | Packed `@tool` | Separa la vegetación (720 instancias, solo visual) de inicios y manantiales (gameplay). |
| `widget_mask.gd` (nuevo) | Zona sin vegetación: posición y `radius`. | Nodo `@tool` | Es la capa editable sobre datos que no se pueden guardar. |
| `high_noon_map.tscn` + `game_map.gd` (018e) | La rama del mapa como escena; `game_map.gd` expone `rules` y `terrain`. | Packed | Es la mitad «Map» de la Fase 6 de la auditoría. |
| `debug/hole_edge.tscn` (mod) | Hoy mueve `MapProps/Slot0/Fount`, que deja de existir. Agrega un `Marker3D` propio en (1391, 0, 1424) y lo asigna a `Start1.faces`. | Escena debug | Sin script nuevo. |

## 5. Resource, nodo, `@export`

**Resource de tipo**
- `MapImportTable` (`data/maps/high_noon_import.tres`): `scenes: Dictionary[String, PackedScene]` y `models: Dictionary[String, String]`. Solo tags y rutas.
- `MatchRules`: sin cambios. Las tasas y radios de maná siguen ahí.

**Nodos**
- Todo lo que el TA coloca: inicios, manantiales, estructuras, NPC, máscaras, plantas sueltas.
- Los poblados son `Node3D` sin script: agrupan.

**`@export` de instancia**
- `PlayerStart`: `slot` (1..N), `faces: Node3D` (el manantial hacia el que mira), `wizard_distance` (30, el valor actual), `preview_model`.
- `BodyVisual`: `model` (desplegable), `stand_on_feet`.
- `MapStructure`: `tag`, `shelter`. `MapNpc`: `creature_tag`, `side`.
- `WidgetField`: `widgets_path`, `widget_models`, `plant_models`, `plant_seed` (se mudan de `MapProps` con los valores de hoy). `WidgetMask`: `radius`.
- `GroundSnap`: `enabled`, `offset`.
- `WizardSpawner.toward_fount`: se queda. `-1` (nuevo valor por defecto) = usar la distancia del inicio; `≥ 0` la pisa. Así `mana_fount`, `late_join`, `wizard_ghost` y `hole_edge` no cambian sus números.

**No se guarda en la escena:** mallas, materiales, pose de `BodyVisual`, los `MultiMesh`, el texto del cartel. Se reconstruyen desde el caché en cada carga.

**Flujo de datos, recomendado:** instalación → exportador → `cache/*.json` → **importador en el editor, una vez** → nodos con transform y tag en la escena, commiteados → el TA edita la escena. Leer el JSON en runtime (como hoy con los widgets) no deja nada para editar; por eso solo queda para la vegetación, donde son 720 instancias sin gameplay. El importador es un `EditorScript` y no un `-s` headless porque en el editor los scripts que no son `@tool` no corren: empaquetar la escena después de `_ready` guardaría valores pisados (`rate`, `radius`). No vuelve a tocar nodos que ya existen (los reconoce por el id del NTTS guardado como metadato).

## 6. Editor, runtime y dedicado

| Pieza | Editor (`@tool`) | Runtime con ventana | Dedicado |
|---|---|---|---|
| `Terrain` | Como hoy | Como hoy | Malla para colisión y suelo, como hoy |
| `BodyCatalog` | Lee JSON y `.res` del caché | Igual | Solo JSON (`loads_meshes()` falso) |
| `BodyVisual` | Muestra la malla; no la guarda | Igual | Sin malla |
| `PlayerStart` | Coloca la vista previa, avisa | Borra `Preview`; pone `owner_slot` en el altar y su `ManaSource` | Igual que runtime |
| `GroundSnap` | Ajusta la altura al mover | Una vez en `_ready`, con `terrain.ground_height` | Igual (mismo resultado en todos los peers) |
| `ManaSource` | No corre | Solo servidor o solo | Aplica el maná |
| `MapStructure` | Visual | Visual + colisión | Colisión desde el JSON |
| `MapNpc` | Visual | Visual | Nodo sin malla |
| `WidgetField` | Arma los `MultiMesh` | Igual | No arma nada |
| Importador | Solo a mano (Archivo → Ejecutar) | — | — |

Red: todo es contenido estático de la escena, idéntico en cada peer y con la misma ruta de nodo. No hace falta spawner ni sincronizador. `manafount_path` y la ocupación por Manalith siguen funcionando porque usan el grupo `manafount` y rutas. Nada entra en `addons/mp_kit`.

## 7. Riesgos

- **Guardar pose o malla sin querer.** `BodyVisual` escribe `mesh` y su transform en el editor. Se resuelve como en `terrain.gd`: quitar `PROPERTY_USAGE_STORAGE` en `_validate_property`; si con `transform` no alcanza, reponer en `NOTIFICATION_EDITOR_PRE_SAVE`. Criterio: `git diff` vacío tras Ctrl+S.
- **Funciones estáticas en el editor.** `GroundGuard` no es `@tool`; `GroundSnap` busca el terreno por el grupo `terrain` por su cuenta y convierte con `terrain.to_local`, porque en el editor la raíz está desplazada.
- **Cambio de juego en 018b:** de 2 a 5 manantiales. Es lo que trae el mapa, pero hay más maná en el centro. `debug/mana_fount.tscn` no se ve afectado: el más cercano al punto de prueba queda a unos 277 m.
- **Colisiones nuevas en 018c:** 69 cuerpos estáticos sin pathfinding (Fase 5 de la auditoría). Las criaturas pueden trabarse contra un edificio.
- **Modelos de James sin hornear.** Los edificios del poblado se van a ver con un modelo de Persephone o con el relleno hasta que haya un exportador de BLDG de James.
- **Flows viejos.** 8 flows de `agent/flows/` leen `MapProps/Slot0…` o `MapProps/Plant0`. Hay que actualizar la ruta en los que se sigan usando (`f22_mana_pt`, `pt35_manalith_lifecycle`); los de plantas dejan de aplicar en 018d.
- **`%Creature`.** El campesino suelto de `high_noon.tscn` va a aparecer en el origen del editor cuando `BodyVisual` funcione. Su retiro está pendiente en F43.
- **Posiciones originales en git.** Las escenas pasan a llevar unas 110 posiciones y tags del mapa original. Hoy ya llevan 4. No son mallas, texturas ni estadísticas.
- **018e:** rutas a `Terrain` en `Camera.ground`, `Selection.ground` y `theme_applier.gd:12`; `owner.get("rules")` deja de servir dentro de la escena del mapa, así que `high_noon.gd` inyecta `rules` y `terrain` en `_enter_tree`; `hole_edge.tscn` necesita `[editable path]`.

## 8. Fuera de alcance

- Comportamiento de NPC: caminar, huir al refugio, morir y soltar alma, conversión, Taurocks hostiles.
- Vida y destrucción de edificios del mapa; fuego (`canBurn`).
- Exportar y hornear los BLDG de James; cambiar el look de altar y manantial a James.
- Mover una por una las 720 plantas originales.
- Otros mapas, más de dos jugadores, bandos (resto de la Fase 6).
- Pasar la distancia del mago de 30 a 15 m.
- Migrar los 14 usos de `BodyLibrary` a `BodyCatalog`.
- Nodo `Match`, estado `destroyed` del altar (RFC-017).

## 9. Orden de implementación

**018a**
1. `body_catalog.gd` con `info`, `has_model`, `models`, `mesh`, `loads_meshes`, `pose(model, stand_on_feet)`, `reload`.
2. `body_library.gd` delega.
3. `body_visual.gd`: usa `BodyCatalog`; `model` como desplegable; no guarda `mesh` ni transform.
4. `altar.tscn`: un `Node3D` por pilar con el transform de hoy y el `BodyVisual` como hijo.
5. Probar las tres packed en el editor y `high_noon.tscn` en solo.

**018b**
1. `ground_snap.gd`.
2. `player_start.tscn` + script, con avisos.
3. En `high_noon.tscn`: `MapProps/Starts` con 2 inicios y `MapProps/Founts` con los 5 manantiales, en las posiciones del punto 0; borrar `Slot0`, `Slot1` y los `Fount`.
4. `map_props.gd`: quitar `_place_slots`, `_drop` y `altar_scene`/`fount_scene`; inyección de `rules` en `_enter_tree`; `_is_clear` usa los grupos `altar` y `manafount`.
5. `wizard_spawner.gd`: buscar el inicio por `slot`, usar `spawn_spot()`; `spawn_points = ../MapProps/Starts`.
6. `debug/hole_edge.tscn`.
7. Regresión: solo, `mana_fount`, `hole_edge`, dedicado + 2 clientes.

**018c**
1. `export_high_noon_entities.py`.
2. `map_import_table.gd` + `.tres`.
3. `map_structure.tscn`, `map_npc.tscn`.
4. `import_map_entities.gd`: agrupa refugios y campesinos por manantial más cercano; el resto a `Decor` y `Creatures`.
5. Ejecutarlo, revisar, guardar la escena.

**018d**
1. `widget_field.tscn` + `widget_mask.gd`; mover los `@export` desde `MapProps`.
2. Máscaras en inicios (40 m) y manantiales (6 m), los valores de hoy.
3. Borrar `_place_widgets` de `map_props.gd`.

**018e** (después de RFC-017)
1. Mover `Terrain` dentro de la rama y guardarla como `scenes/maps/high_noon_map.tscn`.
2. `game_map.gd` reemplaza a `map_props.gd`.
3. Ajustar las cuatro rutas y la inyección en `high_noon.gd`.
4. Abrir las 23 escenas de `debug/`.

## 10. Cómo verifica un humano en el editor

1. Abrir `game/` en Godot 4.7.2. Panel Salida sin `SCRIPT ERROR`.
2. **018a:** abrir `scenes/world/props/altar.tscn`: base, 4 pilares en las esquinas y techo. Seleccionar `Base`: `model` es un desplegable. Ctrl+S y `git diff -- game/scenes/world/props` vacío.
3. **018b:** abrir `scenes/world/high_noon.tscn`. Sobre el terreno: 2 altares con «Jugador 1» y «Jugador 2», un mago translúcido delante de cada uno, 5 manantiales. Arrastrar `Founts/FountCenter` con el gizmo: sigue la altura del suelo. Vaciar `faces` en `Start1`: triángulo amarillo en el árbol. Ctrl+Z.
4. F6 en `high_noon.tscn`: el mago aparece donde estaba el fantasma. F6 en `debug/mana_fount.tscn`: el maná sube al entrar al manantial.
5. **018c:** con `high_noon.tscn` abierta, abrir `tools/import_map_entities.gd` y Archivo → Ejecutar. En el árbol: 5 nodos bajo `Villages`, 58 bajo `Decor`, 6 bajo `Creatures`. Mover `VillageCenter`: se mueve el grupo entero. Ejecutar de nuevo: no duplica.
6. **018d:** la vegetación aparece. Agregar un `WidgetMask` con radio 30 sobre una zona: las plantas de ahí desaparecen. Instanciar `plant.tscn` bajo `Widgets` y elegir modelo.
7. Correr los comandos de la sección 2.

## 11. Relación con RFC-017

| Archivo | RFC-017 | RFC-018 | Conflicto |
|---|---|---|---|
| `props/altar.tscn` | Script `altar.gd` en la raíz, estado `destroyed` | 018a: pivotes de los pilares | Nodos distintos, mismo archivo: no en paralelo |
| `map_props.gd` | Setea `owner_slot` del altar | 018b: borra `_place_slots`; `owner_slot` lo pone `PlayerStart` | Semántico: quien llegue segundo adapta una línea |
| `high_noon.tscn` | Instancia `%Match` | 018b–d: rama `MapProps`; 018e: extrae el mapa | De texto (cabecera de recursos): no en paralelo |

**Orden recomendado: RFC-017 primero, después 018a → 018d, y 018e al final.** RFC-017 arregla un bloqueante (la partida online no termina) y toca poco esos archivos. Lo único de 018 que puede ir en paralelo con 017 son los pasos 1–3 de 018a (`body_catalog.gd`, `body_library.gd`, `body_visual.gd`). Si se prefiere ver el mapa antes, 018a y 018b pueden ir primero: entonces 017 escribe `altar.gd` con `@export var owner_slot`, no toca `map_props.gd`, y el altar ya es un nodo fijo con la misma ruta en todos los peers, que es lo que necesita un `destroyed` replicado.

**Separar `Match` de `Map`:** no ahora. 018b–d dejan todo el contenido del mapa en una sola rama; 018e la extrae cuando 017 ya puso `%Match`. Hacerlo antes obliga a tocar 23 escenas debug y a resolver la inyección de reglas en el mismo corte que cambia los inicios.

## 12. Preguntas abiertas

Ninguna bloquea 018a ni 018b.

1. **¿Se pueden commitear posiciones y tags del mapa original en la escena?** (bloquea 018c). Recomendación: sí. No son mallas, texturas ni estadísticas, y ya hay 4 commiteadas. Sin eso no hay nada que editar.
2. **¿Con qué modelo se ven los edificios del poblado?** (018c). Recomendación: tabla con modelos de Persephone ya horneados donde haya equivalente claro (`jhut` → `huta`) y relleno con aviso en el resto; el TA elige el modelo en el desplegable. Exportar los BLDG de James, en otro corte.
3. **¿Los NPC hacen algo?** Recomendación: nada en este RFC. Quietos, sin colisión, sin vida.
4. **¿Los 5 manantiales dan maná desde 018b?** Recomendación: sí; es el mapa original y es lo que el TA va a ver.
5. **¿017 antes que 018?** Recomendación: sí (sección 11).

¿Está bien el corte, o más/menos piezas? Opciones de «menos»: dejar 018e para la Fase 6; saltear `MapImportTable` y fijar la tabla dentro del importador. Opción de «más»: un botón en el inspector en lugar del `EditorScript`.

## 13. Decisiones del usuario (2026-10-12)

- Árbol aprobado. Orden: 018a + 018b primero (con 017c en paralelo), después 017a, 018c y 018d, 017b, y 018e al final.
- Pregunta 1: sí, las posiciones y tags del mapa original se commitean en la escena.
- Preguntas 2 a 4: se siguen las recomendaciones del plan.
- Numeración en `FEATURES.md`: F47 (018a) a F51 (018e); F44 a F46 son de RFC-017.
