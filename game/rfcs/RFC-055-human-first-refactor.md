# RFC-055: refactor «como lo haría una persona» (human first, Godot priority)

Estado: plan del tech lead, 2026-10-23, sin código. Arquitectura declarada: estándar (RULES). MP: online con dedicado; este RFC no agrega RPC ni toca `addons/mp_kit`.
Autoridad: decisión del usuario 2026-10-23 («que no sea un 1 a 1», «nativo de Godot, sin sistemas intermedios») > PRD > FEATURES > RULES > VISUAL > RFC-036/044/048/054 > este plan.
Plan general de los pedidos del usuario: `docs/PLAN-v2.md`.

## 0. Contradicciones entre artefactos

| Choque | Gana |
|---|---|
| El usuario pide considerar Clean (domain/core/features). RULES y PRD dicen estándar, sin `src/domain/`. | RULES/PRD hasta que el usuario los edite. §6 propone capas dentro del estándar. Si quiere Clean formal, es una línea en RULES y un RFC de mudanza; nada de lo propuesto lo impide. |
| El usuario pide selector de dificultad y de mapa en el boot. `scenes/core/boot.tscn` ya tiene `%AiLevel` (F294) y `%MapPicker` (F290/F297); `boot.gd:54-74` los lee. | Ya existen. Pasa a «revisar que se vean» (orden, etiqueta, visibilidad solo en «Contra la IA»). |
| VISUAL: «el cielo original queda siempre disponible como modo legacy». El usuario pide simplificar el cableado del cielo. | VISUAL. El modo legacy se conserva; se funden los tres escritores del `Environment` y las dos cadenas de datos. |
| RULES §Fidelidad: del original se copia solo lo que se nota al jugar. 235 de 480 scripts citan sacengine. | Los comentarios quedan donde explican un número. Los datos crudos (`flags`, `folder`, `Array[Dictionary]`) salen del inspector (055c/055d). |

## 1. Objetivo

- Una persona abre una escena o un `.tres` y cambia un comportamiento o un look sin leer código: muerte, criatura, cielo, mapa, hechizo.
- Muerte con física de Godot: el cuerpo cae como ragdoll (un volador cae, hoy flota), el alma sube desde el cadáver; con Convert el cadáver se desvanece y la criatura reaparece de pie junto al alma. Sin barra de vida sobre un cadáver mientras un doctor lo trabaja.
- Unidad = escena con hijos visibles: visión como `Area3D` (esfera o cono), armas y ataques como nodos, stats en un `.tres` sin campos crudos.
- Mapa = nodos del editor: edificios, NPC, árboles, arcos y rocas como nodos movibles, con un placeholder de bioma que el `LookProfile` reemplaza por el modelo del dios.
- Cielo y look: un dueño del `Environment`, una cadena de datos por dios; cambiar el cielo de Pyro = un `.tres`.
- La simulación sigue determinista para el dedicado: todo lo nuevo de física es presentación y nunca escribe en la sim.

## 2. Inventario (medido en `game/`)

Totales: `scenes/` 480 `.gd` / 58 612 líneas (con `mp_kit` y `fsm_kit`); 19 dominios; `data/` ≈ 1 100 `.tres` (`catalog/` 795); `addons/` 4; `tools/` 26 gd + 35 py / 10 495 líneas; `debug/` 165 `.tscn` + 127 `.gd`; `agent/flows` 566.

| Sistema | gd / tscn / líneas | Dueño del estado | Archivos a tocar para cambiar un comportamiento | Acople a datos de sacengine |
|---|---|---|---|---|
| Unidades `scenes/units/` | 133 / 80 / 13 398; `unit_body.gd` 750; `unit.tscn` 56 hijos; 11 `UnitState` | `UnitBody.mode`, `Health.current`, `Flight.state`, `Corpse.dissolving`; 21 props replicadas | «Qué pasa al morir»: `unit_body.gd`, `dead_state.gd`, `corpse.gd`, `soul_system.gd`, `captive.gd`, `unit_health_bar.gd` = 6 archivos, 3 dominios | Alto: `CreatureType` con 15 `Dictionary` de clips, `ability_tags` por tag crudo |
| Cuerpos `scenes/bodies/` | 14 / 75 / 1 516; 74 `models/<tag>.tscn` | `BodyModel.clips` | Una animación: abrir `models/<tag>.tscn`. Bien. | Medio: `clips` y `surface_parts` crudos |
| Componentes | 4 / 0 / 454 | `Health`, `ManaPool`, `SoulPurse` | 1 | Bajo |
| Magos `scenes/wizards/` | 5 / 1 / 979 | `WizardBody`; `Spellbook` deriva de `GodType.book` | Un hechizo: `.tres` + escena `SpellAction` + fila en `data/gods/<god>.tres` = 3. Ya «como persona». | Medio: `WizardType.*_animation` |
| Hechizos `scenes/spells/` | 32 / 14 / 3 369; `caster.gd` 449 | `Caster._active`, cooldowns | `.tres` + `actions/<x>.tscn`. Bien. | Alto en datos: `SpellType.flags/flags1/flags2` |
| Dioses | 3 / 0 / 104 | `GodType.tres` ×5 | 1 `.tres` | `theme_path`/`look_path` como strings |
| Estructuras | 4 / 1 / 342 | `BuildingType` ×196 | 1 `.tres` | Muy alto: `flags = 2147493904`, `folder = "joby.WAD!/…"`, `components: Array[Dictionary]` |
| Almas | 2 / 2 / 634 | `Soul.state` replicado; `SoulSystem` | 2 | Medio |
| Sacrificio | 23 / 6 / 2 341 | `SacrificeSystem`, `Captive`, `Ritual` | Convert visual: 4 archivos | Medio |
| Mapa / layout / nav | 27 / 18 / 3 339; `peaks/layout.tscn` 35 `MapBuilding` | `map.tscn` + `layout.tscn`, `MapDefinition`, `nav.res`, `flora.res` | Mover una casa: gizmo (ya). Poner un árbol a mano: no se puede | Alto en `BuildingType`/`FloraMap` |
| Look / cielo | 41 / 11 / 4 699 | Tres escritores del mismo `Environment` (`ThemeApplier`, `SkyLayer`, `LightLayer`); dos cielos; dos cadenas de datos | Cielo de Pyro: ~30 archivos (§2.1) | Alto: `GodEnvi` lo pisa `import_themes.py` |
| IA | 35 / 1 / 5 324 | `AiSide`; perfiles `.tres` | Un cerebro nuevo: `brains/` + `ai_roster.gd` | Medio |
| Órdenes / selección / cámara | 22 / 1 / 2 527 | `Selection`, `Orders` | Bien (RFC-038) | Bajo |
| HUD / UI | 65 / 40 / 6 046 | `.tscn` + `strings.csv` | 1 escena por pantalla | Bajo |
| Match / core / net | 22 / 6 / 3 016 + 5 390 addon | `MatchState`, `MatchRules`, `MatchClock`, `MatchSeed` | Bien | Bajo |
| FX / audio | 48 / 15 / 4 945 | `FxBus`, `SoundBus` | 1 `.tres` por efecto | Bajo |
| Tools | 26 gd + 35 py | horneados | Cambiar la forma de un `.tres` = builder + bake + clase + rehornear | Es la fuente de lo crudo |

