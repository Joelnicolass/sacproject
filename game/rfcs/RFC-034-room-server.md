# RFC-034 — Servidor de salas

Estado: plan del tech lead (Opus), pendiente de OK. Arquitectura **estándar**. MP **online con dedicado**: el dedicado de partida es el de hoy (`--headless -- --dedicated`), sin cambios en la simulación.
- **Pedido del usuario (2026-10-17):** el PRD (líneas 9-42) dice que un dedicado aloja **una** partida y que el cliente escribe la IP. Eso queda reemplazado por un **servidor de salas** en Godot headless (mismo proyecto). El servidor de salas:
  - acepta clientes;
  - lista y crea salas;
  - maneja unirse, elegir mago, listo y chat;
  - al arrancar la partida, lanza **un dedicado de Godot por partida** en un puerto libre del mismo VPS (`OS.create_process`);
  - les pasa a los clientes el puerto y un token de un solo uso.

  El dedicado valida el token, simula (determinista, igual que hoy), reporta el resultado y termina.
- **Descartado:** un solo proceso con muchas salas. `MatchClock`, `MatchSeed`, `FxBus` y los estáticos son estado global. El hub de `MpRoomDirectory` sigue en el kit, pero acá solo se usa para los asientos del lobby, nunca para mundos.
- **Decisión del usuario (2026-10-17, vía orquestador):** el servidor de salas va **genérico dentro de `mp_kit`**. Se desarrolla primero en `game/addons/mp_kit/`, con el pegamento del juego aparte (`scenes/net/`, `scenes/ui/lobby/`). Se sube al repo del kit (`godot-studio-skills`, ramas `rc/vX.Y.Z` y `rc/vX.Y.Z-spanish`, espejo ES/EN) **recién cuando la prueba en este juego sea estable**. Eso es el último corte (034h). El merge a las ramas principales del kit lo decide el usuario.
- **Features:** F178–F185 (034a–034h). F175 queda reservada por RFC-033 (033i). Las asigna el orquestador.
- **Autoridad:** decisión del usuario 2026-10-17 > PRD > FEATURES > RULES > VISUAL > este plan.

### Contradicciones (gana la decisión del usuario del 2026-10-17)
- `PRD.md` §Decisiones dice «Sin Steam, sin WebRTC, sin un proceso por partida». Ahora hay un proceso por partida. Se edita el PRD (§9).
- `PRD.md` dice «Los clientes hacen `join(ip)`» y en §Recorrido «escribe la IP». Se reemplaza por el lobby (§9).
- `RULES.md` §Red dice «Los clientes solo `join(ip)`». Se edita. Además, `RULES.md` §Stack dice «MpKit 0.5.0», pero `addons/mp_kit/plugin.cfg` dice `0.6.0`. Se corrige a lo real.
- `addons/mp_kit/README.md` §Qué no hacer dice «Meter Steam, WebRTC o un proceso Godot por partida en el addon». Este RFC lo cambia a propósito (decisión del usuario). El README se reescribe en 034h, junto con el port.

## 1. Objetivo (criterios de aceptación)

- **Sin IP a mano.**
  - El cliente toma el lobby de `data/net/lobby_endpoint.tres`. En desarrollo es `127.0.0.1:7700`; con `--lobby=host:port` se pisa.
  - El puerto y el token de la partida vienen del lobby.
  - El host de la partida es el mismo del lobby, salvo que el servidor de salas mande `public_host`.
- **Salas.** Un jugador ve la lista de salas, crea una (pública o con código), se une, elige mago y dios, marca «Listo» y chatea. Con la sala llena y todos listos hay una cuenta regresiva de 5 s, que se cancela si alguien deja de estar listo o se va.
- **Un dedicado por partida.**
  - Al terminar la cuenta, el servidor de salas lanza `--headless -- --dedicated --mp-port=P --match-ticket-file=…` en un puerto del rango.
  - El dedicado admite solo a los portadores de un token válido, cada uno en el slot de su ticket, sin importar el orden de conexión.
  - Al haber resultado, el dedicado lo escribe, avisa a los clientes y sale. El servidor de salas libera el puerto y devuelve a los jugadores a la sala con el resultado.
- **Sin huérfanos.**
  - Si el servidor de salas muere, cada dedicado sale solo en 10 s o menos.
  - Si el servidor de salas arranca y encuentra dedicados de una corrida anterior, los mata.
  - Si un dedicado se cuelga (sin latido), el servidor de salas lo mata.
- **Límites por VPS.** Hay topes de partidas, salas, conexiones, largo y ritmo del chat. Pasado el tope, el error es explícito (en español, en la UI); nunca un cuelgue.
- **La simulación no cambia.** `agent/run_determinism.sh quick` da los digests de `agent/det_baseline.txt` en cada corte. El banco no pasa por el lobby.
- **Kit genérico.** Todo lo de `addons/mp_kit/` que agrega este RFC no nombra magos, dioses, High Noon ni textos de Sacrifice (lo chequea un `rg` en la review). Lo del juego vive en `scenes/net/` y `scenes/ui/lobby/`.

## 2. Hoy (leído del código)

- **`MpFlow._ready` (`addons/mp_kit/mp_flow.gd`):**
  - lee `--mp-port` (default 7777);
  - con `--dedicated` llama `host_dedicated()`;
  - con `start_when = DEDICATED_FIRST_CLIENT`, `_on_peer_joined` carga el mundo al entrar el primero.

  **Problema:** un servidor de salas que haga `host_dedicated()` cargaría High Noon al primer cliente. Hace falta un modo manual (§4.1).
