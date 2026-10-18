# AgentKit

CLI para agentes (y humanos) sobre un proyecto Godot 4: captura, flows de clic, HTTP, inspect, diff de PNG. **Cero gameplay.**

No es un MCP. El agente corre el binario de Godot. Las skills `godot-agent-kit` y `godot-playtest` dicen cuándo.

## Por qué existe

`godot -s /tmp` + `extends SceneTree` rompe autoloads: los `class_name` del juego se compilan **antes**. El autoload AgentKit captura desde el proyecto y **sobrevive** `change_scene`.

## Instalar

```bash
./install.sh --addon /path/to/godot-project
```

Habilitá el plugin **AgentKit**. CI/headless:

```
AgentKit="*res://addons/agent_kit/agent_kit.gd"
```

Sin `--agent=`, F5 no cambia.

Workspace del **juego**: `res://agent/` (lo crea `install.sh`). **Todo** lo que el agente cree para AgentKit (JSON, harness, fixtures `.tscn`, PNG) va ahí. Cero escenas de test en `scenes/`. Contrato: `skills/godot-agent-kit/harness.md`. El instalador copia `.cursor/rules/agent-kit-workspace.mdc`.

## CLI

```bash
addons/agent_kit/cli.sh /path/to/godot-project VERB [flags]
```

| Verb | Ventana | Qué hace |
|------|---------|----------|
| `info` | headless OK | versión, main scene, viewport |
| `capture` | **sí** | PNG (`--scene=`, `--wait=`, `--out=`) |
| `flow` | **sí** | JSON (`--flow=`, `--out=` dir) |
| `fetch` | headless OK | HTTP (`--url=`, `--out=`, `--ua=`) |
| `inspect` | headless OK | árbol o `%UniqueName` |
| `diff` | headless OK | dos PNG (`--a=`, `--b=`, `--out=`, `--threshold=`) |

Líneas para grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_CLICK`, `AGENT_PRESS`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `AGENT_SKIP`, `AGENT_REPEAT`, `AGENT_DIFF`, `AGENT_JSON`, `AGENT_CALL`.

## Flow JSON

```json
{
  "scene": "res://scenes/ui/boot.tscn",
  "wait_first": 0.8,
  "steps": [
    { "shot": "01.png" },
    { "click": "%PlaySolo" },
    { "press": "ui_accept" },
    { "wait": 0.4 },
    { "assert": { "node": "%AfterPlay", "visible": true } },
    { "print": { "node": "%Status", "prop": "text" } }
  ]
}
```

`click` pone el puntero en el centro del control y falla si no dispara `pressed`. `%Nombre` se busca en la escena y en hijos. `press` solo acepta una acción que **ya** está en el InputMap; si no existe, falla con `unmapped input`. `call` sobre un nodo del producto, `seed` y `time_scale` fallan. `--fail-on-error` falla si el engine logueó ERROR / SCRIPT ERROR. `--flow=boot_smoke.json` busca en `res://agent/flows/`. `--out=` default: `res://agent/out`.

El harness no mueve actores. AgentKit lo monta **solo** con `--agent=`. F5 de un jugador no lo carga.

UI que aparece y desaparece:

```json
{
  "try_click": "%PlaySolo",
  "repeat": {
    "times": 80,
    "until": { "node": "%AfterPlay", "visible": true },
    "steps": [
      { "try_click": "%PlaySolo" },
      { "wait": 0.2 }
    ]
  }
}
```

`try_click` no falla si el nodo falta, está `disabled` o no está visible (`AGENT_SKIP`). Detalle de steps: `skills/godot-agent-kit/flows.md`. Demo: `example/agent/flows/`.

Editor experimental: `experimental/agent-flow-editor/` (Vite, **pnpm**). No entra en `./install.sh`.

## Qué no es

No es un runner de tests unitarios. No es un MCP. No es un motor de juego. El playtest no pide OK: solo escribe en `res://agent/` y no cambia reglas de negocio.

## Cola de Godot (`determinism/harness/`)

`godot_run.sh <comando godot...>` corre UN Godot bajo un esquema de turnos por máquina, para que varios agentes no se pisen. Genérico: sin nada de ningún juego.

- **headless** (`--headless`, sin `--import`): hasta `HEADLESS_SLOTS` a la vez (3). Se ve en stderr como `headless (<ns>_godot.slot0)`.
- **ventana**: una a la vez, con tope de `GODOT_WINDOW_MAX_S` (600 s; 0 = sin tope). Se cuenta como carga: su tiempo es informativo.
- **`--import`**: exclusivo; espera a que no haya otro Godot (`godot_busy.sh`) y nada arranca mientras lo tiene (`import exclusivo` en stderr).
- Turnos FIFO (tickets en `/tmp/<ns>_godot.queue`), tope global `GODOT_MAX` (4), locks que se limpian si muere el dueño. Nunca `pkill` por patrón.
- **Preflight**: si un `class_name` de los `.gd` no está en `.godot/global_script_class_cache.cfg`, hace `--import` x2 antes (`clases sin importar`). `GODOT_RUN_NO_PREFLIGHT=1` lo apaga.

