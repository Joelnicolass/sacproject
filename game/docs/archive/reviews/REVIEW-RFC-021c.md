# REVIEW RFC-021c (F64, Teleport)

Veredicto: **PASS con observaciones** (sin bloqueantes). El playtest con ventana queda para studio-playtester.

## Evidencia ejecutada
- `debug/rules_suite` completa (`--fixed-fps 600 --quit-after 600000`): exit 0, `RULES SUITE PASS`; `teleport_landing/offsets/carry/action/cast` PASS, `guard_*` PASS.
- Carga headless sin errores ni warnings: `teleport_home`, `guardian_altar`, `desecrate_ritual`, `convert_ritual`.
- `rg -n "func agent_" scenes` vacío. `git diff --stat -- addons/mp_kit`: 4 archivos (mp_boot, mp_flow, mp_authority, README), ninguno `mp_replicate.gd`; 021c no toca el addon. `WarpSnap` solo usa `interpolate_speed` (export publico, `mp_replicate.gd:16`).
- Citas de `state.d` verificadas contra el codigo: 10213-10228 (`getTeleportPosition`), 10247-10253 (50 particulas), 10260-10261/10269 (ordenes), 10306-10311 (`canTeleport`), 10313-10327, 16056-16072, 16074-16101, `renderer.d:1749-1756`. Correctas.

## Criterios 021c
- Clic en Manalith/altar propio en pie, cualquier distancia; mago y criaturas a <=30 aparecen a 30 del edificio con formacion: `teleport_action.gd:46-77`, `teleport_math.gd` (`landing`, `carried`). Caso `teleport_cast`/`teleport_carry`. OK.
- Maná 800 / enfriamiento 15 s / casteo: de `SpellType` (no copiados). OK.
- No viajan guardianas, lejanas, doctores, muertas: `travelers` `teleport_action.gd:122-133` (grupo `rooted` + `doctor` + `is_dead` + `is_taken`). OK.
- Otro blanco: `BAD_TARGET` (`is_building_of`, `:98-115`), validado en servidor con el `path` del cliente. OK.
- Mago muerto a mitad de casteo: `cancel()` + `_has_destination=false`. OK.
- Ambos clientes ven salto y efecto: `WarpSnap._snap` + `_show_jump`. Cubierto por flows `f64_client_a/b`; verificacion visual pendiente del playtest.

## Puntos pedidos
1. **Altura de destino**: sale de `terrain.ground_height` (`_land_y`, `:136-141`), nunca de un rayo; fallback a la altura del edificio solo sin datos de terreno o sobre un agujero (NaN). Mago: `warp_to` resta `feet_drop`. Voladoras: `unit_body.gd` `warp_to` suma lo que tenian sobre el suelo (`_ground_height`, un rayo con `ground_mask` desde el origen, que es terreno). OK.
2. **WarpSnap**: dos saltos seguidos no deja el valor alterado (`_normal_speed` solo se guarda si `!_snapping`; ambos temporizadores restauran el normal). Efecto secundario menor: el primer temporizador restaura antes de que acabe la ventana del segundo (ventana efectiva mas corta, no queda pegado). Si se libera solo `WarpSnap` durante los 0,6 s la corrutina muere y `net` quedaria en 1e6; en la practica `Net` y `WarpSnap` son hermanos y se liberan juntos. Nit (no bloqueante): restaurar en `_exit_tree`.
3. **Autoridad**: el cliente solo puede enviar `submit_cast` (`accept_command` en Caster); el blanco se revalida en servidor. `_show_jump` es `authority, call_local, reliable`: un cliente no puede invocarlo (solo acepta del peer 1); no hay RPC nuevo de entrada. `_snap` es `authority, call_remote`. En dedicado `_show_jump` retorna por `DisplayServer == headless` (misma convencion que `soul.gd`); no se dibuja nada. Cliente tardio: ve la posicion final por spawn/sincronizador; pierde solo el efecto cosmetico (aceptable).
4. **Guardian (021b)**: `rooted` salteado; ordenes: `warped()` conserva GUARD/RETREAT y limpia el resto (alineado con 10260-10261). **Convert/Desecrate**: una criatura tomada (`is_taken`: HELD/REVIVING) y un doctor no viajan. **Mago bajo ritual**: sacengine no restringe el casteo (solo `canCast` por estado, `state.d:9520`); el drenaje del ritual va contra `target_wizard` sin distancia (`ritual.gd:164-170`), asi que Teleport mueve al mago fuera del `RitualPush` pero **no** corta el drenaje ni libera del ritual. El RFC lo contempla (§Teleport 7: «Bajo ritual: sin restriccion»). Coherente.
5. **Composicion**: `TeleportAction` como hijo de `Caster/Actions`; matematica en `TeleportMath` estatico; `@export` con fuente (`rules`, `rings_scene`, `target_groups`, fx); sockets de `WarpSnap` con warning. `@tool` sin autoload en editor (`MpKit`/`FxBus` solo dentro de metodos de runtime). Presentacion no corre en el dedicado.

## Observaciones (no bloqueantes)
- Los flows se llaman `f64_*`, el RFC pedia `pt64_*`. Nit de nombre.
- Una criatura aun en `SUMMONING` entra en `travelers` (solo se excluye muerta/tomada). sacengine usa `isAlive`; sin impacto probado, vale una linea en el RFC o excluirla.
- `warp_to` de `UnitBody` hace `halt()` (cancela objetivo); sacengine no, pero el RFC pide «sin meta de marcha». Desvio documentado.
- Desvios declarados por el developer (distancia en planta, particulas sin escala por cuerpo, sin sonido, cautivas/guardianas no viajan): aceptables, el ultimo es el riesgo 3 del RFC.
- `agent/` y `git diff` de playtest: 021c incluye cambios en `scenes/` por diseño (producto); no hay API de producto cuyo unico caller sea un flow.

## Cierre
RFC 021c se puede dar por cerrado en revision de codigo; resta playtest con ventana y capturas (efecto de anillos, dedicado + 2 clientes).
