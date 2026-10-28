# REVIEW F10 — El mago camina con una orden

Fecha: 2026-10-09
Reviewer: studio-reviewer (pase de solo lectura; el orquestador copió este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios F10 | FAIL |
| Arquitectura | NEEDS WORK |
| Alcance | PASS |
| Escena debug | PASS |
| Idioma | PASS |

Bloqueante: el primer tick cambia la Y de 53.4 a la del rayo (≈ 10.6). Son unos 42.8 m, unas 400 veces el paso 5.25/49. Es un salto. El playtest no corre.

## Corrección

En cada escritura de `position`, la Y no se mueve más que un `plane_step`. Si el rayo cae a otro piso, los pies se quedan en la Y que el mago ya tiene. La llegada a la meta también. No rediseñar el corte.
