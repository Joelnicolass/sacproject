# RFC-068: Puerta de arranque

Estado: en implementación (K1-K3 kit, G1-G2 juego, G3 pruebas y docs) desde el 2026-10-26. Feature F392. Plan: `rfcs/plans/068-start-gate-plan.md` (el texto del plan dice 067; es este RFC).

## Decisiones del usuario (2026-10-26, mandan)

1. **Nadie entra de cero a una partida empezada.** Una sola puerta decide quién se sienta y cuándo arranca, en todos los caminos de red: host LAN (`--listen-host`), dedicado de sala o «Servidor local» con ticket, dedicado a mano y `MpBootMenu`.
2. **Solo vuelve un asiento que se cayó**, antes de `rejoin_grace_s`, al mismo slot y con el mismo mago. Cualquier otro peer se rechaza con un motivo que queda en el log del servidor y en la pantalla del cliente.
3. **Sin compatibilidad de protocolo.** No hay nada productivo que mantener: se sube la versión del kit y un build viejo no habla con uno nuevo.
4. Se aceptan las recomendaciones del plan (§11): el host LAN espera en el mundo pausado con el cartel «Esperando jugadores k/n» y «Empezar ya»; el dedicado a mano arranca con `--start-seats=N` (desde MpKit 0.11.1 corregido hay un solo `start_seats = 0` para host LAN y dedicado: 0 = todos o los que cargaron pasado `load_timeout_s`; las corridas de banco con un cliente pasan `--start-seats=1`); no hay puerta LAN en el boot del producto; el asiento LAN que abandona pierde; los clientes esperan pausados; la credencial vive en memoria (no sobrevive al proceso); un asiento que se cae antes del arranque conserva su slot durante la gracia.
5. **La puerta también se arma en solo y «Contra la IA» (2026-10-26, RFC-069).** Modo «solo espera al host»: sin asientos ni red (`arm([], 0)` con `wait_host`). El mundo queda pausado detrás de la pantalla de carga hasta que avisa que está listo (`MpFlow.report_world_loaded`), así `MatchClock` y la IA no corren mientras se precalientan los shaders. Antes solo no armaba la puerta.

## Qué hace

- `MpMatchGate` (`/root/MpKit/Gate`): fases IDLE → FILLING → RUNNING. Antes del arranque los asientos libres están abiertos; la partida arranca (el árbol se despausa, `MatchClock` empieza a contar) cuando cargaron los asientos esperados. Después del arranque solo admite a un asiento ausente dentro de la gracia.
- Motivos de rechazo: `match_started` (entra de cero después del arranque), `grace_over` (vuelve tarde), `full`, `slot_taken`, `rejected`.
- `MatchTicketGlue` y `MpMatch` leen la puerta; no queda otra copia de la espera ni de la gracia. Solo y «Contra la IA» arman la puerta sin asientos: solo espera al mundo del host (decisión 5).
- Con `world_reports_loaded` (RFC-069) un asiento cuenta como cargado cuando su mundo avisa (`MpKit.report_loaded`, después del precalentado), no al `world_ready`; el servidor espera también su propio mundo (`wait_host`). «slot N cargó el mundo» sale después del precalentado.
- `SeatPresence` escribe el relato de cada asiento: `partida <id|lan>: slot N cargó el mundo (k/n)`, `la simulación arranca (todos cargaron) en el tick 0`, `slot N se fue` / `volvió` con el estado del mago `(al irse)` / `(al volver)`, `peer N rechazado (<motivo>)`, `slot N abandonó y pierde`.

## Criterios (`agent/runs/run_068_gate.sh`)

Host `--listen-host --mode=ffa3 --map=test_flat4 --rejoin-grace-s=6` y tres clientes `debug/net/dedicated_client.tscn` (entran por `SacrificeFlow.join_lan`). Como mucho 4 Godot (`GATE_WINDOW=1` muestra el host en una ventana).

1. El host imprime `slot 2 cargó el mundo (1/2)` y `slot 3 cargó el mundo (2/2)` antes de `la simulación arranca (todos cargaron) en el tick 0`.
2. Los dos clientes imprimen `E2E_CLOCK <name> at_start=<n>` con n ≤ 2 (esperaron pausados).
3. El cliente C, que entra después del arranque, queda sin slot y sin mundo, rechazado con `match_started`; el host imprime `peer N rechazado (match_started)` y el estado del boot muestra `LOCAL_REJECT_MATCH_STARTED`.
4. A se va 2 s después del arranque y vuelve 2 s más tarde: el mismo slot, ve su `Wizards/Wizard2`, y el host registra al mago en la misma X Z (±0,1 m) al irse y al volver.
5. B vuelve pasada la gracia y recibe `grace_over`; el host lo declara abandonado.

## Banco

- `debug/net/late_join.tscn` pasa a `debug/net/rejoin.tscn`; los flows `rejoin_a.json` (A invoca, sale por la pausa, vuelve y su Manahoar1 sigue siendo suyo) y `rejoin_intruder.json` (un segundo boot después del arranque queda afuera) corren contra `--dedicated --world=res://debug/net/rejoin.tscn --start-seats=1`.
- Las corridas que probaban un «late join» (pt73, pt73w, pt57, f63, pt63g, pt19c, pt61b) ahora prueban un rejoin del mismo cliente; las corridas con dos clientes a la vez pasan `--start-seats=2`.
- `debug/net/terrain_late_join.*` es de la línea de terreno y ya usa el criterio de rejoin.

## Fuera

Pantalla de sala LAN propia, credencial persistida en `user://`, renombrar `terrain_late_join`, abandonos con reconexión entre procesos distintos.
