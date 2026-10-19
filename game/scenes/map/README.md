# scenes/map/

El mapa: layout, edificios, spawns de NPC, terreno, navegacion (`nav/`) y props (`props/`). El mapa se edita en Godot; la navegacion se hornea con `tools/bake/bake_nav.tscn`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/map/`.