- **`MpKit._on_peer_connected` (`mp_kit.gd:286`):** asigna el slot **al conectar**, por orden (`ids.assign_client`). No existe admisión. **Problema:** el ticket tiene que decidir el slot (§4.1).
- **`MpKit.join(address)`:** usa el `port` de `configure()`. No hay `join(address, port)`.
- **`MpRoomDirectory` y `MpMatchmaker`:** ya existen en el kit (asientos, código sin `0O1I`, `room_ready`, `push_*_to_room`). Les faltan nombre, listo, metadatos, chat, lista para clientes y estados. Se reusa el directorio como **dueño de los asientos** del lobby.
- **`SacrificeFlow` (`scenes/flow/sacrifice_flow.gd`):**
  - manda `pick` por el canal `pick` al recibir el slot;
  - `--ai-slots` y `--ai-god` arman `solo_ai_seats`;
  - `MatchSetup.from_cli()` lee `--level` y otros.

  `MatchSetup` no tiene semilla de partida.
- **Fin de partida:** `MatchState.result_changed` (`winner_slot`, `defeated_slots`, `ended`). El dedicado **no sale** al terminar. `MatchResultBanner` muestra «Victoria», «Derrota» o «Fin de partida».
- **Boot:** `%Ip` + `%Join` en `scenes/ui/boot.tscn` (líneas 80-89).
- **Pruebas en red de hoy:** `agent/run_f63_net.sh` levanta el dedicado con `&` y clientes con AgentKit (`addons/agent_kit/cli.sh … --mp-port`). `godot_run.sh` permite hasta 3 headless + 1 ventana, con un máximo de 4 Godot.

## 3. Arquitectura

```text
Cliente (boot → Salas)  ──ENet :7700──►  Servidor de salas (headless, --room-server)
                                            MpLobbyServer (sobre MpKit + MpRoomDirectory)
                                            MpMatchLauncher ──OS.create_process──► Dedicado de partida :78xx
Cliente  ── MpKit.leave(); join(host, 78xx, token) ──ENet──────────────────────►  MpMatchAgent (ticket, latido, resultado)
Dedicado ── user://mp_matches/<id>/result.json ──► Launcher (ve que el pid salió) ──► sala: resultado, vuelta
```

- **Transporte del lobby: ENet, con el mismo `MpKit`.** Se reusan slots, handshake y RPC. WebSocket solo sirve para el export web, que está fuera de alcance (PRD).
  - El cliente tiene **una** conexión a la vez: deja el lobby al entrar a la partida y vuelve con su `resume_token` al terminar.
- **Canal servidor de salas ↔ dedicado: archivos en `user://mp_matches/<match_id>/`.** No se usa red ni pipes.
  - `ticket.json`: lo escribe el launcher, con permisos 0600 (`FileAccess.set_unix_permissions`).
  - `state.json`: lo escribe el agente. Tiene `listening`, `heartbeat_ms`, `pid` y `slots`.
  - `result.json`: lo escribe el agente.
  - `log.txt`: `--log-file` del dedicado. 034b verifica que el flag existe en 4.7.2; si no existe, el log se pierde y se anota.
  
  **Por qué archivos:**
  - es el mismo VPS;
  - se prueba sin red;
  - permite un pool más adelante (un dedicado precalentado espera a que aparezca `ticket.json`);
  - no hay riesgo de que un pipe lleno bloquee el `print` del dedicado.
- **Huérfanos:**
  - el agente recibe `--room-pid` y sale si `OS.is_process_running(room_pid)` da falso (lo chequea cada 2 s);
  - el launcher guarda `user://mp_matches/registry.json` (pids vivos) y al arrancar mata con `OS.kill` lo que quedó;
  - si un latido tiene más de 10 s, el launcher mata ese dedicado;
  - si un dedicado pasa `match_max_s`, el launcher lo mata.

## 4. Protocolo

### 4.1 Cambios al núcleo de `mp_kit` (genéricos)

- **`MpKit.join(address, p_port := -1, ticket := "")`:** sin ticket, todo queda igual que hoy. Con ticket, al conectar el cliente manda `rpc_present_ticket(ticket)`.
- **Admisión, `MpKit.admission: Callable`:**
  - **Vacía** (default): todo queda igual que hoy.
  - **Puesta:**
    - `_on_peer_connected` **no** asigna slot;
    - espera el ticket hasta `admission_timeout_s` (5 s);
    - llama `admission.call(peer_id, ticket) -> int` (el slot, o 0 si rechaza);
    - si el slot es mayor que 0, hace `ids.bind_client(peer, slot)` + `rpc_assign_slot` + `peer_joined`;
    - si da 0, manda `rpc_admission_rejected(reason)` y hace `disconnect_peer`.
  
  El cliente emite `admission_rejected(reason)`.
- **`MpIds.bind_client(peer_id, slot) -> bool`:** slot fijo, falso si está ocupado.
- **`MpFlow.StartWhen.MANUAL`:** el flow no carga el mundo solo (lo usa el servidor de salas). `MpFlow.join_endpoint(host, port, ticket)` valida host (IPv4 o nombre) y llama `MpKit.join`.

### 4.2 Piezas nuevas en `addons/mp_kit/lobby/` (genéricas, cero texto de producto)

- **`MpLobbyConfig` (Resource): límites y tiempos.** Valores de producción (ver §7):

| Campo | Valor |
|---|---|
| `lobby_port` | 7700 |
| `max_connections` | 64 |
| `max_rooms` | 32 |
| `seats_per_room` | 2 |
| `max_matches` | 4 |
| `match_port_min` / `match_port_max` | 7800 / 7831 |
| `countdown_s` | 5 |
| `spawn_timeout_s` | 20 |
| `ticket_ttl_s` | 60 |
| `rejoin_grace_s` | 60 |
| `resume_grace_s` | 120 |
| `heartbeat_s` | 2 |
| `heartbeat_stale_s` | 10 |
| `idle_no_players_s` | 60 |
| `match_max_s` | 7200 |
| `empty_room_close_s` | 120 |
| `chat_max_len` | 200 |
| `chat_rate_per_s` | 1 (ráfaga 3) |
| `name_max_len` | 24 |
| `list_push_hz` | 4 |
| `proto_version` | 1 |

