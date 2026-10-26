Estado: **propuesto**, espera el OK del usuario.

# Plan RFC-057: terreno deformable (cierre de fase 2)

No toqué el repo. Corrí `bash tools/lint/conventions.sh` y todas las reglas dan OK contra la base (C1a 83/84, C9 234/236, C14 204/206, C15 24/26, C18 9/12, C21 0/1; el resto está igual a la base). Leí:
- `CONVENTIONS.md`, `RULES.md`, el boceto de RFC-055 (§12.2, §12.5, §13.4 y §15) y los planes 061k y 063D, más la investigación de rendimiento de 063D;
- `scenes/map/terrain/*`: terrain, terrain_live, terrain_stamp, stamp_carry, ground_field, ground_sum_rules, hole_rules, terrain_net, terrain_status, stamp_rules, stamp_profile, terrain_grid, hole_walls y terrain_collision;
- los hechizos: erupt_zone, volcano_zone, bore_zone, hole_cutter, meteor, drop_dent, zone_stamp_stop, zone_erupt y tornado_drift;
- las habilidades: quake.gd, quake_wave.gd/.tscn, bovine_quake_wave.tscn y quake_ring.gd;
- los que escuchan: nav_service, flora_ground_watch, terrain_deform.gdshaderinc, soul.gd, ground_footprint y footprint_rules;
- las pruebas: terrain_cases (672 líneas), bore_cases, dent_cases y terrain_late_join;
- en sacengine: state.d y sacmap.d.

## 0. Qué falta de verdad (resumen)

La API de 063D alcanza. RFC-057 ya no es «construir el terreno deformable»; quedan 7 huecos medibles:
1. El Quake no deforma.
2. Los cuerpos no bajan con el suelo.
3. Bore abre agujeros bajo las bases.
4. Las bases flotan o quedan enterradas bajo un sello (pregunta 1).
5. Un alma queda flotando sobre un agujero.
6. Erupt no se retira en el acto si lo cortan.
7. Hay que decidir qué hace rehornear la nav, y cómo sigue la flora a los sellos largos.

## 1. Inventario: qué deforma el suelo en el original

Fuente: el `Displacement` de state.d:28911-28934 suma lo permanente más `testDisplacements`, `eruptCastings`, `erupts` y `quakes`. Los agujeros son `edgeChanges` (state.d:29027-29066).

| Poder | Tipo | Ref sacengine | En el port | Estado |
|---|---|---|---|---|
| Erupt (tpre) | Vivo: crece al lanzar y en la erupción | state.d:3229-3289; si se interrumpe, desaparece en el acto (18386-18387) | `erupt_zone.tscn`: Mound, Rebound y Wave | Funciona. **Falta** retirarlo al cortar (no tiene `ZoneStampStop`) |
| Quake (kauq) del Jabberocky | Vivo, 0,5 s: hundimiento de 2 m y onda de 1,5 m | 5187-5222, 13204-13207, 13547 | `quake_wave.gd` declara «the land does not bend… render effect» | **Falta**. El desvío declarado está mal: `quakes` está en `Displacement`, que usan `getGroundHeight` y `moveOnGround` (28943-28946) |
| Bovine Intervention (vaca que revienta) | El mismo Quake | 21784 | `bovine_quake_wave.tscn` hereda de `quake_wave` | **Falta**: sale gratis con el Quake |
| Volcano (clov) | Permanente que crece en el lanzamiento y baja al 25 %; cráter de 25 m × 10 m | 4307-4370, 22309-22375, 7323-7335 | `volcano_zone.tscn`: Mound (vivo y después `keep`) y Crater (`keep`) | Funciona. El modelo es distinto (sello vivo y keep) pero el resultado final es igual |
| Bombardment | Permanente: abolladura de 15 m × 1,2 m | 4077-4083, 7305-7315, 21378 | `meteor.tscn`: Dent `manual` + `keep` | Funciona |
| Bore (erob) | Agujeros | 18653-18696, 28999-29066 | `HoleCutter` → `cut_hole`/`fill_hole` | Funciona. **Falta** respetar la base de 8×8 (punto 3) |
| TestDisplacement | Herramienta de debug del original | 5311-5325, 13421 | — | Fuera de alcance |
| Tornado (nrot) | No deforma: no está en `Displacement` | 4456 y siguientes | `tornado_drift` solo lee `height_at` | Nada que hacer |

