# agent/runs/

Los `run_*.sh` del banco. Se corren con `bash agent/runs/run_X.sh` (no hace falta `chmod`). Todos dependen de `--import` hecho una vez (clases nuevas).

## Red: cual correr

| Cuando | Script | Dura | Que cubre |
|---|---|---|---|
| **Todos los dias** (cada cambio de red, lobby, sala o dedicated) | `run_net_quick.sh` | ~5 s | servidor de salas + 2 clientes que cargan el mundo de verdad, sala con mapa, ticket -> dedicated -> ambos cargan, derrota forzada a los pocos ticks -> el resultado llega a la sala, sala con mundo invalido rechazada (`bad_options`), sin procesos huerfanos. `TRANSPORT=ws` para WebSocket. |
| **Al cerrar un RFC de red** (la suite completa) | `run_034d.sh` | ~10 s | protocolo del lobby (stub, 4 clientes, 2 salas en paralelo) |
| | `run_034e.sh` | ~14 s | dos partidas reales en paralelo, tickets cruzados, abandono, aislamiento de resultados |
| | `run_034g.sh` | ~20 s | reconexion: lobby (resume/auto_resume), vuelta al mismo slot, intruso, vuelta tarde rechazada |
| | `run_034m.sh` | ~15 s | «Servidor local»: el host lanza su dedicated, rival con codigo, intruso rechazado |
| | `run_049a.sh` | ~6 s | mapa elegido por la sala (como quick, mas `bad_ticket` de un dedicated a mano) |
| | `run_049e.sh` | ~8 s | dedicated a mano 2v2 con 3 IA, tercer humano afuera, «Contra la IA» con modo |
| | `run_049g.sh` | ~21 s | 2v2 de punta a punta: cuatro humanos (rejoin, abandono de un lado) y dos humanos + dos bots |

Las duraciones son de pared en esta Mac (sin cola). Los viejos tardaban 20-120 s.

## Como corren (F350)

- **Un grupo, no una cola por proceso.** Cada e2e de varios procesos empieza con `net_group N "$@"` (de `agent/harness/net_e2e.sh`): se vuelve a ejecutar dentro de `agent/harness/godot_group.sh N -- ...`, que saca **un** ticket de la cola FIFO de `godot_run.sh` (mismo namespace `/tmp/sacproject_godot.*`), espera a que no haya ningun ticket mas viejo (import, ventana, headless u otro grupo) y lo conserva hasta que termina. Nada puede arrancar en el medio (un import de otro worktree espera detras), asi que el servidor no se queda esperando clientes que no pueden arrancar. Dentro del grupo los Godot se lanzan **directo** (`gd` de `net_e2e.sh`), nunca con `godot_run.sh` (se encolarian detras de su propio grupo).
- **Topes propios**: vigilante de pared (`PROBE_LIMIT_S`), RSS total (`E2E_RSS_LIMIT_MB`, 8192) y numero de procesos Godot del proyecto (`PROC_MAX` de cada script). Si se pasan, matan por pid (nunca `pkill`).
- **Sin sleeps fijos**: las esperas son sobre lineas de log (`wait_line`, 0.1 s) o la muerte del proceso (`wait_gone`). Los plazos del servidor (cuenta regresiva, poll, heartbeat, gracia de reconexion, demora de cierre) son flags de `MpLobbyConfig` (`--countdown-s=0.2 --poll-s=0.1 --rejoin-grace-s=2 --result-quit-delay-s=0.5 ...`).
- **`--fixed-fps 600`** (`NET_FPS`) en los dedicated y clientes donde nada depende del orden en pared: `run_net_quick`, `run_049a`, `run_049e`, la fase B de `run_049g`. El dedicated de la sala lo recibe con `--match-engine-args=--fixed-fps,600` del servidor de salas. Los ticks por segundo simulado no cambian (60); solo se acorta la pared. Los e2e con **orden en pared** (`034e`, `034g`, `034m`, fase A de `049g`: quien entra antes de la derrota, la gracia de reconexion, el abandono) corren el dedicated en tiempo real con plazos cortos: acelerarlos haria depender el orden de cuantos ticks por segundo da la maquina.
- **Orden de los asientos por evento** (`049g`): un cliente entra a la sala cuando ya tiene N asientos ocupados (`--e2e-join-when-used`), no despues de N segundos.
- **Derrota forzada**: `--force-defeat-slot=N --force-defeat-after-ticks=T` (o `--force-defeat-when-file=PATH` en `034m`: cuando el intruso termina), en `--match-args`.

Un e2e nuevo de red: `. "$(dirname "$0")/../harness/net_e2e.sh"; net_group N "$@"`, y despues `gd`, `net_guard`, `wait_line`, `wait_gone`, `kill_pids` (ver `run_net_quick.sh` como plantilla). Para ver donde se va el tiempo: `NET_TS=1 bash agent/runs/run_net_quick.sh` prefija cada linea de log con los segundos desde el arranque.

## Otros

Los demas `run_*.sh` (`run_pt*`, `run_f*`, `run_022e4b`, ...) son pruebas de RFCs anteriores; siguen usando la cola por proceso (`agent/harness/godot_run.sh`). Si alguno levanta mas de un proceso que depende de otro, pasarlo a `net_group` como los de arriba.
