# scenes/wizards/
What: the wizards of a match: `WizardBody` (the body the player or the AI drives), `WizardSpawner`, the ghost form and the types (`WizardType`, one `.tres` per wizard in `data/catalog/wizards/`).
Not: what a wizard casts (`scenes/spells/`), the picks and the lobby (`scenes/net/`, `scenes/ui/`), the size and sockets of the body (`scenes/bodies/` and `bodies/` here).
Talks to: `WizardType.body` (a `BodyFrame` scene in `bodies/`) is worn through `BodyMount`; `BodyCollider` is the only writer of the capsule and the spells read the muzzle, top and feet through `BodyFacts`; `GhostForm` asks `WizardDeathLook` to lay the body down.
Edit: `data/catalog/wizards/<nombre>.tres` (stats, `body`) · `bodies/<nombre>.tscn` (drag `Bounds/Capsule`, `Bounds/Footprint` and the `Sockets/` markers) · `wizard_body.tscn` (parts).
Check: `debug/suite/body_facts_cases.gd` (rules_suite) · `debug/units/death_ragdoll_wizards.tscn` (F6).

Magos: cuerpo, spawner, forma fantasma y tipos. La estadistica concreta de cada mago es un `.tres` en `data/`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/wizards/`.

Muerte (presentacion): `GhostForm` (etapa DYING) le pide a `DeathLook` (`WizardDeathLook` + `RagdollDriver`, esqueleto fisico horneado con `tools/bake/bake_ragdolls.gd`) que el cuerpo caiga como ragdoll durante el morir (se congela a los `settle_s` del driver). En RISING la primera mitad desvanece el cuerpo caido, el cuerpo se para en idle donde esta, y la segunda mitad lo desvanece hacia el fantasma (un solo cuerpo, sin duplicado). Sin altar (GONE) el cuerpo caido se desvanece y desaparece. Un modelo sin esqueleto fisico o un servidor dedicado no cambian nada. Galeria: `debug/units/death_ragdoll_wizards.tscn` (F6).

Cuerpo: cada mago tiene su escena de tamano y sockets en `bodies/<nombre>.tscn` (`BodyFrame`: capsula, huella, `Sockets/Muzzle` de donde sale la bola, `Sockets/Feet`). `WizardType.body` la apunta, `WizardBody.mount` (`BodyMount`) la viste y `BodyCollider` es el unico que escribe la capsula. Check: `debug/suite/body_facts_cases.gd` (rules_suite).
