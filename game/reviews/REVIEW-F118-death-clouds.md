# REVIEW F118 (030g): nubes al morir

**Veredicto: NEEDS WORK** (1 bloqueante). El orquestador guardó este informe del revisor de solo lectura el 2026-10-16.

## Bloqueante
**B1. `tum@` cura sin fin.** En sacengine (`state.d:10446-10449`) `amount = maxHealth` cuando el SPEL dice infinito. La cura dura `ceil(maxHealth/240·60)` cuadros, con `satAdd` si ya había otra. `updateHeal` corta cuando el cuerpo está lleno o se termina el tiempo (`16293-16310`). El port, en cambio, usa `add_until_full()` con `FOREVER` y además pisa los cuadros de la cura anterior.

Arreglo: `effect.add(health.maximum)`, quitar `add_until_full` y `FOREVER`, y corregir la Decisión del RFC.

## Lo que pasa
- **Fidelidad:**
  - `goc@`: 300·(1−d/10). Afecta a criaturas, magos y edificios, sin el muerto.
  - `cen@`: 23,08/s durante 300 cuadros, a 5 m. Solo cuerpos móviles.
  - `tum@`: 30 m, mismo bando, también magos.
  - Las nubes duran 1 update.
- **Red:** el daño y la cura los resuelve solo el servidor. El humo va por `FxBus.broadcast`. El centro se captura antes del diferido. El cadáver no se libera al morir.
- **Un dueño:** `DeathCloudSpawner`. El daño pasa por `Health`, con la pasiva del Taurock. `unit_body.gd` no se tocó. El hechizo Heal no cambia.
- **Export:** solo se agregan `goc@`, `cen@`, `tum@` y la clave `args`. No hay otros cambios.

## Fuego amigo
No es una regla del proyecto: es un hueco que ya figura en AUDIT-2026-10-12:152. Sacengine tiene `friendlyFire=true` por defecto (`options.d:98`), con `sideDamageMultiplier` ×0,5 para la salpicadura y `ignoreFriendly` para el veneno (`state.d:28892-28899`, `9415-9419`). Recomendación: no arreglarlo en 030g, que cambiaría todas las salpicaduras y el digest. Hay que redactarlo como divergencia heredada y abrir un RFC aparte.

## No bloqueantes
- Sirocco (`risH`) también tiene `tum@`: hay que declararlo.
- `Poisoned` hace 300 ticks; sacengine hace 301.
- `DeathCloud.bodies_within` duplica el recorrido de `SplashDamage`.
- `HealEffect.on()` duplica el bloque de `caster.gd:421-426`.
- `health_fraction` del banco queda fuera del rango del inspector.
- Las perillas de `Poisoned` no se pueden editar.
- Hay que actualizar el árbol del RFC.
