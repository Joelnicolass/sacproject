# scenes/components/

Componentes reusables que se cuelgan de un actor: `Health`, `ManaPool`, `SoulPurse`, `GroundSnap`, `HealthRegen` (la vida vuelve a llenarse en `refill_s` segundos), `Locomotion` (`locomotion/`: un paso de un cuerpo que camina, compartido por unidades y magos; el cuerpo lo llama en su orden). Un componente nuevo es un nodo chico con `class_name` y `@export`, sin conocer al dueno.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/suite/`.
