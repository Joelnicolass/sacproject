# MpKit: matriz de casos

Cada caso del framework y la prueba que lo cubre. `run/all.sh` corre todo lo automático; `run/play.sh` lo muestra en ventanas.
Transportes: lo marcado **T** corre en ENet, WebSocket y relay (`TRANSPORT=enet|ws|relay`); **TLS** también por `wss://` (`TLS=1`).

## Sesión

| Caso | Prueba |
|---|---|
| Jugar solo, sin red | `--probe=solo` (all.sh) |
| LAN: host + cliente + tardío | `arena.sh` listen **T** |
| Dedicado + cliente + tardío | `arena.sh` dedicated **T** |
| Unirse a una dirección muerta: falla limpio y el menú sigue | `session.sh` deadjoin |
| Servidor lleno (`--max-players`): el que sobra queda afuera | `session.sh` full |
| Salir al menú (Leave) y volver a entrar | `session.sh` leave |
| El servidor se cae: el cliente vuelve al menú | `session.sh` lost |
| Descubrimiento LAN desde el menú, dos ventanas en la misma PC | `session.sh` lan |
| Transporte equivocado (ENet contra WS y al revés) | `session.sh` mismatch |
| Unirse con un nombre de host | `session.sh` hostname |
| Direcciones: IP, nombre, `:puerto`, `#CÓDIGO`, URL | `tests/test_address.gd` |

## Actores

| Caso | Prueba |
|---|---|
| Sync de posición y propiedades extra, al nacer y en vivo | `arena.sh` **T** |
| `to_server` del dueño (`mp_sv_*`) | `arena.sh` recolor **T** |
| `to_all` (`mp_all_*`) | `arena.sh` flash **T** |
| El servidor rechaza `mp_sv_*` de quien no es dueño (RPC directo) | `arena.sh` late **T** |
| Actor sin dueño con `callers = ANYONE` y `sender_slot` | `arena.sh` bell **T** |
| `spawn_actor` y `despawn` en todos; el tardío no ve restos | `arena.sh` shot **T** |
| Nodo solo del servidor en `spawn_path`: sin gate, sin romper clientes | `arena.sh` watch `--probe-server-node` **T** |
| `MpInput.set_value` llega al servidor | `arena.sh` watch (aim) **T** |
| Predicción: respuesta inmediata y corrección ~0 con lag, jitter y pérdida | `arena.sh` lag **T** |
| Demora con que aparece el movimiento de otro jugador (`remote_delay_ms`; tope con `MAX_REMOTE_DELAY_MS`) | `arena.sh` lag **T** |
| `Mp.net_quality()` mide el RTT, la pérdida y el jitter de la red simulada | `arena.sh` lag **T** |
| Compensación de lag: disparos con anticipación a un blanco que camina aciertan; con `--lag-comp=off`, la mayoría erra | `arena.sh` lagshot **T** |
| Buffers adaptativos, calidad de red, historial de poses y frame con el momento visto | `tests/test_input_queue.gd`, `test_net_quality.gd`, `test_lag_comp.gd`, `test_input_frame_view.gd` |
| Suavizado con buffer: el otro jugador se ve parejo | `arena.sh` lag (observe) **T** |
| Inundación de túnel y de `mp_sv_*`: solo pasan las ráfagas | `arena.sh` flood **T** |
| Reglas de sync, cola de input, interpolador, reloj, llamadas, tope | `tests/*.gd` |
| Qué nodos replica el spawner (hechos públicos) | `tests/test_spawner_rule.gd` |

## Partida

| Caso | Prueba |
|---|---|
| `MpState` y el que entra tarde | `arena.sh` late **T** |
| `MpMatch.finish` llega a todos y a la sala | `rooms.sh` public **T TLS** |
| Volver a la partida (botón del lobby) dentro de la gracia | `rooms.sh` rejoin **T** |
| Abandono pasada la gracia: gana el otro | `rooms.sh` abandon **T** |
| El mundo espera pausado (en todos) a que carguen los asientos | `rooms.sh` wait **T** |

## Salas y servidores

| Caso | Prueba |
|---|---|
| Sala pública desde la lista | `rooms.sh` public **T TLS** |
| Sala privada por código, salir y volver, chat | `rooms.sh` private **T** |
| Dos salas a la vez en un servidor de salas | `rooms.sh` tworooms **T** |
| Tope `max_matches` | `rooms.sh` cap **T** |
| Cliente sin TLS contra lobby `wss://` | `rooms.sh` public `TLS=1` |
| Partida privada en la PC con código; código equivocado afuera | `private.sh` **T** |
| Dos servidores de salas en una máquina (línea de systemd) | `instances.sh` |
| Asistente: juego nuevo 2D y 3D jugable en red (`game.tres` + `MpWorld`) | `wizard.sh` |
| Asistente: las salas del juego nuevo (menú *Online rooms*, partida, `Mp.leave()` al lobby, Back al boot) | `wizard.sh` |
| `MpWorld` en el editor real: arma sus piezas al abrir la escena y al agregarlo; se guardan | `editor.sh` |
| El asistente corriendo dentro del editor | `editor.sh` |
| `MpGame` llena el flow; `Mp` sin red; `MpWorld` arma, empaqueta y vuelve a cargar | `tests/test_mp_facade.gd`, `tests/test_mp_world.gd` |
| Cliente web (navegador) contra dedicado WebSocket | `web.sh` (Chrome headless, o abrir la URL a mano) |
| Cliente web por el relay (el servidor hostea una sala del relay) | `TRANSPORT=relay web.sh` |
| Relay: solo hostea quien tiene el secreto (header o query); sin secreto nadie, salvo `RELAY_OPEN=1` | `relay.sh` |
| Relay: una sala con host vivo rechaza a un segundo host (4009, como un puerto en uso) | `relay.sh` |
| Relay: una partida rechazada vuelve a lanzarse en otro puerto y solo se anuncia la que escucha | `tests/test_launcher_relay_retry.gd` |
| Partida privada: invitación en el HUD, segundo clic, otra partida privada en la misma PC (también por relay) | `private.sh` **T** |
| Botón Leave mientras la partida espera asientos (mundo pausado) | `rooms.sh` wait |
| `deploy.sh` (comandos que correría), también con `--transport relay` y el secreto aparte | `deploy.sh … --dry-run` |

## No cubierto acá (y por qué)

| Caso | Motivo |
|---|---|
| Export de Linux y un VPS real | faltan las plantillas de Linux en esta Mac; no hay VPS de prueba |
| El relay corriendo en Railway | es el mismo `server.mjs` que se prueba local; Railway no se toca desde acá |
| Clientes web por el relay con `wss://` público | requiere el dominio de Railway (por `ws://` local sí: `TRANSPORT=relay web.sh`) |
| Export *Dedicated Server* arrancado sin `--dedicated` | la etiqueta `dedicated_server` solo existe en un export; faltan las plantillas de Linux |