- **`MpLobbyRooms` (RefCounted):** la máquina de estados pura de las salas. No tiene red, así que se prueba en un solo proceso. Dueño único del estado de cada sala.
  - **Estados:**
    - `OPEN` (faltan jugadores o alguien no está listo);
    - `COUNTDOWN` (llena y todos listos);
    - `LAUNCHING` (el launcher arrancó el proceso);
    - `IN_MATCH` (tickets entregados, asientos «ausentes»);
    - `CLOSED`.
  - **Transiciones:**
    - `COUNTDOWN → OPEN` si alguien deja de estar listo, se va o se cae;
    - `LAUNCHING → OPEN` + error si el spawn falla o pasa `spawn_timeout_s`;
    - `IN_MATCH → OPEN` al llegar el resultado (listo se resetea, el resultado queda en la sala);
    - cualquier estado `→ CLOSED` con 0 sesiones durante `empty_room_close_s`.
  - **Asientos:** los guarda por **sesión** (`session_id`), no por peer. Un peer va y viene; la sesión dura `resume_grace_s` sin conexión.
- **`MpLobbyServer` (Node, solo servidor):** RPC (ver tabla), validación, límites. Usa `MpLobbyRooms` y el directorio `MpKit.rooms` solo para el código. La validación de `meta` y `options` es un `Callable` que inyecta el pegamento (`meta_validator`, `options_validator`, `ticket_builder`).
- **`MpLobbyClient` (Node, solo cliente):** espejo del estado (`rooms`, `room`, `chat`), señales en pasado y métodos `create_room`, `join_room`, `join_code`, `leave_room`, `set_meta`, `set_ready`, `chat`.
  - Al llegar `match_assigned`, emite `match_assigned(host, port, token)`. El pegamento hace `leave` + `join_endpoint`.
  - Al terminar, `resume()` reconecta con su `resume_token`.
- **`MpLobby` (autoload `res://addons/mp_kit/lobby/mp_lobby.gd`, después de `MpKit`):** contenedor delgado con los hijos `Server` y `Client` en la misma ruta en los dos lados (las RPC lo necesitan). Solo se activa con `start_server(config)` o `connect_to(host, port, name)`.
- **`MpMatchLauncher` (Node, servidor de salas):**
  - pool de puertos;
  - `launch(match_id, ticket: Dictionary) -> Error` (`ERR_BUSY` si ya hay `max_matches`);
  - crea la carpeta, escribe el ticket, hace `OS.create_process(executable, args)`, lleva el registro y sondea `state.json` y `result.json` cada 0,25 s;
  - señales `match_listening(match_id, port)`, `match_ended(match_id, result)`, `match_failed(match_id, reason)`.
  
  `executable`, `base_args` y `runner` son `@export`. `runner` es un `MpProcessRunner` (Resource con `spawn`, `is_running`, `kill`); `MpProcessRunnerStub` (`.tres`) simula procesos en las pruebas.
- **`MpMatchAgent` (Node, dedicado de partida):**
  - lee `--match-ticket-file` y `--room-pid`;
  - pone `MpKit.admission`;
  - escribe `state.json` (latido);
  - corta por `idle_no_players_s`, por ticket vencido o porque el servidor de salas murió;
  - `report_result(data)` escribe `result.json`, hace `MpKit.broadcast_session_ended(data)` y `get_tree().quit()` a los 3 s.
  
  Tokens:
  - **un uso activo por token:** si el slot ya está conectado, rechaza;
  - **rejoin:** si el peer se cae, ese mismo token entra de nuevo dentro de `rejoin_grace_s` (P2);
  - el token se consume al terminar.
  
  El ticket guarda `sha256(token)`, no el token.

### 4.3 Mensajes del lobby (RPC en `/root/MpLobby/Server` y `/Client`, todos `reliable`)

| Dirección | Mensaje | Qué valida o hace el servidor |
|---|---|---|
| C→S | `hello(proto, name, resume_token)` | `proto` igual; nombre sin espacios a los costados, de 1 a `name_max_len`. Si `resume_token` está vivo, retoma la sesión y su asiento. Responde `welcome(session_id, resume_token)` o `rejected(code)` |
| C→S | `list_rooms()` | Responde `room_list` y suscribe al cliente a los cambios (a `list_push_hz` como máximo) |
| C→S | `create_room(name, private, options)` | Tope `max_rooms`; `options_validator`; sienta al creador en el asiento 0 |
| C→S | `join_room(room_id)` / `join_code(code)` | Sala `OPEN` y con lugar; una sala por sesión. Las privadas solo por código |
| C→S | `leave_room()` | Libera el asiento; cancela `COUNTDOWN` |
| C→S | `set_meta(meta)` | `meta_validator` (el pegamento: mago + dios). Quita el listo |
| C→S | `set_ready(on)` | Exige `meta` válido. Si la sala queda llena y lista, pasa a `COUNTDOWN` |
| C→S | `chat(text)` | Largo y ritmo; sin BBCode (texto plano). Solo a la sala |
| S→C | `room_list(rows)` | `[{id, name, seats_used, seats, state, private:false}]`. Las privadas no se listan |
| S→C | `room_state(room)` | `{id, name, code (solo miembros), state, countdown_end_ms, options, seats:[{name, meta, ready, connected}], last_result}` |
| S→C | `chat_line(seat, name, text)` | — |
| S→C | `match_assigned(host, port, token)` | Solo a esa sesión: su token |
| S→C | `error(code)` | Códigos estables (`room_full`, `rooms_cap`, `matches_cap`, `bad_meta`, `rate`, `version`, `spawn_failed`…). El pegamento los traduce |

