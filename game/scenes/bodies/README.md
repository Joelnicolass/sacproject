# scenes/bodies/

Cuerpos y modelos horneados: animador, cajas, catalogo de modelos y `models/`. Los `.tscn` de modelos se generan una vez con `tools/bake/bake_body_scenes.gd` y despues se editan en el editor: el bake solo escribe los que faltan (`--force` los rehace y pisa tus cambios).

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/bodies/`.
