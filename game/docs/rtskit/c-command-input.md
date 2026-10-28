# RtsKit, pieza (c): la entrada de comandos

Inventario de Sacrifice para que la sesión del kit lo vuelva genérico. Rutas desde `game/` en la rama `refactor/godot-standard`. El kit no tiene red ni conoce MpKit: la orden sale por `RtsOrders.send` (pieza b).

## Cómo está armado

`MatchCommand` (`scenes/orders/match_command.gd`, 70 líneas, en `match.tscn` › `Input`) es un coordinador sin reglas. Cada hijo es dueño de un tipo de entrada; si se saca un hijo, ese comando desaparece. Nada se dibuja como texto: lo armado va a `CommandLog` (`%Battle`) y la UI lo dibuja.

| Archivo | Líneas | Qué hace | Destino |
|---|---|---|---|
| `orders/match_command.gd` (`MatchCommand`) | 70 | Fachada para el menú radial y la UI: `right_at`, `context_kind`, `order_at`, `order_in_formation`, `arm_order`, `set_formation`, `retreat`, `use_ability`, `camera_dragged` | Kit (`RtsCommandInput`), sin `use_ability` |
| `orders/command/command_input.gd` (`CommandInput`) | 128 | Enruta las teclas y el clic izquierdo: si hay algo armado, se lo da; si no, selecciona (clic o rectángulo pasando `rect_threshold_px`) | Kit. Las teclas de hechizos y criaturas quedan en el juego |
| `orders/command/armed_command.gd` (`ArmedCommand`) | 91 | Lo que espera el próximo clic izquierdo: `mode` (`spell`, `structure`, `ability`, `attack`, `guard`, `move`) y con qué se armó. `arm_order`, `cancel`, `is_armed`. Desarmar limpia `%Battle` | Kit: el modo y el ciclo de armado. Los modos `spell` y `structure` son del juego |
| `orders/command/order_command.gd` (`OrderCommand`) | 131 | Las órdenes a la selección: el clic derecho según lo que hay abajo, el ícono armado, la retirada y la formación | Kit, con el mapeo contexto → orden configurable |
| `orders/command/pointer_ray.gd` (`PointerRay`) | 237 | Pantalla → mundo: punto del piso, unidad, alma, cadáver o edificio bajo un píxel, el cuerpo más cercano a un punto del minimapa, «¿es enemigo?». Capas: 1 piso y estructuras, 2 unidades, 4 almas, 8 cadáveres | Kit (`RtsPointer`) con capas configurables. Almas y cadáveres son del juego |
| `orders/command/group_keys.gd` (`GroupKeys`) | 26 | Las teclas 1–0 de los grupos | Kit (ver pieza a) |
| `orders/command/command_feedback.gd` (`CommandFeedback`) | 82 | El ping en el punto de la orden (un cono, local), la frase en `%Battle` y el alta de los convocados en la selección | Kit: el ping como señal o escena. Los convocados son del juego |
| `orders/command/minimap_pointing.gd` (`MinimapPointing`) | 40 | El minimapa como otra superficie: `order_units` ordena ahí; `select` con algo armado apunta ahí | Kit, en la 0.5 (minimapa) |
| `orders/command/armed_preview.gd` (`ArmedPreview`) | 93 | Mientras hay una estructura armada, pregunta 15 veces por segundo (`hz`) qué contestaría el servidor en el puntero (`Caster.aim_for`) y prende el anillo verde o rojo | Kit: el «preview mientras está armado» con un proveedor del juego. La regla es del juego |
| `orders/command/spell_command.gd`, `ability_command.gd` | 241, 90 | Hechizos, estructuras y la habilidad activa | Juego. Usan `ArmedCommand` y `PointerRay` del kit |
| `orders/order_radial.gd` (`OrderRadial`) | 152 | Dueño del clic derecho: un toque es `right_at`; mantenerlo quieto `hold_s` (0.25 s) abre el menú radial donde se apretó y lo que se suelta corre en el punto apretado. Tab (`order_menu`) lo abre en el puntero. `formation_1`…`formation_8` (Alt+1…8) guardan una formación sin menú | Kit |
| `ui/radial/radial_menu.gd` (`RadialMenu`) y sus piezas (`RadialLayout`, `RadialEntry`, `RadialDecor`, `RadialRings`, `RadialAnimator`) | 172 + piezas | Menú radial genérico: dos anillos de íconos, `entry_chosen` / `cancelled`, `point_at`, `confirm`. No conoce órdenes ni red | Kit, tal cual |
| `orders/command_log.gd` (`CommandLog`, `%Battle`) | 64 | El estado de lo armado, solo con señales: `armed_changed(kind, icon)`, `said(text, cue)`, `aim_changed(status, site)`; `arm`, `disarm`, `show_aim`, `say` | Kit (`RtsCommandState`) |
| `ui/command_cue/command_cue.gd`, `cursor_skin.gd`, `refusal_reason.gd`, `target_probe.gd`, `cue_set.gd` | 170, 124, 76, 192, 51 | El cursor: el ícono de lo armado junto al puntero, el destello de rechazo, el cursor de hardware según lo que hay abajo, la frase del rechazo, y la sonda que nombra lo que hay bajo el puntero | Kit: la sonda, el cursor y el ícono con un `CueSet`. Las clases de blanco y los textos son del juego |
| `orders/world_input.gd` (`WorldInput`) | 19 | El único dueño de «¿la entrada llega al mundo?»: un modal entra al grupo `menu_open` y los lectores preguntan `blocked(self)` | Kit, tal cual |

