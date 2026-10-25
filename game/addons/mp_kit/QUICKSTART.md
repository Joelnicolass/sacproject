# MpKit en 6 pasos

Un juego multijugador sin escribir código de red: nodos en el editor y un script como el de un juego de un jugador. Funciona igual solo, en LAN (un jugador hostea) y con servidor dedicado, por ENet (UDP) o WebSocket (TCP).

El ejemplo completo está en `examples/arena_2d/`: abrí `boot.tscn` y apretá F6.

## 1. Instalar

Copiá `addons/mp_kit/` a tu proyecto y activá **MpKit** en Proyecto → Ajustes del proyecto → Plugins. Eso agrega el autoload `MpKit`.

## 2. Boot (el menú)

Escena nueva con raíz `Control`:

- Un hijo **MpFlow**. En el inspector: `boot_path` = esta escena, `world_path` = tu mundo y `net_config` = un **MpNetConfig** nuevo (`.tres`): transporte, puerto, jugadores, dirección pública y TLS en un solo lugar.
- Una instancia de `res://addons/mp_kit/mp_boot_menu.tscn`: botones Jugar solo, Host LAN, Unirse y la lista de salas LAN.

El `MpFlow` se muda solo a la raíz del árbol y sobrevive a los cambios de escena. No hace falta autoload.

## 3. Mundo

Escena con raíz `Node2D` o `Node3D`:

| Nodo | Para qué |
|---|---|
| `SpawnPoints` con un `Marker2D`/`Marker3D` por jugador | dónde nace cada uno |
| `Actors` (vacío) | ahí aparecen los jugadores |
| **MpSlotSpawner** | `spawn_path` = `../Actors`, `pawn_scene` = tu jugador, `spawn_points` = `../SpawnPoints` |
| **MpState** (opcional) | puntaje, reloj, ronda: lo ven todos, también el que entra tarde |

## 4. Jugador

Escena del jugador (`CharacterBody2D`, `CharacterBody3D`...) con dos hijos:

- **MpActor**: tildá qué se sincroniza (posición, rotación, visible, y en *Extra* cualquier propiedad, por ejemplo `health` o `Health:current`) y prendé **Prediction › predict** para el jugador. Guardá la escena: el editor arma el sincronizador y lo guarda.
- **MpInput**: la lista de acciones del InputMap que manda el jugador (por defecto las flechas y Enter).

## 5. Script del jugador

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
		MpState.of(self).add(&"score")
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
| un número de la partida | `MpState.of(self).set_value(&"clave", v)` / `.add(&"clave")`, señal `changed` |
| aparecer balas, unidades, pickups | `$MpSpawner.spawn_actor(escena, {"position": p})` (la escena va en *Extra Scenes*) |

Solo el dueño puede pedir `mp_sv_*` de su actor, y solo el servidor manda `mp_all_*`: el kit lo valida.

### Red real: lag, jitter y pérdida

| Qué | Dónde | Qué hace |
|---|---|---|
| Predicción | **MpActor › Prediction › predict** + `func mp_move(input, delta)` | El dueño se mueve al instante con sus teclas. El servidor corre el mismo `mp_move` una vez por cada frame del dueño, en orden; cuando llega su estado, el dueño vuelve a él y repite los ticks que el servidor no vio (reconciliación). Mismos ticks: la corrección queda en ~0. |
| Suavizado | **MpActor › Smoothing** | `BUFFERED` (por defecto): los demás jugadores se dibujan `buffer_delay_s` en el pasado, entre dos estados reales del servidor: se ven parejos aunque los paquetes lleguen a destiempo. `FOLLOW`: persigue el último estado (sin demora, con tirones chicos). `NONE`: sin suavizado. |
| Ancho de banda | **MpActor › Sync › send_hz** | Estados por segundo (0 = cada frame). `BUFFERED` tapa los huecos. |
| Buffer de entrada | automático con predict | El servidor junta unos pocos frames del dueño antes de consumirlos de a uno por tick, así un jugador con jitter se mueve parejo para los demás. Un cliente que manda frames de más no va más rápido. |

