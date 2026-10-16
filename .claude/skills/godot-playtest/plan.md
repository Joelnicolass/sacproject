# Plan de playtest

No esperes OK para jugar. Validá los límites de [evaluate.md](evaluate.md).

Si falta el contexto para armar el escenario, devolvé **solo** esto a quien te invocó y no escribas archivos. Cuando te relance con `PLAYTEST_SETUP`, usá esas condiciones y seguí.

```
NEED_SETUP
criterio: llegar al objetivo del slice
falta: no hay res://debug/ nombrada en el F<n> o el RFC
no voy a: crear el .tscn ni usar call() para armar el mundo
```

Quien llama (otro agente o un humano) responde así:

```
PLAYTEST_SETUP
escena: res://debug/goal_ready.tscn
accion: interact
observable: %Goal sale del árbol y %Status muestra el texto del criterio
```

El árbol va en el informe, después de poder jugar. No frena el trabajo si las condiciones ya están.

```
PLAYTEST_PLAN
objetivo: …
escena: res://debug/goal_ready.tscn (la del F<n>; no la inventa el playtester)
input: press interact (ya está en el InputMap; si no, BUG)
hooks: ninguno — el JSON alcanza
límites: solo agent/; cero reglas de negocio

agent/
├── flows/goal_ready.json
└── out/
```

Si una acción no está mapeada en el editor, no armes el flow con un keycode: reportá el bug y parate.

Si reimportar no registra el `class_name`, devolvé solo esto y no sigas el slice:

```
CACHE_STALE
tipo: Door
script: res://scenes/door.gd
error: Could not find type "Door"
importe: una vez, el error volvió
```

Quien llama corre el import o corrige el proyecto, y relanza el playtest.
