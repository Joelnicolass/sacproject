# REVIEW RFC-020e (F61, Convert fiel)

Veredicto: **PASS con observaciones**. Sin bloqueantes. El RFC se puede dar por cerrado en revisión; falta el playtest con ventana (regla del proyecto) y, de ahí, las observaciones 1 y 2.

Verificado por mí (no por el informe del developer):
- `Godot --headless res://debug/rules_suite.tscn --fixed-fps 600 --quit-after 600000` completa: 25 casos `: PASS` y `RULES SUITE PASS`, EXIT 0, sin ERROR/WARNING en el log. Incluye `convert_numbers`, `convert_revive`, `convert_check`, `convert_chain` (bombeo 10,0 s, fases 1,2,3,4,2,3,5, 2 rondas, "completo, 1 almas") y `convert_doctor_dies`.
- Carga headless sin errores: `desecrate_ritual`, `ritual_cancel`, `convert_ritual`, `convert_pump_kill`, `convert_carry_kill`.
- `rg "sac_doctor|request_convert|CONVERTED|NO_TARGET|_convert_soul"` (sin `.md` ni `reviews/`): vacío. `rg "func agent_" src scenes glue`: vacío. `git diff --stat` no se pudo correr: el repo no tiene commits (`HEAD` inexistente); no hay forma de acotar el diff, revisé los archivos tocados.

## Criterios de 020e

| Criterio | Evidencia | Estado |
|---|---|---|
| Convert se arma con altar propio en pie y alma roja a <= 20 m | `sacrifice_system.gd:151-156,159-172` (`convert_arm_status`, `convert_status`), `convert_action.gd:19-42`; rango vía `standing_status` del spell. Caso `convert_check` | OK |
| Pump `(almas+1)·5` s, alcance 2 m, revive `max(400, 50 %)` acotado a máx | `sacrifice_math.gd:100-106`, `pump.gd:30-34`, `approach.gd` (`convert_reach`), `match_rules.gd:105-114`. state.d:15697 (`timer=(soulNumber+1)*5*updateFPS`), :15693 (`<4.0f` = 2 m), :8679 (`min(max(400,0.5*max),max)`). Coinciden | OK |
| Lo levanta y lo lleva al altar propio más cercano al mago al castear | `begin_convert_cast` fija `closest_own_altar` al empezar el cast (`sacrifice_system.gd:200-211`); sin rango, como `closestShrine` (state.d:28048, 9907). `Haul` reutilizado | OK |
| Rondas `int(máx/550)+1`, al final se desintegra y suma almas | `sacrifice_math.gd:73-75`, `ritual.gd:144-161,176-195`. state.d:16020-16030 (`nRounds==maxHealth/550` termina; rondas desde 0 = n+1). `convert_chain` lo ejercita | OK |
| 4 casos de muerte del doctor | `approach.gd` (`doctor_died` -> `release_soul`), `pump.gd:53-60` (`die_again` + alma nueva, freeCreature state.d:10145-10147), `haul.gd:28-30` (`release_creature`, viva y de su dueño), ritual (020d). Suite `convert_doctor_dies` | OK |
| No quedan `sac_doctor.*` ni lógica vieja | Archivos borrados, grep limpio, `soul_system.gd` sin doctores (245 líneas), `caster.gd` sin `_convert_soul` | OK |
| Escenas de prueba: el resultado no está ya puesto | `convert_*.tscn`: `starting_souls = 0`, `Victim` vivo, sin alma/doctor; `Killer*` con `target_groups=["victim"]`; los `Guard*` solo ven `doctor`. Reusan `high_noon.tscn`, el `.tres` es solo de reglas | OK |

## Dimensiones