Reglas de `mp_move`: solo movimiento (puede correr varias veces por tick al reconciliar). Sonidos y efectos detrás de `if not keys.is_replaying():`. Saltos con `is_action_just_pressed` sí van adentro: se ven igual en el dueño, en el servidor y al repetir.

Para probar con red mala, agregá a cada proceso `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` (lag de salida, jitter y pérdida de paquetes no confiables). `net.last_correction()` dice cuánto corrigió el servidor al dueño en el último estado.

## 6. Probar

| Modo | Cómo |
|---|---|
| Solo | F5 → Jugar solo |
| LAN | Depurar → Ejecutar varias instancias (2). Una: Host LAN. Otra: Unirse a `127.0.0.1` |
| Dedicado | `godot --headless --path . -- --dedicated` y los clientes se unen a `127.0.0.1` |
| WebSocket | agregá `--transport=ws` a todos los procesos (un servidor WS solo atiende clientes WS) |

| Web | exportá con el preset Web (sin threads). El export usa WebSocket solo y oculta Host y la lista LAN: un navegador solo se une. El servidor es un dedicado con `transport = ws` |

### Online: salas y varias partidas en un servidor

Tres escenas y cero glue (el ejemplo las trae: `rooms.tscn`, `lobby.tscn` y el `MpMatch` de `arena.tscn`):

| Dónde | Nodo | Qué hace |
|---|---|---|
| Servidor (VPS o tu PC) | **MpRoomServer** en una escena propia, con un **MpLobbyConfig** (`.tres`: puerto, salas, rango de puertos de partida, tiempos) y opcional un **MpRoomRules** | Abre el lobby. Cuando una sala está llena y todos listos, lanza **un proceso dedicado por partida** con un ticket: solo entran los sentados. Correlo con `godot --headless --path . res://rooms.tscn`. Varias partidas a la vez = varios procesos; el tope es `max_matches` |
| Cliente | **MpLobbyScreen** (`rooms/ui/mp_lobby_screen.tscn`) en una escena; en el boot, `MpBootMenu.lobby_scene_path` muestra el botón *Online rooms* y `MpFlow.lobby_path` dice adónde volver | Conectar con un nombre, ver salas, crear (pública o con código), sentarse, *listo*, chat. Al arrancar la partida se une solo y al terminar vuelve con el resultado |
| Mundo | **MpMatch** | En el servidor: `all_loaded`, `player_joined`, `player_left`, `player_back`, `player_abandoned`. `finish(resultado)` termina la partida para todos (`finished` en cada peer) y le avisa a la sala |

El proceso de cada partida es tu mismo proyecto con `--dedicated` y un ticket: `MpFlow` arma solo el agente que valida el ticket. Reglas de sala propias (cuántos asientos según el modo, qué personajes valen):

```gdscript
extends MpRoomRules

func seats_for(options: Dictionary) -> int:
	return 4 if options.get("mode") == "2v2" else 2

func accept_pick(pick: Dictionary) -> bool:
	return pick.get("hero") in ["knight", "archer"]
```

### Web

Un navegador no puede abrir un servidor ni usar UDP, así que un juego web se une a un dedicado WebSocket (`MpNetConfig.transport = ws`). Escritorio y web no se mezclan: un servidor WebSocket atiende clientes WebSocket. En el campo de dirección del menú sirven `192.168.1.5`, `juego.ejemplo.com`, cualquiera con `:puerto`, o una URL `wss://…`. Una página servida por `https` necesita `wss://`: o el dedicado tiene certificado y clave en su `MpNetConfig`, o un proxy (Caddy, nginx) pone el TLS delante.

Detalle de cada pieza, salas online y despliegue: [README.md](README.md).
