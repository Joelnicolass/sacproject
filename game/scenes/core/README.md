# scenes/core/

Arranque (`boot`), flujo de escenas (`SacrificeFlow`), catalogo (`GameData`) y `debug_log`. Son los autoloads y lo que sobrevive al cambio de escena.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/suite/`.
