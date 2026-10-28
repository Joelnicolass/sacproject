# RtsKit, pieza (b): órdenes, cola, red y formaciones

Inventario de Sacrifice para que la sesión del kit lo vuelva genérico. Rutas desde `game/` en la rama `refactor/godot-standard`.

Regla acordada: los kits no dependen entre sí. El RtsKit no tiene nada de red y no conoce MpKit ni FsmKit; el transporte queda como pegamento en Sacrifice.

## Archivos

| Archivo | Líneas | Qué hace | Destino |
|---|---|---|---|
| `scenes/orders/orders.gd` (`Orders`, nodo `World/…/Orders` de `match.tscn`) | 388 | Recibe la orden de un grupo, valida que las unidades sean del slot, arma la formación, reparte los lugares y le da la orden a cada unidad | Reglas al kit, transporte a Sacrifice (ver abajo) |
| `scenes/orders/formations/formation_type.gd` (`FormationType`) | — | Resource base: `id`, `display_name`, `icon`; `slots(count, spacing, target_distance, command)`, `row_count`, `match_row_size`, `row_width` | Kit |
| `scenes/orders/formations/row_formation.gd` | — | Línea, flancos, falange, escaramuza: filas de `row_size` (0 = una sola fila), alineadas al centro, a la izquierda o a la derecha | Kit |
| `scenes/orders/formations/arc_formation.gd` | — | Semicírculo y círculo (`arc_deg`), detrás del punto | Kit |
| `scenes/orders/formations/wedge_formation.gd` | — | La cuña en V; en un ataque la punta queda sobre el punto (`attack_forward`) | Kit |
| `scenes/orders/formations/formation_catalog.gd` (`FormationCatalog`) | — | La lista y el `default_id` (`line`); `find`, `has_id`, `default_formation` | Kit |
| `scenes/orders/*.tres` | 9 archivos | `formations.tres` (el catálogo) y las 8 formaciones de Sacrifice | Quedan en Sacrifice como datos; el kit trae un catálogo de ejemplo |
| `scenes/units/unit_orders.gd` (`UnitOrders`, hijo de cada criatura) | ~270 | Ejecuta la orden en la unidad: caminar, perseguir, custodiar, retirarse; elige blancos | Lo que ejecuta queda en el juego; los estados y el contrato pasan a `RtsOrderQueue` (ver abajo) |

## Transporte (queda en Sacrifice) y reglas (van al kit)

Hoy `orders.gd` mezcla los dos. Así se separa:

**Transporte**, que queda en Sacrifice como pegamento:

| Hoy | Después |
|---|---|
| `request(...)`: si `MpAuthority.should_send_command()` (en red y no soy el servidor), `submit_order.rpc_id(SERVER_PEER, …)`; si no, aplica con `MpKit.local_slot()` | `orders.send = func(o): submit_order.rpc_id(1, o.to_array())`, solo en un cliente de red. Sin red no se conecta nada (`send` por defecto aplica local) |
| `@rpc("any_peer", "call_remote", "reliable") submit_order(...)` con el slot de `MpAuthority.command_slot(self)` (el slot del peer que mandó; 0 = rechazar) | `submit_order(data)` → `orders.apply(RtsOrder.from_array(data), MpKit.slot_for_peer(sender))` |
| Las unidades y el blanco viajan como `NodePath` (`_paths_of`) | `RtsOrder.to_array()` decide cómo viajan las unidades. Hoy son `NodePath`; el kit puede ofrecer `NodePath` o un id que pone el juego |
| `MpKit.local_slot()` | `orders.local_slot`, que el pegamento carga desde el `MpLocalSeat` |

**Reglas**, que van al kit:

- `apply(order, from_slot) -> bool`: es el `_apply` de hoy.
  - Descarta las unidades que no son de `from_slot`, las repetidas, el propio blanco y las que no aceptan la orden.
  - Corta en `max_units` (0 = sin límite; el original corta en 12).
