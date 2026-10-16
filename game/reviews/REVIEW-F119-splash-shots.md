# REVIEW F119 (030h): impacto con salpicadura

**Veredicto: PASS.** Sin bloqueantes. El orquestador guardó el informe del revisor, que es de solo lectura, el 2026-10-16.

- **Fidelidad:**
  - El área a distancia escala con `amount·max(0, 1−d/r)`, medida contra la caja de cada cuerpo, y usa la resistencia `splash_ranged`. Fuentes: `state.d:9400-9402`, `9075-9088`, `9052-9055` y `8952-8954`.
  - babt y tugt pegan el golpe entero al tocado y área en `damage_range`, sin volver a pegarle al tocado.
  - crba usa área en `effect_range`, sin golpe entero.
  - Si el disparo cae al suelo, solo hay área.
  - Las cajas de choque miden 1,25 m y 2,0 m.
- **Refactor de `SplashDamage`:** Wrath, Fireball, Swarm y el vapor siguen con `SPLASH_SPELL`. Las nubes delegan con sus grupos y sus exclusiones.
- **Red:** el daño se calcula solo en el servidor y ya no hay doble golpe. El efecto viaja por `FxBus.broadcast`.
- **Extensibilidad:** `ShotImpact` primero aplica su `_affect` y después los hijos, en orden de árbol, que es un orden fijo y visible. Nota para 030i: el aturdimiento del Flummox alcanza a todos los que estén dentro de `effectRange`, sin filtro de bando, así que debe recorrer el área con `bodies_within`.
- **Scarab:** confirmado de gravedad alta. Hoy dispara 150 de daño directo a enemigos; en sacengine cura aliados y nunca daña (`23609-23627`, `12949-12958`). Queda en 030h2, justo después de 030h.
- **Composición:** las perillas son `@export`, la variante es una escena heredada y `unit_body.gd` no se tocó. El banco no se cumple solo.

## No bloqueantes
1. `crba.tres` toma el look de `ekba` (roca). Es un cambio visual no declarado y lo tiene que juzgar el playtest.
2. Si el impacto no es un `ShotImpact`, el nodo se perdía sin liberarse. **El orquestador lo corrigió** con `node.free()`.
3. `splash_impact` recorre el área una segunda vez solo para escribir el log.
4. `box_distance` se calcula dos veces.
5. `ShotImpact.who` duplica `DeathCloud.who` y `report`.
6. `RangedShot` no tiene `class_name`.
7. A los `.tscn` les falta `uid=`.
8. El nombre `f117_splash` viene del RFC.
