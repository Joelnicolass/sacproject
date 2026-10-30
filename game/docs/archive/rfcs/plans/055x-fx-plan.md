# 055x: FX tipados y puestos en sockets

> **Aprobado (2026-10-25)** con todas las recomendaciones de §12: el usuario las dio por buenas de antemano («dalo por bueno y acepta recomendaciones»). Lo guarda el orquestador. Medido en `main` 4410f875.

Fuentes: RFC-055 §13.2 (055x FX), §13.2b C-8d y C-8f, §15; planes 055s §3.4, 055g, 055o §6 y 055c1; CONVENTIONS C1–C23 y §2c.

## 0. Contradicciones (y cuál gana)
1. **Los conteos del RFC están viejos.** C-8f dice «C17 26» y «128 .tres». Hoy C17 = **19** (12 en spells, 6 en units, 1 en death_cloud_type). `data/fx` tiene 130 `ParticleType` sueltos, 3 en `spells/`, 16 en `wards/`, 11 `BeamType`, 26 `FxLightSpec`. Gana la medición de hoy.
2. **C17 no ve la mayoría del texto:** `@export var x_fx := "…"`, nombres derivados, campos de texto en `.tscn`/`.tres`. x1 amplía el patrón y reescribe la base en el mismo corte, como hizo 055o. El objetivo de x7 es C17 = 0.
3. `FxSoundMap` ya no existe (lo sacó 055o). `FxSounds` pasa a leer el `sound` del recurso que trae `played`.
4. C-8f dice «después de 061 cerrado», pero el orden aprobado lo pone antes. Si se abre un corte de 061 mientras corre x2, comparten `scenes/spells/zones/` y van en serie.
5. `altar_collapse` entra en 055x. `soul.gd` y `soul_strike` quedan fuera (los lee la simulación): corte de almas o 055z.
6. «Probar todo al final»: los developers no corren Godot; la pasada final incluye NET QUICK y el costo del dedicado.
7. C23 frente a `GodType.cast_fx_path`: ver la pregunta 3.

## 1. Objetivo
- Un FX es un **recurso tipado** asignado en el inspector: `ParticleType`, `BeamType` o `PackedScene` con raíz `FxScene`. Ningún nodo del producto nombra un FX con texto, y C17 (ampliado) termina en 0.
- Un FX que sale de un cuerpo sale de un **socket** del `BodyFrame` (`Center`, `Top`, `Feet`, `Muzzle`, leídos por `BodyFacts`) o de un `Marker3D` de su escena. C16 baja de 27 a 19.
- La red manda un **id derivado** (la ruta del recurso). Solo `FxWire` lo convierte de vuelta, en la frontera. El servidor dedicado nunca instancia un FX y la simulación nunca lo lee.
- Lo editable vive en el FX: atlas, tamaño, luz `FxLightSpec` (el color del hechizo), `SoundCue` y sacudida de cámara. Sale `ShakeMap.trauma_by_fx`, que buscaba por nombre.
- Los sprites aditivos sobre atlas se mantienen: no se pasa a `GPUParticles3D`.
- Las chispas de `CarryRope` pasan al pool de `FxBus`: nada instancia `CPUParticles3D` en plena partida.

## 2. Escena de prueba
`res://debug/fx/fx_sockets_lab.tscn` (F6, nueva): tres criaturas reales de tamaños distintos (cuerpos gnome, earthfling y jabberocky), un mago y el altar. Cámara fija a 12 m y 35°. `check_tick` pasa de caso. Cada caso dispara el componente real: Rockform, Play Dead, Stealth, Firewalking, Frozen, Petrified, Burning, Heal, Speedup, la ruptura del Pull, Summon y la caída del altar. El FX tiene que aparecer en el socket de ese cuerpo, no a una altura fija. `debug/fx/fx_gallery.tscn` pasa a ranuras tipadas `FxSlot`.

## 3. Árbol (resumen)
- **scenes/fx (x1):**
  - `fx_bus.tscn` es el autoload: `FxBus` (≤150 líneas) con los hijos `%Bursts: BurstPool` y `%Beams: BeamPool`.
  - Nuevos: `fx_wire.gd` y `fx_scene.gd`.
  - Cambian: `particle_type.gd` y `beam_type.gd` (+`camera_trauma`), `shake_map.gd` (sin `trauma_by_fx`), `sprite_particles.gd` (`replay(at, seed, dir)`), `fx_trail.gd`, `beam_fx.gd`, y `quake_ring.gd` y `spike_field.gd` (pasan a extender `FxScene`).
  - Fuera de la carpeta: `body_facts.gd` (enum `Socket` y `point()`), `camera_shake.gd`, `fx_sounds.gd`, `burning.gd`, `falling_chunk` y `wall_spirit` (raíz `FxScene` + `%Mesh`), y los 14 dueños de `play(params)` pasan a extender `FxScene`.
  - `camera_trauma` en 9 `.tres` y en 4 raíces; `shake_map.tres`.
