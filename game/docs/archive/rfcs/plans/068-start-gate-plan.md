Estado: **aprobado 2026-10-26** con todas las recomendaciones de §11. El usuario: no hay nada productivo que deba mantener compatibilidad de protocolo (subir la versión del kit alcanza; sin capa de compatibilidad). Nota del orquestador: el id 067 ya es del plan de mapas PBR; este plan es **RFC-068** (F392). Donde el texto dice RFC-067 / run_067_gate / docs/archive/rfcs/RFC-067-start-gate.md, léase 068.

# Plan tech lead: una puerta de arranque para LAN y salas (propuesta: RFC-067, F392)

No edité el repo ni corrí Godot. Seguí CONVENTIONS.md (C1–C23 y §2c). El lint de hoy: todos los conteos en OK salvo **C19 7/6 FAIL**, que viene de `data/look/*` y `data/fx/*` (el trabajo en paralelo de look), no de este corte.

---

## 0. Contradicciones y cuál gana

1. **La premisa sobre la LAN de Sacrifice no es exacta.**
   - Sacrifice no usa `MpBootMenu`: `scenes/core/boot.gd` llama a `SacrificeFlow`, que extiende `MpFlow`.
   - El late join que de verdad corre está en `addons/mp_kit/mp_flow.gd:389-395` (`_on_peer_joined` → `load_world_to` con `match_running`). Sirve al listen host (`--listen-host`, `host_lan`) **y** al dedicado a mano (`--dedicated` sin ticket, `role == "server"` en `mp_flow.gd:128`).
   - `MpBootMenu._ensure_late_join` solo corre en el ejemplo `arena_2d`, en el lab y en `drive_kit` sin flow.
   - **Gana:** la decisión del usuario. La puerta cubre los tres caminos.
2. **Hay una tercera copia de la espera en el kit.**
   - `addons/mp_kit/nodes/mp_match.gd` ya pausa hasta que cargan todos, cuenta la gracia y declara el abandono en partidas de sala.
   - `MpMatchAgent._admit` (`lobby/mp_match_agent.gd:149`) también cuenta la gracia.
   - Con `MatchTicketGlue` son tres dueños del mismo estado. La puerta los absorbe: `MpMatch` y el agente pasan a leerla.
3. **En Sacrifice no hay botón «Host LAN».** El host LAN solo arranca con el flag `--listen-host`; el botón Unirse existe solo en debug. La LAN del producto es «Servidor local», que va con ticket y ya tiene la puerta.
   - El criterio «host LAN + 2 clientes» se prueba por línea de comandos.
   - **Gana:** el usuario. La puerta aplica a todos los caminos y la UI de host queda como pregunta (Q5).
4. **RULES.md:28 dice que el dedicado sin `admission` es el «modo directo `join(ip)` de hoy, para pruebas y banco».**
   - Ese camino lo usan unas 30 corridas del banco: la mayoría con un cliente para 2 asientos, y algunas con un late join a propósito (pt73, pt57, f63).
   - **Gana:** la decisión del usuario sobre RULES. RULES.md:28 se actualiza y el banco se conserva con `--start-seats` (Q4).
5. **Versiones.** `plugin.cfg` dice 0.8.0, RULES.md:9 dice 0.7.0 y la memoria dice MpKit 0.10 (RC `rc/v0.10.0`). Antes del hotfix hay que fijar la versión real.
6. **C1.** `scenes/net/match_ticket_glue.gd` tiene 379 líneas (ya está en C1b). El plan lo achica. `mp_kit.gd` (524) y `mp_flow.gd` (530) son del addon, el lint no los cuenta, y crecen poco.

---

## 1. Objetivo y criterios medibles

