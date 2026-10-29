# REVIEW F87 — Costo de BodySeparation (RFC-027, corte 027c3)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS con observaciones.** El código está aprobado.

## Cifras con 150 cuerpos

| Caso | Separación por tick | Ticks por frame | Frame |
|---|---|---|---|
| Quietas, antes | 24,8 ms | 8 | 245 ms |
| Quietas, después | 4,30–4,41 ms | 1,33 | 22,4 ms |
| En marcha, antes | 20,6 ms | 8 | ≈228 ms |
| En marcha, después | 5,01–5,02 ms | 2,1 | 35,4 ms |

- El digest A/B da igual en seed 1, seed 7 y seed 7 con `--npcs`.
- `rules_suite` PASS.

## Equivalencia
- **Demostrada por lectura de código.** El filtro descarta solo pares que no se superponen ni empatan, con un margen 10× sobre `is_equal_approx`. Cubre teleport, cambio de tamaño o de capa, `wizard_passes_own`, voladores y entrada o salida del árbol.
- **Fuzz hostil del reviewer.**
  - Montaje: grilla cuantizada para forzar empates, coordenadas de hasta ±8192, cambios de estado a mitad del tick y `free`/`reparent`.
  - Resultado: 2 semillas, unas 202 000 llamadas, unos 2000 sorteos y **0 diferencias**, con más de 15 000 pares por la rama de teleport.
- **`selection_many` con 150 quietas:** 364 000 llamadas y 0 diferencias.
- **`node_removed`:** no deja referencias inválidas y no pierde remociones.
- **`use_grid = false`:** queda intacto.

## Criterio 1 en marcha: 5,01–5,02 ms
Es real, no ruido, pero queda por debajo del costo del propio instrumento. Se acepta como «5,0 ms, en el umbral».

## Bloqueantes de evidencia
- **B1.** Falta la corrida «en marcha» con destino lejano que piden las notas de REVIEW-F85. Se cubre en el playtest.
- **B2.** Las corridas de c3 pisaron las de 027a en `agent/out/perf027/`. **Resuelto por el orquestador:** se restauró 027a desde el respaldo, y c3 quedó como `c3_many150_r{1,2}`.

## Nits
- **N1.** Extraer la grilla a `BodyGrid` antes de 027d.
- **N2.** Documentar que `node_removed` se conecta como efecto lateral.
- **N3.** Comentar la desigualdad del filtro.
- **N4.** El docstring de `resolve` quedó desactualizado.

## Decisiones del orquestador
- B1 va al playtest.
- N1 a N4 se hacen al inicio de 027d, que toca el mismo archivo.
