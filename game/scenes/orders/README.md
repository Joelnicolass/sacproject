# scenes/orders/

Ordenes del jugador: seleccion, comandos, formaciones, radial y `world_input`. El input llama a `Orders`; no simula.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/orders/`.

## `command/`

`MatchCommand` (el nodo `MatchCommand` de `match.tscn`) solo coordina; cada hijo tiene una responsabilidad:

| Nodo | Dueño de |
|---|---|
| `CommandInput` | teclas del mundo y botón izquierdo de `%View` (clic, caja de selección) |
| `MinimapPointing` | clics sobre el minimapa (punto de suelo) |
| `ArmedCommand` | qué hechizo, estructura, habilidad u orden espera su blanco; el Caster local |
| `SpellCommand` / `AbilityCommand` / `OrderCommand` | aplicar el clic armado: lanzar, usar habilidad, ordenar |
| `PointerRay` | píxel a suelo, cuerpo, alma, cadáver o edificio |
| `GroupKeys` | las teclas de grupos 1..0 |
| `CommandFeedback` | ping de la orden, línea en `%Battle`, criaturas invocadas a la selección |

Los sockets entre hijos son `@export` en `match.tscn`; los nodos únicos del mundo (`%Battle`, `%Selection`, `%Orders`...) se leen con `%`.