- Una sola puerta, `MpMatchGate` en `mp_kit`, decide quién se sienta y cuándo arranca la partida, en todos los caminos de red: listen host LAN, dedicado de sala o «Servidor local» con ticket, dedicado a mano y `MpBootMenu`.
- Antes del arranque los asientos libres están abiertos. La partida arranca (el árbol se despausa y `MatchClock` empieza a contar) recién cuando cargaron todos los asientos esperados.
- Después del arranque solo entra un asiento conocido que se fue y vuelve antes de `rejoin_grace_s`, al mismo slot y con el mismo mago. Cualquier otro peer se rechaza con un motivo; el motivo queda en el log y en la pantalla del cliente.
- `MatchTicketGlue` y `MpMatch` usan la puerta. No queda ninguna copia propia de la espera ni de la gracia, y se borra `_ensure_late_join`.
- Solo y «Contra la IA» no cambian: la puerta no se arma.

Criterios numéricos de `agent/runs/run_067_gate.sh`. Host: `--listen-host --mode=ffa3 --map=test_flat4 --rejoin-grace-s=6`.

1. En el log del host salen las líneas `partida lan: slot 2 cargó el mundo (1/2)` y `… slot 3 cargó el mundo (2/2)`, las dos **antes** de `partida lan: la simulación arranca (todos cargaron) en el tick 0`.
2. Los dos clientes imprimen `E2E_CLOCK <name> at_start=<n>` con n ≤ 2, porque estaban pausados.
3. El cliente C, que entra después del arranque, termina con `slot == 0`, sin mundo y con `_rejected == "match_started"`. El host imprime `partida lan: peer N rechazado (match_started)` y el `%Status` del boot muestra el texto de `LOCAL_REJECT_MATCH_STARTED`.
4. El cliente A se va a los 2 s y vuelve a los 4 s:
   - recibe el mismo slot que antes;
   - el host imprime `slot 2 mago en X Z (al irse)` y `… (al volver)` con la misma X Z (±0,1 m);
   - el `instance_id` de `Wizard2` en el servidor es el mismo;
   - A ve su `Wizards/Wizard2` con `owner_slot == 2`.
5. Un cliente que vuelve después de la gracia recibe el motivo `grace_over`.

---

## 2. Escena de prueba

El criterio arranca en las escenas reales: `boot.tscn` → `match.tscn` con `--listen-host`. **No se inventa una escena de debug.**

- **Qué instancia:**
  - el host es el binario del juego (`SacrificeFlow` de `res://scenes/core/flow/sacrifice_flow.tscn`, `res://scenes/match/match.tscn`, `data/modes/ffa3.tres`, `test_flat4`);
  - los clientes headless son el `res://debug/net/dedicated_client.tscn` que ya existe, ampliado: entra por `SacrificeFlow.join_lan`.
- **Estado inicial:** el host está en el mundo, pausado, con el cartel «Esperando jugadores 0/2».
- **Lo que todavía no está:** el arranque (reloj en 0) y el slot 3.
- **Qué usa el que prueba:**
  - **Humano:**
    - ventana del host con `-- --listen-host --mode=ffa3 --map=test_flat4`;
    - dos clientes headless del script;
    - con el mouse, el botón «Empezar ya» del cartel (`Hud/MatchWait/%StartNow`) si quiere arrancar sin esperar a que se llene;
    - `pause_menu` (Esc) → «Salir» y después «Unirse» en un cliente de debug para volver.
    - Son 4 Godot como máximo (3 headless y 1 ventana).
  - **CLI:**
    - `bash agent/runs/run_067_gate.sh`;
    - flags de los clientes: `--e2e-expect-slot`, `--e2e-expect-reject --e2e-expect-reason=match_started`, `--e2e-rejoin-after-s=2 --e2e-away-s=2`.
  - Un atajo de debug sería solo otro flag, no otro `.gd`.
