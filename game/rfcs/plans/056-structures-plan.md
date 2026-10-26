Estado: **aprobado 2026-10-26** con todas las recomendaciones (linger 1 s, sacudida 0,35, el mismo estallido para todo, el corte de 065 se queda con su explosión chica). Nota del orquestador: F390 es de 060; este toma F391.

# Plan RFC-056: estructuras (solo destrucción, extensible)

**Alcance.** El usuario lo cerró el 2026-10-26: por ahora solo la destrucción de las torres (Manalith y Shrine) y de los edificios del mapa, con escombros y explosión como el original. No se agrega nada nuevo de guardián, captura, visión, fuego, Shrine ni altares. Tiene que ser fácil de extender: la estructura avisa con señales y cada comportamiento nuevo es un nodo hijo que se suscribe, sin tocar código.

**Lo que hice.**
- Leí `CONVENTIONS.md` entero, RULES, VISUAL, PRD, RFC-055 (§8, §12, §13.4, §15), `055d-buildings.md`, `055d-plan.md`, el plan 065 y el código real.
- Corrí `bash tools/lint/conventions.sh`: todo OK, nada sube (C1a 83/84, C5 159/159). No edité nada del repo.

## 0. Qué hacía el original (sacengine, archivo:línea)

**Cómo cae un edificio**
- `dealDamageIgnoreGuardians` llama a `destroy` cuando la vida llega a 0 (`state.d:9183-9188`).
- `destroy` no hace nada si la vida máxima es 0 y si no, agrega un `BuildingDestruction` (`state.d:8376-8380`).

**Por cada parte del edificio** (`updateBuildingDestruction`, `state.d:15157-15181`)
- La parte se borra.
- Si tiene un modelo destruido, se pone en su lugar con la misma posición, giro y escala. En el port eso ya es `BuildingType.ruin_scene`.
- En el centro de esa parte suena `destructionAnimation`.
- Si el edificio estaba sobre un manantial, el manantial queda libre en ese mismo momento (`state.d:15175`).

**`destructionAnimation`** (`state.d:27650-27660`)
- Por defecto: `animateDebris` + `explosionAnimation`.
- Con la animación `1tuh`: ceniza (`animateAsh`, 300 partículas) en vez de escombros.
- **NO VERIFICADO** qué BLDG usan `1tuh`: `assets/original/data/buildings.json` no trae el campo `destruction`.

**`animateDebris`** (`state.d:27632-27642`)
- 35 escombros a 20 ± 5 m/s.
- La parte vertical de la dirección va de 0,5 a 2.
- Giran de 0,5 a 2 vueltas por segundo.
- Gravedad 30, rebotan y dejan una estela de fuego (`state.d:15054-15080`).
- Usan la malla de escombro a escala 0,2 (`renderer.d:1567-1576`).

**`explosionAnimation`** (`state.d:27625-27630`)
- El sonido `pxbf`, que es nuestro `fbxp.wav` (`data/audio/cues/explosion_burst.tres`), con ganancia 10.
- Dos esferas: una de 0 a 30 m a 40 m/s y otra de 0 a 5 m a 10 m/s.
- 200 partículas, mitad `explosion` y mitad `explosion2`, a 1,5–6 m/s, que viven 31 cuadros (`state.d:27611-27623`).

**Lo que no hay**
- Ningún `screenShake` es de edificios (lo comprobó el plan 065).
- No hay reparación: solo regeneran el Manalith y el Shrine (`sacobject.d:1004-1009`; REA da 83,3/s y ya está así en el port).

**El port hoy**
- Ya existe un estallido igual en `scenes/spells/zones/explosion_burst.tscn` (`ExplosionBurst`):
  - las dos esferas 30/40 y 5/10;
  - rocas `debris_piece.tscn` (malla bold a escala 0,2, gravedad 30, rebote y fuego);
  - el sonido `fbxp`.
- `data/fx/explosion_blast.tres` y `explosion_blast2.tres` son las 200 partículas (velocidad 1,5–6 y vida 0,517 s, que son los 31 cuadros).
- **Todo se reusa; no hace falta un efecto nuevo.**

## 1. Contradicciones y quién gana

1. **Cómo desaparece una torre que cae en pie.**
   - Hoy `CastTower._on_died` hace `queue_free()` en el servidor (`cast_tower.gd:134-135`).
   - El cliente puede recibir el despawn antes que la vida en 0, y entonces no ve nada.
   - El original deja la caída visible en todos.
   - **Gana el original.** La torre queda caída `linger_s` (1 s) en todos los peers y recién después el servidor la libera.
