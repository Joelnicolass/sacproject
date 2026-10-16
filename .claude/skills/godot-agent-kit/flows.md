# Flows JSON

`--agent=flow --flow=res://agent/flows/boot_smoke.json --out=res://agent/out`

Nombre corto: `--flow=boot_smoke.json` (busca en `res://agent/flows/`).

```json
{
  "scene": "res://scenes/ui/boot.tscn",
  "wait_first": 0.8,
  "steps": [
    { "shot": "01.png" },
    { "click": "%PlaySolo" },
    { "wait": 0.4 },
    { "assert": { "node": "%AfterPlay", "visible": true } },
    { "print": { "node": "%Status", "prop": "text" } }
  ]
}
```

UI que aparece y desaparece:

```json
{
  "repeat": {
    "times": 180,
    "until": { "node": "%AfterPlay", "visible": true },
    "steps": [
      { "try_click": "%PlaySolo" },
      { "wait": 0.2 }
    ]
  }
}
```

`click` manda el puntero al centro del control y solo cuenta si dispara `pressed`. Si no pega, el step falla (`click missed`). `try_click` puede saltar solo dentro de un `repeat` con `until`, mientras el control no está listo. `press` manda un `InputEventAction` de la acción del InputMap (`parse_input_event`) para que `_unhandled_input` / `is_action_pressed` lo reciban, y mantiene el hold con `action_press` en cada frame de física. No manda keycodes. Si la acción no está mapeada, falla con `unmapped input`. `seed` y `time_scale` fallan: no son acciones del jugador. `call` sobre un nodo del producto falla.

`scene` vacío en la raíz = main scene. Un step `{ "scene": "res://…" }` cambia de escena. `%Nombre` se resuelve en la escena y, si falta, en hijos. `repeat` corre `steps` hasta `times` o hasta que `until` pase.

Otros steps: `{ "select": { "node": "%Rooms", "index": 0 } }` o `"text"`; `{ "range": { "node": "%Vol", "value": 0.5 } }`; `{ "scroll": { "node": "%List", "vertical": 80 } }`; `{ "drag": { "node": "%Pad", "from_x": 8, "from_y": 8, "to_x": 80, "to_y": 8 } }`; `{ "shot": { "name": "hud.png", "node": "%Status" } }` recorta un Control; `{ "diff": { "a": "01.png", "b": "02.png", "max_percent": 0 } }` compara PNGs del `--out=`.

`assert` / `wait_until` keys: `disabled`, `visible`, `visible_in_tree`, `text_contains`, `text_equals`, `texture_path_contains`. `visible_in_tree: false` también pasa si el nodo ya no está (por ejemplo `queue_free`). `wait_until` también acepta `contains` como alias de `text_contains`, o `{ "node": "%PlaySolo", "signal": "pressed", "timeout": 5 }`.

Cada step imprime `AGENT_STEP n kind`. Errores del engine: `AGENT_STEP_ERROR` y al final `AGENT_ERRORS […]`. `--fail-on-error` tumba el flow si hubo ERROR / SCRIPT ERROR.

`print.prop` admite puntos: `texture.resource_path`.

El autoload **sobrevive** `change_scene`. Un script `-s` no.

Editor visual experimental: `experimental/agent-flow-editor/` (cables → este JSON). Bind al proyecto Godot, pegá `%` / acciones, **Run flow** ejecuta AgentKit con `--fail-on-error`.