## Comportamientos a conservar

| Comportamiento | Regla o valor |
|---|---|
| Clic derecho sobre un enemigo | `attack` |
| Clic derecho sobre un cadáver | `guard_area` en ese punto |
| Clic derecho sobre algo propio o neutral | `guard` |
| Clic derecho en el piso | `move`. Sin piso (el cielo): rechazo `NO_GROUND` |
| Clic derecho con algo armado | Cancela lo armado y no ordena |
| Ícono armado `attack` o `guard` sobre un cuerpo | Esa orden sobre el cuerpo |
| Ícono armado `attack` o `guard` en el piso | `advance` o `guard_area` |
| Ícono armado `move` | Va al punto del piso, o a la posición del cuerpo si no hay piso |
| Armado que se rechaza | Un hechizo o una habilidad siguen armados después de un clic rechazado, como en el original. Un ícono de orden se desarma al usarlo |
| Teclado sin cursor | `order_units` y `select` por teclado apuntan con la mira (el centro, que la cámara mantiene sobre la cabeza del mago) y saltean al mago propio |
| Menú radial | Mantener 0.25 s; soltar en el centro cancela; la entrada corre en el punto donde se apretó, en un solo envío. El centro muestra el ícono de `context_kind`: `ground`, `enemy`, `own`, `corpse` |
| Alt+1…8 | Guardan la formación sin que Alt+número elija también un grupo (`OrderRadial` lee antes que el mundo) |
| Arrastrar la cámara | Si la cámara se está arrastrando, el clic izquierdo no selecciona ni ordena (`camera_dragged`) |
| Modal abierto | Con un menú de pausa u opciones (grupo `menu_open`), nada de esto lee la entrada |
| Preview | 15 Hz; solo lectura, sin RPC |
| Cursor de rechazo | Destello de 0.6 s (`flash_s`); ícono de 38×38 px de canvas; offset `(-19, 5)` |

## InputMap que usa

`select`, `order_units`, `order_attack` (Ctrl+R), `order_guard` (Ctrl+A), `order_retreat` (Ctrl+Espacio), `use_ability` (Ctrl+Q / Shift+B), `order_menu` (Tab), `formation_1`…`formation_8` (Alt+1…8), `group_*` y `group_set_*` (pieza a), y las teclas de hechizos y criaturas (del juego).

## Lo propio de Sacrifice

- **Hechizos, estructuras y la habilidad activa:** `SpellCommand`, `AbilityCommand`, `Caster.aim_for` y el anillo del manantial. Quedan en el juego, montados sobre el armado y el puntero del kit.
- **El mago:** es el ancla de la retirada, el blanco de la mira y lo que se saltea al apuntar por teclado. Todo eso es un contrato del juego.
- **Almas, cadáveres y edificios** como clases de blanco: el kit define unidad, piso, propio, neutral y enemigo, y el juego suma sus clases.
- **`Refusal`** con sus claves y textos (`scenes/ui/i18n/strings.csv`), y **`CueSet`** con los íconos del original (`curs.FLDR`).
- **`MpLocalSeat`** en `CommandFeedback` y `PointerRay` («¿es mío?»): pasa a ser `local_slot`.
- **El nombre `%Battle` de `CommandLog`**: lo conserva solo porque los flows de AgentKit lo leen. El kit puede nombrarlo como quiera; Sacrifice ajusta sus flows.

## Qué lo cubre hoy

- **Ningún test GUT.**
- **Flows de AgentKit descartables** en `agent/` (no versionados) que clican y leen `%Battle`.
- **La prueba LAN** no pasa por la entrada.

Para la RC del kit propongo tests de:
- el mapeo contexto → orden, con los cuatro casos más el cielo;
- el ciclo armar → clic → desarmar, incluido el clic derecho que cancela y el armado que sigue después de un rechazo;
- el menú radial: tocar contra mantener, soltar en el centro y correr en el punto apretado;
- que Alt+N no elija un grupo;
- `WorldInput.blocked`.
