# 055c: unidades «human first». Plan aprobado 2026-10-23

Aprobado por el usuario con un cambio: **`Vision` reemplaza a `SideVision`** (no la alimenta). P1 armas como nodos en escena opcional por criatura; P2 `CreatureType` con grupos, sub-recurso solo `ClipTiming`; P3 la carpeta `data/catalog/creatures/` se muda después con spells y buildings; P4 forma por defecto cilindro, esfera y `fov_deg` opcionales; P5 pasivas por tag → nodos en **055c5**; P6 `AbilityType.flags` con 055e.

## Hoy (medido sobre 55bed5ee)
`unit.tscn`: 63 nodos, 39 hijos directos, 21 props replicadas. `unit_body.gd` 763 líneas con 12 responsabilidades: catálogo y stats; `mode` replicado y FSM; paso físico; API de caminar y giro; enganche; combate; habilidad y RPC; formas especiales; regeneración; invocación; muerte; clips y debug. No existe nodo de visión: `sight_range` se lee en 6 lugares y `SideVision` mide distancias (`side_vision.gd:96-112`) con su cola de una criatura por bando por tick y 384 ticks de memoria.

## Árbol
```
Unit : CharacterBody3D        unit_body.gd       [~] 763→≤200: mode, ids replicados, swings/shots, ORDEN del paso
├── Tilt/Mesh/Rig, Collision, Health, ManaPool   (igual; nombres fijos por 566 flows)
├── Creature                  creature_link.gd   [+] ~80  tag→CreatureType, modelo, stats. ↑type_applied
├── Locomotion                components/locomotion/locomotion.gd [+] ~150 (compartido con el mago)
├── Air, Flight, Avoidance, BodyCollider, PathFollower, WarpSnap  (igual; Locomotion los usa por socket)
├── Vision : Area3D           units/vision/vision.tscn+.gd [+] ~90  ↑seen ↑lost; in_sight() ordenado por name
│   └── Shape (Cylinder|Sphere, local_to_scene)
├── Engagement                targeting/engagement.gd [+] ~120  dueño de target; elige arma. ↑target_changed
│   ├── Picker (target_picker ≤150 + target_score.gd static) · Futility · Refresh
├── Weapons                   weapons/weapons.gd [+] ~60  prioridad = orden de hijos. ↑swung ↑fired
│   ├── Ranged                weapons/ranged_weapon.tscn+.gd (de ranged_attack) ≤150
│   └── Melee                 weapons/melee_weapon.tscn+.gd (de melee_attack) ≤150 + melee_rules.gd
│       └── OnHit
├── Abilities
│   ├── Ability               abilities/ability_slot.gd ≤150; efecto = AbilityType.effect
│   └── Port                  abilities/ability_port.gd ~50  request_/submit_ability
├── SpecialForms              special_forms.gd [+] ~100  roca, hacerse el muerto, sigilo (stealth replicado se mueve aquí)
├── Regeneration              regeneration.gd [+] ~40
├── Clips (UnitClips)         [~] ≤150 + idle_role, captive_role, has_clip, debug
└── ClipPose, States, Afflictions, pasivas, Orders, Corpse, CorpseLook, Captive, GuardianBond, HealthBar, Net, Synchronizer, UnitSounds (igual)
```
Paso fijo en `UnitBody._physics_process` (≤25 líneas): `simulates?` → `locomotion.begin(delta)` → `states.current.physics_update` → `locomotion.finish()`. Ningún componente nuevo procesa solo.

## Vision (con el cambio del usuario)
- `Area3D`, `monitoring` solo donde simula, `monitorable = false`, filtro por grupo (`unit`, `wizard`, `structure`, `doctor`, `manafount`).
- `radius_m` (0 = `CreatureType.vision_m`), `shape_kind` CYLINDER/SPHERE, `fov_deg` (360 = sin cono; ángulo desde `facing_flat()`).
- **Es la regla**: visto = dentro del área (y del cono). `in_sight()` ordenado por `name` estable; `refresh()` lo llama quien consume en su tick y emite `seen`/`lost` en ese orden. Nada usa `body_entered` directo.
- **`SideVision` se reemplaza**: la memoria del bando es la unión de lo que ven sus unidades más `forget_s` editable (segundos). Se borra la cola por bando y los 384 ticks. El mago tiene su propia `Vision`.
- Consumidores: Engagement, `UnitOrders`, `WoundedAllyPolicy`, `AiPerception` (`vision.radius_m`), aldeano.
- Interruptor `use_area` (false = recorrer grupos con la misma API) por si el rendimiento con 150 unidades no da.
- Los digests cambian con c2 (se acepta); el determinismo se mantiene por el orden por `name`.

