# Cómo evaluar un playtest

No hace falta OK del usuario. El playtester **se valida solo** y sigue. Si el corte no se puede jugar como un humano, el informe es un bug, no un atajo.

## Límites (los chequeás vos)

Podés crear o editar solo dentro de `res://agent/`:

| Path | Para qué |
|------|----------|
| `flows/*.json` | El flujo que juega `res://debug/` o la escena del producto |
| `harness/*.gd` | Solo si el JSON no puede preparar nada. Sin `class_name`. Sin `call()` para armar el mundo |
| `out/` | PNG del CLI |

No toques reglas de negocio: `scenes/`, `src/`, `resources/`, `RULES.md`, `project.godot`, InputMap, scripts de actores. No agregues una acción al editor para que el flow pase. Al cierre: `git diff --name-only` solo bajo `agent/`.

## 1. Jugá la escena que ya aprobaron

`inspect --unique` e `info` primero.

La escena de prueba es `res://debug/…`, nombrada en el `F<n>` o el RFC y construida por el developer. Tu JSON apunta ahí con `"scene"`. No la crees, no la edites y no uses `call()` para armarla. `res://agent/` es el flow, el harness mínimo y los PNG.

- Si el criterio ya empieza en la escena que el jugador abre, jugá esa.
- Si el plan nombra `res://debug/…` y existe, jugá esa.
- Si el criterio no cabe en la escena del jugador y **no** hay `res://debug/` en el pedido: devolvé solo `NEED_SETUP` y parate. Sin archivos. Quien llama (tech lead / orquestador) completa la escena; no la inventes vos. Plantilla: [plan.md](plan.md).

El estado inicial lo dejó el `.tscn`. Vos solo pulsás la acción del InputMap. Si el resultado del criterio ya está visible antes del `press`, es un bug de la escena de prueba: reportalo, no lo “arregles” jugando.

## 2. El humano juega; el harness no empuja

La situación tiene que ocurrir porque el escenario está armado y el jugador actúa.

- Movimiento y acciones de juego: **solo** `press` de una acción que **ya** está en el InputMap del editor (`move_left`, `ui_accept`, …).
- UI: `click` / `type` / `select` en el control que el jugador usaría. No `call("_on_play")` para saltear el botón.
- Si la acción no existe en el InputMap, o el nombre es un keycode (`KEY_A`, `65`): **BUG de producto**. `press` ya falla con `unmapped input`. No inventes teclas. No las agregues al proyecto.

Prohibido en el harness y en el JSON: `global_position`, `velocity`, `translate`, `InputEventKey`, `time_scale` para llegar antes, un `func` que mueva o dispare, un `call` que fuerce el estado para ganar el assert.

`hooks.gd` no es una cocina de helpers. Si el JSON puede `scene` + `press` + `click`, no agregues un método. Un método nuevo solo prepara (por ejemplo esperar a que el árbol exista) y se reutiliza. No uno por flow.

## 2.1. La captura manda

Abrí **cada** PNG que guardaste. El criterio nombra algo que se ve. La imagen tiene que mostrar **eso**.

Un efecto de costado no alcanza. Que cambie un número, que suene un evento o que un label cambie no pasa el criterio si la captura muestra otra cosa: una pila de cajas en lugar de lo pedido, actores superpuestos en lugar del layout, el jugador metido dentro de lo que tenía que enfrentar.

Un placeholder está bien si todavía se lee como lo pedido. Si no se lee, es **FAIL del criterio**, no un nit de look para después. No escribas “el mesh es una caja, el siguiente paso es afinarlo” y dejes `AGENT_OK`.

En el informe, por cada criterio visible: qué pedía el `F<n>` y qué se ve en el PNG (una frase). Si esas dos frases no coinciden, el criterio es FAIL.

## 3. Cache de class_name

Un `SCRIPT ERROR` con `Could not find type "X"` o `Could not resolve external class member` es cache viejo si `X` es un `class_name` que ya está en un `.gd` del proyecto y no está en `.godot/global_script_class_cache.cfg`. No es un bug de la feature. No edites ese archivo a mano. No lo trates como FAIL del criterio hasta haber reimportado.

Reparación, una sola vez, con el mismo binario del flow:

```bash
"$GODOT" --headless --path /ABS/GODOT_ROOT --import --quit
```

Después corré el mismo flow. Si el error desaparece, seguí el slice. Si vuelve el mismo `Could not find type`, no reimportes de nuevo: devolvé `CACHE_STALE` a quien te invocó y parate. Quien llama importa o arregla el proyecto. Plantilla: [plan.md](plan.md).

## 4. Informe

Fixture vs main, acciones de InputMap usadas, y si el diff salió de `agent/`. Un `unmapped input` es FAIL del producto, no del flow. Un `Could not find type` que se fue con `--import` no es FAIL del criterio: decí que reimportaste y seguiste.
