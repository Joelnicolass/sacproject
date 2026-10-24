# scenes/bodies/

Cuerpos y modelos horneados: animador, cajas, catalogo de modelos y `models/`. Los `.tscn` de modelos se generan una vez con `tools/bake/bake_body_scenes.gd` y despues se editan en el editor: el bake solo escribe los que faltan (`--force` los rehace y pisa tus cambios).

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/bodies/`.

Un modelo propio (RFC-051): un `.glb` en `assets/custom/models/` y `tools/bake/new_creature.gd` (o Project > Tools > Sacrifice: Nueva criatura desde modelo…) escriben su `models/<tag>.tscn`, su `BodySize` y su `CreatureType`; ver «Crear una criatura propia desde Blender» en `docs/HOWTO.md`.

`IdleSway` (idle_sway.gd): hijo opcional de un cuerpo que respira mientras esta en idle (sube y baja unos centimetros y se inclina un par de grados) moviendo solo el `pivot` que dibuja (el BodyRig), nunca el cuerpo. Es lo que anima al Sac Doctor, cuyo idle es una pose quieta (cuadro 10 de SDst, ver `sacd.tscn`: estado con `timeline_length` de un cuadro y `start_offset` en ese cuadro; el audit lo reporta como HOLD). Cualquier modelo sin idle o con idle quieto lo suma como hijo.