2. **El corte durante la subida.**
   - El plan 065, aprobado, hace una explosión chica (`build_cut.tres`).
   - El original usa el mismo `destroy` para cortar y para destruir (`state.d:15262-15263`).
   - **Gana 065** en el corte, porque lo aprobó el usuario. Este plan no toca la torre que sube: una torre subiendo no recibe daño (`is_targetable`), así que no hay solapamiento.
3. **La ruina.**
   - `MapBuilding` la agrega como hijo `INTERNAL_MODE_BACK` (`map_building.gd:146`).
   - El checklist del reviewer no quiere hijos internos nuevos.
   - **Gana CONVENTIONS.** La ruina pasa a ser un hijo normal, que se ve en el árbol remoto.
4. **Doc vieja.** El `##` de `guard_post.gd` dice «a shrine would add its own», pero `shrine_tower.tscn` hereda el `GuardPost`. No se toca: está fuera de alcance. Va a la lista de pendientes.
5. **Bloom.** VISUAL.md pide «bloom fuerte en hechizos y fuego»; la memoria del usuario (2026-10-24) dice «sin bloom fuerte». **Gana el usuario:** el flash se mide (criterio 4).

## 2. Objetivo y criterios de aceptación

- Un edificio con vida que llega a 0 estalla en cada una de sus partes: escombros, dos esferas de fuego, partículas y sonido, como el original. Pasa igual en solo, en el servidor y en cada cliente.
- Las torres en pie (Manalith y Shrine):
  - estallan igual;
  - liberan el manantial en el mismo tick;
  - salen del grupo de torres;
  - dejan de dar maná;
  - desaparecen a `linger_s`.
- Los edificios del mapa muestran su ruina (si tienen) y estallan.
- Extensible: `MapBuilding` publica `damaged` y `destroyed` en todos los peers. Un comportamiento nuevo (sonido, otra FX, una regla) es un nodo hijo con `@export var building: MapBuilding` que se conecta a esas señales.
- Cero RPC nuevos. El dedicado no dibuja ni suena.

**Criterios medibles** (`--fixed-fps 60`; el tick 0 es el golpe que deja la vida en 0)

1. **Estallido por parte.** `StructureBreak.broke` se emite exactamente una vez por parte con malla de `Visuals`, en el tick 0 a 1, en todos los peers:
   - torre: 1;
   - `james_hut`: 1;
   - un edificio indestructible: 0, aunque se intente.
   - Lo cuenta la suite headless: la señal se emite aunque el FxBus no dibuje.
2. **La torre.** En el tick 0:
   - `fount.is_free()` es verdadero;
   - la torre ya no está en el grupo `cast_tower` ni en `structure`;
   - el `ManaSource` da 0;
   - `is_targetable()` es falso.
   - El nodo sale del árbol en el tick 60 ± 1 (`linger_s` = 1,0). Nunca suena `manalith_loop` después del tick 0.
3. **El edificio del mapa.** En el tick 0:
   - `Visuals` no se ve;
   - la ruina (`james_hut_ruin`) es un hijo visible y **no interno**;
   - la colisión está apagada.
   - Se vuelve a hornear el navmesh una sola vez (`NavService._on_building_destroyed`, ya existe).
4. **Look y sonido**, con la cámara fija de la escena de prueba:
   - El SoundLog registra `explosion_burst` en el tick 0 ± 2, una vez por parte.
   - La captura `f390_02` (+0,1 s) muestra las esferas y las rocas.
   - Píxeles con algún canal ≥ 250: ≤ base + 1,5 % del cuadro.
   - A +3 s (`f390_03`) no queda ninguna esfera ni roca: el `ExplosionBurst` se libera solo a los 4 s.
5. **Sacudida.** Con `camera_trauma` = 0,35 en la escena del estallido, el mago a 30 m recibe 0,35·(40−30)/32 ≈ 0,11 ± 0,02 de trauma, y 0 a 40 m o más. Con «Sacudida» en 0 %, el offset es 0.
6. **Entrar tarde a la partida.** Un cliente que entra con la casa ya caída:
   - ve la ruina;
   - `broke` = 0, porque no se arma antes de `arm_after_s` = 2 s;
   - no tiene un `explosion_burst` en el SoundLog.
