# REVIEW-RFC-030o-a (F126): catálogo, LifeShield y Protector

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Revisión
- **Fidelidad:** PASS.
  - El Protector no gasta si ya tiene escudo.
  - En T+1, una sola vez: distancia 3D centro a centro, radio 30, mismo bando, sin magos.
  - `lifeShield` rechaza si ya hay escudo.
  - Fin en el frame 1200.
  - ×0,5 salvo con `peirceShield`.
- **Un dueño:** PASS. `LifeShield` es el único dueño del escudo. No quedan escritores viejos (transparencia, sigilo). `damage_factor` solo lo escribe Rockform y `shield_factor()` es el único que multiplica escudos. El catálogo no duplica ni el gasto ni el enfriamiento.
- **Determinismo y red:** PASS. `is_on()` se deriva de `MatchClock` y en el cliente de `shown`, que se replica.
- **Regresión:** las otras 5 ramas de `_apply` quedan idénticas.
- **Reglas:** PASS.

## Enfriamiento con `delta`
Es deuda, no bloqueante. Ya existía antes de este corte y usa un paso físico fijo, sin un reloj de render de por medio. Se migra a ticks de `MatchClock` en 030o-b, que toca `ActiveAbility`.

## Menores
- **M1:** el bando se compara por `owner_slot`, no por side.
- **M2:** la fórmula de duración del escudo aparece en dos lugares, uno con un 60 literal. Unificarla en `LifeShield.start_for(ability)`.
- **M3:** si el Ent muere en T, en T+1 no reparte escudos. Confirmar con `updateProtector`.
- **M4:** un cuerpo que vuelve a la vida (Convert) no recupera la burbuja.
