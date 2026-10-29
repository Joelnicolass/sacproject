# REVIEW RFC-025 · corte 025b (F79, panel de unidades seleccionadas)

Revisor: studio-reviewer, una pasada, sin implementar. Fecha 2026-10-15.
Producto juego: SQL/XSS/auth = N/A.
No se corrió Godot: había otro Godot de prueba vivo (pid 67088, banco de pasto `rfc022e4c_bench_persephone`) además del editor del usuario (9527). Regla de un solo proceso respetada; todo es lectura de código, logs y capturas.

## Veredicto

| Dimensión | Resultado |
|---|---|
| Criterios 1–8, 10 del RFC | PASS (6, 7 y 8 con evidencia débil, ver observaciones) |
| Criterio 9 (23 flows migrados pasan) | NEEDS WORK: no demostrado (pt58, pt59, pt63 fallan y la causa no está aislada; 12 online sin correr) |
| §3.3 | NEEDS WORK por desvíos no registrados en el RFC (sin `max_columns`, Ctrl en grupo) |
| Composición Godot | NEEDS WORK por 1 bloqueante (`reload()`) |
| Reglas del kit (agent_kit) | FAIL puntual: `SelectionRoster.reload()` en producto, único caller el harness |
| Look / escala | NEEDS WORK (52 % vs 41 %), decisión de usuario, no de código |

El RFC no se puede dar por cerrado hasta resolver B1 y B2. B3 se puede cerrar con una corrida cuando la máquina esté libre.

## Bloqueantes

**B1. `reload()` es API de producto que solo llama el flow** (`scenes/ui/selection_roster/selection_roster.gd:95-98`, único caller `agent/harness/hud_cache_probe.gd:29`).
Comprobado: `rg "\.reload\(\)"` en `scenes/` y `debug/` no da nada y en `agent/harness` da solo ese. El kit lo marca FAIL.
Además el propio repo advierte que `reload()` colisiona con `Script.reload()` (`scenes/world/body_catalog.gd:24`).
Arreglo mínimo: que la sonda reconstruya sin tocar producto. Por ejemplo `hide_cache()` instancia una segunda copia con `roster.scene_file_path`, o corre antes del primer dibujo con el flow arrancando en una escena sin roster. Se saca `reload()`. No hace falta cambiar `_build_frame`.

**B2. Criterio 9 sin demostrar** (pt58_melee, pt63_melee, pt63_melee2, pt59_select; 12 flows online sin ejecutar).
Evidencia de que NO los causa la migración de asserts ni `%Unit`:
- `agent/out/f79_reg/pt58_melee.log`: los asserts migrados (`%SelectionRoster count`, pasos 8 y 12) dan `ok`. Lo que falla es el paso 61 (`wait_until DoctorMelee visible_in_tree false`, `agent/flows/pt58_melee.json:284`), con `DoctorMelee/Health = 400.0` constante en todos los prints. Nadie le pega al doctor.
- `agent/out/f79_reg/pt59_select.log`: el doctor existe (`Doctor1 pose 1, 2, 2…`) y después `AGENT_FAIL flow print missing %SacrificeSystem/Doctors/Doctor1` (línea 146). Es un nodo dinámico del `sacrifice_system` que desaparece antes de lo que el flow espera. No se lee `%Unit` ahí. La corrida vieja (`agent/out/pt59/select.log`, 13-oct) sí lo tenía en el mismo paso.
- Ningún archivo del doctor o del sacrificio se tocó en 025b: `scenes/world/sacrifice/*`, `debug/doctor_*`, `desecrate_*` no tienen mtime posterior al 14-oct 12:00. 025b tocó `hud.*`, `selection_roster/*`, `high_noon.tscn`, 2 líneas de `match_command.gd`, `spell_book.gd`, `orders_group.gd`.
- No hay `show_selection`, `show_unit` ni `%Unit` en ningún `.gd`/`.tscn`/`.json` fuera de `agent/out` (grep limpio).

Pero tampoco hay prueba de que sean previos. Indicios que apuntan a cambios anteriores a 025b o ajenos:
1. En `pt58_b1_selected4.png` (nuevo, `f79_reg/`) se seleccionan 3 unidades con la leyenda «selected4»; la captura vieja del 13-oct (`agent/out/pt58/`) mostraba 4. La cámara y la iluminación del terreno son distintas (el suelo ya no es el violeta oscuro): han cambiado `look_quality.gd`, `terrain.gd` (01:04), `grass_*` y los ajustes de 025a (`selection.gd`, `orders.gd`).
2. Los flows dependen de `press turn_left hold X` para apuntar. Ese giro depende de la cámara y del tope `--max-fps 60`, que el run viejo quizá no tenía.
3. No hay commits en el repo (`git log`: sin commits), así que no se puede bisectar ni stashear.

