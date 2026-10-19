# scenes/orders/

Ordenes del jugador: seleccion, comandos, formaciones, radial y `world_input`. El input llama a `Orders`; no simula.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/orders/`.