7. **Red.** `fx_net_probe`: una destrucción manda 0 RPC de FxBus. Headless: `StructureBreak` y `BuildingRuin` corren sin dibujar.
8. **Extensible.** Un nodo de prueba con solo `@export var building` y dos `connect` en `_ready` recibe `damaged(fraction_left)` en cada golpe y `destroyed` una vez, en solo y en un cliente. Lo verifica la suite.
9. **Lint.** Ningún conteo sube. Ningún script nuevo pasa de 150 líneas, y `map_building.gd` queda en ≤ 150 o menos (hoy 149).

## 3. Escena de prueba

**`res://debug/structures/structure_break.tscn` [+]**
- Hereda `res://debug/map/structure_siege.tscn` (High Noon). Esa escena ya la usan `manalith_build_area` y `guardian_manalith`.
- Instancia:
  - `EnemyTower`: `scenes/structures/buildings/_jman.tscn` puesto a mano, `owner_slot` 2, `fount` = FountEast (1520, 16.1, 1450), `build_progress` 1;
  - las casas y los cactus de la aldea del mapa (`james_hut`, 5000 de vida, con ruina; `james_cactus_1`, 1000 de vida);
  - `BreakKey` (`debug/structures/break_key.gd` [+], solo debug, ≤ 40 líneas).
- `BreakKey` tiene `@export var targets: Array[MapBuilding]`, `@export_range hit_fraction := 0.5` y `@export var mods := 0`.
  - Con `debug_hit` (K), el blanco que sigue recibe `hit_fraction × maximum` por `Health.damage_typed(..., Health.SPLASH_SPELL, 1, ...)`.
  - Dos K tiran un blanco.
- **Estado inicial:**
  - el mago (slot 1) a 30 m de FountEast;
  - la torre enemiga en pie con la columna;
  - las casas enteras.
- **Lo que todavía no está:** estallido, escombros, ruina, manantial libre.
- **El playtester:** K, K (sobre `EnemyTower`), K, K (casa) y K, K (cactus).
- **Flujo:** `agent/flows/f390_structure_break.json` [+], con capturas `f390_01` (antes), `f390_02` (+0,1 s) y `f390_03` (+3 s) por blanco. Hace `print` de `broke`, `is_free()`, `CameraShake.trauma` y el SoundLog.
- La escena y el flujo quedan en el F390 de FEATURES.

## 4. Árbol de archivos

```
game/
├─ scenes/map/
│  ├─ map_building.gd                 [~] + signal damaged(fraction_left); sin ocultar Visuals ni ruina (lo hace BuildingRuin); ≤150
│  ├─ map_building.tscn               [~] + StructureBreak, + BuildingRuin; Sync Health:current spawn=true
│  └─ README.md                       [~] Talks to: damaged/destroyed
├─ scenes/structures/
│  ├─ building_fit.gd                 [~] + static part_center(part) (~+12 → ~42)
│  ├─ breaking/                       [+] sistema nuevo
│  │  ├─ README.md                    [+] What/Not/Talks to/Edit/Check
│  │  ├─ structure_break.gd           [+] StructureBreak (~75)
│  │  ├─ building_break.tscn          [+] hereda spells/zones/explosion_burst.tscn: pieces 35, scar vacío, camera_trauma 0,35
│  │  └─ building_ruin.gd             [+] BuildingRuin (~40)
│  ├─ towers/cast_tower.gd            [~] linger_s, al caer: libera la fuente, sale del grupo, ManaSource off; is_targetable (~146)
│  ├─ towers/README.md                [~] Talks to (caída), Check
│  └─ README.md                       [~] Talks to / Check (breaking/)
├─ debug/structures/
│  ├─ structure_break.tscn            [+]
│  └─ break_key.gd                    [+] solo debug
├─ debug/suite/
│  ├─ structure_break_cases.gd        [+] criterios 1, 2, 3, 6 y 8 headless
│  └─ rules_suite (lista de casos)    [~] + structure_break_cases
├─ agent/flows/f390_structure_break.json [+]
└─ FEATURES.md                        [~] F390   (compartido: 065 agrega F389)
```

**Compartidos con el trabajo en paralelo**
- **Plan 065.** `cast_tower.gd` no está en su árbol, pero su `BuildCues` escucha el `tree_exiting` de la torre. La espera no le cambia nada, porque solo actúa con la torre subiendo.
- **Plan 065, sin tocar:** `tower.tscn` y `shrine_tower.tscn` heredan los nodos nuevos de `map_building.tscn`. `manafount_body.gd` tampoco se toca: solo se llama a su `release()`, que ya existe y sigue valiendo con el look derivado de 065.
- **Mapas y terrain_tools:** nada.
- **Auditoría de RFC-055:** solo documentos.

