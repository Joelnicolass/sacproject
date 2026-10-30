# REVIEW F96 — Pool de emisores y estelas por tiempo (RFC-029, corte 029b)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK, con 2 bloqueantes baratos.**

## PASS
- **Pool:** un emisor reusado no arrastra estado y nada queda visible para siempre.
- **Estelas:** mismo ritmo a 60 fps, sin simulación e inertes en headless.
- **Determinismo:** con ventana, el RNG global no cambia con el pool caliente.
- **Composición y MP:** sin observaciones.

## Bloqueantes
- **B1. El tope uniforme de 24 corta las estelas.**
  - `spit_trail` va a 60 puffs/s con 0,517 s de vida: necesita unos 31 emisores vivos por disparo.
  - `wrath_trail` lo comparten wrath, swarm y fireball, y necesita unos 15,5 por proyectil.
  - Con varios proyectiles en vuelo, las estelas desaparecen antes de terminar su vida.
  - **Corrección:** tope por tipo con `pool_max` en `ParticleType` (.tres), dimensionado como ritmo × vida × proyectiles simultáneos.
  - **Prueba:** varios proyectiles en vuelo, sin que ningún puff se reinicie antes de terminar su vida.
- **B2. El harness `fx_pool_probe.gd` llama a `FxBus.play`, que cambia estado.** Además hay API de producto cuyo único caller es el harness: `pool_line`, `pool_counts`, `pool_capacity` y `FxTrail.puffed`/`puffs`.
  - **Corrección:** harness de solo lectura que cuente desde el árbol, impresión desde `debug/` y medición de CPU en un bench de `res://debug/`.

## Criterio 3 (enmienda propuesta)
El costo depende de la cantidad de partículas: unos 0,13 µs por partícula. Además, a 30 fps la CPU baja de frecuencia.
- Las estelas tienen que quedar en ≤ 50 µs de media en cualquier fps.
- La ráfaga más cara (explosión de wrath) tiene que quedar en ≤ 0,5 ms por evento.

## Nits
- El comentario de `shot_look.gd:15` quedó desactualizado.
- Medir el prewarm real (con y sin) y su delta de RSS.
- `carry_rope.gd` y `red_vortex.gd` siguen instanciando sin pool (deuda de RNG).
- Faltan `f96_pool.json` y la medición con una roca real en `rock_hit`.
- `f23_fx_gallery.json` quedó roto.

## Decisiones del orquestador (2026-10-16)
- **B1 y B2:** una ronda del developer.
- **Criterio 3:** se acepta la enmienda; queda en RFC-029 §13.
- **Prewarm:** se mantiene al cargar, no perezoso dentro de la partida (por el RNG).
- **Criterio 4, `f96_pool.json`, roca real y arreglo de `f23`:** los hace el playtester.
- **`carry_rope`/`red_vortex`:** quedan en la tarea del RNG propio de `MatchSeed`.