Hipótesis, no hecho: el origen está en 025a o en el look del otro agente, y los flows scripteados por tiempo de giro dejaron de apuntar al doctor. Para confirmar con UNA corrida (cuando no haya otro Godot): `agent/run_f79.sh pt58_melee` con `SelectionRoster` oculto (`visible = false` en la escena de la corrida, o comentando su instancia en una copia de `high_noon.tscn`) y ver si el paso 61 falla igual. Si falla igual, es previo y se registra como deuda en FEATURES.md; si pasa, el culpable es el roster (por ejemplo el área STOP) y vuelve a B2.
Hasta eso, F79 no puede declararse «hecho» con la regresión en rojo sin explicar.

## Cumplimiento de §3.3 y criterios

| Punto | Evidencia | Estado |
|---|---|---|
| Escala por `_fit_screen`, a la izquierda, centrado | `selection_roster.gd:101-104`, capturas 720 y 1080 | PASS |
| Marco `fram` espejado, dibujado vacío | `:109-138`, `f79_0_empty` | PASS |
| Por unidad ≤ 12, más nueva primero, col `i >= rows`, fila `i % rows` | `:154-165`, GridContainer de 2 columnas. En `f79_hit.log` la Cell1 (0,833) = Trogg4 (799,7/960): la más nueva va primero | PASS |
| Barras 2×30 (192,0,0)/(0,96,192) solo con `maximum > 0` | `roster_cell.gd:13-15,107-114` | PASS |
| Agrupado: una celda por tag, cantidad descendente y luego tag, `%Count` solo dígitos, Σ/Σmax | `:168-191`, `roster_cell.gd:53-64,97-104`; `f79_2_grouped150` | PASS |
| Si los tipos superan `capacity`, crecen columnas hasta `max_columns` (4) y luego scroll | No hay `max_columns`; solo scroll vertical (`selection_roster.tscn` Scroll, `_ensure_cells`) | DESVÍO (ver O1) |
| Clics unidad: clic/Shift/Ctrl por tipo dentro de la selección | `_on_cell_activated` `:230-239` | PASS |
| Clics grupo: clic `select_only(tipo)`, Shift `remove(tipo)` | `:236-239` (Ctrl = clic) | PASS |
| `%Ability` emite `ability_pressed` → `_use_ability()` | `selection_roster.gd:83`, `match_command.gd:51` | PASS |
| Tooltip apagable | `@export var tooltips`, `:161,187,225` | PASS |
| Pool de `capacity`, reconstruye en `Selection.changed`, Timer 10 Hz, sin 150 señales | `:77-92,196-205`; `Refresh` Timer en la escena | PASS |
| Visible con `local_slot() > 0`, oculto en dedicado | `:258-259`; `f79_720/dedicated.log` sin errores del roster | PASS |
| Criterio 1 (vacío, 12 huecos, lado a lado 720 y 1080) | `f79_0_empty`, `f79_3_side_by_side` en ambas resoluciones; assert `count == 0` | PASS (el «12 huecos» es arte del marco, no hay assert) |
| 2 (`orders_group` 4 celdas `ycro`, vida llena) | `f79_roster.json` | PASS |
| 3 (150, 3 celdas, 50/50/50) | `f79_roster_many.json` | PASS |
| 4 (clic Trogg → 50; Shift Manahoar → 100) | flows `drag` sobre celdas | PASS |
| 5 (clic celda 2 → 1; Ctrl → 4) | `f79_roster.json` pasos 29 y 38 | PASS |
| 6 (barra baja en ≤ 0,2 s) | Solo `print`, sin assert ni cronómetro (`f79_hit.json`) | DÉBIL (ver O2) |
| 7 (`%Ability` Rockform, clic 200 → 187) | `f79_ability.log:32,40` (200 → 187); captura `f79_ability_after` | PASS (por `print`, no por assert) |
| 8 (clic en el fondo no cambia `size`) | `f79_roster*.json` pasos con `drag` en (96, 236) y (52, 18) | PASS |
| 9 (sin `%Unit`; 23 flows pasan) | `%Unit` ya no existe; ver B2 | NEEDS WORK |
| 10 (`last_build_us` ≤ 1500; refresco ≤ 300 µs) | `f79_roster_many.log`: build 1086 µs, refresh 85 µs, con asserts `lte` | PASS |