- **Late join → rejoin:**
  - `debug/net/late_join.tscn` pasa a `debug/net/rejoin.tscn` (mismo contenido).
  - Los flows `late_join_a/b.json` pasan a `rejoin_a.json` («A invoca, sale por la pausa, vuelve a entrar y su Manahoar1 sigue con `owner_slot` 2») y `rejoin_intruder.json` (un segundo boot entra después del arranque y en `%Status` aparece el rechazo).
  - Corren contra el dedicado a mano con `--world=res://debug/net/rejoin.tscn --start-seats=1`.
- **`debug/net/terrain_late_join.*` no se toca.** Es en un solo proceso y no pasa por la admisión. Además, el trabajo en paralelo de terreno **acaba de reescribirlo** con el criterio de rejoin («A match is never joined half way; the snapshot is for a seat that rejoins»). Lo dejo en manos de esa línea.

Esto queda en el RFC-067 y en F392 de FEATURES.

---

## 3. Árbol de archivos y nodos

```
addons/mp_kit/
  [+] mp_match_gate.gd          MpMatchGate (~200 l): fases IDLE/FILLING/RUNNING, admisión, gracia, carga, pausa, RPC de estado
  [~] mp_kit.gd                 hijo de hub "Gate"; rpc_present_ticket -> gate.admit; el cliente presenta siempre;
                                rpc_seat_credential; leave() -> gate.reset(); se va el caso especial "MpBootLateJoin"
  [~] mp_flow.gd                @export_group "Match start"; _arm_gate() después de host()/host_dedicated(); rejection_text(reason)
                                virtual; admission_rejected -> status
  [~] mp_boot_menu.gd           [-] _ensure_late_join y la clase LateJoin; drive_kit host: gate.arm abierto + mandar el mundo al admitido
  [~] lobby/mp_match_agent.gd   _admit -> seat_of(peer, credential) (solo identidad + vencimiento del ticket); arm_gate()
  [~] nodes/mp_match.gd         sin pausa ni timers propios: reemite lo que dice la puerta
  [~] mp.gd                     Mp.gate() -> MpMatchGate
  [+] tests/test_match_gate.gd  reglas puras con reloj inyectado
  [~] README.md GUIDE.md QUICKSTART.md plugin.cfg   «puerta de arranque»; late join -> rejoin; versión
mpkit_lab/  [~] run/arena.sh, probe/lab_probe.gd    el cliente "late": rechazado + el primero vuelve (rejoin)
scenes/net/
  [+] seat_presence.gd          SeatPresence: el relato de cada asiento en el log + derrota al que abandona (todos los caminos)
  [~] match_ticket_glue.gd      [-] hold/_loaded/_away/_check_abandon por tiempo; escucha la puerta; se queda con ticket, picks, reporte, empty
  [~] README.md                 Talks to / Check
scenes/core/flow/
  [~] sacrifice_flow.gd         rejection_text -> LocalServerText; tr de los estados; prefijo del log de SeatPresence
  [~] sacrifice_flow.tscn       hijo SeatPresence; knobs "Match start" en el inspector
scenes/wizards/  [~] wizard_spawner.gd   [-] el chequeo de match-ticket-file (el valor viene de la escena)
scenes/match/    [~] match.tscn          WizardSpawner.despawn_on_leave = false; Hud/MatchWait (instancia)
scenes/ui/match_wait/  [+] match_wait.tscn, match_wait.gd, README.md   cartel «Esperando jugadores k/n» + «Empezar ya» (host)
scenes/ui/local_server/[~] local_server_text.gd   motivos match_started, grace_over, full
data/i18n/       [~] strings.csv
debug/net/       [~] dedicated_client.gd (flags de rejoin, de motivo y de E2E_CLOCK)
                 [~] late_join.tscn -> rejoin.tscn (git mv)
agent/runs/      [+] run_067_gate.sh
                 [~] run_pt73_net.sh, run_pt73w_net.sh, run_pt57.sh, run_f63_net.sh   el cliente tarde pasa a rejoin
                 [~] run_audio_net.sh, run_pt61b_net.sh, run_055s_dedicated_cost.sh   + --start-seats=2
agent/harness/   [~] run_pt143.sh, run_pt143p.sh   + --start-seats=2/3
agent/flows/     [~] late_join_a/b -> rejoin_a / rejoin_intruder; pt73_net_late, pt57_client_late, f63_client_late -> rejoin
                 [-] late_join_ghost_a/b, pt140pt_net_c2late (hoy ninguna corrida los usa: confirmar con grep antes de borrar)
RULES.md:28, FEATURES.md (F392), docs/archive/rfcs/RFC-067-start-gate.md, docs/archive/rfcs/plans/067-start-gate-plan.md
```

