# Review RFC-025 corte 025a (F78): selección sin tope y clic en vacío

Revisor: studio-reviewer, una pasada, solo lectura (no corrí Godot; había un editor, pid 9527, y otro proceso de Godot de un developer). Producto juego: SQL/XSS/auth N/A.

## Veredicto: NEEDS WORK (1 corrección menor, sin bloqueantes duros). Cerrable tras esa corrección y la re-corrida de flows.

| Dimensión | Veredicto |
|---|---|
| 1. Regla 3.2 | NEEDS WORK (cadáver) |
| 2. Selection | PASS (nits) |
| 3. Orders | PASS (nits, riesgo RFC-024) |
| 4. AgentKit | PASS (subir a upstream) |
| 5. Frame ~420 ms | No bloqueante; RFC aparte |
| 6. Composición/inspector | PASS |

## 1. Regla 3.2
Correcto, con evidencia en `scenes/world/match_command.gd`:
- Armado nunca deselecciona: `_left_at` hace `match _mode` y el `clear` solo está en la rama `_` (nada armado), líneas 255-276. Incluye `menu`.
- Shift/Ctrl: `not shift and not ctrl` (l.273). Arrastre: `_release_left` sale por `_rect`/`_camera_dragged` antes de `_left_at` (l.152-160). Un rectángulo vacío sin Shift ya deselecciona (`select_rect` no aditivo); con Shift conserva.
- Clic derecho: ruta aparte (`_right_at`), no toca la selección.
- HUD: no llega a `%View`.
- Criatura propia: sigue en `Selection.click` (doble clic, Ctrl tipo). `Selection.clear()` pone `_last_unit = null`, así que no hay doble clic fantasma.
- Criatura enemiga: `_unit_under` la devuelve, `can_select` falla y no pasa nada. Correcto.

**Hallazgo A (menor, corregir en la única ronda): el cadáver deselecciona.** `_is_empty_at` (l.539) lanza el rayo con máscara 7 (capas 1, 2 y 3). Los cadáveres están en `corpse_layer = 8` (capa 4; `scenes/world/units/corpse.gd:14`, `lay_down` l.45), explícitamente "off the unit layer so picks ignore it". El rayo atraviesa el cadáver, pega en el suelo, y el clic cuenta como vacío. La tabla 3.2 dice «cadáver → nada». La comprobación `is_in_group("corpse")` de `_is_empty_at` es código muerto. Arreglo: máscara 15 en `_is_empty_at` (el grupo `corpse` ya está tratado) o documentar que el cadáver equivale a suelo y quitar el chequeo. Ningún criterio del RFC lo cubre (5 pide Druid, mago y CreatureTab), por eso no es bloqueante duro.
- Observación: `selection_probe._is_ground` y `aim_empty` usan máscara 7 y listan `corpse` entre cuerpos; el probe tampoco detectaría el fallo.
- Observación: manafount y altar en capa 1 sin grupo ajeno cuentan como suelo salvo `Altar.GROUP`. Consistente con "suelo (máscara 1)".
- Sin cámara, `_cast` devuelve `{}` y el clic cuenta como vacío (deselecciona). Aceptable.

## 2. Selection (`scenes/world/selection.gd`)
- Membresía O(1): `_members` (instance_id) con `has()` (l.64); `_replace` (l.233) y `_merge_front` (l.288) O(n) con dictionary `seen`. `_prune` reconstruye `_members` (l.268). `drop` la mantiene.
- API: `clear`, `select_only`, `remove`, `has`, más `count` (getter solo lectura para AgentKit, desvío razonable, bien comentado). Señal `changed(units)` igual.
- `max_size` 0 = sin tope: resize/break solo con `max_size > 0` en `_replace`, `_merge_front`, `_push_back`, `_same_type_near`, `select_rect`. 12 = clásico. El mismo knob gobierna grupos y grupo de convocadas (P2 OK). `high_noon.tscn` max_size=0; `selection_many_classic.tscn` max_size=12.
- Nits (no bloquean):
  - `_prune` corre en cada `size()` y `_process` y recorre los 10 grupos llamando `can_select` por miembro (hasta ~1500 llamadas con `MpKit` y `call` por cuadro). Hoy no se nota; si se mide, podría limitarse a cuando cambia algo.
  - `_push_back` (`result.has`) y los `erase` en `define_group`/`extend_group` son O(n²). Con 150 son ~22k operaciones, irrelevante, pero el RFC prometía O(n) en lo de la selección, que sí se cumple.
  - `drop` hace `_units.erase` O(n).

## 3. Orders (`scenes/world/orders.gd`)
- `max_units = 0` se aplica en el servidor (`_own_units` l.120, solo corta si `> 0`), misma escena. Filas de `row_size` 12 en `_formation` (l.132-157): fila 0 con guardia flanqueada solo en la primera, filas siguientes detrás a `spacing`, última fila centrada. El ancho es `(per_row-1)·spacing` ≤ 12·spacing + 1. Evidencia en captura: filas 13, ancho 31.5.
- Validación de dueño intacta (`_can_order` + `command_slot`). Sin RPC nueva. `addons/mp_kit` no se toca en este corte (los cambios de mp_kit en el worktree no son de 025a).
- `_match` O(n·m) con `PackedFloat64Array.sort`: 22 500 claves con 150; la clave es exacta bajo 2^53 (hay `cap`). Bien.
- Nits:
  - `print("orden %s %d")` en `_apply` queda en producción (lo usan los flows y el log de red; aceptable, pero es ruido por orden). Mejor detrás de un `@export var log_orders`.
  - `submit_order` acepta un `unit_paths` de tamaño arbitrario; con tope 0 un cliente malicioso puede mandar miles de paths (`get_node_or_null` por cada uno). Sugiero acotar el recorrido (p. ej. por el número de unidades propias del slot) en un RFC de endurecimiento; no es nuevo del corte pero antes lo mitigaba el 12.
  - `last_apply_us` no se actualiza en retirada o salida temprana (solo instrumentación).