### 2.1 Ejemplo trabajado: cambiar el cielo de Pyro

Lo que cruza hoy quien quiere «el cielo de Pyro más oscuro con nubes más lentas»:
1. `data/gods/pyro.tres`: `theme_path` y `look_path` como strings.
2. `data/themes/pyro.tres` (`GodTheme`): el color de fondo no está acá.
3. `assets/original/themes/pyro/envi.tres` (`GodEnvi`): lo escribe `import_themes.py`; editarlo a mano se pierde.
4. `assets/original/themes/pyro/{skyt,skyb,sky}.png`: `sky.gd` arma la ruta con `OriginalAssets.theme()`.
5. `theme_applier.gd`: duplica el `Environment`, escribe fog/ambient/sol y llama a `LookApplier`.
6. `match_biome.gd`: sortea el dios y lo aplica.
7. `look_applier.gd` → `look_rig.gd/.tscn` → `look_layer.gd` → `sky_layer.gd/.tscn`: vuelve a duplicar el `Environment`, decide LEGACY o SWIRL.
8. `data/look/pyro.tres` → `data/look/sky/pyro_sky.tres` (93 líneas de knobs, varios neutros) y `pyro_sky_swirl.tres`.
9. Piezas: `sky_piece.gd`, `sky_discs.*`, `sky_swirl.*`, 4 shaders.
10. `data/look/light/pyro_light.tres` + `light_layer.gd`: tercer escritor del `Environment`.
11. `scenes/map/maps/<mapa>/map.tscn` ×7: cada uno instancia `Sky`, `Environment`, `Look`, `Sun` y cablea sockets.
12. `look_quality.gd` / `quality_applier.gd` + presets.

Total: ≈ 30 archivos en 6 carpetas, 3 escritores del `Environment`, 2 cielos, 2 cadenas de datos, 1 importador que pisa un `.tres`. La velocidad de las nubes es un `@export` de `sky.tscn`, que cada mapa instancia: cambiarla para Pyro obliga a tocar código o 7 mapas. Después de 055b: `data/look/sky/pyro_sky.tres`, 1 archivo.

## 3. Grupos y puntaje

E = editabilidad hoy, N = nativo de Godot hoy (1–5); costo S/M/L/XL; G = ganancia visible (1–5).

| Grupo | E | N | Costo | G | Nota |
|---|---|---|---|---|---|
| A. Muerte / cadáver / alma / Convert | 2 | 2 | M | 5 | Lo que el usuario más siente. Primero. |
| B. Look / cielo / Environment | 1 | 3 | M | 4 | 30 archivos → 1. Segundo: barato y el usuario ya chocó con esto. |
| C. Unidades como escena | 3 | 3 | XL | 3 | Mucho código, poco cambio visible. Tercero, en sub-cortes. |
| D. Mapa / layout / flora | 3 | 3 | L | 4 | Cuarto. |
| E. Mago + libro | 4 | 4 | S–M | 2 | Ya casi: falta limpiar `SpellType.flags*` y `WizardType.*_animation`, y un `@export book` de override. Quinto. |
| F. Estructuras | 2 | 3 | M | 3 | Entra con D. |
| G. IA (NPC que huyen, dificultad) | 3 | 3 | M | 3 | Backlog. |
| H. HUD / UI | 4 | 5 | S | 2 | Revisar el boot. |
| I. Red / MpKit / match / core | 4 | 5 | — | 1 | No se toca. |
| J. FX / audio / luces | 4 | 4 | M | 4 | Luces por hechizo = packed scene por acción. |
| K. Tools / import / bake | — | — | M | 0 | Cambia con C y D. |

## 4. Orden propuesto

El cielo (B) sube al segundo lugar: es el corte más barato, es donde el usuario se frenó, y no toca la sim. Unidades (C) pasa al tercero, en sub-cortes.