**Árboles de nodos:**

```
/root/MpKit (autoload)          /root/SacrificeFlow (autoload, sacrifice_flow.tscn)
├ NetQuality                    ├ PickBoard
├ Rooms                         ├ SeatPresence          [+]
├ Matchmaker                    └ MatchTicketGlue/Agent (solo en el proceso con ticket, como hoy)
└ Gate (MpMatchGate)  [+]

HighNoon (match.tscn)
├ WizardSpawner        despawn_on_leave = false   [~ en el inspector]
└ Hud
  └ MatchWait (Control, PROCESS_MODE_ALWAYS)   [+]
    └ Panel ├ %Count (Label)  └ %StartNow (Button, visible si Mp.gate().can_start_now())
```

### Mapa de responsabilidades

| Pieza | Hace | No hace |
|---|---|---|
| `MpMatchGate` (kit) | Fases. Admite o rechaza con un motivo. Credencial por asiento (modo abierto). Cuenta los cargados. Pausa y despausa (y avisa a los clientes). Gracia, `load_timeout`, `give_up`. Emite las señales. | Validar tokens de sala (`MpMatchAgent`). Mandar el mundo. Decidir qué significa abandonar. Elegir map o mode. |
| `MpKit` (kit) | Lleva la presentación al servidor (siempre, cuando la puerta está armada). Guarda en memoria las credenciales por endpoint. `reject_peer`. | Reglas de tiempo ni de fase. |
| `MpFlow` (kit) | Arma la puerta en cada camino que hostea. Knobs en el inspector y flags CLI. Muestra el rechazo como estado. Manda el mundo a cada asiento admitido (`_on_peer_joined`). | Contar cargados ni gracia. |
| `MpMatchAgent` (kit) | Identidad del ticket: sha256 → slot, y vencimiento de un asiento nunca usado. `state.json`. Resultado. | Gracia (pasa a la puerta). |
| `MpMatch` (kit) | Vista de la puerta para los juegos con `MpWorld`; `finish`. | Una pausa propia. |
| `MpBootMenu` (kit) | Botones; sin flow: arma la puerta abierta. | Late join. |
| `SeatPresence` (juego) | Las líneas `partida <id\|lan>: …` (adentro, cargó k/n, arranca + tick, se fue o volvió con la posición del mago, rechazado, no cargó, abandonó y pierde). Le pide al `DefeatRule` la derrota del que abandonó. | Admitir. Reportar a la sala. |
| `MatchTicketGlue` (juego) | Ticket → setup, picks y bots. Arma la puerta por el agente. Reporte (`result`/`abandon`/`empty`/`bad_ticket`). Derrota forzada de prueba. Timeout de picks abiertos (`gate.give_up`). | Pausa, carga ni gracia. |
| `MatchWait` (juego, UI) | Muestra la espera; el host puede arrancar con los que estén. | Lógica de red (solo `Mp.gate()`). |
| `WizardSpawner` | Igual que hoy: el mago se queda quieto mientras el asiento no está. | Decidir por ticket. |

### Resource, nodo o `@export`

- **Nodo:**
  - `MpMatchGate` es un hijo de hub de `MpKit`, como Rooms y Matchmaker, y se ve en Remote como `/root/MpKit/Gate`;
  - `SeatPresence` y `MatchWait` son nodos de escena.
