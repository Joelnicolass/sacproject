# REVIEW F95 — Shader de sprites moderno (RFC-029, corte 029a)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK.**
- **Código de shaders: PASS.** Con los globals en 0, el resultado es aritméticamente idéntico al previo para los aditivos y para el mix sin luz.
- **Criterios 1 a 4: sin evidencia.**

## Bloqueantes
- **B1.** `lit = true` vale en todos los presets, así que el criterio 1 («idéntico en legacy») no puede cumplirse para los 11 tipos mix con `lit`. La contradicción está en el RFC.
- **B2.** El lab no permite medir:
  - el ruido base es del 13–14 %, por la semilla aleatoria;
  - la cámara `ref` queda tapada por un tronco;
  - los slots se pisan;
  - las capturas no salen a tiempo fijo;
  - `heal_slow` emite en continuo.

## Hallazgos
- **H1 (determinismo, anterior al corte).** Probado en Godot 4.7.2: `CPUParticles3D.new()` y `restart()` consumen el RNG global que siembra `MatchSeed`. En headless no pasa. Con ventana (solo o contra la IA), cada efecto mueve la secuencia de azar de la simulación.
- **H2 (niebla en aditivos).** El desvío es correcto, pero hay un arreglo barato: atenuar con la fórmula de `FOG_MODE_DEPTH`, usando tres globals que escribe el mismo código que configura el environment.
- **H3 (nits de shader).**
  - La profundidad lineal se puede calcular más barata.
  - Los defaults de `[shader_globals]` en 1,0 contradicen el comentario de `QualityApplier`.
  - Preferible `lit = false` por defecto, con `lit = true` explícito en los 11 `.tres`.
  - La sangre tiene `energy = 8` con luz: hay que mirarla.
- **H4.** El fixture extra está justificado. `heal_slow` continuo es un desvío.

## Propuesta para medir
- Correr con `--fixed-fps 60`.
- Semilla fija en las partículas (lo mismo que arregla H1) y en `HealSlow`.
- Cámara `fx` sin obstáculos, con `columns = 9` y `spacing = 4`.
- Criterio 1 sobre un fixture con solo los 18 aditivos.
- `heal_slow` con una sola partícula quieta y 6 capturas a tiempo fijo.
- Criterio 4 en una corrida de banco.

## Decisiones del orquestador (2026-10-16)
- **B1:** se acepta la recomendación. El criterio 1 se mide sobre los aditivos y el mix sin luz (fixture con los 18 aditivos). Además, `lit = false` por defecto en el script y `lit = true` explícito en los 11 `.tres`. El look `lit` de la sangre y la roca se le muestra al usuario con capturas.
- **B2:** se corrige en esta ronda, según la propuesta.
- **H2:** la atenuación por niebla en aditivos entra en este corte.
- **H1 parcial en este corte:** `use_fixed_seed` más una semilla tomada de un `RandomNumberGenerator` propio de `FxBus` en `SpriteParticles` y `SpriteEmitter`.
- **H1 de fondo:** que la simulación use un RNG propio de `MatchSeed` en vez del global. Va como tarea aparte (deuda en RULES y RFC-024).
- **Criterio 4:** se autoriza una corrida con `FrameBudget` de 027a. Si no resuelve 0,3 ms, se informa la cota medida.
- **H3:** se corrigen los defaults de los globals (o el comentario).
