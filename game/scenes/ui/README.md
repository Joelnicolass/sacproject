# scenes/ui/

Interfaz por pantalla o widget: `hud/`, `spell_book/`, `character_select/`, `minimap/`, `radial/`, `lobby/`, etc. Una pantalla nueva es una subcarpeta con su escena y su script.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/suite/`.
