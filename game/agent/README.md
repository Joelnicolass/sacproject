# agent/

Banco y playtest (AgentKit), todo de desarrollo.
- `runs/`: los `run_*.sh` (ver `runs/run_034e.sh`, el e2e de red). `ROOT` se calcula con `dirname "$0")/../..`.
- `flows/`: los flows `.json` de playtest. `fixtures/`: escenas y datos de apoyo por flow.
- `harness/`: helpers de Godot para el banco (incluye `godot_run.sh`, la cola global de Godot). `perf/`, `editor/`: sondas.
- `scripts/` y `tools/`: generadores de flows y comparadores en Python.
- `run_determinism.sh`, `det.cfg`, `det_cases.txt`, `det_baseline.txt`: banco de determinismo (`quick`, `all`).
- `out/`: salidas, historia; no se reescribe.

Agregar uno: un run nuevo va en `runs/`, un flow en `flows/`. Los helpers de playtest viven aca, nunca en `scenes/`.