`room_list` y `room_state` son estado completo, no deltas: es simple y aguanta reconexiones.

### 4.4 Ticket (`ticket.json`)

```text
{match_id, port, room_pid, expires_ms, world, options, seed,
 seats: [{slot, token_sha256, meta}]}
```

Lo arma `ticket_builder` (pegamento). El kit solo agrega `match_id`, `port`, `room_pid`, `expires_ms` y los hashes.

### 4.5 Seguridad mínima

- Token de 128 bits (`Crypto.generate_random_bytes(16).hex_encode()`).
- En disco queda solo el hash.
- Vence a los `ticket_ttl_s` si nadie lo usa.
- Un peer sin ticket válido en 5 s queda afuera.
- Ningún mensaje del cliente elige slot, puerto ni semilla.
- Sin cuentas ni contraseñas (fuera de alcance).
- El VPS abre UDP 7700 y 7800-7831, y nada más.

## 5. Pegamento del juego

- **`scenes/net/room_server.tscn` + `room_server.gd`:** la escena que corre el VPS (`godot --headless --path game res://scenes/net/room_server.tscn -- --room-server`). Instancia `MpMatchLauncher` y `SacrificeRoomRules`, llama `MpLobby.start_server(config)` y conecta los validadores.
  - `SacrificeFlow` con `--room-server` pone `start_when = MANUAL` y no manda el canal `pick`.
- **`scenes/net/sacrifice_room_rules.gd` (`class_name SacrificeRoomRules`, Node):**
  - `meta_validator` usa `SacrificeFlow.sanitize_pick`;
  - `options_validator` acepta `world` (solo `high_noon`), `level` (1-9), `friendly_fire`, `drop_soul` y `starting_souls`, con los rangos de `MatchSetup`;
  - `ticket_builder` pone `slot = seat + 1`, `meta = pick`, `options` y `seed` (lo sortea el servidor de salas).
- **`scenes/net/match_ticket_glue.gd` (`class_name MatchTicketGlue`, Node, en el dedicado de partida):** lo instancia `SacrificeFlow` solo si hay `--match-ticket-file`.
  - Del ticket saca `slot_picks`, `setup` y `seed`.
  - Ignora el canal `pick`: el pick quedó cerrado en el lobby.
  - Conecta `MatchState.result_changed` a `report_result({winner_slot, defeated_slots, seed, ticks, reason:"result"})`.
  - Abandono: un slot ausente más de `rejoin_grace_s` cuenta como derrota del ausente (`reason:"abandon"`, P3). Con todos ausentes, `reason:"empty"` y sin ganador.
- **`MatchSetup`:**
  - campo nuevo `match_seed` (0 = el de las reglas);
  - `apply_to` lo pone en `rules.match_seed`;
  - `from_cli` lee `--match-seed`.
  
  Esto no cambia el banco, porque el banco no lo pasa.
- **UI (`scenes/ui/lobby/`, textos en español, VISUAL.md):**
  - **Boot:** botón «Jugar en línea» (abre Salas). `%Ip`/`%Join` quedan solo en debug build (P1).
  - **Salas (`room_list.tscn`):**
    - filas con nombre, jugadores (1/2) y estado («Abierta», «En partida»);
    - botones «Crear sala», «Unirse», «Unirse con código», «Actualizar» y «Volver»;
    - estado «Conectando…» o «No se pudo conectar al servidor de salas».
  - **Crear (`room_create.tscn`):** nombre, «Privada», nivel, fuego amigo, soltar alma y almas iniciales. Los valores iniciales salen de `GameplayPrefs`.
  - **Sala (`room_view.tscn`):**
    - dos asientos (nombre, mago y dios, «Listo»), con el `wizard_preview` del asiento local;
    - «Cambiar mago» (reusa `character_select.tscn`), «Listo», chat (lista + `LineEdit`), código si es privada y «Salir»;
    - resultado de la última partida si hay.
  - **Cuenta regresiva:** «La partida empieza en 5…» encima de la sala, y después «Preparando partida…».
  - **Al final:** `MatchResultBanner` más un botón «Volver a salas» (`LobbyReturn`), que hace `MpFlow.return_to_boot` → `MpLobby.Client.resume()` → la Sala.
  
  `LobbyScreen` (`lobby_screen.gd`) es el controlador delgado que cambia entre las tres vistas. Cada vista corre sola con F6 (un `MpLobbyClient` sin conexión muestra «Sin conexión»).
- **`data/net/lobby_endpoint.tres` (`MpLobbyEndpoint`: host, port) y `data/net/lobby_config.tres` / `lobby_config_local.tres` (`MpLobbyConfig`).**

## 6. Escena de prueba

- **Lógica (034c, sin red):** `res://debug/net/lobby_cases.tscn` (`lobby_cases.gd`). Instancia `MpLobbyRooms`, un `MpMatchLauncher` con `runner = data/net/runner_stub.tres` y `lobby_config_local.tres`.
  - **Estado inicial:** 0 salas, 0 procesos.
  - **Lo que todavía no está:** cada caso arma su estado (crear, llenar, listo, cuenta, spawn falso, latido viejo, tope).
  - Sin InputMap: headless, imprime `PASS`/`FAIL` por caso y termina con `LOBBY CASES PASS`.
  - Un atajo es otro `.tres` del mismo script (`lobby_config_local.tres`: `max_matches=1`, `countdown_s=1`, `rejoin_grace_s=5`), no otro `.gd`.
- **Punta a punta (034e en adelante):** no hay escena de debug.
  - El servidor de salas corre la escena de producto `scenes/net/room_server.tscn` con `--lobby-config=res://data/net/lobby_config_local.tres`.
  - El jugador abre el boot (`F5`). El criterio empieza ahí.
  - El playtester pulsa los botones de la UI (no hay acción de InputMap nueva) y `ui_cancel` para salir.
