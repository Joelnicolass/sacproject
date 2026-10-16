# REVIEW F85 — Medición de rendimiento (RFC-027, corte 027a)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: sin bloqueantes, con nits de texto. Se cierra.**

- **H1 confirmada.** Con 150 cuerpos corren 8,0 ticks por frame (120 de 120 frames). Ocho ticks de 28–30 ms dan los 227–245 ms de frame medidos.
- **El reparto cierra** al 98–101 % cuando se usa el render medido.
- **El medidor no perturba la partida:** el digest da `328438de…` en r1 y en r2.
- **Repetición del reviewer:** su corrida cayó después del cambio de 027c3, así que los totales ya no son comparables. Lo que no depende de BodySeparation reproduce dentro de ±1 ms: `obstacles` 15,2, `move_and_slide` 1,09, base en pausa 22,24 ms y 321 draws.

## Nits (aplicados en el texto por el orquestador)
- Las restas de capas en ms de pared estaban infladas, porque también bajan los ticks por frame. La cifra limpia es el render de CPU:
  - pasto: ≈ 21 ms en la partida y 8 ms con 50 cuerpos;
  - sombras: 6,5–7,1 ms.
  - Las decisiones no cambian.
- «Explicado (render medido)» pasa a ser la métrica principal.
- «En marcha» es en realidad una orden de ataque: los cuerpos llegan y paran dentro de la ventana.
- El límite de presentación de macOS es bimodal, no un tope fijo de 120 Hz.
- `agent/perf/` es un instrumento, no un harness.
- Los barridos pueden consumir el RNG de separación si hay empates.
- `debug/orders_group.gd` divide por cero con `own_count = 0`.