## Armas
Contrato `Weapon extends Node` (`weapons/weapon.gd` ~50): `setup(body, type, rng)` (mismo stream `MatchSeed ["body", name]`), `wants(target)`, `aim(target) -> Step {APPROACH, HOLD, FIRE}`, `start`, `advance(delta) -> bool`, `cancel`, `cooldown_left`, `clip_role`, `busy_state`; señales `struck`, `connected`. Melee → `MeleeWeapon` (doctor igual); Ranged + `ShotLook` tipado (`ballistic`, `fall_accel` como campos); aliento = `RangedWeapon` con otro `ShotLook`; `ActiveAbility` + `AbilityCatalog` → `Abilities/Ability` con `AbilityType.effect: PackedScene` (se borra el catálogo). Arma nueva = soltar `ranged_weapon.tscn` bajo `Weapons` en la escena de la criatura (`CreatureType.scene`, vacío = `unit.tscn`).

## CreatureType
Grupos: Identity (`display_name`, `tag` solo lectura, `god`, `icon`, `body: PackedScene`, `scene: PackedScene`), Health, Movement, Senses (`vision_m`, `aggressiveness`), Melee (`swings: Array[ClipTiming]`), Ranged (`ranged_attack: AbilityType`, `shots`), Ability, Stun, Resistances, Summon, Passives (tags hasta 055c5). Se borran 7 `Dictionary` de animaciones (viven en el AnimationTree del modelo). `ClipTiming`: `frames`, `fps := 30`, `hit_frames`.
Renombre `ycro.tres` → `trogg.tres` (72 archivos; Faestus ×2 → `faestus.tres`/`faestus_pyro.tres`; espacios en snake) con `tools/migrate/c1_creatures.gd` en dos commits (forma con snapshot de campos de sim que aborta si difiere; nombres + reescritura de `ext_resource`). `TypeRef` pasa a índice tag→recurso; `GameCatalog` falla con tags duplicados; `bake_catalog.gd`/`catalog_builder.gd` a `tools/import/legacy/`.

## Locomotion compartida
`begin(delta)`: asentar, gravedad, gancho vertical (Air/Flight por socket en la unidad). `finish()`: afflictions → avoidance → giro hacia la velocidad (`face_velocity`, true en la unidad, false en el mago) → EdgeClamp → `move_and_slide` → FallCheck; `turn_rate` π; `signal fell`. `wizard_body.gd` 547 → ~430.

## Aldeano
`creatures/villager.tscn` (desde `peasant.tscn`) con `Brain: FsmMachine` {Idle, Work, Flee, Cower} + `villager_senses.gd` ~80 (usa `Vision`); conserva el pánico al golpe (`55bed5ee`). Se borran `peasant_behavior.gd` y `PeasantBehavior.TAGS`.

## Sub-cortes (11 días, un developer)
| Día | Corte | Trabajo |
|---|---|---|
| 1–3 | c1 | `CreatureType` en grupos + `ClipTiming` + migración forma; ~150 lectores; `new_creature.gd`; renombres; `TypeRef`. Digests sin cambio |
| 4–5 | c2 | `Vision` en unidad y mago; reemplazo de `SideVision`; lectores de sight; perf 150 unidades; `debug/units/vision_range.tscn` + rules. Regrabar |
| 6–8 | c3 | `Weapon`, `Weapons`, melee, ranged, aliento, `Abilities`; ~25 harness/debug; `debug/units/weapon_swap.tscn`. Digests sin cambio |
| 9–11 | c4 | `Locomotion` (unidad + mago), `Creature`, `Engagement`, `SpecialForms`, `Regeneration`, `UnitClips`, raíz ≤200; aldeano FSM + `debug/units/villager_fsm.tscn`; quick + all + review + playtest |
| luego | c5 | pasivas por tag (FireShield, LightningCharge, DamagePassive, DeathCloud, ManaSupport…) como nodos |

Lint esperado al cerrar c4: C1a 113→~107, C1b 25→23, C5 223→~195, C8 27→16, C9 372→~355.
