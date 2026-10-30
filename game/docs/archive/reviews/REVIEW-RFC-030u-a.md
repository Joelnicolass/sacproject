# REVIEW-RFC-030u-a (F132): Quake

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Revisión

- **Fidelidad:** PASS.
  - `act()` cobra al empezar, `fire` corre sin rechequear el maná y el enfriamiento se pone solo si estaba en 0. Si se corta, el maná queda gastado.
  - Onda: f32 con `SacFloat`. Aturde con `0,5 < onda < 10`, radio de caja `onda + 0,1` en 2D y banda 2,5, sin daño.
- **`pays_upfront`:** con `false`, todas las habilidades existentes quedan idénticas.
- **Preparación cortada en el tick del corte:** es más fiel al original y no cambia el resultado de ninguna habilidad existente.
- **`QuakeRing` con `MatchClock`:** avanza en todos los peers y se congela en pausa, sin riesgo de red.
- **Un dueño:** PASS. `SacFloat` es el único para float32. `ActiveAbility` es el único dueño del maná y del enfriamiento.
- **Reglas:** PASS.

## Menores

- **N1:** el anillo avanza a saltos de tick.
- **N2:** documentación sobrante.
- **N3:** redundancia en `status`.
- **N4:** falta un assert de rama inalcanzable.
- **N5:** hay que actualizar el comentario de `SacFloat` cuando se cierre 030u-c.

## Playtest (Sonnet, una corrida)

- **Lógica: PASS.**
  - Prepara 192 ticks.
  - Aturde a Q1, Q2 y Q3, y nunca a Q4 ni a Q5.
  - J2 cortado pierde el maná sin sacudir y después da «Sin maná».
- **Anillo de tierra:** se ve expandiéndose.
- **FAIL visual 1:** los aturdidos no se distinguen desde arriba, porque el aturdido es una inclinación provisional.
- **FAIL visual 2:** el Jabberocky no cambia de pose mientras prepara, porque falta el clip. Los dos FAIL visuales son deuda del sistema de animaciones.
- **FAIL 3:** J1 pisaba la punta de la cabaña `jhut`. **Corregido:** se movió el carril y `--lanes` ahora mide la caja por especie y el radio de la cabaña. Con las posiciones viejas habría dado FAIL.