| Corte | Qué | Sim / presentación | Regraba `quick` |
|---|---|---|---|
| **055a** | Muerte humana: ragdoll + caída del volador + alma que sube + Convert con fade y reaparición + barra con un solo dueño (§5). | Sim: el volador cae y el cadáver se asienta por física del `CharacterBody3D`. Presentación: ragdoll y fades. | Sí |
| **055b** | Un dueño del look: `EnvironmentLayer` único escritor; `GodTheme`+`GodEnvi` se funden en `LookProfile` (un `.tres` por dios con sub-recursos `sky/light/ground/grass` tipados); `SkyLook` absorbe texturas y knobs del cilindro legacy; `ThemeApplier` desaparece; `GodType.look: LookProfile` tipado; los 7 `map.tscn` dejan de instanciar `Sky` suelto. | Presentación | No |
| **055c** | Unidad como escena, en sub-cortes: c1 `CreatureType` limpio (clips a `BodyModel`, habilidades como referencias tipadas); c2 `Vision` = `Area3D` hijo (esfera o cono por `angle_deg`) que alimenta a `SideVision`; c3 armas como nodos (`MeleeWeapon`, `RangedWeapon`, `Ability` bajo `Weapons/` con `WeaponType.tres`); c4 giro hacia la velocidad real. | c2–c4 sim | Sí |
| **055d** | Mapa de editor: `BuildingType` humano (`display_name`, `max_health`, `shelter`, `destructible`, `parts: Array[BuildingPart]`); nodo `BiomeProp` (`kind: tree/rock/arch…`, el `LookProfile.props` lo resuelve al modelo del dios; placeholder gris sin set); nodo `VegetationPatch` (`species`, `radius_m`, `count`, `seed`) para plantar a mano; `PeaksLayout` pasa a `Buildings/`, `Npcs/`, `Props/`. | Edificios/NPC sim (ya); props y patches presentación | No, salvo props con colisión |
| **055e** | Mago + libro: `WizardBody.book: GodBook` de override; `SpellType.flags*` → booleanos con nombre; `WizardType.*_animation` a su `BodyModel`; `structures` → `Dictionary[StringName, PackedScene]`. | Datos | No |
| **055f…** | Backlog por visibilidad (§8). | — | — |

## 5. Corte 055a: muerte humana, árbol completo

### 5.1 Qué pasa hoy
- **El volador flota muerto.** `unit_body.gd:527-531` sostiene la altura antes de consultar al estado; `DeadState.rests_on_floor()` da `true` pero el gate exige `is_on_floor()`, que un volador muerto nunca cumple. sacengine (state.d:14026-14030) lo hace caer (`tumbling`) y recién en el suelo lo mata y suelta el alma. Parche provisorio en `bb324052`.
- **Barra sobre el cadáver con doctor.** `DeadState.exit()` la muestra al pasar a HELD/REVIVING; `Captive.revive()` sube la vida y `UnitHealthBar` la muestra. Dos escritores de `visible`.
- **El cadáver se para en el lugar.** `Corpse.stand_up()` es el Tween al revés. Sin fade ni reaparición.
- **La caída es un Tween** sobre `Tilt` y la sim depende de su `finished` para `settled` → alma. Un Tween como reloj de simulación es frágil.

### 5.2 Diseño: quién es dueño de qué
- **Sim, determinista, en ticks:** `Corpse` es un contador. `fall_ticks` para un cuerpo en tierra (0,91 s · 60, como hoy); en el aire, gravedad del `CharacterBody3D` hasta `is_on_floor()` (tope `max_fall_s`); entonces `settled`. El gate de `hold_height` consulta `rests_on_floor()` primero. Nada nuevo se replica.
- **Presentación:** `CorpseLook` escucha `body.mode_changed` y `Corpse.settled/dissolving` y elige ragdoll si el modelo tiene `PhysicalBoneSimulator3D`; si no, `TippingFall` (el Tween de hoy). Fades con `BodyVisual.set_fade`. En headless o dedicado no se crea.
- **Capas de física:** huesos del ragdoll en capa nueva «ragdoll» (bit 5, valor 16), máscara 1 (solo suelo). La cápsula del cuerpo sigue en la capa 8.
- **Deriva visual vs sim:** el alma y el pick siguen a `UnitBody.soul_anchor()`. El ragdoll se congela a los `settle_s`; si quedó a más de `max_drift_m`, `CorpseLook` lo acerca con un Tween corto.

### 5.3 Árbol de nodos

```
Unit : CharacterBody3D                      unit_body.gd        [~] gate: si current_state().rests_on_floor() → gravedad, antes de hold_height
├── Tilt : Node3D
│   └── Mesh : MeshInstance3D (BodyVisual)  (igual)
│       └── Rig → ModelSlot → models/<tag>.tscn
│               └── Model / Skeleton3D
│                   └── Ragdoll : PhysicalBoneSimulator3D       [+] horneado por tools/bake/bake_ragdolls.gd: un PhysicalBone3D
│                       ├── Bone_<n> : PhysicalBone3D ×k           (CapsuleShape3D) por hueso ≥ min_bone_m; joints PIN/CONE;
│                       └── …                                      layer 16, mask 1. Vive en el .tscn: se edita a mano después.
├── Collision : CollisionShape3D            (igual)
├── Health : Node (Health)                  (igual)
├── Corpse : Node (Corpse)                  corpse.gd           [~] SIM: capas/grupos, fall_ticks, max_fall_s, dissolve_s, dissolving (replicado).
│                                                                   Señales: settled, dissolving_changed(bool), stood_up. Sin Tween ni pivot.
├── CorpseLook : Node (CorpseLook)          corpse_look.gd      [+] PRESENTACIÓN. Sockets: body, corpse, visual, ragdoll, fallback.
│   ├── RagdollDriver : Node                ragdoll_driver.gd   [+] start(impulse), freeze(), reset(). Knobs: push_back_m_s, settle_s,
│   │                                                               max_drift_m, bone_damping. Sin simulador en el modelo → available() false.
│   └── TippingFall : Node                  tipping_fall.gd     [+] el Tween de hoy sobre pivot (anticipation/fall/settle, stand_s).
│                                                                   Fallback y pose instantánea para quien entra tarde.
├── States : FsmMachine
│   ├── Dead : UnitState                    dead_state.gd       [~] solo sim: target = null, cancel_attacks(), rests_on_floor() true.
│   ├── Reviving : UnitState                reviving_state.gd   [+] marca el modo; CorpseLook hace fade-out y fade-in de pie en soul_anchor().
│   └── (Idle, Move, …)                     (igual)
├── Captive : Node (Captive)                captive.gd          [~] revive() sin look: pide corpse.stand_up() (sim) y emite revived.
├── HealthBar (unit_health_bar.tscn)        unit_health_bar.gd  [~] ÚNICO dueño de visible: not health.is_dead() and not body.is_taken().
├── Flight / Air / Avoidance / …            (igual)
└── UnitSounds, OmniLight3D                 (igual)

Soul (soul.tscn)                            soul.gd             [~] @export_group("Rise") rise_m := 1.0, rise_s: mientras EMERGING el sprite
                                                                    sube desde el centro del cadáver. Presentación.
```

