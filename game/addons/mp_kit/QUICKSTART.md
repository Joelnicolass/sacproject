# MpKit: primeros pasos

Un juego multijugador sin escribir código de red: nodos en el editor y un script como el de un juego de un jugador. Funciona igual solo, en LAN (un jugador hostea) y con servidor dedicado, por ENet (UDP) o WebSocket (TCP).

El ejemplo completo está en `examples/arena_2d/`: abrí `boot.tscn` y apretá F6.

**El camino más corto**: con el plugin activo, **Proyecto › Herramientas › MpKit: Setup game...**. Elegís carpeta, 2D o 3D, jugadores, transporte y si querés salas online; el diálogo muestra los archivos que va a crear (`[+]`, y `[~]` si ya existen: entonces no escribe nada) y arma `game.tres`, boot, mundo, jugador predicho y salas. F5 y ya se juega solo, en LAN, dedicado u online. Los pasos de abajo son lo mismo a mano: un recurso, dos nodos de escena y tu jugador.

## 1. Instalar

Copiá `addons/mp_kit/` a tu proyecto y activá **MpKit** en Proyecto → Ajustes del proyecto → Plugins. Eso agrega el autoload `MpKit`.

## 2. El juego en un `.tres`

Recurso nuevo **MpGame** (`game.tres`). Tiene todo lo de la red (transporte, puerto, jugadores, relay, TLS) y, en el grupo **Scenes**, tus escenas: `boot_scene`, `world_scene` y, si querés salas online, `lobby_scene` y `rooms_scene`. Es el único lugar donde se escribe cada cosa.

## 3. Boot (el menú)

Escena nueva con raíz `Control`:

- Un hijo **MpFlow** con **Game** = tu `game.tres`. Nada más.
- Una instancia de `res://addons/mp_kit/mp_boot_menu.tscn`: Jugar solo, Host LAN, Unirse, la lista de salas LAN y, si el juego tiene lobby, Online rooms.

El `MpFlow` se muda solo a la raíz del árbol y sobrevive a los cambios de escena. No hace falta autoload. El flow es el dueño de la sesión; el menú, la pantalla de lobby y el servidor de salas leen el juego de él.

## 4. Mundo

Escena con raíz `Node2D` o `Node3D` (tu nivel) y un nodo **MpWorld** con **Player Scene** = tu jugador. Al agregarlo, el editor arma sus piezas como hijos que podés ver y mover:

| Pieza | Para qué |
|---|---|
| `SpawnPoints` | un marcador por asiento: movelos adonde nace cada jugador |
| `Actors` | ahí aparecen los jugadores (y lo que haga un spawner) |
| `Players` | un jugador por asiento, en todos, también para el que vuelve |
| `State` | puntaje, reloj, ronda: lo ven todos (`Mp.state()`) |
| `Match` | espera a que carguen todos, quién se va y quién vuelve, el final (`Mp.finish()`) |
| `Hud/Leave` | botón para salir de la partida |
| `Hud/Invite` | en una partida privada de esta PC, lo que escriben los amigos para entrar |
| `Hud/Start` | en Host LAN, mientras la partida espera asientos: arrancar con los jugadores que ya entraron |
| `Hud/Waiting` | mientras la partida espera sus asientos: «Waiting for players (1/4)» |

Si borrás una pieza, se vuelve a armar al abrir la escena. No les cambies el nombre.

## 5. Jugador

Escena del jugador (`CharacterBody2D`, `CharacterBody3D`...) con dos hijos:

- **MpActor**: tildá qué se sincroniza (posición, rotación, visible, y en *Extra* cualquier propiedad, por ejemplo `health` o `Health:current`) y prendé **Prediction › predict** para el jugador. Guardá la escena: el editor arma el sincronizador y lo guarda.
- **MpInput**: la lista de acciones del InputMap que manda el jugador (por defecto las flechas y Enter).

## 6. Script del jugador

