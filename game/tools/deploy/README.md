# Despliegue del servidor de salas (RFC-034, corte 034g)

Estos archivos están **escritos y revisados, no desplegados**. La prueba real en el VPS (Vultr) la hacés vos; en la Mac se verificó todo en `127.0.0.1` (`agent/run_034g.sh`, `run_034e.sh`, `run_034m.sh`).

## Qué corre en el VPS

Un solo binario exportado, que hace dos trabajos:

| Proceso | Cómo arranca | Quién lo lanza |
|---|---|---|
| **Servidor de salas** (lobby, salas, chat, lanzador) | `sacrifice_server.x86_64 --headless -- --room-server` | systemd (`room_server.service`) |
| **Partida** (un dedicado por sala) | `... --headless -- --dedicated --mp-port=N --match-ticket-file=… --room-pid=…` | el servidor de salas, solo |

Los dedicados **no** se configuran: el servidor de salas los lanza con un ticket, les da un puerto del rango, los vigila (latido) y los mata si el servidor cae. Si el servidor de salas se detiene o muere, cada dedicado se cierra solo en 10 s o menos.

## 1. Exportar (en tu Mac)

1. Plantillas de exportación 4.7.2 instaladas (Editor → Administrar plantillas de exportación).
2. En `game/` ya está `export_presets.cfg` con el preset **`dedicated_server`** (Linux x86_64, `embed_pck=false`). Exportá sin ventana:

   ```bash
   cd game
   mkdir -p build/dedicated
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release dedicated_server build/dedicated/sacrifice_server.x86_64
   ```

3. Salen dos archivos que van juntos: `sacrifice_server.x86_64` y `sacrifice_server.pck`.

Notas del preset:

- Es el export **normal** de Linux (`dedicated_server=false`, no el modo «Dedicated Server» que recorta recursos): el mismo binario es el servidor de salas y cada partida, y la partida necesita el mundo completo (terreno, colisiones, navegación). El modo recortado, además, pone la etiqueta `dedicated_server`, que haría que el servidor de salas abriera también un puerto de partida. Si más adelante querés achicar el build, probalo aparte y con una partida entera.
- Excluye `agent/`, `visual/`, `reviews/`, `rfcs/`, `docs/`, `changes/` y `tools/`: nada de eso lo usa el juego.
- **El export no se probó** (en la Mac solo se escribió el preset): es lo primero a verificar. Si falla por un recurso excluido, sacalo de `exclude_filter`.

## 2. Instalar en el VPS

Requisitos: Linux x86_64 (Ubuntu/Debian), systemd. El juego en modo headless no pide GPU ni librerías gráficas.

```bash
sudo useradd --system --home /var/lib/sacrifice --shell /usr/sbin/nologin sacrifice
sudo mkdir -p /opt/sacrifice /var/lib/sacrifice
sudo chown sacrifice:sacrifice /var/lib/sacrifice
# desde tu Mac:
scp build/dedicated/sacrifice_server.x86_64 build/dedicated/sacrifice_server.pck tools/deploy/room_server.service usuario@IP_DEL_VPS:/tmp/
# en el VPS:
sudo mv /tmp/sacrifice_server.* /opt/sacrifice/
sudo chmod +x /opt/sacrifice/sacrifice_server.x86_64
sudo cp /tmp/room_server.service /etc/systemd/system/sacrifice-rooms.service
sudo systemctl daemon-reload
sudo systemctl enable --now sacrifice-rooms
journalctl -u sacrifice-rooms -f      # debe decir: «salas listo puerto 7700»
```

## 3. Puertos y firewall

| Puerto | Protocolo | Para qué |
|---|---|---|
| **7700** | **UDP** (ENet, por defecto) o **TCP** (con `--transport=ws`) | el lobby: lista de salas, chat, asientos |
| **7800-7831** | el mismo protocolo | una partida por puerto (`data/net/lobby_config.tres`: 4 partidas a la vez) |

- Abrí los dos en el firewall del VPS **y** en el panel de Vultr (Firewall Group). El rango de partidas se puede achicar con `--match-port-max` / `--max-matches`.
- ufw: `sudo ufw allow 7700/udp && sudo ufw allow 7800:7831/udp` (con `ws`, cambiá `udp` por `tcp`).
- El cliente entra a la partida por **la misma IP** que usó para el lobby, salvo que fijes `public_host` en `MpLobbyConfig` (`--public-host=`).
- El servidor del lobby que usan los jugadores sale de `data/net/lobby_endpoint.tres` (hoy `127.0.0.1:7700`): **antes de exportar el cliente**, poné ahí la IP o el dominio del VPS, o abrí el juego con `--lobby=IP:7700` para probar.
- `wss://` (TLS) no está: para navegador hace falta un proxy inverso que termine TLS. No es parte de este corte.