- **`@export` de instancia:**
  - en el nodo `SacrificeFlow` (grupo «Match start»): `rejoin_grace_s`, `load_timeout_s`, `start_seats` (0 = todos), `dedicated_start_seats` (1), `pause_clients`, `match_started_status`;
  - `despawn_on_leave` en `WizardSpawner`, dentro de `match.tscn`.
  - En runtime la puerta muestra en Remote, en solo lectura: `phase`, `expected`, `loaded`, `away`.
- **Resource:**
  - para las salas, los valores salen de los `data/net/lobby_config*.tres` que ya existen (`rejoin_grace_s`, `load_timeout_s`) a través del agente;
  - no se crea un `.tres` nuevo. Un `MpNetConfig` en `SacrificeFlow` pisaría `max_players` con el de la config, y Sacrifice saca ese número del modo.

---

## 4. Contratos (firmas)

```gdscript
class_name MpMatchGate extends Node
## The door of a match: who may sit and when it starts. Before the start every free seat is open; the match starts (the tree unpauses)
## once the seats it waits for have loaded their world. After the start only a seat that is away comes back, within rejoin_grace_s;
## anybody else is turned away with a reason. Not: who wins, what an abandon means (the game listens), the room's tokens (MpMatchAgent).
signal waiting_changed(waiting: bool, loaded: int, expected: int)   # every peer (clients via RPC)
signal seat_admitted(slot: int, back: bool)                         # server
signal seat_loaded(slot: int, loaded: int, expected: int)           # server, before the start
signal started(why: String)            # "all_loaded" | "host_started" | "load_timeout" | "no_hold"
signal seat_away(slot: int)
signal seat_abandoned(slot: int, why: String)   # "grace_over" | "not_loaded" | what give_up says; is_abandoned() is true BEFORE the emit
signal all_gone                         # every expected seat past the grace
signal turned_away(peer_id: int, reason: String)
enum Phase { IDLE, FILLING, RUNNING }
const MATCH_STARTED := "match_started"; const FULL := "full"; const GRACE_OVER := "grace_over"; const SEAT_TAKEN := "slot_taken"; const UNKNOWN := "rejected"
var rejoin_grace_s := 60.0
var load_timeout_s := 60.0
var pause_clients := true
var now_ms: Callable = Time.get_ticks_msec      # tests inject a clock
func arm(seats: Array[int], need: int = 0, identity: Callable = Callable(), hold: bool = true) -> void
func admit(peer_id: int, credential: String) -> Admission   # MpKit only
func start_now() -> bool
func can_start_now() -> bool
func give_up(slot: int, why: String) -> void
func is_waiting() -> bool
func is_abandoned(slot: int) -> bool
func expected_slots() -> Array[int]
func loaded_slots() -> Array[int]
func away_slots() -> Array[int]
func reset() -> void                    # MpKit.leave(); unpauses only if it paused
class Admission: var slot := 0; var reason := ""; var credential := ""
```

**Reglas:**

- `seats` son los slots humanos sin el del listen host (el host cuenta siempre como cargado).
- `need = 0` quiere decir todos.
- Con `identity` vacía (LAN), el primer asiento libre recibe una credencial nueva. Con `identity` (ticket), el slot sale de `identity.call(peer, credential)`.
- Un asiento admitido es de esa credencial durante la gracia, también en FILLING (Q10).
- En RUNNING solo entra un asiento que cargó, está ausente y sigue dentro de la gracia.
- Si todos los asientos esperados están ausentes, no se abandona a nadie (se espera); cuando todos pasaron la gracia sale `all_gone`.