- **Cliente headless de prueba:** flows de AgentKit (`agent/flows/f18x_lobby_*.json`) que clican la UI. No hay un cliente de pruebas fuera de `agent/`. Ningún `.gd` nuevo en `agent/harness/` (todos se montan en cada flow).

## 7. Árbol de archivos y responsabilidades

```text
game/
├── addons/mp_kit/                                   # GENÉRICO (sube al kit en 034h)
│   ├── mp_kit.gd                 [~] 034a  join(address, port, ticket); admission + rpc_present_ticket/rpc_admission_rejected; señal admission_rejected
│   ├── mp_ids.gd                 [~] 034a  bind_client(peer, slot)
│   ├── mp_flow.gd                [~] 034a  StartWhen.MANUAL; join_endpoint(host, port, ticket)
│   ├── mp_boot.gd                [~] 034a  role() conoce "room-server"
│   ├── lobby/
│   │   ├── mp_lobby_config.gd        [+] 034b  class_name MpLobbyConfig extends Resource (tabla §4.2)
│   │   ├── mp_lobby_endpoint.gd      [+] 034e  class_name MpLobbyEndpoint extends Resource (host, port; --lobby= pisa)
│   │   ├── mp_process_runner.gd      [+] 034b  class_name MpProcessRunner extends Resource (spawn/is_running/kill con OS.*)
│   │   ├── mp_process_runner_stub.gd [+] 034b  procesos simulados para pruebas (tiempos por @export)
│   │   ├── mp_match_files.gd         [+] 034b  static: rutas user://mp_matches/<id>/, leer/escribir JSON 0600, sha256
│   │   ├── mp_match_launcher.gd      [+] 034b  class_name MpMatchLauncher (pool de puertos, registro, sondeo, reap)
│   │   ├── mp_match_agent.gd         [+] 034b  class_name MpMatchAgent (ticket, admisión, latido, room-pid, report_result, quit)
│   │   ├── mp_lobby_rooms.gd         [+] 034c  class_name MpLobbyRooms extends RefCounted (estados, sesiones, asientos)
│   │   ├── mp_lobby_server.gd        [+] 034d  RPC servidor, límites, validadores inyectados
│   │   ├── mp_lobby_client.gd        [+] 034d  espejo de estado + señales en pasado
│   │   └── mp_lobby.gd               [+] 034d  autoload delgado: hijos Server/Client
│   └── README.md                 [~] 034h  sección «Servidor de salas»; se borra «no un proceso por partida»
├── project.godot                 [~] 034d  autoload MpLobby entre MpKit y SacrificeFlow
├── data/net/
│   ├── lobby_config.tres         [+] 034e  producción
│   ├── lobby_config_local.tres   [+] 034c  pruebas (max_matches 1, tiempos cortos)
│   ├── lobby_endpoint.tres       [+] 034e  127.0.0.1:7700
│   └── runner_stub.tres          [+] 034c
├── scenes/
│   ├── flow/sacrifice_flow.gd    [~] 034e  --room-server → MANUAL; --match-ticket-file → instancia MatchTicketGlue; join_from_lobby()
│   ├── flow/match_setup.gd       [~] 034e  match_seed (+ --match-seed)
│   ├── net/
│   │   ├── room_server.tscn/.gd  [+] 034e  escena del VPS: MpMatchLauncher + SacrificeRoomRules
│   │   ├── sacrifice_room_rules.gd [+] 034e validadores + ticket_builder (Sacrifice)
│   │   └── match_ticket_glue.gd  [+] 034e  ticket → picks/setup/seed; resultado; abandono
│   └── ui/
│       ├── boot.tscn/.gd         [~] 034f  «Jugar en línea»; %Ip/%Join solo en debug build
│       ├── match_result.tscn/.gd [~] 034f  «Volver a salas» (LobbyReturn)
│       └── lobby/                [+] 034f  lobby_screen.tscn/.gd, room_list.*, room_create.*, room_view.*, seat_row.tscn, chat_box.tscn, lobby_text.gd (códigos de error → español)
├── debug/net/lobby_cases.tscn/.gd [+] 034c
├── agent/
│   ├── run_034_net.sh            [+] 034e  servidor de salas + 2 clientes (los dedicados los lanza el servidor)
│   ├── run_034_soak.sh           [+] 034h  N corridas seguidas de run_034_net + chequeo de huérfanos
│   └── flows/f18x_lobby_{host,guest,resume}.json [+] 034e/f/g
├── tools/deploy/
│   ├── room_server.service       [+] 034g  systemd (solo el servidor de salas; los dedicados son hijos)
│   └── README.md                 [+] 034g  export dedicated, puertos, firewall
├── PRD.md / FEATURES.md / RULES.md [~] ediciones de §9
└── rfcs/RFC-034-room-server.md   [+]
```

**Mapa de responsabilidades (un dueño por estado):**

| Estado | Dueño |
|---|---|
| Asientos, listo y estado de la sala | `MpLobbyRooms` |
| Procesos y puertos | `MpMatchLauncher` |
| Quién entra al dedicado y en qué slot | `MpMatchAgent` (vía `MpKit.admission`) |
| Qué es un pick y unas opciones válidas | `SacrificeRoomRules` |
| Resultado | `MatchState` (lo decide) → `MatchTicketGlue` (lo reporta) |
| Qué ve el jugador | Vistas de `scenes/ui/lobby/` (solo leen `MpLobbyClient`) |

## 8. Resource, nodo, `@export`

- **Resource de tipo:** `MpLobbyConfig` (producción y local), `MpLobbyEndpoint`, `MpProcessRunner` y su stub. No se mutan en runtime.
- **Nodos:** `MpLobby` (con `Server`/`Client`), `MpMatchLauncher`, `MpMatchAgent`, `SacrificeRoomRules`, `MatchTicketGlue` y las vistas de UI.
- **`@export` de instancia:**
  - `MpMatchLauncher.config`, `runner`, `executable` (vacío = `OS.get_executable_path()`), `base_args`;
  - `RoomServer.rules`;
  - en las vistas, sus `%UniqueName` y los textos;
  - `LobbyReturn.endpoint`.