```gdscript
extends CharacterBody2D

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput

# Movimiento: lo corre el servidor y, con predict, también el dueño al instante (sin lag).
func mp_move(keys: MpInput, _delta: float) -> void:
	velocity = keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * 200.0
	move_and_slide()

func _physics_process(_delta: float) -> void:
	if not net.is_authority():   # las reglas corren en el servidor (o en solo)
		return
	if input.is_action_just_pressed(&"ui_accept"):
		Mp.state().add(&"score")
		net.to_all(&"flash")      # corre mp_all_flash() en todos

func _process(_delta: float) -> void:
	if net.is_local() and Input.is_action_just_pressed(&"ui_focus_next"):
		net.to_server(&"recolor")  # corre mp_sv_recolor() en el servidor

func mp_sv_recolor() -> void:
	modulate = Color(randf(), randf(), randf())

func mp_all_flash() -> void:
	$Sprite.modulate = Color.WHITE
```

| Querés… | Usá |
|---|---|
| que algo se vea igual en todos | tildalo en **MpActor › Sync** |
| que el jugador responda sin lag | **MpActor › Prediction › predict** y el movimiento en `mp_move(input, delta)` |
| leer las teclas del jugador en el servidor | `input.get_vector`, `input.is_action_just_pressed`… (misma API que `Input`) |
| mandar un valor propio (punto de mira, cursor) | `input.set_value(&"aim", v)` en el dueño, `input.get_value(&"aim")` en el servidor |
| una orden puntual del jugador | `net.to_server(&"nombre", args)` → `func mp_sv_nombre(args)` |
| un efecto en todos (sonido, destello) | `net.to_all(&"nombre", args)` → `func mp_all_nombre(args)` |
| saber quién pidió una orden | `net.sender_slot()` dentro de `mp_sv_*` |
| un número de la partida | `Mp.state().set_value(&"clave", v)` / `.add(&"clave")`, señal `changed` |
| aparecer balas, unidades, pickups | `$MpSpawner.spawn_actor(escena, {"position": p})` (la escena va en *Extra Scenes*) |

Desde cualquier script, la clase **Mp** tiene los verbos de la partida:

| Querés… | Usá |
|---|---|
| jugar solo, hostear, unirte, salir | `Mp.play_solo()`, `Mp.host()`, `Mp.join("192.168.1.5")` (o `"ip:puerto#CÓDIGO"`, o `"wss://…"`), `Mp.leave()` |
| abrir las salas online | `Mp.open_rooms()` |
| saber si corrés las reglas | `Mp.is_server()` (servidor, o tu PC en solo) |
| tu asiento, tu jugador | `Mp.me()`, `Mp.player(Mp.me())` |
| los números de la partida | `Mp.state()` |
| terminar la partida para todos | `Mp.finish({"winner": slot})` (en el servidor) |

Solo el dueño puede pedir los `mp_sv_*` de su actor (`MpActor › Owner › callers = OWNER`), y solo el servidor manda `mp_all_*`: el kit lo valida. Para cosas del mundo que usa cualquiera (una puerta, la campana del ejemplo), `callers = ANYONE` y validá lo que piden dentro de `mp_sv_*`. Para salir de la partida, el botón Leave del `MpWorld` (un **MpLeaveButton**) o `Mp.leave()`.

### Red real: lag, jitter y pérdida

| Qué | Dónde | Qué hace |
|---|---|---|
| Predicción | **MpActor › Prediction › predict** + `func mp_move(input, delta)` | El dueño se mueve al instante con sus teclas. El servidor corre el mismo `mp_move` una vez por cada frame del dueño, en orden; cuando llega su estado, el dueño vuelve a él y repite los ticks que el servidor no vio (reconciliación). Mismos ticks: la corrección queda en ~0. |
| Suavizado | **MpActor › Smoothing** | `BUFFERED` (por defecto): los demás jugadores se dibujan un poco en el pasado, entre dos estados reales del servidor: se ven parejos aunque los paquetes lleguen a destiempo. Con `adaptive_buffer` (prendido) ese "poco" se mide: pocos ticks en una red buena, más en una mala, hasta el tope `buffer_delay_s`. `FOLLOW`: persigue el último estado (sin demora, con tirones chicos). `NONE`: sin suavizado. |
| Ancho de banda | **MpActor › Sync › send_hz** | Estados por segundo (0 = cada frame). `BUFFERED` tapa los huecos. |
| Buffer de entrada | automático con predict | El servidor junta los frames del dueño que hagan falta según cómo llegan (uno en una red buena) antes de consumirlos de a uno por tick, así un jugador con jitter se mueve parejo para los demás. Si el servidor se queda corto, el dueño acelera apenas para llenarlo. Un cliente que manda frames de más no va más rápido. |
| Disparos con ping | **MpActor › Lag compensation** + `net.rewound(func)` o `net.view_lag()` | El servidor valida un disparo contra donde el tirador VIO a los demás (un segundo de historia), no contra el presente. |
| Calidad de red | `Mp.net_quality()` | RTT, jitter, pérdida y una nota (`good`, `fair`, `bad`) para tu interfaz. |

