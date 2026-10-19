# scenes/fx/

Efectos: rayos, atlas de FX, shaders y partículas del juego. Un efecto nuevo es una packed scene con su shader; el bus es `FxBus`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/fx/`.
