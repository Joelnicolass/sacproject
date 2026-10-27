# scenes/camera/

Camara del mundo (`world_camera`). Solo presentacion y entrada de camara.

La camara sigue la pose DIBUJADA del cuerpo (`DrawnPose.origin`, solo en `_process`) y corre con `process_priority = 15000`, despues de MpActor (10000); su propia interpolacion esta apagada porque se coloca cada cuadro. `FollowCamera` (lluvia, vida del aire) corre en 15001, despues de ella. `Check:` el CSV de `agent/harness/jitter_watch.gd` trae una fila `camera` por cuadro y `agent/tools/jitter_stats.py` la juzga con el criterio absoluto.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/camera/`.
