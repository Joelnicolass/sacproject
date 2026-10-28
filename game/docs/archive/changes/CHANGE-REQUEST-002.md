# CHANGE-REQUEST-002 — Bestiario completo (RFC-030)

Fecha: 2026-10-16. Pedido del usuario: «también está pendiente tener a disponibilidad todas las criaturas… en el juego original al avanzar en la campaña teníamos muchas más criaturas». Las decisiones las delegó el usuario («usa tus recomendaciones»).

## Clasificación
- **Feature Modification / Scope Change, Medium–Large, Must have.** Las criaturas son entradas del libro, y `PRD.md` dejaba «libro de hechizos completo» fuera del primer corte.

## Conflicto
- PRD «Fuera del primer corte»: se acota. **Entran** las 10 criaturas de cada dios más el Manahoar, filtradas por nivel del mago (como `getSpells` del original). **Siguen fuera** los hechizos de nivel 2 en adelante y el Shrine.
- RULES: ninguna regla violada. La IA sigue sin trampa y lee el mismo libro filtrado.

## Impacto
- Partida de producto con nivel 9: maná 1900 y vida 1950 para el mago (fiel a sacengine `state.d:2307-2311`). Cambia qué convoca la IA en partidas reales; los bancos `ai_*` quedan en nivel 1 y su digest no cambia.
- Export: unos 1,7 GB más de clips (riesgo de disco; RFC-023 los reemplazaría por `.glb`).

## Alternativas rechazadas
- **Nivel 3 con XP, como el mapa High Noon:** necesita XP, que es otro RFC. Se difiere.
- **Ocultar las criaturas con habilidades pendientes:** sería menos fiel al libro, y cada corte las va completando.

## Artefactos actualizados
- `PRD.md` (fuera del primer corte), `rfcs/RFC-030-full-bestiary.md` §13. Las F112–F133 se registran en `FEATURES.md` cuando arranque cada corte.
