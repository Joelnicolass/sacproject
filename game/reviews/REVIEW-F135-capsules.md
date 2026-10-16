# REVIEW F135 (030e2b): cápsula en tierra y en vuelo

**Veredicto: NEEDS WORK** (2 bloqueantes). El orquestador guardó este archivo a partir del informe del revisor de solo lectura, el 2026-10-16.

Corrí la auditoría: `POSE AUDIT PASS` (68 modelos, 10 híbridas y 10 de vuelo, sin fallas). C2 y C3 PASS. `unit_body.gd` no se tocó.

## Bloqueantes
- **B1. En el spawn, la cápsula de tierra pisa a la de vuelo.** Un cliente que recibe el spawn de una híbrida que ya está en FLYING aplica `Flight:state` (`_fit_capsule` → vuelo). Después corre `UnitBody._ready()` → `_apply_model()`, que vuelve a crear la cápsula de tierra. Resultado: la híbrida vuela con la cápsula de tierra hasta el próximo cambio de estado. El efecto queda en el cliente (selección, picking). Arreglo: en `Flight._ready`, `body.ready.connect(_fit_capsule, CONNECT_ONE_SHOT)` o un ajuste diferido.
- **B2. El cambio de simulación no está declarado.** `info().height` de tierra cambia en 7 modelos:

  | Modelo | Antes | Después |
  |---|---|---|
  | adrg | 6,90 | 12,18 |
  | drag | 11,98 | 12,75 |
  | sprg | 3,72 | 3,91 |
  | sprl | 3,75 | 3,89 |
  | ddmn | 10,47 | 11,02 |
  | edmn | 9,52 | 10,07 |
  | fdrg | 12,96 | 15,21 |

  Esa altura la leen `MeleeAttack`, `BodySeparation`, el origen del disparo (`ranged_attack.gd:232`) y `captive.gd`. Además, el centro de la mira (`ranged_attack.gd:277`) lee `Collision`, así que en vuelo apunta a h_fly/2. El digest de seed 7 no cambia solo porque esa partida no incluye estas criaturas. El RFC se contradice: la «Decisión» dice que el digest cambia y el criterio dice que no.

## No bloqueantes
1. `_fit_capsule` duplica la forma 2 veces por vuelo. No pierde memoria; el comentario de «forma compartida» es engañoso.
2. No choca con la altura de vuelo. El único contacto nuevo posible es el techo de una estructura alta, y no se probó. Silverback aterriza 0,28 s más tarde y no está explicado.
3. `MeleeAttack`, `BodySeparation` y `HealthBar` siguen usando la altura de tierra en vuelo. Está en alcance porque el hitbox por cuadro queda fuera.
4. **Valores.**
   - Silverback 17,78: razonable.
   - Dragon: su mínimo en vuelo es −3,59 m, así que una parte queda bajo la cápsula.
   - Hellmouth pasa C3 por poco (11,02 contra 10,98).
   - Phoenix 15,21: coherente con C2.
5. La galería escribe `Flight.state`. Las capturas de fly necesitan `freeze_time`.
6. La sonda solo lee y tolera `scene == null`.
7. `BodyCatalog.info()` siempre duplica y agrega `height_flying`. Inocuo.

---

# Segunda pasada (2026-10-16): B1 con un solo dueño de la cápsula

**Veredicto: PASS.** Sin bloqueantes. B1 y B2 quedan resueltos.

- **Un solo escritor:** `BodyCollider` es el único que escribe la cápsula de `UnitBody`. Los demás cuerpos (mago, doctor, estructuras, edificios) tienen su propia cápsula, y nadie usa `UnitBody` sin `unit.tscn`.
- **Tierra igual que antes:** mismo cálculo de altura y radio, con el relleno de `BodyVisual` incluido.
- **Idempotente en cualquier orden:** spawn local, cliente que entra tarde en FLYING, `on_change` y cambio de modelo en vuelo. El `body.ready` one-shot tiene la última palabra.
- **Nadie lee `Collision` antes de `_ready`:** ni `NavGrid`, ni `BodyGrid`, ni los hooks `child_entered_tree`/`node_added`. La ventana de la cápsula de relleno se achicó respecto de HEAD.
- **RFC-023:** `refit()` es el único lugar a cambiar. La caja por cuadro entra como otra conexión en `_ready`, no como un `_process`.

## No bloqueantes
- La doble asignación de `height` compensa el clamp de `CapsuleShape3D`; sin comentario parece un error.
- `_get_configuration_warnings` no se ve porque el script no es `@tool`.
- Quedan comentarios viejos que dicen que «Flight cambia la cápsula» (`pt116_flight.gd`, nota de adrg).
- TAKEOFF y LANDING usan la cápsula de tierra; es una decisión del plan.