Quién habla con quién:
- `Health.died` → `UnitBody._on_died` → `mode = DEAD`; el setter emite `mode_changed` en todos los peers (ya).
- `mode_changed(…, DEAD)` → `CorpseLook`: `ragdoll.available()` ? `ragdoll.start(push)` : `fallback.lay_down()`. En el proceso que simula, `DeadState.enter` llama `Corpse.begin_fall()`.
- `Corpse.settled` (sim) → `SoulSystem._spawn_on_corpse` (igual) y → `CorpseLook.freeze()`.
- `Soul.state == EMERGING` → su `Rise`.
- `Captive.revive()` (sim) → `mode = REVIVING` → `CorpseLook`: `fade_out` → `ragdoll.reset()` / `fallback.stand_up(instant)` → `visual.set_fade(1→0)` en pose `idle`. El cuerpo ya está en `soul_anchor()`: «reaparece junto al alma» sin mover la sim.
- `Corpse.dissolving_changed(true)` → `CorpseLook.fade_out`.
- `UnitHealthBar` escucha `Health.changed` y `body.taken_changed`; nadie más escribe `visible`.

Qué edita una persona en el inspector:
- `unit.tscn` → `CorpseLook/RagdollDriver`: empuje, amortiguación, segundos hasta congelar, deriva máxima. `CorpseLook`: `corpse_fade_s`, `revive_fade_s`, `fade_s`.
- `unit.tscn` → `Corpse`: `fall_ticks`, `max_fall_s`, `dissolve_s`.
- `models/<tag>.tscn` → `Skeleton3D/Ragdoll`: cada `PhysicalBone3D` con el editor de Godot («Create physical skeleton» lo rehace).
- `soul.tscn`: `rise_m`, `rise_s`.

### 5.4 Archivos y responsabilidades

```
scenes/units/unit.tscn               [~] CorpseLook (+RagdollDriver, +TippingFall), Reviving, HealthBar.body
scenes/units/unit_body.gd            [~] orden del gate (~10 líneas)
scenes/units/corpse.gd               [~] sim pura (~−80 líneas)
scenes/units/corpse_look.gd          [+] ~120
scenes/units/ragdoll_driver.gd       [+] ~90
scenes/units/tipping_fall.gd         [+] ~70 (el Tween de hoy, movido)
scenes/units/unit_health_bar.gd      [~] único dueño de visible
scenes/units/captive.gd              [~] revive() sin look
scenes/units/states/dead_state.gd    [~] sin HealthBar ni Corpse.lay_down
scenes/units/states/reviving_state.gd [+] ~20
scenes/units/death_rules.gd          [+] reglas puras (§6)
scenes/souls/soul.gd, soul.tscn      [~] grupo Rise
scenes/bodies/models/<tag>.tscn ×74  [~] Skeleton3D/Ragdoll (lo escribe el bake; no pisa el existente)
tools/bake/bake_ragdolls.gd          [+] ~150; entrada en el plugin Sacrifice
project.godot                        [~] layer_names/3d_physics/layer_5 = "ragdoll"
debug/units/death_ragdoll.tscn, death_ragdoll_rules.tres, death_ragdoll_flier_rules.tres  [+]
```

| Pieza | Responsabilidad | No hace |
|---|---|---|
| `Corpse` | Reloj de la muerte en ticks y capas del cadáver; `dissolving` replicado | Animar, fundir, saber de huesos |
| `CorpseLook` | Elegir y encadenar el look de DEAD / REVIVING / dissolve | Escribir en la sim; correr en headless |
| `RagdollDriver` | Prender, congelar y acercar el ragdoll | Crear huesos |
| `TippingFall` | El tumbado por Tween, fallback y pose instantánea | Decidir cuándo |
| `DeadState` | Lo que la sim deja de hacer muerta | Tocar la barra o el pivot |
| `RevivingState` | Marcar el modo | Animar |
| `UnitHealthBar` | Único dueño de su `visible` | Ser escrita por estados |
| `Soul.Rise` | Subir el sprite al emerger | Mover la posición replicada |
| `bake_ragdolls.gd` | Escribir una vez el simulador físico en cada modelo | Correr en partida; pisar lo editado sin `--force` |

### 5.5 Escena de prueba
`debug/units/death_ragdoll.tscn`: instancia `scenes/match/high_noon.tscn` con `death_ragdoll_rules.tres` (sin IA, semilla fija, maná y almas de sobra). Una criatura del jugador (`ycro`, slot 1, sin agresividad) a 6 m de una enemiga (slot 2, agresiva). Estado inicial: de pie, barras visibles. Lo que todavía no pasa: la caída ragdoll, el alma subiendo, el cadáver sin barra, el volador cayendo, el fade de Convert. La enemiga ataca sola; para Convert, armar el hechizo y clic en el alma roja. Variante `death_ragdoll_flier_rules.tres`: la víctima vuela.

### 5.6 Determinismo y red
- Cambia en la sim: un muerto en el aire cae por `move_and_slide` hasta `is_on_floor()` o `max_fall_s`; `settled` sale de ticks, no de un Tween. Solo donde simula. `quick` cambia para voladores; se regraba con la causa.
- No entra a la sim: huesos, impulsos, fades, `rise_m`. El dedicado no instancia `CorpseLook`.
- Nada nuevo en el `SceneReplicationConfig`. El que entra tarde recibe `mode = DEAD` y `dissolving`: `CorpseLook.present(false)` pone la pose congelada.