```gdscript
# MpKit
var gate: MpMatchGate
func forget_seat_credentials() -> void
@rpc("authority", "call_remote", "reliable") func rpc_seat_credential(credential: String) -> void
# join(): presents `ticket`, else this endpoint's stored credential, else "" (always presented on connect).
# MpFlow
func rejection_text(reason: String) -> String     # virtual; SacrificeFlow -> LocalServerText.rejection_text
func _arm_gate() -> void                           # agent.arm_gate() if there is a ticket; else open seats
# MpMatchAgent
func seat_of(peer_id: int, credential: String) -> int
func arm_gate() -> void
# Mp
static func gate() -> MpMatchGate
# SeatPresence
var log_prefix := "partida lan: "                  # MatchTicketGlue sets "partida <id>: "
```

- **Motivo del reporte:** el glue reporta `abandon` si `gate.is_abandoned(defeated_slots.back())`. No hay bandera `_abandoning` ni dependencia del orden de conexión.
- **`_first_admit_tick` de la derrota forzada:** se toma en `started` si hay hold, y en el primer `seat_admitted` si no lo hay (034e usa `--no-load-hold`). Así se conserva la semántica de hoy.

---

## 5. Cómo lo hace un humano (los seis verbos más «encontrar un fallo»)

| Verbo | Qué abre o toca | Lugares |
|---|---|---|
| Entender | `sacrifice_flow.tscn`: grupo «Match start» de SacrificeFlow y el hijo SeatPresence. En Remote, `/root/MpKit/Gate` (phase, expected, loaded, away). | 1–2 |
| Modificar | Gracia, timeout y asientos para arrancar en el inspector de SacrificeFlow. Para salas, `data/net/lobby_config*.tres`. | 1 |
| Agregar | Una puerta nueva al juego (pantalla LAN) llama a `host_lan()`, que ya arma la puerta. Un motivo nuevo es una línea en `LocalServerText` y otra en `strings.csv`. | 1–2, sin código de red |
| Quitar | El cartel: borrar `Hud/MatchWait`. La derrota por abandono: borrar el hijo SeatPresence. | 1 |
| Crear | Otro juego con el kit: `MpFlow` arma la puerta solo y `MpMatch` la refleja. | 0 |
| Escalar | Más asientos: `seats` del modo (`data/modes/*.tres`). La puerta cuenta con `max_players`. | 1 |
| Encontrar un fallo | `grep "^partida "` del log del server da, en orden, adentro → cargó k/n → arranca (tick) → se fue / volvió (posición) → rechazado (motivo). Además, Remote de `Gate` y los tests del kit. | 1 log |

---

## 6. Sub-cortes y paralelismo

1. **K1 (kit, base):**
   - `mp_match_gate.gd`;
   - el cableado de `mp_kit.gd` (presentación siempre, credenciales, `reset` en `leave`);
   - `tests/test_match_gate.gd`.
2. **K2 (kit, flujo):** `mp_flow.gd` (`_arm_gate`, knobs, `rejection_text`), `mp_boot_menu.gd`, `mp_match_agent.gd` (`seat_of`, `arm_gate`) y `mp.gd`. **Va en paralelo con K1 si el contrato de §4 queda fijo.**
3. **K3 (kit, vistas y docs):**
   - `nodes/mp_match.gd` lee la puerta;
   - README, GUIDE, QUICKSTART y la versión;
   - en `mpkit_lab`, `arena.sh` y `lab_probe.gd`.
   - En paralelo, después de K1.
4. **G1 (juego, red):**
   - `seat_presence.gd` y el `match_ticket_glue.gd` más chico;
   - `sacrifice_flow.gd/.tscn`;
   - `wizard_spawner.gd` y la línea `despawn_on_leave` de `match.tscn`;
   - `scenes/net/README.md`.
5. **G2 (juego, UI):** `scenes/ui/match_wait/*`, la instancia en `Hud`, `local_server_text.gd` y `strings.csv`. En paralelo con G1.
6. **G3 (pruebas y docs):**
   - `dedicated_client.gd`, `run_067_gate.sh`;
   - conversión late → rejoin y `--start-seats=2` en las corridas de 2 clientes;
   - RULES, FEATURES, RFC y plan.
   - En paralelo.