- **`apply_for(slot, units, ...)` de la IA**: hoy le pasa los nodos directo, sin `NodePath`, porque «la IA ordena miles de veces por partida y la vuelta por NodePath costaba la mitad de cada orden». El kit tiene que conservar ese camino rápido: `apply` con nodos, sin serializar. Solo corre en el servidor o en solo.
- **La formación de la mayoría**: el grupo usa la formación que tienen más unidades; un empate gana la primera del catálogo, que es el orden del original. Cada unidad guarda su `formation_id` (por defecto `line`).
- **La orden «formation»**: guarda la formación en cada unidad sin mover a nadie, e ignora un id que el catálogo no conoce. Una orden que trae una formación (la elección del menú radial) primero la guarda y después la usa.
- **El espaciado**: `min(1.25 · tamaño máximo del grupo + 0.85, 10)` m (`spacing_per_size`, `spacing_base`, `max_spacing`). El tamaño de una unidad es el doble de su medio ancho, que es el mayor entre el radio de colisión y el alcance cuerpo a cuerpo. En el kit sale de `RtsUnit.size`.
- **Alrededor de un blanco**: la distancia al cuerpo custodiado o atacado es `max(0.5 · (1.25 · spacing + medio ancho del blanco), spacing)`.
- **Los lugares**: los `slots` de la formación (derecha, adelante en metros) se giran por `facing`, que es el yaw de la cámara.
  - Al custodiar un cuerpo se giran por el yaw del cuerpo custodiado.
  - La base es el blanco si hay uno, o el punto.
- **El reparto de lugares**:
  - **Una sola fila**: greedy por la distancia más corta entre unidad y lugar, con un sort nativo de claves `floor(d²·1000)·total + índice`, sin comparador en GDScript.
  - **Varias filas** (`match_row_size > 0`): las unidades que están más adelante según el yaw toman la primera fila, las siguientes la de atrás, y dentro de cada fila se ordenan de izquierda a derecha. Así no se cruzan los caminos; el greedy sobre 150 cuerpos cruzaba la formación.
- **Re-blanco al atacar**: si la orden es atacar a una criatura, cada unidad ataca a la criatura enemiga más cercana a su propio lugar, dentro de `retarget_range` (100 m). Si no hay ninguna, ataca el blanco original. En el kit esto necesita un contrato del juego, «el enemigo más cercano a un punto», que en la 0.4 pasa a la visión.
- **Retirada**: ordena a todas las unidades del slot, no a la selección, ir junto al mago. En el kit sería «todas las unidades de `from_slot`» más un ancla que da el juego.
- **Medición**: `last_apply_us`, `last_rows` y `last_width` son overlays de debug. `log_ai_orders` controla si las órdenes de la IA se loguean.
- **`signal requested(units, command)`**: solo para la presentación local (la voz de la orden). Se emite en el dueño antes de enviar, y nunca para la IA ni en el servidor. En el kit sería `RtsOrders.requested(order)`.

## Las órdenes de hoy (`UnitOrders.Command`)

| Orden | Qué hace la unidad | ¿Termina sola? |
|---|---|---|
| `MOVE` | Camina a su lugar y no pelea hasta llegar (`arrive_distance` = 0.5 m) | Sí, al llegar |
| `ATTACK` | Persigue a su blanco a cualquier distancia. Si el blanco desaparece, pelea con lo que ve o camina a donde estaba | Sí |
| `GUARD` | Sigue a un cuerpo amigo y pelea con los enemigos a menos de `guard_range` (50 m) de él | No |
| `GUARD_AREA` | Mantiene un punto y pelea a menos de 50 m de él | No |
| `ADVANCE` | Va a un punto peleando en el camino y se queda ahí | No |
| `RETREAT` | Se queda cerca del mago, a su radio más `retreat_distance` (10 m) | No |