## 6. Clean vs estándar: capas dentro del estándar

Seguir estándar y hacer explícitas tres capas que el código ya insinúa, sin carpetas `domain/core/features`:
1. **Reglas puras:** `RefCounted` con `static func`, sin nodos ni autoloads, junto a su dominio (ya hay 67: `SacrificeMath`, `TargetRules`, `SplashDamage`, `KillEstimate`…). Regla nueva para RULES: si una función no necesita el árbol, es `static` en `scenes/<dominio>/<cosa>_rules.gd`. Testeables con GUT sin escena.
2. **Glue de escena:** nodos chicos que leen señales, llaman a una regla y escriben estado replicado (`Corpse`, `Captive`, `Caster`).
3. **Wrapper de red:** ya existe: `request_*` en el cliente → `submit_*` RPC → `apply_*` en el servidor. La IA usa el mismo puerto. Si MpKit se refactoriza, cambia solo esa cáscara.

Ejemplo (055a), `scenes/units/death_rules.gd`:

```gdscript
class_name DeathRules
extends RefCounted
## Pure: what a death resolves to. No nodes, no clock, no RNG.

enum Fall { TIP_OVER, DROP_FROM_AIR }

static func fall_kind(airborne: bool) -> Fall:
	return Fall.DROP_FROM_AIR if airborne else Fall.TIP_OVER

static func fall_ticks(kind: Fall, tip_over_ticks: int) -> int:
	return tip_over_ticks if kind == Fall.TIP_OVER else -1  # -1: until the body is on the floor
```

Lo que se queda como escena plana: todo el look, la UI, los mapas. No se crea `src/`, no hay use cases con `execute()`, no hay inyección de repositorios.

## 7. Riesgos y qué se pierde (aceptado: «que no sea un 1 a 1»)

| Riesgo | Mitigación |
|---|---|
| El volador muere donde cae; el alma aparece tras una caída variable | Aceptado. `fall_ticks` fijo para terrestres mantiene el digest de hoy en casos sin voladores. |
| Ragdolls de 74 modelos horneados a ciegas | Solo cápsulas en huesos ≥ `min_bone_m`, joints CONE conservadores; sin simulador → `TippingFall`. Galería para revisar de a 10. |
| 150 ragdolls activos no dan 60 fps | `settle_s` corto y `freeze()`; `max_active_ragdolls` en `LookQuality` (bajo = 0 → `TippingFall`). |
| Al fundir los escritores del `Environment` (055b) algún mapa pierde un color | Capturas con cámara fija de `debug/look/biome_gallery.tscn` antes/después, por dios. |
| Sin `flags` crudos (055c/e) se pierde un bit que el código lee | `grep -rn "\.flags" scenes` y tabla bit → booleano; `catalog_cases.gd` compara campo a campo. |
| `BuildingType.components` → `parts`: 196 archivos regenerados | Lo escribe `bake_catalog.gd`; `check_map_models.tscn` valida. |
| Los clips `death`/`fly_death` quedan sin usar | `CorpseLook.prefer_clip` (`@export`, default false). |
| 566 flows con rutas de nodo | 055a/b no renombran nodos; 055d mantiene `PeaksLayout` como raíz. |
| Un ragdoll queda fuera de su cápsula | `max_drift_m` + acercamiento; pick y alma usan `soul_anchor()`. |

## 8. Backlog del usuario, ubicado

| Pedido | Dónde cae | Diagnóstico |
|---|---|---|
| Unidades de espaldas deben girar | 055c4 | En sacengine las criaturas siempre encaran su dirección; `backward` es solo el mago con teclado. En el port `MoveState` gira hacia la dirección deseada, pero la evasión puede dar otra velocidad y el cuerpo la camina sin girar. Arreglo: girar hacia `velocity` plana. |
| Dificultad y mapa en el boot | H | Ya existen (`%AiLevel`, `%MapPicker`). Revisar orden y visibilidad. |
| Sin barra sobre el cadáver | 055a | Dos escritores de `visible`. |
| Aldeanos que huyen al golpe | G | `PeasantBehavior` huye de enemigos conocidos; confirmar que `Health.hit(from_slot)` alimenta `GrudgeMemory` al primer golpe. |
| Habilidades, estructuras, hechizos que faltan | E/F | Un `.tres` + una `SpellAction` cada uno. Volcán/tornado: RFC propio (terreno deformable). |
| Luces en hechizos y unidades | J | `light_unit.tscn` ya cuelga de `unit.tscn`; hechizos: `OmniLight3D` hijo de cada proyectil/acción con `LightLook` por dios. |
| Persephone más verde, árboles, arcos | 055d + `LookProfile` de Persephone | Datos. |
| Insectos, lluvia, día-noche, clima | B (capas nuevas del `LookRig`) | Después de 055b, con un solo dueño del `Environment`. |
| `FloraMap.counts` ilegible | 055d | Queda horneado como mapa de densidad, pero deja de ser lo único: `VegetationPatch` para plantar a mano. |

## 9. Orden de implementación

1. **055a-1:** `Corpse` a ticks + gate de gravedad + `RevivingState` + barra con un dueño. Sin ragdoll (`TippingFall` único). Escena de prueba + 2 `.tres`. `quick` → regrabar.
2. **055a-2:** `CorpseLook` + `TippingFall` + fades de Convert y dissolve + `Soul.Rise`.
3. **055a-3:** `bake_ragdolls.gd` sobre 5 modelos + `RagdollDriver`; revisar en galería; luego los 74.
4. **055a-4:** review + playtest con ventana + `all`.
5. **055b** en dos pasos: `EnvironmentLayer` único escritor; fundir `GodTheme`/`GodEnvi` en `LookProfile`.
6. **055c1 → c4**, cada uno con `quick`.
7. **055d**, **055e**, backlog.