- **Riesgo de merge con RFC-024 (`apply_for`)**: ambos tocan `_apply` / `_own_units` / `_formation`. Conviene que 024 extraiga `apply_for(slot, units, command, ...)` sin renombrar `_formation`/`_own_units` ni los campos `last_*`, y que 025a se integre primero. Hay que mantener el `print` o su sustituto si los flows lo esperan, y `row_size` aplicado dentro de `_formation` (la IA planea en grupos ≤ 12 y cae en una sola fila).

## 4. AgentKit
- `agent_flow.gd`: `_assert_prop` con `equals|gte|lte|contains`, prop con puntos; `is_equal_approx` numérico; error claro si falta el operador. `wait_until` no reinterpreta `contains` cuando hay `prop`. Correcto.
- `agent_ops.gd`: `drag` con `shift` y `ctrl` en botón y movimiento. Correcto.
- **Anotar: estos dos cambios al addon deben subirse a godot-studio-skills** (repo upstream), con README del addon actualizado (`addons/agent_kit/README.md`).
- Checklist del reviewer:
  - `rg -n "func agent_" scenes` → sin coincidencias (exit 1). `src` y `glue` no existen en este proyecto.
  - `git diff --stat -- scenes` no sirve como evidencia: el repo no tiene commits y el índice mezcla el trabajo de otros developers (pasto, RFC-023/024).
  - Helper de playtest en `res://agent/harness/selection_probe.gd`: correcto. `debug/selection_many.tscn` instancia `orders_group.tscn` con otros números (sin script paralelo) y el resultado del criterio no está puesto de antemano (el flow lo provoca con `check_tick`).

## 5. Frame ~420-540 ms
Datos: `f78_perf.log` frame_ms 411 con 0 seleccionadas, y la captura `f78_3_cleared` (0 seleccionadas) muestra 544 ms; `cpu_ms` ~49,8 (process + physics) y 248 draws. El frame de pared es ~8 veces el tiempo de CPU de proceso, así que ~350 ms del frame no son script ni física: son render/GPU/espera o contención con el otro Godot. No depende de la selección (con 0 seleccionadas es igual o peor).
- Qué hacer: no es bloqueante para F78, porque la medición útil (CPU de proceso 49,46 vs 49,79 ms, Δ 0,33 ms; draws 246 vs 250) muestra que la selección de 150 no agrega costo. Pero el criterio 9c literal (Δ frame_ms ≤ 1,0) no está verificado: debe quedar anotado como NO MEDIDO y repetirse con la máquina libre (un solo Godot, `--max-fps 60`).
- Aparte, 50 ms de CPU de proceso con 150 cuerpos animados es un problema real (≈20 fps con CPU puro): corresponde a un RFC de rendimiento aparte (separación O(N²) de F66, animación de 150 modelos, pasto). Propongo abrirlo, no mezclarlo con 025a.
- El «primer orden 37 545 µs vs 5 102 µs después» (primera reproducción del clip «run» por modelo) supera el tope de 12 000 µs solo la primera vez: aceptable si se anota; el criterio 9b se cumple desde la segunda orden.

## 6. Composición e inspector
- Knobs `@export`: `max_size`, `max_units`, `row_size` en `high_noon.tscn` (l.191-197), `group_count`, `summon_group`, etc. Sin god-nodes: Selection no pinta ni ordena; Orders no selecciona; `match_command` solo llama API (`clear`, `click`). Señal hacia arriba, API hacia abajo.
- Sin MpKit/RPCs nuevos; el servidor valida el dueño.
- `FEATURES.md` F27 reescrito y F78 anotado (no verifiqué su texto línea por línea).
- La captura `f78_2_order_rows` y `f78_1_sel150` muestran lo esperado: 150 barras, 13 filas, ancho 31.5. `f78_3_cleared`: 0 barras. En `f78_2` el overlay dice «ordenadas 102» en el instante de la captura (el flag `ordered` se propaga con el frame de 450 ms); el assert del flow debe esperar a 150, revisar que lo haga. Los textos de la HUD ('Orden', 'Mago', '150 unidades') siguen dibujados: es de 025c, no de este corte. El look queda para `studio-visual`.

## Regresión (criterio 8)
Los seis flows completan pasos, pero `--fail-on-error` falla por `scenes/world/look/grass/grass_field.gd:246` (error de parseo de otro developer). Hasta que ese archivo parsee no hay evidencia limpia de `f27_orders`, `f27_pt_group`, `f27_pt_formation`, `f27_pt_summon`, `f25_summon`, `f29_spit` ni f78_*. Condición de cierre: re-correr y pegar la salida cuando se arregle.

## Alcance extra señalado
`Selection.count`, `drag` con modificadores en AgentKit, log «orden <cmd> <n>», propiedades de medición en `Group`, flows extra (`f78_classic`, `f78_four`, `f78_perf`, `f78_online_a`) y `run_f78_net.sh`: todos están al servicio de los criterios y quedan aceptados.

## Cierre
Se puede cerrar 025a con: (1) corregir el cadáver (máscara 15 o aclarar), (2) re-correr los flows de regresión cuando `grass_field.gd` parsee, (3) anotar 9c como no medido y abrir RFC de rendimiento, (4) subir los cambios de AgentKit a godot-studio-skills.