- **Autoridad y réplica: PASS.** Todo lo que decide corre en servidor/solo (`SacrificeSystem._physics_process`, `CarryErrand._ready` apaga los pasos en el cliente, `Captive._physics_process` retorna en cliente, spawners solo en servidor). Lo replicado: `UnitBody.mode` (`REVIVING`/`HELD` al final del `enum`, `unit_body.gd:30`), `Soul.state` (`REVIVING` al final, `soul.gd:15`; modo 2 en `soul.tscn`), `Ritual.kind` (spawn + onchange en `ritual.tscn`, `DESECRATE=0` intacto), `Health.current`, `owner_slot`, `attached`. La reserva (`_reserved_mask`) es solo servidor y está bien: el cliente puede armar el icono de más, el servidor re-valida (`check` -> `convert_status`). Orden del setter de `mode`: `_hide_corpse` (restaura grupo y capa) corre antes que `taken_changed`, así `Captive._apply` guarda la capa correcta; en la muerte de vuelta ocurre al revés y `_apply` respeta `is_dead()`. Cliente tardío: `Captive._ready` aplica `is_taken()`, el alma `REVIVING` se oculta en `_process` (`soul.gd`), el ritual llega por datos de spawn. El orden de los enums replicados por entero no cambió (solo se agregaron al final).
- **Cambio `Area3D` -> `StaticBody3D` del alma: PASS.** `soul.tscn:37-41`: capa 4 (bit de la capa 3), máscara 0. Nadie tiene la capa 4 en su máscara: unidades/doctor/mago `ground_mask`=1, proyectiles y `ranged_shot` 1 y 3, `selection.gd:259` 1; `match_command._soul_under` usa la máscara 4. No bloquea el paso ni los proyectiles. Único efecto lateral: ver observación 3.
- **Composición: PASS.** `ConvertAction` es solo contrato con el `Caster`; reglas en `SacrificeSystem`; el pump es un `FsmState` hijo (`pump.gd`, 73 líneas); `Approach` ramifica por `kind` pero cada rama es una función chica. `Ritual` conserva una sola `FsmMachine` de fases, el fin de Convert es `is_last_round()` (mejor que tocar `shoot.gd`; desvío aceptado). Números en `MatchRules` con fuente (`state.d:NNNN`) en cada `@export`. `ConvertAction` es `@tool` y `_find_system` retorna null en editor: sin autoloads en el editor. Nada de presentación nueva en el dedicado (el `FxBus.broadcast` de `pump.gd` es del bus ya existente; `ritual_fx` y `ritual_notice` filtran por `kind`: el aviso "Están profanando" no sale en Convert).
- **Desecrate (020d/F60): PASS.** La suite cubre `desecrate_check`, `ritual_ring`, `ritual_numbers`, `ghost_under_ritual`, `captive`; `desecrate_ritual`, `ritual_cancel` y `desecrate_carry` cargan sin errores. La cadena online completa de Desecrate queda para el playtester (`rfc020d_*`); no la corrí.
- **Alcance: PASS.** Sin extras visibles fuera del RFC. Reorganizar `sacrifice_system.gd` (`_open_vortex`, `_cast_problem`, `_release_soul`) está justificado por compartir Desecrate y Convert.
- **Producto juego:** SQL/XSS/auth N/A.
- **GUT/visual:** la suite no es playtest. El look (aro azul, bombeo, vórtice, estado "levantándose") queda para el playtester / `studio-visual`.

## Bloqueantes

Ninguno.

## Observaciones (no bloquean)

1. **Nombres de flows y cobertura online.** El RFC (§2) pide `rfc020e_convert_a` + `rfc020e_convert_b`, `rfc020e_pump_kill_a`, `rfc020e_carry_kill_a` con dedicado y dos clientes. Existen `rfc020e_convert_a`, `rfc020e_convert_solo`, `rfc020e_pump_kill`, `rfc020e_carry_kill`; **falta `convert_b`** (el observador) y las escenas dicen "SOLO (un proceso)". Es consecuencia de la limitación declarada (copia fantasma de las unidades puestas a mano al liberarse en el cliente): es un artefacto de la escena de prueba (en partida real las unidades nacen del spawner), pero deja sin verificar online `REVIVING`/`HELD`/alma `REVIVING`/almas sumadas y la entrada tardía. Pedir al playtester una pasada con dedicado + 1 cliente, o aceptar explícitamente la reducción y actualizar §2/§18 del RFC.
2. **Playtest pendiente** (`agent/run_pt61.sh`): el developer lo deja "falta review y playtest" en F61; no lo ejecuté (solo lectura). Cierre del corte depende de eso.
3. **`walk_order.gd:66`**: el raycast del clic derecho usa máscara por defecto (todas las capas) y ahora golpea la cápsula del alma (layer 4, hasta 2,8 m de altura); un clic derecho justo sobre un alma da un punto elevado. Ya pasa con unidades y cadáveres; es un nit. `world_camera.gd:230` salta golpes que no son suelo, sin problema.
4. **`captive.gd` `die_again()`** fuerza `health.current = 0` y llama `health.died.emit(0)` a mano en vez de pasar por la API de `Health` (`damage` solo emite si no está muerto y hay autoridad). Funciona y la suite lo cubre, pero duplica el contrato de muerte; un `Health.kill()` sería más limpio. Nit.
5. **`sacrifice_system.gd` 444 líneas** mezcla consultas/validación, casts, spawn y arranque del ritual. Aún legible; si 021 o el Shrine suman más, separar `convert`/`desecrate` validation en un hijo.
6. El pump arranca al llegar a 2 m; el original espera a la animación `pumpCorpse` (state.d:15742). Diferencia de unos cuadros, aceptable y sin clips.
