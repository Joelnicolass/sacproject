# Desplegar un servidor MpKit en un VPS

Un solo binario de Linux hace todo: cliente, servidor de salas (`--room-server`) y cada partida (`--dedicated`, lo lanza el servidor de salas). En el VPS corre con systemd, y varias instancias son varias unidades.

## Lo que necesitás

- Un VPS Linux x86_64 con systemd (Ubuntu o Debian) y un usuario con `sudo` al que entrás por SSH.
- En tu PC: las plantillas de export de Linux de tu versión de Godot (Editor → Administrar plantillas de exportación).
- En el proyecto: `MpFlow` con `room_server_path` apuntando a tu escena con `MpRoomServer` (para el lobby) y un `MpNetConfig`.

## 1. Exportar

Copiá los presets de [export_presets.example.cfg](export_presets.example.cfg) a tu `export_presets.cfg` (o crealos en Proyecto → Exportar) y exportá:

```bash
godot --headless --path . --export-release "Linux Server" build/server/juego.x86_64
```

Salen `juego.x86_64` y `juego.pck`, que van juntos.

## 2. Subir e instalar (un comando)

```bash
addons/mp_kit/deploy/deploy.sh usuario@mi-vps build/server --rooms 7700 --open-firewall
```

Eso crea el usuario `juego`, copia el build a `/opt/juego`, instala las unidades y arranca `juego-rooms@7700` (lobby en 7700, partidas en 7800-7899). Correlo de nuevo para actualizar: copia lo nuevo y reinicia todo. Probalo primero con `--dry-run`, que solo imprime los comandos.

| Querés | Opción |
|---|---|
| Más servidores de salas en el mismo VPS | `--rooms 7700,7701,7702` (cada uno tiene 100 puertos de partida propios: 7800, 7900, 8000…) |
| Servidores dedicados sin lobby (entrar con IP y puerto) | `--dedicated 7777,7787` (sin `--rooms`, no instala salas; 7778-7781 los usa la búsqueda LAN) |
| Clientes web | `--transport ws` (el lobby y las partidas por TCP) |
| Que el script abra los puertos | `--open-firewall` (ufw: UDP con ENet, TCP con WebSocket) |
| Clientes web por https (`wss://`) | `--transport ws --tls-cert /etc/letsencrypt/live/DOMINIO/fullchain.pem --tls-key /etc/letsencrypt/live/DOMINIO/privkey.pem` |

Varias partidas a la vez en un servidor de salas es automático: cada sala llena lanza su proceso, hasta `max_matches` del `MpLobbyConfig` (o `--max-matches=N`). Cada número del `MpLobbyConfig` se pisa con un flag de su nombre; para una instancia, ponelo en `EXTRA_ARGS` de `/etc/juego/rooms-7700.env` y reiniciá.

## 3. Operar

```bash
ssh usuario@mi-vps journalctl -u 'juego-rooms@*' -f      # logs en vivo: salas, partidas, resultados
ssh usuario@mi-vps sudo systemctl restart juego-rooms@7700
ssh usuario@mi-vps sudo systemctl disable --now juego-rooms@7701
```

Si el servidor de salas se cae, systemd lo levanta y sus partidas se cierran solas en pocos segundos (`parent_check_s`). Un jugador que se cae vuelve a su asiento dentro de `rejoin_grace_s`.

## Web por https

Una página servida por `https` solo abre `wss://`. En el servidor, `deploy.sh … --transport ws --tls-cert … --tls-key …` (o `tls_certificate_path` / `tls_key_path` en el `MpLobbyConfig`, o los flags `--tls-certificate-path=` y `--tls-key-path=`): el lobby y cada partida usan ese certificado. En el cliente, `MpNetConfig.tls_client` encendido y la dirección del dominio del certificado (`juego.ejemplo.com:7700`). El usuario del servicio tiene que poder leer el certificado y la clave (con Let's Encrypt, por ejemplo, un grupo con permiso sobre `/etc/letsencrypt/live` y `archive`).

## Relay (sin puertos abiertos)

Con `transport = relay` el servidor se conecta hacia afuera al relay: el VPS no abre ningún puerto (`--open-firewall` no abre nada). El secreto sale de `MPKIT_RELAY_SECRET` en **tu** máquina y queda en `/etc/NOMBRE/relay.env`, que solo lee el usuario del servicio; un redeploy sin la variable no lo toca.

```bash
MPKIT_RELAY_SECRET=la-clave addons/mp_kit/deploy/deploy.sh usuario@vps build/server --rooms 7700 \
  --transport relay --relay-url wss://tu-relay.up.railway.app
```

`--relay-room NOMBRE` cambia el prefijo de las salas del relay si no querés el del juego. Cómo subir el relay: [../relay/README.md](../relay/README.md).

## Sin VPS: Fly.io

El mismo servidor en una máquina de Fly.io en la que nunca entrás: sin VPS, sin plantillas de export, sin puertos abiertos (se conecta hacia afuera al relay). Un comando desde la carpeta de tu proyecto:

```bash
MPKIT_RELAY_SECRET=<el secreto del relay> addons/mp_kit/deploy/fly.sh --app mi-servidor-de-juego --relay-url wss://mi-relay.fly.dev
```

Escribe `fly.toml` en tu proyecto (a partir de [fly/fly.toml](fly/fly.toml)), crea la app, guarda el secreto como secreto de Fly por stdin y despliega: Fly construye [fly/Dockerfile](fly/Dockerfile), que baja el Godot headless oficial de tu versión (verificado contra las sumas SHA-512 de la release), copia tu proyecto, lo importa una vez y corre `godot --headless --path /app -- --room-server …`. `--dedicated PUERTO` para un dedicado simple, `--region`, `--memory`, `--godot X.Y.Z`, `--dry-run`. El paso a paso completo (qué necesitás, verificar, actualizar, costo, comandos útiles, problemas): [GUIDE 13.6](../GUIDE.md#136-sin-vps-flyio).

Para probar todo en tu PC antes (Docker): el paso a paso con un relay local, el contenedor y dos ventanas está en [GUIDE 13.7](../GUIDE.md#137-tu-servidor-en-docker-en-tu-pc-de-punta-a-punta); en el repo del kit, `mpkit_lab/run/docker.sh` lo hace solo con el lab.

## Verificado y no verificado

Verificado en una Mac: varias instancias de `--room-server` lado a lado con sus rangos (e2e `run_mpkit_instances.sh` del laboratorio), salas, partidas privadas y web. No verificado: el export de Linux (faltan las plantillas en esa Mac) y un VPS real.

Verificado para Fly.io (`fly.sh`): la imagen en Docker en esa Mac (`mpkit_lab/run/docker.sh`: un dedicado y un servidor de salas, con sus partidas dentro del contenedor, jugados a través de un relay local), y un despliegue real en `gru` detrás de un relay en Fly: dos jugadores desde Argentina se encontraron en el lobby del servidor de salas, la partida arrancó en la máquina de Fly, la jugaron y volvieron al lobby con el resultado.
