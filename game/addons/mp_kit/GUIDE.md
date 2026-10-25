# MpKit: guía completa, paso a paso

Esta guía es para una persona que sabe Godot básico (escenas, nodos, inspector, scripts) y quiere armar un juego multijugador con MpKit, sin escribir código de red. Expande [QUICKSTART.md](QUICKSTART.md): si algo de acá parece contradecirlo, avisá, porque es un error.

Los nombres de código (`MpActor`, `to_server`, `owner_slot`...) quedan en inglés, como en el kit. Los menús del editor se nombran en español; si tu editor está en inglés, el equivalente está entre paréntesis la primera vez.

## Índice

1. [Qué es MpKit](#1-qué-es-mpkit)
2. [Conceptos en palabras simples](#2-conceptos-en-palabras-simples)
3. [Instalar](#3-instalar)
4. [Camino A: el asistente Setup game](#4-camino-a-el-asistente-setup-game)
5. [Camino B: a mano, escena por escena](#5-camino-b-a-mano-escena-por-escena)
6. [Programar el jugador](#6-programar-el-jugador)
7. [Cosas del mundo: objetos, apariciones, puntaje, inicio y fin](#7-cosas-del-mundo-objetos-apariciones-puntaje-inicio-y-fin)
8. [Probar](#8-probar)
9. [Online con salas](#9-online-con-salas)
10. [Partida privada con código](#10-partida-privada-con-código)
11. [Web](#11-web)
12. [Subir a un VPS](#12-subir-a-un-vps)
13. [Seguridad y límites](#13-seguridad-y-límites)
14. [Problemas comunes](#14-problemas-comunes)
15. [Glosario](#15-glosario)
16. [Quiero X → uso Y](#16-quiero-x--uso-y)
17. [Dónde seguir](#17-dónde-seguir)

## 1. Qué es MpKit

MpKit es un addon de Godot 4 que resuelve la red de un juego multijugador. Vos armás escenas con unos pocos nodos y escribís el juego como si fuera de un jugador.

Qué resuelve:

- **Un modelo único: el servidor manda** (host-authoritative). Las reglas corren en un solo lugar, el servidor. Los clientes mandan teclas y pedidos; el servidor decide y les manda el resultado.
- **Los mismos archivos para todos los modos**:

| Modo | Quién es el servidor |
|---|---|
| Solo | Tu propia PC, sin red |
| LAN (listen server) | Un jugador "hostea": juega y a la vez es servidor |
| Dedicado | Un proceso sin jugador (tu PC o un VPS), los demás se unen |
| Salas online | Un servidor de salas (lobby) que arranca un dedicado por partida |
| Privada con código | Un dedicado en tu PC; tus amigos entran con un código |
| Web | Un navegador se une a un dedicado por WebSocket |

- **Dos transportes**: ENet (UDP, escritorio, lo más rápido) o WebSocket (TCP, obligatorio para web). La API es la misma.

Qué **no** hace: no trae gameplay. Ni puntaje, ni personajes, ni textos de juego. Eso es tuyo. Tampoco conviene instalarlo en un juego que es solo de un jugador.

## 2. Conceptos en palabras simples

| Palabra | Qué significa |
|---|---|
| **Servidor** | El proceso donde corren las reglas. En LAN es la PC del host; en dedicado, un proceso sin jugador. En solo, tu PC hace de servidor. |
| **Cliente** | Un proceso que se unió a un servidor. Manda teclas y pedidos, dibuja lo que el servidor le manda. |
| **Autoridad** | Donde se decide. En MpKit siempre es el servidor (o solo). `net.is_authority()` es verdadero ahí. |
| **Slot** | El número de jugador: 1, 2, 3… Lo asigna el servidor. Es lo que usa tu juego ("P1", "P2"). |
| **Peer id** | El número interno de conexión de Godot (1 = servidor, después números grandes al azar). **No lo uses como jugador**: usá el slot. |
| **Dueño** (`owner_slot`) | El slot del jugador al que pertenece un nodo. 0 = no es de nadie (es del servidor: una campana, una puerta). |
| **Local** | El nodo es del jugador que está sentado en esta máquina. `net.is_local()`. |
| **Proxy** | La copia de un nodo que esta máquina solo dibuja: en tu pantalla, los otros jugadores son proxies. |
| **Sincronizar** | Copiar una propiedad del servidor a todos (posición, vida, color). Se tilda en **MpActor › Sync**. |
| **Predicción** | El dueño mueve su personaje al instante con sus teclas, sin esperar al servidor. |
| **Reconciliación** | Cuando llega el estado real del servidor, el dueño vuelve a esa posición y repite las teclas que el servidor todavía no vio. Si todo coincide, la corrección es casi 0. |
| **Suavizado** | Cómo se dibujan los proxies entre dos estados del servidor, para que no salten. |

Slot vs peer id, con un ejemplo. En un dedicado con dos jugadores: el servidor es peer 1 y no tiene slot (`MpKit.local_slot()` da 0). Los clientes son slot 1 y slot 2, aunque sus peer id sean, por ejemplo, `1739281` y `20918377`. En LAN, el host es slot 1 **y** peer 1; el primer cliente, slot 2.

## 3. Instalar

1. Copiá la carpeta `addons/mp_kit/` a `res://addons/mp_kit/` de tu proyecto.
2. Abrí **Proyecto › Ajustes del proyecto › Plugins** (Project › Project Settings › Plugins).
3. Tildá **MpKit** (Enable).
4. Revisá **Ajustes del proyecto › Autoload**: tiene que aparecer `MpKit` apuntando a `res://addons/mp_kit/mp_kit.gd`. El plugin lo agrega solo al activarse.

Al activarlo pasa esto:

- Se agrega el autoload `MpKit`.
- Se copian plantillas de script a `res://script_templates/` (para `CharacterBody2D`, `CharacterBody3D`, `Node`, `Node2D`, `Node3D`). Al crear un script nuevo podés elegir, por ejemplo, la plantilla *MpKit actor*.
- Aparecen estas entradas en **Proyecto › Herramientas** (Project › Tools):

| Entrada | Qué hace |
|---|---|
| **MpKit: Setup game...** | El asistente: arma un juego completo (ver [Camino A](#4-camino-a-el-asistente-setup-game)). |
| **MpKit: Make selection a network actor** | Agrega un `MpActor` a cada nodo seleccionado y, si es un `CharacterBody2D`/`3D`, también un `MpInput`. Se deshace con Ctrl+Z. |
| **MpKit: New replicated feature...** | Crea `res://features/<id>/<id>.gd` + `.tscn` (camino de bajo nivel). |
| **MpKit: New session flow...** | Crea un `MpFlow` como autoload en `res://glue/session_flow.tscn`. **No hace falta** si ponés el `MpFlow` en la escena de boot (lo recomendado acá). |
| **MpKit: Install Cursor/VS Code snippets** | Copia snippets a `.vscode/mpkit.code-snippets`. |

## 4. Camino A: el asistente Setup game

El camino más corto. En dos minutos tenés un juego que anda solo, en LAN, dedicado y online.

### 4.1 Abrir el diálogo

1. Con el plugin activo, andá a **Proyecto › Herramientas › MpKit: Setup game...**
2. Se abre el diálogo *MpKit: setup a multiplayer game*.

### 4.2 Cada opción

| Opción | Qué es | Por defecto |
|---|---|---|
| **Folder** | Carpeta donde escribe todo. Tiene que empezar con `res://`. | `res://game` |
| **World** | `2D` o `3D`. | 2D |
| **Max players** | Jugadores de la partida (1 a 64). Va a `MpNetConfig.max_players` y a la cantidad de puntos de aparición. | 4 |
| **Transport** | `ENet (UDP, desktop)` o `WebSocket (TCP, web builds)`. Va a `MpNetConfig.transport`. | ENet |
| **Online rooms** | Agrega servidor de salas y pantalla de lobby. | tildado |
| **Private server button** | Muestra el botón *Private server* en el menú (partida en tu PC con código). | tildado |
| **Make the boot scene the main scene** | Pone el boot como escena principal del proyecto (F5 la abre). | tildado |

### 4.3 El árbol de archivos

Abajo, bajo **Files:**, el diálogo muestra qué va a escribir. Con la carpeta `res://game` y salas online:

```
[+] res://game/net.tres
[+] res://game/player.gd
[+] res://game/player.tscn
[+] res://game/world.tscn
[+] res://game/boot.tscn
[+] res://game/rooms_config.tres
[+] res://game/rooms.tscn
[+] res://game/lobby.tscn
```

- `[+]` = archivo nuevo.
- `[~]` = ya existe. Si aparece **uno solo** `[~]`, el botón **Create** se desactiva y no se escribe nada. Nunca pisa un archivo tuyo. Elegí otra carpeta.
- Sin *Online rooms* no aparecen las últimas tres.
- Ojo: si dejás tildado *Make the boot scene the main scene*, además se modifica `project.godot` (`application/run/main_scene`), aunque no figure en la lista.

Apretá **Create**. El editor escanea los archivos y abre `boot.tscn`.

### 4.4 Qué hay en cada archivo

**`net.tres`**: un `MpNetConfig` con el transporte y los jugadores que elegiste (puerto 7777).

**`player.tscn`**:

```
Player (CharacterBody2D o CharacterBody3D, motion_mode = Floating, script player.gd)
├── Visual   (Polygon2D cuadrado, o MeshInstance3D cápsula)
├── Shape    (CollisionShape2D / CollisionShape3D)
├── MpActor  (predict = on; sync_rotation solo en 3D)
│   └── MpSync (MultiplayerSynchronizer ya armado)
└── MpInput  (acciones ui_left, ui_right, ui_up, ui_down, ui_accept)
```

**`player.gd`**: movimiento en `mp_move`, y Enter (`ui_accept`) suma un punto en el `MpState` y hace un destello en todos (`mp_all_flash`).

**`world.tscn`**:

```
World (Node2D o Node3D)
├── Camera, Sun          (solo en 3D)
├── SpawnPoints          (P1..Pn en círculo, uno por jugador)
├── Actors               (vacío: ahí aparecen los jugadores)
├── Players              (MpSlotSpawner: spawn_path ../Actors, pawn_scene player.tscn, spawn_points ../SpawnPoints)
├── Score                (MpState, con su MpSync)
└── Match                (MpMatch)
```

**`boot.tscn`**:

```
Boot (Control, pantalla completa)
├── Flow  (MpFlow: net_config = net.tres, boot_path, world_path, lobby_path, room_server_path, start_when = Dedicated first client)
└── Menu  (instancia de mp_boot_menu.tscn: lobby_scene_path, offer_private_server)
```

**`rooms_config.tres`**: un `MpLobbyConfig` con `seats_per_room` = el menor entre *Max players* y 2. El resto, por defecto (lobby en 7700, partidas en 7800-7899, `transport = enet`).

**`rooms.tscn`**: un nodo `Rooms` con `MpRoomServer` y `config = rooms_config.tres`.

**`lobby.tscn`**: una instancia de `MpLobbyScreen` con `back_path` = el boot. Se conecta a `127.0.0.1:7700` (cambialo en `lobby_address` para un servidor real).

### 4.5 Probarlo enseguida

1. F5. Aparece el menú.
2. **Play solo**: flechas para mover, Enter para sumar un punto.
3. LAN: ver [8.2](#82-lan-dos-ventanas-en-tu-pc).
4. Online: ver [9.6](#96-correr-el-servidor-de-salas).

Lo que el asistente **no** agrega, y conviene que agregues vos:

- Un botón para volver al menú (el ejemplo tiene un *Leave* en el HUD). Ver [7.6](#76-volver-al-menú).
- Un fin de partida (`MpMatch.finish`). Sin eso, una partida de sala no termina hasta que se van todos.
- Si elegiste **WebSocket** y salas online: abrí `rooms_config.tres` y poné `transport = ws`. El asistente no lo cambia, y el servidor de salas le pasa su transporte a cada partida. Ver [9.8](#98-transporte-de-las-salas).

## 5. Camino B: a mano, escena por escena

Lo mismo que arma el asistente, con los clics del editor. Te sirve para entender qué hay, o para sumar MpKit a un juego que ya tenés. El ejemplo `examples/arena_2d/` está armado así.

### 5.1 La configuración de red (`MpNetConfig`)

1. En el panel **Sistema de archivos**, clic derecho en tu carpeta › **Nuevo › Recurso...**
2. Buscá **MpNetConfig** y creá `net.tres`.
3. En el inspector:

| Propiedad | Qué poner | Por defecto |
|---|---|---|
| `transport` | `enet` (escritorio) o `ws` (web, túneles TCP) | `enet` |
| `port` | Puerto del servidor | 7777 |
| `max_players` | Jugadores por partida | 4 |
| `public_host` | Dominio o IP pública. Hoy el kit no lo lee: dejalo vacío o usalo como nota | vacío |
| `custom_channels` | Canales permitidos del túnel `Dictionary` (vacío = todos) | vacío |
| `lan_discovery` | Anunciar la partida en la red local | on |
| Grupo **TLS (wss://)** | Ver [Web](#11-web) | vacío |

Los flags de línea de comando le ganan al `.tres`: `--transport=ws`, `--mp-port=N`, `--max-players=N`.

### 5.2 Escena de boot (el menú)

1. **Escena › Nueva escena**. Raíz: **Interfaz de usuario** (`Control`). Renombrala `Boot`.
2. Seleccioná `Boot`, **Agregar nodo hijo** (Ctrl+A), buscá **MpFlow** y agregalo. Renombralo `Flow`.
3. En el inspector del `Flow`:

| Propiedad | Qué poner |
|---|---|
| `net_config` | Arrastrá tu `net.tres` |
| `boot_path` | La ruta de esta misma escena, por ejemplo `res://game/boot.tscn` |
| `world_path` | La ruta de tu mundo, por ejemplo `res://game/world.tscn` |
| `start_when` | **Dedicated First Client** (como el ejemplo y el asistente) |
| `room_name` | Nombre que se ve en la lista LAN (ojo: el del menú le gana, ver abajo) |
| `lobby_path` | Solo con salas online: la escena de lobby |
| `room_server_path` | Solo con salas online: la escena con `MpRoomServer` |

4. Seleccioná `Boot` otra vez y **Instanciar escena hija** (Ctrl+Shift+A). Elegí `res://addons/mp_kit/mp_boot_menu.tscn`. Renombralo `Menu`.
5. En el inspector del `Menu` (un `MpBootMenu`):

| Propiedad | Qué hace |
|---|---|
| `title_text` | Título del menú |
| `room_name` | Nombre de la sala LAN. **Pisa** el `room_name` del `Flow` si no está vacío (por defecto `MpKit`) |
| `offer_private_server` | Botón *Private server* |
| `lobby_scene_path` | Botón *Online rooms*, que abre esa escena |
| `max_players` | Asientos del botón *Private server* (por defecto 4) |
| `play_solo_text`, `host_text`, `join_text`... | Los textos de los botones, para traducir |

6. Guardá la escena como `boot.tscn`.
7. **Proyecto › Ajustes del proyecto › General › Aplicación › Ejecutar › Escena principal**: elegí `boot.tscn`.

Qué tiene el menú: **Play solo**, **Host LAN**, **Private server** (opcional), **Online rooms** (opcional), un campo de dirección con **Join**, y la lista **LAN rooms**. En web se ocultan Host, Private y la lista LAN.

Qué hace el `MpFlow`: arranca la red con la config, cambia de escena (boot ↔ mundo), le manda el mundo al que entra tarde y vuelve al boot si se cae el servidor. Se muda solo a la raíz del árbol y sobrevive a los cambios de escena. No hace falta autoload.

### 5.3 Escena del mundo

1. **Escena › Nueva escena**. Raíz: **Escena 2D** (`Node2D`) o **Escena 3D** (`Node3D`). Renombrala `World`.
2. Agregá un hijo `Node2D` (o `Node3D`) llamado `SpawnPoints`.
3. Adentro, un `Marker2D` (o `Marker3D`) por jugador: `P1`, `P2`, `P3`, `P4`. Movelos donde querés que aparezca cada uno. El slot 1 usa el primero, el 2 el segundo; si hay más jugadores que marcas, vuelven a empezar.
4. Agregá un hijo `Node2D` (o `Node3D`) vacío llamado `Actors`. Ahí aparecen los jugadores.
5. Agregá un hijo **MpSlotSpawner** (buscalo por nombre; es un `MultiplayerSpawner`). Renombralo `Players`.
6. En su inspector:

| Propiedad | Valor |
|---|---|
| `spawn_path` | `../Actors` |
| `pawn_scene` | Tu `player.tscn` (lo armás en 5.4; podés volver después) |
| `spawn_points` | `../SpawnPoints` |
| `despawn_on_leave` | on: borra el jugador cuando se va |
| `hold_until_world_ready` | on (dejalo así) |
| `gate_unsynced_spawns` | on (dejalo así) |
| `room_id` | vacío |

7. Opcional, para el puntaje: agregá un hijo **MpState** llamado `Score`.
8. Opcional, para inicio y fin: agregá un hijo **MpMatch** llamado `Match`.
9. **Guardá la escena** (Ctrl+S). Al guardar, el `MpState` arma su hijo `MpSync` y queda guardado.

Qué hace el `MpSlotSpawner`: crea un jugador por slot ocupado. En solo, el tuyo. En LAN, el del host al arrancar y el de cada cliente cuando termina de cargar el mundo. En dedicado, ninguno para el servidor. Los llama `Pawn_1`, `Pawn_2`... y les pone `MpActor.owner_slot` antes de que entren al árbol.

### 5.4 Escena del jugador

1. **Escena › Nueva escena**. Raíz: `CharacterBody2D` (o `CharacterBody3D`). Renombrala `Player`.
2. Agregá lo visual y la colisión como siempre (`Polygon2D` o `Sprite2D`, `CollisionShape2D`).
3. Para un juego visto desde arriba, en el inspector de la raíz poné `motion_mode` = **Floating**.
4. Con la raíz seleccionada: **Proyecto › Herramientas › MpKit: Make selection a network actor**. Agrega `MpActor` y `MpInput`. (O agregalos a mano con **Agregar nodo hijo**.)
5. Configurá el `MpActor` (abajo, cada propiedad).
6. Configurá el `MpInput` (abajo).
7. Asignale un script a la raíz (ver [6](#6-programar-el-jugador)).
8. **Guardá la escena.** El `MpActor` arma su hijo `MpSync` (un `MultiplayerSynchronizer`) y se guarda en el `.tscn`. Sin guardar, el inspector del `MpActor` muestra el aviso *"Save the scene: the MpSync child is built in the editor."*

Importante: el `MpActor` tiene que estar en la **escena del actor** (`player.tscn`), no agregado sobre una instancia dentro del mundo. El `MpSync` solo se arma en la escena que es dueña del `MpActor`.

#### MpActor, propiedad por propiedad

**Grupo Sync** (qué ven todos):

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `sync_position` | Sincroniza la posición | on |
| `sync_rotation` | Sincroniza la rotación | on |
| `sync_visible` | Sincroniza `visible` | off |
| `sync_extra` | Más propiedades: del padre (`health`, `color_index`) o de un nodo de adentro (`Health:current`) | vacío |
| `send_hz` | Estados por segundo que manda el servidor. 0 = cada frame de física. Menos = menos ancho de banda | 0 |

Las transformaciones (y `velocity`) viajan siempre; lo demás, solo cuando cambia. Todo viaja al nacer, así que el que entra tarde ve los valores actuales.

**Grupo Smoothing** (cómo se dibujan los proxies):

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `smoothing` | `BUFFERED`: dibuja un poco en el pasado, entre dos estados reales; parejo aunque los paquetes lleguen desparejos. `FOLLOW`: persigue el último estado, sin demora pero con tirones chicos. `NONE`: dibuja cada estado tal cual llega | `BUFFERED` |
| `buffer_delay_s` | Con `BUFFERED`: cuánto en el pasado (más = tapa redes peores, pero se ve más atrasado) | 0.1 |
| `follow_speed` | Con `FOLLOW`: qué tan rápido persigue | 14.0 |
| `freeze_rigid_if_proxy` | Si el padre es un `RigidBody`, lo congela en los clientes (la física corre en el servidor) | on |

**Grupo Prediction**:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `predict` | El dueño se mueve al instante. Necesita un `MpInput` al lado y `func mp_move(input, delta)` en el padre | off |

**Grupo Owner**:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `owner_slot` | Slot dueño. 0 = el servidor. **No lo toques en un jugador**: lo pone el spawner | 0 |

Con `smoothing` distinto de `NONE` o con `predict`, la posición no viaja en `position` sino en `MpActor:net_position` (y `net_rotation`, `net_stamp`). Si mirás el panel Replicación del `MpSync`, vas a ver eso: es normal. En el cliente, solo `MpActor` mueve el nodo.

#### MpInput

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `actor` | El `MpActor` al que pertenece. Vacío = el que está al lado | vacío |
| `actions` | Acciones del **Mapa de entrada** que manda el jugador. **Solo esas** se pueden leer en el servidor | `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_accept` |

Si usás acciones propias (`jump`, `shoot`), crealas en **Ajustes del proyecto › Mapa de entrada** y agregalas a `actions`. El ejemplo agrega `ui_select` (Espacio) para disparar.

### 5.5 Conectar todo

1. En `world.tscn`, en el `MpSlotSpawner`, asigná `pawn_scene` = `player.tscn`.
2. En `boot.tscn`, en el `Flow`, revisá `world_path`.
3. Guardá todo y apretá F5.

## 6. Programar el jugador

El script del jugador se escribe como el de un juego de un jugador, con tres reglas:

- **El movimiento** va en `mp_move(keys, delta)`.
- **Las reglas** (puntos, disparos, daño) van detrás de `if net.is_authority()`.
- **Las teclas** se leen de `input` (el `MpInput`), no de `Input`, cuando las usa el servidor.

### 6.1 El esqueleto

Del ejemplo (`examples/arena_2d/player.gd`):

```gdscript
extends CharacterBody2D

const SPEED := 220.0

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput


func mp_move(keys: MpInput, _delta: float) -> void:
	velocity = keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * SPEED
	move_and_slide()


func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	if input.is_action_just_pressed(&"ui_accept"):
		MpState.of(self).add(StringName("p%d" % net.owner_slot))
		net.to_all(&"flash")
```

### 6.2 `mp_move` y sus reglas

Con **Prediction › predict** prendido, `mp_move(keys, delta)` lo corren:

- el servidor, una vez por cada frame de teclas del dueño, en orden;
- el dueño, al instante, con sus propias teclas;
- el dueño otra vez, al reconciliar: repite los frames que el servidor todavía no confirmó.

Por eso:

1. Poné **solo movimiento** ahí: puede correr varias veces en un mismo tick.
2. Leé las teclas del parámetro (`keys`), no de `Input`.
3. Sonidos y efectos, detrás de `if not keys.is_replaying():`.
4. Saltos con `keys.is_action_just_pressed(&"jump")` **sí** van adentro: se ven igual en el dueño, en el servidor y al repetir.
5. Puntos, daño, disparos: **no** van ahí. Van en `_physics_process` detrás de `is_authority()`.
6. El kit corrige posición y rotación. Si tu movimiento acumula velocidad entre ticks (gravedad, inercia), puede haber correcciones chicas: `net.last_correction()` te dice cuánto.

Sin `predict`, `mp_move` **no se llama**. Ahí movés en `_physics_process` detrás de `is_authority()`, leyendo `input`. Funciona, pero el dueño ve su propio movimiento con el retraso de la red.

```gdscript
# Sin predicción: el servidor mueve, todos dibujan.
func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	velocity = input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * SPEED
	move_and_slide()
```

### 6.3 ¿Dónde estoy? `is_authority` e `is_local`

| Llamada | Verdadero cuando | Para qué |
|---|---|---|
| `net.is_authority()` | Solo, o en el servidor (LAN host o dedicado) | Las reglas del juego |
| `net.is_local()` | En la máquina del jugador dueño de este nodo | Cámara, HUD propio, leer el mouse |
| `MpKit.is_networked()` | Hay red (no es solo) | Textos tipo "Solo" / "Online" |
| `MpKit.is_server()` | Este proceso es servidor con red | |
| `MpKit.is_dedicated()` | Servidor sin jugador | No reproducir sonidos, no esperar teclas |
| `MpKit.local_slot()` | El slot de esta máquina (0 en un dedicado o antes de que el servidor asigne) | "Sos P2" |

En un host LAN, `is_authority()` **y** `is_local()` son verdaderos a la vez para su propio jugador.

### 6.4 Teclas del jugador: `input.*`

`MpInput` tiene la misma API que `Input`. En la máquina del dueño (y en solo, y en el host para su propio jugador) lee `Input` directo; en el servidor lee lo que mandó el dueño.

| Método | Igual que |
|---|---|
| `input.is_action_pressed(&"a")` | `Input.is_action_pressed` |
| `input.is_action_just_pressed(&"a")` | `Input.is_action_just_pressed` (no se pierde aunque se pierda un paquete) |
| `input.is_action_just_released(&"a")` | `Input.is_action_just_released` |
| `input.get_action_strength(&"a")` | `Input.get_action_strength` |
| `input.get_axis(&"neg", &"pos")` | `Input.get_axis` |
| `input.get_vector(&"l", &"r", &"u", &"d")` | `Input.get_vector` (largo máximo 1, zona muerta 0.2) |
| `input.is_replaying()` | Verdadero mientras se repiten frames viejos |

Una acción que no está en `MpInput.actions` siempre da 0 / falso en el servidor.

### 6.5 Valores propios: `set_value` / `get_value`

Para lo que no es una tecla: el punto de mira, el cursor. El dueño lo pone; el servidor lo lee.

```gdscript
func _process(_delta: float) -> void:
	if not net.is_local():
		return
	input.set_value(&"aim", (get_global_mouse_position() - global_position).normalized())

# en el servidor, por ejemplo al disparar:
var aim: Vector2 = input.get_value(&"aim", Vector2.RIGHT)
```

`set_value` fuera del dueño no hace nada. Hasta 16 valores por frame. Lo que llega lo mandó el cliente: validalo (ver [13](#13-seguridad-y-límites)).

### 6.6 Pedidos al servidor: `to_server` → `mp_sv_*`

Una orden puntual del jugador (cambiar de color, comprar, usar un ítem):

```gdscript
func _process(_delta: float) -> void:
	if net.is_local() and Input.is_action_just_pressed(&"ui_focus_next"):
		net.to_server(&"recolor")   # corre mp_sv_recolor() en el servidor


func mp_sv_recolor() -> void:
	color_index += 1                # color_index está en MpActor › Sync › Extra: todos lo ven
```

- `net.to_server(&"nombre", arg1, arg2...)` corre `mp_sv_nombre(arg1, arg2...)` en el servidor.
- En solo y en el servidor corre al toque.
- Solo se puede llamar un método que empiece con `mp_sv_` y que acepte esa cantidad de argumentos.
- En un nodo con dueño, **solo el dueño** puede pedirlo. En un nodo sin dueño (`owner_slot = 0`), **cualquier jugador** puede.
- Dentro de `mp_sv_*`, `net.sender_slot()` dice quién lo pidió (0 = el propio servidor; fuera de un `mp_sv_*` da -1).

### 6.7 Efectos en todos: `to_all` → `mp_all_*`

Un sonido, un destello, una partícula: algo que pasa una vez.

```gdscript
# en el servidor:
net.to_all(&"flash")


func mp_all_flash() -> void:
	body.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(body, "modulate", Color.WHITE, 0.25)
```

- Solo el servidor puede llamar `to_all`. Corre ahí y en cada peer que ya tiene el nodo.
- El que entra después **no** lo recibe. Para algo que tiene que quedar (un color, una puerta abierta), usá **Sync** o `MpState`.

### 6.8 Más del `MpActor`

| Llamada | Qué hace |
|---|---|
| `net.despawn()` | Solo servidor: borra el nodo en todos (si lo creó un spawner) |
| `net.snap()` | Después de teletransportar: en el cliente salta a la pose del servidor en vez de deslizarse |
| `net.last_correction()` | Con predicción, en el dueño: cuánto lo corrigió el servidor en el último estado (0 = la predicción acertó) |
| `net.owner_slot` | El slot dueño (para mostrar "P1", elegir color...) |
| `MpActor.of(nodo)` | El `MpActor` hijo de un nodo, o `null` |

Ejemplo de `snap` después de un respawn:

```gdscript
func respawn(at: Vector2) -> void:   # en el servidor
	position = at
	net.to_all(&"respawned")

func mp_all_respawned() -> void:
	net.snap()
```

## 7. Cosas del mundo: objetos, apariciones, puntaje, inicio y fin

### 7.1 Un objeto sin dueño (la campana del ejemplo)

Una puerta, una palanca, una campana: está en el mundo desde el principio y no es de ningún jugador.

1. Hacé su escena (`bell.tscn`) con un `MpActor` hijo.
2. En el `MpActor`: `sync_position` off y `sync_rotation` off (no se mueve), `smoothing` = `NONE`, `sync_extra` = `rings`.
3. Guardá la escena.
4. Instanciala en el mundo (a mano, no por spawner).

```gdscript
extends Node2D

@export var rings: int = 0:
	set(value):
		rings = value
		if is_node_ready():
			$Label.text = "Bell %d" % rings

@onready var net: MpActor = $MpActor


func ring() -> void:          # lo llama cualquier jugador en su máquina
	net.to_server(&"ring")


func mp_sv_ring() -> void:    # corre en el servidor
	rings += 1
	MpState.of(self).set_value(&"bell_by", net.sender_slot())
```

Como `owner_slot` es 0, cualquier jugador puede pedir `mp_sv_ring`, y `sender_slot()` dice quién fue. El valor `rings` está en Sync: lo ven todos, también el que entra tarde.

Un nodo estático con `MpActor` no necesita nada más: el spawner del mundo lo retiene hasta que cada peer está listo.

### 7.2 Aparecer cosas: balas, unidades, pickups

1. En el mundo, agregá un `Node2D` vacío llamado `Projectiles`.
2. Agregá un **MpSpawner** (buscalo por nombre) llamado `Shots`.
3. En su inspector: `spawn_path` = `../Projectiles`.
4. En **Extra Scenes**, agregá `shot.tscn`. **Obligatorio**: todos los peers necesitan la misma lista; no se puede agregar solo en el servidor.
5. Para encontrarlo desde el jugador, ponelo en un grupo: pestaña **Nodo › Grupos**, `shot_spawner`.

La bala (`shot.tscn`) tiene su `MpActor` (posición sincronizada, `sync_rotation` off). Desde el servidor:

```gdscript
const SHOT := preload("res://addons/mp_kit/examples/arena_2d/shot.tscn")

func _shoot() -> void:   # en el servidor
	var shots := get_tree().get_first_node_in_group(&"shot_spawner") as MpSpawner
	var aim: Vector2 = input.get_value(&"aim", Vector2.RIGHT)
	shots.spawn_actor(SHOT, {"position": position, "direction": aim}, net.owner_slot)
```

`spawn_actor(escena, props, owner_slot)`:

- Solo corre en el servidor (o en solo).
- `props` se aplican **antes** de que el nodo entre al árbol (su `_ready` ya los ve).
- `props` se ponen solo en el servidor. Lo que los clientes tengan que ver, tiene que estar en Sync (la posición lo está; `direction` no hace falta porque el servidor mueve la bala).
- `owner_slot` > 0 hace dueño a ese jugador.

### 7.3 Borrar cosas

En la bala, cuando se acaba su vida:

```gdscript
func _physics_process(delta: float) -> void:
	if not net.is_authority():
		return
	position += direction * SPEED * delta
	_age += delta
	if _age >= LIFE_S:
		net.despawn()   # se borra en todos
```

Los jugadores los borra solo el `MpSlotSpawner` cuando se van (`despawn_on_leave`).

### 7.4 Estado de partida: `MpState`

Para lo que tienen que ver todos y no es de un actor: puntaje, reloj, ronda.

| Llamada | Qué hace |
|---|---|
| `MpState.of(self)` | El `MpState` de la escena actual, desde cualquier nodo. Con varios: `MpState.of(self, &"Score")` |
| `state.set_value(&"clave", v)` | Solo servidor: pone un valor |
| `state.add(&"clave", 1)` | Solo servidor: suma (si no existe, arranca en 0) |
| `state.get_value(&"clave", default)` | Lee, en cualquier peer |
| `state.values` | El `Dictionary` completo (para leer). Valores iniciales: cargalos en el inspector |
| señal `changed(key, value)` | En todos los peers, cada vez que cambia una clave |

Un HUD que lo muestra (del ejemplo, `hud.gd`):

```gdscript
@export var state: MpState

func _ready() -> void:
	state.changed.connect(_refresh.unbind(2))
	_refresh()
```

No escribas `state.values["x"] = 3` a mano: no se sincroniza. Usá `set_value`.

### 7.5 Inicio y fin: `MpMatch`

Un `MpMatch` en el mundo dice cuándo empieza la partida, quién se fue y quién volvió, y la termina para todos.

Señales (todas en el servidor, salvo `finished`):

| Señal | Cuándo |
|---|---|
| `all_loaded` | Están todos (partida de sala) o el mundo está listo (LAN, dedicado, solo) |
| `player_joined(slot)` | Entró un jugador por primera vez |
| `player_left(slot)` | Se fue un jugador |
| `player_back(slot)` | Solo partida de sala: volvió dentro de la gracia, mismo slot |
| `player_abandoned(slot)` | Solo partida de sala: no volvió a tiempo, o nunca cargó |
| `finished(result)` | **En todos los peers**: el servidor llamó `finish` |

Métodos:

| Método | Qué hace |
|---|---|
| `finish(result)` | Solo servidor: termina la partida. Todos reciben `finished(result)`. En una partida de sala, además escribe el resultado para la sala |
| `seats()` | Los slots del ticket de sala (vacío fuera de una partida de sala) |

Propiedad: `pause_until_loaded` (on): en una partida de sala, el mundo queda pausado hasta que cargan todos o pasa `load_timeout_s`.

Del ejemplo (`arena.gd`): gana el primero que llega a 3; el que abandona pierde.

```gdscript
const WIN_SCORE := 3

@onready var score: MpState = $Score
@onready var match_node: MpMatch = $Match


func _ready() -> void:
	score.changed.connect(_on_score)
	match_node.finished.connect(_on_finished)
	match_node.player_abandoned.connect(_on_abandoned)


func _on_score(key: StringName, value: Variant) -> void:
	if MpKit.is_authority() and int(value) >= WIN_SCORE:
		match_node.finish({"winner": String(key)})


func _on_abandoned(slot: int) -> void:
	for other in match_node.seats():
		if other != slot:
			match_node.finish({"winner": "p%d" % other, "abandoned": slot})
			return


func _on_finished(result: Dictionary) -> void:
	%Info.text = "%s wins!" % str(result.get("winner", "?")).to_upper()
	if MpKit.is_dedicated():
		return
	await get_tree().create_timer(2.0).timeout
	MpFlow.find_in_tree(self).leave_match()
```

`leave_match()` vuelve al lobby si la partida vino de una sala, o al menú si no.

### 7.6 Volver al menú

Un botón *Salir* en el HUD:

```gdscript
%Leave.pressed.connect(func() -> void: MpFlow.find_in_tree(self).return_to_boot())
```

Usá `MpFlow.find_in_tree(self)` para llegar al flow desde cualquier nodo.

## 8. Probar

### 8.1 Solo

1. F5.
2. **Play solo**.

En solo, tu PC es servidor y dueño a la vez: `is_authority()` e `is_local()` son verdaderos. Todo el código corre, sin red.

### 8.2 LAN: dos ventanas en tu PC

1. Menú **Depurar › Ejecutar varias instancias** (Debug › Run Multiple Instances) y elegí 2.
2. F5. Se abren dos ventanas.
3. En una: **Host LAN**.
4. En la otra: escribí `127.0.0.1` en el campo de dirección y **Join**. (O elegí la sala en *LAN rooms* si aparece.)

En dos PCs de la misma red: en la del cliente, la sala aparece en *LAN rooms* (el host la anuncia por UDP, puerto 7778). Si no aparece, escribí la IP que muestra el menú del host abajo de la lista.

### 8.3 Dedicado

En una terminal, en la carpeta del proyecto:

```bash
godot --headless --path . -- --dedicated
```

Después abrí clientes (F5, o varias instancias) y uní cada uno a `127.0.0.1`. El servidor no tiene jugador: el primer cliente es P1.

Desde el editor: en el diálogo de personalizar instancias del menú **Depurar**, poné `--headless -- --dedicated` en los argumentos de una instancia (marcá que anule los argumentos).

### 8.4 WebSocket

Agregá `--transport=ws` a **todos** los procesos (servidor y clientes), o poné `transport = ws` en el `MpNetConfig`. Un servidor WebSocket solo atiende clientes WebSocket.

```bash
godot --headless --path . -- --dedicated --transport=ws
godot --path . -- --transport=ws
```

### 8.5 Red mala a propósito

Para ver cómo se siente con lag de verdad, agregá a cada proceso:

```bash
godot --path . -- --net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05
```

| Flag | Qué hace |
|---|---|
| `--net-lag-ms=N` | Demora de salida, en milisegundos |
| `--net-jitter-ms=N` | Demora extra al azar, hasta N ms |
| `--net-loss=P` | Probabilidad de perder un paquete no confiable (0.05 = 5%) |

Es solo de salida: ponelo en el servidor **y** en los clientes para tener ida y vuelta. Al arrancar se imprime `MpLagPeer: 100 ms + 30 ms jitter, 5% loss`. Los paquetes confiables nunca se pierden. Nunca lo dejes en un build de verdad.

Qué ajustar mirando:

- Los otros jugadores tironean: subí `buffer_delay_s`, o pasá a `BUFFERED`.
- Tu jugador responde tarde: prendé `predict`.
- Tu jugador "salta" seguido: imprimí `net.last_correction()`; si es alto, revisá que `mp_move` solo dependa de las teclas y la posición.

### 8.6 Cómo leer lo que pasa

- **El menú** muestra el estado abajo (*Connecting to…*, *Could not join*, *Lost the server*).
- **El HUD del ejemplo** muestra el rol: *Solo*, *Host · P1*, *Client · P2*, *Dedicated server*. Copialo para tu juego (`hud.gd`).
- **Panel Depurador › Errores**: los avisos del kit empiezan con el nombre del nodo (`MpActor on 'Pawn_2': ...`). Ver [14](#14-problemas-comunes).
- **Árbol remoto** (pestaña *Remoto* del panel Escena, con el juego corriendo): ves los nodos del proceso, `/root/MpKit`, tus `Pawn_N` y sus valores.
- **El servidor de salas** imprime una línea por evento: `rooms ready port 7700 (enet)`, `match for room "x" on port 7810`, `match … ended {…}`, `match … failed …`.

### 8.7 Flags útiles

| Flag | Qué hace |
|---|---|
| `--dedicated` | Arranca como servidor dedicado y carga el mundo |
| `--listen-host` | Arranca hosteando LAN, sin tocar el menú |
| `--client1` / `--client2` + `--join-ip=IP` | Arranca uniéndose a esa IP (por defecto `127.0.0.1`) |
| `--room-server` | Abre la escena de `MpFlow.room_server_path` |
| `--mp-port=N` | Puerto (le gana al `MpNetConfig`) |
| `--max-players=N` | Jugadores (le gana al `MpNetConfig`) |
| `--transport=enet` / `ws` | Transporte |
| `--world=id` | Mundo, si usás el catálogo `MpFlow.worlds` |
| `--no-flow` | El `MpFlow` no hace nada (herramientas y pruebas) |

Van después de `--` en la línea de comando.

### 8.8 Los tests del kit

```bash
godot --headless --path . --script res://addons/mp_kit/tests/mp_test_runner.gd
```

Tiene que terminar con `MPKIT TESTS PASS (n)`. Prueban piezas sueltas (slots, frames de input, sincronizador, asistente), no partidas en red.

## 9. Online con salas

Para jugar por internet sin que nadie escriba IPs: un **servidor de salas** (el lobby) donde la gente se conecta con un nombre, crea o elige una sala, se sienta y dice *listo*. Cuando todos están listos, el servidor arranca **un proceso dedicado por partida** y le pasa a cada jugador la dirección y un token. Solo entran los sentados.

```
Cliente A ─┐                                 ┌─> Partida 1 (dedicado, puerto 7800)
Cliente B ─┼─> Servidor de salas (7700) ─────┤
Cliente C ─┘     lobby, salas, chat          └─> Partida 2 (dedicado, puerto 7801)
```

Son tres piezas, cero código de pegamento. El ejemplo las trae: `rooms.tscn`, `lobby.tscn` y el `MpMatch` de `arena.tscn`.

### 9.1 La escena del servidor: `MpRoomServer`

1. Escena nueva, raíz `Node`, llamala `Rooms`.
2. Asignale el script `res://addons/mp_kit/rooms/mp_room_server.gd` (o agregá un nodo **MpRoomServer**).
3. En el inspector:

| Propiedad | Qué poner |
|---|---|
| `config` | Un `MpLobbyConfig` (`.tres`, abajo) |
| `rules` | Opcional: tus reglas (`MpRoomRules`, abajo). Vacío = acepta todo, 2 asientos |
| `match_scene` | Escena que abre cada partida. Vacío = la escena principal (lo normal: tiene el `MpFlow`) |

4. Guardala como `rooms.tscn`.

### 9.2 `MpLobbyConfig`: los campos importantes

Creala como recurso nuevo (**Nuevo › Recurso › MpLobbyConfig**).

| Campo | Qué es | Por defecto |
|---|---|---|
| `lobby_port` | Puerto del lobby | 7700 |
| `transport` | `enet` o `ws`. Lo usa el lobby y se lo pasa a cada partida | `enet` |
| `max_connections` | Conexiones al lobby a la vez | 64 |
| `max_rooms` | Salas a la vez | 32 |
| `seats_per_room` | Asientos por sala si tus reglas no dicen otra cosa | 2 |
| `max_seats_per_room` | Tope de asientos, digan lo que digan las reglas | 8 |
| `countdown_s` | Cuenta regresiva cuando están todos listos | 5.0 |
| `empty_room_close_s` | Cierra una sala vacía después de esto | 120.0 |
| `resume_grace_s` | Cuánto guarda el lobby el asiento de alguien que se cayó del lobby | 120.0 |
| `public_host` | Dirección de las partidas que se manda a los clientes. Vacío = la misma que usaron para el lobby | vacío |
| `tls_certificate_path`, `tls_key_path` | Certificado y clave PEM para `wss://` | vacío |
| `max_matches` | Partidas a la vez en esta máquina (cada una es un proceso) | 99 |
| `match_port_min`, `match_port_max` | Rango de puertos de las partidas | 7800-7899 |
| `ticket_ttl_s` | Cuánto vale el ticket para entrar a la partida | 60.0 |
| `rejoin_grace_s` | Cuánto puede tardar en volver un jugador que se cayó de la partida | 60.0 |
| `load_timeout_s` | Cuánto espera la partida a que todos carguen el mundo | 60.0 |
| `idle_no_players_s` | La partida se cierra si queda vacía este tiempo | 60.0 |
| `match_max_s` | Duración máxima de una partida (2 horas) | 7200.0 |

Cualquier campo se pisa con un flag de su nombre, con guiones: `max_matches` → `--max-matches=8`, `lobby_port` → `--lobby-port=7701`. Otro `.tres` entero: `--lobby-config=res://otra.tres`.

El ejemplo (`rooms_config.tres`) usa lobby 7700, 2 asientos, cuenta de 3 s, 4 partidas y puertos 7710-7719.

### 9.3 Reglas propias: `MpRoomRules`

Un script que extiende `MpRoomRules` y pisa las funciones que necesitás. Todas corren en el servidor de salas con lo que mandó un cliente: chequealo, no le creas.

| Función | Para qué | Por defecto |
|---|---|---|
| `seats_for(options) -> int` | Asientos según las opciones de la sala. 0 o menos = rechaza. -1 = `seats_per_room` | -1 |
| `accept_options(options) -> bool` | ¿Valen esas opciones (mapa, modo)? Falso = error `bad_options` | true |
| `accept_pick(pick) -> bool` | ¿Vale lo que eligió el jugador (personaje, equipo)? Falso = `bad_meta` | true |
| `accept_bot(pick) -> bool` | ¿Vale el bot que puso el anfitrión? Falso = `bad_bot` | true |
| `build_ticket(seats, options) -> Dictionary` | Qué recibe la partida. Mantené `seats`; agregá lo que haga falta (semilla, mapa) | `{"options": ..., "seats": ...}` |

```gdscript
# my_rules.gd
extends MpRoomRules

func seats_for(options: Dictionary) -> int:
	return 4 if options.get("mode") == "2v2" else 2

func accept_pick(pick: Dictionary) -> bool:
	return pick.get("hero") in ["knight", "archer"]
```

1. Guardá el script.
2. **Nuevo › Recurso**, buscá tu script (`my_rules.gd`), guardalo como `my_rules.tres`.
3. Asignalo a `MpRoomServer.rules`.

Ojo con dos cosas:

- La pantalla de lobby que trae el kit crea salas **sin opciones** (`{}`). Para que `seats_for` vea un `mode`, tu UI tiene que llamar `create_room(nombre, privada, {"mode": "2v2"})` (ver 9.4).
- El pick por defecto es `{"pick": "default"}`. Con el `accept_pick` de arriba, ese pick se rechaza: cambiá `default_pick` en la pantalla de lobby o llamá `set_pick` desde tu UI.

### 9.4 La pantalla del cliente: `MpLobbyScreen`

1. **Escena › Nueva escena heredada…** y elegí `res://addons/mp_kit/rooms/ui/mp_lobby_screen.tscn` (así está hecho el `lobby.tscn` del ejemplo). Guardala como `lobby.tscn`.
2. En el inspector:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `lobby_address` | `host:puerto` del servidor de salas (se puede editar en pantalla) | `127.0.0.1:7700` |
| `player_name` | Nombre inicial | `Player` |
| `default_pick` | El pick con el que arranca cada asiento. El lobby necesita uno antes de *listo* | `{"pick": "default"}` |
| `auto_join_match` | Entrar a la partida apenas arranca. Off = se emite `match_found` y tu UI llama `join_found()` | on |
| `back_path` | Escena del botón *Back* (el boot) | vacío |
| Grupo **Texts** | Todos los textos, para traducir | |

Qué hace: pantalla de conectar (nombre y dirección), lista de salas, crear sala (pública o con código), unirse con código, asientos, *Ready*, chat. Al arrancar la partida se une solo (por el `MpFlow`); al terminar vuelve acá y muestra el último resultado.

Cada botón llama un método público, así podés hacer tu propia pantalla encima:

| Método | Qué hace |
|---|---|
| `connect_lobby(address, name)` | Conecta |
| `refresh()` | Pide la lista de salas |
| `create_room(nombre, privada, options)` | Crea una sala |
| `join_room(id)` / `join_listed(index)` / `join_code(codigo)` | Entra a una sala |
| `set_pick(dict)` | Cambia lo que eligió el jugador |
| `set_ready(on)` | Listo / no listo |
| `leave_room()` | Se levanta |
| `send_chat(texto)` | Chat |
| `go_back()` | Cierra y vuelve a `back_path` |
| `join_found()` | Con `auto_join_match` off: entra a la partida encontrada |

### 9.5 Conectar el boot con las salas

En `boot.tscn`:

1. En el `Flow`: `lobby_path` = tu `lobby.tscn` (adonde vuelve al terminar una partida) y `room_server_path` = tu `rooms.tscn` (lo que abre `--room-server`).
2. En el `Menu`: `lobby_scene_path` = tu `lobby.tscn`. Aparece el botón **Online rooms**.

El `MpFlow` vive en el boot. Por eso el juego tiene que arrancar por el boot: si abrís `lobby.tscn` directo con F6, no hay flow y no puede entrar a la partida.

En el mundo, el `MpMatch` hace el resto: espera a que carguen todos, avisa ausencias y escribe el resultado.

### 9.6 Correr el servidor de salas

En tu PC, para probar:

```bash
godot --headless --path . res://rooms.tscn
# o, con MpFlow.room_server_path puesto:
godot --headless --path . -- --room-server
```

Con el ejemplo:

```bash
godot --headless --path . res://addons/mp_kit/examples/arena_2d/rooms.tscn
```

Después abrí dos clientes (F5 dos veces), **Online rooms**, **Connect**, uno crea la sala, el otro entra, los dos tildan **Ready**. Arranca la cuenta y la partida.

Cada partida es tu mismo proyecto corriendo con `--dedicated` y un ticket. El `MpFlow` arma solo el agente que valida el ticket. Varias partidas a la vez son varios procesos, hasta `max_matches`.

### 9.7 Qué pasa cuando alguien se cae

**En el lobby**: el servidor le guarda el asiento `resume_grace_s` (120 s).

**En la partida**:

1. El servidor emite `player_left(slot)`. El `MpSlotSpawner` borra su jugador (si `despawn_on_leave`).
2. Si vuelve dentro de `rejoin_grace_s` (60 s) con su mismo ticket, recupera su slot: `player_back(slot)`, y el spawner le crea un jugador nuevo en su punto de aparición. Qué conserva (puntos, vida) lo decidís vos: lo que está en `MpState` sigue ahí.
3. Si no vuelve a tiempo, o nunca cargó el mundo (`load_timeout_s`): `player_abandoned(slot)`. Qué significa (pierde, se sigue sin él) lo decidís vos, como en el ejemplo.
4. Si se cae el servidor de salas, sus partidas se cierran solas en pocos segundos (`parent_check_s`).
5. Si una partida queda vacía `idle_no_players_s`, se cierra.

Un jugador que se cae de la partida vuelve al lobby (`lobby_path`) con *Lost the server*. La pantalla de lobby no trae un botón para volver a esa partida: si lo querés, hacé uno en tu UI con los datos de la última partida.

```gdscript
func _on_rejoin_pressed() -> void:
	var last := MpLobbyLink.client(get_tree()).last_match()   # {host, port, token}
	if not last.is_empty():
		MpFlow.find_in_tree(self).join_match(last["host"], last["port"], last["token"])
```

### 9.8 Transporte de las salas

Tiene que ser el mismo en todos: el lobby, cada partida y cada cliente.

- El servidor de salas usa `MpLobbyConfig.transport` (o `--transport=`), y se lo pasa a cada partida como `--transport=…`. Ese flag le gana al `MpNetConfig` de la partida.
- En el cliente, la pantalla de lobby y la partida usan el `MpNetConfig` del flow (en web, siempre WebSocket).

En la práctica, los dos `.tres` tienen que decir lo mismo:

| Juego | `MpNetConfig.transport` | `MpLobbyConfig.transport` |
|---|---|---|
| Escritorio (ENet) | `enet` | `enet` |
| Web, o web y escritorio juntos | `ws` | `ws` |

## 10. Partida privada con código

Sin VPS y sin servidor de salas: un dedicado en tu PC, y tus amigos entran con un código.

### 10.1 Con el botón

1. En el `Menu` del boot, tildá `offer_private_server`. (El asistente lo deja tildado.)
2. En el `Menu`, `max_players` = asientos de la partida privada (por defecto 4). Que no supere el `max_players` del `MpNetConfig`.
3. F5 › **Private server**.
4. El kit arranca un proceso dedicado en tu PC (`MpLocalServer`), te une solo y muestra en el estado algo como `Private match on 192.168.1.5:7800 · friends join with 192.168.1.5:7800#K7P2QX`.
5. Tus amigos escriben `192.168.1.5:7800#K7P2QX` en el campo de dirección del menú y **Join**. Cada asiento tiene su código; si hay varios, aparecen separados por coma.
6. Alguien sin código no entra.

El formato `ip:puerto#CÓDIGO` lo entiende `MpFlow.join_address`: la parte después de `#` es el ticket. Por internet, tus amigos necesitan tu IP pública y el puerto abierto en tu router.

### 10.2 Por código

```gdscript
var server := MpLocalServer.start_on(get_tree(), 2)
server.server_ready.connect(func(address: String, port: int, codes: Dictionary) -> void:
	print("%s:%d  códigos: %s" % [address, port, codes]))
server.server_failed.connect(func(reason: String) -> void: print("falló: ", reason))
```

| Pieza | Qué es |
|---|---|
| `MpLocalServer.start_on(tree, seats, options, join_host)` | Crea el nodo bajo la raíz y arranca. El slot 1 sos vos |
| `server_ready(address, port, codes)` | Listo. `codes`: slot → código para cada otro asiento |
| `server_failed(reason)` | No pudo arrancar |
| `server_ended(result)` | Terminó la partida |
| `stop()` | Mata la partida |

Usa los mismos tiempos y puertos que un `MpLobbyConfig` por defecto (partidas en 7800-7899). Con WebSocket en escritorio, arrancá tu juego con `--transport=ws` para que la partida privada también lo use.

## 11. Web

### 11.1 Qué cambia

Un navegador no puede abrir un servidor ni usar UDP. Entonces:

- Un export web usa **siempre WebSocket**, diga lo que diga el `MpNetConfig`.
- No puede hostear ni buscar salas LAN: el menú oculta **Host LAN**, **Private server** y la lista LAN. Si algo llama `host_lan()`, el estado dice *This build cannot host (web): join a server*.
- Solo se une: a un dedicado WebSocket o a un servidor de salas WebSocket.

### 11.2 Por qué no se mezcla con escritorio

Un servidor WebSocket solo atiende clientes WebSocket, y uno ENet solo atiende ENet. Si querés web y escritorio en la misma partida, usá WebSocket para todos (`transport = ws` en el `MpNetConfig` y en el `MpLobbyConfig`).

### 11.3 Exportar

1. Copiá el preset *Web* de `addons/mp_kit/deploy/export_presets.example.cfg` a tu `export_presets.cfg` (o crealo en **Proyecto › Exportar**).
2. Es sin threads (`variant/thread_support=false`): cualquier hosting estático sirve, sin cabeceras especiales.
3. Exportá a `build/web/index.html` y subilo a tu hosting.
4. El servidor: un dedicado (o un servidor de salas) con `transport = ws`.

### 11.4 `wss://` y TLS

Una página servida por `https://` **no puede** abrir `ws://` (sin cifrar): necesita `wss://`. Dos caminos:

**Camino 1: TLS en Godot.**

En el servidor, alguna de estas:

| Dónde | Qué poner |
|---|---|
| `MpNetConfig` del dedicado | `tls_certificate` (`X509Certificate`) y `tls_key` (`CryptoKey`) |
| Flags del dedicado | `--tls-certificate-path=/ruta/fullchain.pem --tls-key-path=/ruta/privkey.pem` |
| `MpLobbyConfig` (salas) | `tls_certificate_path` y `tls_key_path`. El lobby escucha en `wss://` y cada partida recibe el mismo certificado |
| `deploy.sh` | `--transport ws --tls-cert … --tls-key …` (ver [12](#12-subir-a-un-vps)) |

En el cliente:

| Dónde | Qué poner |
|---|---|
| `MpNetConfig` del cliente | `tls_client` = on. `tls_trusted_ca` vacío para un certificado normal (Let's Encrypt). `tls_common_name` solo si el certificado es de otro nombre que la dirección |
| Flags | `--tls-client`, `--tls-trusted-ca=archivo.pem`, `--tls-common-name=nombre` |

La dirección tiene que ser el **dominio** del certificado (`juego.ejemplo.com:7700`), no una IP. La pantalla de lobby toma el TLS del `MpNetConfig` del flow.

**Camino 2: proxy inverso.** nginx o Caddy terminan TLS en el puerto 443 y reenvían al puerto WS local. El juego no cambia. En el campo de dirección del menú se puede escribir una URL completa: `wss://juego.ejemplo.com/ruta`. Detalle en [README.md](README.md) (sección *wss:// (TLS) para el VPS*).

### 11.5 Pestaña oculta

Un navegador pausa una pestaña oculta. El jugador web que cambia de pestaña se congela para los demás hasta que vuelve. En una partida de sala, si tarda más que `rejoin_grace_s`, cuenta como abandono.

## 12. Subir a un VPS

Un solo binario de Linux hace todo: cliente, servidor de salas (`--room-server`) y cada partida (`--dedicated`).

### 12.1 Lo que necesitás

- Un VPS Linux x86_64 con systemd (Ubuntu o Debian) y un usuario con `sudo` al que entrás por SSH.
- En tu PC, las plantillas de export de Linux de tu versión de Godot (**Editor › Administrar plantillas de exportación**).
- En el proyecto: el `MpFlow` con `room_server_path` (si usás salas) y un `MpNetConfig`.

### 12.2 Exportar

1. Copiá el preset *Linux Server* de `deploy/export_presets.example.cfg` a tu `export_presets.cfg`. Es un export de Linux normal (no el modo *Dedicated Server*: la partida necesita colisiones y el mundo entero).
2. Exportá:

```bash
godot --headless --path . --export-release "Linux Server" build/server/juego.x86_64
```

Salen `juego.x86_64` y `juego.pck`, que van juntos.

### 12.3 Subir e instalar con `deploy.sh`

```bash
addons/mp_kit/deploy/deploy.sh usuario@mi-vps build/server --rooms 7700 --open-firewall
```

Eso:

1. Crea el usuario de sistema `juego` (el nombre sale del binario).
2. Copia el build a `/opt/juego`.
3. Instala las unidades `juego-rooms@.service` y `juego-dedicated@.service`.
4. Arranca `juego-rooms@7700`: lobby en 7700, partidas en 7800-7899.
5. Con `--open-firewall`, abre los puertos con `ufw`.

Correlo otra vez para actualizar: copia lo nuevo y reinicia.

| Opción | Qué hace | Por defecto |
|---|---|---|
| `--name NOMBRE` | Nombre del servicio y del usuario (minúsculas, números, `-`, `_`) | el binario sin `.x86_64` |
| `--rooms 7700,7701` | Un servidor de salas por puerto. Cada uno con 100 puertos de partida: 7800-7899, 7900-7999… | `7700` |
| `--dedicated 7777,7778` | Dedicados sin lobby, uno por puerto (se entra con IP y puerto) | ninguno |
| `--transport enet\|ws` | Se pasa a todas las instancias | lo del build |
| `--tls-cert RUTA` / `--tls-key RUTA` | `wss://` con ese certificado y clave PEM. Van juntos y piden `--transport ws` | — |
| `--open-firewall` | Abre los puertos con `ufw` (UDP con ENet, TCP con WebSocket) | off |
| `--dry-run` | Solo imprime los comandos, no los corre | off |

Ojo: `--rooms` tiene valor por defecto. Si querés **solo** dedicados, pasá `--rooms ""`:

```bash
addons/mp_kit/deploy/deploy.sh usuario@mi-vps build/server --rooms "" --dedicated 7777 --open-firewall
```

Probalo siempre primero con `--dry-run`.

Web por https:

```bash
addons/mp_kit/deploy/deploy.sh usuario@mi-vps build/server --rooms 7700 --transport ws \
  --tls-cert /etc/letsencrypt/live/DOMINIO/fullchain.pem \
  --tls-key /etc/letsencrypt/live/DOMINIO/privkey.pem --open-firewall
```

El usuario del servicio tiene que poder leer el certificado y la clave (con Let's Encrypt, por ejemplo, un grupo con permiso sobre `/etc/letsencrypt/live` y `archive`).

### 12.4 Varias instancias

- Varias partidas a la vez en un servidor de salas: automático, hasta `max_matches`.
- Varios servidores de salas en el mismo VPS: `--rooms 7700,7701,7702`. Cada uno tiene su rango de puertos y su carpeta de partidas.
- Un número distinto para una sola instancia: editá `EXTRA_ARGS` en `/etc/juego/rooms-7700.env` (por ejemplo `--max-matches=8`) y reiniciala.

### 12.5 Operar

```bash
ssh usuario@mi-vps journalctl -u 'juego-rooms@*' -f        # logs en vivo
ssh usuario@mi-vps journalctl -u 'juego-dedicated@*' -f    # logs de dedicados sueltos
ssh usuario@mi-vps sudo systemctl restart juego-rooms@7700  # reiniciar uno
ssh usuario@mi-vps sudo systemctl disable --now juego-rooms@7701   # apagar uno
```

Si el servidor de salas se cae, systemd lo levanta. Sus partidas se cierran solas en pocos segundos.

En los clientes, poné la dirección del VPS en `MpLobbyScreen.lobby_address` (por ejemplo `juego.ejemplo.com:7700`). Para dedicados sueltos, los jugadores escriben `juego.ejemplo.com:7777` en el menú.

Más detalle: [deploy/README.md](deploy/README.md).

## 13. Seguridad y límites

### 13.1 Lo que el kit ya pone

| Qué | Límite |
|---|---|
| `to_server` / `mp_sv_*` | Solo el dueño del nodo (o cualquier jugador con slot, si `owner_slot` = 0). Solo métodos que empiezan con `mp_sv_` y con esa cantidad de argumentos. Argumentos de hasta 4 KB. Hasta 60 por segundo por cliente (ráfaga de 120), sumando todos sus `MpActor` |
| `to_all` / `mp_all_*` | Solo los manda el servidor |
| `MpInput` | Solo el dueño manda frames. Frames de hasta 1 KB, con tipos validados, fuerza de cada acción entre 0 y 1, hasta 16 valores propios. Un cliente que manda frames de más no se mueve más rápido |
| Túnel `Dictionary` | Mensajes de hasta 8192 bytes, 30 por segundo (ráfaga de 60) |
| Admisión por ticket (partidas de sala y privadas) | Solo entran los tickets del asiento. Tickets de hasta 512 caracteres. Sin ticket en 5 s, afuera. Hasta 64 conexiones esperando ticket a la vez |
| Lobby | Valida versión, nombre (24 caracteres), tamaño de opciones y picks (2048 bytes), ritmo del chat, y tiempo para saludar (`hello_timeout_s`). El cliente nunca elige slot, puerto ni semilla |
| Slots | Los asigna el servidor. El cliente nunca dice "soy el 2" |

### 13.2 Lo que tiene que validar tu juego

1. **Los argumentos de cada `mp_sv_*`.** Llegan del cliente: pueden ser de cualquier tipo. Chequeá tipo y rango.

```gdscript
func mp_sv_buy(item: Variant) -> void:
	if typeof(item) != TYPE_STRING or not SHOP.has(item):
		return
	# ...
```

2. **Los valores de `input.get_value`.** También los manda el cliente. Si un vector tiene que ser una dirección, normalizalo; si es un punto, limitalo.

```gdscript
var aim: Vector2 = input.get_value(&"aim", Vector2.RIGHT)
if typeof(aim) != TYPE_VECTOR2 or aim == Vector2.ZERO:
	aim = Vector2.RIGHT
aim = aim.normalized()
```

3. **Los picks y opciones de sala** en `MpRoomRules.accept_pick` y `accept_options`.
4. **Que el pedido tenga sentido en el juego**: que el jugador tenga plata, esté cerca de la puerta, no esté muerto. El kit sabe quién pidió (`sender_slot()`), no si el pedido es justo.
5. **Nodos sin dueño** (`owner_slot` = 0): cualquier jugador puede llamar sus `mp_sv_*`. No pongas ahí nada que solo deba hacer uno.

Nunca mandes tipos de bala o de personaje como texto por red: usá un `Resource` en el actor.

## 14. Problemas comunes

### Avisos del editor (triángulo amarillo en el nodo)

**"Save the scene: the MpSync child is built in the editor."** (en `MpActor` o `MpState`)
1. Abrí la escena del actor (no la del mundo).
2. Guardala (Ctrl+S).
3. Si sigue: el `MpActor` está agregado sobre una instancia en otra escena. Movelo a la escena del actor.

**"MpActor goes inside the node the network shares (not as a scene root)."**
El `MpActor` es la raíz de la escena. Tiene que ser hijo del nodo que se comparte (el `CharacterBody2D`, la bala).

**"Predict is on: the parent needs func mp_move(input: MpInput, delta: float)."**
Agregá `func mp_move(keys: MpInput, delta: float) -> void:` al script del padre, o apagá `predict`.

**"Put an MpActor next to this MpInput (same parent)."**
El `MpInput` tiene que ser hermano de un `MpActor`, o tener `actor` asignado.

### Errores al jugar (panel Depurador)

**"MpActor on 'X': no MpSync child. Open the scene in the editor and save it (the editor builds it)."**
Igual que el primer aviso: abrí y guardá la escena del actor.

**"MpActor on 'X': predict needs an MpInput next to it and mp_move(input, delta) on the parent"**
Falta el `MpInput` o `mp_move`. El kit apaga `predict` para ese nodo y sigue.

**"MpInput 'X': no MpActor next to it"**
Ver arriba.

**"MpActor 'X': to_server(y) from a peer that does not own it"**
Un cliente llamó `to_server` en el jugador de otro. Poné la llamada detrás de `if net.is_local():`.

**"MpActor 'X': no mp_sv_y() taking N arguments"** (o `mp_all_y`)
El nombre o la cantidad de argumentos no coincide. `to_server(&"buy", item)` necesita `func mp_sv_buy(item)`. Sin prefijo en la llamada: `&"buy"`, no `&"mp_sv_buy"`.

**"… only runs on the server"** (`to_all`, `despawn`, `MpState.set_value`, `MpMatch.finish`, `spawn_actor`)
Lo llamaste en un cliente. Ponelo detrás de `if net.is_authority():` (o `MpKit.is_authority()`).

**"MpSpawner 'X': add res://… to Extra Scenes"**
Agregá esa escena a **Extra Scenes** del spawner, en el editor.

**"MpSpawner 'X': set spawn_path to the parent of replicated actors"** / **"spawn_path does not resolve"**
Poné `spawn_path` en el nodo vacío donde aparecen las cosas (`../Actors`, `../Projectiles`).

**"MpSlotSpawner 'X': assign pawn_scene"**
Asigná la escena del jugador.

**"MpSpawner 'X': … was added after its node was set up. Put synchronizers in the scene (or add them before add_child): the spawn packet and late joiners miss it."**
Un `MultiplayerSynchronizer` se agregó por código tarde (con un timer, diferido). Ponelo en la escena, o en el `_ready` del propio actor.

**"MpKit.host_dedicated failed: …"** / estado **"Could not host (port busy?)"**
El puerto está ocupado: otro servidor abierto, u otra instancia. Cerrala o usá `--mp-port=N`.

**"MpRoomServer: lobby port 7700: …"**
El puerto del lobby está ocupado. Cerrá el otro servidor de salas o usá `--lobby-port=N`.

**"--transport=x: unknown, ENet is used"**
Valores válidos: `enet` o `ws` (también se aceptan `udp`, `websocket`, `wss`).

**"MpTransport: cannot load TLS certificate … / key …"**
La ruta está mal o el usuario del servicio no puede leer el archivo.

**"MpLobbyScreen: no MpFlow in the tree to join the match"**
Abriste la escena de lobby directo. Arrancá por el boot (F5), que tiene el `MpFlow`.

**"MpMatchAgent: unusable ticket …"**
El proceso de partida no pudo leer su ticket. Pasa si lo arrancaste a mano con `--match-ticket-file` de una partida vieja. Las partidas las arranca el servidor de salas.

**"MpKit: setup failed (…)"** / el botón **Create** desactivado
Algún archivo ya existe (`[~]`) o la carpeta no empieza con `res://`. Elegí otra carpeta.

### Comportamientos

**Mi jugador no se mueve en el cliente.**
1. ¿Las acciones que usás están en `MpInput.actions`? Si no, el servidor lee 0.
2. ¿Leés `input` (o `keys` en `mp_move`) y no `Input`? `Input` en el servidor lee el teclado del servidor.
3. ¿Con `predict` y sin `mp_move`? Mirá el error del depurador: el kit apagó la predicción.
4. ¿Sin `predict`, movés detrás de `is_authority()`? Si movés detrás de `is_local()`, el cliente se mueve en su pantalla pero el servidor lo devuelve a su lugar.
5. ¿`sync_position` está tildado? ¿Guardaste la escena del jugador después de tildarlo?
6. ¿El `MpSlotSpawner` tiene `spawn_path` y `pawn_scene`?

**Se mueve, pero los otros jugadores tironean.**
Usá `smoothing = BUFFERED` y subí `buffer_delay_s` (0.15, 0.2). Si bajaste `send_hz`, subilo o dejalo en 0.

**Mi jugador responde tarde.**
Prendé **Prediction › predict** y pasá el movimiento a `mp_move`.

**El que entra tarde no ve X.**
- Si X lo hiciste con `to_all`: es un efecto de una vez, no queda. Usá una propiedad en **Sync › Extra** o `MpState`.
- Si X es una propiedad: agregala a **Sync** del `MpActor` y guardá la escena.
- Si cambiaste `state.values` a mano: usá `set_value`.
- Si el sincronizador lo agregás por código tarde: ver el error del spawner de arriba.

**No encuentro la sala LAN.**
1. La lista muestra solo partidas **Host LAN** (no dedicados ni privadas).
2. `lan_discovery` del `MpNetConfig` y `advertise_lan` del `Flow` tienen que estar en on en el host.
3. El anuncio va por UDP broadcast al puerto 7778: el firewall de las dos PCs lo tiene que dejar pasar, y tienen que estar en la misma red (no funciona por internet ni entre subredes).
4. En la misma PC con varias instancias, la lista puede no aparecer en todas: escribí `127.0.0.1`.
5. En web no hay lista LAN.
6. Siempre podés escribir la IP que el host ve abajo de su lista.

**"Invalid IPv4" en el estado.**
Lo muestra para cualquier dirección mal escrita, también un puerto inválido o un nombre con caracteres raros. Formatos válidos: `192.168.1.5`, `juego.ejemplo.com`, cualquiera con `:puerto`, `ip:puerto#CÓDIGO` o una URL `wss://…`.

**"Could not join" / se queda en "Connecting to …".**
- ¿El servidor está corriendo y en ese puerto?
- ¿Mismo transporte en los dos? Un cliente ENet no habla con un servidor WebSocket.
- ¿El firewall o el router dejan pasar el puerto (UDP con ENet, TCP con WebSocket)?
- ¿Está lleno? Pasado `max_players`, el servidor corta la conexión.

**El web no conecta por https.**
1. La página es `https`: necesita `wss://`. Prendé `tls_client` en el `MpNetConfig` del cliente.
2. El servidor tiene que tener certificado y clave (ver [11.4](#114-wss-y-tls)), o un proxy inverso.
3. Usá el dominio del certificado, no la IP.
4. El servidor tiene que ser WebSocket (`transport = ws`), también el de salas.
5. Para el lobby, `lobby_address` es `dominio:puerto` (no una URL `wss://`); el `wss` lo pone `tls_client`.

**"Lost the server".**
El servidor se cerró o se cortó la red. El flow vuelve al boot (o al lobby si la partida vino de una sala).

**Rechazado al entrar a una partida de sala (`rejected`, `slot_taken`, `timeout`, `dropped`).**
- `rejected`: el ticket no vale (vencido, de otra sala, o ya pasó la gracia).
- `slot_taken`: ese asiento lo tiene otro peer conectado. También pasa si la sala tiene más asientos que el `max_players` del `MpNetConfig` de la partida: subí `max_players`.
- `timeout`: no presentó ticket a tiempo.
Se escuchan con `MpKit.admission_rejected`.

**El lobby dice `Error: bad_meta`.**
Tu `accept_pick` rechazó el pick. Revisá `default_pick` de la pantalla de lobby o llamá `set_pick` con algo válido.

**La partida de sala no arranca.**
Todos los asientos tienen que estar ocupados y en **Ready**. Mirá el log del servidor de salas: si dice `match … failed …`, el proceso de partida no arrancó (puerto, `max_matches`, el ejecutable).

**Dos flows: cambio el inspector del `Flow` y no pasa nada.**
Si además tenés un `MpFlow` como autoload (por ejemplo, de *New session flow...*), ese gana: el del boot se borra solo, sin aviso. Usá uno solo: o el autoload, o el nodo en el boot. Lo mismo si el boot se vuelve a cargar: el flow que ya estaba se queda y el nuevo se va.

**El nombre de la sala LAN no es el que puse en el `Flow`.**
El `room_name` del `Menu` le gana al del `Flow`. Ponelo en el `Menu`.

**`start_when` no parece hacer nada.**
Con `--dedicated`, el flow carga el mundo enseguida, sin esperar clientes. `start_when` importa al hostear LAN y en procesos dedicados por *feature tag* (`dedicated_server`) sin el flag.

**El jugador web se congela para los demás.**
Cambió de pestaña: el navegador la pausó. Ver [11.5](#115-pestaña-oculta).

## 15. Glosario

| Término | Qué es |
|---|---|
| `MpKit` | El autoload: red, slots, mensajes de sesión |
| `MpFlow` | El nodo que maneja escenas y modos (solo, LAN, unirse, dedicado) |
| `MpNetConfig` | Recurso `.tres` con la red del juego: transporte, puerto, jugadores, TLS |
| `MpBootMenu` | El menú listo para usar (`mp_boot_menu.tscn`) |
| `MpActor` | Hijo de todo lo que la red comparte: sync, dueño, llamadas, predicción |
| `MpSync` | El `MultiplayerSynchronizer` que arma el editor bajo un `MpActor` o `MpState` |
| `MpInput` | Las teclas del dueño, leídas en el servidor con la API de `Input` |
| `MpState` | Valores de partida que ven todos |
| `MpMatch` | Inicio y fin de partida, ausencias y abandonos |
| `MpSpawner` | Spawner que crea cosas en todos (`spawn_actor`, Extra Scenes) |
| `MpSlotSpawner` | Spawner de un jugador por slot |
| `MpRoomServer` | Escena del servidor de salas |
| `MpLobbyConfig` | Recurso `.tres` con puertos, límites y tiempos de salas y partidas |
| `MpRoomRules` | Tus reglas de sala (asientos, picks, opciones) |
| `MpLobbyScreen` | La pantalla de lobby del cliente |
| `MpLocalServer` | Dedicado en tu PC con códigos (partida privada) |
| Slot | Número de jugador (1, 2, 3…) |
| Peer id | Número de conexión de Godot. No es el jugador |
| `owner_slot` | Slot dueño de un nodo. 0 = el servidor |
| Proxy | Copia de un nodo que esta máquina solo dibuja |
| Listen server / host LAN | Un jugador que también es servidor |
| Dedicado | Servidor sin jugador |
| Ticket / token | Lo que presenta un jugador para entrar a una partida de sala o privada |
| Pick | Lo que eligió un jugador en su asiento (personaje, equipo) |
| Predicción | El dueño se mueve al instante |
| Reconciliación | El dueño vuelve al estado del servidor y repite lo que faltaba |
| `BUFFERED` / `FOLLOW` / `NONE` | Modos de suavizado de proxies |
| ENet | Transporte UDP (escritorio) |
| WebSocket / `ws` / `wss` | Transporte TCP (web); `wss` = cifrado con TLS |

## 16. Quiero X → uso Y

| Quiero… | Uso… |
|---|---|
| un juego que anda en minutos | **Proyecto › Herramientas › MpKit: Setup game...** |
| que algo se vea igual en todos | **MpActor › Sync** (posición, rotación, visible, Extra) |
| sincronizar una propiedad propia (`health`) | **MpActor › Sync › sync_extra** = `health` (o `Health:current`) |
| que el jugador responda sin lag | **MpActor › Prediction › predict** + `func mp_move(keys, delta)` |
| que los otros se vean parejos | **MpActor › Smoothing** = `BUFFERED`, ajustar `buffer_delay_s` |
| gastar menos ancho de banda | **MpActor › Sync › send_hz** (por ejemplo 20) |
| leer las teclas del jugador en el servidor | `input.get_vector`, `input.is_action_just_pressed`… |
| mandar el punto de mira | `input.set_value(&"aim", v)` en el dueño, `input.get_value(&"aim")` en el servidor |
| una orden del jugador | `net.to_server(&"x", args)` → `func mp_sv_x(args)` |
| saber quién pidió la orden | `net.sender_slot()` dentro de `mp_sv_*` |
| un efecto en todos | `net.to_all(&"x", args)` → `func mp_all_x(args)` (solo servidor) |
| un objeto que cualquiera puede usar | `MpActor` con `owner_slot` = 0 + `to_server` |
| aparecer balas o pickups | **MpSpawner** con la escena en **Extra Scenes** + `spawn_actor(escena, props, owner_slot)` |
| borrar algo en todos | `net.despawn()` (servidor) |
| teletransportar sin deslizar | `net.snap()` en los clientes |
| puntaje, reloj, ronda | `MpState.of(self).set_value` / `.add`, señal `changed` |
| terminar la partida | `MpMatch.finish({"winner": ...})`, señal `finished` en todos |
| saber si alguien volvió o abandonó | `MpMatch.player_back` / `player_abandoned` |
| volver al menú | `MpFlow.find_in_tree(self).return_to_boot()` |
| salir de la partida al lobby o al menú | `MpFlow.find_in_tree(self).leave_match()` |
| saber si soy servidor | `net.is_authority()` / `MpKit.is_authority()` |
| saber si este nodo es mío | `net.is_local()` |
| saber qué jugador soy | `MpKit.local_slot()` |
| jugar en LAN | **Host LAN** + **Join** a la IP |
| un servidor dedicado | `godot --headless --path . -- --dedicated` |
| salas online | `MpRoomServer` + `MpLobbyConfig` + `MpLobbyScreen` + `MpMatch` |
| reglas de sala | un script que extiende `MpRoomRules` |
| partida con código en mi PC | `MpBootMenu.offer_private_server` o `MpLocalServer.start_on` |
| juego web | `MpNetConfig.transport = ws`, servidor dedicado WS, export Web |
| web por https | `wss://`: `tls_client` en el cliente y certificado en el servidor |
| probar con lag | `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` |
| subir a un VPS | `deploy/deploy.sh usuario@vps build/server --rooms 7700 --open-firewall` |
| ver los logs del VPS | `journalctl -u 'juego-rooms@*' -f` |

## 17. Dónde seguir

- [QUICKSTART.md](QUICKSTART.md): la versión corta, en seis pasos.
- [README.md](README.md): referencia de cada pieza, transporte, túnel `Dictionary`, salas hub y bajo nivel.
- [deploy/README.md](deploy/README.md): despliegue en un VPS en detalle.
- [examples/arena_2d/](examples/arena_2d/): el ejemplo completo. Abrí `boot.tscn` y apretá F6.
