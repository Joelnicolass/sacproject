# Changelog de PropKit

## 0.2.2

- **`component_at(point, max_distance, min_area)`** y **`can_reach(a, b, max_distance, min_area)`**: una componente más chica que `min_area` (un techo, un bolsillo entre paredes junto al punto) no cuenta, y sí cuenta la tierra más cercana así de grande dentro de `max_distance`. La misma idea que el `min_area` de `closest_point`, sin llamar a los dos.

## 0.2.1

- **Iteraciones de navegación síncronas.** Con `navigation/world/map_use_async_iterations` apagado (un juego en lockstep lo pone así, para que el tick del cambio sea el mismo en todas las máquinas), `is_ready()` nunca llegaba y `updated` nunca se emitía: el mapa se reconstruye con las regiones en el mismo paso, y el nodo esperaba una iteración más del mapa que nunca llega. Ahora un mapa síncrono cuenta como al día en cuanto sus regiones se reconstruyeron. `tools/bake_scene.tscn` también termina en esos proyectos.
- **Tests**: 68.

## 0.2.0

La API del navmesh, repensada para personas. **Rompe la 0.1.**

- **El navmesh sigue a sus props.** Un prop liberado o agregado en el juego rehornea sus zonas solo (`follow_props`, los cambios de un frame juntos); un grupo agregado justo después de `add_child()` cuenta. `rebake_prop(prop)` para uno que se movió. El código del juego para talar un árbol es `tree.queue_free()`.
- **Los rehorneados se piden por nombre.** `rebake(position, radius)` (cambió el suelo o un edificio: vuelve a parsear), `rebake_prop(prop)`, `rebake_all()`. Ya no están: `rebake(areas, reparse)` ni `rebake_all(reparse)`.
- **Una señal para "los caminos ya lo ven".** `updated` (el mapa de navegación usa las últimas piezas, con su `index`), `is_ready()` (las primeras piezas están puestas; queda en true) e `is_updating()`. Ya no están: `applied`, `synced`, `is_done()`, `is_synced()`.
- **MANUAL espera solo los cambios en el juego.** Los horneados propios del kit (el arranque, un horneado guardado vencido) se aplican solos.
- **Un horneado guardado vencido nunca se usa**: primero se vuelve a hornear (`rebake_when_stale`). Un horneado guardado se carga con su índice, y entran juntos.
- **El fingerprint cubre la configuración**: la plantilla, la grilla de zonas, `height_range`, la configuración de las obstrucciones. Un horneado guardado cortado en otra grilla también emite `stale`. `extra_fingerprint` se puede poner en cualquier momento; las piezas en uso se vuelven a comparar ahí. Los horneados guardados con la 0.1 quedan vencidos: apretá «Bake».
- **El índice**: `can_reach(a, b, max_distance)` (antes `same_component`), `component_at(point, max_distance)`, y `closest_point(point, max_distance, min_area)` mide `max_distance` en el plano del suelo, sea cual sea la altura del navmesh sobre él.
- **El inspector**: lo que la mayoría de los juegos pone primero, el resto en Advanced.
- **Las herramientas de línea de comandos son escenas**: `tools/bake_scene.tscn` y `tools/scatter_scene.tscn`, así el proyecto corre como en el juego (su main loop, sus autoloads).
- **En el editor**: «Bake» guarda la escena, la hornea en otro Godot headless y la recarga (no importa dónde esté la escena en el editor); «Scatter» y «Clear» se pueden deshacer, y un scatter que no puede correr deja los props; Proyecto > Herramientas > *PropKit: Bake the open scene*; las vistas 3D y 2D dibujan el suelo de un scatter y las zonas de un nodo de zonas; avisos por un horneado guardado vencido, sin props, props parseados como geometría, un tamaño de zona o de celda que no encaja.
- **2D: sin errores de aristas.** El horneado 2D de Godot puede dejar vértices más cerca que una celda del mapa de navegación, que entonces deja aristas sin unir ("More than 2 edges…"). El kit los suelda en cada pieza; los contornos de `merge_gap` pierden sus aristas más cortas que una celda.
- **Tests**: 66, y un chequeo del editor (`PROPKIT_EDITOR_CHECK=1`, 17 chequeos en un editor real).