**Bore contra la API nueva, verificado:**
- `HoleCutter` solo usa `cut_hole`/`fill_hole` y no ve ids.
- `FallingChunk` recibe `{at}`.
- `HoleWalls` lee `holes.version` (sirve para quien entra tarde).
- La colisión se rehace con `settled`, la nav con `holes_changed`, y `fill_hole` nunca rellena un vacío del mapa.

**Lo que falta de Bore:**
- `canRemoveLandVertex` también rechaza un vértice si alguna de sus 4 celdas cae en la máscara `ground` 8×8 de un edificio con `BldgFlags.ground` (state.d:29013-29023). `HoleRules` solo mira los 11 m.
- El alma sobre un agujero: en el original cae a 1 m/s y desaparece 50 m más abajo (state.d:14912-14920; `mapDepth`, sacmap.d:108). En el port, `soul.gd:296-304` hace `return` con NAN y el alma queda flotando.

**Los cuerpos:** en el original, una criatura que camina sigue el suelo en las dos direcciones (`moveOnGround`, state.d:14700). Las inmovilizadas solo suben (14657-14662). `StampCarry` hoy solo sube. Con `floor_snap_length = 0.5`, una bajada de más de 0,5 m por tick despega al cuerpo: el hundimiento del Quake (−4 m en unos 9 ticks), la abolladura (−1,2 m de golpe) o el cráter (−10 m).

**Flora y marcas:**
- Las marcas siguen solas, porque son una textura que lee el shader del suelo.
- La flora se replanta solo con `settled`. Durante los 64 s del monte de Volcano, las plantas de la ladera quedan a la altura vieja. El original no lo resuelve: `// TODO: weather, widgets` (state.d:22356), NO VERIFICADO qué hace el ejecutable.

## 2. Contradicciones y quién gana

| Contradicción | Gana |
|---|---|
| No existe `rfcs/RFC-057-*.md`; solo el boceto de RFC-055 §12.5 (TerrainShape, Chunks, DeformLog, TerrainBrush) | 063D, que es lo construido y lo aprobado. Este plan hace de RFC; el orquestador escribe `rfcs/RFC-057-deformable-terrain.md` con §3 y marca §12.5 como reemplazado (ese archivo también lo toca la auditoría de RFC-055) |
| `quake_wave.gd`/`quake_ring.gd`: «sacengine Quake.displacement is a render effect» frente a state.d:28929-28931 | sacengine: es simulación. RFC-055 §12.2 ya lo lista entre los que deforman |
| Decisión del usuario del 2026-10-24 (061k): «la nav como el original, solo los agujeros». El código de hoy (72dfae70) conecta `NavService` a `settled`, así que rehornea también por cada abolladura y al terminar Erupt, aunque Erupt no deja nada | La decisión del usuario. Como aquel motivo (el costo) desapareció con F6, pregunto de nuevo (pregunta 2) |
| El plan 061k §8 decía «los edificios no siguen el relieve (NO VERIFICADO)» | sacengine lo confirma: ni `getHeight` ni los edificios enmascaran el desplazamiento (sacmap.d:589-603). Si las bases se protegen o no lo decide el usuario (pregunta 1) |

## 3. Objetivo y criterios de aceptación (medibles)

1. **Quake deforma** (Jabberocky y la vaca de Bovine):
   - `height_at(c+d) − base` coincide con `Quake.displacement` (state.d:5204-5222) ±0,05 m, para d ∈ {0, 10, 25, 40, 55} m y t ∈ {1, 5, 10, 20, 29} ticks.
   - En el tick 31, |Δ| < 0,01 m en todo el rect.
   - En el host, `Status.live_stamps` tiene exactamente 2 claves (no 4).
2. **Los cuerpos bajan con el suelo:**
   - En `f132_quake_onhit`, el Trogg a 5 m queda a |y − `height_at`| ≤ 0,5 m en cada tick de la onda y no pasa a volar ni a dar tumbos.
   - Un cuerpo a 5 m de una abolladura queda a ≤ 0,05 m del suelo nuevo en el mismo tick.
   - Un cuerpo sobre un techo no se mueve (±0,01 m).
