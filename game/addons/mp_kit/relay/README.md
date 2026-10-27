# Relay de MpKit (túnel WebSocket)

Un servidor Node chico que hace de túnel entre tu servidor Godot y los jugadores. El servidor Godot se conecta **hacia afuera** al relay, así que no necesita IP pública ni puertos abiertos: puede correr en tu PC detrás del router. Los jugadores (web o escritorio) se conectan al mismo relay. Railway, Render, Fly o cualquier VPS con Node lo corren.

```
jugador web ─┐
jugador PC  ─┼── wss://tu-relay.up.railway.app ──── servidor Godot (tu PC, un VPS, donde sea)
jugador PC  ─┘          (sala juego-7777)              se conecta como host de la sala
```

Node 18+ y una dependencia, [`ws`](https://github.com/websockets/ws) (la librería de WebSocket habitual en Node): corré `npm install` una vez en esta carpeta. El código es corto y está separado por tarea:

| Archivo | Qué hace |
|---|---|
| `server.mjs` | Arranca el relay con la configuración del entorno |
| `lib/config.mjs` | Las variables de entorno y sus valores por defecto |
| `lib/protocol.mjs` | Los mensajes binarios y los códigos de cierre (sección 4) |
| `lib/rooms.mjs` | Las reglas: quién hostea una sala, quién entra, a dónde va cada mensaje, hosts mudos |
| `lib/relay.mjs` | HTTP, `/health`, el secreto del host, cada WebSocket entregado a las reglas |
| `test/` | `npm test`: las reglas con peers falsos, y el relay de punta a punta |

## 1. Subirlo a Railway

1. Creá un repo (o una carpeta en el tuyo) con los archivos de esta carpeta: `server.mjs`, `lib/`, `package.json` y `package-lock.json` (no `node_modules/`).
2. En Railway: **New Project › Deploy from GitHub repo** y elegí ese repo. Railway detecta Node, instala `ws` y corre `npm start`.
3. En **Variables**: `RELAY_HOST_SECRET` = una clave larga al azar. Sin ella el relay no deja hostear a nadie.
4. En **Settings › Networking**: **Generate Domain**. Te queda algo como `tu-relay.up.railway.app`. Railway pone el TLS: la dirección es `wss://tu-relay.up.railway.app`.
5. Healthcheck (opcional): ruta `/health`.

Probalo local antes: `npm install`, después `PORT=8080 RELAY_HOST_SECRET=prueba node server.mjs` y `ws://127.0.0.1:8080`. Para pruebas en tu máquina, `RELAY_OPEN=1` deja hostear sin secreto; nunca lo uses en un relay público.

### O en Fly.io (una región cerca de tus jugadores, p.ej. São Paulo)

Fly tiene regiones que Railway no (`gru` para Sudamérica; las de Railway están en EE.UU., Europa y Asia). [relay-godot](https://github.com/Joelnicolass/relay-godot) trae estos mismos archivos y el `Dockerfile` + `fly.toml` para Fly, listos para clonar.

1. Instalá `flyctl` e iniciá sesión: `fly auth login`.
2. En `fly.toml`, poné en `app` un nombre tuyo (en Fly es global) y en `primary_region` la región más cercana a tus jugadores (`fly platform regions`).
3. `fly apps create <tu-app>`, y el secreto del host (nunca en un archivo del repo): `fly secrets set --app <tu-app> RELAY_HOST_SECRET=<una clave larga al azar>`.
4. `fly deploy --ha=false`: una sola máquina (las salas viven en su memoria). La dirección es `wss://<tu-app>.fly.dev`; `/health` responde `ok`.

`fly.toml` deja la máquina siempre prendida (`auto_stop_machines = "off"`, `min_machines_running = 1`): un apagado por inactividad cortaría los WebSocket abiertos. Costo: la máquina más chica más el tráfico de salida por GB; el ejemplo arena del kit mueve unos 0,15 GB por jugador por hora a través del relay.

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
| peer → relay | `0x04 DATA i32 to u8 canal u8 modo bytes…` (host: un id, `0` = todos, `-id` = todos menos id; cliente: siempre al host) · `0x05 KICK u32 id [motivo]` (solo el host; el relay cierra a ese cliente con `4007` y el motivo, así sabe por qué lo rechazaron) |

Conexión: `wss://relay/?role=host&room=SALA` con el header `X-Relay-Secret: CLAVE` (también se acepta `&secret=CLAVE`), o `?role=client&room=SALA`.

## 5. Comandos útiles

Un secreto del host (copialo en el relay y en el servidor Godot, en ningún otro lado):

```bash
openssl rand -hex 24
```

El relay en tu máquina:

```bash
npm install --prefix addons/mp_kit/relay    # una vez: la dependencia ws
npm test --prefix addons/mp_kit/relay       # las pruebas del relay
PORT=8080 RELAY_HOST_SECRET=prueba node addons/mp_kit/relay/server.mjs   # ws://127.0.0.1:8080
RELAY_OPEN=1 PORT=8080 node addons/mp_kit/relay/server.mjs               # cualquiera puede hostear: solo pruebas locales
curl http://127.0.0.1:8080/health   # ok
```

En Fly.io (`<tu-app>` = `app` en `fly.toml`):

```bash
fly auth login
fly apps create <tu-app>
fly secrets set --app <tu-app> RELAY_HOST_SECRET=<clave>   # con --stage antes del primer deploy
fly deploy --ha=false                 # desplegar o actualizar, una sola máquina
fly status --app <tu-app>             # la máquina, su región, el chequeo de /health
fly logs --app <tu-app>               # log en vivo: hosts que entran, hosts rechazados, salas
curl https://<tu-app>.fly.dev/health  # ok
fly secrets list --app <tu-app>       # nombres y digests, nunca los valores
fly scale count 0 --app <tu-app>      # apagarlo (no se cobra máquina)
fly scale count 1 --app <tu-app>      # prenderlo otra vez
fly platform regions                  # códigos de región (gru = São Paulo)
fly apps destroy <tu-app>             # borrarlo del todo
```

En Railway: **Variables** (`RELAY_HOST_SECRET`), **Deployments › View logs**, **Settings › Networking** (el dominio).

El servidor Godot por el relay (el secreto por entorno, nunca en el `.tres`):

```bash
MPKIT_RELAY_SECRET=<clave> godot --headless --path . -- --dedicated --transport=relay --relay-url=wss://<tu-relay> --relay-room=mi-juego
MPKIT_RELAY_SECRET=<clave> godot --headless --path . -- --room-server   # con relay_url / relay_room en game.tres
```

Probar las reglas del relay desde el repo del kit: `bash mpkit_lab/run/relay.sh` (secreto del host, sala ocupada) y `bash mpkit_lab/run/relayfault.sh` (un host que muere, se congela o reinicia); todo el juego por un relay local: `TRANSPORT=relay bash mpkit_lab/run/arena.sh`.

## Verificado

Con el relay local: arena (dedicado, LAN, rejoin, lag, inundación), salas (siete escenarios) y partida privada por el relay. En Fly.io (`gru`), probado desde Argentina: arena, salas, la partida privada y un cliente web pasan por él; el kit midió 59 ms de ida y vuelta a través del relay (Railway, en EE.UU.: unos 300 ms).
