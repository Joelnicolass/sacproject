# Pieza (e): scatter de props (bosques)

Inventario de Sacrifice para que la sesión del kit decida si lo vuelve genérico, y dónde: en RtsKit, o en un kit aparte de mundo o props, porque no es RTS. Rutas desde `game/` en la rama `refactor/godot-standard`, commit `8cfe09c1d`.

Qué resuelve: plantar miles de props con colisión en un terreno, que queden como nodos editables con gizmo, que corten el navmesh sin encarecer los re-bakes y que se dibujen baratos.

## Archivos

| Archivo | Líneas | Qué hace | Destino |
|---|---|---|---|
| `scenes/map/props/forest_scatter.gd` (`ForestScatter`, `@tool Node3D`) | 220 aprox. | Botones «Scatter» y «Clear» que plantan una `PackedScene` como hijos guardados (`owner` = la escena editada). Bosquecillos por `FastNoiseLite`, más una chance baja de árboles sueltos. Primero junta candidatos, después planta del corazón del bosquecillo hacia afuera, con una grilla de separación que crece con la escala. La escala sale del «corazón» más un jitter. Hunde la base en pendiente. Tope `max_trees` | Kit: el algoritmo y los botones. El suelo y las zonas prohibidas, como contrato |
| `scenes/map/props/forest_tree.tscn` | 25 | `StaticBody3D` con hijos `Trunk` (cilindro) y `Mesh`. Grupos `forest_tree` y `nav_obstruction`. Sin script | Kit: la plantilla del prop, o un ejemplo |
| `scenes/map/nav/nav_obstructions.gd` (`NavObstructions`, estático) | 70 | Por cada nodo del grupo `nav_obstruction`, cada `CylinderShape3D` hijo (con la escala del nodo) se vuelve un polígono con `NavigationMeshSourceGeometryData3D.add_projected_obstruction`. Filtro opcional por rectángulos (las zonas del re-bake) y conteo guardado en la metadata del navmesh | Kit, si el kit tiene navegación. Es Godot puro |
| `scenes/look/vegetation/forest_draw.gd` (`ForestDraw`, `Node3D`) | 60 | En juego, dibuja los props en un `MultiMeshInstance3D` por malla y por cuadrado de `chunk_m` (256 m) y oculta la malla de cada nodo. En el editor no corre | Kit: «dibujar en lotes los props de un grupo». Godot puro |
| `tools/look/scatter_forest.gd/.tscn` | 90 | Corre el scatter headless y escribe los nodos como texto dentro del `.tscn`, para que el diff quede limpio | Kit: opcional, útil para CI |

## Contrato con el juego (lo que no puede ir al kit tal cual)

| Hoy en Sacrifice | Contrato genérico propuesto |
|---|---|
| `Terrain.of(self)`, `is_on_ground`, `height_at`, `bounds` | Un proveedor de suelo: `bounds() -> Rect2`, `height_at(x, z)` y `is_on_ground(x, z)`. Un `Callable`, o un recurso con esos métodos |
| `Terrain.ground_roles` (B = roca, A = camino) | Una máscara opcional (`Image` o `Texture2D`) con un canal para ralear y otro para prohibir |
| Zonas prohibidas por clase: `PlayerStart` 70 m, `ManaSource` 40 m, `MapBuilding` 18 m | Una lista de `{grupo: radio}` y un borde suave del 40 % del radio |
| `MatchRules.forest` y `take_away()` (opción de partida; el cliente se entera por `BiomeLink`) | Del juego: quitar el grupo antes de arrancar |
| `FloraField.dress_trees`: la tierra de la partida elige la malla de cada árbol por hash del nombre | Del juego. En el kit, un gancho `mesh_of(node) -> Mesh` en el dibujo en lotes (ya existe en `ForestDraw.build`) |
| `NavService._check_obstructions`: si el conteo guardado difiere del actual, re-bake del mapa entero | Del juego, o del kit de navegación si existe |

## Números medidos (Mac, con bajo consumo activo)

| Medición | Valor |
|---|---|
| 2000 árboles dibujados como `MeshInstance3D` sueltos | Bajan unos 10 fps |
| Los mismos en `ForestDraw` (MultiMesh por zona) | Sin costo medible |
| Escena heredada de un edificio con `MultiplayerSynchronizer` y barra de vida por árbol | De 60 a 28 fps. Por eso el prop es liviano, sin red ni vida |
| Re-bake de una zona parseando los troncos como geometría | 60 ms en el hilo principal |
| Re-bake con obstrucciones proyectadas y filtro por zona | 6,7 ms (sin bosque, 4 ms) |
| `map_get_path` de punta a punta, Alpine Meadow | 4,5 ms con bosque (59k polígonos) contra 2,0 ms sin él (23k). Sin resolver |

## Pendiente

El pasto (`scenes/look/grass/`, `GrassField` y `grass.gdshader`) va en un inventario aparte, cuando termine el rediseño con el enfoque de Ghost of Tsushima (Bezier cúbica por hoja, clumps de Voronoi, interruptor gráfico en runtime).