3. **Bases y Bore:** con la espiral de Bore pasando por el altar de Start1, `holes ∩ FootprintRules.vertices_under(huella) = ∅`, también para el manantial.
4. **(Si sale la pregunta 1b)** Con Erupt, Volcano o Dent sobre el altar, |`field().at(id)`| ≤ 1e-4 en cada vértice bajo una huella con `pins_ground`, en cada tick, y ≤ 0,5 × el valor libre en el anillo de vértices que la rodea.
5. **Borde y vacío:**
   - Erupt en (5, 5) m y en el borde del vacío de `edit_bed`: sin errores, 3 claves vivas y los vértices iguales a la fórmula ±1e-4.
   - `GroundRay.surface_y` = `height_at` ±0,05 en 20 puntos del borde durante el monte.
   - Al terminar, |Δ| < 0,01.
6. **Cortar Erupt:** con `cancel()` a los 0,5 s, al tick siguiente `field().at` = 0 exacto en el rect y `live_stamps` queda vacío (state.d:18386).
7. **Alma sobre un agujero:**
   - Baja 1,00 ± 0,05 m por segundo mientras no hay tierra.
   - El servidor la libera cuando pasa `vanish_depth_m` (50 m) por debajo del último suelo que tuvo.
   - Con tierra debajo, sigue como hoy.
8. **Nav** (según la pregunta 2, recomendación b):
   - un Erupt entero no cambia `NavService.rebakes`;
   - una abolladura suma 1 dentro de `holes_rebake_s` más el horneado;
   - un agujero de Bore suma 1;
   - `bore_nav` sigue en PASS.
9. **Red:**
   - `terrain_late_join` da `TERRAIN NET PASS`, con dos casos nuevos:
     - un `kept` en vuelo antes del snapshot: el checksum es igual;
     - un cliente que entra a los 20 s de un Volcano: su `ticks` queda a ≤ `resync_ticks` (8) del servidor y |`at(centro)` del cliente − el del servidor| ≤ 0,05 m.
   - El cliente ve las 2 claves del Quake mientras dura.
10. **Rendimiento:** en `debug/perf/terrain_deform_bench.tscn` con 5 Quakes simultáneos:
    - el tick de física sube ≤ 1 ms en promedio contra la base;
    - ningún frame pasa de 20 ms.
11. **(Si sale la pregunta 3b)** Durante la bajada del Volcano, las plantas de las celdas tocadas quedan a |y − `height_at`| ≤ 0,5 m en cada replanificación de 1 s, y hay 0 replanificaciones fuera del rect.
12. **Lint:** ningún conteo sube.

## 4. Escena de prueba

No invento escenas: los criterios ya empiezan en dos que existen.

- **`res://debug/spells/cast_terrain.tscn`** (F6):
  - High Noon; el mago `james` en Start1, con su altar y su manantial al lado; Troggs a 10, 45 y 60 m; la casa `jhut` a 30 m y helechos a 25 m.
  - **Estado inicial:** suelo sin deformar, 0 agujeros.
  - **Lo que todavía no está:** agujeros bajo el altar (tiene que seguir en 0), el altar a nivel tras un Erupt encima (1b) y el monte que se retira al cortar.
  - **El playtester:** `spell_N` (Bore, Erupt) y clic sobre el altar. Para cortar, se mueve o golpea durante el lanzamiento. Con `wizard_god = pyro` hace lo mismo con Volcano.
  - Verifica en Remote → `Terrain/Status` (`holes`, `live_stamps`, `rev`).
- **`res://debug/units/f132_quake_onhit.tscn`** (F6): el Jabberocky en el manantial central y un Trogg a 5 m.
  - **Lo que todavía no está:** la tierra que se hunde y la onda.
  - **Criterio:** el Trogg sigue el suelo, |y − `height_at`| ≤ 0,5.
  - No hace falta pulsar nada: el Jabberocky usa el Quake solo.

**Bancos sin ventana:**
- `debug/terrain/edit_bed.tscn` (la isla de 600 m con altar, manantial y vacío alrededor) para los casos de borde.
- `terrain_late_join` para la red.

## 5. Árbol de archivos

⚠ marca lo que comparte algo con el trabajo en paralelo.