7. **Pasada final** (sin Godot durante los cortes, según la memoria):
   - import y parse check de los `.gd` tocados;
   - `MPKIT TESTS`;
   - `run_067`;
   - NET QUICK (enet y `TRANSPORT=ws`);
   - `run_034e/g/m`, `run_049a/e/g`;
   - `mpkit_lab/run/arena.sh`;
   - lint.
8. **Hotfix del kit:** con todo en verde, `addons/mp_kit` y `mpkit_lab` van a godot-studio-skills (`rc/…` y `-spanish`, espejo ES/EN). El merge a las ramas principales solo con OK del usuario.

**Cruces con el trabajo en paralelo:**
- `scenes/look/*`, `addons/terrain_tools/*` y `debug/perf`: ninguno.
- `scenes/map/terrain/*` docs: no se tocan `terrain_net.gd`, el README de terreno ni `terrain_late_join.*` (ya los está reescribiendo esa línea).
- **Único riesgo:** `scenes/match/match.tscn`, donde se cambian dos líneas (`despawn_on_leave` y la instancia de `MatchWait`). Hacerlo al final y rebasear.

---

## 7. Pruebas

- **Nuevas:**
  - `MPKIT TESTS`, con `test_match_gate`: llenar, lleno, need, arranque, nuevo después del arranque, vuelta en gracia, gracia vencida, asiento vivo, modo identidad, `load_timeout`, `all_gone`, `reset` que despausa;
  - `run_067_gate.sh` (criterios de §1);
  - los flows `rejoin_a`/`rejoin_intruder`.
- **Tienen que seguir en verde** (motivos y líneas que hoy se leen):
  - NET QUICK (enet y ws): `slot \d cargó el mundo \(2/2\)$`, el resultado;
  - 034d;
  - 034e (`--no-load-hold`);
  - 034g: «slot N volvió/se fue», `(al irse)`/`(al volver)`; el rechazo tarde puede pasar de `rejected` a `grace_over`, y el test no compara el texto;
  - 034m: `bad_pick` sigue siendo de PickBoard, y la vuelta con el mismo código en FILLING tiene que admitirse;
  - 049a;
  - 049e: a Beto ahora lo rechazan con `full` en vez de cortarle en silencio; el test pide slot 0 y sin mundo, así que pasa igual;
  - 049g: `startswith("…la simulación arranca (todos cargaron)")`, por eso el tick va **después** del paréntesis;
  - WIRE CONFIG (no se toca);
  - `lobby_cases`/`lobby_net_cases`: `MpKit.host` sin armar queda en el modo de siempre;
  - `mpkit_lab/run/all.sh`.
- **C14:** las líneas que se mueven del glue a SeatPresence no suben el conteo. Para que «rechazado» no sume un `print(` nuevo, el relato del mago se imprime una sola vez en lugar de dos. Verificar con el lint.

---

## 8. Red y determinismo

- **Cambio de protocolo:**
  - el cliente siempre manda `rpc_present_ticket`, aunque sea con `""`;
  - hay RPCs nuevos: `rpc_seat_credential` y el estado de la puerta (`/root/MpKit/Gate`);
  - un build viejo y uno nuevo no se entienden. Subir la versión del kit y avisar al worktree web (`../sacproject-web`).
- **Retrocompatible:**
  - con un server sin puerta ni `admission`, `""` se ignora;
  - con un ticket inválido, el rechazo llega enseguida en vez de por timeout.
- **Tick 0:** con `pause_clients` todos los peers arrancan juntos en el tick 0. `MatchSeed` no cambia.
- **Corridas viejas:** en el dedicado a mano el reloj ahora arranca cuando carga el primer cliente, no al abrir el proceso. Las corridas que medían ticks desde el arranque del server se pueden correr de lugar; el banco de determinismo está pospuesto.
- **Credenciales:** viven solo en memoria, por `host:port`, y sobreviven a `leave()`.

---

