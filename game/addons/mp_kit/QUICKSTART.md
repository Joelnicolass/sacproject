# MpKit en 6 pasos

Un juego multijugador sin escribir código de red: nodos en el editor y un script como el de un juego de un jugador. Funciona igual solo, en LAN (un jugador hostea) y con servidor dedicado, por ENet (UDP) o WebSocket (TCP).

El ejemplo completo está en `examples/arena_2d/`: abrí `boot.tscn` y apretá F6.

## 1. Instalar

Copiá `addons/mp_kit/` a tu proyecto y activá **MpKit** en Proyecto → Ajustes del proyecto → Plugins. Eso agrega el autoload `MpKit`.

## 2. Boot (el menú)

Escena nueva con raíz `Control`:

- Un hijo **MpFlow**. En el inspector: `boot_path` = esta escena, `world_path` = tu mundo, `max_players`.
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

- **MpActor**: tildá qué se sincroniza (posición, rotación, visible, y en *Extra* cualquier propiedad, por ejemplo `health` o `Health:current`). Guardá la escena: el editor arma el sincronizador y lo guarda.
- **MpInput**: la lista de acciones del InputMap que manda el jugador (por defecto las flechas y Enter).

## 5. Script del jugador

```gdscript
extends CharacterBody2D

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput

func _physics_process(_delta: float) -> void:
	if not net.is_authority():   # las reglas corren en el servidor (o en solo)
		return
	velocity = input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * 200.0
	move_and_slide()
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
| leer las teclas del jugador en el servidor | `input.get_vector`, `input.is_action_just_pressed`… (misma API que `Input`) |
| mandar un valor propio (punto de mira, cursor) | `input.set_value(&"aim", v)` en el dueño, `input.get_value(&"aim")` en el servidor |
| una orden puntual del jugador | `net.to_server(&"nombre", args)` → `func mp_sv_nombre(args)` |
| un efecto en todos (sonido, destello) | `net.to_all(&"nombre", args)` → `func mp_all_nombre(args)` |
| saber quién pidió una orden | `net.sender_slot()` dentro de `mp_sv_*` |
| un número de la partida | `MpState.of(self).set_value(&"clave", v)` / `.add(&"clave")`, señal `changed` |
| aparecer balas, unidades, pickups | `$MpSpawner.spawn_actor(escena, {"position": p})` (la escena va en *Extra Scenes*) |

Solo el dueño puede pedir `mp_sv_*` de su actor, y solo el servidor manda `mp_all_*`: el kit lo valida.

## 6. Probar

| Modo | Cómo |
|---|---|
| Solo | F5 → Jugar solo |
| LAN | Depurar → Ejecutar varias instancias (2). Una: Host LAN. Otra: Unirse a `127.0.0.1` |
| Dedicado | `godot --headless --path . -- --dedicated` y los clientes se unen a `127.0.0.1` |
| WebSocket | agregá `--transport=ws` a todos los procesos (un servidor WS solo atiende clientes WS) |

Detalle de cada pieza, salas online y despliegue: [README.md](README.md).