- **x2:** `scenes/spells/**` salvo `actions/`, `wards/`, `caster.gd`, `chain/chain_strike.gd` y `zones/bolt_launcher.gd`.
- **x3:** `caster.gd`, `actions/*.gd/.tscn` (31 escenas), `wards/ward.gd`, `aura_impact.gd`, `god_type.gd` + 2 `data/gods`, `hand_fx.gd`, `wizard_sounds.gd` y una línea de `wizard_body.gd`.
- **x4:** `scenes/units/**` salvo `passives/`, `death_clouds/`, `creature_type.gd`, `unit.tscn`, `unit_mana_support.gd` y `creature_fx.gd`. Incluye `abilities/rock_shell.tscn` (nuevo), los 24 `data/shots`, `chain_strike` y `bolt_launcher`.
- **x5:** `carry_rope`, `ritual_fx`, `pump`; `altar_collapse` y `altar.tscn` (`BurstSpot`); `manafount.tscn` (`SummonSpot`); y `Texture2D` tipadas en `tether`, `portal_look`, `portal_disc`, `spike_field` y `order_marker`.
- **x6:** `rend_soul`, `breath_of_life`, `lob_ability` y `halo_of_earth` (`rock_tag`) pasan a `look: PackedScene`; también `shot_look`, `ranged_shot` y `shot_spawner`.
- **x7:** `fire_shield`, `lightning_charge` y `death_clouds` (después de 055c5, ya integrado). `FxBus` deja de aceptar texto; salen `bus_name`, `fx_name`, `FxAtlas.texture`. Allowlist de C18c, C17 = 0, base del lint y cierre del RFC.
- **debug y agent:**
  - nuevos: `fx_sockets_lab.*`, `fx_slot.gd`, `fx_wire_cases.gd`, `fx_sockets_capture.gd`, `fx_net_probe.gd`;
  - cambian: la galería, los bancos de pool y los listeners de `played`.
- **tools:** `tools/migrate/fx_refs_055x.py` (nuevo, lo crea x1). Reescribe `campo = "nombre"` → `ExtResource`, con `--dry-run`.

## 4. Responsabilidades
| Pieza | Hace | No hace |
|---|---|---|
| `FxBus` | API única (`play`, `puff`, `broadcast`, `play_beam`, `broadcast_beam`, `play_scene`, `broadcast_scene`), los RPC y la señal `played(kind, fx, at)` | Pools, ids, cuerpos |
| `BurstPool` / `BeamPool` | Pool por tipo, precalentado recursivo al arrancar el cliente; nunca headless | Red, sonido |
| `FxWire` | `id_of(res)` (la ruta) y `resource(id)` con caché: la única conversión de texto a FX | Reproducir |
| `FxScene` | Raíz de un FX de escena: `play(params)` y `camera_trauma` (leído por SceneState, cacheado) | Reglas |
| `ParticleType` / `BeamType` | Atlas, tiempos, `light`, `sound`, `camera_trauma` | Dónde se juegan |
| `BodyFacts` | `Socket {FEET, CENTER, TOP, MUZZLE}` y `point(body, socket)` | Instanciar |
| `ShakeMap` / `CameraShake` / `FxSounds` | Caída por distancia / sacudida del recurso / sonido del recurso | Buscar por nombre |
| Nodos de gameplay | `@export var x_fx: ParticleType` + `@export var socket` → `FxBus.broadcast(fx, BodyFacts.point(body, socket))` | Calcular alturas |
| `Caster` | Replica `cast_fx_shown` (id) y expone `cast_fx()` / `is_casting()` | Dibujar la mano |

## 5–6. Composición, Resources y nodos
`fx_bus.tscn` es un autoload compuesto, como `sound_bus.tscn`. Los FX de escena tienen raíz `FxScene` (profundidad 1). El socket es un nodo del cuerpo; fuera de un cuerpo, es un `Marker3D` de la escena del lugar (`BurstSpot`, `SummonSpot`). La cáscara de Rockform pasa a `rock_shell.tscn`, que solo se instancia con `BodyLook.loads_meshes()`. Un solo dueño del FX de la mano: `Caster.cast_fx_shown`.
Qué es cada cosa:
- Tipos: `ParticleType` y `BeamType` (`data/fx`); la luz es un `FxLightSpec` dentro del FX.
- FX de escena: `PackedScene` con raíz `FxScene`.
- Qué FX dispara un nodo: `@export` en su `.tscn`. En los nodos que viven dentro de `unit.tscn` o `wizard_body.tscn`, el default es `preload` en el script.
- Dónde sale: `@export var <rol>_socket: BodyFacts.Socket` o un `Marker3D`.
- Sacudida: en el FX. La caída por distancia está en `ShakeMap`.
- Mano del dios: `GodType.cast_fx: ParticleType`.
- Hechizo: `SpellAction.cast_fx`.