## 0.1.1

- **Costuras que aguantan cuando el suelo cambia de altura (3D).** El piso y el techo del horneado de cada zona caen en celdas enteras de `cell_height` desde 0. Antes salían directo de los límites del parseo: una zona rehorneada después de que el suelo bajó de su punto más bajo medía sus alturas desde otro piso, y el mapa de navegación dejaba de unirla con las zonas vecinas. `height_range` (piso, techo) les da a todas las zonas la misma caja. Un horneado guardado con 0.1.0 puede tener el piso fuera de la grilla de celdas: volvé a apretar «Bake».
- **Islas en el índice.** `PropNavIndex.component_area` (el área de cada componente en el plano del suelo) y `closest_point(point, max_distance, min_area)` (y `closest_point_2d`): la tierra más cercana, salteando un techo caminable o un bolsillo encerrado por paredes.
- **Tests**: 58.

## 0.1.0

- **Scatter** (`PropScatter3D`, `PropScatter2D`): props sobre cualquier suelo como hijos guardados y editables, desde el inspector («Scatter», «Clear»), desde código (`scatter()`), desde el menú Herramientas o headless (`tools/scatter_scene.gd`). Determinista. `PropScatterRules` compartibles: grupos según un ruido, un espacio que crece con la escala, tamaño del borde al corazón de un grupo, un tope que corta en los bordes, hundir e inclinar con la pendiente (3D).
- **Suelos** (`PropGround`): `PropFlatGround` (un rect o un contorno), `PropRayGround` (3D: rayos contra cualquier collider, una pendiente máxima), o el del juego (`extends PropGround`). **Zonas prohibidas** por grupo (`PropKeepOut`), una **máscara** pintada (`PropMask`: raleo parcial con `density_strength`, `density_invert`), **variantes** con peso (`PropVariant`).
- **Dibujo en lotes** (`PropBatch3D`): un MultiMesh por tipo de parte y por cuadrado, las partes ocultas, un cuadrado redibujado cuando se va un prop, `refresh()`, `rebuild_all()`, un gancho `mesh_of`. Nada en el editor, headless ni en un servidor dedicado.
- **Navmesh por zonas** (`PropNavZones3D`, `PropNavZones2D`):
  - zonas cuadradas que se tocan justo, una región por zona sin edge connections, horneado e índice en hilos de trabajo (tareas propias del kit: liberar el nodo o cerrar a mitad de un horneado las espera, nunca se cuelga);
  - `rebake(areas, reparse)`, con un índice de los nodos de obstrucción por zona, y pedidos que se juntan mientras hornea;
  - aplicar en AUTO o MANUAL (`bake_ready`, `has_result()`, `is_done()`, `apply()` en orden de zona), `applied` y `synced`;
  - un horneado guardado (`PropNavBake`, «Bake», `save_bake()`) que carga de una y queda `stale` cuando cambian los props o el `extra_fingerprint` del juego;
  - horneado headless para CI (`tools/bake_scene.gd`; `--check` imprime un hash reproducible del contenido);
  - `stats` (PropNavStats).
- **Obstrucciones** (`PropObstructions`): los props del grupo `prop_obstruction` cortan el navmesh como obstrucciones proyectadas a partir de sus formas:
  - 3D: Cylinder, Capsule, Sphere, Box, ConvexPolygon y CollisionPolygon3D;
  - 2D: Circle, Rectangle, Capsule, ConvexPolygon y CollisionPolygon2D;
  - `merge_gap` junta props cercanos con un cierre que nunca tapa un paso más ancho que el hueco;
  - el fingerprint detecta un horneado vencido.
- **Índice** (`PropNavIndex`): componentes conexas entre zonas, el polígono y la componente en un punto, el punto caminable más cercano, el navmesh cosido.
- **Esquiva un bug de Godot 4.7**: una navmesh que se le pone a una región durante su iteración asíncrona anterior se pierde, así que el nodo de zonas guarda la pieza hasta que la región está lista.
- **Ejemplos**: `forest_3d` y `grove_2d` (con el suelo propio del juego). **Tests**: `propkit_lab` (54).