## 9. Riesgos

- `pause_clients` es nuevo en el camino de sala. Las réplicas y los RPC se procesan en pausa, y `MpMatch` ya lo hace en el lab. Si NET QUICK falla, se pone en `false` en el inspector.
- El listen host pausado congela su HUD y su cámara. `MatchWait`, `PauseMenu` y `OptionsMenu` van con ALWAYS.
- Si a algún flow del banco no se le actualiza `--start-seats`, el segundo cliente queda rechazado.
- `MpMatch` cambia por dentro. Hay que verificar el ejemplo `arena_2d` del lab.
- `match.tscn` lo puede estar tocando el trabajo en paralelo.

## 10. Fuera de alcance

- Una pantalla de sala LAN propia.
- Persistir la credencial en `user://`.
- Renombrar `terrain_late_join`, que es de la línea de terreno.
- Abandonos con reconexión entre procesos distintos.
- Navegación y look.

## 11. Preguntas (con recomendación)

1. **ID:** RFC-067 «Puerta de arranque» y F392. *Recomiendo sí.*
2. **¿Dónde espera el host LAN?** En el mundo pausado con el cartel (igual que el dedicado) o en un lobby previo. *Recomiendo el mundo pausado: no hay pantalla nueva y es un solo camino.*
3. **«Empezar ya» del host con los que haya:** *Recomiendo sí.* Arranca solo cuando se llena; el botón se ve únicamente en el listen host y con al menos un cliente cargado.
4. **Dedicado a mano** (puerta de banco): *Recomiendo `dedicated_start_seats = 1` por defecto más `--start-seats=N`.* Si no, unas 25 corridas con un cliente quedan pausadas.
5. **¿Puerta LAN en el boot del producto?** *Recomiendo no.* La LAN del producto es «Servidor local»; `--listen-host` queda para CLI y debug.
6. **Abandono en LAN:** que el asiento pierda al pasar la gracia, igual que en salas, con SeatPresence para todos. *Recomiendo sí.*
7. **Clientes pausados mientras se espera:** *Recomiendo sí.*
8. **¿La credencial sobrevive al reinicio del proceso?** *Recomiendo no.*
9. **Flows de late join sin corrida** (`late_join_ghost_a/b`, `pt140pt_net_c2late`): *Recomiendo borrarlos y convertir `late_join_a/b` a rejoin.*
10. **En FILLING, un asiento LAN que se cae** conserva su slot durante la gracia. *Recomiendo sí: es una sola regla.*

## Archivos clave leídos

- `/Users/joelsartori/Development/sacproject/game/addons/mp_kit/mp_boot_menu.gd` (184, 281-295)
- `/Users/joelsartori/Development/sacproject/game/addons/mp_kit/mp_flow.gd` (128-137, 235-244, 378-397)
- `/Users/joelsartori/Development/sacproject/game/addons/mp_kit/mp_kit.gd` (352-370, 442-491)
- `/Users/joelsartori/Development/sacproject/game/addons/mp_kit/nodes/mp_match.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/mp_kit/lobby/mp_match_agent.gd` (149-165)
- `/Users/joelsartori/Development/sacproject/game/scenes/net/match_ticket_glue.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/core/flow/sacrifice_flow.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/wizards/wizard_spawner.gd` (8-17)
- `/Users/joelsartori/Development/sacproject/game/scenes/match/match_clock.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/match/match_state.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/map/terrain/terrain_net.gd`
- `/Users/joelsartori/Development/sacproject/game/debug/net/dedicated_client.gd`
- `/Users/joelsartori/Development/sacproject/game/agent/runs/run_net_quick.sh`
- `/Users/joelsartori/Development/sacproject/game/agent/runs/run_049e.sh`
- `/Users/joelsartori/Development/sacproject/game/RULES.md` (líneas 9 y 28)
- `/Users/joelsartori/Development/sacproject/mpkit_lab/run/arena.sh`
