# REVIEW F76 — Dificultades y perfiles por dios (RFC-024, corte 024e)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS.** Sin bloqueantes.

## Control de digest
Corrí `ai_vs_trivial` seed 1, 3 min, dos veces:
- en una copia del proyecto **sin** los cambios de F76 en el camino de Normal;
- en el árbol real.

Las dos dan el mismo digest: `047a3a7c…`. **F76 no es la causa del cambio de digest**, que viene de otros cortes en paralelo. La única diferencia entre las corridas es que la guarda `is_connected` evita 14 conexiones repetidas.

## Criterios (Adenda 1.3)
| Criterio | Medido |
|---|---|
| Normal gana a Fácil | 5/5 |
| Convocatorias de Fácil frente a Normal | 16 % |
| Rechazos por recursos | 0 |
| `mana_in` de otras fuentes | 0 |
| Libro de almas | balanceado |
| `unseen_*` | 0 |
| `decision_ms` p99 | 1,45 / 1,36 |
| `ai_ms` medio | 0,27 / 0,26 |

- Sin trampa y sin RNG global nuevo.
- Composición con `.tres`, sin god-node.

## Fácil todavía juega, pero floja
En 20 min, Fácil:
- convoca de 5 a 11 veces;
- arma de 1 a 3 Manalitos;
- convierte de 1 a 5 almas;
- lanza de 38 a 71 hechizos;
- mata de 3 a 9 NPC.

Pero termina con 10 a 13 almas sin gastar y casi solo convoca Manahoars. La reserva del 30 % frena más que el intervalo de 40 s.

## Nits
1. `summon_pace` solo verifica los datos; no tiene caso unitario de la lógica.
2. `keeps_reserve` llama a estáticos privados de `AiPerception`.
3. `_last_summon_tick` se fija al decidir, no al emitir.
4. Actualizar la nota de atribución en FEATURES.
5. Revisar el balance de Fácil.

## Decisiones del orquestador
- Pasa al playtest por dificultad.
- **Balance de Fácil:** lo juzga el playtest. Si Fácil no arma un ejército visible a los 10 min, la reserva baja del 30 % al 15 % y el intervalo queda en 40 s, en una ronda de datos sin código.
- Nits 1–3: deuda menor.
- Nit 4: lo actualiza el orquestador.
