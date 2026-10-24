# scenes/gods/

Dioses y libros de hechizos (`GodType`, `GodBook`, desbloqueos). `GodType.structures` tiene una fila `GodStructure` (hechizo + escena de la torre) por Manalith y Shrine del dios. Cada dios es un `.tres` en `data/gods/`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/suite/`.
