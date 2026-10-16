# REVIEW F140 (031a2): MatchSetup, flag del dedicado y la regla en los clientes

**Veredicto: PASS.** No hay bloqueantes. El revisor es de solo lectura, así que este informe lo guardó el orquestador (2026-10-16).

Criterios 1 a 5 con evidencia de log (logs en el scratchpad `f140/`):
- **Dedicado con `--no-friendly-fire`:** el servidor y los dos clientes muestran «no». Sin el flag, muestran «sí».
- **En solo:** igual que en el dedicado.
- **F115:** con nivel 4 hay 7 casillas, y el dedicado con `--level=2` muestra 5.
- **`.tres` en memoria:** sin cambios. La partida usa una copia (`same=false`).
- **Digests:** seed 7, `f139_ff_clouds` y `f116`, iguales que antes.

Lo verificado en el código:
- **Nombres de los flags:** coinciden con los de sacengine (`app.d:333-355`).
- **Lectores del nivel y del fuego amigo:** todos leen `world.rules`. `Match`, `UnitSpawner` y `StructureSpawner` no leen esos campos, así que el override no rompe nada.
- **`apply_to` con el setup vacío** devuelve el mismo objeto. Es seguro porque nadie modifica `rules` en tiempo de ejecución.
- **Clientes:** no aplican el setup, y un cliente que entra tarde recibe la regla en el snapshot.
- **Diseño:** sin god-nodes ni API pensada solo para el harness, y `unit_body.gd` no se tocó.

## No bloqueantes
- **N1:** si llegan los dos flags, gana `--no-friendly-fire`; en sacengine gana el último en argv. **Ya está documentado** en `from_cli`.
- **N2:** el comentario de `high_noon.gd` dice que el setup «siempre copia». **Ya está corregido.**
- **N3:** los flags también se aplican a los bancos. Es coherente con F115. Pendiente para 031d: `--souls` va a quedar duplicado con `ai_match.gd:105-106`.
- **N4:** no se volvieron a correr seed 1, `--npcs` ni `ai_duel_seeded_ff`. El riesgo es bajo, porque con el setup vacío el camino es el mismo.
- **N5:** quedan `.uid` sueltos de cortes anteriores.
