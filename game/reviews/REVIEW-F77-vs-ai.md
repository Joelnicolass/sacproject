# REVIEW F77 — Partida completa contra la IA (RFC-024, corte 024f)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK, por falta de evidencia de regresión.** El código y la composición están aprobados.

## Repetido por el reviewer
- **`pt77_vs_ai` con ventana:** AGENT_OK.
  - `Wizard2` aparece a 2,8 s (Charnel sorteado).
  - La IA tiene 7 criaturas a 48 s y 12 a 105 s.
  - El HUD cambió 1 vez mientras la IA emitió 15 mensajes: el HUD propio no muestra lo que hace la IA.
  - 0 «already connected».
- **Dedicado con `--ai-slots=2` y un cliente:** AGENT_OK.
  - El cliente queda en slot 1, con `sides=0` y 32 NPC.
  - `Wizard2` se mueve y llega a 12, 16 y 19 criaturas.

## Criterios
- Todos PASS con evidencia, salvo uno: falta la regresión `f24_cast`, `f25_summon`, `f30_souls`, `f31_ghost`, `pt61b` y `pt64` **(bloqueante)**.
- Sin trampa: libro de almas balanceado, `resource_bonus` en 0, maná de otras fuentes en 0.
- Sin RPC nuevos y sin `AiSide` en los clientes. La partida de dos humanos queda igual (pt60 OK).

## Nits
1. La captura de «Derrota» sale de `ai_endgame`, no de `ai_vs_idle`.
2. `host_lan()` no vacía `solo_ai_seats`.
3. Comentario huérfano en `debug/bench_rules.gd:18-20`.
4. `max_players = seats[0].slot - 1` supone un solo asiento.
5. `run_pt77_net.sh` corre el servidor headless sin `--fixed-fps 60`.
6. `pt77_vs_ai.json` no tiene asserts sobre las criaturas del slot 2 ni sobre el HUD.
7. No está probada la victoria ni la derrota en el dedicado con IA.
8. Se editó `splash_probe.gd`, que es de otro agente.

## Choque con 030d
El modo «Contra la IA» se elige después de `character_select`, así que la fila «Nivel del mago» de 030d no puede vivir en la selección de personaje. Va junto a `%AiGod` en el boot, o hay que mover la elección del modo.

## Decisiones del orquestador (2026-10-16)
- **Una ronda de corrección del developer:**
  - correr los 6 flows de regresión;
  - corregir los nits 2, 3 y 5;
  - en el nit 6, agregar un `wait_until` de criaturas del slot 2 ≥ 1 en `pt77_vs_ai`.
- **Nit 1:** se acepta el desvío. La cifra sale de `ai_vs_idle` y la captura de `ai_endgame`.
- **Nit 4:** se anota en el RFC para mapas de 3 y 4 jugadores.
- **Nit 7:** lo cubre el playtest.
- **030d:** la fila «Nivel del mago» va junto a `%AiGod` en el boot. Se anota en RFC-030.
