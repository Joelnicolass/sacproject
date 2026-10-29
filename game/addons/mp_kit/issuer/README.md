# Emisor de MpKit (salas que hospedan tus jugadores)

Un servidor Node + Express chico que deja que **los jugadores hospeden las partidas**: ningún servidor de juego tuyo las corre, solo este emisor y el relay. El juego de un jugador le pide una sala y recibe un código más un token corto para hospedar esa sala en el relay; los amigos le piden un asiento y reciben un token para entrar. Lista las salas públicas, mantiene límites y olvida las salas cuyo host dejó de hablar.

```
juego del host ── POST /v1/rooms ─────────────► emisor (este)       firma con la clave PRIVADA Ed25519
               ◄─ código K7F3QX, token de host ─
               ── wss://relay/?role=host&room=p-K7F3QX&token=… ───► relay   chequea con la clave PÚBLICA
amigo          ── POST /v1/rooms/K7F3QX/join ─► emisor: un asiento, un token de cliente
               ── wss://relay/?role=client&room=p-K7F3QX&token=… ─► relay
```

Del lado de Godot son `MpFlow.host_online()` / `join_online(code)` / `online_rooms()` (GUIDE sección 10.3). Un host de escritorio corre la partida en un proceso de su PC (`MpLocalServer`); un navegador la hospeda en su propia pestaña y sigue simulando con la pestaña oculta (`MpWebKeepAlive`).

Node 20+. `npm install` una vez en esta carpeta.

| Archivo | Qué hace |
|---|---|
| `server.mjs` | Arranca el emisor con la configuración del entorno |
| `keys.mjs` | Hace el par de claves: la mitad privada para este emisor, la pública para el relay |
| `lib/config.mjs` | Las variables de entorno y sus valores por defecto |
| `lib/tokens.mjs` | Los tokens del relay (JWT, EdDSA) |
| `lib/rooms.mjs` | Las reglas: salas, asientos, la lista, versiones, límites, hosts en silencio |
| `lib/app.mjs` | HTTP (Express): chequeo de pedidos, rate limits, CORS, las rutas |
| `test/` | `npm test`: las reglas con un reloj falso, HTTP de punta a punta, y el relay aceptando estos tokens |
| `Dockerfile`, `fly.toml` | Para ponerlo en Fly (o en cualquier host con Docker) |

## 1. Probalo en tu PC

```bash
npm install
node keys.mjs                    # imprime ISSUER_PRIVATE_KEY='…' y RELAY_TOKEN_KEYS='…'
```

Terminal 1, el relay (`addons/mp_kit/relay`), con la clave pública:

```bash
RELAY_TOKEN_KEYS='{"keys":[…]}' RELAY_HOST_SECRET=prueba-local PORT=8080 node server.mjs
```

Terminal 2, el emisor, con la clave privada:

```bash
ISSUER_PRIVATE_KEY='{…}' ISSUER_RELAY_URL=ws://127.0.0.1:8080 \
  ISSUER_GAMES='{"mi-juego":{"max_players":8}}' PORT=8090 node server.mjs
```

El juego: `issuer_url = http://127.0.0.1:8090` y `game_id = mi-juego` en su `MpNetConfig` (o `--issuer-url=… --issuer-game=…`). Todo el camino lo prueba `bash mpkit_lab/run/online.sh` en el repo del kit.

## 2. Ponerlo en Fly

1. `fly auth login`. Copiá esta carpeta (o desplegá desde acá).
2. En `fly.toml`: `app` (un nombre tuyo, global en Fly), `primary_region`, y en `[env]`: `ISSUER_RELAY_URL` (el `wss://` de tu relay), `ISSUER_GAMES`, `ISSUER_ORIGINS` (desde dónde se sirve la versión web).
3. `node keys.mjs` una vez. Sus dos líneas, fuera del repo.
4. `fly apps create <tu-app>`, y la clave privada por stdin (nunca en una línea de comandos, nunca en un archivo del repo):
   ```bash
   printf 'ISSUER_PRIVATE_KEY=%s\n' '<el JSON que imprimió keys.mjs>' | fly secrets import --app <tu-app>
   ```
