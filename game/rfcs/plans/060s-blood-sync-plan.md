# Plan 060s: misma sangre y mismas marcas en todos los peers

Tech lead, 2026-10-26. Estado: **aprobado** 2026-10-26 («ok a todo con tus recomendaciones»). Corte chico sobre RFC-060.

Nota: `scars=` del harness cuenta baldosas de 10 m pintadas (`ptnet_real_watch.gd:298-299`), no manchas. El 86/78 de `lan_v2` incluye las rocas del Volcano (`ScarMark`).

## 1. Causas
Sangre:
- Semilla por proceso: `blood_fx.gd:62`, `spray_marks.gd:40` (`get_instance_id()`).
- Decisión con reloj local: `blood_fx.gd:84-92` (`Time.get_ticks_msec`); `Health:current` llega comprimido (ON_CHANGE).
- Silencio solo en el cliente: `blood_fx.gd:87,114-116` (`quiet_s` 0,5 s) → el cliente pinta menos.
- Posición local del cuerpo: `blood_fx.gd:107-109`; cambia baldosa y el rechazo por altura de `ground_scars.gd:96-100`.
`ScarMark`:
- El cliente nunca recibe la semilla de la partida: `match_world.gd:28-30` solo siembra en el servidor; `match_seed.gd:49-55` aleatoriza → `wall_scars.gd:24`, `debris_burst.gd:29`, `explosion_burst.gd:56` difieren.
- La roca integra con el delta de cuadro: `debris_piece.gd:41-55`.

## 2. Diseño (un dueño: el servidor decide la herida; sin RPC nuevo)
- `BloodFx` en la autoridad escucha `health.changed`, decide con `BloodRules.kind_for` en segundos de `MatchClock`, y escribe `@export var wound := Vector4` (xyz pies del servidor, w = 2·n + heavy), replicada en el sincronizador del cuerpo.
- Todos pintan desde el setter si `n` avanzó; semilla `MatchSeed.rng(["blood", body.name, n])`. Fuera `quiet_s`, `_born_s`, `_now()`, `_rng` de instancia. En el rejoin, `wound` llega con spawn=true y `_ready` la toma como ya mostrada.
- `SprayMarks`: `MatchSeed.rng(["spray_marks", at])`.
- Semilla común: `SacrificeFlow._apply_match_choice` la fija antes del snapshot (`setup.match_seed` o sorteo) y la guarda en `ActiveMatch`; `MatchWire` la lleva (`"seed"`); `MatchWorld._enter_tree` siembra en todos con `MatchSeed.begin(rules, ActiveMatch.seed())`.
- `DebrisPiece`: `_process` → `_physics_process`.
- Sin tocar: `HitFlash`, `DamageNumbers`, `GroundScars*`.

## Árbol (todos cambiados)
```
scenes/fx/blood/blood_fx.gd, blood_rules.gd (+wound_of/index_of/is_heavy), spray_marks.gd
scenes/units/unit.tscn, scenes/wizards/wizard_body.tscn, scenes/sacrifice/doctor.tscn   + BloodFx:wound (spawn, ON_CHANGE)
scenes/match/match_seed.gd (begin(rules, announced := 0)), scenes/match/match_world.gd
scenes/core/catalog/active_match.gd, scenes/core/flow/sacrifice_flow.gd, scenes/net/match_wire.gd
scenes/spells/zones/debris_piece.gd
agent/harness/ptnet_real_watch.gd (+ marks=), debug/fx/blood_checks.gd
```

## 4. Criterio
`ptnet_real_run.sh lan`: `scars=` y `marks=` iguales en host y A (hoy 86/78); `lanr`: igual tras el rejoin; misma línea `semilla <n>` en host y cliente; lint sin subir (C22 baja); `blood_checks` PASS.

## 5. Riesgos
16 bytes por herida (≤ ~4/s por cuerpo) en el delta del sincronizador; dos heridas en un envío se pintan con la última posición. En red manda la semilla anunciada (los `debug/rules` con semilla fija necesitan `--match-seed`); regrabar el determinismo. El dedicado decide con `fallback` (`red.tres`). Mancha visible de un cuerpo en sigilo. Terreno vivo algo atrasado en el cliente. Falta de `spawn=true` en un sincronizador = ese cuerpo sangra solo en el host. Última herida antes del despawn.