## 10. Cómo lo verifica un humano en el editor
1. `scenes/units/unit.tscn`: sacar `RagdollDriver` → F6 en `debug/units/death_ragdoll.tscn` → la criatura se tumba con el Tween; ponerlo → cae como muñeco y se congela a los `settle_s`.
2. Con `death_ragdoll_flier_rules.tres`: la voladora muere, cae, y el alma sube desde el suelo.
3. Mientras cae no hay barra; Convert → el doctor llega, el cadáver se funde, la criatura reaparece de pie con fade, sin barra hasta que la sueltan.
4. `models/eorc.tscn` → `Skeleton3D/Ragdoll`: cambiar la masa de un hueso se nota.
5. `soul.tscn`: `rise_m = 3` sube más alto.
6. (055b) `data/look/sky/pyro_sky.tres`: cambiar `cloud_period_s` y ver el cambio en el editor con `preview_god = pyro`, sin F5.
7. Dedicado: `--dedicated` arranca sin `PhysicalBone` en el log.

## 11. Preguntas abiertas (con recomendación)
- **P1.** `fall_ticks`/`dissolve_s` en `Corpse` o en `MatchRules`: en `Corpse` (son look-timing).
- **P2.** ¿Ragdoll para el mago? No: pasa a fantasma (`GhostForm`).
- **P3.** ¿Impulso según de dónde vino el golpe? Empezar hacia atrás del `facing`; agregar `from: Vector3` a `Health.hurt` en 055c si se quiere.
- **P4.** ¿Capa 16 o reutilizar 8? Propia: la 8 la consulta el pick.
- **P5.** ¿Clean formal? No ahora (§6). Si el usuario lo decide, se edita RULES primero.

Fuera de alcance: refactor de MpKit (diferido), deformación de terreno (RFC propio), port web (RFC-039), pasto.

## 12. Addendum 2026-10-23: segunda ronda de análisis

Decisiones del usuario: estándar con tres capas aceptado (no Clean formal). Nada se afirma del original sin sacengine o REA. Investigación: `research/055R-original-reference.md` (original) y `research/055R-codebase-readability.md` (codebase y convenciones).

### 12.1 Corrección del inventario
`scenes/` tiene 480 `.gd` y 53 033 líneas; los addons suman aparte 51 `.gd` y 7 624 líneas. Sin `class_name`: 54 (no 72).

### 12.2 Lo que faltaba mapear (medido)
- Hechizos: el original tiene 53 no criatura y 51 criaturas (`nttData.d:1243-1258`). El port tiene los 53 `.tres` pero solo 12 lanzables (7 neutrales/estructura sin Shrine, y el nivel 1 de cada dios). Faltan 41: Shrine y los niveles 2 a 8 de los cinco dioses. Checklist en 055e.
- Edificios: 196 tipos con modelo; los mapas usan 82; Shrine tiene modelo y datos pero no acción. Checklist en 055d.
- Terreno: deforman Volcano (permanente), Bombardment (permanente), Erupt (temporal), Bore (temporal) y Quake del Jabberocky. El original: base + Δh por vértice en 256×256 cada 10 m; el pathfinding solo reacciona a agujeros. El port tiene 5 representaciones del suelo sin dueño (datos, malla, trimesh, navmesh, derivados) y 42 llamadas a `ground_height()` en 25 archivos.
- Doctor muerto cargando: el original suelta la criatura viva y aturdida (`state.d:15776-15779`). El usuario pide que caiga y su alma quede donde aterriza: gana el usuario («que no sea un 1 a 1»), con `MatchRules.carried_dies_when_dropped` apagable.
- Giro: en el original la criatura siempre avanza hacia donde mira, gira también para esquivar (π rad/s), nunca camina hacia atrás. El bug del port: `_on_avoided` reemplaza la velocidad después del giro.
- Aldeanos: el port ya implementa huida a refugio ≤50 m o agacharse. Revisar por qué el usuario no lo vio.

### 12.3 Orden actualizado

| Orden | Corte | Letra PLAN-v2 | Cambio |
|---|---|---|---|
| 0 | **055-0** `CONVENTIONS.md` + `tools/lint/conventions.sh` + baseline con ratchet + plantilla de README por sistema | — | Nuevo, medio día, sin tocar la sim |
| 1 | **055a** muerte + doctor que muere cargando | A | Se agrega §12.4 |
| 2 | 055b look y cielo con un dueño | E (parte) | Igual |
| 3 | 055c unidades c1–c4 + `Locomotion` compartido con el mago | B | `Vision` y `Locomotion` cierran el recorrido (a) |
| 4 | 055d mapa + checklist de edificios + **055d-t** `TerrainShape` como único dueño de alturas | C | Prerrequisito de la deformación |
| 5 | 055e mago y libro + checklist de los 41 hechizos | D | Cierra el recorrido (b) |
| 6 | RFC-056 estructuras · RFC-057 terreno deformable · clima | Fase 2 | Volcán y tornado son `SpellAction`, por eso van después de 055e |

Benchmark de legibilidad (archivos que un recién llegado toca o lee): visión +5 m hoy 13 → meta 2; hechizo nuevo hoy 13 → meta 3; mover un edificio hoy 7 → meta 2.