Reglas de la ejecución que hoy viven en `UnitOrders`, y que el kit tiene que permitir aunque las ejecute el juego:
- **Pacifistas**: una unidad con `aggressiveness <= 0` rechaza `ATTACK` y `ADVANCE`. En el kit es `RtsUnit.accepts(command_type)`.
- **Repetición**: la misma orden con el mismo blanco (`GUARD`, `GUARD_AREA` o `ADVANCE`) solo actualiza el punto y piensa en el próximo tick (`defer_repeat_think`). La IA repite la orden de un seguidor cada vez que su líder se mueve; cada repetición costaba dos búsquedas de blanco.
- **Bloqueos**: una unidad en furia (`afflictions.raging()`) ignora toda orden. Una unidad muerta, convocándose o sin nodo `Orders` no recibe órdenes.
- **Teletransporte**: pierde la orden salvo que esté custodiando o retirándose (`warped()`).
- **Búsqueda de blancos al custodiar**: umbral `min(100, distancia al ancla) · 0.01`, y el enemigo tiene que estar dentro del rango de visión del ancla. El blanco actual pesa ×1.3, para no saltar de uno a otro.
- **Búsqueda de blancos al avanzar**: referencia 150 y umbral 0.25.
- **`think_interval_s`**: 0.25 s.

Con la `RtsOrderQueue` del kit, `MOVE` y `ATTACK` avisan `complete()` al terminar. Las órdenes que no terminan solas quedan activas hasta que llegue otra (o la siguiente de la cola, con Shift).

## Quién llama a `Orders`

| Llamador | Cómo |
|---|---|
| `scenes/orders/command/order_command.gd` | `request(units, kind, point, target, ray.camera_yaw(), formation_id)`, la orden `formation` y `retreat` |
| `scenes/orders/order_radial.gd`, `match_command.gd`, `command_input.gd` | `retreat()` y las órdenes del menú radial |
| `scenes/ai/command/ai_orders_out.gd` | `apply_for(slot, [unit], command, point, goal_node)`, el camino rápido |
| `scenes/audio/command_voice.gd` | Escucha `requested` |

## Lo propio de Sacrifice (queda como contrato o en el juego)

- `UnitBody`, `UnitBody.GROUP`, `is_dead()`, `is_summoning()` y el nodo hijo `Orders`. En el kit pasan a ser `RtsUnit` y su `RtsOrderQueue`.
- `type.aggressiveness` (pacifista): queda en el juego y se expone por `RtsUnit.accepts`.
- `BodyFacts.half_size_m()`: pasa a ser `RtsUnit.size`.
- `engagement.is_foe(node)` y `engagement.closest_foe(...)`: contrato del juego para el re-blanco y la búsqueda de blancos.
- `WizardBody` como ancla de la retirada: contrato del juego.
- `GameBody.facing_flat()` como yaw del blanco: en el kit, el `basis` del `Node3D`.
- `MpAuthority`, `MpKit.local_slot()`, `slot_for_peer` y el `@rpc`: pegamento de Sacrifice.
- `DebugLog.on(&"orders")`: el kit trae su propio log apagado o una señal.

## Qué lo cubre hoy

- **Ningún test GUT** de las órdenes ni de las formaciones.
- **La partida con semilla** (`agent/phase_b/probe.tscn -- --match-seed=7`, hash `1960276436`): la IA ordena con `apply_for`, así que la migración tiene que dar el mismo hash. Es la mejor red de seguridad del reparto, de las formaciones y del re-blanco.
- **La prueba LAN** (`agent/lan_smoke/lan_probe.tscn`): el servidor fuerza las órdenes con `apply_for` y no prueba el camino cliente → servidor (`submit_order`). Al migrar hace falta una prueba LAN que mande una orden desde el cliente.

Para la RC del kit propongo tests de:
- los `slots` de cada formación (posiciones exactas para 1, 5, 12 y 150 unidades);
- el espaciado;
- el reparto greedy y por filas, incluido que no se crucen los caminos;
- la formación de la mayoría con su desempate;
- la validación de `from_slot`;
- `max_units`;
- `to_array` y `from_array` (ida y vuelta);
- la cola: `complete` y `fail`.