## 5. Árboles de nodos

```
MapBuilding (StaticBody3D, MapBuilding)       map_building.tscn
├─ Visuals            partes (MeshInstance3D); una parte puede tener un Marker3D hijo = su punto de estallido (opcional)
├─ Collision
├─ Health
├─ Sync               Health:current (spawn=true, ON_CHANGE)
├─ HealthBar
├─ StructureBreak     [+] building=.., scene=building_break.tscn, bursts=[explosion_blast, explosion_blast2], arm_after_s 2
└─ BuildingRuin       [+] building=..  (oculta Visuals y agrega type.ruin_scene como hijo normal)

Tower (CastTower ← map_building.tscn)          sin cambios en el .tscn: hereda StructureBreak y BuildingRuin
└─ (los nodos de 065 + los de hoy)

BuildingBreak (ExplosionBurst ← explosion_burst.tscn)   building_break.tscn
├─ Big, Small         esferas 30 m @40 m/s y 5 m @10 m/s (heredadas)
├─ Scar               heredado, sin uso (scar = null en la raíz: un edificio no deja quemadura)
└─ Sound              explosion_burst (fbxp)
```

## 6. Responsabilidades (un dueño por estado)

| Pieza | Hace | No hace |
|---|---|---|
| `Health` | dueño de la vida (replicada) | decidir qué pasa al caer |
| `MapBuilding` | dueño de «caído» (`_gone`): colisión, grupos, refugio; emite `damaged` (en cada baja, en todos los peers, desde `changed`) y `destroyed` (una vez) | dibujar, sonar, ruina |
| `BuildingRuin` | presentación de lo que queda: oculta `Visuals` y muestra la ruina | estallar |
| `StructureBreak` | por parte con malla: `FxBus.play_scene(scene)` + `FxBus.play` de cada burst en `BuildingFit.part_center`; emite `broke(at)`; no se arma antes de `arm_after_s` (entrar tarde) | decidir la caída; broadcast |
| `BuildingFit` | medir: caja y centro de una parte | — |
| `CastTower` | al caer: `fount.release`, sale de `TOWER_GROUP`, `ManaSource` deshabilitado; el servidor cuenta `linger_s` en ticks y libera; `is_targetable` = en pie y no caída | FX |
| `ExplosionBurst` (reusado) | esferas, rocas y sonido; se libera solo | — |

Cómo se extiende: un nodo hijo nuevo (por ejemplo un sonido al dañarse, humo, una regla) con `@export var building: MapBuilding` se conecta a `damaged` o `destroyed`. Se apaga sacándolo. Es el mismo patrón que `StructureBreak` y `BuildingRuin`.

## 7. Resource de tipo, nodo o `@export` de instancia

- **Resources (ya existen):**
  - `BuildingType` (`max_health`, `ruin_scene`): sin campos nuevos;
  - `explosion_blast.tres` y `explosion_blast2.tres`;
  - el cue `explosion_burst.tres`.
- **Escenas o nodos:**
  - `building_break.tscn` (variante heredada del estallido);
  - `StructureBreak` y `BuildingRuin`;
  - un `Marker3D` opcional por parte.
- **`@export` de instancia:**
  - `StructureBreak.scene`, `bursts` y `arm_after_s`;
  - `CastTower.linger_s`;
  - `camera_trauma` y `pieces` en la raíz de `building_break.tscn`.
- Un edificio que necesita otra caída (ceniza, algo chico para un cactus) cambia `StructureBreak.scene` en **su** escena de edificio, como override de instancia.
- Ningún número va a `MatchRules`.

## 8. Cómo lo hace un humano (los seis verbos y «encontrar un bug»)

