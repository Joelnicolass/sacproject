# Relay de MpKit (túnel WebSocket)

Un servidor Node chico que hace de túnel entre tu servidor Godot y los jugadores. El servidor Godot se conecta **hacia afuera** al relay, así que no necesita IP pública ni puertos abiertos: puede correr en tu PC detrás del router. Los jugadores (web o escritorio) se conectan al mismo relay. Railway, Render, Fly o cualquier VPS con Node lo corren.

```
jugador web ─┐
jugador PC  ─┼── wss://tu-relay.up.railway.app ──── servidor Godot (tu PC, un VPS, donde sea)
jugador PC  ─┘          (sala juego-7777)              se conecta como host de la sala
```

No tiene dependencias: `server.mjs` usa solo Node 18+.

## 1. Subirlo a Railway

1. Creá un repo (o una carpeta en el tuyo) con `server.mjs` y `package.json` de esta carpeta.
2. En Railway: **New Project › Deploy from GitHub repo** y elegí ese repo. Railway detecta Node y corre `npm start`.
3. En **Variables**: `RELAY_HOST_SECRET` = una clave larga al azar. Sin ella el relay no deja hostear a nadie.
4. En **Settings › Networking**: **Generate Domain**. Te queda algo como `tu-relay.up.railway.app`. Railway pone el TLS: la dirección es `wss://tu-relay.up.railway.app`.
5. Healthcheck (opcional): ruta `/health`.

Probalo local antes: `PORT=8080 RELAY_HOST_SECRET=prueba node server.mjs` y `ws://127.0.0.1:8080`. Para pruebas en tu máquina, `RELAY_OPEN=1` deja hostear sin secreto; nunca lo uses en un relay público.

## 2. Configurar el juego

En el `game.tres` del juego (un `MpGame`; o el `MpNetConfig` que uses):

| Campo | Valor |
|---|---|
| `transport` | `relay` |
| `relay_url` | `wss://tu-relay.up.railway.app` |
| `relay_room` | el nombre de tu juego (`mi-juego`); cada puerto es la sala `mi-juego-<puerto>` |

El secreto **no** va en el `.tres` (viaja con los clientes). Es la misma clave con dos nombres: `RELAY_HOST_SECRET` en el relay y `MPKIT_RELAY_SECRET` en el servidor Godot, que la recibe por entorno o flag:

```bash
MPKIT_RELAY_SECRET=la-clave godot --headless --path . -- --dedicated          # un dedicado
MPKIT_RELAY_SECRET=la-clave godot --headless --path . -- --room-server        # salas: lobby y partidas por el relay
```

Las partidas que lanza el servidor de salas heredan el secreto y la configuración del relay solas. Los jugadores no necesitan nada: el menú se une con la dirección de siempre (el host del texto se ignora con el relay; cuenta el puerto, que elige la sala).

Flags equivalentes: `--transport=relay --relay-url=wss://… --relay-room=mi-juego --relay-secret=…`.

## 3. Qué hace y qué no

- Pasa paquetes entre el host de una sala y sus clientes (todo por WebSocket: confiable y en orden). El host es el peer 1; los clientes reciben 2, 3…
- El host manda el secreto en el header `X-Relay-Secret`, no en la URL: así no queda en los logs de acceso.
- Una sala con un host vivo está **ocupada**, como un puerto en uso: un segundo host se rechaza (`4009`). El kit lo trata así: una partida de un servidor de salas o una partida privada prueba el puerto siguiente; un dedicado o un lobby avisa que el puerto está en uso y se cierra. Con relay, cada servidor busca puerto desde uno al azar del rango, así dos jugadores que abren una partida privada casi nunca chocan.
- El relay le hace ping a cada host cada 5 s; uno que no responde en `RELAY_HOST_SILENT_MS` (15 s) se suelta (`4010`) y la sala queda libre. Así un servidor que murió sin cerrar no bloquea su sala para siempre.
- Un cliente de una sala sin host se rechaza (`4004`); si el host se va, sus clientes se cierran (`4005`). El host puede echar a un cliente (`4007`): así funcionan "servidor lleno" y la admisión por ticket.
- Topes por entorno: `RELAY_MAX_CLIENTS` por sala (64), `RELAY_MAX_MESSAGE` en bytes (262144).
- No guarda nada, no ve el juego, no mezcla salas. Latencia: la del relay en el medio (elegí una región cerca de tus jugadores).

## 4. Protocolo (por si querés otro relay)

Mensajes binarios, little-endian:

| Dirección | Mensaje |
|---|---|
| relay → peer | `0x01 WELCOME u32 tu_id` · `0x02 JOIN u32 id` (al host) · `0x03 LEAVE u32 id` (al host) · `0x04 DATA u32 from u8 canal u8 modo bytes…` |
| peer → relay | `0x04 DATA i32 to u8 canal u8 modo bytes…` (host: un id, `0` = todos, `-id` = todos menos id; cliente: siempre al host) · `0x05 KICK u32 id` (solo el host) |

Conexión: `wss://relay/?role=host&room=SALA` con el header `X-Relay-Secret: CLAVE` (también se acepta `&secret=CLAVE`), o `?role=client&room=SALA`.

## Verificado

En una Mac, con el relay local: arena (dedicado, LAN, rejoin, lag, inundación), salas (siete escenarios) y partida privada por el relay. Railway en sí no se probó desde acá: el relay es el mismo archivo.
