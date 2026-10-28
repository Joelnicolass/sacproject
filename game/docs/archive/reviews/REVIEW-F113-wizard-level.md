# REVIEW F113 — Nivel del mago y libro por nivel (RFC-030, corte 030b)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK por falta de evidencia; el código está aprobado.**

## Aprobado por lectura
- **Red:** el cliente no puede mentir su nivel. `submit_summon` solo manda el tag y el servidor valida contra su propio libro.
- **Libro del cliente:** el `level` replicado reconstruye el libro.
- **Nivel 1:** queda idéntico (digests `d0cd…` y `ac6b…`, `rules_suite` PASS).
- **Composición:** limpia; F77 sin pérdidas.

## Bloqueantes de cierre (ninguno de código)
- **B1.** Las enemigas del banco están a unos 350 m, en el centro del mapa, cuando el RFC pide 60 m. Además, las criaturas pasan por el punto de atasco (1488, 1511).
- **B2.** Criterio 2 incompleto: 11 de 20 criaturas con golpe o disparo, 3 atascadas y 6 sin datos (Charnel y Stratos).
- **B3.** El criterio 3 se verificó con muertes forzadas por script, no en combate.
- **B4.** Falta la regresión online a nivel 1 (`f25_online_client`), por la propiedad 13 nueva del synchronizer.

## Nits
- **N1.** `_apply_human_god` no restaura `SacrificeFlow.pick`.
- **N2.** `_rebuild` borra los cooldowns: anotar un TODO para la XP.
- **N3.** `character_select` sigue en nivel 1; le toca a 030d.
- **N4.** `_try_summon` sale antes si `wizard_can_cast()` da falso.
- **N5.** El driver del developer está en el scratchpad.
- **N6.** El primer cuadro de cada convocatoria pasa a RFC-027.

## Decisiones del orquestador (2026-10-16)
- **B1:** ronda de datos del developer. Mover el `anchor` de los 6 `.tres` a un lugar alcanzable en ≤ 20 s de caminata, lejos de (1488, 1511), sin que las enemigas maten al mago antes de que se pueda probar (reducir la cantidad por banco si hace falta). Corregir también el `editor_description`.
- **B2:** el atasco en (1488, 1511) se acepta como desvío declarado. Existe desde antes y le pasa también a la Trogg de nivel 1. Se revisa después de 027c3 y 027d. Con B1 resuelto, las 20 criaturas tienen que pelear sin pasar por ahí.
- **B3 y B4:** los cubre el playtest con ventana, sin rellenar maná ni matar por script.
- **N2:** comentario TODO en esta ronda.
- **N1, N4 y N5:** deuda menor.
- **N3:** queda para 030d.
