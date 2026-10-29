# RtsKit, pieza (a): RtsUnit y la selección

Inventario de Sacrifice para que la sesión del kit lo vuelva genérico. Rutas desde `game/` en la rama `refactor/godot-standard` ([Joelnicolass/sacproject#7](https://github.com/Joelnicolass/sacproject/pull/7)).

## Archivos

| Archivo | Líneas | Qué hace |
|---|---|---|
| `scenes/orders/selection.gd` (`Selection`) | 394 | La selección del jugador local y sus grupos. Es la pieza central |
| `scenes/orders/command/group_keys.gd` (`GroupKeys`) | 26 | Lee las teclas 1–0 y llama a `Selection`. No tiene estado |
| `scenes/orders/command/command_input.gd` (`CommandInput`) | ~130 | El clic izquierdo y el rectángulo: decide entre clic y arrastre, y llama a `click`, `show_box` / `select_rect` o `clear` |
| `project.godot` › InputMap | — | Las acciones `select`, `group_1`…`group_0` y `group_set_1`…`group_set_0` |

## Qué hace a una unidad propia y seleccionable

Hoy lo decide `Selection.can_select(unit)`, y ese método conoce tipos del juego:

1. es un `Node` válido y está dentro del árbol;
2. está en el grupo `UnitBody.GROUP` (`&"unit"`);
3. `seat.is_mine(unit.owner_slot)`, donde `seat` es el `MpLocalSeat` de MpKit, o sea el asiento que mira esta pantalla. En el kit pasa a ser `local_slot`, un int que el pegamento de Sacrifice carga desde el `MpLocalSeat`: el kit no conoce MpKit;
4. es un `UnitBody` y no `is_dead()`.

El mago queda afuera porque no es `UnitBody`. Una criatura muerta sale sola: `_prune()` corre cada frame en `_process` y la saca de la selección y de los grupos.

**Lo que tendría `RtsUnit`:**
- `owner_slot`;
- `selectable` (hoy equivale a «viva»);
- `kind`, para «todas las del mismo tipo» (hoy es `creature_tag`);
- `center`, el punto que se proyecta para el rectángulo (hoy `BodyFacts.of_body(unit).center`, el centro del cuerpo).

La pregunta «¿es mía?» es `owner_slot == local_slot`.

## API que usa el resto del juego

| Miembro | Quién lo usa | Notas |
|---|---|---|
| `signal changed(units: Array)` | `SelectionRoster` (HUD), `CommandVoice` (dice «selected»), `CommandFeedback` | Se emite en cada cambio, también cuando `_prune` saca una muerta |
| `units() -> Array[Node3D]` | `OrderCommand`, `AbilityCommand`, `ArmedCommand` | Copia, de la más nueva a la más vieja |
| `size()`, `has(unit)`, `count` | Flows de AgentKit (`count` existe porque AgentKit lee propiedades, no métodos) | `has` es O(1) con `_members` |
| `clear()`, `select_only(units)`, `remove(units)` | `CommandInput` (clic en el piso), lógica del juego | `remove` deja las unidades en sus grupos |
| `click(unit, screen, shift, ctrl)` | `CommandInput.left_at` | Ver «Comportamientos» |
| `show_box(from, to)`, `hide_box()`, `select_rect(from, to, additive)` | `CommandInput` | `box` es un `Control` del HUD |
| `define_group(i)`, `extend_group(i)`, `select_group(i) -> bool` | `GroupKeys` | |
| `add_summoned(unit)` | `CommandFeedback`, cuando nace una criatura propia | Entra a la selección y al grupo de convocados |
| `drop(unit)` | `GuardianBond`, por `call_group(Selection.GROUP, "drop", body)` | Sale de la selección y de todos los grupos |
| `ability() -> AbilityType` | `AbilityCommand`, `SelectionRoster` | **Propio de Sacrifice**: la habilidad activa de la criatura más nueva que tiene una. Va en el juego |
| `const GROUP := &"selection"` | `GuardianBond` | |
| Exports: `seat`, `box`, `ground`, `max_size`, `group_count`, `summon_group`, `same_type_radius`, `double_click_s`, `double_click_px` | `match.tscn` (`Input/Selection`) | `last_rect_us` es una medición de debug |

## Comportamientos a conservar

| Comportamiento | Valor o regla |
|---|---|
| Umbral para que un arrastre sea rectángulo | 3 px en x o en y (`CommandInput.rect_threshold_px`). Con Ctrl apretado, o si la cámara se está arrastrando, nunca es rectángulo |
| Doble clic | 0.333 s (`double_click_s`) **y** a menos de 10 px (`double_click_px`), o sobre la misma unidad |
| Clic | Elige solo esa unidad |
| Shift + clic | Alterna esa unidad (la saca o la pone adelante) |
| Ctrl + clic o doble clic | Todas las propias del mismo `kind` a menos de 50 m (`same_type_radius`), de la más cercana a la más lejana. Con Shift, las suma adelante |
| Rectángulo | Las propias cuyo centro proyectado cae adentro, que la cámara ve (un rayo de la cámara al centro, contra `ground` en la capa 1, no puede chocar el terreno) y que no están detrás de la cámara. Quedan de la más nueva a la más vieja (`instance_id` descendente). Shift suma |
| Clic izquierdo en el piso o en la nada, sin Shift ni Ctrl | Limpia la selección. Un clic sobre un edificio no la toca: lo muestra en el inspector |
| Orden armada | Si hay una orden esperando blanco, el clic izquierdo es para ella y no selecciona |
| Tamaño máximo | `max_size = 0` es sin límite. Con un límite (el original usa 12), lo nuevo entra adelante y empuja afuera lo último. En un grupo lleno, lo nuevo saca al primero (`_push_back`) |
| Grupos | Diez (`group_count`): Ctrl+N define, N elige (un grupo vacío no cambia nada), Shift+N suma la selección al grupo y lo elige |
| Grupo de convocados | `summon_group = 9` (la tecla 0): lo que nace entra ahí y a la selección. Definir o extender otro grupo saca esas unidades del de convocados |
| Marca visual | `_mark` prende y apaga `HealthBar.set_selected(on)` en cada unidad. En el kit sería una señal de `RtsUnit` (`selected_changed`) que el juego dibuja |
| Orden de la selección | La más nueva primero. `units()` la devuelve en ese orden y el HUD y la voz lo usan |

## Lo propio de Sacrifice (queda como contrato o en el juego)

- `UnitBody`, `UnitBody.GROUP`, `is_dead()` y `creature_tag` pasan a ser `RtsUnit`: `selectable` y `kind`.
- `MpLocalSeat` sale de la selección: el kit lee `local_slot` y el pegamento de Sacrifice lo carga.
- `BodyFacts.of_body(unit).center` pasa a ser `RtsUnit.center`, un `Marker3D` o un offset.
- `UnitHealthBar.set_selected` pasa a ser una señal del kit que dibuja el juego.
- `GuardianBond`: una criatura atada a un edificio. Ctrl+clic sobre un guardián elige los guardianes de ese mismo edificio, sean del tipo que sean, y un guardián no entra en «mismo tipo» de las libres. En el kit alcanza con que el juego cambie el `kind` del guardián (por ejemplo, el edificio). Que deje la selección y los grupos (`drop`) es una llamada del juego.
- `ability()`: queda en el juego. Lee `units()`.
- `ground`: el nodo del terreno para tapar el rectángulo. En el kit sería una máscara de colisión o un proveedor.

## Qué lo cubre hoy

- **Ningún test GUT.** Los 64 tests son de reglas puras; la selección no tiene.
- La probé jugando, y hay flows de AgentKit descartables en `agent/` que no se versionan.
- La prueba LAN (`agent/lan_smoke/lan_probe.tscn`) no toca la selección, porque las órdenes las fuerza el servidor.

Para migrar con seguridad, la RC del kit debería traer tests de: clic, Shift, Ctrl o doble clic con el radio, el rectángulo con el umbral y la oclusión, el máximo con su empuje, los grupos (definir, elegir, extender y convocados) y el `prune` de las muertas.