- **RefCounted:** `MpLobbyRooms` (estado puro). **Static:** `MpMatchFiles`.

## 9. Ediciones a PRD, FEATURES y RULES

**PRD.md**
- §Decisiones, «Multijugador» → «online con **servidor de salas** (Godot headless, mismo proyecto, `--room-server`) que lanza **un dedicado por partida** (`host_dedicated()`, el de hoy) en un puerto del VPS. El peer 1 del dedicado no es un jugador. El cliente se conecta al lobby de `data/net/lobby_endpoint.tres`; no escribe la IP.»
- §Decisiones, «Desarrollo local» → «`res://scenes/net/room_server.tscn -- --room-server` y clientes al lobby `127.0.0.1:7700`; el servidor de salas lanza los dedicados en `127.0.0.1:7800+`. El VPS corre el mismo binario y abre UDP 7700 y 7800-7831.»
- §Decisiones, «Sin Steam, sin WebRTC, sin un proceso por partida» → «Sin Steam ni WebRTC. Un proceso dedicado por partida (decisión del 2026-10-17: el estado global de la simulación no admite varias partidas por proceso).»
- §Decisiones, «Sin fork de `addons/mp_kit`» → se agrega «El servidor de salas es genérico del kit; se sube a `godot-studio-skills` como RC cuando sea estable (RFC-034).»
- §Slice jugable, punto 2 → «Dos clientes entran a una sala del lobby, marcan listo y el servidor de salas los manda al mismo dedicado de High Noon con slots distintos.»
- §Recorrido → «El jugador abre el cliente, elige mago, pulsa Jugar en línea, crea o elige una sala, marca Listo y, tras la cuenta regresiva, entra a la partida. Al terminar vuelve a la sala con el resultado.»
- §Éxito → se agrega «El servidor de salas imprime `salas listo puerto 7700`; una partida de dos clientes termina y el dedicado sale solo, sin procesos huérfanos.»
- §Modo solo: `--ai-slots` sigue siendo una prueba de humo del dedicado directo (sin lobby). Salas con IA: fuera de alcance (§12).

**RULES.md**
- §Stack: «MpKit 0.5.0» → «MpKit 0.6.0 (`plugin.cfg`); RFC-034 la lleva a 0.7.0 dentro del juego hasta el RC del kit.»
- §Red → «Online = servidor de salas + dedicado por partida. El dedicado admite solo con ticket (`MpKit.admission`). Los clientes no escriben IP: `MpLobby` + `join_endpoint`. `play_solo()` no abre servidor. El host LAN no es el camino de internet. Lo genérico de salas vive en `addons/mp_kit/lobby/` sin textos ni reglas de Sacrifice; validadores, opciones y resultado van en `scenes/net/`.»

**FEATURES.md** (append-only, después de la última sección)
- **F2:** se le agrega una línea: «Reemplazado para jugadores por F181–F182 (RFC-034); queda en debug build y para el banco.»
- **F178 (034a):** admisión por ticket en el núcleo de `mp_kit`.
- **F179 (034b):** launcher y agente de partida (procesos, archivos, huérfanos).
- **F180 (034c):** estados de sala sin red (`MpLobbyRooms`) y `lobby_cases`.
- **F181 (034d):** protocolo del lobby sobre ENet (`MpLobby`).
- **F182 (034e):** servidor de salas de Sacrifice y partida punta a punta headless.
- **F183 (034f):** pantallas de salas, cuenta regresiva y vuelta a la sala.
- **F184 (034g):** reconexión, límites y despliegue en VPS.
- **F185 (034h):** estabilidad y port al kit como RC.

## 10. Cortes (en serie)

### 10.0 Medición común
- **Godot:** solo el orquestador (headless) y el playtester (ventana) lo corren, siempre por `agent/harness/godot_run.sh`. **Los developers no ejecutan Godot.**
- **Topes de procesos:** el servidor de salas lanza dedicados por `OS.create_process` y eso **saltea** el lock. Por eso:
  - en local, `lobby_config_local.tres` tiene `max_matches = 1`;
  - `run_034_net.sh` toma un ticket de `godot_run.sh` por cada proceso que va a existir: servidor de salas + 1 dedicado + 2 clientes = **4 = `GODOT_MAX`**;
  - con ventana, va 1 ventana + 3 headless.
- **Simulación:** `quick` igual a `det_baseline.txt` en 034a y 034e (los que tocan `mp_kit.gd`, `SacrificeFlow` y `MatchSetup`). El resto no toca la simulación; alcanza la review.
- **Sesiones cortas:** cada corrida punta a punta dura ≤ 90 s (partida que termina por abandono con `rejoin_grace_s = 5`).
- **Huérfanos:** al final de cada corrida, `pgrep -f "match-ticket-file"` da vacío y `user://mp_matches/registry.json` queda `[]`.
- **Playtest con ventana:** solo en 034f (lo visible). Los demás cortes cierran con banco o casos, más una review corta.