```
game/scenes/units/abilities/
  [+] quake_ground.tscn          the ground of a Quake: Rebound + Wave TerrainStamps, profiles embedded (state.d:5204-5222). No script
  [~] quake_wave.tscn            + Ground (instance of quake_ground.tscn): the server plays it in the simulation
  [~] quake_wave.gd              doc only: without «Deviations: the land does not bend» (C9: Ref at the end)
  (bovine_quake_wave.tscn        unchanged: it inherits the Ground)
game/scenes/fx/
  [~] quake_ring.tscn  ⚠065 (same folder as «scenes/fx particle flat», different file)   + Ground (instance, editable children: Rebound/Wave on_clients_only = true)
  [~] quake_ring.gd    ⚠065 (folder)   doc only
game/scenes/map/terrain/
  [~] terrain_stamp.gd           + @export on_clients_only (does not play where the server simulates)
  [~] stamp_carry.gd             standing → Standing {bodies, ground_y}; lift → follow (up AND down for whoever stood on the land)
  [~] terrain.gd                 the two calls standing/follow; (1b) + _pins built in _ready and handed to Live and to keep_stamp
  [~] hole_rules.gd  ⚠065 (reads ManafountBody.GROUP; does not edit it)   + bases_of(tree) and the base rule in can_remove/removable
  [+] pin_rules.gd               (only 1b) static: weights(areas) -> 65536 floats (0 under the base, 0.5 on the ring, 1 elsewhere); apply(values, rect, weights)
  [~] terrain_live.gd            (only 1b) var pins: PackedFloat32Array; _shift_of applies them
  [~] README.md                  the inventory of §1 (who deforms, through which API), the new Check lines
game/scenes/map/props/
  [~] ground_footprint.gd  ⚠065 (same folder as manafount_body; different file)   (only 1b) + @export pins_ground := true
game/scenes/spells/zones/
  [~] erupt_zone.tscn            + Cut (ZoneStampStop, stamps [Mound, Rebound, Wave]); no new script
game/scenes/souls/
  [~] soul.gd                    _settle: with no land under it, sinks fall_speed and is freed vanish_depth_m below its last ground
game/scenes/map/nav/
  [~] nav_service.gd             (question 2) holes_changed + kept instead of settled
game/scenes/look/vegetation/
  [~] flora_ground_watch.gd  ⚠terrain_tools/flora (if that work touches the vegetation watcher)   (only 3b) + live changes in their own list, flushed every live_every_s
  [~] flora_field.gd  ⚠terrain_tools/flora   (only 3b) + @export live_replan_s := 1.0 (0 = as today)
game/debug/suite/
  [+] quake_ground_cases.gd      criteria 1 and the 2 keys on the host
  [+] carry_cases.gd             criterion 2 (Quake, dent, roof)
  [+] base_cases.gd              criteria 3 and 4, on edit_bed
  [+] deform_edge_cases.gd       criteria 5, 6, 7 and 8
  [+] deform_net_cases.gd        criterion 9 (in-flight kept, join mid-Volcano, Quake on the client)
  [~] terrain_cases.gd           registers the 5 files (merge, like bore/dent) and run_net adds deform_net_cases
game/debug/perf/terrain_deform_bench.gd (or .tscn)   [~] + «5 Quakes» run (criterion 10)
game/rfcs/RFC-057-deformable-terrain.md   [+] (orchestrator) §1 + §3 of this plan
game/rfcs/RFC-055-human-first-refactor.md [~] ⚠RFC-055 audit   §12.5 «Reemplazado por 063D + RFC-057»
```

No se toca:
- `addons/terrain_tools/*` (lo usan el trabajo de mapa nuevo y de flora);
- `tower.tscn`, `reveal/*`, `manafount_body` y `wizard_sounds` (plan 065);
- `GroundField`, `TerrainNet` (ni el formato en el cable ni el snapshot) y los `map.tscn`.

## 6. Árboles de nodos

```
QuakeGround (Node3D)                                       quake_ground.tscn, no script
├── Rebound (TerrainStamp)   profile (embedded): radial −(1+cos πx)/2 · timeline sin(π·rp(t)), 0..0.5 s
│   └── Reach (CollisionShape3D, Cylinder r 50 m, h 4 m)   2·reboundHeight
└── Wave (TerrainStamp)      radial (1+cos πx)/2 · timeline (1−p²)·min(1, t/0.05) · ring_travel 50·t/0.5 · ring_width (0.15+0.65(1−p)²)·50
    └── Reach (CollisionShape3D, Cylinder r 58 m, h 3 m)   2·waveHeight; r = waveLoc + waveSize at most

QuakeWave (QuakeWave, server)          QuakeRing (FxScene, every peer with a window)
├── … (as today)                       ├── Ring (MeshInstance3D)
└── Ground (QuakeGround)               └── Ground (QuakeGround; Rebound/Wave on_clients_only = true)

EruptZone (GroundZone)
├── Mound · Rebound · Wave (TerrainStamp)   as today
├── Cut (ZoneStampStop)  [+] stamps = [Mound, Rebound, Wave]
└── Blast · Stun · Dust                     as today

Altar / Manafount (unchanged)
└── GroundFootprint (CollisionShape3D, Box)   (1b) pins_ground = true  ← the base the spell does not move
```

