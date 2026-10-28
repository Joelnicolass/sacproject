# REVIEW F146 + F147 (032c, 032d): un dueño del azar; plazos en ticks

**Veredicto: PASS.** Revisión corta, de solo lectura. El orquestador la guardó el 2026-10-17.

- **Corrientes:** los nombres son estables. `["body", name]` toma el nombre que elige el servidor (etiqueta más contador) y ese nombre viaja en el spawn. No hay `instance_id`. Cada sistema usa su propio prefijo, así que no hay choques.
- **`make_way._prune`:** el reloj solo retrocede en `begin()`, es decir, al empezar una partida nueva, así que no hay riesgo a mitad de partida. `snapshot` y `restore` son coherentes entre sí.
- **`make_way_pause`:** escribe en `_asks`. Se acepta porque es un caso de debug, y la alternativa sería una API que solo usaría el test.
- **`red_vortex`:** el servidor lo crea con un spawner y la réplica del cliente se libera junto con la del servidor.
- **Restos:** no queda ningún `get_physics_frames` de juego ni azar global en la simulación. `body_grid` y `body_separation` son cachés por paso del motor.

## No bloqueantes
1. **El lint se puede burlar:**
   - la exención de `seed_rng` vale para todo el archivo;
   - las líneas de la lista blanca se comparan por texto exacto.

   Alcanza para atrapar errores honestos, no a alguien que lo quiera esquivar.
2. **Alcance del lint:** hoy solo cubre `scenes/world`. Conviene sumar `scenes/flow` y `scenes/data`.
3. **`red_vortex`:** cuenta llamadas a `_physics_process` en lugar de usar `MatchClock`. Si alguna vez corre con `PROCESS_MODE_ALWAYS`, contaría también en pausa.
4. **`clip_pose_player`:** corta trabajo por tiempo real, pero es solo animación. Falta confirmar que ninguna regla de juego lea esa pose.
