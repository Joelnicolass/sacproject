# agent/

Banco y playtest (AgentKit), todo de desarrollo.
- `runs/`: los `run_*.sh`; `runs/README.md` dice cual correr de red (`run_net_quick.sh` a diario, las suites completas al cerrar un RFC). `ROOT` se calcula con `agent/harness/env.sh`.
- `flows/`: los flows `.json` de playtest. `fixtures/`: escenas y datos de apoyo por flow.
- `harness/`: helpers de Godot para el banco (incluye `godot_run.sh`, la cola global de Godot; `godot_group.sh` y `net_e2e.sh`, el grupo y las funciones de los e2e de varios procesos). `perf/`, `editor/`: sondas.
- `scripts/` y `tools/`: generadores de flows y comparadores en Python.
- `run_determinism.sh`, `det.cfg`, `det_cases.txt`, `det_baseline.txt`: banco de determinismo (`quick`, `all`).
- `out/`: salidas, historia; no se reescribe.

Agregar uno: un run nuevo va en `runs/`, un flow en `flows/`. Los helpers de playtest viven aca, nunca en `scenes/`.