## 7. Responsabilidades

| Pieza | Hace | No hace | Tipo |
|---|---|---|---|
| `QuakeGround` | La forma de la sacudida en el suelo | Aturdir (`QuakeWave`) ni dibujar el anillo (`QuakeRing`) | Escena (nodos y `StampProfile` embebidos) |
| `TerrainStamp.on_clients_only` | La copia para el look de un cliente | Simular nada | `@export` de instancia |
| `StampCarry` | Pone en el suelo nuevo a quien estaba parado en tierra: sube y baja | Mover cuerpos que vuelan, dan tumbos o están sobre un techo; decidir cómo se mueve el suelo | static |
| `HoleRules` | Dice si un vértice puede irse: borde, ya quitado, 11 m de una parte, **base** | Abrir el agujero (`Terrain`) | static |
| `PinRules` (1b) | Los pesos de las bases | Saber qué es un hechizo | static |
| `Terrain` | El único escritor; arma `_pins` una vez | Saber qué base es cuál | Nodo |
| `ZoneStampStop` | Al cortar, retira los sellos | — | Nodo, ya existe |
| `Soul._settle` | Cae sin tierra y desaparece | Decidir agujeros | Nodo, ya existe |
| `NavService` | Rehornea con agujeros y con lo que queda | Escuchar sellos vivos | Nodo |
| `FloraGroundWatch` (3b) | Agrupa también lo vivo, cada `live_every_s` | Tocar el suelo | RefCounted |

## 8. Resource, nodo o `@export`

- **Resource de tipo:** los `StampProfile` del Quake, embebidos en `quake_ground.tscn` (sin cadenas de `.tres`). Los números del Quake salen de sus curvas y sus `Reach`, no de `kauq.tres`.
- **Nodos:**
  - `QuakeGround` y sus dos `TerrainStamp`;
  - `Cut` en `erupt_zone`;
  - `GroundFootprint`, que ya existe: su caja con gizmo es la base.
- **`@export` de instancia:**
  - `TerrainStamp.on_clients_only`;
  - `GroundFootprint.pins_ground` (1b);
  - `Soul.vanish_depth_m` (50 m; Ref: `mapDepth`, sacmap.d:108);
  - `FloraField.live_replan_s` (3b).
- **Derivado en memoria, nunca guardado:** `_pins` de `Terrain`, armado de las huellas del árbol en `_ready` (C19: ningún `.tres` con posiciones).

## 9. Cómo lo hace un humano

| Verbo | Dónde y qué | Lugares |
|---|---|---|
| Entender | `scenes/map/terrain/README.md`, que trae la tabla de quién deforma y por qué API; la escena del hechizo muestra sus sellos | 1 |
| Modificar | La escena del hechizo → `TerrainStamp`: el gizmo `Reach` y las curvas. Quake: `quake_ground.tscn`. Una base: el gizmo de `GroundFootprint` y `pins_ground` | 1 |
| Agregar | Un poder que deforma = un nodo `TerrainStamp` (o `HoleCutter`) en su escena, sin código. Si la escena vive solo en el servidor, una copia con `on_clients_only` en su FX | 1-2 |
| Quitar | Borrar el nodo del sello, o la instancia de `QuakeGround` | 1 |
| Crear | Un `StampProfile` nuevo en el inspector | 1 |
| Escalar | Más hechizos = más nodos; más bases = más `GroundFootprint`. El mapa más grande que 256² sigue fuera (063D) | — |
| Encontrar un bug | Remote → `Terrain/Status` (`live_stamps`: 2 claves por Quake; `holes`; `rev`) · `zone_run.tscn -- --only=terrain --case=<caso>` · `terrain_late_join` (checksum) · `terrain_deform_bench` · F6 en `cast_terrain` o `f132_quake_onhit` | 1 |

