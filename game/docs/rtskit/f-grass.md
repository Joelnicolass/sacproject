# Pieza (f): el pasto

Inventario de Sacrifice para que la sesión del kit decida si va a PropKit, a otro kit o se queda en el juego. Rutas desde `game/` en la rama `refactor/godot-standard`, commit `3fb39d483`.

Qué resuelve: un campo de hojas armadas en la GPU alrededor de la cámara, al estilo de Ghost of Tsushima. La CPU solo mueve celdas y escribe uniforms; el shader coloca, descarta, dobla y pinta cada hoja.

## Archivos

| Archivo | Líneas | Qué hace | Destino |
|---|---|---|---|
| `scenes/look/grass/grass_field.gd` (`GrassField`, una LookLayer) | 762 | Anillo de celdas de 16 m alrededor del punto que mira la cámara, cada una un `MultiMeshInstance3D`. Hay tiers de cantidad por distancia y cada tier es un prefijo de las mismas hojas, así el LOD no hace «pop». Cruzar una celda solo mueve transforms. Además hornea las texturas de altura, zona y suelo desde el terreno, y maneja claros y pisoteo | Kit: el anillo, los tiers y el pisoteo. El horneado desde el terreno, como contrato |
| `scenes/look/vegetation/cell_ring.gd` (`CellRing`) | — | Qué celdas existen y su tier; centro del campo y de la atenuación | Kit |
| `scenes/look/grass/grass.gdshader` | 532 | La hoja como Bezier cúbica (el viento mueve la punta y menos el punto medio; conserva el largo), clumps de Voronoi (altura, orientación, tono y apertura desde el centro), densidad y ancho por distancia sin valle, atenuación por altura, hojas de al menos `min_blade_px` en pantalla, claros, pisoteo, color desde el suelo | Kit: casi todo. Lo que lee del terreno entra por las texturas |
| `grass_blade_mesh.gd` | 69 | Malla de la hoja (filas por segmento) y buffer de instancias por secuencia de baja discrepancia | Kit |
| `grass_type.gd`, `grass_palette.gd`, `grass_set.gd` | 265 | La forma (`GrassType`), los colores por bioma (`GrassPalette`) y el conjunto por bioma con los claros por defecto | Kit: tipo y paleta. El set es del juego |
| `grass_trample.gd`, `vegetation_clear.gd` | 199 | Huellas de las unidades (vec4 por stamp, hasta 48) y nodos de claro con gizmo | Kit |
| `grass_height.gd`, `grass_mask.gd`, `grass_bake.gdshader` | 216 | Altura del suelo en una textura y máscara de zonas desde los roles del terreno | Contrato: un proveedor de altura y de zonas |

## Contrato con el juego

| Hoy en Sacrifice | Contrato genérico propuesto |
|---|---|
| `Terrain` (altura, roles del suelo, malla y material del suelo para hornear el color) | Un proveedor de suelo: textura de altura y rect, más una textura de zonas (densidad, altura, ladera) y otra de color |
| `LookRig` (preset, `grass_toggled`), `LookQuality.grass_*` | Exports en el nodo, o un recurso de calidad propio |
| `GraphicsPrefs` «Pasto» | Del juego: el kit expone `enabled` |
| Unidades que pisan (`GrassTrample` las junta por grupo) | Grupo configurable más radio |
| Claros por defecto alrededor del altar y las fuentes, por grupo | Lista {grupo: radio, borde}, igual que las zonas prohibidas del scatter |

## Números medidos (Mac con bajo consumo activo, Tutorial Valley)

| Configuración | Hojas instanciadas | fps |
|---|---|---|
| Antes: 120/m², preset alto con escala 1,4, hojas de hasta 2,3 m | 303 000 | 16 a 22 |
| Ahora alto: 45/m², escala 0,75, radio 56 m | 207 000 | 38 (56 sin pasto) |
| Ahora medio: escala 0,75, radio 52 m, render al 67 % | 185 000 | 53 (51 sin pasto) |

Conclusión: el costo está en las hojas instanciadas. El vertex shader corre aunque la hoja se descarte por rango, y dos veces con el depth prepass. No lo explican el MSAA, el filtro de sombras, el SSIL ni la cantidad de luces: probé cada uno. Una mejora grande sería descartar en GPU antes de instanciar (compute más draw indirect, como Ghost of Tsushima), pero Godot no lo expone directo para MultiMesh.