| Corte | Qué | Criterio medible |
|---|---|---|
| **034a** Admisión (kit) | `join(address, port, ticket)`, `admission`, `bind_client`, `StartWhen.MANUAL`, `join_endpoint`, `role()` | Sin `admission` el comportamiento es el de hoy: `quick` igual y `run_f63_net.sh` PASS (incluido el cliente tarde). La admisión con ticket se mide en 034b (el agente la usa) y en 034e (punta a punta). Review: API sin nombres de producto |
| **034b** Launcher y agente (kit) | `MpLobbyConfig`, `MpProcessRunner` (+ stub), `MpMatchFiles`, `MpMatchLauncher`, `MpMatchAgent`; verificar `OS.create_process`, `is_process_running`, `kill`, `get_process_id`, `set_unix_permissions` y `--log-file` en 4.7.2 | Corrida real (orquestador): un script headless lanza 1 dedicado con un ticket. (1) `state.json` llega a `listening` en ≤ 15 s. (2) Sin clientes, el dedicado sale por `idle_no_players_s=10`, `result.json` dice `reason:"empty"` y el puerto se libera. (3) Si se mata el padre, el dedicado sale en ≤ 10 s. (4) Al relanzar el launcher con un pid vivo en el registro, lo mata. `quick` igual |
| **034c** Estados de sala (kit) | `MpLobbyRooms`, `debug/net/lobby_cases`, `runner_stub.tres`, `lobby_config_local.tres` | `LOBBY CASES PASS` con al menos estos casos: crear/llenar/listo → `COUNTDOWN`; dejar de estar listo → `OPEN`; fin de cuenta → `LAUNCHING` → `IN_MATCH`; spawn que falla o pasa el timeout → `OPEN` + `spawn_failed`; `max_rooms` y `max_matches` dan error; puertos sin repetir; latido viejo → kill; sesión que vuelve dentro de `resume_grace_s` → mismo asiento; sala vacía → `CLOSED` |
| **034d** Protocolo (kit) | `MpLobbyServer`/`Client`/`MpLobby` (autoload), RPC de §4.3, límites de chat y nombre | 3 procesos headless: `debug/net/lobby_cases.tscn -- --role=server` y dos `--role=client-a`/`client-b` (otro `.tres` de casos del mismo script, runner stub, sin UI). El log muestra `room_state` igual en los dos, `chat_line` recibido, `COUNTDOWN` y `match_assigned` con el runner stub. El séptimo mensaje de chat en 1 s da `rate` |
| **034e** Sacrifice punta a punta (juego) | `room_server.tscn`, `SacrificeRoomRules`, `MatchTicketGlue`, `MatchSetup.match_seed`, `SacrificeFlow` (room-server, ticket), `run_034_net.sh` | `run_034_net.sh` (4 procesos):<br>• los dos clientes en slots 1 y 2 según el ticket (B se conecta primero y queda en 2);<br>• picks del lobby en `slot picks`;<br>• `bioma … semilla` = la semilla del ticket;<br>• B se va → a los 5 s `result.json` `{winner_slot:1, reason:"abandon"}`;<br>• el dedicado sale;<br>• A recibe `session_ended`.<br>Sin huérfanos. `quick` igual. Un token inventado da `admission_rejected` en ≤ 5 s |
| **034f** Pantallas (juego) | Boot «Jugar en línea», Salas, Crear, Sala, cuenta regresiva, «Volver a salas», textos de error | Playtest (1 ventana + 3 headless). Capturas de: lista con 1 sala; sala con los dos asientos, mago y dios, y «Listo»; chat con una línea del otro; «La partida empieza en…»; High Noon; banner + «Volver a salas»; de vuelta en la sala con el resultado. Cada vista con F6 sola muestra «Sin conexión» sin errores |
| **034g** Reconexión, límites y VPS | `resume()` del lobby; rejoin al dedicado con el mismo token; `--lobby=`; `room_server.service`; `tools/deploy/README.md`; preset de export `dedicated_server` (Linux) | `f18x_lobby_resume`: el cliente cae del lobby y vuelve dentro de 120 s con el mismo asiento. A sale del dedicado y vuelve con su token dentro de `rejoin_grace_s`: mismo slot. Un tercer cliente con el token de A, mientras A está conectado, queda rechazado. La review ve el export preset; la prueba real en el VPS es del usuario (P4) |
| **034h** Estabilidad y port al kit como RC | `run_034_soak.sh`; reescribir `addons/mp_kit/README.md` (ES) + espejo EN; copiar `addons/mp_kit/` del juego a `godot-studio-skills` en `rc/vX.Y.Z` (EN) y `rc/vX.Y.Z-spanish` (ES), con la versión siguiente a la RC vigente (hoy existe `rc-v0.9.0`, así que sería `rc/v0.10.0`); `plugin.cfg` 0.7.0; el `example/` del kit suma una escena de servidor de salas mínima sin Sacrifice | **Estabilidad, antes de portar** (en `main`, sin agentes en paralelo):<br>• `run_034_soak.sh 10`: **10 corridas seguidas** de `run_034_net.sh` PASS, 0 huérfanos y puertos que rotan sin repetir uno ocupado;<br>• `LOBBY CASES PASS` **3 veces seguidas**;<br>• el caso de 034d PASS 3 veces;<br>• `quick` igual;<br>• el playtest de 034f PASS una vez más sobre el `main` final;<br>• `rg -n "Sacrifice\|wizard\|god\|High Noon\|[áéíóú]" addons/mp_kit/lobby` vacío (sin producto ni textos ES en el código; los docs aparte).<br>**Port:** diff de `addons/mp_kit` entre el juego y la RC igual salvo README/docs; el `example/` del kit corre sus casos headless (1 corrida). El merge a las ramas principales del kit lo hace el usuario |

**Orden:** a → b → c → d → e → f → g → h. 034c no depende de 034b en código (usa el stub), pero sí de `MpLobbyConfig`. Se dejan en serie para que un solo developer haga cada corte.

## 11. Riesgos

- **Procesos fuera del lock.** Un bug del launcher puede lanzar dedicados de más y colgar la Mac (memoria del 2026-10-14). Mitigación:
  - `max_matches` duro en el launcher (no solo en la sala);
  - `lobby_config_local.tres` con 1;
  - `run_034_net.sh` mata por pid (nunca `pkill` por patrón) y chequea huérfanos al final.