Reglas de `mp_move`: solo movimiento (puede correr varias veces por tick al reconciliar). Si usa inercia o gravedad, agregá `velocity` a *Sync › Extra*: viaja con la pose y la reconciliación parte de él. Sonidos y efectos detrás de `if not keys.is_replaying():`. Saltos con `is_action_just_pressed` sí van adentro: se ven igual en el dueño, en el servidor y al repetir.

Para probar con red mala, agregá a cada proceso `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` (lag de salida, jitter y pérdida de paquetes no confiables). `net.last_correction()` dice cuánto corrigió el servidor al dueño en el último estado.

## 7. Probar

| Modo | Cómo |
|---|---|
| Solo | F5 → Jugar solo |
| LAN | Depurar → Ejecutar varias instancias (2). Una: Host LAN. Otra: Unirse a `127.0.0.1` |
| Dedicado | `godot --headless --path . -- --dedicated` y los clientes se unen a `127.0.0.1` |
| WebSocket | agregá `--transport=ws` a todos los procesos (un servidor WS solo atiende clientes WS) |
| Web | exportá con el preset Web (sin threads). El export usa WebSocket (directo, o por el relay si el juego dice `relay`) y oculta Host y la lista LAN: un navegador solo se une. El servidor es un dedicado con `transport = ws`, o cualquiera por el relay |

## Más allá de lo básico

### Online: salas y varias partidas en un servidor

Dos escenas más, y anotarlas en `game.tres` (`lobby_scene`, `rooms_scene`); el `MpMatch` ya viene en el `MpWorld`. El ejemplo las trae: `rooms.tscn` y `lobby.tscn`.

| Dónde | Nodo | Qué hace |
|---|---|---|
| Servidor (VPS o tu PC) | **MpRoomServer** en una escena propia, con un **MpLobbyConfig** (`.tres`: puerto, salas, rango de puertos de partida, tiempos) y opcional un **MpRoomRules** | Abre el lobby. Cuando una sala está llena y todos listos, lanza **un proceso dedicado por partida** con un ticket: solo entran los sentados. Toma la red del juego. Correlo con `godot --headless --path . -- --room-server`. Varias partidas a la vez = varios procesos; el tope es `max_matches` |
| Cliente | **MpLobbyScreen** (`rooms/ui/mp_lobby_screen.tscn`) en una escena. Con `lobby_scene` en el juego, el menú muestra *Online rooms* y el botón Back vuelve al boot | Conectar con un nombre, ver salas, crear (pública o con código), sentarse, *listo*, chat. Al arrancar la partida se une solo y al terminar vuelve con el resultado |
| Mundo | **MpMatch** | En el servidor: `all_loaded`, `player_joined`, `player_left`, `player_back`, `player_abandoned`. `finish(resultado)` termina la partida para todos (`finished` en cada peer) y le avisa a la sala |
| (kit) | **MpMatchGate** | La puerta de arranque (`Mp.gate()`): el mundo espera pausado hasta que cargan los asientos; después del arranque solo vuelve el que se fue (dentro de `rejoin_grace_s`), al resto lo rechaza con un motivo. Knobs: grupo **Match start** del `MpFlow` |