## 10. Contratos

```gdscript
# TerrainStamp
## A copy for the look on a client: the server plays the real one in its own scene (QuakeWave). It does not play on the
## server, alone or on the host; there the real one is seen.
@export var on_clients_only := false
# _ready: set_physics_process(_terrain != null and is_ready() and not manual and not (on_clients_only and _terrain.is_authority()))

# StampCarry
class Standing:
	var bodies: Array[Node3D]
	var ground_y: PackedFloat32Array   ## the land under each one before the change
## The bodies over `rect` on or above the land (as today), with the land under them; none on a client.
static func standing(shape: Terrain, rect: Rect2i) -> Standing
## Covered by the land → on it (as today). Was on the land (|y − ground_y| ≤ SINK_M), is not flying nor tumbling, and the
## land under it went down (not NAN) → on it as well. A body on a roof or in the air is left alone.
static func follow(standing: Standing, shape: Terrain) -> void
## Ref: moveOnGround (state.d:14700); the immobilized ones of the original only go up (14657-14662): here they also go down (declared deviation).

# HoleRules
## The lattice vertices under every base of `tree` (GroundFootprint.GROUP, FootprintRules.vertices_under): a hole there cuts a base.
static func bases_of(tree: SceneTree) -> Array[Rect2i]
static func can_remove(shape: Terrain, vertex: Vector2i, parts: PackedVector3Array, bases: Array[Rect2i]) -> bool
## Ref: canRemoveLandVertex checkGround (state.d:29013-29023): the 4 cells around the vertex = the vertex lies in vertices_under.

# (1b) PinRules + GroundFootprint
@export var pins_ground := true      ## a spell's stamp leaves the land under this base as it is
static func weights(areas: Array[Rect2]) -> PackedFloat32Array   ## empty when there is no base (nothing is multiplied)
static func apply(values: PackedFloat32Array, rect: Rect2i, weights: PackedFloat32Array) -> void
# Terrain._ready (match only): live.pins = PinRules.weights(<areas of the footprints with pins_ground>); keep_stamp applies the same

# Soul
@export_range(0.0, 200.0, 1.0, "suffix:m") var vanish_depth_m := 50.0
## _settle: NAN and Terrain.of(self).is_on_ground(x, z) == false → y −= fall_speed·delta; y < last ground − vanish_depth_m → the
## server frees it through the same path as today. Ref: updateSoul (state.d:14912-14920).

# NavService (question 2b)
terrain.holes_changed.connect(_on_ground_settled.unbind(1))
terrain.kept.connect(_on_ground_settled.unbind(4))     # in place of settled: a live stamp that ends changes nothing for good
```

## 11. Subcortes y paralelo

Los developers no corren Godot. Hay una sola pasada al final.

| Subcorte | Archivos | Depende de | En paralelo con |
|---|---|---|---|
| 057a Quake | `quake_ground.tscn`, `quake_wave.tscn/.gd`, `quake_ring.tscn/.gd`, `terrain_stamp.gd`, `quake_ground_cases.gd` | — | todos |
| 057b Bajar con el suelo | `stamp_carry.gd`, `terrain.gd` (2 líneas), `carry_cases.gd` | — | 057a, 057d, 057e |
| 057c Bases | `hole_rules.gd`, `base_cases.gd`; con 1b también `pin_rules.gd`, `terrain_live.gd`, `ground_footprint.gd` y `terrain.gd` | con 1b, después de 057b (los dos tocan `terrain.gd`) o con el mismo developer | 057a, 057d |
| 057d Arreglos | `erupt_zone.tscn`, `soul.gd`, `nav_service.gd`, `deform_edge_cases.gd` | — | todos (carpetas disjuntas) |
| 057e Flora viva (solo 3b) | `flora_ground_watch.gd`, `flora_field.gd` (⚠ trabajo de flora) | — | todos, salvo el de flora en paralelo |
| 057z Integración | `terrain_cases.gd` (registro), `deform_net_cases.gd`, bench, README, RFC-057, RFC-055 §12.5, base del lint | todos | — |

