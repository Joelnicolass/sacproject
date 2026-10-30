# REVIEW F117 (030f): pasivas de daño Taurock y Firefist

**Veredicto: PASS.** Sin bloqueantes. El revisor es de solo lectura; el orquestador guardó este informe el 2026-10-16.

## Criterios
- **C1 (Taurock al 50 % recibe ×0,625):** PASS en código. `korq.tres` define 0,25 + 0,75·h, con h leída antes de `_hit`, en `damage()` y en `damage_typed()`.
- **C2 (Firefist pega ×(1 + 1,5·(1−h))):** PASS en código. Con h = 0,181 da ×2,228 (ver Decisiones del RFC).
- **C3 (los NPC Taurock usan la pasiva):** PASS. Todo sale de `unit.tscn`. Queda declarado que cambia el registro de `village_taurock`.

## Fidelidad a sacengine
- **Taurock (`state.d:9010-9015`):** todos los caminos que restan vida pasan por `Health.damage` o `damage_typed`: melee, ranged, hechizo, rayo, roca, splash, guardianes y ritual. Las escrituras directas de `current` (doctor, `defeat_rule`, `captive`) fijan la vida o matan, no son golpes. El port no tiene DoT ni daño por caída.
- **Firefist:** solo melee, también contra edificios y en el reparto a guardianes (`state.d:9197`, equivalente lineal).

## Diseño y red
- `DamagePassive` es el único dueño del factor. Sin el hijo, el factor queda en ×1.
- Solo corre en el servidor (`_has_authority`) y es determinista.
- El desvío de `abilities` (conserva el slot 2) es correcto: la IA (`ai_perception`) y `hmba` dependen de él.
- Las perillas están en `.tres`, `health_fraction` queda solo en `debug/` y `unit_body.gd` no cambió.

## No bloqueantes
- **N1:** la excepción de la caída no está en el código. Hay que agregarla cuando exista daño por caída.
- **N2:** `incoming_factor(h)` no recibe ni el tipo ni el atacante. `gcil` (rayo ×0,25) va a necesitar otra firma.
- **N3:** `DamagePassive.active()` es pública pero nadie de afuera la llama.
- **N4:** texto viejo en el RFC. Ya lo corregí.
- **N5:** `load_steps` en `unit.tscn` es cosmético.
- **N6:** los `.uid` de F135 se commitearon aparte.
- **N7:** `ai_match.gd` usa `get_node("Health")`. Se acepta porque es debug.