El proceso de cada partida es tu mismo proyecto con `--dedicated` y un ticket: `MpFlow` arma solo el agente que valida el ticket. Reglas de sala propias (cuántos asientos según el modo, qué personajes valen):

```gdscript
extends MpRoomRules

func seats_for(options: Dictionary) -> int:
	return 4 if options.get("mode") == "2v2" else 2

func accept_pick(pick: Dictionary) -> bool:
	return pick.get("hero") in ["knight", "archer"]
```

### Sin IP pública: el relay (Railway u otro host)

Si tu servidor no tiene IP pública (tu PC detrás del router) o querés un dominio con TLS para la web, usá el relay: un servidor Node chico (`relay/server.mjs`, `npm install` una vez) que hace de túnel. El servidor Godot se conecta hacia afuera y los jugadores también. En `game.tres`: `transport = relay`, `relay_url = wss://tu-relay.up.railway.app`, `relay_room = mi-juego`; el servidor recibe el secreto por `MPKIT_RELAY_SECRET`. Salas, partidas y partida privada funcionan igual. Pasos para Railway: [relay/README.md](relay/README.md).

### Partida privada en tu PC (con código)

`MpBootMenu.offer_private_server` muestra *Private server*: arranca un dedicado en tu PC (`MpLocalServer`, mismo código que el VPS, sin servidor de salas), te une solo y el HUD de la partida (un `MpInviteLabel`, ya incluido en el `MpWorld`) muestra `ip:puerto#CÓDIGO`. Tus amigos escriben eso en el campo de dirección; sin el código no entran. Un segundo clic devuelve la partida que ya corre. Por código: `MpLocalServer.start_on(get_tree(), asientos)` y la señal `server_ready(address, port, codes)`.

### Salas online que hospedan tus jugadores (sin servidor tuyo)

Con el relay y el emisor (`issuer/`, un servidor Node + Express chico; los dos entran en las máquinas más chicas de Fly), el juego de un jugador hospeda cada partida: `flow.host_online(4, "Viernes a la noche")` abre una sala y su `room_ready(code)` da el código; los amigos llaman a `flow.join_online(code)` o eligen una de `flow.online_rooms()`. En `game.tres`: `issuer_url` y `game_id`. Un escritorio hospeda con un proceso de partida de su PC; un navegador hospeda en su propia pestaña y sigue simulando con la pestaña oculta. Ningún cliente lleva el secreto del relay: el emisor le da a cada host y jugador un token de un solo uso. Pasos: GUIDE 10.3, [issuer/README.md](issuer/README.md).

### Web

Un navegador no puede abrir un servidor ni usar UDP, así que un juego web se une a un dedicado WebSocket (`transport = ws` en `game.tres`) o por el relay (`transport = relay`). Escritorio y web no se mezclan: un servidor WebSocket atiende clientes WebSocket. En el campo de dirección del menú sirven `192.168.1.5`, `juego.ejemplo.com`, cualquiera con `:puerto`, o una URL `wss://…`. Una página servida por `https` necesita `wss://`: el servidor lleva certificado y clave (en su `game.tres`, o en el `MpLobbyConfig` para las salas, o con `deploy.sh --tls-cert … --tls-key …`) y el cliente prende `tls_client` en `game.tres`. Un navegador pausa una pestaña oculta: el jugador web que cambia de pestaña se frena para los demás hasta que vuelve, y si tarda más que `rejoin_grace_s` cuenta como abandono.

### Subirlo a un VPS

Exportá el preset de Linux y corré `addons/mp_kit/deploy/deploy.sh usuario@vps build/server --rooms 7700 --open-firewall`. Guía completa, varias instancias y web por https: [deploy/README.md](deploy/README.md).

Sin VPS: `addons/mp_kit/deploy/fly.sh --app mi-servidor-de-juego --relay-url wss://mi-relay.fly.dev` (con `MPKIT_RELAY_SECRET` puesta) sube el servidor a Fly.io detrás de tu relay, sin exportar: [GUIDE 13.6](GUIDE.md#136-sin-vps-flyio).

Detalle de cada pieza: [README.md](README.md). Paso a paso, para una persona: [GUIDE.md](GUIDE.md).
