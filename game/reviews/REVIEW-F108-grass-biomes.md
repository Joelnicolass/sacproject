# REVIEW F108 — Pasto en James, Stratos y Charnel (corte 022e4b)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador. Salidas en el scratchpad de la sesión (`scratchpad/out/`).

**Veredicto: NEEDS WORK.** El código y los datos están aprobados. Falta evidencia contra el original y hay dos desvíos de color.

## Medido
- **Alcance:** cero código de juego tocado. Persephone y Pyro, intactos. Mecanismo único sin ramas por bioma; `GrassSet.resolved_type()` duplica el tipo antes de aplicar la paleta.
- **Borde invisible** (±5 m de R = 54,4 m, ≤ 6 %): entre 0,1 y 1,6 % en `rts` y en ladera. En la llanura de `hill_game` la medida no vale, porque esa franja cae en el horizonte.
- **Costo:** las primitivas son iguales a Persephone (+0,03 % en Charnel). El tiempo de GPU no se puede medir en esta Mac (devuelve 0,000).
- **Dedicado:** sin `LookRig` ni `GrassField`, y `AGENT_ERRORS []`.
- **Parches a lo lejos:** ninguno. Briznas aisladas por 10.000 px: entre 0 y 0,79 (el umbral es ≤ 1).

## Bloqueante
1. Faltan las capturas del original de James, Stratos y Charnel (§11, decisión 4).

## Color (decisión del orquestador)
2. **Charnel:** el pasto en sombra sale `#54564b` (verdoso) y el suelo en sombra `#564f48`.
3. **Stratos:** el pasto en sombra sale `#9099ae` (azulado) y el suelo `#a7a4a8`.

## Nits
- **`agent/fixtures/biome_shots.gd`:** el motivo del workaround ya no existe. Volver a los flows `rfc022e4b_*` y retirar el fixture y `run_022e4b.sh`.
- **Capturas «rts» del developer:** no son una vista RTS real.
- **`sample_grass_palette.py`:** en suelos cálidos satura de más. Documentarlo o bajar el tope.
- **Stratos:** el borde del claro se nota.
- Los criterios de banco 1, 2, 3 y 5 de §12.6 ya fallaban en Pyro. Contexto, no se imputa a este corte.
- La edición en vivo de la paleta no se midió.

## Decisiones del orquestador (2026-10-16)
- **Referencia del original:** se captura con sacengine, que renderiza los datos originales y ya corre en esta Mac, en los mismos encuadres de juego y RTS. Lámina por bioma.
- **Color en sombra:** se corrige solo con datos de la paleta, sin código ni tocar la luz. Criterio: en sombra, la distancia de color entre pasto y suelo debe ser ≤ la que da Pyro en las mismas regiones; en sol, el pasto no puede alejarse del suelo más que hoy.
- **Workaround:** se retira y se usan los flows.
