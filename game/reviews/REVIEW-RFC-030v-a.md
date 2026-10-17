# REVIEW RFC-030 030v-a (F133) — APPROVE

Revisión corta, solo lectura (sin Godot). Diff sin commitear contra HEAD.

## Fidelidad (PASS)
- Life Shield: `life_shield_ability.gd:12-16` rechaza con BAD_TARGET si no hay `LifeShield` o ya está encendido (igual que la rama borrada); `fire` hace `start_for(ability)` + FxBus "heal" a +UP (igual).
- Run Away: `run_away.gd` mismo guard `SpeedupEffect`, mismo `start(maxf(duration, 1.0))`, `halt`, FxBus "speedup". `min_duration_s = 1.0` coincide con el literal viejo.
- Divine Sight: `divine_sight.gd` mismo orden de chequeos (blanco nulo -> BAD_TARGET, luego rango -> OUT_OF_RANGE), mismos efectos y FxBus.
- Costo, enfriamiento y log: el camino `use()` (`active_ability.gd:150-166`) paga, arranca enfriamiento (`starts_cooldown`) y loguea igual que con `_apply`. `fire` devuelve false solo sin autoridad o sin LifeShield, casos que `status()` ya filtra.
- Catálogo `ability_catalog.tres`: tags `hsba`, `!nur`, `eesd` registrados; `load_steps` 18 correcto.

## Un dueño (PASS)
- Sin lógica duplicada: las ramas, constantes y `_apply_*` salieron de `active_ability.gd`. El `match` queda con Rockform, Play Dead y Stealth (declarado para 030v-b).
- Nada solo-para-harness en el juego: `log_ability` es un `static var` apagado; el caso f133 vive en `debug/` y `agent/`.

## Bloqueantes: ninguno
- Desvío `UsingAbility` (`active_ability.gd:136-139`): ese camino ya existía para todo `_effect`; ahora lo heredan estas tres. `UsingAbility` solo lo encienden ventanas de otros efectos (Firewalk, Pull, Lob, Breath), que no están en Druid, Shrike, Ranger, Flame Minion, Silverback ni Frostwolf. Sin cambio jugable. Si una criatura mezclara ventana y estas habilidades, rechazar mientras prepara es lo fiel a `startUsingAbility`.
- R6: único encendido en `debug/ai_match.gd:99` (el que ya enciende los demás `log_*`). Los `*_expect.py` corren sobre `ai_match`, así que ven los mismos logs; ninguno depende de escenas sin `ai_match`.

## Nits (no bloquean)
1. `active_ability.gd:50`: el comentario del `@export var catalog` dice "(Protector)... keeps the branches below"; quedó viejo (ahora son muchos tags y solo tres ramas). Actualizar en 030v-b.
2. `active_ability.gd:266`: el `print("rockform ...")` va detrás de `AbilityEffect.log_effects` (ok, ya estaba gateado); no hay prints sin gatear que queden en el producto.
3. `divine_sight.gd`: queda declarado el «Blanco inválido» desde la UI (F165); sin cambio.
