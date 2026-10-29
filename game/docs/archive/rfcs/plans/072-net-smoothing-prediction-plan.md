# Plan 072: suavizado BUFFERED y predicción del mago

Tech lead, 2026-10-27. Estado: **aprobado** por el usuario 2026-10-27 (D1–D9 con las recomendaciones; coordinación y OK mutuo con la sesión del kit). API del kit 0.14 sin cambios (MpActor, MpInput, mp_move, MpPrediction, MpInputQueue; GUIDE §5.4, §6.2, §6.8).

## 1. Problema (medido)
Partida 1v1 por WebSockets contra el relay real (RTT ~68 ms): el host suave, el cliente con jitter. Variación del movimiento por frame: cliente CV 1,83 y p95/mediana 17,6; host 1,19 y 8,7. Causa: `unit.tscn` y `wizard_body.tscn` replican `.:position`/`.:rotation` al nodo (MultiplayerSynchronizer ALWAYS) y `MpReplicate` → `MpSmoother` persigue la última pose; sobre TCP los estados llegan en ráfagas. El mago propio del cliente no se predice.

## 2. Criterios
- Paso 1 (criterio absoluto, usuario 2026-10-27: el relativo al host pasó con judder evidente porque el host también lo tiene): por cuerpo caminando y en los DOS lados, CV ≤ 0,15, p95/mediana ≤ 1,3, stalls ≤ 1 %, y p95 del tiempo de cuadro ≤ 20 ms (si no, la máquina está cargada y la corrida lo dice). Base de hoy sobre el relay: host CV 0,47–0,55 y p95/med 3,0; cliente 0,49–0,54 y 1,84–1,95; cuadro p95 37–43 ms (dos ventanas en una Mac). Dos corridas sobre el relay. Determinismo: mismos digests (el servidor no cambia).
- Paso 2: el mago propio con los mismos criterios; tecla → primer paso ≤ 2 cuadros; `last_correction` caminando recto sin efectos p95 ≤ 0,05 m y máx ≤ 0,25 m; proxies sin regresión > 5 %.
- En el cliente solo `MpActor` escribe la pose de un nodo replicado.

## 3. Cortes
| Corte | Contenido |
|---|---|
| 1d | medición: `agent/harness/jitter_watch.gd` (CSV por cuadro), `agent/tools/jitter_stats.py` (`JITTER PASS/FAIL`), flows `jitter_host/a.json`, escenarios `jitter` (relay real) y `jitter_lan` (ENet loopback con lag) en `ptnet_real_run.sh` |
| 1a | `unit.tscn`: fuera `Net` (MpReplicate) y el MultiplayerSynchronizer; `MpActor` BUFFERED (adaptive, 0,1 s, late 0,03), send_hz 30, lag_compensate off, las 22 props en `sync_extra`, `MpSync` guardado; `warp_snap.gd` → `net.snap()` en el cliente, conserva su @rpc |
| 1b | `wizard_body.tscn` igual (send_hz 60, 21 props); `_return_to_altar` anuncia el salto |
| 1c | `doctor.tscn` igual (D3) |
| 2-0 | kit: hotfix de `MpInputQueue` al volver un asiento (bloqueante); «dueño sin peer = servidor simula» opcional (D8) |
| 2a | `wizard_drive.gd` (`WizardDrive`, único escritor del movimiento por tick, dueño de `locked`), `wizard_body.gd` (`mp_move`, fuera `submit_drive`), `MpInput` (values forward/yaw), `Locomotion.finish_now`, `BodyAvoidance.announce`; base de determinismo regrabada (D5) |
| 2b | opcional (D7): tumbo y empujones predichos |

## 4. Decisiones
D1 un synchronizer por actor; D2 send_hz 30/60 y buffer 0,1 s; D3 doctores en el paso 1; D4 lag_compensate off; D5 el mago predicho no esquiva con RVO (mago contra mago); D6 forward/yaw como values de MpInput; D7 efectos del servidor no predichos al principio (salto ~1 RTT); D8 hotfix del kit obligatorio; D9 interpolación de física aparte.

## 5. Pruebas
Pasada final: import, abrir y guardar las escenas sin diff, rules suite, NET QUICK enet y ws, gate, rejoin, determinismo quick, `jitter_lan` y `jitter` ×2. En el editor: el MpSync muestra `net_position`/`net_rotation`/`net_stamp`; Teleport se ve como salto; en el paso 2, W responde en el acto.