**Pasada final del orquestador** (con Godot de a uno):
1. Import una vez.
2. `zone_run.tscn -- --only=terrain`.
3. `terrain_late_join`.
4. `terrain_deform_bench` con ventana.
5. Con ventana, porque hay cambios visibles: F6 en `cast_terrain` (Bore y Erupt sobre el altar, cortar Erupt; Volcano con pyro) y en `f132_quake_onhit`.
6. El lint.

## 12. Pruebas

- **Existentes que siguen en PASS:** `terrain_{rules, displacement, hole, erupt_*, flora, net, volcano_*}`, `bore_*`, `dent_*`, `grid_constants` y `terrain_late_join`.
- **Nuevas:**
  - `quake_ground` (1);
  - `carry_quake`, `carry_dent` y `carry_roof` (2);
  - `base_hole` y `base_pin` (3 y 4);
  - `rim_stamp`, `void_stamp`, `erupt_cancel`, `soul_hole` y `nav_trigger` (5 a 8);
  - `net_inflight`, `net_mid_volcano` y `net_quake_client` (9);
  - el bench (10).
- `terrain_cases.gd` ya tiene 672 líneas, por eso cada subcorte agrega su propio archivo y `terrain_cases` solo los registra, como hace hoy con bore y dent.
- El banco de determinismo sigue pospuesto, según la memoria.

## 13. Red y determinismo

- **Lo que queda** (Volcano, abolladura, cráter) viaja como bytes por `TerrainNet` (`kept`), igual que los agujeros. Un par que entra tarde recibe el snapshot; el formato no cambia.
- **Los sellos vivos** corren en cada par con su propio reloj: `synced_ticks` y el `pattern` de Volcano por `synced_on_change`. El Quake es la excepción: `QuakeWave` vive solo en el servidor, así que el cliente juega la copia `on_clients_only` que llega con el FX. Ese FX va por RPC no confiable, y si se pierde el paquete, a ese cliente le falta la onda. Es solo look: en el cliente las posiciones las pone el servidor.
- **Simulación** (servidor o solo): `StampCarry`, `cut_hole`, `HoleRules`, `NavService`, el alma.
- **Presentación:** la malla por shader, `HoleWalls`, las marcas, la flora y la copia del Quake en el cliente.
- `checksum()` deja fuera lo vivo a propósito.
- **`net_inflight`** prueba que un `keep` con un `rev` mayor que llega antes del snapshot no hace perder cambios. El snapshot se acepta cuando su `rev` es mayor o igual al de este par, y se envía después del RPC.
- **Pines (1b):** salen de los nodos del mapa, que son iguales en cada par. Los sellos vivos dan lo mismo en todos y los que quedan viajan en bytes.

## 14. Riesgos

- **Pines con Erupt de 15 m:** queda un escalón de unos 7,5 m en 10 m al borde de la base. Se mide con `base_pin` y una captura; si no gusta, el anillo pasa a 2 vértices.
- **Volcano encimado con otro sello vivo:** `StampRules.ground_under` deja lo vivo afuera, mientras que el original aplana hacia la altura que incluye el monte anterior (state.d:4340, `getHeight`). Es un desvío menor que acepto. NO VERIFICADO cuánto se nota.
- **Altura de las partes de los edificios:** `HoleRules` compara contra la altura deformada; el original usa la base (`map.heights`, state.d:29002). Es menor.
- **`fling` de Bore:** mira 30 m alrededor; el original mira todo el mapa (state.d:29051-29056). Basta, porque solo pierde el suelo quien está cerca.
- **Erupt con un lanzamiento de más de 4 s:** el original congela el monte en `castingLimit` (state.d:18383); con 1,11 s de lanzamiento no aplica. NO VERIFICADO con un lanzamiento lento.
- **El alma tarda 50 s en desaparecer** a 1 m/s, como el original. Si el agujero se rellena antes, queda enterrada: igual que el original, y NO VERIFICADO.
- **`terrain.gd` ya tiene 230 líneas:** 1b agrega unas 8. Si se pasa de 240, armar `_pins` sale a `PinRules.of_tree`.
- **⚠ El trabajo de flora en paralelo** puede tocar `flora_field.gd`: 057e va después o con el mismo developer.

## 15. Fuera de alcance (los pospuso el usuario, al final de todo)

- **La navegación por zonas o tiles** (rehornear solo lo tocado). Memoria del 2026-10-26: «podemos dejarlo hasta el final de todo».
- **El hechizo «gota de agua» y modernizar Erupt, Volcano, Dent y Bombardment** (memoria `terrain-spell-ideas`: «dejalos para el final de todo, ya son agregados»).

