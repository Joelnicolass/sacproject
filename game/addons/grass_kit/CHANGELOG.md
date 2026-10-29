# Changelog de GrassKit

## 0.2.0

Herramientas para hacerlo a mano, y los arreglos que pidió la migración de Sacrifice.

- **Pinceles en la vista 3D.** Seleccioná un GrassField3D y la vista 3D muestra arriba el menú **GrassKit** y cuatro pinceles, y abajo sus ajustes:
  - **Grass**: dónde crece el pasto;
  - **Height**: qué tan alto;
  - **Colour**: el color del suelo bajo el pasto;
  - **Kind**: dónde crece un tipo de hoja.

  Pintan los mapas del propio suelo, las texturas de las que dibuja el campo.
  - Tamaño, fuerza, caída y ruido (un borde irregular, fijo en el mundo); la presión de un lápiz.
  - Las teclas de Terrain3D: Ctrl (Cmd) borra, Shift suaviza, `[` `]` tamaño, `-` `=` fuerza, Esc baja el pincel.
  - El pasto sigue al pincel, el círculo del pincel se apoya en el suelo, y el mapa se puede mostrar encima.
  - Cada trazo es un paso del historial del editor. Los mapas se guardan dentro del suelo con la escena.
- **El menú.** Hornear el suelo, ajustar el área a los colliders, armar lo que falta; llenar, limpiar, importar o exportar como PNG el mapa del pincel.
- **Asas.** El área del suelo tiene un asa por lado: lo pintado queda donde está y la parte nueva se hornea. Un GrassClear3D tiene asas para su `radius` y su borde `soft`. Cada arrastre se deshace.
- **Deshacer** en Bake ground, los cambios de área, los rellenos, las importaciones, el nombre nuevo de un tipo y los presets de calidad.
- **Armado.** Un GrassField3D agregado en el editor se arma solo: un suelo ajustado a los colliders de la escena, el look meadow, calidad media, un viento. Si la escena ya está guardada, también hornea. Desde código: `set_up()` y `colliders_area()`.
- **GrassQuality.** Botones **Low**, **Medium** y **High**, y una línea de **costo** en vivo en el inspector; `apply_preset()`.
- **Looks.** `looks/`: meadow, autumn, lush, steppe.
- **Mapas pintados.**
  - `GrassMap`: una textura que guarda su imagen pintada y la guarda en el archivo, también headless.
  - Desde código: `GrassBrush`, y `GrassGround.paint()`, `fill_map()`, `clear_map()`, `import_map()`, `export_map()`, `map_region()` / `put_map()`.
  - `kind_maps` por el nuevo `GrassMesh.map_name` de un tipo, así los looks que comparten un nombre hacen crecer sus tipos en los mismos lugares.
  - `paint_texel_size`.
  - El alfa de `color_texture` cubre el color de suelo del look.
- **Los tipos que crecen por un mapa suman sus hojas** en vez de tomar parte de las otras, así pintar flores no ralea nada.
- **Las celdas se saltean lo despintado.** No se dibuja nada donde el mapa de densidad está vacío, y un tipo que crece por un mapa solo donde está pintado (las flores del ejemplo: 31 draws en vez de 46).
- **El suelo bajo el pasto** (pedido de Sacrifice).
  - `grasskit_ground_color()` lleva el suelo del juego al color del pasto bajo las hojas dibujadas, conservando algo de su relieve: `GrassLook.under_grass` y `under_relief`, en el nuevo global `grasskit_under`. De cerca el campo ya no se ve sombreado ni manchado.
  - `grasskit_painted_grass(xz)` (globales `grasskit_density`, `grasskit_area`) deja que el suelo del juego muestre su tierra en un sendero pintado.
- **`trample_recover`** (pedido de Sacrifice): el pasto pisado se vuelve a levantar en esa cantidad de segundos, desde un rastro que se desvanece. Un cuerpo quieto mantiene su lugar aplastado.
- **`GrassClear3D.changed`** (pedido de Sacrifice): se emite cuando cambian `radius` o `soft`.
- **`GrassGround.set_heights_image(image, rect)`** (pedido de Sacrifice): alturas desde una imagen o un PackedFloat32Array. Con 1 millón de texels tarda 0,3 s, contra 1,4 s de `set_heights()`.
- **También en `GrassGround`:**
  - `ray_hit()`: dónde un rayo encuentra el suelo (los pinceles apuntan con él);
  - `resize_area()`, `layout()` / `set_layout()`;
  - `map_empty_in()`;
  - la señal `map_painted`.
