# REVIEW-RFC-030m-a (F124): Gnome y Styx

Reviewer, una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Revisión

- **Fidelidad:** PASS.
  - Gnome: el rayo sale en el mismo tick y lo frena cualquier cuerpo vivo; hace 600 directos y el fuego amigo lo decide Health.
  - Styx: golpe en T+1 sobre el centro del blanco vivo o, si no, en el punto apuntado, con la salpicadura del Mutant.
- **`ShotAim.scatter`:** idéntico a `_apply_accuracy` y en el mismo orden de sorteos. PASS.
- **`ShotImpact.land`:** es el único dueño del impacto para disparos y strikes, y es neutro. PASS.
- **Strike:** corre solo en el servidor y es hijo de `RangedAttack`. Si el tirador muere en T, el golpe del Styx igual cae en T+1. Los ticks son idempotentes y la prioridad es −1. PASS.
- **Red:** el strike no se replica; el beam y los fx van por FxBus. PASS.
- **Reglas y composición:** PASS.

## Menores

- **M1:** `ray_strike.gd:46,52` llama `source.call("shot_origin")` sin tipo. Tipar `source` antes de 030m-b.
- **M2:** `shot_origin()` es público y en este corte nadie lo llama; lo va a usar 030m-b.
- **M3:** `pt124_watch.gd:87` lee `global_transform.origin` (solo para la cámara) y `:46` lee la variable privada `_running`.
- **M4:** si el Styx se gibea en T, el strike se libera con él y el golpe no cae. Declarar como divergencia.
- **M5:** el caso «el tirador muere en T» no está ejercitado en el banco.
- **M6:** `warmonger_hit` ya se exporta, aunque es de 030m-b.
- **M7:** B2 a quemarropa (1,8 m): prueba la frenada por un aliado, pero no a mitad del recorrido.

El visual (el fogonazo, que no se ve sobre la nieve) queda fuera de esta review y se corrige aparte.