5. En el **relay**, la clave pública: `fly secrets set --app <tu-relay> RELAY_TOKEN_KEYS='<el JSON que imprimió keys.mjs>'` (es pública, también serviría una variable), y redesplegá el relay.
6. `fly deploy --ha=false` acá: una máquina, siempre prendida (las salas viven en su memoria). `https://<tu-app>.fly.dev/health` responde `ok`.

Costo: la máquina más chica (256 MB) y muy poco tráfico: las partidas pasan por el relay, no por acá.

**Rotar la clave**: hacé un par nuevo; poné las dos claves públicas en `RELAY_TOKEN_KEYS` (`{"keys":[vieja, nueva]}`), pasá el emisor a la clave privada nueva, y sacá la pública vieja un minuto después (ningún token vive más).

## 3. Configuración

| Variable | Por defecto | Qué es |
|---|---|---|
| `ISSUER_PRIVATE_KEY` | (obligatoria) | El JWK privado Ed25519 con su `kid`, de `keys.mjs`. Es un secreto |
| `ISSUER_RELAY_URL` | (obligatoria) | La dirección `wss://` del relay: el emisor le dice a cada jugador adónde conectarse |
| `ISSUER_GAMES` | (obligatoria) | `{"<game_id>": {"min_version": "1.0.0", "max_players": 8, "max_rooms": 500}}`. Solo estos juegos tienen salas |
| `ISSUER_ORIGINS` | ninguno | Orígenes web que pueden llamarlo desde un navegador (`https://mi-juego.itch.io`, separados por comas; `*` cualquiera). Los builds de escritorio no necesitan nada |
| `ISSUER_TRUST_PROXY` | `none` | De dónde sale la IP del jugador: `fly` (el header `Fly-Client-IP`), `proxy` (el primer salto de `X-Forwarded-For`) o `none` (la conexión) |
| `PORT` | `8090` | Puerto HTTP |
| `ISSUER_TOKEN_TTL_S` | `60` | Cuánto puede esperar un token del relay antes de usarse (cada uno sirve una vez) |
| `ISSUER_HEARTBEAT_S` | `10` | Cada cuánto dice un host que está vivo |
| `ISSUER_ROOM_SILENT_S` | `30` | Una sala cuyo host calla ese tiempo desaparece (una pestaña cerrada no puede despedirse) |
| `ISSUER_ROOM_START_S` | `120` | Una sala nueva tiene ese tiempo para aparecer en el relay |
| `ISSUER_ROOM_MAX_S` | `21600` | Lo más que vive una sala (6 h) |
| `ISSUER_ROOMS_PER_IP` / `ISSUER_ROOMS_PER_INSTALL` | `3` / `1` | Salas vivas que puede hospedar una IP / una instalación |
| `ISSUER_RATE_CREATE` / `_JOIN` / `_LIST` / `_HOST` | `10` / `30` / `60` / `60` | Pedidos por IP y minuto en cada tipo de ruta |
| `ISSUER_BANNED` | ninguno | IPs e ids de instalación rechazados, separados por comas |
| `ISSUER_QUIET` | | `1`: sin líneas de log |

El emisor no arranca sin la clave, la URL del relay o un juego: nunca corre abierto por error.

## 4. API (v1)

Todo pedido de un jugador dice quién pregunta: `game`, `version` (la del juego), `kit` (la de MpKit), `platform`, `install` (al azar, la guarda el juego) y `session` (nueva en cada proceso, así dos copias del juego en una PC tienen dos asientos). La IP sale de la conexión, nunca del cuerpo. Las respuestas son JSON; un rechazo es `{"error": "<palabra>", …}`.

