# REVIEW F97 — Luces de efectos (RFC-029, corte 029c)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK, por un bloqueante.**

## Criterios
| # | Criterio | Resultado |
|---|---|---|
| 1 | Luminancia de la luz | PASS: +39,9 %, ≥ 30 % durante 0,25 s, con vuelta a tiempo |
| 2 | Tope de luces por preset | PASS en el conteo: 0/8/16 |
| 3 | Sombras | PASS: 0 |
| 4 | Costo de GPU | Sin evidencia: Metal no da tiempo de GPU |
| 5 | Sin la capa queda como antes | PASS |

- Reinicio, robo y liberación de la luz del emisor del pool: sin huérfanas.
- Headless, dedicado y RNG: sin cambios.
- Composición: correcta.
- El color de `fire_burst` coincide con el atlas de wrath, (0,59; 1; 0,62).
- El `randi()` del bioma en `rock_hit` y `wrath_splash` aparece solo en debug, sin `MatchSeed`.

## Bloqueante
- **B1.** `_weakest()` y `_open_slot()` calculan la prioridad con la envolvente actual. Durante la subida (`attack_s`) da cerca de 0, así que una chispa lejana le roba el lugar a una explosión cercana que recién empieza. Está reproducido en la prueba (caso A).
- **Arreglo:** usar el nivel 1,0 mientras `t < attack_s`, y ejercitar el robo con más de 8 luces en el mismo cuadro.

## Nits
- El nombre `fire_burst` confunde: mejor `wrath_burst`.
- La energía vale 0 en el primer cuadro.
- Las luces quedan congeladas cuando el árbol está en pausa.

## Decisiones del orquestador (2026-10-16)
- B1 se corrige en una ronda del developer, con una prueba del caso A.
- Criterio 4: se enmienda §13. Como Metal no da tiempo de GPU, alcanza con que la CPU de render y los draws no aumenten de forma medible con 8 luces activas (proxy). Se vuelve a medir si aparece una GPU que lo informe.
- Renombrar a `wrath_burst` en la misma ronda.