### 12.4 Doctor que muere cargando (cambios al árbol de §5.3)
```
Unit
├── Captive            [~] release(reason: Release) — CARRIER_DIED → asks DeathRules
├── Corpse             [~] begin_fall(DROP_FROM_AIR) also for a carried body
└── (rest as in §5.3)
scenes/units/death_rules.gd            [+] static on_carrier_lost(kind, alive, dies_on_drop) -> {LAND_ALIVE, DROP_DEAD}
scenes/sacrifice/carry_errand.gd       [~] release_creature(Captive.Release.CARRIER_DIED)
scenes/sacrifice/errand_states/{haul,approach,pump}.gd [~] doctor_died() → one single call (today 3 paths)
MatchRules                             [~] @export var carried_dies_when_dropped := true
debug/units/death_carrier_rules.tres   [+] the doctor is killed mid-haul at tick N
```
Flujo: con `DROP_DEAD` el cuerpo pasa a `DEAD` en el aire, el gate de gravedad de 055a lo baja en ticks hasta `is_on_floor()`, `Corpse.settled` avisa y `SoulSystem` crea el alma en `soul_anchor()`, donde aterrizó. Sin RPC nuevas: `mode` ya se replica.

### 12.5 Terreno deformable (RFC-057, boceto)
```
Map
├── Terrain : Node3D                 [~] only assembles
│   ├── Shape : TerrainShape         [+] the ONE owner of heights: base + Deform grid (Δh per vertex). ground_height() lives here
│   ├── Chunks : TerrainChunk ×N     [+] MeshInstance3D + StaticBody3D/ConcavePolygonShape3D, rebuilt only if touched
│   └── DeformLog : Node             [+] SIM: replicated stamps {tick, brush_id, pos}, applied in tick order on every peer
├── NavRegion (MapNavRegion)         [~] listens Shape.changed(rect) → NavRebake swapped at a chosen tick (exists)
Volcano.tscn (spawned by VolcanoAction)
├── TerrainStamp                     [+] @export brush: TerrainBrush (.tres: radius_m, height_m, grow_s, profile: Curve)
└── Lava / Smoke / OmniLight3D       presentation
scenes/map/terrain/terrain_brush_rules.gd [+] static Δh(distance, brush, t)
```
No hay `HeightMapShape3D` y el original tiene paredes verticales: un heightfield puro no alcanza. El estampado es estado de la sim; malla y flora son presentación.

### 12.6 Primera semana (1 developer a la vez)
| Día | Corte | Archivos |
|---|---|---|
| 1 | 055-0 | `CONVENTIONS.md`, `tools/lint/conventions.sh`, `tools/lint/baseline.txt`, README «quién habla con quién» en units/spells/map, línea en RULES |
| 2 | 055a-1 | `corpse.gd`, `unit_body.gd` (gate), `dead_state.gd`, `reviving_state.gd`, `unit_health_bar.gd`, `death_rules.gd`, `debug/units/death_ragdoll.tscn` + 2 `.tres`; regrabar quick |
| 3 | 055a-1b | `captive.gd`, `carry_errand.gd`, `errand_states/*`, `MatchRules.carried_dies_when_dropped`, `death_carrier_rules.tres`; regrabar quick |
| 4 | 055a-2 | `corpse_look.gd`, `tipping_fall.gd`, `soul` Rise, `unit.tscn` |
| 5 | 055a-3 | `bake_ragdolls.gd` sobre 5 modelos, `ragdoll_driver.gd`, galería; el tech lead escribe el árbol de 055b |

### 12.7 Preguntas abiertas nuevas
P6 ¿el cargado muere al caer aunque estuviera vivo (Desecrate)? Recomendación: sí por defecto, apagable. P7 ¿los `.tres` del catálogo pasan a nombres humanos (`trogg.tres`)? Recomendación: sí en 055c1. P8 ¿lint en pre-commit o solo reviewer? Recomendación: reviewer primero.

## 13. Prioridad: deprecar el 1 a 1 primero, contenido nuevo después (2026-10-23)

El usuario marcó dos huecos: (1) el plan no prioriza construir el juego para que un humano lo modifique, deprecando lo que se hizo como calco del motor original; (2) el ambiente y el bioma no estaban mapeados.

### 13.1 Regla de prioridad
1. **Fase 1 (refactor) va antes que cualquier contenido nuevo.** Ningún hechizo, edificio, clima o asset nuevo entra sobre un sistema que todavía es 1 a 1: primero se rehace el sistema, después se le agrega contenido.
2. **Cada corte borra su parte 1 a 1.** Un corte no está cerrado si el código viejo sigue vivo al lado del nuevo. El reviewer lo verifica contra el registro de §13.2.
3. **Se mide la salida del original.** Además del lint (C9 encabezados que citan el original: 372; C13 lecturas del original en runtime: 47), se cuenta en cada corte el total de líneas que citan sacengine en `scenes/` (hoy 1 439 en 280 archivos). Meta al cerrar la fase 1: C13 = 0, C9 < 50, citas < 300 y solo en una línea `## Ref:` al final.

### 13.2 Registro de deprecación (sistemas calcados del original)