Variables: `GODOT_RUN_NS` (espacio de nombres de los locks, `/tmp/<NS>_godot.*`, default `agentkit`; todos los que comparten máquina usan el mismo), `GODOT_BIN` (binario para el preflight), `HEADLESS_SLOTS`, `GODOT_MAX`, `GODOT_WINDOW_MAX_S`, `GODOT_BUSY_SCRIPT`.

Un proyecto lo usa con un shim fino: `GODOT_RUN_NS=mijuego GODOT_BIN=... exec bash addons/agent_kit/determinism/harness/godot_run.sh "$@"`.

Autoprueba sin Godot (comandos falsos `bash -c 'sleep N' --headless`; ~20 s, namespace propio): `bash addons/agent_kit/determinism/harness/selftest_queue.sh` → 4 × `PASS`.

## Determinismo (`determinism/`)

Mide que una misma corrida da el mismo resultado con relojes distintos. Genérico: sin nada de ningún juego.

**En la escena del juego**
- `DetRecorder` (Node, `class_name`): registro de líneas `"<tick> <tipo> <texto>"` con sha256 en orden. `@export keep_lines` (guarda las líneas, hace falta para `--events`), `@export self_tick` (true: cuenta ticks en su `_physics_process`; false: el dueño llama `advance()` y el orden de física no cambia), `@export position_decimals` (1). Métodos: `start()`, `stop()`, `advance()`, `record(kind, text)`, `sample(bodies)` (posiciones ordenadas por nombre), `digest()` (una vez; las llamadas siguientes repiten el valor), `write_outputs(report)` (agrega `digest`, `events`, `end_tick` y escribe `--out`/`--events`). Señal `finished(digest)`. `tick` y `line_count` son legibles.
- `DetCli` (estático): `args()` (`--k=v` y `--flag` de `OS.get_cmdline_user_args()`), `out_path()`, `events_path()`, `absolute(path)`.
- Nada de tiempo de pared en las líneas. Si el juego tiene un reloj propio, el dueño lo mueve con `advance()`.

**Corredor**
`bash addons/agent_kit/determinism/det_run.sh <casos.txt> CASO|all|quick|table|bless [MODO...] [--no-window]`
- `casos.txt`: una línea `nombre|args|quick|set` (`quick`: `all` = todos los modos, `fixed` = solo referencia, vacío = fuera de quick; `set`: `all` = entra en `all`).
- `det.cfg` junto al archivo de casos (shell): `DET_SCENE` (obligatorio), `DET_PROJECT`, `DET_OUT`, `DET_BASELINE` (líneas `caso digest`), `DET_RSS_LIMIT_KB`, `DET_LIMIT_FIXED|STRESS|WINDOW`, `DET_STRESS_FPS`, `DET_WINDOW_RES`, `DET_WINDOW_ARGS`, `GODOT_BIN`, `GODOT_RUN_NS`.
- Modos: `fixed` (referencia), `fixed2` (repetición), `stress` (headless con `--max-fps` bajo), `window` (nunca dos ventanas a la vez).
- Salidas por caso y modo en `DET_OUT`: `.json`, `.events`, `.log`, `.meta` (`wall_s`, `rss_max_kb`, `contaminated`, `watchdog`). Un `watchdog` distinto de `none` o `CONTAMINATED` hace fallar el veredicto.
- Watchdog: RSS, tiempo, y **corte inmediato** (`script_error_kill`) si el log trae `Parse Error`, `Compile Error` o `Failed to load script`.
- `quick` borra los resultados viejos de sus casos, compara el digest de `fixed` con la base (`baseline X OK|FAIL`) y exige al menos 2 modos frescos: `QUICK PASS` / `QUICK FAIL`. `bless` escribe la base desde los `fixed` actuales.
- Tabla y veredicto: `det_report.py` (`DETERMINISM PASS|FAIL`; columnas `case, mode, sha256, end_tick, lines, vs fixed, wall (s), RSS max (MB), warnings, first different line`).

**Autoprueba** (escena propia con 20 cuerpos y semilla): `perl -e 'alarm 900; exec @ARGV' bash addons/agent_kit/determinism/det_selftest.sh` -> `SELFTEST PASS`.

## Versión

0.1.5