| Verbo | Dónde, sin código |
|---|---|
| Entender | `scenes/structures/breaking/README.md` (5 líneas) y el árbol de `map_building.tscn` |
| Modificar | fuerza y rocas en la raíz de `building_break.tscn` (`pieces`, radios, `camera_trauma`); partículas en `explosion_blast*.tres`; cuánto queda la torre en `CastTower.linger_s` en `tower.tscn` |
| Agregar | otra reacción = un nodo hijo en `map_building.tscn` (o en la escena de un edificio) que escucha `damaged`/`destroyed`; otro burst = arrastrar un `.tres` a `StructureBreak.bursts` |
| Quitar | borrar `StructureBreak`: el edificio cae sin FX; vaciar `bursts` = solo esferas y rocas |
| Crear | un edificio nuevo hereda `map_building.tscn` y trae la caída; otra caída = duplicar `building_break.tscn` y asignarla en la escena de ese edificio |
| Escalar | 1 o 2 lugares: la escena del estallido y el nodo; mover el punto de una parte = soltar un `Marker3D` en la parte y arrastrarlo |
| Encontrar un bug | F6 en `debug/structures/structure_break.tscn` + K; inspector remoto: `StructureBreak` (señal `broke`), `EnemyTower/Health.current`, `FountEast.is_free()`; suite `structure_break_cases` |

## 9. Contratos

```gdscript
# MapBuilding
## Every peer: the health went down (fraction_left = current / maximum, 0..1). Not emitted at 0 twice.
signal damaged(fraction_left: float)
## Every peer, once: the health reached 0. Collision and groups are already off.
signal destroyed(building: MapBuilding)

# BuildingFit
## World centre where a part bursts: its Marker3D child when it has one, else the middle of its meshes. A part with no mesh: NAN vector.
static func part_center(part: Node3D) -> Vector3

# StructureBreak (presentation, every peer, local FxBus.play_scene / play; never broadcast)
signal broke(at: Vector3)
@export var building: MapBuilding
@export var scene: PackedScene              ## an FxScene: building_break.tscn
@export var bursts: Array[ParticleType] = []
@export_range(0.0, 10.0, 0.1, "suffix:s") var arm_after_s := 2.0

# BuildingRuin
@export var building: MapBuilding

# CastTower
@export_range(0.0, 10.0, 0.1, "suffix:s") var linger_s := 1.0   ## server: MatchClock.ticks_for(linger_s), then queue_free
func is_targetable() -> bool    ## standing and not destroyed
```

- **Red:**
  - la caída sale de `Health:current` (ON_CHANGE, confiable), que ya replican la torre (spawn = true) y el edificio del mapa (pasa a spawn = true);
  - en los clientes, `MapBuilding._on_health_changed` ya emite `destroyed`;
  - la torre sigue en el árbol `linger_s`, y por eso el cliente ve el 0 antes del despawn;
  - el estallido es `FxBus.play_scene` local: 0 RPC.
- **Simulación o presentación:**
  - Simulación: `CastTower` (fuente, grupo, maná, la espera en ticks) y `MapBuilding._gone`.
  - Presentación: `StructureBreak`, `BuildingRuin` y `ExplosionBurst`. Las rocas usan `MatchSeed.rng` por posición, igual en cada peer y sin leer nada de la simulación.
- **Determinismo:** la torre sale del árbol 60 ticks más tarde que hoy, pero la fuente queda libre en el mismo tick que hoy. Si cambia un digest, se regraba al final (memoria «sin banco de determinismo»).

## 10. Sub-cortes y paralelismo (los developers no corren Godot)

- **S1. Caída en todos los peers (simulación).** `cast_tower.gd` (espera, liberar al caer, `is_targetable`), `map_building.gd` (`damaged`, sin la parte visual) y `Sync spawn=true`.
- **S2. Lo que se ve.** `building_ruin.gd`, `structure_break.gd`, `building_fit.part_center`, `building_break.tscn`, los nodos en `map_building.tscn` y los README. Depende de S1 (el mismo `map_building.*`), así que va en serie, con el mismo developer.
- **S3. Verificación.** `debug/structures/*`, `structure_break_cases.gd` y el flujo `f390`. Puede escribirse en paralelo a S2 contra los contratos de §9.
- **Con 065:** se puede empezar ya. No comparte archivos de escritura; solo `FEATURES.md`, que se integra a mano.
- **Una pasada de pruebas al final:**
  - el import;
  - `rules_suite`: `tower_cases`, `build_area_cases`, `guardian_cases`, `tree_block_cases` y `structure_break_cases`;
  - el flujo `f390` con ventana (es un cambio visible, va el playtest);
  - una corrida con red: cliente que mira la caída y cliente que entra tarde;
  - `fx_net_probe`;
  - `bash tools/lint/conventions.sh`.

## 11. Riesgos

