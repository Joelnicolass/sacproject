# scenes/bodies

What: the 74 skeletal models (`models/<tag>.tscn`) and what draws them: each has a library of clips by role (`<tag>_clips.tres`, one Animation per role with its exact length, `hit`/`shoot` markers and event calls) and a Tree with one state per role; `BodyRig` plays a role, `ClipFacts` gives the rules the same numbers.
Not: what a creature does (that is `units/`) or how long a swing lasts in the match (the rules read `ClipFacts`, they never play a clip).
Talks to: `BodyAnimator` asks `BodyRig` for a role; `BodyRig` travels the model's Tree; the Animations call `ClipEvents.fire(kind)`; `UnitBody`/`WizardBody` read `ClipFacts.of(library)`.
Edit: open `models/<tag>.tscn` (F6): `Clips` > Animation panel for a role (length, `hit` marker, method calls), `Tree` for the states; a new model is `tools/bake/new_creature.gd`.
Check: `debug/suite/clip_facts_cases.gd` (rules_suite), `debug/bodies/anim_model_audit.gd`, `debug/bodies/anim_gallery.tscn` (F6).

---

Cuerpos y modelos: animador, cajas, catalogo de modelos y `models/`. Los `.tscn` de modelos se editan en el editor; los clips de cada uno viven en `models/<tag>_clips.tres` (la biblioteca) y `models/<tag>_clips/<clip>.res` (un archivo por clip, con sus pistas de huesos, el marcador del golpe y los eventos). Un modelo nuevo sale de `tools/bake/new_creature.gd`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/bodies/`.

Un modelo propio (RFC-051): un `.glb` en `assets/custom/models/` y `tools/bake/new_creature.gd` (o Project > Tools > Sacrifice: Nueva criatura desde modelo…) escriben su `models/<tag>.tscn`, su biblioteca de clips, su `BodySize` y su `CreatureType`; ver «Crear una criatura propia desde Blender» en `docs/HOWTO.md`. Si reexportas el `.glb`, `new_creature.gd --sync` copia las pistas de huesos de nuevo a las Animations y conserva los marcadores.

`IdleSway` (idle_sway.gd): hijo opcional de un cuerpo que respira mientras esta en idle (sube y baja unos centimetros y se inclina un par de grados) moviendo solo el `pivot` que dibuja (el BodyRig), nunca el cuerpo. Es lo que anima al Sac Doctor, cuyo idle es una pose quieta (cuadro 10 de SDst, ver `sacd.tscn`: el estado `idle` conserva un `timeline_length` de un cuadro y un `start_offset` en ese cuadro; el audit lo reporta como HOLD). Cualquier modelo sin idle o con idle quieto lo suma como hijo.
