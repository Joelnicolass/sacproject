# MpKit: guía completa, paso a paso

Esta guía es para una persona que sabe Godot básico (escenas, nodos, inspector, scripts) y quiere armar un juego multijugador con MpKit, sin escribir código de red. Expande [QUICKSTART.md](QUICKSTART.md): si algo de acá parece contradecirlo, avisá, porque es un error.

Los nombres de código (`MpActor`, `to_server`, `owner_slot`...) quedan en inglés, como en el kit. Los menús del editor se nombran en español; si tu editor está en inglés, el equivalente está entre paréntesis la primera vez.

## Índice

1. [Qué es MpKit](#1-qué-es-mpkit)
2. [Conceptos en palabras simples](#2-conceptos-en-palabras-simples)
3. [Instalar](#3-instalar)
4. [Camino A: el asistente Setup game](#4-camino-a-el-asistente-setup-game)
5. [Camino B: a mano, escena por escena](#5-camino-b-a-mano-escena-por-escena) (un recurso, `MpFlow` y `MpWorld`)
6. [Programar el jugador](#6-programar-el-jugador)
7. [Cosas del mundo: objetos, apariciones, puntaje, inicio y fin](#7-cosas-del-mundo-objetos-apariciones-puntaje-inicio-y-fin)
8. [Probar](#8-probar)
9. [Online con salas](#9-online-con-salas)
10. [Partida privada con código](#10-partida-privada-con-código)
11. [Web](#11-web)
12. [Relay (túnel por Railway u otro host)](#12-relay-túnel-por-railway-u-otro-host)
13. [Subir a un VPS](#13-subir-a-un-vps)
14. [Seguridad y límites](#14-seguridad-y-límites)
15. [Problemas comunes](#15-problemas-comunes)
16. [Glosario](#16-glosario)
17. [Quiero X → uso Y](#17-quiero-x--uso-y)
18. [Dónde seguir](#18-dónde-seguir)

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

- **Tres transportes**, con la misma API:

| Transporte | Valor | Para qué |
|---|---|---|
| ENet | `enet` | UDP, escritorio, lo más rápido (por defecto) |
| WebSocket | `ws` | TCP, obligatorio para web |
| Relay | `relay` | WebSocket por un servidor intermedio (Railway u otro): el servidor Godot no necesita IP pública ni puertos abiertos. Ver [12](#12-relay-túnel-por-railway-u-otro-host) |

Qué **no** hace: no trae gameplay. Ni puntaje, ni personajes, ni textos de juego. Eso es tuyo. Tampoco conviene instalarlo en un juego que es solo de un jugador.

## 2. Conceptos en palabras simples

| Palabra | Qué significa |
|---|---|
| **Servidor** | El proceso donde corren las reglas. En LAN es la PC del host; en dedicado, un proceso sin jugador. En solo, tu PC hace de servidor. |
| **Cliente** | Un proceso que se unió a un servidor. Manda teclas y pedidos, dibuja lo que el servidor le manda. |
| **Autoridad** | Donde se decide. En MpKit siempre es el servidor (o solo). `net.is_authority()` es verdadero ahí. |
| **Slot** | El número de jugador: 1, 2, 3… Lo asigna el servidor. Es lo que usa tu juego ("P1", "P2"). |
| **Peer id** | El número interno de conexión de Godot (1 = servidor, después otros números). **No lo uses como jugador**: usá el slot. |
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
| **MpKit: New session flow...** | Crea un `MpFlow` como autoload en `res://glue/session_flow.tscn`. **No hace falta** si ponés el `MpFlow` en la escena de boot (lo recomendado acá). No uses los dos: ver [15](#15-problemas-comunes), "two flows". |
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
| **Max players** | Jugadores de la partida (1 a 64). Va a `max_players` de `game.tres` y a la cantidad de puntos de aparición. | 4 |
| **Transport** | `ENet (UDP, desktop)`, `WebSocket (TCP, web builds)` o `Relay (WebSocket tunnel: Railway…)`. Va a `transport` de `game.tres`. | ENet |
| **Relay URL** | Solo aparece con Relay: la dirección del relay (`wss://tu-relay.up.railway.app`). Va a `relay_url`. | vacío |
| **Online rooms** | Agrega servidor de salas y pantalla de lobby. | tildado |
| **Private server button** | Muestra el botón *Private server* en el menú (partida en tu PC con código). | tildado |
| **Make the boot scene the main scene** | Pone el boot como escena principal del proyecto (F5 la abre). | tildado |

### 4.3 El árbol de archivos

Abajo, bajo **Files:**, el diálogo muestra qué va a escribir. Con la carpeta `res://game`, salas online y escena principal:

```
[+] res://game/game.tres
[+] res://game/player.gd
[+] res://game/player.tscn
[+] res://game/world.tscn
[+] res://game/boot.tscn
[+] res://game/rooms_config.tres
[+] res://game/rooms.tscn
[+] res://game/lobby.tscn
[~] project.godot (main scene)
```

- `[+]` = archivo nuevo.
- `[~]` en un archivo de la carpeta = ya existe. Si aparece **uno solo**, el botón **Create** se desactiva y no se escribe nada. Nunca pisa un archivo tuyo. Elegí otra carpeta.
- `[~] project.godot (main scene)` aparece si dejás tildado *Make the boot scene the main scene*: avisa que se va a cambiar la escena principal. Esa línea no desactiva **Create**.
- Sin *Online rooms* no aparecen `rooms_config.tres`, `rooms.tscn` ni `lobby.tscn`.

Apretá **Create**. El editor escanea los archivos y abre `boot.tscn`.

### 4.4 Qué hay en cada archivo

**`game.tres`**: un `MpGame`, el juego en un solo recurso. Tiene la red (transporte y jugadores que elegiste, puerto 7777) y, en **Scenes**, las rutas de `boot.tscn`, `world.tscn` y, con salas, `lobby.tscn` y `rooms.tscn`. `relay_url` es lo que escribiste en *Relay URL*, y `relay_room` es el nombre del proyecto más una cola al azar (`mi-juego-3fa9c1`): dos juegos hechos con el asistente nunca comparten salas en el mismo relay.

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

**`world.tscn`**: tu nivel y un solo nodo de red, `MpWorld`, que armó sus piezas:

```
World (Node2D o Node3D)
├── Camera, Sun          (solo en 3D)
└── MpWorld              (player_scene = player.tscn, seats = Max players)
    ├── SpawnPoints      (P1..Pn en círculo, uno por jugador)
    ├── Actors           (vacío: ahí aparecen los jugadores)
    ├── Players          (MpSlotSpawner)
    ├── State            (MpState, con su MpSync)
    ├── Match            (MpMatch)
    └── Hud
        ├── Leave        (MpLeaveButton: sale de la partida)
        ├── Invite       (MpInviteLabel: en una partida privada, el código para los amigos)
        ├── Start        (MpStartButton: el host arranca con los jugadores que ya entraron)
        └── Waiting      (MpWaitingLabel: «Waiting for players (1/4)» mientras la partida espera)
```

**`boot.tscn`**:

```
Boot (Control, pantalla completa)
├── Flow  (MpFlow: game = game.tres, nada más)
└── Menu  (instancia de mp_boot_menu.tscn: offer_private_server)
```

El menú muestra *Online rooms* solo porque `game.tres` tiene `lobby_scene`.

**`rooms_config.tres`**: un `MpLobbyConfig` con `seats_per_room` = el menor entre *Max players* y 2. El resto, por defecto (lobby en 7700, partidas en 7800-7899).

**`rooms.tscn`**: un nodo `Rooms` con `MpRoomServer` y `config = rooms_config.tres`. El servidor de salas toma transporte, relay y TLS de `game.tres` (a través del flow que lo abrió con `--room-server`), y cada partida abre el boot del juego.

**`lobby.tscn`**: una instancia de `MpLobbyScreen`. Su botón Back vuelve al boot del juego. `lobby_address` queda vacío: el campo arranca con `public_host` de `game.tres` en el puerto 7700, o `127.0.0.1:7700` si no hay.

### 4.5 Probarlo enseguida

1. F5. Aparece el menú.
2. **Play solo**: flechas para mover, Enter para sumar un punto. **Leave** vuelve al menú.
3. LAN: ver [8.2](#82-lan-dos-ventanas-en-tu-pc).
4. Online: ver [9.6](#96-correr-el-servidor-de-salas).

Lo que el asistente **no** agrega, y conviene que agregues vos: un fin de partida (`MpMatch.finish`, ver [7.5](#75-inicio-y-fin-mpmatch)). Sin eso, una partida de sala no termina hasta que se van todos.

## 5. Camino B: a mano, escena por escena

Lo mismo que arma el asistente, con los clics del editor. Te sirve para entender qué hay, o para sumar MpKit a un juego que ya tenés. Son tres cosas: un recurso (`game.tres`), el boot con un `MpFlow`, y el mundo con un `MpWorld`. Más tu jugador.

### 5.1 El juego en un recurso (`MpGame`)

1. En el panel **Sistema de archivos**, clic derecho en tu carpeta › **Nuevo › Recurso...**
2. Buscá **MpGame** y creá `game.tres`. Un `MpGame` es un `MpNetConfig` (la red) con tus escenas.
3. En el inspector, la red:

| Propiedad | Qué poner | Por defecto |
|---|---|---|
| `transport` | `enet` (escritorio), `ws` (web) o `relay` (túnel, ver [12](#12-relay-túnel-por-railway-u-otro-host)) | `enet` |
| `port` | Puerto del servidor | 7777 |
| `max_players` | Jugadores por partida | 4 |
| `public_host` | Dónde encuentran los clientes al servidor (`juego.ejemplo.com`, `203.0.113.5:7777`). El campo Join del menú y la pantalla de lobby arrancan con esto | vacío (= `127.0.0.1`) |
| `custom_channels` | Canales permitidos del túnel `Dictionary` (vacío = todos) | vacío |
| `lan_discovery` | Anunciar la partida en la red local | on |
| Grupo **Relay** | `relay_url` y `relay_room`. Ver [12](#12-relay-túnel-por-railway-u-otro-host) | vacío / `mpkit` |
| Grupo **TLS (wss://)** | Ver [Web](#11-web) | vacío |

Y el grupo **Scenes**:

| Propiedad | Qué poner |
|---|---|
| `boot_scene` | La escena del menú (5.2), por ejemplo `res://game/boot.tscn`. Leave y un servidor caído vuelven acá |
| `world_scene` | La escena de la partida (5.3) |
| `lobby_scene` | Opcional: la pantalla de salas online (ver [9](#9-online-con-salas)). Con esto, el menú muestra *Online rooms* |
| `rooms_scene` | Opcional: la escena con `MpRoomServer`, que abre `--room-server` |

Los flags de línea de comando le ganan al `.tres`: `--transport=ws`, `--mp-port=N`, `--max-players=N`, `--relay-url=`, `--relay-room=`.

Un `MpNetConfig` solo (sin escenas) sigue andando en `Flow › net_config`, con las rutas puestas a mano en el flow. Es el armado de antes; el `MpGame` lo junta todo.

### 5.2 Escena de boot (el menú)

1. **Escena › Nueva escena**. Raíz: **Interfaz de usuario** (`Control`). Renombrala `Boot`.
2. Seleccioná `Boot`, **Agregar nodo hijo** (Ctrl+A), buscá **MpFlow** y agregalo. Renombralo `Flow`.
3. En el inspector del `Flow`, **Game** = tu `game.tres`. Es lo único obligatorio.

El resto de los campos del `Flow` es opcional. Uno puesto a mano le gana al `game.tres`:

| Propiedad | Qué hace |
|---|---|
| `room_name` | Nombre que se ve en la lista LAN |
| `net_config`, `boot_path`, `world_path`, `lobby_path`, `room_server_path` | Lo mismo que el `game.tres`, campo por campo. Vacíos = los del juego |
| `start_when` | Dejalo como está. Host LAN y `--dedicated` siempre cargan el mundo al arrancar; `DEDICATED_FIRST_CLIENT` y `MANUAL` solo cuentan en un export *Dedicated Server* arrancado sin `--dedicated` |

`max_players`, `custom_channels` y el puerto salen del `.tres`, no de los campos del `Flow`.

4. Seleccioná `Boot` otra vez y **Instanciar escena hija** (Ctrl+Shift+A). Elegí `res://addons/mp_kit/mp_boot_menu.tscn`. Renombralo `Menu`.
5. En el inspector del `Menu` (un `MpBootMenu`):

| Propiedad | Qué hace |
|---|---|
| `title_text` | Título del menú |
| `offer_private_server` | Botón *Private server* |
| `lobby_scene_path` | Otra escena de lobby para *Online rooms*. Vacío = la del juego (`lobby_scene`) |
| `play_solo_text`, `host_text`, `join_text`... | Los textos de los botones, para traducir |
| `world_scene`, `max_players`, `room_name`, `advertise_lan`, `drive_kit` | Solo para un menú **sin** `MpFlow`. Con flow, el flow manda y estos campos no hacen nada |

6. Guardá la escena como `boot.tscn`.
7. **Proyecto › Ajustes del proyecto › General › Aplicación › Ejecutar › Escena principal**: elegí `boot.tscn`.

Qué tiene el menú: **Play solo**, **Host LAN**, **Private server** (opcional), **Online rooms** (opcional), un campo de dirección con **Join** (arranca con `public_host` si está puesto), y la lista **LAN rooms**. En web se ocultan Host, Private y la lista LAN.

El campo de dirección acepta: `192.168.1.5`, `juego.ejemplo.com`, cualquiera con `:puerto`, `#CÓDIGO` al final (partida privada) o una URL `ws://…` / `wss://…`. Lo mismo acepta la pantalla de lobby y `MpFlow.join_address` (los tres usan `MpAddress.parse`).

Qué hace el `MpFlow`: arranca la red con la config, arma la puerta de arranque, cambia de escena (boot ↔ mundo), le manda el mundo a cada asiento admitido (también al que vuelve) y vuelve al boot si se cae el servidor. Se muda solo a la raíz del árbol y sobrevive a los cambios de escena. No hace falta autoload.

### 5.3 Escena del mundo

1. **Escena › Nueva escena**. Raíz: **Escena 2D** (`Node2D`) o **Escena 3D** (`Node3D`). Renombrala `World`. Tu nivel va acá, como siempre.
2. **Agregar nodo hijo**, buscá **MpWorld** y agregalo. Al soltarlo, arma sus piezas como hijos: `SpawnPoints` (un marcador por asiento), `Actors`, `Players` (un `MpSlotSpawner`), `State` (un `MpState`), `Match` (un `MpMatch`), `Hud/Leave` (un `MpLeaveButton`) y `Hud/Invite` (un `MpInviteLabel`). Detecta solo si el mundo es 2D o 3D.
3. En su inspector:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `player_scene` | Tu `player.tscn` (lo armás en 5.4; podés volver después). Es la escena que recibe cada asiento | vacío |
| `seats` | Cuántos marcadores arma en `SpawnPoints` (si hay más jugadores, vuelven a empezar) | 4 |
| `leave_button` | Arma `Hud/Leave` | on |
| `invite_label` | Arma `Hud/Invite`: en una partida privada de esta PC muestra el código para los amigos | on |
| `start_button` | Arma `Hud/Start`: en Host LAN, mientras la partida espera asientos, el host arranca con los que ya cargaron | on |
| `waiting_label` | Arma `Hud/Waiting`: mientras la partida espera sus asientos, lo dice en todos los peers | on |

4. Mové los marcadores de `MpWorld/SpawnPoints` adonde querés que nazca cada jugador.
5. **Guardá la escena** (Ctrl+S).

Si borrás una pieza, el `MpWorld` la vuelve a armar la próxima vez que abrís la escena. No les cambies el nombre: el `MpWorld` las busca así. Desde un script, `Mp.state()`, `Mp.current_match()` y `Mp.player(slot)` las encuentran.

#### Sin MpWorld: cada pieza a mano

El `MpWorld` solo arma nodos que también podés poner vos. Sirve si tu mundo ya tiene su propia estructura (el ejemplo `examples/arena_2d/arena.tscn` está armado así):

1. Agregá un hijo `Node2D` (o `Node3D`) llamado `SpawnPoints`.
2. Adentro, un `Marker2D` (o `Marker3D`) por jugador: `P1`, `P2`, `P3`, `P4`. Movelos donde querés que aparezca cada uno. El slot 1 usa el primero, el 2 el segundo; si hay más jugadores que marcas, vuelven a empezar.
3. Agregá un hijo `Node2D` (o `Node3D`) vacío llamado `Actors`. Ahí aparecen los jugadores.
4. Agregá un hijo **MpSlotSpawner** (buscalo por nombre; es un `MultiplayerSpawner`). Renombralo `Players`.
5. En su inspector:

| Propiedad | Valor |
|---|---|
| `spawn_path` | `../Actors` |
| `pawn_scene` | Tu `player.tscn` (lo armás en 5.4; podés volver después) |
| `spawn_points` | `../SpawnPoints` |
| `despawn_on_leave` | on: borra el jugador cuando se va |
| `hold_until_world_ready` | on (dejalo así) |
| `gate_unsynced_spawns` | on (dejalo así) |
| `room_id` | vacío |

6. Opcional, para el puntaje: agregá un hijo **MpState** llamado `Score`.
7. Opcional, para inicio y fin: agregá un hijo **MpMatch** llamado `Match`.
8. Para salir: agregá un `CanvasLayer` llamado `Hud` y, adentro, un **MpLeaveButton** llamado `Leave` (ver [7.6](#76-salir-de-la-partida)), un **MpInviteLabel** para las partidas privadas un **MpStartButton** para que el host LAN pueda arrancar sin esperar todos los asientos y un **MpWaitingLabel** que dice que la partida espera.
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
| `sync_extra` | Más propiedades: del padre (`health`, `color_index`, `velocity`) o de un nodo de adentro (`Health:current`) | vacío |
| `send_hz` | Estados por segundo que manda el servidor. 0 = cada frame de física. Menos = menos ancho de banda | 0 |

Las transformaciones (y `velocity`) viajan siempre, en el mismo paquete que la pose; lo demás, solo cuando cambia. Todo viaja al nacer, así que el que entra tarde ve los valores actuales.

**Grupo Smoothing** (cómo se dibujan los proxies):

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `smoothing` | `BUFFERED`: dibuja un poco en el pasado, entre dos estados reales; parejo aunque los paquetes lleguen desparejos. `FOLLOW`: persigue el último estado, sin demora pero con tirones chicos. `NONE`: dibuja cada estado tal cual llega | `BUFFERED` |
| `buffer_delay_s` | Con `BUFFERED`: lo más en el pasado que puede dibujar (el tope). Más = tapa redes peores | 0.1 |
| `adaptive_buffer` | Con `BUFFERED`: mide cada cuánto llegan los estados y con cuánto atraso, y dibuja solo lo necesario, hasta `buffer_delay_s`. En una red buena son pocos ticks; en una mala, más. Apagado = siempre `buffer_delay_s` | on |
| `late_tolerance` | Con `adaptive_buffer`: qué parte de los estados puede llegar tarde (3% = percentil 97, como Photon Fusion). Menos = más parejo en una red mala, un poco más atrasado | 0.03 |
| `follow_speed` | Con `FOLLOW`: qué tan rápido persigue | 14.0 |
| `freeze_rigid_if_proxy` | Si el padre es un `RigidBody`, lo congela en los clientes (la física corre en el servidor) | on |

**Grupo Prediction**:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `predict` | El dueño se mueve al instante. Necesita un `MpInput` al lado y `func mp_move(input, delta)` en el padre | off |
| `max_resim_ticks` | Lo más que repite una corrección. Con mucho ping hay más ticks sin confirmar; pasado el tope corrige menos seguido, para no gastar CPU | 32 |

**Grupo Owner**:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `owner_slot` | Slot dueño. 0 = el servidor. **No lo toques en un jugador**: lo pone el spawner | 0 |
| `callers` | Quién puede pedir los `mp_sv_*` de este nodo. `OWNER`: el jugador de `owner_slot` (con `owner_slot` = 0, solo el propio servidor). `ANYONE`: cualquier jugador sentado (puertas, campanas, una tienda); validá lo que piden dentro de `mp_sv_*` | `OWNER` |

**Grupo Lag compensation**:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `lag_compensate` | El servidor guarda el último segundo de poses de este nodo, para que un disparo se valide contra donde lo vio el tirador (ver 6.8) | on |

Con `smoothing` distinto de `NONE` o con `predict`, la posición no viaja en `position` sino en `MpActor:net_position` (y `net_rotation`, `net_stamp`). Si mirás el panel Replicación del `MpSync`, vas a ver eso: es normal. En el cliente, solo `MpActor` mueve el nodo.

#### MpInput

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `actor` | El `MpActor` al que pertenece. Vacío = el que está al lado | vacío |
| `actions` | Acciones del **Mapa de entrada** que manda el jugador. **Solo esas** se pueden leer en el servidor | `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_accept` |

Si usás acciones propias (`jump`, `shoot`), crealas en **Ajustes del proyecto › Mapa de entrada** y agregalas a `actions`. El ejemplo agrega `ui_select` (Espacio) para disparar.

### 5.5 Conectar todo

1. En `world.tscn`, en el `MpWorld`, asigná `player_scene` = `player.tscn`.
2. En `game.tres`, revisá `boot_scene` y `world_scene`.
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
6. **Inercia o gravedad**: si `mp_move` usa la velocidad del tick anterior (acelerar, caer), agregá `velocity` a **MpActor › Sync › sync_extra**. Lo mismo con cualquier otro estado que `mp_move` lea (un contador de dash, "en el piso"). Viaja en el mismo paquete que la pose, y la reconciliación parte de ese valor. `net.last_correction()` te dice cuánto se corrigió.

```gdscript
# Con gravedad: velocity en Sync › Extra.
func mp_move(keys: MpInput, delta: float) -> void:
	velocity.x = keys.get_axis(&"ui_left", &"ui_right") * SPEED
	velocity.y += GRAVITY * delta
	if is_on_floor() and keys.is_action_just_pressed(&"jump"):
		velocity.y = -JUMP
	move_and_slide()
```

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
| `MpKit.is_server()` | Este proceso es servidor con red (falso en solo) | Lo que solo existe en red: snapshots, el matchmaker, el túnel. Para las reglas, `is_authority()` |
| `MpKit.is_listening()` | Servidor alcanzable por los clientes (con relay, recién cuando el relay lo aceptó) | Avisar "listo" |
| `MpKit.is_dedicated()` | Servidor sin jugador | No reproducir sonidos, no esperar teclas |
| `MpKit.local_slot()` | El slot de esta máquina (0 en un dedicado o antes de que el servidor asigne) | "Sos P2" |

Dentro de cualquier nodo, `is_multiplayer_authority()` (el de Godot) dice lo mismo que `net.is_authority()`: el kit deja la autoridad de cada nodo en el servidor, así que es verdadero en solo, en el host LAN y en el dedicado, y falso en un cliente. `MpKit.is_authority()` (o `Mp.is_server()`) es la misma pregunta desde un script que no está en el mundo.

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

Para lo que no es una tecla: el punto de mira, el cursor. El dueño lo pone; el servidor lo lee. Lo que llega lo mandó el cliente: validalo siempre, como el ejemplo.

```gdscript
func _process(_delta: float) -> void:
	if not net.is_local():
		return
	input.set_value(&"aim", (get_global_mouse_position() - global_position).normalized())

# en el servidor, al disparar (examples/arena_2d/player.gd):
var aim: Variant = input.get_value(&"aim", Vector2.RIGHT)
var direction: Vector2 = (aim as Vector2).normalized() if aim is Vector2 and (aim as Vector2).length() > 0.01 else Vector2.RIGHT
```

`set_value` fuera del dueño no hace nada. Hasta 16 valores por frame. Más en [14](#14-seguridad-y-límites).

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
- Quién puede pedirlo lo decide **MpActor › Owner › callers**: con `OWNER` (por defecto), solo el dueño; con `ANYONE`, cualquier jugador sentado.
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

**¿Un efecto o un estado?** Un efecto es un momento: un destello, un sonido, una sacudida. Va por `to_all` (o por un `@rpc` tuyo), y el que no estaba se lo pierde, y está bien. Un estado es lo que queda: una marca en el piso, una puerta abierta, un puntaje. Va en **Sync**, en `MpState` (una lista de marcas en una clave) o como un nodo que crea un spawner: el que entra o vuelve lo recibe al cargar, sin que nadie lo mande de nuevo. Si mandás efectos con un `@rpc` tuyo, mandalos a `MpKit.ready_peers()` (los peers con el mundo cargado) con `rpc_id`, y reproducilo también en el servidor si se ve ahí: un peer que todavía carga lo jugaría sin mundo. `MpKit.broadcast_custom(channel, data, true)` hace lo mismo para el túnel.

### 6.8 Más del `MpActor`

| Llamada | Qué hace |
|---|---|
| `net.despawn()` | Solo servidor, y solo en nodos que hizo un spawner: lo borra en todos (ver [7.3](#73-borrar-cosas)) |
| `net.snap()` | Después de teletransportar: en el cliente salta a la pose del servidor en vez de deslizarse |
| `net.last_correction()` | Con predicción, en el dueño: cuánto lo corrigió el servidor en el último estado (0 = la predicción acertó) |
| `net.owner_slot` | El slot dueño (para mostrar "P1", elegir color...) |
| `MpActor.of(nodo)` | El `MpActor` hijo de un nodo, o `null` |
| `net.view_lag()` | En el servidor: cuánto atrás ve el dueño de este nodo a los demás, en segundos (su ping más lo que dibuja en el pasado) |
| `net.rewound(func)` | En el servidor: corre `func` con los demás nodos movidos adonde los vio el dueño, y los devuelve. Para un disparo instantáneo: `net.rewound(func(): return espacio.intersect_ray(consulta))` |
| `net.seen_position_of(nodo)` | En el servidor: dónde estaba `nodo` cuando lo vio el dueño de este (Vector2 en 2D) |

**Compensación de lag** (como hace Valve): un jugador con ping ve a los demás un poco en el pasado. Si el servidor validara el disparo contra el presente, erraría contra lo que estaba en su pantalla. El kit guarda un segundo de poses y sabe qué momento veía cada jugador, porque viaja con cada frame de input y con cada `to_server`. Validá con `net.rewound`, `net.seen_position_of` o, para un proyectil, guardá `net.view_lag()` al dispararlo y compará con `MpLagComp.position_at_like(blanco, ahora - view_lag)`, como hace `shot.gd` del ejemplo. Nunca rebobina más de un segundo. `--lag-comp=off` en el servidor la apaga, para comparar.

Ejemplo de `snap` después de un respawn:

```gdscript
func respawn(at: Vector2) -> void:   # en el servidor
	position = at
	net.to_all(&"respawned")

func mp_all_respawned() -> void:
	net.snap()
```

### 6.9 La partida desde cualquier script: `Mp`

El `MpActor` es de cada actor. Para lo que es de la partida, la clase **Mp** tiene los verbos, sin buscar nodos:

| Verbo | Qué hace |
|---|---|
| `Mp.play_solo()` | Juega solo, sin red |
| `Mp.host()` | Hostea en esta PC (LAN, o por el relay si el juego lo dice) y juega |
| `Mp.join(direccion)` | Se une: `"192.168.1.5"`, `"juego.ejemplo.com:7777"`, `"ip:puerto#CÓDIGO"` o `"wss://…"` |
| `Mp.leave()` | Sale de la partida: al lobby si era de sala, al boot si no. Lo mismo que el botón Leave |
| `Mp.open_rooms()` | Abre el lobby (`lobby_scene` del juego). `false` si no hay |
| `Mp.is_server()` | ¿Corren acá las reglas? El servidor, o tu PC en solo |
| `Mp.is_online()` | ¿Hay red? Host, dedicado o cliente |
| `Mp.me()` | Tu asiento: 1, 2, 3… (0 en un dedicado) |
| `Mp.player(slot)` | El jugador de ese asiento en esta máquina |
| `Mp.state()` | El `MpState` del mundo: `Mp.state().add(&"score")` en el servidor, `get_value` en todos |
| `Mp.current_match()` | El `MpMatch` del mundo (señales y asientos) |
| `Mp.finish(resultado)` | En el servidor: termina la partida para todos |
| `Mp.net_quality()` | La conexión: `rtt_ms`, `jitter_ms`, `loss` (0 a 1), `grade_name` (`good`, `fair`, `bad`). En el servidor, `Mp.net_quality(slot)` da la de ese jugador |

Un menú propio en vez de `mp_boot_menu.tscn` son tres botones: `Mp.play_solo()`, `Mp.host()` y `Mp.join(campo.text)`.

## 7. Cosas del mundo: objetos, apariciones, puntaje, inicio y fin

### 7.1 Un objeto que usa cualquiera (la campana del ejemplo)

Una puerta, una palanca, una campana: está en el mundo desde el principio y no es de ningún jugador.

1. Hacé su escena (`bell.tscn`) con un `MpActor` hijo.
2. En el `MpActor`: `sync_position` off y `sync_rotation` off (no se mueve), `smoothing` = `NONE`, `sync_extra` = `rings`.
3. En **Owner**: `callers` = **ANYONE**. Sin esto, con `owner_slot` = 0 solo el servidor podría tocarla.
4. Guardá la escena.
5. Instanciala en el mundo (a mano, no por spawner).

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


func mp_sv_ring() -> void:    # corre en el servidor (callers = ANYONE)
	rings += 1
	MpState.of(self).set_value(&"bell_by", net.sender_slot())
```

`sender_slot()` dice quién fue. El valor `rings` está en Sync: lo ven todos, también el que entra tarde. Con `ANYONE`, chequeá en `mp_sv_*` que el pedido tenga sentido (que el jugador esté cerca, que la puerta no esté trabada).

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
	shots.spawn_actor(SHOT, {"position": position, "direction": direction}, net.owner_slot)
```

`spawn_actor(escena, props, owner_slot)`:

- Solo corre en el servidor (o en solo).
- `props` se aplican **antes** de que el nodo entre al árbol (su `_ready` ya los ve).
- `props` se ponen solo en el servidor. Lo que los clientes tengan que ver, tiene que estar en Sync (la posición lo está; `direction` no hace falta porque el servidor mueve la bala).
- `owner_slot` > 0 hace dueño a ese jugador.

Qué replica un spawner:

- Un nodo de una escena de su lista (**Extra Scenes**), o uno hecho por `spawn(data)` con tu `spawn_function`.
- Un nodo que un script agrega a mano en `spawn_path` (`add_child` de algo que no está en la lista) **no** se replica: queda solo en el servidor. Sirve para un efecto solo del servidor.
- Si usás `spawn_function`, asignala en un `_ready` de la escena (el del spawner, un hermano o el padre): el spawner la toma al final de ese frame, antes de que nada spawnee. Si la asignás más tarde, sale un warning y el primer nodo cuenta como agregado a mano.

`spawner.spawn_here(data)` es un `spawn(data)` que podés llamar desde cualquier peer: en el servidor (o en solo) spawnea con tu `spawn_function`; en un cliente no hace nada y devuelve `null`. Sin `if servidor` alrededor.

El spawner de jugadores (`MpSlotSpawner`, el `Players` del `MpWorld`) le da un jugador a cada asiento con el mundo listo: a los que lo avisan después, y a los que ya estaban listos cuando entra el spawner (un mundo cargado otra vez, un spawner en una escena que carga después).

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

`despawn()` solo vale para nodos que no venían guardados en la escena del mundo: los que hizo un spawner. Que un script le ponga `owner` después no cambia eso. En un nodo guardado en la escena del mundo (la campana, una puerta) da el error *"despawn() on a node of the world scene; hide it (sync visible) or spawn it"*: el que entra tarde carga la escena y lo vería igual. Para eso, ocultalo (tildá `sync_visible` y poné `visible = false` en el servidor) o hacelo aparecer con un spawner.

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
| `state.watch(&"clave", callback, default)` | En todos los peers: `callback(valor)` ya con el valor actual y después en cada cambio de esa clave. El que entra o vuelve recibe primero el valor actual, sin importar en qué orden arranca todo. `unwatch(handle)` lo corta |

Un HUD que lo muestra (del ejemplo, `hud.gd`):

```gdscript
@export var state: MpState

func _ready() -> void:
	state.changed.connect(_refresh.unbind(2))
	_refresh()
```

O para una sola clave, `state.watch(&"round", _show_round, 1)`: muestra la ronda actual al instante y cada ronda nueva.

No escribas `state.values["x"] = 3` a mano: no se sincroniza. Usá `set_value`.

### Quién mira esta pantalla: `MpLocalSeat`

El HUD, los sonidos, las órdenes, la pausa y el resultado muestran el lado de un jugador. Poné un **MpLocalSeat** en el mundo y pasáselo con `@export var seat: MpLocalSeat` (lo que nace en runtime lo encuentra con `MpLocalSeat.of(self)`):

| | Qué dice |
|---|---|
| `seat.slot` | El asiento que juega esta PC (0 en un dedicado, o en un cliente todavía sin asiento) |
| `seat.is_mine(slot)` | Si ese asiento es el de esta pantalla |
| `seat.is_online()` | Si hay red |
| señal `changed(slot)` | Cambió el asiento de esta pantalla (el servidor dio uno) |
| `preview_slot` (inspector) | Solo en solo: mirar la partida como ese asiento, p.ej. el HUD del jugador 2, sin una segunda ventana |

Quién simula es otra pregunta: `is_multiplayer_authority()` / `is_authority()` (6.3).

### 7.5 Inicio y fin: `MpMatch`

Un `MpMatch` en el mundo dice cuándo empieza la partida, quién se fue y quién volvió, y la termina para todos. Lo que cuenta lo decide la **puerta de arranque** (`MpMatchGate`, en `/root/MpKit/Gate`, `Mp.gate()`), que el `MpFlow` arma en cada camino que hostea (Host LAN, dedicado a mano, dedicado de sala):

- **Antes del arranque** los asientos libres están abiertos. El mundo queda **pausado en todos los peers** hasta que cargan los asientos que espera: todos por defecto (`start_seats` = 0, igual en Host LAN y en un dedicado a mano; en una partida de sala, todos los del ticket). `--start-seats=N` cambia ese número sin tocar la escena. Pasado `load_timeout_s` (15 s) desde el primero que entró, arranca con los que cargaron; mientras tanto el HUD dice que espera (`MpWaitingLabel`, `Hud/Waiting`: «Waiting for players (1/4)»). En Host LAN el host no tiene que esperar: el botón **Start now** del HUD (`MpStartButton`, en `Hud/Start` del `MpWorld`) arranca con los que ya cargaron.
- **Después del arranque** solo vuelve un asiento que se fue, dentro de `rejoin_grace_s`, al mismo slot (*rejoin*), salvo que esté prendido **`late_join`** (inspector del `MpFlow` o `--late-join`; apagado por defecto): entonces un recién llegado todavía toma un asiento libre, y un asiento abandonado pasada la gracia queda libre otra vez. Una partida de sala nunca tiene late join (el ticket nombra cada asiento). En LAN el cliente vuelve solo con la credencial que el servidor le dio al sentarlo (en memoria, por `host:puerto`); en una sala, con su ticket. Si el servidor todavía no notó que el cliente se cayó, gana la credencial (o el ticket): se suelta la conexión vieja y el asiento vuelve como rejoin. Cualquier otro peer se rechaza con un motivo: `match_started`, `full`, `grace_over`, `slot_taken`. El cliente recibe `admission_rejected(motivo)` y el flow lo muestra con `rejection_text(motivo)` (pisalo para traducir).
- Un asiento que no vuelve a tiempo, o que nunca cargó, **abandona** (`player_abandoned`). Si se fueron todos en un dedicado, nadie abandona: la puerta espera y, cuando pasó la gracia de todos, emite `all_gone`. En un listen host el host sigue jugando: cada asiento que pasa la gracia abandona y no hay `all_gone`.
- **Un dedicado a mano sirve una partida tras otra** (una VPS arrancada con `--dedicated`): cuando su partida termina (`Mp.finish()`) y se va el último jugador, o todos quedaron afuera pasada la gracia (`all_gone`), carga un mundo nuevo (puntos y actores desde cero) y abre otra vez todos los asientos. Un juego con pantalla de revancha puede llamar él mismo a `MpFlow.next_open_match()` cuando se fueron sus jugadores. **Si tu juego termina la partida a su manera** (no con `Mp.finish()`), avisale al kit en el servidor con `MpKit.broadcast_session_ended(result)`, o llamá a `MpFlow.next_open_match()` cuando terminó y quedó vacío; si no, la partida siguiente recién se abre cuando pasó la gracia de todos, y el que llega antes se rechaza (`match_started`). Los clientes reciben el estado de la puerta al ser admitidos y se pausan apenas cargan su mundo, así que su `MatchClock` arranca en 0.

Los knobs están en el inspector del `MpFlow`, grupo **Match start** (`rejoin_grace_s`, `load_timeout_s`, `start_seats`, `late_join`, `pause_clients`, `match_started_status`). En una partida de sala, la gracia y el tiempo de carga salen del `MpLobbyConfig`. En el Remote del editor, `/root/MpKit/Gate` muestra `phase`, `expected`, `loaded` y `away`. En Host LAN el host puede arrancar con los que ya cargaron: `MpStartButton`, o `Mp.gate().can_start_now()` / `Mp.gate().start_now()` desde un botón propio.

Señales:

| Señal | Dónde | Cuándo |
|---|---|---|
| `all_loaded` | servidor | La partida arranca (cargaron los asientos que esperaba) o el mundo está listo (solo) |
| `player_joined(slot)` | servidor | Entró un jugador por primera vez |
| `player_left(slot)` | servidor | Se fue un jugador |
| `player_back(slot)` | servidor | Volvió dentro de la gracia, mismo slot |
| `player_abandoned(slot)` | servidor | No volvió a tiempo, o nunca cargó |
| `waiting_changed(waiting)` | **todos** | La partida empieza o deja de esperar asientos |
| `finished(result)` | **todos** | El servidor llamó `finish` |

Métodos y propiedades:

| Nombre | Qué hace |
|---|---|
| `finish(result)` | Solo servidor: termina la partida. Todos reciben `finished(result)`. En una partida de sala, además escribe el resultado para la sala |
| `seats()` | Los slots de la partida (los de la puerta; vacío en solo) |
| `waiting` | Verdadero mientras espera asientos, en todos los peers |

Mientras espera, el árbol está pausado. La red del kit sigue andando (MpKit, el lobby, el agente, el lanzador, el beacon LAN corren igual), y también el botón Leave y la línea de invitación. Lo tuyo no: si querés mostrar "Esperando jugadores…", poné ese nodo del HUD con **Process › Mode = Always** y escuchá `waiting_changed`.

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$"../Match".waiting_changed.connect(func(on: bool) -> void: $Waiting.visible = on)
```

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

### 7.6 Salir de la partida

Agregá un **MpLeaveButton** al HUD (es un `Button`; el `MpWorld` ya trae uno en `Hud/Leave`):

1. En el mundo, un `CanvasLayer` llamado `Hud`.
2. Adentro, **Agregar nodo hijo › MpLeaveButton**. Si no le ponés texto, dice *Leave*.

Hace `MpFlow.leave_match()`: al lobby si la partida vino del lobby, si no al menú. Sirve igual en solo, en el host y en un cliente, y también con el mundo pausado esperando asientos. No termina la partida para los demás (eso es `MpMatch.finish`).

Por código, lo mismo:

```gdscript
Mp.leave()                                  # al lobby o al menú
MpFlow.find_in_tree(self).return_to_boot()  # siempre al menú
```

### 7.7 Pantalla de carga

El `MpFlow` carga el mundo en un hilo (`MpWorldLoader`, hijo interno del flow y único dueño de la carga): primero lee la escena del mundo y los archivos que nombre tu juego, después cambia de escena y, si lo pediste, espera a que **el mundo avise que está listo** (por ejemplo, después de precalentar shaders detrás de una pantalla). Recién ahí ese peer cuenta como cargado en la puerta de arranque. Así nadie arranca la partida con el mundo a medio compilar.

1. En tu flow (o su escena), tildá **`world_reports_loaded`** (o arrancá con `--world-reports-loaded`). Apagado (por defecto), «cargado» es «la escena del mundo entró», como siempre.
2. En el mundo, cuando esté listo: `MpFlow.find_in_tree(self).report_world_loaded()`. Mientras tanto podés contar el avance con `report_world_progress(0..1)`. Si el mundo nunca avisa, el loader sigue solo a los `report_timeout_s` (30 s) y la puerta arranca igual pasado `load_timeout_s`.
3. Para la pantalla, escuchá `world_load_progressed(ratio, phase)` del flow: `phase` es `MpWorldLoader.Phase` (`FILES` leyendo archivos, `WORLD` el mundo preparándose, `READY` listo, `IDLE` la carga se cortó porque la escena cambió por otro lado, por ejemplo se cayó el servidor). `ratio` va de 0 a 0,5 con los archivos y de 0,5 a 1 con el mundo. `world_loaded` avisa al final. La pantalla, y lo que precalienta el mundo, tienen que tener **Process › Mode = Always**: la puerta pausa el árbol mientras espera.
4. Dos ganchos para pisar en tu subclase de `MpFlow`: `_before_world_load()` (justo antes de cargar, en cada peer: elegir el mapa) y `_extra_world_loads() -> PackedStringArray` (archivos que el mundo va a usar después, para leerlos en el mismo hilo y no trabarse al aparecer).

Con `world_reports_loaded` prendido cambia quién cuenta:

- **Cliente**: su asiento cuenta al `report_loaded` (RPC al servidor), no al `world_ready` de los spawners. El `world_ready` sigue igual para lo demás (revelar spawns, `client_world_ready`), así que el servidor le puede mandar lo que el cliente necesita para prepararse.
- **Servidor** (host LAN, dedicado): la puerta espera también su propio mundo (`wait_host`, `mark_host_loaded`). Un dedicado sin pantalla avisa enseguida.
- **Solo** («Jugar solo» o contra la IA): la puerta se arma también, sin asientos ni red (`arm([], 0)`), y solo espera al host. El árbol queda pausado hasta que el mundo avisa, así el reloj de la partida y la IA no corren detrás de la pantalla. Sin `world_reports_loaded` arranca enseguida, como antes.

Si leer el mundo en el hilo falla (un arranque en frío justo después de importar, un pedido que el motor rechaza), el loader lo lee en el hilo principal en vez de quedarse sin mundo.

## 8. Probar

### 8.1 Solo

1. F5.
2. **Play solo**.

En solo, tu PC es servidor y dueño a la vez: `is_authority()` e `is_local()` son verdaderos. Todo el código corre, sin red.

### 8.2 LAN: dos ventanas en tu PC

1. Menú **Depurar › Ejecutar varias instancias** (Debug › Run Multiple Instances) y elegí 2.
2. F5. Se abren dos ventanas.
3. En una: **Host LAN**.
4. En la otra: elegí la sala en *LAN rooms*, o escribí `127.0.0.1` en el campo de dirección, y **Join**.

Hasta 4 ventanas en la misma PC pueden buscar salas a la vez: cada una escucha uno de los puertos UDP 7778 a 7781, y el host anuncia a los cuatro. En dos PCs de la misma red, la sala aparece igual. Si no aparece, escribí la IP que muestra el menú del host abajo de la lista.

### 8.3 Dedicado

En una terminal, en la carpeta del proyecto:

```bash
godot --headless --path . -- --dedicated
```

Después abrí clientes (F5, o varias instancias) y uní cada uno a `127.0.0.1`. El servidor no tiene jugador: el primer cliente es P1.

La partida arranca cuando cargaron todos los asientos, o `load_timeout_s` (15 s) después de que entró el primero. Para probarlo con un solo cliente y sin esperar: `godot --headless --path . -- --dedicated --start-seats=1`.

Desde el editor: en el diálogo de personalizar instancias del menú **Depurar**, poné `--headless -- --dedicated` en los argumentos de una instancia (marcá que anule los argumentos).

### 8.4 WebSocket y relay

Agregá `--transport=ws` a **todos** los procesos (servidor y clientes), o poné `transport = ws` en `game.tres`. Un servidor WebSocket solo atiende clientes WebSocket.

```bash
godot --headless --path . -- --dedicated --transport=ws
godot --path . -- --transport=ws
```

Con relay, ver [12](#12-relay-túnel-por-railway-u-otro-host).

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

- Los otros jugadores tironean: pasá a `BUFFERED`, bajá `late_tolerance` o subí el tope `buffer_delay_s`.
- Los otros se ven muy atrasados en una red buena: revisá que `adaptive_buffer` esté prendido.
- Tu jugador responde tarde: prendé `predict`.
- Tu jugador "salta" seguido: imprimí `net.last_correction()`; si es alto, revisá que `mp_move` solo dependa de las teclas, la posición y lo que está en Sync (por ejemplo `velocity`, ver [6.2](#62-mp_move-y-sus-reglas)).

Qué hace el kit solo con la red (todo medido, nada fijo):

| Pieza | Qué mide | Qué ajusta |
|---|---|---|
| Dibujo de los demás (`MpActor › Smoothing`) | cada cuánto llegan los estados y con cuánto atraso (percentil 97) | cuánto en el pasado se dibujan, un 10% del error por cuadro, nunca para atrás |
| Input en el servidor | con cuánto atraso llegan los frames de cada jugador (percentil 97) | cuántos frames junta antes de usarlos; crece al quedarse corto, se achica después de 2 s estables |
| Ritmo del dueño | cuántos frames le sobran o le faltan al servidor | si le faltan, el dueño mete un frame de más cada 16 ticks (alrededor de 6% más rápido), como Overwatch |
| Calidad de red (`Mp.net_quality()`) | pings 4 por segundo: RTT, jitter, pérdida | nada solo: es para tu interfaz (`grade_name`: `good`, `fair`, `bad`) |

En una PC, sin red, el movimiento de otro jugador aparece en tu pantalla unos 80-90 ms después de que apretó la tecla. Con 60 ms de lag por tramo, 30 ms de jitter y 3% de pérdida, unos 275-335 ms, y sigue parejo. `mpkit_lab/run/arena.sh` lo mide en cada corrida (`remote_delay_ms`).

### 8.6 Probar como en producción: `mpkit_lab`

El repo trae un proyecto de pruebas aparte del juego, `mpkit_lab/` (en la raíz del repo, no dentro del addon). Arranca el servidor como en producción (headless) y dos ventanas:

```bash
mpkit_lab/run/play.sh dedicated     # un dedicado headless + 2 ventanas
mpkit_lab/run/play.sh listen        # la ventana 1 hostea LAN, la 2 se une
mpkit_lab/run/play.sh rooms         # un servidor de salas headless + 2 ventanas en el lobby
```

| Opción | Qué hace |
|---|---|
| sin opciones | Jugás vos en las dos ventanas (flechas, Enter, Espacio, Tab, Escape) |
| `--watch` | Las ventanas juegan solas: ves una partida entera |
| `--relay` | Todo pasa por un relay local (necesita Node), como un túnel de Railway |

Cerrá las ventanas (o Ctrl+C) para terminar. Los logs quedan en la carpeta que imprime al arrancar.

Toda la matriz de casos automáticos: `mpkit_lab/run/all.sh` (una hora con una cola compartida). Para cada cambio, `mpkit_lab/run/all.sh --quick`: uno de cada tipo por ENet, en unos minutos. Fallas del relay (choque de puertos, reinicio, host congelado): `mpkit_lab/run/relayfault.sh`. Qué cubre cada prueba: `mpkit_lab/CASES.md`.

### 8.7 Cómo leer lo que pasa

- **El menú** muestra el estado abajo (*Connecting to…*, *Could not join*, *Lost the server*).
- **El HUD del ejemplo** muestra el rol: *Solo*, *Host · P1*, *Client · P2*, *Dedicated server*. Copialo para tu juego (`hud.gd`).
- **Panel Depurador › Errores**: los avisos del kit empiezan con el nombre del nodo (`MpActor on 'Pawn_2': ...`). Ver [15](#15-problemas-comunes).
- **Árbol remoto** (pestaña *Remoto* del panel Escena, con el juego corriendo): ves los nodos del proceso, `/root/MpKit`, tus `Pawn_N` y sus valores.
- **El servidor de salas** imprime una línea por evento: `rooms ready port 7700 (enet)` (recién cuando es alcanzable; con relay, cuando el relay lo aceptó), `match for room "x" on port 7810`, `match … ended {…}`, `match … failed …`. Con `--keep-match-files` conserva la carpeta de cada partida (ticket, estado, resultado y su log).
- **El cliente de lobby** imprime `lobby client: connecting to …` y `lobby client: welcome from …`.

### 8.8 Flags útiles

| Flag | Qué hace |
|---|---|
| `--dedicated` | Arranca como servidor dedicado y carga el mundo |
| `--listen-host` | Arranca hosteando LAN, sin tocar el menú |
| `--client1` / `--client2` + `--join-ip=IP` | Arranca uniéndose a esa IP (por defecto `127.0.0.1`) |
| `--room-server` | Abre la escena de salas (`rooms_scene` del juego, o `MpFlow.room_server_path`) |
| `--mp-port=N` | Puerto (le gana a `game.tres`) |
| `--max-players=N` | Jugadores (le gana a `game.tres`) |
| `--transport=enet` / `ws` / `relay` | Transporte |
| `--relay-url=`, `--relay-room=`, `--relay-secret=` | Relay (ver [12](#12-relay-túnel-por-railway-u-otro-host)) |
| `--world=id` | Mundo, si usás el catálogo `MpFlow.worlds` |
| `--keep-match-files` | Servidor de salas: no borra la carpeta de cada partida |
| `--lag-comp=off` | Servidor: sin compensación de lag (para comparar) |
| `--relay-refused-grace-s=N` | Cuánto reintenta un host que el relay rechazó antes de darse por rechazado (3 s; las partidas de un servidor de salas usan 0.5 s) |
| `--no-flow` | El `MpFlow` no hace nada (herramientas y pruebas) |

Van después de `--` en la línea de comando.

### 8.9 Los tests del kit

```bash
godot --headless --path . --script res://addons/mp_kit/tests/mp_test_runner.gd
```

Tiene que terminar con `MPKIT TESTS PASS (n)`. Prueban piezas sueltas (slots, frames de input, sincronizador, direcciones, asistente, buffers adaptativos, compensación de lag), no partidas en red: eso es `mpkit_lab`.

## 9. Online con salas

Para jugar por internet sin que nadie escriba IPs: un **servidor de salas** (el lobby) donde la gente se conecta con un nombre, crea o elige una sala, se sienta y dice *listo*. Cuando todos están listos, el servidor arranca **un proceso dedicado por partida** y le pasa a cada jugador la dirección y un token. Solo entran los sentados.

```
Cliente A ─┐                                 ┌─> Partida 1 (dedicado, puerto 7800)
Cliente B ─┼─> Servidor de salas (7700) ─────┤
Cliente C ─┘     lobby, salas, chat          └─> Partida 2 (dedicado, puerto 7801)
```

Son dos escenas más, anotadas en `game.tres`, y el `MpMatch` que ya trae el `MpWorld`. Cero código de pegamento. El ejemplo las trae: `rooms.tscn`, `lobby.tscn` y el `MpMatch` de `arena.tscn`.

### 9.1 La escena del servidor: `MpRoomServer`

1. Escena nueva, raíz `Node`, llamala `Rooms`.
2. Asignale el script `res://addons/mp_kit/rooms/mp_room_server.gd` (o agregá un nodo **MpRoomServer**).
3. En el inspector:

| Propiedad | Qué poner |
|---|---|
| `config` | Un `MpLobbyConfig` (`.tres`, abajo) |
| `net_config` | Dejalo vacío: toma el `game.tres` del flow que abrió esta escena con `--room-server`. El lobby y cada partida toman de ahí transporte, relay y TLS, así hablan como el juego. Ponelo solo si este servidor tiene que hablar distinto |
| `rules` | Opcional: tus reglas (`MpRoomRules`, abajo). Vacío = acepta todo, 2 asientos |
| `match_scene` | Escena que abre cada partida. Vacío = el `boot_scene` de `game.tres` (sin `MpGame`, la escena principal) |

4. Guardala como `rooms.tscn`.

### 9.2 `MpLobbyConfig`: los campos importantes

Creala como recurso nuevo (**Nuevo › Recurso › MpLobbyConfig**).

| Campo | Qué es | Por defecto |
|---|---|---|
| `lobby_port` | Puerto del lobby | 7700 |
| `transport` | `enet`, `ws` o `relay`. Con `game.tres` (o `MpRoomServer.net_config`), sale de ahí | `enet` |
| `max_connections` | Conexiones al lobby a la vez | 64 |
| `max_rooms` | Salas a la vez | 32 |
| `seats_per_room` | Asientos por sala si tus reglas no dicen otra cosa | 2 |
| `max_seats_per_room` | Tope de asientos, digan lo que digan las reglas | 8 |
| `countdown_s` | Cuenta regresiva cuando están todos listos | 5.0 |
| `empty_room_close_s` | Cierra una sala vacía después de esto | 120.0 |
| `resume_grace_s` | Cuánto guarda el lobby el asiento de alguien que se cayó del lobby | 120.0 |
| `public_host` | Dirección de las partidas que se manda a los clientes. Vacío = la misma que usaron para el lobby | vacío |
| `tls_certificate_path`, `tls_key_path` | Certificado y clave PEM para `wss://` (vacíos = los `tls_*` de `game.tres`) | vacío |
| `max_matches` | Partidas a la vez en esta máquina (cada una es un proceso) | 99 |
| `match_port_min`, `match_port_max` | Rango de puertos de las partidas | 7800-7899 |
| `ticket_ttl_s` | Cuánto vale el ticket para entrar a la partida | 60.0 |
| `rejoin_grace_s` | Cuánto puede tardar en volver un jugador que se cayó de la partida | 60.0 |
| `load_timeout_s` | Cuánto espera la partida a que todos carguen el mundo | 60.0 |
| `idle_no_players_s` | La partida se cierra si queda vacía este tiempo | 60.0 |
| `match_max_s` | Duración máxima de una partida (2 horas) | 7200.0 |

Cualquier campo se pisa con un flag de su nombre, con guiones: `max_matches` → `--max-matches=8`, `lobby_port` → `--lobby-port=7701`. Otro `.tres` entero: `--lobby-config=res://otra.tres`.

El ejemplo (`rooms_config.tres`) usa lobby 7700, 2 asientos, cuenta de 3 s, 4 partidas y puertos 7710-7719.

Cada partida se arma con tantos lugares como asientos tiene su ticket, aunque sean más que el `max_players` del juego.

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

- Para que `seats_for` vea un `mode`, la sala se tiene que crear con esa opción: poné `room_options = {"mode": "2v2"}` en la pantalla de lobby (el botón *Create room* las manda), o llamá `create_room(nombre, privada, {"mode": "2v2"})` desde tu UI.
- El pick por defecto es `{"pick": "default"}`. Con el `accept_pick` de arriba, ese pick se rechaza: cambiá `default_pick` en la pantalla de lobby o llamá `set_pick` desde tu UI.

### 9.4 La pantalla del cliente: `MpLobbyScreen`

1. **Escena › Nueva escena heredada…** y elegí `res://addons/mp_kit/rooms/ui/mp_lobby_screen.tscn` (así está hecho el `lobby.tscn` del ejemplo). Guardala como `lobby.tscn`.
2. En el inspector:

| Propiedad | Qué hace | Por defecto |
|---|---|---|
| `lobby_address` | El servidor de salas: `host:puerto`, un nombre o una URL `wss://…` (se puede editar en pantalla). Vacío = `public_host` del juego en `lobby_port`, o `127.0.0.1` en ese puerto | vacío |
| `lobby_port` | El puerto del servidor de salas, cuando la dirección no trae uno (`lobby_port` del `MpLobbyConfig`) | 7700 |
| `room_options` | Opciones que lleva cada sala creada con *Create room* (mapa, modo); las leen `seats_for` y `accept_options` | `{}` |
| `player_name` | Nombre inicial | `Player` |
| `default_pick` | El pick con el que arranca cada asiento. El lobby necesita uno antes de *listo* | `{"pick": "default"}` |
| `auto_join_match` | Entrar a la partida apenas arranca. Off = se emite `match_found(host, port, token)` y tu UI llama `join_found()` (para un botón "Unirse" propio) | on |
| `back_path` | Escena del botón *Back*. Vacío = el boot del juego | vacío |
| Grupo **Texts** | Todos los textos, para traducir | |

Qué hace: pantalla de conectar (nombre y dirección), lista de salas, crear sala (pública o con código), unirse con código, asientos, *Ready*, chat. Al arrancar la partida se une solo (por el `MpFlow`); al terminar vuelve acá y muestra el último resultado. Si te caíste de una partida que sigue corriendo, aparece **Back to the match** (ver 9.7).

Cada botón llama un método público, así podés hacer tu propia pantalla encima:

| Método | Qué hace |
|---|---|
| `connect_lobby(address, name)` | Conecta |
| `refresh()` | Pide la lista de salas |
| `create_room(nombre, privada, options)` | Crea una sala (sin `options`, usa `room_options`) |
| `join_room(id)` / `join_listed(index)` / `join_code(codigo)` | Entra a una sala |
| `set_pick(dict)` | Cambia lo que eligió el jugador |
| `set_ready(on)` | Listo / no listo |
| `leave_room()` | Se levanta |
| `send_chat(texto)` | Chat |
| `go_back()` | Cierra y vuelve a `back_path` (o al boot del juego) |
| `join_found()` | Con `auto_join_match` off: entra a la partida encontrada |
| `can_rejoin()` / `rejoin_match()` | ¿Tu partida sigue corriendo? / Volver a ella con el mismo ticket |

### 9.5 Conectar el boot con las salas

En `game.tres`, grupo **Scenes**: `lobby_scene` = tu `lobby.tscn` y `rooms_scene` = tu `rooms.tscn`. Con eso:

- El menú muestra **Online rooms**.
- Una partida de sala, al terminar, vuelve al lobby.
- `--room-server` abre `rooms.tscn`.
- `Mp.open_rooms()` abre el lobby desde tu propio menú.

(Sin `MpGame`: `lobby_path` y `room_server_path` en el `Flow`, y `lobby_scene_path` en el `Menu`.)

El `MpFlow` vive en el boot. Por eso el juego tiene que arrancar por el boot: si abrís `lobby.tscn` directo con F6, no hay flow y no puede entrar a la partida.

En el mundo, el `MpMatch` hace el resto: espera a que carguen todos, avisa ausencias y escribe el resultado.

### 9.6 Correr el servidor de salas

En tu PC, para probar:

```bash
godot --headless --path . -- --room-server
```

Arranca por el boot, y el `MpFlow` abre `rooms_scene` de `game.tres`: así el servidor de salas toma la red del juego y cada partida abre el boot del juego. Con el ejemplo, nombrá su boot: `godot --headless --path . res://addons/mp_kit/examples/arena_2d/boot.tscn -- --room-server`. Abrir `rooms.tscn` directo también anda, pero sin flow: toma la red de su propio `net_config` y las partidas abren la escena principal.

Esperá la línea `rooms ready port 7700 (…)`. Después abrí dos clientes (F5 dos veces), **Online rooms**, **Connect**, uno crea la sala, el otro entra, los dos tildan **Ready**. Arranca la cuenta y la partida. (O todo junto: `mpkit_lab/run/play.sh rooms`.)

Cada partida es tu mismo proyecto corriendo con `--dedicated` y un ticket. El `MpFlow` arma solo el agente que valida el ticket. Varias partidas a la vez son varios procesos, hasta `max_matches`.

### 9.7 Qué pasa cuando alguien se cae

**En el lobby**: el servidor le guarda el asiento `resume_grace_s` (120 s).

**En la partida**:

1. El servidor emite `player_left(slot)`. El `MpSlotSpawner` borra su jugador (si `despawn_on_leave`).
2. El jugador que se cayó vuelve a la pantalla de lobby. Si su partida sigue corriendo, ve **Back to the match** (*Your match is still running.*). Si lo aprieta dentro de `rejoin_grace_s` (60 s), vuelve con su mismo ticket y recupera su slot: `player_back(slot)`, y el spawner le crea un jugador nuevo en su punto de aparición. Qué conserva (puntos, vida) lo decidís vos: lo que está en `MpState` sigue ahí.
3. Si no vuelve a tiempo, o nunca cargó el mundo (`load_timeout_s`): `player_abandoned(slot)`. Qué significa (pierde, se sigue sin él) lo decidís vos, como en el ejemplo.
4. Si se cae el servidor de salas, sus partidas se cierran solas en pocos segundos (`parent_check_s`).
5. Si una partida queda vacía `idle_no_players_s`, se cierra.

Desde tu propia UI, lo mismo que el botón: `rejoin_match()` de la pantalla, o a mano:

```gdscript
var last := MpLobbyLink.client(get_tree()).last_match()   # {host, port, token}
if not last.is_empty():
	MpFlow.find_in_tree(self).join_match(last["host"], last["port"], last["token"])
```

### 9.8 Transporte de las salas

Tiene que ser el mismo en todos: el lobby, cada partida y cada cliente. Con `game.tres` (como hace el asistente) ya está: el servidor de salas usa ese transporte y se lo pasa a cada partida, y el cliente (pantalla de lobby y partida) usa el mismo `.tres`. Un flag `--transport=` en el servidor de salas le gana a los dos.

## 10. Partida privada con código

Sin VPS y sin servidor de salas: un dedicado en tu PC, y tus amigos entran con un código.

### 10.1 Con el botón

1. En el `Menu` del boot, tildá `offer_private_server`. (El asistente lo deja tildado.)
2. F5 › **Private server**.
3. El kit arranca un proceso dedicado en tu PC (`MpLocalServer`), con tantos asientos como `max_players` del juego, y te une solo.
4. Ya en la partida, el HUD muestra la invitación: `Friends join with 192.168.1.5:7800#K7P2QX`. La muestra un **MpInviteLabel**: el `MpWorld` trae uno en `Hud/Invite`; en un mundo armado a mano, agregá uno al HUD. Se ve solo en la PC que hostea la partida privada.
5. Tus amigos escriben eso en el campo de dirección del menú y **Join**. Cada asiento tiene su código; si hay varios, aparecen separados por coma.
6. Alguien sin código no entra.
7. Un segundo clic en **Private server** no arranca otra partida: devuelve la que ya corre y vuelve a mostrar su invitación. Dos programas en la misma PC pueden tener cada uno su partida privada sin pisarse.

La partida usa el mismo transporte que tu juego (ENet, WebSocket o relay). Por internet sin relay, tus amigos necesitan tu IP pública y el puerto abierto en tu router. Con relay no hace falta: la parte de la IP se ignora y el puerto elige la sala del relay.

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
| `invites()` / `invite_text()` | Lo que escriben los amigos, uno por asiento libre: `192.168.1.5:7801#K7P2QX` (por relay, `:7801#K7P2QX`) |
| `MpLocalServer.running(tree)` | El servidor privado que corre en este proceso, o `null`. `start_on` con uno corriendo lo devuelve |

Usa los tiempos y puertos de un `MpLobbyConfig` por defecto (partidas en 7800-7899) y la red de tu `game.tres` (transporte, relay, TLS). Con relay, busca puerto desde uno al azar del rango, y si el relay lo rechaza porque otro lo usa, prueba el siguiente.

## 11. Web

### 11.1 Qué cambia

Un navegador no puede abrir un servidor ni usar UDP. Entonces:

- Un export web usa **WebSocket**: directo, o por el relay si `game.tres` dice `transport = relay`. Con `enet` en el `.tres`, usa WebSocket directo, porque un navegador no tiene ENet.
- No puede hostear ni buscar salas LAN: el menú oculta **Host LAN**, **Private server** y la lista LAN. Si algo llama `host_lan()`, el estado dice *This build cannot host (web): join a server*.
- Solo se une: a un dedicado o un servidor de salas WebSocket, o a cualquiera por el relay.

### 11.2 Por qué no se mezcla con escritorio

Un servidor WebSocket solo atiende clientes WebSocket, y uno ENet solo atiende ENet. Si querés web y escritorio en la misma partida, usá WebSocket para todos (`transport = ws` en `game.tres`), o el relay para todos.

### 11.3 Exportar

1. Copiá el preset *Web* de `addons/mp_kit/deploy/export_presets.example.cfg` a tu `export_presets.cfg` (o crealo en **Proyecto › Exportar**).
2. Es sin threads (`variant/thread_support=false`): cualquier hosting estático sirve, sin cabeceras especiales.
3. Exportá a `build/web/index.html` y subilo a tu hosting.
4. El servidor: un dedicado (o un servidor de salas) con `transport = ws`, o cualquiera por el relay.

### 11.4 `wss://` y TLS

Una página servida por `https://` **no puede** abrir `ws://` (sin cifrar): necesita `wss://`. Tres caminos:

**Camino 1: TLS en Godot.**

En el servidor, alguna de estas:

| Dónde | Qué poner |
|---|---|
| `game.tres` del dedicado | `tls_certificate` (`X509Certificate`) y `tls_key` (`CryptoKey`). Las partidas de un servidor de salas los reciben como archivo: en un export, el kit los copia a `user://` |
| Flags del dedicado | `--tls-certificate-path=/ruta/fullchain.pem --tls-key-path=/ruta/privkey.pem` |
| `MpLobbyConfig` (salas) | `tls_certificate_path` y `tls_key_path`. El lobby escucha en `wss://` y cada partida recibe el mismo certificado. Si están vacíos, salen del `tls_*` de `game.tres` |
| `deploy.sh` | `--transport ws --tls-cert … --tls-key …` (ver [13](#13-subir-a-un-vps)) |

En el cliente:

| Dónde | Qué poner |
|---|---|
| `game.tres` del cliente | `tls_client` = on. `tls_trusted_ca` vacío para un certificado normal (Let's Encrypt). `tls_common_name` solo si el certificado es de otro nombre que la dirección |
| Flags | `--tls-client`, `--tls-trusted-ca=archivo.pem`, `--tls-common-name=nombre` |

La dirección tiene que ser el **dominio** del certificado (`juego.ejemplo.com:7700`), no una IP. La pantalla de lobby toma el transporte y el TLS del `game.tres` del flow.

**Camino 2: proxy inverso.** nginx o Caddy terminan TLS en el puerto 443 y reenvían al puerto WS local. El juego no cambia. En el campo de dirección del menú se puede escribir una URL completa: `wss://juego.ejemplo.com/ruta`. Detalle en [README.md](README.md) (sección *wss:// (TLS) para el VPS*).

**Camino 3: relay.** El relay en Railway ya tiene `wss://` con su dominio; tu servidor Godot se conecta a él. Ver [12](#12-relay-túnel-por-railway-u-otro-host). Un export web con `transport = relay` lo usa directo.

### 11.5 Pestaña oculta

Un navegador pausa una pestaña oculta. El jugador web que cambia de pestaña se congela para los demás hasta que vuelve. En una partida de sala, si tarda más que `rejoin_grace_s`, cuenta como abandono.

## 12. Relay (túnel por Railway u otro host)

El relay es un servidor Node chico (`relay/server.mjs`, sin dependencias, Node 18+) que hace de túnel. Tu servidor Godot se conecta **hacia afuera** al relay, así que no necesita IP pública ni puertos abiertos: puede correr en tu PC detrás del router. Los jugadores se conectan al mismo relay.

```
jugador ─┐
jugador ─┼── wss://tu-relay.up.railway.app ──── servidor Godot (tu PC, un VPS, donde sea)
jugador ─┘          (sala mi-juego-7777)          se conecta como host de la sala
```

Cada "puerto" del kit es una sala del relay: `<relay_room>-<puerto>`. Así el lobby (7700) y cada partida son salas distintas. Salas online, partidas y partida privada funcionan igual por el relay.

### 12.1 Subir el relay a Railway

1. Creá un repo (o una carpeta en el tuyo) con `server.mjs` y `package.json` de `addons/mp_kit/relay/`.
2. En Railway: **New Project › Deploy from GitHub repo** y elegí ese repo. Railway corre `npm start`.
3. En **Variables**: `RELAY_HOST_SECRET` = una clave larga al azar. Sin ella el relay no deja hostear a nadie (`RELAY_OPEN=1` lo abre, solo para pruebas locales).
4. En **Settings › Networking**: **Generate Domain**. Te queda `tu-relay.up.railway.app`, con TLS: la dirección es `wss://tu-relay.up.railway.app`.
5. Opcional: healthcheck en la ruta `/health`.

Probalo local antes:

```bash
PORT=8080 RELAY_HOST_SECRET=prueba node addons/mp_kit/relay/server.mjs
# dirección: ws://127.0.0.1:8080
```

O en **Fly.io**, con una región cerca de tus jugadores (`gru` = São Paulo; Railway no tiene ninguna en Sudamérica): los pasos, el `Dockerfile` + `fly.toml` y todos los comandos útiles (desplegar, logs, secretos, apagar) están en [relay/README.md](relay/README.md).

### 12.2 Configurar el juego

En el `game.tres` del juego (o el `MpNetConfig` que uses):

| Campo | Valor |
|---|---|
| `transport` | `relay` |
| `relay_url` | `wss://tu-relay.up.railway.app` |
| `relay_room` | el nombre de tu juego (`mi-juego`) |

El secreto **no** va en el `.tres` (viaja con los clientes). El servidor lo recibe por entorno o flag:

```bash
MPKIT_RELAY_SECRET=la-clave godot --headless --path . -- --dedicated      # un dedicado
MPKIT_RELAY_SECRET=la-clave godot --headless --path . -- --room-server    # salas: lobby y partidas por el relay
```

El servidor Godot usa `MPKIT_RELAY_SECRET` (o `--relay-secret=`); el relay usa `RELAY_HOST_SECRET`. Tienen que tener el mismo valor.

Las partidas que lanza el servidor de salas heredan el secreto y la configuración del relay solas. Los jugadores no necesitan nada: el menú se une con la dirección de siempre. Con relay, la parte del host se ignora y cuenta el puerto, que elige la sala (`127.0.0.1:7777` entra a `mi-juego-7777`). Una URL completa en el campo (`wss://otro-relay…`) usa ese relay.

Flags equivalentes: `--transport=relay --relay-url=wss://… --relay-room=mi-juego --relay-secret=…`.

Para probarlo todo junto en tu PC: `mpkit_lab/run/play.sh dedicated --relay` o `mpkit_lab/run/play.sh rooms --relay`.

### 12.3 Qué hace y qué no

- Pasa paquetes entre el host de una sala y sus clientes, todo por WebSocket (confiable y en orden).
- Una sala con un host vivo está ocupada, como un puerto en uso: un segundo host se rechaza (4009). Una partida de salas o privada prueba el puerto siguiente; un dedicado o un lobby avisa y se cierra. Cada servidor busca puerto desde uno al azar, así dos jugadores con partida privada casi nunca chocan.
- Un host que no responde los pings del relay en 15 s se suelta y su sala queda libre. Un host rechazado reintenta 3 s antes de darse por rechazado, así un servidor que se reinicia enseguida recupera su sala; las partidas de un servidor de salas reintentan 0.5 s y pasan al puerto siguiente.
- Un cliente de una sala sin host se rechaza; si el host se va, sus clientes se cierran.
- Topes, por variables del relay: `RELAY_MAX_CLIENTS` por sala (64), `RELAY_MAX_MESSAGE` en bytes (262144).
- No guarda nada, no ve el juego. La latencia es la del relay en el medio: elegí una región cerca de tus jugadores.
- Web: un export web con `transport = relay` usa el relay (es WebSocket). Con `enet` en el `.tres`, el navegador usa WebSocket directo, porque no tiene ENet.
- El host manda el secreto en el header `X-Relay-Secret`, no en la URL: no queda en los logs de acceso.

Protocolo y detalles: [relay/README.md](relay/README.md).

## 13. Subir a un VPS

Un solo binario de Linux hace todo: cliente, servidor de salas (`--room-server`) y cada partida (`--dedicated`). Si preferís no abrir puertos, el servidor puede correr en cualquier lado detrás del relay ([12](#12-relay-túnel-por-railway-u-otro-host)).

### 13.1 Lo que necesitás

- Un VPS Linux x86_64 con systemd (Ubuntu o Debian) y un usuario con `sudo` al que entrás por SSH.
- En tu PC, las plantillas de export de Linux de tu versión de Godot (**Editor › Administrar plantillas de exportación**).
- En el proyecto: un `game.tres` con `rooms_scene` (si usás salas) en el `MpFlow` del boot.

### 13.2 Exportar

1. Copiá el preset *Linux Server* de `deploy/export_presets.example.cfg` a tu `export_presets.cfg`. Es un export de Linux normal (no el modo *Dedicated Server*: la partida necesita colisiones y el mundo entero).
2. Exportá:

```bash
godot --headless --path . --export-release "Linux Server" build/server/juego.x86_64
```

Salen `juego.x86_64` y `juego.pck`, que van juntos.

### 13.3 Subir e instalar con `deploy.sh`

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
| `--rooms 7700,7701` | Un servidor de salas por puerto. Cada uno con 100 puertos de partida: 7800-7899, 7900-7999… | `7700` si no pasás ni `--rooms` ni `--dedicated` |
| `--dedicated 7777,7787` | Dedicados sin lobby, uno por puerto (se entra con IP y puerto). Solo con esto no instala salas | ninguno |
| `--transport enet\|ws\|relay` | Se pasa a todas las instancias | lo del build |
| `--relay-url URL` / `--relay-room NOMBRE` | El relay y el prefijo de sus salas, si no son los del build. El secreto sale de `MPKIT_RELAY_SECRET` en tu máquina | — |
| `--tls-cert RUTA` / `--tls-key RUTA` | `wss://` con ese certificado y clave PEM. Van juntos y piden `--transport ws` | — |
| `--open-firewall` | Abre los puertos con `ufw` (UDP con ENet, TCP con WebSocket; el lobby y sus partidas igual; nada con relay) | off |
| `--dry-run` | Solo imprime los comandos, no los corre | off |

Solo dedicados, sin salas:

```bash
addons/mp_kit/deploy/deploy.sh usuario@mi-vps build/server --dedicated 7777,7787 --open-firewall
```

No uses 7778-7781 para dedicados: son los puertos de la búsqueda LAN.

Probalo siempre primero con `--dry-run`.

Web por https:

```bash
addons/mp_kit/deploy/deploy.sh usuario@mi-vps build/server --rooms 7700 --transport ws \
  --tls-cert /etc/letsencrypt/live/DOMINIO/fullchain.pem \
  --tls-key /etc/letsencrypt/live/DOMINIO/privkey.pem --open-firewall
```

El usuario del servicio tiene que poder leer el certificado y la clave (con Let's Encrypt, por ejemplo, un grupo con permiso sobre `/etc/letsencrypt/live` y `archive`).

Relay en un VPS: el VPS no necesita puertos abiertos, porque el servidor se conecta hacia afuera. `--open-firewall` no abre nada con relay.

```bash
MPKIT_RELAY_SECRET=la-clave addons/mp_kit/deploy/deploy.sh usuario@mi-vps build/server --rooms 7700 \
  --transport relay --relay-url wss://tu-relay.up.railway.app
```

`deploy.sh` toma `MPKIT_RELAY_SECRET` de **tu** máquina y lo escribe en `/etc/juego/relay.env`, que solo lee el usuario del servicio. Si no lo pasás, ese archivo queda como estaba: un redeploy no borra el secreto. `--relay-room` cambia el prefijo de las salas si no querés el de `game.tres`.

### 13.4 Varias instancias

- Varias partidas a la vez en un servidor de salas: automático, hasta `max_matches`.
- Varios servidores de salas en el mismo VPS: `--rooms 7700,7701,7702`. Cada uno tiene su rango de puertos y su carpeta de partidas.
- Un número distinto para una sola instancia: editá `EXTRA_ARGS` en `/etc/juego/rooms-7700.env` (por ejemplo `--max-matches=8`) y reiniciala.

### 13.5 Operar

```bash
ssh usuario@mi-vps journalctl -u 'juego-rooms@*' -f        # logs en vivo
ssh usuario@mi-vps journalctl -u 'juego-dedicated@*' -f    # logs de dedicados sueltos
ssh usuario@mi-vps sudo systemctl restart juego-rooms@7700  # reiniciar uno
ssh usuario@mi-vps sudo systemctl disable --now juego-rooms@7701   # apagar uno
```

Si el servidor de salas se cae, systemd lo levanta. Sus partidas se cierran solas en pocos segundos.

En los clientes, poné la dirección del VPS en `public_host` de `game.tres` (por ejemplo `juego.ejemplo.com`): el menú y la pantalla de lobby arrancan con ella. Para dedicados sueltos, los jugadores escriben `juego.ejemplo.com:7777` en el menú.

Más detalle: [deploy/README.md](deploy/README.md).

## 14. Seguridad y límites

### 14.1 Lo que el kit ya pone

| Qué | Límite |
|---|---|
| `to_server` / `mp_sv_*` | Con `callers = OWNER`, solo el dueño (y con `owner_slot` = 0, nadie más que el servidor). Con `ANYONE`, cualquier jugador con slot. Solo métodos que empiezan con `mp_sv_` y con esa cantidad de argumentos. Argumentos de hasta 4 KB. Hasta 60 por segundo por cliente (ráfaga de 120), sumando todos sus `MpActor` |
| `to_all` / `mp_all_*` | Solo los manda el servidor |
| `MpInput` | Solo el dueño manda frames. Frames de hasta 1 KB, con tipos validados, fuerza de cada acción entre 0 y 1, hasta 16 valores propios. Un cliente que manda frames de más no se mueve más rápido |
| Túnel `Dictionary` | Mensajes de hasta 8192 bytes, 30 por segundo (ráfaga de 60) |
| Admisión por ticket (partidas de sala y privadas) | Solo entran los tickets del asiento. Tickets de hasta 512 caracteres. Sin ticket en 5 s, afuera. Hasta 64 conexiones esperando ticket a la vez |
| Lobby | Valida versión, nombre (24 caracteres), tamaño de opciones y picks (2048 bytes), ritmo del chat, y tiempo para saludar (`hello_timeout_s`). El cliente nunca elige slot, puerto ni semilla |
| Slots | Los asigna el servidor. El cliente nunca dice "soy el 2" |
| Compensación de lag | Nunca rebobina más de un segundo (como `sv_maxunlag` de Valve): un momento visto más atrás, o adelante de ahora, se recorta |
| Relay | Solo hostea quien tiene el secreto (`RELAY_HOST_SECRET`); viaja en un header, nunca en la URL. El secreto nunca va en el `.tres`. Una sala con host vivo no se puede tomar |

### 14.2 Lo que tiene que validar tu juego

1. **Los argumentos de cada `mp_sv_*`.** Llegan del cliente: pueden ser de cualquier tipo. Chequeá tipo y rango.

```gdscript
func mp_sv_buy(item: Variant) -> void:
	if typeof(item) != TYPE_STRING or not SHOP.has(item):
		return
	# ...
```

2. **Los valores de `input.get_value`.** También los manda el cliente. Si un vector tiene que ser una dirección, normalizalo y tené un valor por defecto, como el `aim` del ejemplo ([6.5](#65-valores-propios-set_value--get_value)).
3. **Los picks y opciones de sala** en `MpRoomRules.accept_pick` y `accept_options`.
4. **Que el pedido tenga sentido en el juego**: que el jugador tenga plata, esté cerca de la puerta, no esté muerto. El kit sabe quién pidió (`sender_slot()`), no si el pedido es justo.
5. **Nodos con `callers = ANYONE`**: cualquier jugador puede llamar sus `mp_sv_*`. No pongas ahí nada que solo deba hacer uno.
6. **El relay sin secreto no deja hostear a nadie.** Para pruebas en tu máquina existe `RELAY_OPEN=1`; en Railway, siempre `RELAY_HOST_SECRET`.

Nunca mandes tipos de bala o de personaje como texto por red: usá un `Resource` en el actor.

## 15. Problemas comunes

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

**"Set Player Scene: the scene every seat gets (it needs an MpActor)."** (en `MpWorld`)
Asigná `player_scene` en el `MpWorld`.

### Errores al jugar (panel Depurador)

**"MpActor on 'X': no MpSync child. Open the scene in the editor and save it (the editor builds it)."**
Igual que el primer aviso: abrí y guardá la escena del actor.

**"MpWorld 'X': no Y child. Open the scene in the editor and save it (the editor builds it)."**
Falta una pieza del `MpWorld` (le cambiaste el nombre, o la escena nunca se abrió en el editor). Abrí la escena del mundo y guardala: el `MpWorld` arma lo que falta.

**"MpActor on 'X': predict needs an MpInput next to it and mp_move(input, delta) on the parent"**
Falta el `MpInput` o `mp_move`. El kit apaga `predict` para ese nodo y sigue.

**"MpInput 'X': no MpActor next to it"**
Ver arriba.

**"MpActor 'X': to_server(y) from a peer that does not own it (callers = OWNER)"**
Un jugador llamó `to_server` en un nodo que no es suyo. Si es el jugador de otro, poné la llamada detrás de `if net.is_local():`. Si es un objeto del mundo que usa cualquiera (puerta, campana), poné `callers = ANYONE` en su `MpActor`.

**"MpActor 'X': no mp_sv_y() taking N arguments"** (o `mp_all_y`)
El nombre o la cantidad de argumentos no coincide. `to_server(&"buy", item)` necesita `func mp_sv_buy(item)`. Sin prefijo en la llamada: `&"buy"`, no `&"mp_sv_buy"`.

**"… only runs on the server"** (`to_all`, `despawn`, `MpState.set_value`, `MpMatch.finish`, `spawn_actor`)
Lo llamaste en un cliente. Ponelo detrás de `if net.is_authority():` (o `Mp.is_server()`).

**"MpActor 'X': despawn() on a node of the world scene; hide it (sync visible) or spawn it"**
Ese nodo está guardado en la escena del mundo: no se puede borrar para todos. Ocultalo con `sync_visible`, o hacelo aparecer con un `MpSpawner` para poder borrarlo (ver [7.3](#73-borrar-cosas)).

**"MpSpawner 'X': add res://… to Extra Scenes"**
Agregá esa escena a **Extra Scenes** del spawner, en el editor.

**"MpSpawner 'X': set spawn_path to the parent of replicated actors"** / **"spawn_path does not resolve"**
Poné `spawn_path` en el nodo vacío donde aparecen las cosas (`../Actors`, `../Projectiles`).

**"MpSpawner 'X': spawn_function was set after the scene was set up; set it in a _ready"**
Asigná `spawn_function` en un `_ready` de la escena (el del spawner, un hermano o el padre), no más tarde.

**"MpSlotSpawner 'X': assign pawn_scene"**
Asigná la escena del jugador.

**"MpSpawner 'X': … was added after its node was set up. Put synchronizers in the scene (or add them before add_child): the spawn packet and late joiners miss it."**
Un `MultiplayerSynchronizer` se agregó por código tarde (con un timer, diferido). Ponelo en la escena, o en el `_ready` del propio actor.

**"MpFlow: two flows (… and …); the one already running stays, this one's settings are ignored"**
Tenés dos `MpFlow` de distinto origen, por ejemplo un autoload (de *New session flow...*) y el nodo del boot. Gana el que ya estaba corriendo y lo que pusiste en el otro no se usa. Dejá uno solo. (Si es el mismo boot que se vuelve a cargar, no avisa: es normal.)

**"MpKit.host_dedicated failed: …"** / estado **"Could not host (port busy?)"**
El puerto está ocupado: otro servidor abierto, u otra instancia. Cerrala o usá `--mp-port=N`.

**"MpRoomServer: lobby port 7700: …"**
El puerto del lobby está ocupado. Cerrá el otro servidor de salas o usá `--lobby-port=N`.

**"MpLanBeacon: UDP 7778-7781 are all taken (4 game windows browsing?): this LAN list stays empty"**
Hay más de 4 ventanas buscando salas LAN en la misma PC, u otro programa usa esos puertos. Cerrá ventanas o escribí la IP a mano.

**"--transport=x: unknown, ENet is used"**
Valores válidos: `enet`, `ws` o `relay` (también se aceptan `udp`, `websocket`, `wss`, `tunnel`).

**"MpTransport: the relay transport needs a relay URL (--relay-url=wss://… or MpNetConfig.relay_url)"**
Con `transport = relay`, poné `relay_url` en `game.tres` o pasá `--relay-url=`.

**"MpRelayPeer: the relay closed the host (…)"**
El relay cortó a tu servidor. Causas comunes:
- El secreto no coincide (`MPKIT_RELAY_SECRET` del servidor ≠ `RELAY_HOST_SECRET` del relay): el relay ni acepta la conexión.
- El relay se reinició o se cayó.

**"MpRelayPeer: the relay room is in use by another host (like a port in use)"** / **"MpFlow: port N is in use on the relay …"** / **"MpRoomServer: lobby port N is in use on the relay …"**
Otro servidor del mismo juego tiene esa sala del relay (`relay_room` y puerto iguales). Una partida de salas o privada prueba sola otro puerto; un dedicado o un lobby se cierran. Usá otro puerto u otro `relay_room`. Si es tu propio servidor que se reinició, el kit reintenta 3 s y el relay suelta a un host mudo a los 15 s.

**"MpTransport: cannot load TLS certificate … / key …"**
La ruta está mal o el usuario del servicio no puede leer el archivo.

**"MpLobbyScreen: no MpFlow in the tree to join the match"**
Abriste la escena de lobby directo. Arrancá por el boot (F5), que tiene el `MpFlow`.

**"MpMatchAgent: unusable ticket …"**
El proceso de partida no pudo leer su ticket. Pasa si lo arrancaste a mano con `--match-ticket-file` de una partida vieja. Las partidas las arranca el servidor de salas.

**"MpKit: setup failed (…)"** / el botón **Create** desactivado
Algún archivo de la carpeta ya existe (`[~]`) o la carpeta no empieza con `res://`. Elegí otra carpeta.

### Comportamientos

**Mi jugador no se mueve en el cliente.**
1. ¿Las acciones que usás están en `MpInput.actions`? Si no, el servidor lee 0.
2. ¿Leés `input` (o `keys` en `mp_move`) y no `Input`? `Input` en el servidor lee el teclado del servidor.
3. ¿Con `predict` y sin `mp_move`? Mirá el error del depurador: el kit apagó la predicción.
4. ¿Sin `predict`, movés detrás de `is_authority()`? Si movés detrás de `is_local()`, el cliente se mueve en su pantalla pero el servidor lo devuelve a su lugar.
5. ¿`sync_position` está tildado? ¿Guardaste la escena del jugador después de tildarlo?
6. ¿El `MpSlotSpawner` (el `Players` del `MpWorld`) tiene `spawn_path` y `pawn_scene`?
7. ¿La partida espera asientos? El mundo está pausado hasta que cargan los que espera (`MpMatch.waiting`, `Mp.gate().is_waiting()`). Arranca sola pasado `load_timeout_s`; en Host LAN tocá **Start now** (`MpStartButton`), o probá `--start-seats=1`.

**Un cliente se rechaza enseguida con `timeout`, solo contra un servidor o relay remoto.**
El log del servidor dice `MpKit: the server turned peer N away (timeout)`: su ticket no llegó en `admission_timeout_s`. Los timeouts de red del kit cuentan tiempo real, así que un servidor lejos no es problema. Si el servidor corre temporizadores tuyos para cosas de red, usá `MpKit.after_real(segundos, callable)`, no `create_timer`: con `--fixed-fps` (deja de sincronizar con el reloj y puede correr miles de cuadros por segundo) o `Engine.time_scale`, el tiempo de juego no es tiempo real.

**Un segundo cliente no entra: «The match already started» (`match_started`).**
La puerta ya arrancó la partida: después del arranque solo vuelve un asiento que se fue. Para que entren varios, que carguen antes del arranque (`start_seats` = 0 espera todos los asientos, `--start-seats=N`), o prendé `late_join` (`--late-join`) para un juego de entrar y salir. En un dedicado a mano, la partida siguiente se abre sola cuando esta termina y se fueron todos.

**Se mueve, pero los otros jugadores tironean.**
Usá `smoothing = BUFFERED` con `adaptive_buffer` prendido; si sigue, bajá `late_tolerance` (0.01) o subí el tope `buffer_delay_s` (0.15, 0.2). Si bajaste `send_hz`, subilo o dejalo en 0.

**Los otros se ven muy atrasados, aun en una red buena.**
Revisá que `adaptive_buffer` esté prendido. Apagado, se dibujan siempre todo `buffer_delay_s` atrás.

**Mi jugador responde tarde.**
Prendé **Prediction › predict** y pasá el movimiento a `mp_move`.

**Con gravedad o inercia, mi jugador se corrige seguido.**
Agregá `velocity` (y lo que `mp_move` lea) a **Sync › sync_extra**. Ver [6.2](#62-mp_move-y-sus-reglas).

**Los disparos no aciertan lo que estaba en la pantalla del tirador.**
Validá contra lo que vio el tirador: `net.rewound(func)`, `net.seen_position_of(nodo)` o, para un proyectil, `net.view_lag()` como hace `shot.gd` del ejemplo ([6.8](#68-más-del-mpactor)).

**El que entra tarde no ve X.**
- Si X lo hiciste con `to_all`: es un efecto de una vez, no queda. Usá una propiedad en **Sync › Extra** o `MpState`.
- Si X es una propiedad: agregala a **Sync** del `MpActor` y guardá la escena.
- Si cambiaste `state.values` a mano: usá `set_value`.
- Si el sincronizador lo agregás por código tarde: ver el error del spawner de arriba.
- Si X es un nodo que agregaste con `add_child` en `spawn_path`: no se replica. Usá `spawn_actor` con la escena en **Extra Scenes**.

**No encuentro la sala LAN.**
1. La lista muestra solo partidas **Host LAN** (no dedicados ni privadas).
2. `lan_discovery` de `game.tres` y `advertise_lan` del `Flow` tienen que estar en on en el host.
3. El anuncio va por UDP broadcast a los puertos 7778-7781: el firewall de las dos PCs lo tiene que dejar pasar, y tienen que estar en la misma red (no funciona por internet ni entre subredes).
4. Más de 4 ventanas en la misma PC: ver el warning `MpLanBeacon` de arriba.
5. En web no hay lista LAN.
6. Siempre podés escribir la IP que el host ve abajo de su lista.

**"Invalid address (an IP or a name, optionally :port)" en el estado.**
La dirección está mal escrita: un puerto fuera de 1-65535, un nombre con caracteres raros, o vacía. Formatos válidos: `192.168.1.5`, `juego.ejemplo.com`, cualquiera con `:puerto`, `ip:puerto#CÓDIGO` o una URL `ws://…` / `wss://…`. En la pantalla de lobby el mismo error dice *Invalid lobby address*.

**"Could not join" / se queda en "Connecting to …".**
- ¿El servidor está corriendo y en ese puerto?
- ¿Mismo transporte en los dos? Un cliente ENet no habla con un servidor WebSocket.
- ¿El firewall o el router dejan pasar el puerto (UDP con ENet, TCP con WebSocket)?
- ¿Está lleno? Pasado `max_players`, el servidor corta la conexión.
- Con relay: ¿el servidor ya está conectado al relay? Un cliente de una sala sin host se rechaza.

**El web no conecta por https.**
1. La página es `https`: necesita `wss://`. Prendé `tls_client` en el `game.tres` del cliente.
2. El servidor tiene que tener certificado y clave (ver [11.4](#114-wss-y-tls)), o un proxy inverso.
3. Usá el dominio del certificado, no la IP.
4. El servidor tiene que ser WebSocket (`transport = ws`), también el de salas, o ir por el relay.

**"Lost the server".**
El servidor se cerró o se cortó la red. El flow vuelve al boot (o al lobby si la partida vino de una sala, donde aparece **Back to the match** si sigue corriendo).

**Rechazado al entrar a una partida de sala o privada (`rejected`, `slot_taken`, `slot_out_of_range`, `timeout`, `dropped`).**
- `rejected`: el ticket o código no vale (vencido, de otra sala, mal escrito, o ya pasó la gracia).
- `slot_taken`: ese asiento lo tiene otro peer conectado.
- `slot_out_of_range`: el ticket pide un slot que la partida no tiene. No debería pasar con partidas del kit (se dimensionan según el ticket); revisá un `admission` o un `build_ticket` propio.
- `timeout`: no presentó ticket a tiempo.
Se escuchan con `MpKit.admission_rejected`.

**El lobby dice `Error: bad_meta`.**
Tu `accept_pick` rechazó el pick. Revisá `default_pick` de la pantalla de lobby o llamá `set_pick` con algo válido.

**La partida de sala no arranca.**
Todos los asientos tienen que estar ocupados y en **Ready**. Mirá el log del servidor de salas: si dice `match … failed …`, el proceso de partida no arrancó (puerto, `max_matches`, el ejecutable). Con `--keep-match-files` queda el log de esa partida.

**No veo el código de mi partida privada.**
Lo muestra el HUD de la partida con un **MpInviteLabel** (en `Hud/Invite` del `MpWorld`). En un mundo armado a mano, agregá uno al HUD.

**El jugador web se congela para los demás.**
Cambió de pestaña: el navegador la pausó. Ver [11.5](#115-pestaña-oculta).

## 16. Glosario

| Término | Qué es |
|---|---|
| `MpKit` | El autoload: red, slots, mensajes de sesión |
| `MpFlow` | El nodo que maneja escenas y modos (solo, LAN, unirse, dedicado). Es dueño de la sesión |
| `Mp` | La clase con los verbos de la partida: `play_solo`, `host`, `join`, `leave`, `is_server`, `me`, `state`, `finish`, `net_quality` |
| `MpGame` | El juego en un `.tres`: la red (es un `MpNetConfig`) y las escenas (boot, mundo, lobby, salas) |
| `MpWorld` | Un nodo en el mundo que arma puntos de aparición, actores, spawner, estado, partida, botón Leave, invitación, botón Start now y aviso de espera |
| `MpInviteLabel` | En el HUD: en una partida privada de esta PC, lo que escriben los amigos para entrar |
| `MpStartButton` | En el HUD: en Host LAN, mientras la partida espera asientos, el host arranca con los que ya entraron |
| `MpWaitingLabel` | En el HUD: mientras la partida espera sus asientos, «Waiting for players (1/4)» en todos los peers |
| `MpNetQuality` | La calidad de la conexión (RTT, jitter, pérdida, nota); se lee con `Mp.net_quality()` |
| `MpLagComp` | La compensación de lag: un segundo de poses en el servidor, para validar un disparo contra lo que vio el tirador |
| `MpNetConfig` | Recurso `.tres` con la red del juego: transporte, puerto, jugadores, dirección pública, relay, TLS |
| `MpAddress` | El lector de direcciones (IP, nombre, `:puerto`, `#CÓDIGO`, URL) que usan el menú, el flow y el lobby |
| `MpBootMenu` | El menú listo para usar (`mp_boot_menu.tscn`) |
| `MpActor` | Hijo de todo lo que la red comparte: sync, dueño, llamadas, predicción |
| `callers` | Quién puede pedir los `mp_sv_*` de un `MpActor`: `OWNER` o `ANYONE` |
| `MpSync` | El `MultiplayerSynchronizer` que arma el editor bajo un `MpActor` o `MpState` |
| `MpInput` | Las teclas del dueño, leídas en el servidor con la API de `Input` |
| `MpState` | Valores de partida que ven todos |
| `MpMatch` | Inicio y fin de partida, espera de asientos, ausencias y abandonos |
| `MpLeaveButton` | Botón que sale de la partida (al lobby o al menú) |
| `MpSpawner` | Spawner que crea cosas en todos (`spawn_actor`, Extra Scenes) |
| `MpSlotSpawner` | Spawner de un jugador por slot |
| `MpRoomServer` | Escena del servidor de salas |
| `MpLobbyConfig` | Recurso `.tres` con puertos, límites y tiempos de salas y partidas |
| `MpRoomRules` | Tus reglas de sala (asientos, picks, opciones) |
| `MpLobbyScreen` | La pantalla de lobby del cliente |
| `MpLocalServer` | Dedicado en tu PC con códigos (partida privada) |
| Relay | Servidor Node intermedio; el servidor Godot se conecta hacia afuera |
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
| Compensación de lag | El servidor valida un disparo contra lo que vio el tirador |
| `BUFFERED` / `FOLLOW` / `NONE` | Modos de suavizado de proxies |
| ENet | Transporte UDP (escritorio) |
| WebSocket / `ws` / `wss` | Transporte TCP (web); `wss` = cifrado con TLS |

## 17. Quiero X → uso Y

| Quiero… | Uso… |
|---|---|
| un juego que anda en minutos | **Proyecto › Herramientas › MpKit: Setup game...** |
| toda la red y las escenas en un lugar | un **MpGame** (`game.tres`) en **Flow › Game** |
| un mundo en red sin cablear nodos | un **MpWorld** con **Player Scene** |
| jugar solo, hostear, unirse o salir desde mi propio menú | `Mp.play_solo()`, `Mp.host()`, `Mp.join(texto)`, `Mp.leave()` |
| una pantalla de carga que espera al mundo (shaders) | **MpFlow › world_reports_loaded** + `report_world_loaded()` en el mundo; escuchá `world_load_progressed` ([7.7](#77-pantalla-de-carga)) |
| que algo se vea igual en todos | **MpActor › Sync** (posición, rotación, visible, Extra) |
| sincronizar una propiedad propia (`health`) | **MpActor › Sync › sync_extra** = `health` (o `Health:current`) |
| que el jugador responda sin lag | **MpActor › Prediction › predict** + `func mp_move(keys, delta)` |
| gravedad o inercia con predicción | `velocity` en **Sync › sync_extra** |
| que los otros se vean parejos | **MpActor › Smoothing** = `BUFFERED` (con `adaptive_buffer`), y `late_tolerance` o el tope `buffer_delay_s` |
| mostrar el ping o la calidad de la conexión | `Mp.net_quality()` |
| que un disparo acierte lo que vio el tirador | `net.rewound(func)`, `net.seen_position_of(nodo)` o `net.view_lag()` (compensación de lag) |
| gastar menos ancho de banda | **MpActor › Sync › send_hz** (por ejemplo 20) |
| leer las teclas del jugador en el servidor | `input.get_vector`, `input.is_action_just_pressed`… |
| mandar el punto de mira | `input.set_value(&"aim", v)` en el dueño, `input.get_value(&"aim")` en el servidor (validalo) |
| una orden del jugador | `net.to_server(&"x", args)` → `func mp_sv_x(args)` |
| saber quién pidió la orden | `net.sender_slot()` dentro de `mp_sv_*` |
| un efecto en todos | `net.to_all(&"x", args)` → `func mp_all_x(args)` (solo servidor) |
| un objeto que cualquiera puede usar | `MpActor` con **Owner › callers = ANYONE** + `to_server` |
| aparecer balas o pickups | **MpSpawner** con la escena en **Extra Scenes** + `spawn_actor(escena, props, owner_slot)` |
| borrar algo en todos | `net.despawn()` (servidor, nodos hechos por un spawner) |
| ocultar un objeto del mundo | `sync_visible` + `visible = false` en el servidor |
| teletransportar sin deslizar | `net.snap()` en los clientes |
| puntaje, reloj, ronda | `Mp.state().set_value` / `.add`, señal `changed` |
| terminar la partida | `Mp.finish({"winner": ...})`, señal `finished` en todos |
| mostrar "esperando jugadores" | `MpMatch.waiting_changed` + nodo con Process Mode = Always |
| saber si alguien volvió o abandonó | `MpMatch.player_back` / `player_abandoned` |
| un botón para salir | el `Hud/Leave` del `MpWorld` (un **MpLeaveButton**), o `Mp.leave()` |
| volver al menú siempre | `MpFlow.find_in_tree(self).return_to_boot()` |
| volver a una partida de sala después de caerme | botón **Back to the match** (`MpLobbyScreen.rejoin_match()`) |
| saber si soy servidor | `net.is_authority()` / `Mp.is_server()` |
| saber si este nodo es mío | `net.is_local()` |
| saber qué jugador soy | `Mp.me()`, o un **MpLocalSeat** pasado al HUD (`seat.slot`, `is_mine`, `preview_slot` en solo) |
| un valor de la partida desde el inicio y en cada cambio | `state.watch(&"clave", callback)` |
| spawnear desde cualquier peer sin preguntar quién soy | `spawner.spawn_here(data)` |
| jugar en LAN | **Host LAN** + **Join** a la IP |
| un servidor dedicado | `godot --headless --path . -- --dedicated` |
| salas online | `lobby_scene` y `rooms_scene` en `game.tres`: `MpRoomServer` + `MpLobbyConfig` + `MpLobbyScreen` (el `MpMatch` viene en el `MpWorld`) |
| reglas de sala | un script que extiende `MpRoomRules` |
| salas con modo o mapa | `MpLobbyScreen.room_options` + `MpRoomRules.seats_for` |
| partida con código en mi PC | `MpBootMenu.offer_private_server` o `MpLocalServer.start_on` |
| que el menú ya tenga la dirección del servidor | `public_host` en `game.tres` |
| servidor sin IP pública ni puertos | relay: `transport = relay`, `relay_url`, `MPKIT_RELAY_SECRET` |
| juego web | `transport = ws` (o `relay`) en `game.tres`, servidor WS o relay, export Web |
| web por https | `wss://`: `tls_client` en el cliente y certificado en el servidor |
| probar con lag | `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` |
| ver una partida entera sin jugar | `mpkit_lab/run/play.sh dedicated --watch` |
| subir a un VPS | `deploy/deploy.sh usuario@vps build/server --rooms 7700 --open-firewall` |
| ver los logs del VPS | `journalctl -u 'juego-rooms@*' -f` |

## 18. Dónde seguir

- [QUICKSTART.md](QUICKSTART.md): la versión corta.
- [README.md](README.md): referencia de cada pieza, transporte, túnel `Dictionary`, salas hub y bajo nivel.
- [deploy/README.md](deploy/README.md): despliegue en un VPS en detalle.
- [relay/README.md](relay/README.md): el relay, Railway, Fly.io, comandos útiles y su protocolo.
- [examples/arena_2d/](examples/arena_2d/): el ejemplo completo. Abrí `boot.tscn` y apretá F6.
- `mpkit_lab/` (en la raíz del repo): `run/play.sh` para jugar o mirar en ventanas, `run/all.sh` para toda la matriz, y `CASES.md` con qué cubre cada prueba.
