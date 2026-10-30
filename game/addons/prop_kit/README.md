# PropKit

Props para mundos 2D y 3D, en tres piezas independientes:

1. **Scatter.** Planta props sobre cualquier suelo como nodos guardados y editables: grupos según un ruido, zonas prohibidas alrededor de los nodos del juego, una máscara pintada, variantes con peso.
2. **Dibujo en lotes (3D).** Dibuja miles de props en pocas llamadas de dibujo.
3. **Navmesh por zonas.** Hornea el navmesh en zonas cuadradas, con los props como obstrucciones proyectadas baratas, así un cambio rehornea solo las zonas que toca, en hilos de trabajo.

No tiene red, ni reglas de juego, ni autoload, y PropKit no depende de ningún otro kit. Cada pieza funciona sin las otras.

```bash
./install.sh --addon /path/to/godot-project prop_kit
```

Habilitá el plugin **PropKit**: agrega las herramientas del editor ([En el editor](#en-el-editor)). Los nodos del kit funcionan también sin él.

Ejemplos:

- `examples/forest_3d/forest_3d.tscn`: un bosque, los lotes y un navmesh de 16 zonas. Dos clics marcan un camino, C tala y R da otro bosque.
- `examples/grove_2d/grove_2d.tscn`: arbustos alrededor de paredes y un navmesh 2D, con las mismas teclas.

## El plano del suelo

Todos los puntos del kit están sobre el plano del suelo: **(x, z) en 3D** y **(x, y) en 2D**, en coordenadas globales, como `Vector2`. Las distancias van en las unidades del mundo: metros en 3D, píxeles en 2D.

## 1. Scatter

```
World
├── Ground              # cualquier cosa con colisión (3D, para PropRayGround)
├── Forest              # PropScatter3D: rules, ground, variants, keep_out, mask
│   ├── Prop0000        # los props: hijos guardados, se mueven o borran como cualquier nodo
│   └── …
└── Camps/Start         # en un grupo que el scatter respeta
```

1. Agregá un **PropScatter3D** (o **PropScatter2D**).
2. Poné **rules**: un `PropScatterRules`, que podés compartir entre mapas.
3. Poné **ground** (abajo). El editor dibuja su contorno.
4. Agregá **variants**: un `PropVariant` por escena, cada uno con su peso.
5. Apretá **Scatter** en el inspector. **Clear** los saca. Ctrl+Z deshace cualquiera de los dos.

Las mismas reglas y semilla dan siempre los mismos props. Volver a plantar reemplaza todos los hijos del nodo; un scatter que no puede correr (sin suelo, sin variantes) los deja como están.

Los props son hijos comunes, del dueño de la escena: se guardan y se editan con el gizmo. Desde código: `scatter.scatter(scene_owner)`. Desde un paso de build o CI (una escena, así el proyecto corre como en el juego, autoloads incluidos):

```bash
godot --headless --path . res://addons/prop_kit/tools/scatter_scene.tscn -- --scene=res://maps/forest.tscn
```

Las `rules`:

| Regla | Qué hace |
|---|---|
| `random_seed` | El ruido y cada tirada |
| `cluster_size`, `cover`, `edge`, `density`, `lone_chance` | Los grupos: bosques y claros. `cover` 1 = un scatter parejo |
| `spacing` | Espacio entre dos props de escala 1, centro a centro. Crece con la escala |
| `scale_range`, `scale_jitter` | Chicos en el borde de un grupo, grandes en el corazón, más una parte al azar |
| `keep_out_shrink` | Props más chicos cerca de una zona prohibida |
| `random_rotation` | Un giro al azar para cada prop |
| `max_count` | El tope. Corta primero en los bordes de los grupos |
| `sink`, `align_to_normal` | En 3D: hundir en el suelo e inclinar con la pendiente |

**Ground** (`PropGround`): dónde puede ir un prop. Da el área, la altura y la normal (3D), y un peso de 0 (nunca) a 1 (del todo).

- `PropFlatGround`: un rect o el contorno de un polígono, a una altura. El suelo de siempre en 2D.
- `PropRayGround` (3D): un rayo hacia abajo contra `collision_mask`, con `max_slope_deg`. Funciona con cualquier collider, en el editor y en el juego. Dejá la capa de los props fuera de su máscara.
- **El suelo del juego**: un script que `extends PropGround` (o un suelo del kit) y responde desde el terreno del juego. Necesita `@tool`, porque el scatter lo llama en el editor. `examples/grove_2d/grove_ground.gd` saca así los arbustos de las paredes.

**Zonas prohibidas** (`PropKeepOut`): `{group, radius, soft}`. No hay ningún prop a menos de `radius` de un nodo de ese grupo, y hay menos y más chicos hasta `radius * (1 + soft)`. El kit nunca conoce las clases del juego: el juego pone en un grupo sus puntos de inicio, edificios o marcadores.

**Máscara** (`PropMask`): una textura sobre un área. Un canal ralea props y otro los prohíbe (por encima de `forbid_above`).

- `density_strength` dice cuánto ralea el canal de densidad: 1 baja la chance hasta el valor del canal, 0,6 ralea como mucho un 60 %.
- `density_invert` lee el canal al revés, así blanco = menos props (la roca pintada de blanco).

## 2. Dibujo en lotes (3D)

Agregá un **PropBatch3D** y poné en **props** los padres de los props (los PropScatter3D).

- **Los lotes.** Cada `MeshInstance3D` de cada prop va a un `MultiMeshInstance3D`, uno por tipo de parte (malla, material, sombra, capas, rango de visibilidad) y por cuadrado de `chunk_size`, así la cámara descarta por cuadrado. Los nodos de los props siguen ahí, por la colisión y el navmesh; solo se ocultan sus partes. Los 1600 árboles del ejemplo son unas pocas decenas de draws.
- **Liberar un prop** redibuja solo su cuadrado, en el frame siguiente.
- **`refresh(prop)`** después de ocultar un prop o moverlo dentro de su cuadrado.
- **`rebuild_all()`** después de agregar props o de cambiar lo que responde `mesh_of`.
- **`mesh_of`** (`func(prop, part) -> Mesh`) dibuja otro aspecto para el mismo prop, como el árbol de otro bioma, sin tocar la escena.
- **Dónde no dibuja:** en el editor (cada prop se muestra solo, para moverlo), en un servidor dedicado o headless, y en una parte con materiales por superficie, que queda como está.

En 2D no hay lotes: Godot ya agrupa los sprites.

## 3. Navmesh por zonas

```
Game
├── World               # source_root: lo que se parsea (terreno, edificios) y donde están los props
│   ├── Ground
│   └── Forest          # props en el grupo prop_obstruction, en una capa que el navmesh no parsea
└── Nav                 # PropNavZones3D (o PropNavZones2D): una NavigationRegion por zona, interna
```

1. Poné los props en el grupo **`prop_obstruction`**, en la escena del propio prop. Sus formas de colisión directas y habilitadas cortan el navmesh:
   - en 3D: Cylinder, Capsule, Sphere, Box, ConvexPolygon y CollisionPolygon3D;
   - en 2D: Circle, Rectangle, Capsule, ConvexPolygon y CollisionPolygon2D.
2. Poné los props en una **capa de colisión que el navmesh no parsea**: sacala de la máscara de colisión de la plantilla y parseá colliders estáticos. Si no, el horneado los paga dos veces; el inspector avisa.
3. Agregá un **PropNavZones3D** con una plantilla `navigation_mesh`: agente, celdas, geometría parseada y máscara. Poné `source_root` y `zone_size` (un múltiplo del tamaño de celda). El editor dibuja las zonas.
4. Apretá **Bake** en el inspector. Guarda la escena, la hornea como lo va a hacer el juego (en otro Godot headless, con los autoloads del proyecto) en un `.res` junto a la escena, que es el `saved` del nodo, y recarga la escena. El inspector avisa cuando el horneado guardado ya no coincide con los props o la configuración. Desde CI o un paso de build:

   ```bash
   godot --headless --path . res://addons/prop_kit/tools/bake_scene.tscn -- --scene=res://maps/forest.tscn [--check]
   ```

   - Sin `--check`, hornea todas las zonas de cada nodo de zonas y guarda los resultados. Si un nodo no tenía `saved`, el archivo de la escena se actualiza desde una copia limpia, así no queda nada de lo que hicieron sus scripts mientras horneaba.
   - Con `--check` no escribe nada. Imprime el hash del contenido de cada horneado (dos corridas tienen que dar el mismo) y sale con 1 si un horneado no coincide con el guardado.

En el juego:

| Querés | Escribí |
|---|---|
| Esperar a que los caminos funcionen | `if not nav.is_ready(): await nav.updated` |
| Liberar o agregar un prop | Nada más: `prop.queue_free()` o `add_child(prop)`, y las zonas que toca se rehornean solas (`follow_props`) |
| Avisar que un prop se movió | `nav.rebake_prop(prop)` |
| Avisar que cambió el suelo o un edificio | `nav.rebake(position, radius)` |
| Rehornear todo | `nav.rebake_all()` |
| Saber cuándo los caminos ven un cambio | `await nav.updated`, o `nav.is_updating()` |

| Señal o llamada | Quiere decir | Ahora podés |
|---|---|---|
| `updated` | El mapa de navegación usa las últimas piezas | Pedir caminos y usar `index`: ven todos los cambios pedidos |
| `is_ready()` | Las primeras piezas están puestas; queda en true | Pedir caminos |
| `is_updating()` | Viene un cambio (un horneado, un resultado esperando, el mapa tomándolo) | Esperar `updated` si lo necesitás |
| `stale` | El horneado guardado no coincide con los props o la configuración | Nada: todas las zonas se vuelven a hornear (`rebake_when_stale`). En el editor, apretá Bake |
| `bake_ready(zones)` | Aplicar en MANUAL: un cambio en el juego ya se horneó | Llamar a `apply()` en el tick que elijas (`has_result()`) |

- **Al arrancar** carga el horneado guardado con su índice, y después llega `updated`. Si no coincide con los props o la configuración (la plantilla, la grilla de zonas, el `extra_fingerprint` del juego), el nodo emite `stale`, vuelve a hornear todas las zonas y nunca usa las piezas vencidas. Con `rebake_when_stale` apagado, las usa.
- **Los cambios en el juego** rehornean solo las zonas que tocan, en hilos de trabajo. Si solo cambiaron props no hace falta parsear: se reusa la geometría parseada y solo se leen los props cerca de esas zonas (un índice por zona, así no recorre el grupo entero). Un cambio mientras hornea se junta con el siguiente.
- **`extra_fingerprint`** (`func() -> int`): un número del juego que cambia cuando cambia algo de lo que se hornea el navmesh además de los props, como las alturas del terreno. Entra en el fingerprint, así el horneado guardado queda vencido cuando difiere. Se puede poner en cualquier momento: si las piezas en uso son las del horneado guardado, se vuelven a comparar ahí.
- **`apply_mode` MANUAL** (Advanced, para lockstep): un cambio en el juego espera a `apply()`, así todos los peers lo aplican en el mismo tick. Los horneados propios del kit (el arranque, un horneado guardado vencido) se aplican solos, así `is_ready()` nunca espera al juego.
- **`stats`** (PropNavStats) para los logs: `parse_ms`, `obstruct_ms`, `bake_ms`, `index_ms`, `zones_baked` / `zones_total`, `obstructions`, `polygons`, `components`.

**Cómo se tocan las zonas.** Cada zona se hornea con su propio filtro (`filter_baking_aabb` / `baking_rect`) y un borde (`zone_border`, 0 = según el radio del agente), con las líneas de zona ancladas en (0, 0). Las piezas se tocan justo en la línea de zona y el mapa de navegación las une sin edge connections (`use_edge_connections` queda apagado, y cada cambio sale barato). Un rehorneado parcial da las mismas piezas que hornear todo.

**Altura (3D).** El horneado mide las alturas en celdas desde el piso de cada zona, así que el piso y el techo de cada zona caen en celdas enteras de `cell_height` desde 0. Una zona rehorneada después de que el suelo bajó o subió en el juego (un cráter, un montículo) se sigue tocando con las zonas que no se rehornearon. Salen de la geometría parseada, con un margen. `height_range` (piso, techo) les da a todas las zonas la misma caja, sea cual sea la geometría cuando una zona se rehornea; lo que queda afuera no se hornea.

**Menos polígonos** (`merge_gap`):

- Los props más cerca que el hueco se vuelven una sola obstrucción. Es un cierre: cada contorno crece gap / 2, los que se tocan se unen y después se achican de nuevo. Así un paso más ancho que el hueco queda abierto; ponelo por debajo del diámetro del agente.
- Un claro cerrado por completo con huecos más angostos se rellena, porque ningún agente podría entrar ni salir. Dejá una abertura más ancha que el hueco donde tenga que haberla.
- `obstruction_sides` (los lados del contorno de una forma redonda) es la otra perilla.
- `carve` corta justo el contorno, sin el radio del agente alrededor.

**El índice** (`index`: PropNavIndex). Se arma en un hilo de trabajo con cada horneado, así está listo en el momento en que se cambian sus piezas. Responde lo que el servidor no:

| Consulta | Respuesta |
|---|---|
| `can_reach(a, b, max_distance, min_area)` | Si un agente puede caminar de `a` hasta `b`. `max_distance`: los puntos que están así de lejos del navmesh en el plano del suelo (una unidad contra una pared) cuentan desde el punto caminable más cercano; `min_area`: las islas no cuentan |
| `closest_point(point, max_distance, min_area)` | El punto caminable más cercano entre los que están a `max_distance` en el plano del suelo, sea cual sea la altura del navmesh sobre el suelo. Con `min_area`, solo sobre una componente al menos así de grande: la tierra más cercana y no el techo o el bolsillo entre paredes donde está un cuerpo |
| `component_at(point, max_distance, min_area)`, `component_area[c]` | La componente conexa en un punto (con `min_area`, la tierra más cercana así de grande, no una isla al lado), y el área de cada una en el plano del suelo (m² en 3D, px² en 2D) |
| `polygon_at(point)` | El polígono bajo un punto |
| `stitched(template)` | Todo el navmesh como una sola NavigationMesh |

En 2D, las mismas consultas terminan en `_2d`. Con `build_index` apagado no hay índice.

**2D** (`PropNavZones2D`, píxeles): el área caminable son los contornos de la plantilla, o la zona entera si no hay ninguno; los colliders parseados y los props la bloquean. `rebake(position, radius)` recibe un `Vector2`.

**Cuándo alcanza con una NavigationRegion.** Un nivel chico que no cambia en el juego se hornea bien con una NavigationRegion3D y su propio botón Bake. PropKit vale la pena cuando los props cambian en el juego, cuando el mundo es tan grande que hornearlo entero tarda, o cuando los props tienen que cortar el navmesh desde sus colliders sin un NavigationObstacle en cada uno.

## En el editor

- **Scatter** y **Clear** (nodo de scatter) se pueden deshacer: Ctrl+Z devuelve los props que reemplazaron, con las ediciones a mano.
- **Bake** (nodo de zonas) guarda la escena, la hornea como lo va a hacer el juego en otro Godot headless (corren sus autoloads y su main loop; no importa dónde esté la escena en el editor) y la recarga.
- **Proyecto > Herramientas**: *PropKit: Scatter the open scene* corre todos los scatters de la escena abierta, cada uno deshacible; *PropKit: Bake the open scene* es Bake para todos sus nodos de zonas.
- **Las vistas 3D y 2D** dibujan el contorno del suelo de un scatter (blanco) y las zonas de un nodo de zonas (azul).
- **Avisos** en un nodo de zonas: el horneado guardado no coincide con los props o la configuración (apretá Bake); ningún nodo del grupo de los props bajo `source_root`; la capa de un prop parseada como geometría; un tamaño de zona que no es múltiplo de la celda; un tamaño de celda que no es el del mapa de navegación.

## Multijugador

PropKit no tiene red. Un scatter es determinista, así que todos los peers que cargan la misma escena tienen los mismos props.

Cuando algo que bloquea cambia durante la partida (un prop talado, un edificio levantado), cada peer recibe el cambio como un dato del juego, por su propio transporte (MpKit o cualquier otro). Cada uno lo hace: libera el prop (el navmesh lo sigue) o llama a `rebake(position, radius)`. Con `apply_mode` MANUAL, cada uno aplica el resultado en el mismo tick (`bake_ready`, `apply()`). Un juego en lockstep también puede apagar las iteraciones asíncronas del mapa de navegación (`navigation/world/map_use_async_iterations`); PropKit funciona igual de las dos maneras.

## Problemas de Godot que esquiva

- **Godot 4.7: una región puede perder una actualización.** Con las iteraciones asíncronas de regiones, una navmesh que se le pone a una región mientras su iteración anterior todavía corre se pierde: el mapa se queda con la vieja para siempre. El nodo de zonas guarda la pieza nueva hasta que la región tomó la anterior, así no se pierde nada. Se reproduce solo: una región y dos navmeshes puestas con un frame de diferencia. `test_a_saved_bake_loads_and_goes_stale` lo cubre.
- **2D: vértices más cerca que una celda del mapa.** El horneador 2D de Godot puede dejar dos vértices a menos de una celda (astillas de menos de un píxel donde se juntan contornos). El mapa une las aristas por las celdas de sus puntas, así que encuentra más de dos aristas en una, avisa "More than 2 edges tried to occupy the same map rasterization space" y las deja sin unir. El kit suelda los vértices de cada pieza 2D horneada que caen en la misma celda del mapa y descarta los polígonos que colapsan. Lo cubren `test_a_weld_drops_what_the_map_cannot_tell_apart` y `test_grove_2d_runs`.

## Medido

En una Mac, headless, con el bosque del ejemplo a 1365 props, 16 zonas y 11 678 polígonos:

| Horneado | Obstrucciones (hilo principal) | Horneado (hilos de trabajo) | Índice (hilo de trabajo) |
|---|---|---|---|
| Todas las zonas | 24 ms | 32 ms | 62 ms |
| Talar un claro (1 zona de 16) | 3,3 ms | 10 ms | 61 ms |

En una ventana, el primer horneado de una escena tarda más mientras Godot compila sus shaders. Después, los 343 props del ejemplo se hornean en unos 24 ms.

Las zonas se hornean en tareas propias del kit, no en el horneado asíncrono del servidor. Así, liberar el nodo o cerrar el juego a mitad de un horneado espera a los hilos de trabajo en vez de colgarse.

## Tests

```bash
godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd
```

El resultado es `PROPKIT TESTS PASS (n)`. Los tests cubren:

- **el planner**: determinismo, espacio, zonas prohibidas, máscaras (raleo parcial, invertidas), contornos, variantes y el tope;
- **el scatter**: hijos guardados, suelo por rayos, pendientes, normales, 2D, guardar una escena;
- **las herramientas de línea de comandos**: `scatter_scene` guarda los props, `bake_scene --check` da el mismo hash dos veces y hornea una escena cuyo script usa un autoload;
- **cada forma de obstrucción**, el merge y el fingerprint;
- **la grilla de zonas**;
- **las zonas 3D y 2D**: zonas que se tocan, props que bloquean, ready y updated, props liberados, agregados y movidos que el nodo sigue, parcial = completo, `follow_props` apagado, aplicar en MANUAL los cambios en el juego mientras los horneados propios del kit se aplican solos, cambios que se juntan, horneados guardados y vencidos (por los props, la configuración o el fingerprint del juego), merge, una costura después de que el suelo bajó, un rango de altura fijo, `can_reach` cerca del navmesh, el punto más cercano en el plano y salteando islas, la soldadura 2D, iteraciones de navegación síncronas;
- **los lotes**;
- **los dos ejemplos, de punta a punta.**

Las herramientas del editor tienen su propio chequeo, un editor real haciendo lo que hace una persona (Scatter, Clear, deshacer y rehacer, una edición a mano que deshacer conserva, Bake y la escena que recarga, el aviso de horneado vencido):

```bash
PROPKIT_EDITOR_CHECK=1 godot --headless --editor --path propkit_lab
```

Imprime `EDITOR CHECK PASS`.

## Lo que no está en el kit

Esto es del juego:

- qué es un prop (vida, botín, sincronización en red);
- el transporte, y cuándo se aplica un cambio en el juego (MANUAL);
- qué más cambió además de los props (`rebake`), y los datos del suelo.

El pasto es un kit aparte, GrassKit, planeado como el siguiente.