**También afuera:**
- edificios que siguen el relieve;
- el minimapa que se actualiza;
- el pasto;
- cachear `VolcanoLook.height_at` (F8);
- las cuevas;
- que la IA use los hechizos de terreno;
- `TestDisplacement`.

## 16. Preguntas (con mi recomendación)

1. **¿Un sello mueve el suelo bajo una base (altar, manantial y la torre que se construye encima)?**
   - (a) Como el original: el altar flota o queda enterrado y la torre igual.
   - (b) `GroundFootprint.pins_ground`: la base queda a nivel, con un anillo suave alrededor; es un desvío declarado y se apaga por huella.
   - **Recomiendo (b):** un altar flotando 15 m se lee como un bug y rompe la regla de «base a nivel» de check_map. Bore rechaza vértices bajo la base en los dos casos, como el original.
2. **¿Qué rehornea la nav?**
   - (a) Solo los agujeros, como el original y como decidió el usuario el 2026-10-24.
   - (b) Agujeros más lo que queda (`kept`).
   - (c) Como hoy, con cada `settled`, incluido el fin de Erupt, que no deja nada.
   - **Recomiendo (b):** desde F6 rehornear cuesta 1,3-1,6 ms de hilo principal, el navmesh queda igual a la colisión y se evita el rehorneado inútil de (c). Si el usuario prefiere su decisión, (a) es una línea.
3. **¿La flora sigue a los sellos que duran (el monte de Volcano, 64 s)?**
   - (a) Como hoy: se replanta al asentar y la ladera queda fuera de lugar hasta el final.
   - (b) Se replanifica lo vivo cada 1 s, solo en las celdas tocadas.
   - **Recomiendo (b):** es presentación y el costo está acotado a las celdas.
4. **¿Cómo ve el Quake un cliente?**
   - (a) La copia `on_clients_only` dentro de `QuakeRing`: una perilla y nada de red nueva.
   - (b) Replicar `QuakeWave` por el `ShotSpawner`: es confiable, pero hay que cambiar el registro del spawner y proteger su lógica de aturdir.
   - **Recomiendo (a).**
5. **¿Las criaturas inmovilizadas también bajan con el suelo?** El original solo las sube. **Recomiendo que sí bajen:** una sola regla para todos los que están parados en tierra, como desvío declarado.
6. **¿El alma sobre un agujero cae y desaparece a 50 m, como el original?** **Recomiendo que sí.**

## Archivos relevantes

- /Users/joelsartori/Development/sacproject/game/scenes/map/terrain/terrain.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/terrain/terrain_stamp.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/terrain/terrain_live.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/terrain/stamp_carry.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/terrain/hole_rules.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/terrain/README.md
- /Users/joelsartori/Development/sacproject/game/scenes/units/abilities/quake_wave.gd
- /Users/joelsartori/Development/sacproject/game/scenes/units/abilities/quake_wave.tscn
- /Users/joelsartori/Development/sacproject/game/scenes/fx/quake_ring.tscn
- /Users/joelsartori/Development/sacproject/game/scenes/spells/zones/erupt_zone.tscn
- /Users/joelsartori/Development/sacproject/game/scenes/spells/zones/volcano_zone.tscn
- /Users/joelsartori/Development/sacproject/game/scenes/spells/zones/hole_cutter.gd
- /Users/joelsartori/Development/sacproject/game/scenes/souls/soul.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/nav/nav_service.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/props/ground_footprint.gd
- /Users/joelsartori/Development/sacproject/game/scenes/look/vegetation/flora_ground_watch.gd
- /Users/joelsartori/Development/sacproject/game/debug/spells/cast_terrain.tscn
- /Users/joelsartori/Development/sacproject/game/debug/units/f132_quake_onhit.tscn
- /Users/joelsartori/Development/sacproject/game/debug/suite/terrain_cases.gd
- /Users/joelsartori/Development/sacproject/game/debug/net/terrain_late_join.gd
- /Users/joelsartori/Development/sacproject/sacengine/source/state.d (28911-28934, 5187-5222, 3229-3289, 18377-18392, 4307-4370, 7294-7345, 22309-22375, 28999-29066, 14904-14920, 14654-14700)