## Composición (checklist Godot)

- **Un nodo, una responsabilidad:** PASS. `SelectionRoster` solo presenta y estrecha la selección vía `Selection.select_only/remove`. No emite órdenes ni conoce `Orders`; la habilidad sube por la señal `ability_pressed`. `RosterCell` es una vista tonta que sube `activated(cell, shift, ctrl)`. Señal hacia arriba, API hacia abajo: PASS.
- **Sockets:** PASS. `selection` y `cell_scene` son `@export` tipados, con `_get_configuration_warnings`, y la escena los asigna con `NodePath("../../Selection")`. No hay `get_node("../..")`. `%UniqueName` solo dentro de la escena.
- **Look en la escena:** PASS. Colores, tamaños y estilos en `.tscn` y `@export`. `HudIcons` es `RefCounted` estático, no un autoload. Con respaldo a plato oscuro y a `text = tag` sin caché; `f79_nocache` lo prueba sin errores.
- **MOUSE_FILTER:** PASS. Raíz `STOP` (`selection_roster.tscn: mouse_filter = 0`), celdas y `Ability` Button (STOP por defecto), `Frame` y sub-Controles decorativos `IGNORE`. `WizardHud` sigue en IGNORE.
- **Sin MP:** PASS. Solo lee `MpKit.local_slot()`, como `Selection`.
- **Originales fuera del repo:** `cache/` está en `.gitignore`; nada de `cache/look` está versionado. Ver O5 por las capturas.
- **Alcance:** el cambio a `agent_flow.gd` / `agent_ops.gd` (drag con `shift`/`ctrl`) es de 025a, no de este corte.

Nits de composición:
- `_show_ability` (`selection_roster.gd:208-225`) duplica `_selection_ability`/`_ability_of` de `match_command.gd:421-433`. Si cambia uno, el icono puede mostrar una habilidad y Ctrl+Q usar otra. Mejor que el comando lea `%SelectionRoster.ability_tag`, o extraer una función común.
- `min_health`, `cells_shown`, `last_refresh_us`, `summary` y los `last_*` son lecturas para flows. Hay precedente (`Selection.count`, `last_rect_us`) y no cambian la conducta: tolerables. `summary` y `last_build_us` están en los criterios del RFC; `min_health` y `cells_shown` no (ver O3).
- `HudIcons._icons` guarda también los `null`: una caché que aparece más tarde no se ve hasta `reset()`. Vale para el probe, no estorba en producto.

## Escala 480 vs 600 (recomendación)

Medido en las capturas a 1280×720: el marco ocupa y 168 a 552 (53 % del alto), contra ~41 % en `orig_4_manantial.webp`; en el original también el libro de hechizos se ve más chico que el nuestro. La proporción relativa (~1,27) coincide con 600/480.
Recomendación: **no** cambiar solo el panel a 600. El libro usa 480 y quedarían dos escalas en la misma HUD, lo cual se ve peor que la diferencia con el original. 480 es lo que dice la fuente (`hudScaling` = alto/480, `dagonBackend.d:311`) y lo que ya aprobó el usuario en 025a/libro.
Lo correcto: dejar 480 en 025b y abrir una decisión única de usuario: si el look del original manda, la perilla debe ser **una sola** para HUD completa (por ejemplo un `hud_base_height` compartido por `SpellBook` y `SelectionRoster`, que hoy son dos `@export` sueltos) y comparar con una captura del original de resolución conocida, no con una foto recortada. La captura actual no es base fiable para medir 41 %.

## Riesgos con RFC-024 y 025c