- **`spawn=true` en un `MultiplayerSynchronizer` de una escena que no se spawnea.** No sé si Godot manda el valor al que entra tarde (**NO VERIFICADO**). Lo mide el criterio 6. Si falla, la ruina no se ve para quien entra tarde, pero sigue sin haber FX.
- **Explosión en todo lo que cae.** Un cactus que cae tira esferas de 30 m. Es fiel al original. Si queda mal, se cambia `StructureBreak.scene` en la escena de ese edificio.
- **IA y blancos en el segundo de espera.** `is_targetable` = falso y la torre fuera de `structure`/`cast_tower` lo cubren. Si `TargetPicker` no pregunta `is_targetable`, una criatura puede pegarle 1 s a una torre ya caída, sin efecto (**NO VERIFICADO**).
- **Overdraw.** 2 esferas + 35 rocas con fuego + 240 sprites por parte. Hoy solo hay edificios de 1 parte destructibles; los altares no entran.
- **`map_building.gd` en el límite de C1a (149 líneas).** Lo que se va (ocultar las partes y la ruina) compensa lo que entra.
- **`ExplosionBurst` vive en `spells/zones` y ahora tiene un segundo llamador.** Moverlo a `scenes/fx/` va después de 065, con `move_map.py`.

## 12. Fuera de alcance (decisión del usuario; cada uno sería un nodo hijo que escucha estas señales)

- **Fuego en edificios.** El original quema a 25/s (`state.d:28007-28015`, lista `canBurn` en `sacobject.d:1010-1021`) y en el port «no building catches fire» (`burn_impact.gd:11`).
- **Visión de 75 m de las estructuras** (`sacobject.d:88-93`, `state.d:27976-27980`).
- **El look del Shrine.**
  - Hoy muestra la columna y el zumbido del Manalith.
  - El original le pone llama `fb_g` de 4 m a +3 m, más rápida durante un ritual (`state.d:27814-27833`, `28004`), y el loop `afir` (`sacobject.d:266-271`).
  - El altar tampoco tiene esa llama en el port.
- **El altar de cada dios.** Los mapas del original usan `jaal`, `ca_a`, `pyal` y `stal` (`ntts.json`); el port usa siempre `alba`.
- **El Magnifryer y el Dynamo** (`state.d:27883-27960`). Ningún mapa del port los usa.
- **XP al destruir** (`sacobject.d:974`). El port no tiene XP.
- **La ceniza `1tuh`.** **NO VERIFICADO.**
- **Guardián y captura.** Ya funcionan: el reparto `GuardPost.split_divisor` = `state.d:9101`, y `CaptureTask` destruye para volver a construir. Es lo de hoy y no se toca.
- **La explosión del corte** es del plan 065.

## 13. Preguntas, con mi recomendación

1. **Espera de la torre caída:** 1 s. **Recomiendo 1,0 s.** Alcanza para que llegue el 0 de la vida antes del despawn sin que la torre estorbe.
2. **Sacudida:** el original no tiene. **Recomiendo 0,35,** la misma del corte de 065, para que el final de una torre se sienta igual en los dos casos.
3. **El mismo estallido para todo** (fiel) o uno más chico para plantas. **Recomiendo el fiel por defecto,** con override por escena si en el playtest algo queda mal.
4. **¿El corte de 065 usa después `building_break.tscn`?** **Recomiendo dejar lo aprobado** y revisarlo en el playtest final con los dos a la vista.
5. **ID:** RFC-056 / F390.

## Archivos relevantes (rutas absolutas)

- /Users/joelsartori/Development/sacproject/game/scenes/map/map_building.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/map_building.tscn
- /Users/joelsartori/Development/sacproject/game/scenes/structures/towers/cast_tower.gd
- /Users/joelsartori/Development/sacproject/game/scenes/structures/building_fit.gd
- /Users/joelsartori/Development/sacproject/game/scenes/spells/zones/explosion_burst.tscn
- /Users/joelsartori/Development/sacproject/game/scenes/spells/zones/explosion_burst.gd
- /Users/joelsartori/Development/sacproject/game/scenes/spells/zones/debris_piece.tscn
- /Users/joelsartori/Development/sacproject/game/data/fx/explosion_blast.tres
- /Users/joelsartori/Development/sacproject/game/data/fx/explosion_blast2.tres
- /Users/joelsartori/Development/sacproject/game/debug/map/structure_siege.tscn
- /Users/joelsartori/Development/sacproject/game/rfcs/plans/065-build-feedback-plan.md
- /Users/joelsartori/Development/sacproject/sacengine/source/state.d (8376-8380, 9183-9188, 15157-15181, 27611-27660)