- **El plugin** agrega los globales de shader que falten cada vez que arranca el editor, así una actualización trae los suyos.
- **Ejemplo:** un sendero de tierra pintado con pasto corto a los lados, manchas de flores, una mancha seca, y pasto pisado que se vuelve a levantar; su suelo muestra tierra en el sendero.
- **Tests:** 51, y un chequeo del editor de 41 que pinta, deshace, guarda, arrastra asas y arma un campo nuevo.

## 0.1.0

- **GrassField3D**: pasto alrededor de la cámara en la GPU, en celdas cuadradas que se mueven con ella.
  - Por tipo de hoja, un MultiMesh compartido por tier, cada tier un prefijo de las mismas hojas repartidas parejo, así nada aparece de golpe.
  - Los límites de cada celda se ajustan a su suelo, así el renderer la descarta.
  - Centrado donde mira la cámara (nunca más adelante de lo alta que está), o en un nodo `center`.
  - `enabled` libera todas las celdas. No se dibuja nada headless ni en un servidor dedicado.
  - En el editor sigue a la cámara de la vista 3D dentro de `editor_radius`.
  - `stats`: celdas, hojas, draws, en total, a la vista y por tipo.
- **GrassGround**: el suelo sobre `area`, en una textura float (altura, normal, suelo).
  - Horneado desde los colliders (alturas exactas) o escrito desde los datos del juego (`set_heights`).
  - `slope_fade` raleа y acorta el pasto en suelo empinado.
  - `density_texture` y `size_texture` pintadas, y la `color_texture` del suelo.
  - `area_changed` para una parte que cambió en el juego, con la textura subida una vez por frame.
  - `bake_cost()`, y un aviso en el inspector para un horneado grande.
- **GrassLook**: un `.tres` por look (un bioma, una estación, una paleta), todo uniforms, así cambiar de look no reconstruye nada.
  - Forma: alturas de 0,25 a 0,8 m, ancho, inclinación, `align_to_normal`, matas.
  - Color: base, punta, variación, el tinte del suelo, y un color que comparten el pasto lejano y el suelo.
  - Luz: translucidez, sombra en la raíz, redondez, engrosado según la vista.
  - Viento: respuesta, aleteo, luz de las ráfagas.
- **GrassMesh**: tipos de hoja mezclados por peso (la hoja del kit o cualquier malla), cada uno un prefijo de su parte.
  - Tamaño, una máscara de dónde crece.
  - Texturas albedo, normal y ORM, alpha scissor con sombras recortadas, tinte, cuánto se aplica la paleta, y doblado desde el color de vértice.
- **GrassWind**: el viento del mundo, compartido con uniforms globales de shader.
  - Bandas de ruido sin costuras viajan a su velocidad, y las ráfagas las coronan.
  - Los cambios entran mezclándose en `blend_time` y el patrón nunca salta.
  - `time_override` lo congela; se detiene con la pausa.
  - `grass_wind.gdshaderinc` para cualquier shader; `grass_ground.gdshaderinc` deja que el suelo del juego se encuentre con el color del pasto lejano y lleve las bandas de las ráfagas.
- **GrassQuality**: densidad, radio, densidad cercana y lejana, celdas, tiers (8), segmentos (a la mitad en cada paso hacia afuera, mezclados antes de un cambio), `min_blade_pixels`, `near_fade`, sombras; `preset()`, `blades_in_ring()`, `describe()`.
- **Claros** por grupo (`GrassClearing`) y a mano (`GrassClear3D`, con su gizmo); **pisoteo** por grupo, cada cuerpo con su propio ancho.
- **El shader de la hoja**:
  - Salidas tempranas, la más barata primero, con una sola lectura del suelo.
  - Una hoja Bézier cúbica a lo largo de la normal del suelo, el empuje y el aleteo del viento, el pisoteo.
  - Filas del LOD mezcladas con la forma más gruesa, engrosado en espacio de vista, normales redondeadas que tienden a la del suelo.
  - Ancho nunca menor a `min_blade_pixels`; más bajas cerca del lente y en el borde del anillo.
  - Nada de `instance uniform`. Forward+ y Compatibility.
- **Plugin**: gizmos, y los globales de shader de GrassKit agregados a Project Settings (solo los que faltan).
- **Ejemplo** `grass_3d`: tres looks (uno con flores), una tormenta, un cráter, pisoteo, claros, un shader de suelo que se encuentra con el pasto. **Tests**: `grasskit_lab` (31), y un chequeo del editor (`GRASSKIT_EDITOR_CHECK=1`).
