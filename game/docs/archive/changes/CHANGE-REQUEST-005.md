# CHANGE-REQUEST-005: táctica de la IA en Normal (RFC-053)

Fecha: 2026-10-19. El usuario jugó contra la IA y pidió arreglarla: «la IA es el problema principal».

## Clasificación

- **Tipo:** Feature Modification.
- **Tamaño:** Medium.
- **Prioridad:** Must have.

## Conflicto

`PRD.md` dice que la dificultad Normal usa los números del original. RFC-053 agrega reglas de táctica que cambian su comportamiento:
- curar solo por debajo de un umbral;
- no dañarse con sus propios hechizos de área;
- comprobar la línea de tiro;
- rematar con foco.

La comprobación de línea de tiro también existe en el original.

## Decisión

- **Normal:** son los números del original más las reglas de táctica de RFC-053 (`AiTactics`, un `.tres` por dificultad).
- **Sin trampa:** la IA usa lo mismo que el jugador y solo lo que ve.
- **Fácil y Difícil:** cambian solo los umbrales.

## Alternativas rechazadas

- **Que Normal siga siendo 100 % el original y las reglas apliquen solo a Difícil.** Se rechaza porque el problema que reportó el usuario se ve justamente en Normal.

## Artefactos

- `PRD.md` (sección de dificultades)
- `rfcs/RFC-053-ai-and-combat-feel.md`