## 7. Los seis verbos
| Verbo | Qué abre y qué toca | Lugares |
|---|---|---|
| Entender | `scenes/fx/README.md`; el nodo muestra `x_fx` y `x_socket`; el `.tres` muestra atlas, luz, sonido y sacudida juntos | 1–2 |
| Modificar | El look en el `.tres`; arrastrar otro `.tres` al campo; el socket por enum, o mover el `Center` del cuerpo con el gizmo | 1 |
| Agregar | Duplicar un `.tres` y arrastrarlo al campo | 2 |
| Quitar | Vaciar el campo | 1 |
| Crear | Escena con raíz `FxScene`, arrastrada al `@export PackedScene` | 2 |
| Escalar | Más `.tres`: el pool se precalienta solo y el id sale de la ruta | 1 por FX |

## 8. Contratos
```gdscript
# BodyFacts (x1)
enum Socket { FEET, CENTER, TOP, MUZZLE }
func local(socket: Socket) -> Vector3
static func point(body: Node3D, socket: Socket) -> Vector3   # body.global_transform * of_body(body).local(socket); without a mount, the default

class_name FxWire extends RefCounted
static func id_of(fx: Resource) -> String     # resource_path; "" + push_error if embedded
static func resource(id: String) -> Resource   # loaded once and cached
static func label_of(fx: Resource) -> String   # logs only

class_name FxScene extends Node3D
@export_range(0.0, 1.0, 0.01) var camera_trauma := 0.0
func play(_params: Dictionary) -> void: pass
static func trauma_of(scene: PackedScene) -> float   # SceneState, cached

# FxBus
signal played(kind: StringName, fx: Resource, at: Vector3)
func play(fx, at: Vector3, dir := Vector3.ZERO) -> void   # x7: fx: ParticleType
func puff(fx, at: Vector3) -> void
func broadcast(fx, at: Vector3, dir := Vector3.ZERO) -> void
func play_beam(beam, from, to, follow: Node3D = null) -> void
func broadcast_beam(beam, from, to, follow: Node3D = null) -> void
func play_scene(scene, at, params: Dictionary) -> void
func broadcast_scene(scene, at, params: Dictionary) -> void
func next_particle_seed() -> int
# Transition x1..x6: `fx` may be a String (old name or scene path), resolved to the Resource BEFORE `played` and the RPC.
# The RPCs keep their signature; the value becomes FxWire.id_of(resource). x7 removes the String branch.
# Headless: emits `played` and returns; nothing instanced.

static func ignite(target, damage, lifetime, kind, from_slot, mana_drain := 0.0, pierce := false, fx = null, attacker: Node = null) -> Burning   # Burning (x1)
static func launch(scene, from, shooting, from_point, target, ground_point, damage, tag, with_retarget := true,
		beam: BeamType = null, travel_s := -1.0, seat := -1, hit: ParticleType = null) -> LightningStrike   # x4

# Caster (x3)
signal cast_changed(casting: bool, fx: ParticleType)
@export var cast_fx_shown := ""   # SAME name and type (WIRE CONFIG unchanged): FxWire id, BARE or ""
const BARE := "-"
func is_casting() -> bool
func cast_fx() -> ParticleType
# GodType (x3): @export var cast_fx: ParticleType (replaces @export_file cast_fx_path)
# SpellAction (x3): @export var cast_fx: ParticleType (null = the god's)
```
Reglas:
- El servidor llama `broadcast*` con lo que ya tiene en sus `@export`, nunca con `load` por nombre.
- En el dedicado, los `ParticleType` se cargan con el atlas como placeholder y el `SoundCue` vacío, y no se instancia ningún FX.
- Nada de `load()`/`find()` por frame.
- Ninguna búsqueda por tag fuera de `FxWire` y del default del spawner de disparos.