| Ruta | Quién | Qué |
|---|---|---|
| `POST /v1/rooms` | host | Cuerpo: quién + `name`, `max_players`, `visibility` (`public`/`private`), `mode` (`dedicated`: hospeda un proceso de partida, `seats` = un ticket de admisión por asiento menos el del host; `listen`: hospeda el juego del host, sin tickets). `201` → `code`, `room` (`p-<código>`), `relay_url`, `host_token`, `room_key` (la prueba del host, se muestra una vez), `heartbeat_s`, `token_ttl_s`, `max_players` |
| `PUT /v1/rooms/:code` | host (`Authorization: Bearer <room_key>`) | Heartbeat: `players` (el host cuenta), `state` (`open`/`playing`), `taken` (los tickets conectados). El primero deja la sala **viva**: antes no se lista y quien quiera entrar recibe `room_starting` |
| `POST /v1/rooms/:code/tokens` | host (Bearer) | `{"role": "host"|"client"}` → un token nuevo (un host que se reconecta; el jugador host de una sala dedicada) |
| `DELETE /v1/rooms/:code` | host (Bearer) | Cierra la sala |
| `GET /v1/rooms?<quién>` | jugador | `rooms`: las salas públicas vivas de ese juego y **versión** con lugar, las más nuevas primero |
| `POST /v1/rooms/:code/join` | jugador | Cuerpo: quién. → `room`, `relay_url`, `token`, `ticket` (dedicada: la partida lo admite; `null` en listen), `mode`, `max_players`. El mismo proceso que vuelve a pedir recibe el mismo asiento mientras esté reservado (2 × la vida del token) |
| `GET /health` | | `ok` |

Rechazos: `bad_request` (400, con los `fields`), `banned` (403), `no_such_room` / `unknown_game` (404), `room_full` / `version_mismatch` (con `host_version`) / `room_starting` (409), `version_too_old` (426, con `min_version`), `too_many_rooms` / `rate_limited` (429), `no_room_left` (503), `too_large` (413). `MpFlow.online_texts` convierte cada uno en una frase para el jugador.

## 5. Tokens (el contrato con el relay)

Un JWT firmado con EdDSA (Ed25519), header `kid` = el id de la clave.

| Claim | Valor |
|---|---|
| `iss` / `aud` | `mpkit-issuer` / `mpkit-relay` |
| `room` | `p-<código>`: el relay pide token para estas salas, y solo para estas |
| `role` | `host` o `client`: un token sirve solo para ese rol |
| `max` | tokens de host: cuántos clientes deja entrar el relay (un host listen juega, así que `max_players - 1`) |
| `sub` | el id de instalación que lo pidió |
| `jti`, `iat`, `nbf`, `exp` | id único, emitido, no antes de, vencimiento (`ISSUER_TOKEN_TTL_S`) |

El relay chequea la firma con la clave pública, `iss`, `aud`, `exp`, que `room` y `role` sean los de la conexión, y gasta el `jti` cuando el peer queda sentado (un host rechazado porque su sala está ocupada conserva el token para reintentar). Un token va en `?token=` (un navegador no puede poner headers) o en el header `X-Relay-Token`; sirve una vez y muere en un minuto, así que una URL en un log no le sirve a nadie.

## 6. Lo que no hace

- Nunca pasa tráfico del juego: eso es del relay. Nunca ve inputs ni estados.
- Guarda las salas en memoria: una máquina (un reinicio olvida las salas; sus partidas siguen, sin listar). Varias máquinas necesitarían un almacén compartido (Redis) para las salas y los rate limits.
- No evita que un host haga trampa: el juego del host es la autoridad de su partida. Los juegos competitivos entre desconocidos quieren un servidor dedicado (GUIDE 13).
- Un host en el navegador de un celular se congela cuando el navegador pasa a segundo plano (los navegadores de celular frenan del todo las pestañas ocultas); sus jugadores ven "Waiting for the host…" (`MpKit.host_silent`) y se rinden tras `MpFlow.host_silent_timeout_s`.