- **RFC-024:** `orders.gd` no lo toca este corte; `match_command.gd` solo recibe 2 líneas (`ability_pressed.connect`, y se saca `show_selection`): conflicto de fusión improbable. `high_noon.tscn`: el nodo `SelectionRoster` se agregó a mano, sin `unique_id=` como los vecinos; Godot lo completa al guardar, pero otro agente que reguarde la escena puede producir diff ruidoso. Releer antes de editar.
- **025c (`%Battle`):** `match_command._on_selection_changed` (`:478-484`) sigue escribiendo «N unidades», el nombre o «Mago» en `%Battle.text`. Se ve en las capturas (arriba a la izquierda, junto al panel), duplicando lo que muestra el panel. Es correcto para este corte (025c lo borra y `f80_hud_text` exige `found == 0` con 150 seleccionadas), pero 025c.6 va a fallar mientras eso exista; anotarlo en la lista de 025c.
- **025c `CursorSkin`:** su rayo de hover a 30 Hz no debe tratar el área del panel como «suelo/nada» debajo del puntero; con el roster en STOP conviene que consulte `gui_get_hovered_control()` y solo corra con `%View`. Si no, el cursor `T*` puede quedar en `Tntr` sobre el panel.
- **CommandCue `%Aim`:** el contenedor a pantalla completa en IGNORE no roba clics al panel; verificar el orden de nodos (CommandCue después de `SelectionRoster` solo cambia el dibujo).
- El flow `f79_*` y los 23 migrados leen `%SelectionRoster`; 025c cambia `%Battle` a `Node`, no el roster. Sin choque.

## Observaciones (no bloquean)

- **O1. Desvíos del RFC no registrados:** (a) no hay `max_columns`, solo scroll vertical con más de 12 tipos (el marco es 2×6 fijo; defendible, pero §3.3 dice otra cosa y hay que editar el RFC); (b) Ctrl+clic en celda de grupo = clic (tampoco figura en §3.3, aunque el criterio 4 no lo pide). FEATURES.md ya los menciona; falta el RFC.
- **O2. Criterio 6 sin cronómetro:** `f79_hit.json` hace `wait_until min_health lte 0.85` (la lectura de la propia vista) y prints. Demuestra que la barra sigue a `Health` (Cell1 0,833 = Trogg4 799,7/960), no el ≤ 0,2 s. Por diseño el Timer a 10 Hz da ≤ 0,1 s más un cuadro, argumento razonable; conviene un assert que lo cuantifique o dejarlo como «por construcción» en el RFC.
- **O3. Varios criterios por `print`:** 6 y 7 usan prints en vez de asserts (maná 200 → 187 lo da el log, no un `equals`). Subir a `assert` los que ya se verifican.
- **O4. macOS y Ctrl+clic:** Godot en macOS convierte Ctrl+clic izquierdo en clic derecho a nivel de sistema; `Button` solo reacciona al izquierdo, así que con un mouse real Ctrl+clic en una celda probablemente no haga nada. El flow lo prueba con evento sintético, no con el SO. Lo mismo ya afecta al Ctrl+clic del mundo (`Selection.click`). Vale una nota en el RFC; alternativa en el original no hay. Considerar doble clic en celda como atajo equivalente en un corte posterior.
- **O5. Capturas sin ignorar:** `agent/out/f79_*/` quedó `??` (sin trackear) pero no ignorado; `f79_3_side_by_side.png` incluye un recorte de la foto del original y arte del caché (`fram`, iconos). Si el repo trackea `agent/out` (lo hace, 1425 archivos), un `git add .` los sube. Sacarlos del staging o ignorar la carpeta de f79; la carpeta `visual/refs/original/` ya está ignorada.
- **O6. Timer en el dedicado:** `Refresh` sigue corriendo a 10 Hz en el dedicado, ahí solo reevalúa `_update_visible`. Despreciable, pero `Timer.autostart` podría apagarse con `local_slot() == 0` o salir antes de construir marco y texturas.
- **O7. Evidencia lado a lado:** la comparación visual contra el original queda para `studio-visual`; GUT/flows no son playtest visual. Faltan las capturas a 1080 de `f79_hit` y `f79_ability` (solo existen a 720).
- **O8. Playtest con ventana:** FEATURES.md dice «falta review y playtest»; las capturas existen (de una corrida del developer) pero el playtest independiente sigue pendiente y debe hacerse antes de cerrar (regla de no saltear playtests).

## Cierre

No cerrar F79 todavía. Orden sugerido para la única corrección:
1. Quitar `SelectionRoster.reload()` y rehacer la sonda sin API de producto (B1).
2. Una corrida de `pt58_melee` con el roster oculto para aislar la regresión; documentar el resultado y, si es previa, anotarla como deuda con su causa (B2).
3. Editar §3.3 con los desvíos (O1) y decidir la escala HUD con el usuario (480 compartido por ahora).
4. Playtest independiente con ventana y las capturas a 1080 que faltan.