| Sistema 1 a 1 hoy | Por qué limita | Reemplazo Godot | Corte |
|---|---|---|---|
| Muerte por Tween rígido; el cadáver no cae | Voladores en el aire; el alma depende de un Tween | `Corpse` por ticks + `CorpseLook` + ragdoll | 055a (en curso) |
| Cielo: `GodEnvi` pisado por `import_themes.py`, 3 escritores del `Environment` | ~30 archivos para cambiar un cielo | `LookProfile` único, un dueño | 055b |
| `original_material.gd` parsea `index.json` en runtime; 47 lecturas del original | El juego depende del formato original | Materiales horneados como `.tres` | 055b/055c |
| `SideVision`: una criatura por bando por tick, memoria de 384 ticks | Nadie entiende cómo «ve» una unidad | `Vision` (`Area3D`) por unidad | 055c |
| `UnitBody.Mode` replicado como puente a la FSM; 750 líneas | God file de 12 responsabilidades | Componentes hijos + FSM sola | 055c |
| `CreatureType` de 44 campos, clips en `Dictionary`, nombres del WAD (`ycro`) | Ilegible en el inspector | Sub-recursos con nombre, `trogg.tres`, `AnimationLibrary` | 055c |
| Ataques que copian `state.d` (`ranged_attack.gd`, 26 citas) | Un arma nueva exige leer el original | `Weapons/` con escenas `Weapon` enchufables | 055c |
| Aldeanos con la regla de 50 m de sacengine | Parecen quietos | FSM visible `Idle/Work/Flee/Cower` | 055c |
| `BuildingType` con `flags/folder/components`; `Layout` instanciado y caché `bldg()` | No se ve ni se mueve en el editor | Escena por edificio, nodos en `map.tscn` | 055d |
| `FloraMap` de bytes desde `widgets.json` | Números sin sentido para un humano | `FloraLayer` (PNG pintable) + `VegetationPatch` | 055d |
| Terreno: triángulos crudos con 5 representaciones | Imposible deformar o esculpir | `TerrainShape` único dueño | 055d-t |
| `SpellType.flags/flags1`; IA que despacha por tag; `AimedAction` con herencia de 2 | Un hechizo nuevo toca 13 archivos | Campos con nombre, `ai_role`, `Aim` como hijo, proyectil `PackedScene` | 055e |
| `AiPerception` (698 líneas, 32 citas), cerebros por tag | La IA no se puede ajustar sin leer sacengine | Percepción que escucha `Vision`; tácticas en `.tres` | **055f (nuevo)** |
| `SacrificeSystem` (492) + `Ritual` (311) + `DoctorBody` (406) | Ritual y doctor calcados | Ritual como FSM con nodos y `.tres` | **055g (nuevo)** |
| Herramientas de bake del original (`bake_catalog`, `bake_map_layout`, `bake_flora_map`…) | Re-correrlas borra ediciones humanas | Borrar o congelar en `tools/import/legacy/` | Con 055c/055d |
| `MpKit.` en 86 archivos | La red está en todas partes | Wrapper de casos de uso | Fase 3 |

### 13.3 Ambiente y bioma (contenido nuevo, después del refactor del look)
Verificado: el formato de ambiente del original solo trae niebla por mapa (`sacengine/source/envi.d:58-65`); no hay día y noche ni lluvia. Todo esto es contenido nuevo, diseñado como juego moderno. El mapa tutorial no está importado (solo existe en el instalador original).

| Pedido del usuario | Dónde | Forma Godot (borrador) |
|---|---|---|
| Día y noche | **RFC-058 Ambiente** | Nodo `TimeOfDay` en el mapa: `cycle_s`, `Curve`/`Gradient` de sol y cielo; escribe solo a través del dueño de 055b |
| Lluvia, tormentas, clima | RFC-058 | Nodo `Weather` con estados (`Clear/Rain/Storm/Fog`) como `.tres`; `GPUParticles3D` que siguen a la cámara; rayos de tormenta como luz + sonido; presentación solamente |
| Insectos, polen, luciérnagas, partículas del entorno | RFC-058 | Nodo `AmbientLife` con emisores por bioma, `VisibleOnScreenEnabler3D` para el costo |
| Luces en hechizos, magos y unidades | 055b | `OmniLight3D` como hijo configurable, con tope global |
| Bioma de Persephone rico y verde como el tutorial: árboles, arcos, terreno sinuoso | **RFC-059 Bioma Persephone** | 1) investigar el tutorial en el instalador (`tools/import`, sin datos en el runtime); 2) kit de props propio en Blender (árboles, arcos, rocas) como `BiomeProp` de 055d; 3) especies de `VegetationPatch`; 4) paleta en `LookProfile`; 5) terreno esculpido con `TerrainShape` |

### 13.4 Orden final
| Fase | Cortes |
|---|---|
| 1. Refactor (prioridad) | 055a muerte → 055b look → 055c unidades → 055d mapa + terreno → 055e mago y hechizos → 055f IA → 055g ritual y doctor |
| 2. Contenido sobre la base limpia | RFC-060 sangre → RFC-058 ambiente → RFC-059 bioma Persephone → RFC-056 estructuras → los 41 hechizos (checklist de 055e) → RFC-057 terreno deformable |
| 3. Multijugador como wrapper | Refactor de MpKit |

## 14. Agregados del usuario tras probar 055b-3 (2026-10-23)

### 14.1 Luz y brillo como el original
Verificado: sacengine no tiene luces dinámicas puntuales (`renderer.d`: no hay `PointLight` ni equivalente). El brillo del original sale de partículas aditivas (`dagonBackend.d:2677`). El maná brilla con el **color del bando**: `manaColor(side)` y `manaEnergy(side)` (`state.d:30104-30112`) tiñen las partículas del Manalith, del Shrine y la **llama del Manahoar** (`sacobject.d:1408-1412`, emitida en su punto de enganche, `state.d:28325`). Corrección en curso: bloom sutil, emisión de vuelta a valores sobrios, mago y unidades sin charco de luz por defecto, llama del Manahoar y partículas de maná con el color del bando.

### 14.2 Sangre (nuevo: RFC-060)
Hoy el port solo tiene sangre al desintegrar un cuerpo (`unit_body.gd:608`) y en el ritual (`ritual.gd:186`). En los videos del original se ven manchas rojas en el suelo donde hubo combate y salpicaduras al golpear. sacengine solo emite partículas `blood`/`hoverBlood` al desintegrar y en la plaga (`state.d:8313-8324`, `21019`): las manchas en el suelo no están en sacengine y se toman de los videos.
**RFC-060 Sangre y feedback de golpe** (presentación, fase 2, después de 055c porque escucha `Weapons.struck`):
- `BloodFx` (nodo hijo de la unidad): al recibir daño emite salpicadura (`GPUParticles3D` o el sistema de partículas existente) con el color de sangre del tipo de criatura (`CreatureType.blood_color`: rojo por defecto; verde, negro o nada para no-muertos y elementales).
- `BloodDecals` (capa del `LookRig`): `Decal` de Godot en el suelo con pool y tope por calidad, se desvanecen en `fade_s`; nunca entran a la sim.
- Escena de prueba `debug/fx/blood_lab.tscn`.
