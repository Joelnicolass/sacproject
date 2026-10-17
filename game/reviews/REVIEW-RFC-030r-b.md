# REVIEW-RFC-030r-b (F155): Viscous oil e ignite ×2

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: CHANGES** (1 bloqueante). El playtest falló en lo visual.

## Bloqueante

**B1** (`afflictions.gd:195-204`, `unit_body.gd:217,744`): `held_changed` solo se emite cuando cambia `holds()`. Si una criatura en `ROCK_FORM` está untada (`holds` ya en true) y la petrifican, la señal no sale. Entonces no se cierra Rockform ni se cancelan los ataques.

Arreglo propuesto: que `Afflictions` emita también cuando cambia `breaks_special_modes()`. Así hay un dueño único y es idempotente.

## Resto

- **Fidelidad: PASS.**
  - Caja de 1 para cualquier bando; radio 15; 900 ticks.
  - Las órdenes se borran, salvo en magos.
  - La explosión al tick siguiente hace 500 en radio 5, a nombre del tirador del aceite.
  - El ×2 se aplica una sola vez y después del bando.
  - Portadores correctos; Tickferno y Phoenix no.
- **`coexists`:** seguro, no cambia nada para los estados que no lo usan.
- **Un dueño: PASS.** `Oiled` y el ×2 solo en `Health`. La cadena de `mods` es limpia.
- **Red, determinismo y reglas: PASS.**

## Menores

- **m1:** `fhba` es el aliento-cono del Spitfire (23035-23055), no un proyectil. Hay que borrar `fhba.tres` y dejarlo para su corte.
- **m2:** `fkba.tres` está bien.
- **m3:** `log_oil`, que está encendido en todos los bancos, cambia el nombre en `dano` a nombre de nodo. Hay que revalidar `f127_expect`, `f149_expect` y `f151_expect`.
- **m4:** `land` imprime `dano` para golpes directos.
- **m5:** cuando entren Rain of Fire, Lava ball y Dragonfire, tienen que llevar `IGNITE`.
- **m6:** `holds` es más fuerte que sacengine: bloquea habilidades y deja colgado en vuelo. Falta declararlo.

## Playtest (Sonnet)

- **Mecánica: PASS.** Trogg quieto durante 131 ticks, 288 de daño, explosión en cadena, aliado sin daño.
- **FAIL visual 1:** el cuerpo untado cambia la luminancia solo en un 4 % contra la nieve.
- **FAIL visual 2 (marginal):** la explosión de fuego es un manchón de unos 60 px, sin bola de 5 m.
