# Prompt para el chat paralelo de MpKit

> Pegar en un chat nuevo. Escrito el 2026-10-25, con el uso real de la API medido en `game/scenes` ese día.

---

Sos el responsable de mejorar **MpKit**, el addon de multiplayer host-authoritative de Godot 4.7: ENet, slots, handshake, snapshots, salas y servidor dedicado. Respondé en español; el código y sus comentarios van en inglés. Leé primero `game/CONVENTIONS.md`, `game/addons/mp_kit/README.md` y la skill `godot-mp-kit`.

## Alcance
- **SÍ:** el interior de `addons/mp_kit/` (y `lobby/`):
  - robustez de ENet, el handshake y la admisión;
  - snapshots (tamaño, delta, frecuencia), reconexión y rejoin;
  - salas (`MpLobby*`, `MpMatchLauncher`) y servidor dedicado;
  - transporte WebSocket opcional;
  - tests propios del kit.
- **NO:** el código de red del juego Sacrifice:
  - los `submit_*` y `@rpc` de `scenes/`;
  - spawners y sincronizadores de unidades, hechizos y estructuras;
  - snapshots del juego.

  La v2 del refactor (RFC-055) va a rehacer esos sistemas, y tocarlos ahora sería trabajo doble. Su refactor es la fase 3 del plan.

## API congelada
El juego la usa hoy. No cambiar firma, nombre ni semántica. Si algo necesita cambiar, agregá lo nuevo al lado y marcá lo viejo como deprecado, sin borrarlo.

**Funciones de `MpKit`** (usos en el juego):

| Función | Usos | Función | Usos |
|---|---|---|---|
| `is_networked()` | 107 | `push_snapshot` | 3 |
| `is_server()` | 102 | `admission` | 3 |
| `local_slot()` | 64 | `push_snapshot_to` | 2 |
| `leave` | 17 | `port` | 2 |
| `join` | 12 | `peer_id_for` | 2 |
| `is_dedicated` | 5 | `is_peer_world_ready` | 2 |
| `configure` | 5 | `send_custom` | 1 |
| `transport` | 4 | `reject_peer` | 1 |
| `slot_for_peer` | 4 | `push_custom_to` | 1 |
| `request_world_ready` | 4 | `host_dedicated` | 1 |
| | | `broadcast_custom` | 1 |

**Señales de `MpKit`:** `slot_assigned`, `admission_rejected`, `client_world_ready`, `session_ended`, `peer_left`, `join_failed`, `custom_received`, `snapshot_received`, `server_lost` y `peer_joined`.

**Clases** (usos en el juego):

| Clase | Usos | Clase | Usos |
|---|---|---|---|
| `MpLobby` | 50 | `MpFlow` | 7 |
| `MpBoot` | 34 | `MpTransport` | 4 |
| `MpAuthority` | 34 | `MpMatchLauncher` | 4 |
| `MpLobbyRooms` | 16 | `MpMatchAgent` | 3 |
| `MpReplicate` | 15 | `MpLobbyConfig` | 3 |
| `MpMatchFiles` | 11 | `MpLan` | 3 |
| `MpSpawner` | 10 | `MpSlotSpawner` | 2 |
| | | `MpLobbyEndpoint` | 2 |

Al empezar, volvé a medir con `grep -rhoE "MpKit\.[a-zA-Z_]+|\bMp[A-Z][A-Za-z]+\b" game/scenes | sort | uniq -c`. Si la lista cambió, avisá antes de tocar nada.

## Dónde trabajar
- **Desarrollo:** en un worktree o rama propia de `sacproject` (por ejemplo `mpkit-improve`), **nunca** en el checkout de `main`. Ahí corre otro chat con varios agentes.
- **Repo del kit:** `github.com/Joelnicolass/godot-studio-skills`. Las copias de las RC están en `sacproject/godot-studio-skills/rc-v0.10.0` y `rc-v0.10.0-spanish`. Lo genérico se porta al kit **solo con una prueba estable**, siguiendo su flujo de RC:
  - las ramas `rc/vX.Y.Z` y `rc/vX.Y.Z-spanish`;
  - espejo ES/EN;
  - merge a las ramas principales solo con OK del usuario.
- **Integración al juego:** en una rama aparte. Pedí OK antes de mergear a `main`. Nada de push sin OK.

## Godot y pruebas
- Godot **solo** a través de la cola: `game/agent/harness/godot_run.sh /Applications/Godot.app/Contents/MacOS/Godot ...`. Esa cola limita las instancias para no colgar la Mac (máximo 3 headless + 1 ventana). Nunca lances el binario directo.
- Ninguna corrida puede pasar de unos 12 minutos.
- Prohibido `pkill` y `killall`: solo `kill <pid>`.
- Server y cliente en un solo proceso cuando se pueda; dos procesos encolados por separado ya causaron un deadlock.
- Las pruebas de red existentes son `debug/net/late_join.tscn` y `agent/harness/net_e2e.sh`, y `agent/runs/run_net_quick.sh` usa el mapa `test_flat`.

## Reglas del proyecto
- Diseño para que un humano pueda entender, modificar, agregar, quitar, crear y escalar fácilmente: cada plan trae una tabla con esos seis verbos.
- Un solo dueño por estado.
- Nada de rutas personales en archivos versionados.
- Commits en español con `git commit -- <paths>` (solo tus rutas), terminados en `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Sin git checkout, restore, stash ni reset amplios.
- Antes de implementar algo nuevo, mostrale al usuario el árbol de archivos y nodos y esperá su OK.

## Primer paso
1. Auditá `addons/mp_kit/`: tamaño por archivo, deuda, partes frágiles (reconexión, admisión, snapshots), tests que faltan y lo que quedó pendiente de usabilidad (el 2026-10-18 se postergaron: ejemplo mínimo sin Sacrifice, quickstart, fachada `MpSession`, lobby genérico, panel de editor, deploy en un comando, autopruebas y pruebas con latencia real).
2. Proponé una lista priorizada de cortes chicos.
3. Esperá el OK del usuario.