## 9. Sub-cortes
| Sub | Qué | Depende de | Paralelo con |
|---|---|---|---|
| **x1** núcleo | Todo lo de x1 en §3, más el script de migración, C17 ampliado + base y el README | — | (va primero) |
| **x2** hechizos | 12 literales a `@export`; fuera `bus_name`, `name_of` y `resource_path`; `heal_effect`, `speedup_effect` y `summoner` con socket `CENTER`; `wall_spikes.texture` | x1 | x3, x4, x5 |
| **x3** lanzamiento | Contrato de `Caster`, `SpellAction.cast_fx`, las 31 escenas de acciones por script, beam, out/in, pups, structure (`SummonSpot`), `GodType.cast_fx`, `HandFx`, `Ward`, `aura_impact`, `WizardSounds`, la pose | x1 | x2, x4, x5 |
| **x4** unidades | Habilidades, aflicciones, estado, impactos, ataques, strikes y gib con sus sockets (§3), `rock_shell.tscn`, `ShotLook` y los 24 `data/shots`, `LightningStrike.launch`, los C21 de `quake_wave`/`ground_hug_flight`/`spike_wave`, y los casos del lab | x1 | x2, x3, x5 |
| **x5** sacrificio, mapa y texturas | `CarryRope` → `FxBus.play` (sin `instantiate`), `ritual_fx`/`pump`, `BurstSpot`, `SummonSpot`, texturas tipadas | x1 | x2, x3, x4 |
| **x6** looks de disparo | `look_tag`, `rock_tag` y `shot_tag` → `look: PackedScene`; los datos de spawn llevan `"look"` | x4 | x5 |
| **x7** cierre | Pasivas y nubes de muerte; `FxBus` estrecho; fuera las APIs de texto; allowlist de C18c; C17 = 0; base; RFC | x1–x6 | — |

Lint esperado al cerrar x7: C17 (ampliado) a 0 · C16 27 → 19 · C15 28 → 26 · C13 6 → 2 · C21 5 → 1 · C7 54 → 52 · C1b 16 → 15 · C18c sigue en 0.

## 10. Pruebas (una pasada al final)
1. Lint.
2. `rules_suite` con `fx_wire_cases`: ida y vuelta de cada recurso FX, 0 fallas y 0 ids vacíos.
3. Línea de tiempo del ritual idéntica 7/7. Si difiere solo en los casos con `CarryRope`, se regraba con una nota (R2).
4. NET QUICK con WIRE CONFIG idéntica.
5. `fx_net_probe`: ≥ 98 % de los bursts llegan al cliente, 0 ids sin resolver y las mismas etiquetas a los dos lados.
6. Dedicado ≤ 2,6 s y ≤ 350 MB, con 0 hijos en `%Bursts`/`%Beams`.
7. Capturas del lab:
   - |`at` − socket| ≤ 0,01 m;
   - el centroide de los píxeles brillantes a ≤ 16 px de la proyección del socket;
   - el tono de esos píxeles a ≤ 20° del color de la luz;
   - el suelo bajo el mago no se tiñe.
8. Galería: las ranuras igualan a los `ParticleType`, con los mismos topes de pool.
9. A ojo: Firewalking, Play Dead y Stealth.

## 11. Riesgos
- **R1, red:** el id (la ruta) es más largo que el nombre; se mide en el probe y, si molesta, se acorta en `FxWire`. Si el defecto está en el transporte, el arreglo va a MpKit como hotfix del kit.
- **R2, digest:** `CarryRope` hoy saca números del RNG global. Con el pool deja de hacerlo, y puede mover la línea de tiempo: se regraba en x5.
- **R3, look:** las alturas fijas pasan a sockets. x4 verifica en `state.d` antes de elegir socket; si el original usa otro punto, se agrega un `Marker3D` al `BodyFrame`, no un número.
- **R4, servidor:** se espera menos de 5 MB más en el dedicado.
- **R5, transición:** mientras `FxBus` acepte texto, un nombre mal escrito avisa una sola vez con `push_warning`. x7 lo cierra.
- **R6:** `caster.gd` y `halo_of_earth.gd` siguen largos; partirlos queda fuera de alcance.
- **R7, merge:** el script de migración toca carpetas disjuntas en cada sub-corte.

Fuera de alcance: almas (`soul.gd`, `soul_strike`), C15 de los materiales en código (055z), `GPUParticles3D`, sangre (RFC-060), la IA.

## 12. Preguntas (recomendaciones aprobadas)
1. El id de red es la ruta del recurso.
2. La sacudida vive en el FX; `ShakeMap` se queda solo con la caída por distancia.
3. `GodType.cast_fx: ParticleType`: sí.
4. Se mantiene `cast_fx_shown: String` (mismo nombre y tipo); su valor es el id.
5. Socket puro, sin desplazamiento; si hace falta otro punto, un `Marker3D` en el `BodyFrame`.
6. `FallingChunk` y `WallSpirit` se envuelven en una raíz `FxScene` + `%Mesh`.
7. Los looks de disparo por tag van en x6.
8. FX de nodos dentro de `unit.tscn`/`wizard_body.tscn`: default por `preload` en el script.
9. Precalentar también `spells/` y `wards/`: sí.
10. `GPUParticles3D`: no.
