# scenes/spells/

Hechizos: lanzador, tiempos, acciones (`actions/`) y proyectiles/efectos; `guardian/` guarda altares y manaliths. Un hechizo nuevo es una escena + un `.tres`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/spells/`.