- **API de procesos en macOS/Linux.** `OS.kill` y `is_process_running` con hijos de `create_process`, más `--log-file`: se verifican en 034b antes de seguir. Plan B para el log: `create_process` sin log y `print` mínimo en el dedicado.
- **Ruta del ejecutable.**
  - En desarrollo: `OS.get_executable_path()` + `--path <globalize res://>`.
  - Exportado: el binario con su `.pck` y sin `--path`.
  
  `base_args` lo resuelve por `OS.has_feature("editor")`/`template`.
- **Arranque del dedicado.** Carga GameData + High Noon al primer cliente: puede tardar varios segundos. La cuenta regresiva se superpone con el spawn (`LAUNCHING` empieza al terminar la cuenta; el cliente ve «Preparando partida…»). Si pasa de 10 s en el VPS, hay pool (P5).
- **Una conexión por proceso cliente.** Mientras el cliente está en partida no está en el lobby, así que no hay chat de lobby en partida (fuera de alcance). Si `resume()` falla tras la partida, el cliente va a Salas con «Conectando…».
- **El canal `pick` y `--ai-slots`.** En el dedicado con ticket, el pick del ticket gana y el canal `pick` se ignora. `--ai-slots` sin ticket sigue como hoy.
- **Que entren reglas del juego al kit.** Los validadores son `Callable` inyectados; la review y el `rg` de 034h lo cierran.
- **Chat abierto.** Texto plano, largo y ritmo con tope. Sin moderación (fuera de alcance).

## 12. Fuera de alcance

- Salas con IA (un asiento IA en la sala). RFC aparte; hoy `--ai-slots` sigue para el dedicado directo.
- Cuentas, contraseñas, ranking, emparejamiento por cola automática (`MpMatchmaker` sigue disponible pero no se usa) y moderación del chat.
- Varios VPS y descubrimiento de servidores; pool precalentado (P5); más de 2 asientos por sala (High Noon tiene dos inicios).
- Export web y WebSocket. Espectadores. Chat dentro de la partida.
- Cambios a la simulación o al determinismo.

## 13. Cómo verifica un humano

1. **Inspector:** abrir `data/net/lobby_config.tres` y `lobby_config_local.tres`: los mismos campos, con otros números. Ninguno se pisa en `_ready`.
2. **F6 en `scenes/ui/lobby/room_list.tscn` y `room_view.tscn`:** se ven solas, con «Sin conexión».
3. **F6 en `debug/net/lobby_cases.tscn`:** la salida termina en `LOBBY CASES PASS`.
4. **Partida local (con el editor cerrado si hace falta memoria):**
   - Terminal: `Godot --headless --path game res://scenes/net/room_server.tscn -- --room-server --lobby-config=res://data/net/lobby_config_local.tres`. Imprime `salas listo puerto 7700`.
   - Editor: Debug → Run Multiple Instances (2), F5 en cada una, «Jugar en línea». A crea la sala, B se une, los dos marcan «Listo».
   - Hay cuenta regresiva, entran a High Noon, A queda en slot 1 y B en slot 2.
   - B sale; a los 5 s, A ve «Victoria» y «Volver a salas», y vuelve a la sala con el resultado.
5. **Huérfanos:** `ps aux | grep match-ticket-file` da vacío. Si se cierra la terminal del servidor de salas a mitad de partida, en ≤ 10 s no queda ningún dedicado.

## 14. Preguntas abiertas (con recomendación)

1. **El campo de IP en el boot.**
   - (a) Solo en debug build, para pruebas y el banco **[recomendado]**.
   - (b) Quitarlo del todo.
   - (c) Dejarlo visible como «Conexión directa».
2. **Rejoin a mitad de partida con el mismo token.**
   - (a) Sí, dentro de 60 s; el slot queda reservado **[recomendado]**: el juego ya soporta entrar tarde (F63).
   - (b) No: si te caés, perdés.
3. **Abandono.**
   - (a) Si un jugador está ausente más de 60 s, pierde y el otro gana (`reason:"abandon"`) **[recomendado]**.
   - (b) La partida sigue sin él hasta el resultado normal (el dedicado puede quedar abierto mucho tiempo; `match_max_s` lo corta a las 2 h).
4. **Despliegue.**
   - (a) 034g deja el export, systemd y el README, y el usuario lo prueba en su VPS **[recomendado]**.
   - (b) Además, el orquestador lo despliega en un VPS que dé el usuario (necesita acceso SSH: lo tiene que hacer o autorizar el usuario).
5. **Pool precalentado.**
   - (a) No en este RFC: spawn por partida, medir el arranque en el VPS y abrir un corte si pasa de 10 s **[recomendado]**. El diseño con `ticket.json` ya lo permite.
   - (b) Pool de 1 desde 034b.
6. **Topes del VPS.** `max_matches = 4` (cada dedicado headless usa ~0,3-1 GB) con 32 puertos: (a) así, ajustable en `lobby_config.tres` **[recomendado]**; (b) otro número según el VPS que tenga el usuario.

## Decisiones del usuario (2026-10-17, preguntas de §14)
1. El campo de IP del arranque queda solo en builds de debug.
2. Reconexión a la partida con el mismo token dentro de una ventana de 60 s.
3. Abandono: si no vuelve dentro de esa ventana, pierde. La ventana es **fácilmente parametrizable**: `@export` en `MpLobbyConfig` (`.tres`) y flag de línea de comando del dedicado, sin tocar código.
4. VPS: el corte deja el export y la guía; la prueba en el VPS la hace el usuario.
5. Sin pool de dedicados precalentados por ahora.
6. Tope de partidas por VPS: **99 por defecto**, parametrizable (`MpLobbyConfig.max_matches` y flag `--max-matches`). En local, las corridas de prueba siguen con tope 1 por la regla de Godot de la Mac.