## 4. Reconexión (lo que se probó en local)

- **Lobby:** si el cliente pierde la conexión con las salas (también durante una partida), vuelve solo con su ficha y recupera el **mismo asiento** si lo hace dentro de `resume_grace_s` (120 s por defecto; `--resume-grace-s=`). El cliente reintenta cada 2 s durante esa ventana (`auto_resume`).
- **Partida:** quien sale de su partida puede volver con **el mismo ticket** dentro de `rejoin_grace_s` (60 s por defecto; `--rejoin-grace-s=`) y recupera **el mismo slot**. Mientras está fuera, su mago se **queda quieto** donde estaba (sin tecla apretada ni orden de caminar), con su vida, sus criaturas y su altar; la partida sigue para el rival. Pasada la ventana pierde por abandono (`reason: abandon`) y el ticket ya no sirve.
- Un tercer cliente que use el ticket de un jugador que sigue conectado es **rechazado** (`admission_rejected`). Con la partida llena (dos conectados) ni siquiera llega a la admisión: ENet no acepta más conexiones que jugadores.
- En la sala, el botón **«Volver a la partida»** aparece si el jugador salió de la partida y la sala sigue «En partida».
- No probado en local (necesita ventana): que el cliente que vuelve vea su mundo y su mago ya en marcha. Es parte de tu prueba del VPS (checklist).

## 5. Checklist para tu prueba en el VPS

- [ ] El export de Linux sale sin error y pesa lo esperable (cientos de MB por los assets originales).
- [ ] `journalctl -u sacrifice-rooms` muestra `salas listo puerto 7700` y nada en rojo.
- [ ] `ss -lunp | grep 7700` (UDP) o `ss -ltnp | grep 7700` (ws) muestra el servidor escuchando.
- [ ] Desde tu Mac: el juego con `-- --lobby=IP_DEL_VPS:7700` → «Jugar en línea» → «Conectar» sin error de tiempo.
- [ ] Dos jugadores (dos PCs o dos instancias) crean/entran a una sala, eligen mago y dios, «Listo»; la cuenta regresiva termina y los dos entran a la partida. En el VPS: `ps aux | grep match-ticket-file` muestra un dedicado por partida.
- [ ] Un jugador cierra el juego en plena partida, lo reabre, vuelve a conectarse a las salas y usa «Volver a la partida» antes de 60 s: mismo lugar, mismo mago (quieto mientras estuvo fuera) y sus criaturas.
- [ ] Un jugador corta el Wi-Fi 20 s en el lobby: al volver conserva su asiento (mensaje «Volviendo a las salas…»).
- [ ] Pasado `rejoin_grace_s` fuera de la partida, el rival gana por abandono y la sala muestra el resultado.
- [ ] Al terminar una partida: `ps aux | grep match-ticket-file` sin procesos sueltos y los puertos libres (`ss -lunp | grep 78`).
- [ ] `sudo systemctl restart sacrifice-rooms` con una partida en curso: la partida se cierra en ≤ 10 s y no queda ningún proceso `match-ticket-file`.
- [ ] Tras un reinicio del VPS el servicio vuelve solo (`systemctl is-enabled sacrifice-rooms`).

## 6. Qué mirar si algo falla

| Síntoma | Causa probable |
|---|---|
| El cliente dice «Las salas no respondieron a tiempo» | Puerto 7700 cerrado (firewall del VPS **o** del panel de Vultr), o `--transport` distinto entre cliente y servidor |
| La sala llega a «Preparando la partida…» y vuelve a «Abierta» con `spawn_failed` | El binario no se puede lanzar a sí mismo (permisos de `/opt/sacrifice`) o falta el `.pck` al lado. El log de cada partida es `mp_matches/<partida>/log.txt` bajo `/var/lib/sacrifice/.local/share/godot/app_userdata/Sacrifice/` |
| Los jugadores entran a la sala pero la partida no conecta | Rango 7800-7831 cerrado |
| «Volver a la partida» responde «La partida terminó con un error» | Pasó `rejoin_grace_s` o la partida ya terminó |
