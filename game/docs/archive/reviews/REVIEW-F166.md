# REVIEW F166 (030w-d, rayo instantáneo de la Locust zbba) — APPROVE

Diff 8811cd1..d92d89a. Sin correr Godot (pedido). Producto juego: seguridad web N/A.

## 1. Fidelidad (state.d 11527-11531, 22992-23006): PASS
- Instantáneo: `bursts=1, first_tick=0` en `strikes/locust_ray.tscn`; `locustShoot` crea el efecto y `updateLocustShoot` daña en su primer update y devuelve false. OK.
- Alcance: `RayStrike.max_distance` (ability range 50) = `rangedAttack.range`. OK.
- Frena en el primer cuerpo de cualquier bando distinto del tirador (`filter: id!=attacker && isValidTarget`): `ray_strike.gd:_cast` salta al tirador por RID y frena en el primer `Attackable` vivo; `foes_only=false`. OK.
- Fuego amigo: con `foes_only=false` el daño va por `ShotImpact.land` y decide Health, como `dealRangedDamage` sin filtro de bando. OK.
- Desvío: `reroll=false`, un solo rayo, precisión sorteada una vez por RangedAttack (= `getShotDirection` en locustShoot). OK.
- Sin blanco, extremo visual a 0,5 del alcance (23000): `miss_fraction=0.5`, solo el beam; log y daño intactos. OK.

## 2. Un dueño: PASS
- Reusa `RayStrike`; no hay clase nueva. `zbba.tres` sin `impact`: el daño pasa por `ShotImpact.land`, el único camino donde F164 pondrá el drenaje (030w-e).
- `miss_fraction` (`ray_strike.gd:36-39`, uso en :106-107) default 1: `seen_end == end` si 1, y solo toca `broadcast_beam`. Consumidores en el repo: `gnome_ray.tscn`, `warmonger_gun.tscn`, `locust_ray.tscn`; los dos primeros no lo setean. Gnome cubierto por f124 en quick. Phoenix heat ray no usa `RayStrike` (f125 no ejerce esta ruta; no aplica).
- `camera_target_offset` default 0: no cambia las demás escenas del banco.

## 3. Red/sim: PASS
Sin RNG nuevo ni sin semilla (no hay `reroll`); el daño cae en el tick del disparo dentro de la sim; el beam es solo presentación (FxBus). Caso f166 con digest en 3 modos y réplica PASS (reportado, no re-ejecutado).

## Nits (no bloqueantes)
- `FEATURES.md` F166 (Piezas, `locust_ray.tres`) dice atlas `ltn2` y banda de 0,2 s; el `.tres` usa `gmfl_a` y `life_s=0.26667`. Corregir el texto.
- `ray_strike.gd:106`: si el rayo frena en el suelo (`stopped=true`) se dibuja completo; en el motor el terreno no es un blanco de `collideRay` (type none, 0,5 del alcance). Solo visual y el beam es provisorio; anotar en deuda.
- `locust_ray.tres` beam: `jitter_m=0`, `bolts=1`, coherente con "provisorio".

Veredicto: APPROVE. F166 se puede cerrar con las dos notas de arriba.
