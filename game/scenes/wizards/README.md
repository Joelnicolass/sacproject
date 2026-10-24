# scenes/wizards/

Magos: cuerpo, spawner, forma fantasma y tipos. La estadistica concreta de cada mago es un `.tres` en `data/`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/wizards/`.

Muerte (presentacion): `GhostForm` (etapa DYING) le pide a `DeathLook` (`WizardDeathLook` + `RagdollDriver`, esqueleto fisico horneado con `tools/bake/bake_ragdolls.gd`) que el cuerpo caiga como ragdoll durante el morir (se congela a los `settle_s` del driver). En RISING la primera mitad desvanece el cuerpo caido, el cuerpo se para en idle donde esta, y la segunda mitad lo desvanece hacia el fantasma (un solo cuerpo, sin duplicado). Sin altar (GONE) el cuerpo caido se desvanece y desaparece. Un modelo sin esqueleto fisico o un servidor dedicado no cambian nada. Galeria: `debug/units/death_ragdoll_wizards.tscn` (F6).
