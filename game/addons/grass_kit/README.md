# GrassKit

Pasto para mundos 3D, dibujado en la GPU alrededor de la cámara:
- **Pintado a mano:** pinceles en la vista 3D pintan dónde crece el pasto, qué tan alto, el color del suelo bajo él y dónde crece cada tipo de hoja (flores). Cada trazo se deshace.
- **Celdas:** las hojas están en celdas cuadradas que se mueven con la cámara.
- **Distancia:** las celdas cercanas tienen más hojas, las lejanas menos y más anchas, y nada salta.
- **El suelo:** sale de los colliders del juego: alturas exactas, la pendiente y la normal por la que crecen las hojas.
- **El viento:** un viento compartido las mueve, y el suelo, los árboles o las partículas del juego pueden leer el mismo viento.
- **Las hojas:** la hoja propia del kit, o cualquier malla con texturas PBR, mezcladas por peso.

No tiene red, reglas de juego ni autoload, y GrassKit no depende de ningún otro kit.

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Habilitá el plugin **GrassKit**. Trae las herramientas de la vista 3D, y agrega los uniforms globales de shader de GrassKit a Project Settings (solo los que falten, también después de actualizar). Los nodos funcionan sin él.

**Ejemplo:** `examples/grass_3d/grass_3d.tscn`. Lomas de pasto con:
- un sendero de tierra pintado con los pinceles, pasto corto a sus lados, manchas de flores y una mancha seca;
- un caminante que pisa un sendero que se vuelve a levantar detrás de él;
- campamentos despejados por grupo, y un claro puesto a mano;
- un montículo demasiado empinado para el pasto;
- un suelo que se encuentra con el pasto, cerca y lejos.

Teclas:
- **1 2 3:** calidad.
- **L:** el look siguiente (verano, otoño, flores).
- **T:** una tormenta que sube o se calma.
- **G:** pasto apagado y prendido.
- **C:** un cráter bajo el mouse.

## Empezar

1. **Agregá un GrassField3D** al mundo, en el origen. Se arma solo:
   - un suelo ajustado a los colliders de la escena;
   - el look meadow;
   - calidad media;
   - un viento.

   Si la escena ya está guardada, también hornea el suelo; si no, usá **GrassKit ▸ Bake ground** cuando la guardes. El pasto se ve alrededor de la cámara de la vista 3D.
2. **Seleccionalo.** La vista 3D muestra arriba el menú **GrassKit** y cuatro pinceles, y abajo los ajustes del pincel.
3. **Pintá.** Elegí un pincel y pintá sobre el suelo; Ctrl (Cmd en Mac) borra. El pasto sigue al pincel, así ves lo que pintás donde sea.
4. **Guardá la escena.** Los mapas pintados quedan dentro del archivo del suelo, `<escena>_grass_ground.res`.

Para cambiar el look, elegí otro `.tres` de `addons/grass_kit/looks/` (meadow, autumn, lush, steppe), o duplicá uno y editalo. Para cambiar el costo, apretá **Low**, **Medium** o **High** en el inspector de la calidad y leé la línea de costo debajo de los botones.

## Pintar a mano

| Pincel | Pinta | Ctrl (Cmd) |
|---|---|---|
| **Grass** | Dónde crece el pasto (un sendero, una mancha pelada) | Sin pasto |
| **Height** | Qué tan alto crece: la **Height** de la barra contra la del look (0.5 = la mitad de alto) | Vuelve a la altura del look |
| **Colour** | El color del suelo bajo el pasto, el del selector de color de la barra | Vuelve al color de suelo del look |
| **Kind** | Dónde crece el tipo elegido en la barra (flores entre las hojas) | Acá no |

**Shift** suaviza cualquier mapa bajo el pincel.

La barra bajo la vista 3D:
- **Size**, **Strength** (cuánto avanza un toque) y **Falloff** (cuánto del radio se desvanece).
- **Noise**: un borde irregular, fijo en el mundo, así pasar de nuevo por un lugar hace crecer una sola mancha natural.
- **Erase**: borrar sin mantener Ctrl.
- **Map**: muestra el mapa del pincel sobre el suelo. Verde tiene pasto y rojo no; azul es más bajo y naranja más alto; el color mismo; magenta donde crece el tipo.
- El tamaño del mapa y las hojas a la vista.

La presión de un lápiz de tableta escala la fuerza.

| Tecla sobre la vista 3D | Hace |
|---|---|
| Botón izquierdo | Pinta |
| Ctrl / Cmd + botón izquierdo | Borra |
| Shift + botón izquierdo | Suaviza |
| `[` `]` | Pincel más chico, más grande |
| `-` `=` | Menos fuerza, más fuerza |
| Esc | Baja el pincel (la vista vuelve a seleccionar) |

Son las teclas de Terrain3D, así que te van a resultar conocidas.

**El menú GrassKit:**
- **Bake ground**.
- **Fit area to the colliders**: el área sigue a los colliders de la escena. Lo pintado queda donde está, y las partes nuevas se hornean.
- **Set up what is missing**.
- Para el mapa del pincel:
  - **Fill** con el valor del pincel: con Erase prendido, nada de pasto en ningún lado, y después pintás dónde crece;
  - **Clear**: como si nunca se hubiera pintado;
  - **Import from a PNG…**;
  - **Export to a PNG…**, para editarlo en Krita o Photoshop y volver a importarlo.
- **Show the painted map** y **Shortcuts**.

**Asas en la vista 3D:**
- El área del suelo tiene un asa en cada lado. Arrastrarla mueve ese lado, deja lo pintado donde está y hornea la parte nueva.
- Un `GrassClear3D` tiene asas para su `radius` y su borde `soft`.

Cada trazo, relleno, importación, horneado, cambio de área y arrastre de asa es un paso del historial del editor (Ctrl+Z, Ctrl+Shift+Z). Proyecto ▸ Herramientas ▸ **GrassKit: Bake the open scene** hornea todos los campos de la escena.

**Dónde viven los mapas.** Un mapa es un `GrassMap`: una textura que guarda su imagen pintada dentro del archivo del suelo. Una textura hecha en otro lado también sirve: poné `density_texture`, `size_texture`, `color_texture` o una entrada de `kind_maps` en el inspector. El primer trazo sobre ella pinta una copia que queda en el suelo, y el archivo queda como estaba. Un mapa nuevo tiene `paint_texel_size` metros por texel (0,25 por defecto, nunca más de 2048 por lado).

## En el juego

| Querés | Escribí |
|---|---|
| Cambiar de bioma, estación o la paleta de un dios | `field.look = autumn` (un `.tres`), o `field.look.tip_color = …`: solo uniforms |
| Levantar una tormenta | `field.wind.strength = 1.3`, `field.wind.direction = …`: entra mezclándose en `blend_time` |
| Que el jugador elija la calidad | `field.quality = GrassQuality.preset(GrassQuality.Level.LOW)` |
| Apagar el pasto desde las opciones | `field.enabled = false`: se liberan todas las celdas |
| Un cráter o un montículo cambió el suelo | `field.ground_changed(position, radius)`: vuelve a leer los colliders ahí |
| Escribir el suelo desde los datos propios del juego | `field.ground.set_heights_image(heights)` (rojo = metros), o `set_heights(rect, func(x, z): return terrain.height_at(x, z))` |
| Quemar o gastar el pasto en el juego | `field.ground.paint(GrassGround.DENSITY, Vector2(x, z), brush)` con un `GrassBrush` (`mode = GrassBrush.Mode.ERASE`) |
| Despejar el pasto alrededor de edificios o puntos de aparición | `clearings`: un `GrassClearing` {group, radius, soft}; o un nodo `GrassClear3D` (su señal `changed` le avisa al juego) |
| Que las unidades aparten el pasto | `trample_group`, `trample_radius` (o `grass_trample_radius` en la unidad), `trample_recover` (s) para que se vuelva a levantar |
| Centrar el pasto en lo que sigue una cámara de RTS | `field.center = unit` |
| Apuntar al pasto con el mouse | `field.ground.ray_hit(camera.project_ray_origin(at), camera.project_ray_normal(at))` |
| Mover árboles, partículas o el suelo con el mismo viento | `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"` |
| Que el suelo se encuentre con el pasto, y muestre tierra en un sendero pintado | `#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"` |
| Ver cuánto cuesta | `print(field.stats)`, `field.quality.describe()` |

## El suelo (`GrassGround`)

Dónde crece el pasto y qué tan alto está el suelo, sobre `area`.

- **Alturas.**
  - `bake()` (Bake ground, o `field.bake_ground()` desde código) tira un rayo hacia abajo en cada texel contra `collision_mask`. Guarda la altura exacta, la normal del suelo y si había suelo, todo en una textura float (`data`), así una hoja la lee una sola vez.
  - Un juego con sus propios datos de altura los escribe con `set_heights_image(image, rect)`: el rojo de la imagen es la altura en metros, NAN donde no hay suelo. Alturas en un PackedFloat32Array arman una imagen con `Image.create_from_data(w, h, false, Image.FORMAT_RF, heights.to_byte_array())`. Con 1 millón de texels tarda unos 0,3 s, contra 1,4 s de `set_heights(rect, sampler)`, que llama a `func(x, z) -> float` por texel.
- **Resolución.** Con `texel_size` de como mucho un cuarto de los triángulos del terreno, una raíz queda a menos de 5 cm del suelo exacto, aun en pendientes ásperas y empinadas (`test_roots_sit_on_the_ground` lo mide a 30° y 60°). Sobre un plano la lectura es exacta en cualquier pendiente; el error solo viene de los pliegues entre triángulos.
- **Tamaño.** `bake_cost()` dice cuántos rayos tira un horneado completo y cuántos megabytes guarda (16 bytes por texel), y el inspector avisa pasando los 64 MB. Un mapa de 2560 m a 0,5 m son 26 millones de rayos y 400 MB; a 2,5 m son 16 MB.
- **Pendientes.** `slope_fade` (grados): desde el primero, las hojas ralean y se acortan; pasado el segundo, ninguna. Las hojas crecen por la normal del suelo en su base (`look.align_to_normal`) y se enderezan hacia la punta. Su ancho queda sobre la pendiente, así ninguna base se hunde en una ladera.
- **Mapas pintados**, estirados sobre `area` (los pintan los pinceles; desde código `paint()`, `fill_map()`, `clear_map()`, `import_map()`, `export_map()`):
  - `density_texture` (rojo): blanco = pasto, negro = nada.
  - `size_texture` (rojo): 0,5 = como dice el look, negro = plano, blanco = el doble de alto.
  - `color_texture`: el color del suelo, que va a la base de las hojas. Su alfa es cuánto cubre el `ground_color` del look. Una textura hecha en otro lado también sirve: el mapa de albedo del juego, o su suelo renderizado una vez desde arriba, **tal como se ve con el color de GrassKit bajo el pasto** (más abajo), así las raíces coinciden con lo que se ve entre ellas.
  - `kind_maps`: dónde crece cada tipo con un `map_name` (rojo).
- **Mover el área.** `resize_area(rect)` mueve sus bordes dejando las alturas y los mapas donde están en el mundo. Es lo que usan Fit area y las asas.
- **Cambios en el juego.** Hornear o escribir alturas emite `area_changed(rect)` en el acto. El campo les da límites nuevos solo a las celdas de ahí. Pintar emite `map_painted(map)`. En los dos casos, las texturas suben a la GPU una vez al final del cuadro, tengan los cambios que tengan.

## El look (`GrassLook`)

Un `.tres` para duplicar y editar en el inspector; un juego tiene varios (una pradera, un desierto, nieve, flores) y los cambia en el juego. `looks/` trae cuatro para empezar: meadow, autumn, lush y steppe.

- **Forma:** `height_range` (de 0,25 a 0,8 m por defecto, justo para un RTS), `width`, `tip_width`, `lean`, `align_to_normal`, `clump_size`. Las hojas de una mata son más altas cerca de su centro, se inclinan hacia afuera y comparten su tono.
- **Color:**
  - `base_color` y `tip_color`, con `color_variation`;
  - `ground_tint` (cuánto del color del suelo se ve en la base) y `ground_color` (donde el suelo no tiene mapa de color);
  - `fade_to_ground` y `far_grass` (donde el pasto lejano y el suelo del juego se encuentran, más abajo);
  - `roughness`.
- **Luz:** `translucency` (luz a través de las hojas desde atrás, más en la punta fina), `root_shade`, `roundness` (la normal de una hoja gira hacia afuera en sus bordes), `view_thicken` (las hojas vistas de canto se ensanchan, así un campo nunca se ve ralo de costado).
- **Viento:** `wind_response`, `flutter` (el temblor propio de cada hoja a través del viento), `gust_lighten` (las ráfagas aclaran las puntas y su brillo, así las olas se leen de lejos).
- **El suelo bajo el pasto:**
  - `under_grass` (0,6): cuánto toma el suelo del juego el color del pasto bajo las hojas dibujadas, así lo que se ve entre ellas se lee como más pasto y no como suelo pelado y manchado;
  - `under_relief` (0,35): cuánto de sus propias luces y sombras conserva ahí.
- **Mallas:** los tipos de hoja (más abajo).

Cada valor es un uniform del shader: otro look, o un valor cambiado, no reconstruye nada. Solo otras mallas, u otros pesos, vuelven a armar las mallas del campo.

## Tipos de hoja (`GrassMesh`)

`look.meshes` mezcla tipos de hoja por `weight`: por ejemplo 90 % la hoja del kit, 8 % una mata, 2 % una flor. Vacío es solo la hoja del kit.

- **La malla.** `mesh` es cualquier malla, como un `.glb` de Blender: y hacia arriba, la raíz en y 0. Se escala a la altura de hoja del look (por `size`) y se gira al azar. Su base crece por la normal del suelo y su punta queda derecha. El viento y el pisoteo la doblan más cuanto más alto está un vértice, o según el rojo de su color de vértice con `bend_from_color`. Vacío = la hoja del kit, una curva de Bézier cúbica.
- **Material.**
  - `albedo_texture`, `normal_texture`, `orm_texture` (oclusión, rugosidad, metálico);
  - `tint`;
  - `alpha_scissor` para pétalos o tarjetas recortadas. Usa el shader recortado, y la sombra de la hoja también se recorta. Dejalo en 0 para hojas comunes: opaco cuesta menos.
- **La paleta.** `palette` es cuánto tiñen los colores del look a este tipo: 1 para hojas, 0 para una flor con sus propios colores.
- **Dónde.**
  - `map_name` es el nombre del mapa pintado del suelo para este tipo. El pincel **Kind** lo pinta, y le pone nombre al tipo en su primer trazo. Los looks que comparten un nombre hacen crecer sus tipos en los mismos lugares, como las flores en verano y en otoño. Un nombre sin mapa pintado todavía crece en todos lados.
  - `mask_texture` es una textura propia (rojo sobre el área del suelo), que se usa cuando el suelo no tiene un mapa con ese nombre.
- **Cómo se reparten las hojas.**
  - Los tipos que crecen en todos lados se reparten una secuencia compartida con una tirada fija sobre sus pesos, así cada uno es un prefijo de su parte y la densidad sigue cambiando suave con la distancia.
  - Un tipo que crece por un mapa tiene puntos propios y suma su parte donde crece: pintar flores deja el resto de la pradera igual de densa.
  - Una celda dibuja un tipo así solo donde su mapa está pintado.
- **Para copiar:** `examples/grass_3d/flower.tres` es una flor hecha así: `flower_mesh.tres`, `flower_petals.png`, alpha scissor 0,5, palette 0, `map_name` "flower". El look de flores del ejemplo la hace crecer en las manchas pintadas.

## El viento (`GrassWind`)

El viento del mundo, compartido: el campo lo hace avanzar y cualquier shader lo puede leer.

- **Ajustes:** `direction`, `strength` (0 calma, 1 tormenta), `speed` (qué tan rápido viajan las bandas), `scale` (el tamaño de una banda) y `noise` (una textura sin costuras; vacía = la del kit).
- **Sin saltos.** La posición del patrón se lleva cuadro a cuadro, así una dirección o velocidad nueva nunca hace saltar el campo. Una dirección o fuerza nueva se alcanza en `blend_time`.
- **Congelado.** `time_override` (0 o más) lo congela, para tests y capturas.
- **Pausa.** Se mueve con el procesamiento del campo, así se detiene mientras el árbol está en pausa (modo de proceso por defecto). Poné el campo en procesar siempre para que siga soplando.
- **Compartido.** Varios campos pueden compartir un viento; avanza una vez por cuadro.
- **En las hojas.** Una brisa pareja más ráfagas donde crestan las bandas del ruido. Cada hoja también tiembla a través del viento con su propia fase, y las ráfagas aclaran las puntas que pasan.
- **Para otros shaders.** `field/grass_wind.gdshaderinc` da `grasskit_wind_wave(xz)` (0..1), `grasskit_wind_gust(xz)` y `grasskit_wind_push(xz)`.

## El suelo del juego (`grass_ground.gdshaderinc`)

Incluilo en el shader del suelo del juego así el suelo y el pasto se encuentran sin costura:

```glsl
#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"
...
float grass = grasskit_painted_grass(xz);          // el mapa de densidad pintado: 0 en un sendero
vec3 ground = mix(soil, ground_color, smoothstep(0.1, 0.7, grass));
ALBEDO = grasskit_ground_color(ground, xz, grass) * (1.0 + grasskit_ground_bands(xz, 0.12));
```

- `grasskit_ground_color(rgb, xz, grass_here)`:
  - bajo las hojas dibujadas, el suelo toma el color del pasto según el `under_grass` del look y conserva `under_relief` de sus luces y sombras;
  - desde donde las hojas se desvanecen, va al color al que se desvanece el pasto lejano, así el borde del pasto dibujado nunca se ve.
- `grasskit_painted_grass(xz)`: dónde el mapa de densidad del suelo hace crecer pasto (1 donde no hay nada pintado, 0 fuera del área). Un sendero pintado con el pincel Grass puede mostrar la tierra propia del juego.
- `grasskit_ground_bands(xz, amount)`: bandas claras donde las ráfagas cruzan el suelo.

Las lomas del ejemplo usan las tres.

Los valores son uniforms globales de shader:
- `grasskit_wind`, `grasskit_wind_offset`, `grasskit_wind_time`, `grasskit_wind_noise`;
- `grasskit_field`, `grasskit_grass`, `grasskit_under`;
- `grasskit_density`, `grasskit_area`.

El plugin agrega los que falten a Project Settings cada vez que arranca el editor y no toca ningún otro. Deshabilitarlo los deja, por si un shader del juego los lee. Sin el plugin, un campo los declara antes de que compilen sus propios shaders. Un solo campo por mundo los escribe.

## La calidad (`GrassQuality`)

| Ajuste | Qué hace |
|---|---|
| `density` | Hojas por m² cerca del centro |
| `radius`, `near_radius`, `far_density` | Densidad completa hasta `near_radius`, raleando hasta `far_density` en `radius`, nada más allá |
| `cell_size`, `tiers` | Celdas del anillo, y cuántos juegos de menos hojas por distancia |
| `segments` | Los segmentos de las hojas más cercanas (1, 2, 4 u 8), a la mitad en cada paso hacia afuera hasta un triángulo |
| `min_blade_pixels` | Las hojas lejanas se ensanchan en vez de achicarse por debajo de estos píxeles (sin parpadeo) |
| `near_fade` | Las hojas así de cerca del lente se achican hasta el suelo, así ninguna llena la pantalla |
| `cast_shadows` | Las hojas proyectan sombra |

En el inspector, los botones **Low**, **Medium** y **High** ponen un preset (un paso que se deshace), y la línea **cost** debajo dice cuánto instancia un anillo mientras ajustás. Desde código: `preset(LOW | MEDIUM | HIGH)`, `apply_preset()`, `blades_in_ring()`, `describe()`.

`field.stats` (GrassStats) cuenta lo que se dibuja ahora:
- celdas y hojas, en total y a la vista;
- las hojas a la vista de cada tipo;
- las draw calls (una por tipo por celda a la vista: un tipo agregado a un look suma una draw por celda donde crece).

Las hojas son instancias, así que su shader de vértices corre aunque después el shader las ralee; las que están a la vista son las que paga la GPU.

## Cambios suaves

Ningún cambio con la distancia o en el juego es un escalón:

- **Densidad:** una hoja se va cuando su rango pasa la densidad. Es la misma hoja en cada tier, así menos hojas nunca saltan, y las que quedan se ensanchan.
- **Segmentos:** antes de que una celda pase a una malla con la mitad, cada fila que le falta a la malla más gruesa ya se mezcló con sus vecinas.
- **El borde:** las hojas se acortan hasta nada en el radio.
- **Color a distancia:** las hojas se desvanecen a un color entre el del suelo y el del pasto (`GrassLook.average_color()`). El suelo del juego se desvanece al mismo, y toma el color del pasto bajo las hojas dibujadas, así el pasto y el suelo se encuentran sin costura, cerca y lejos.
- **El viento:** se lleva y se mezcla, nunca se reinicia.
- **Pintar:** la caída y el ruido de un pincel dan bordes suaves e irregulares; el pasto pisado se vuelve a levantar en `trample_recover`.

## Claros y pisoteo

- **Por grupo:** `clearings`, una lista de `GrassClearing` {group, radius, soft}. Nada de pasto a menos de `radius` de cada nodo del grupo, volviendo a completo en `soft`. Los nodos se vuelven a leer cada medio segundo, así un edificio puesto en el juego despeja su suelo.
- **A mano:** un nodo `GrassClear3D` con `radius` y `soft`, que se arrastran con sus asas en la vista 3D. Su señal `changed` le avisa a cualquier otra cosa que lo siga (la flora propia del juego).
- **Los dos** cuentan juntos, hasta 48 claros.
- **Pisoteo:** los nodos de `trample_group` cerca del campo doblan el pasto hacia afuera. Cada uno tiene `trample_radius` de ancho, o su propio `grass_trample_radius` (propiedad o meta). Con `trample_recover` (s), cada uno deja un rastro que se desvanece, así el pasto se levanta despacio detrás de él. Un cuerpo quieto mantiene su lugar aplastado. Primero los cuerpos, después los puntos de rastro más frescos, hasta 48 marcas.

## Rendimiento

El pasto cuesta por hoja instanciada: en un shader de vértices cada vértice de una hoja vuelve a hacer el trabajo de la hoja. Los píxeles importan poco; renderizar con la cuarta parte de los píxeles ahorró menos del 10 % acá.

Lo que lo mantiene bajo:

- **Mallas:** un MultiMesh por tier y tipo, compartido por todas las celdas, y un material por tipo.
- **Celdas:** cruzar una celda solo mueve nodos, y los límites de cada celda se ajustan a su suelo, así el renderer descarta las celdas fuera de vista.
- **Lo despintado no cuesta nada:** una celda donde el mapa de densidad está vacío no dibuja nada, y un tipo que crece por un mapa solo dibuja en las celdas donde está pintado. En el ejemplo, las manchas de flores cuestan 31 draws en vez de 46.
- **Lo más barato primero:** el shader decide si dibuja una hoja con la distancia y el rango, después una lectura del suelo. Solo las hojas que quedan hacen las matas, el viento y el pisoteo. Una hoja que no se dibuja colapsa a un punto.
- **Sin discard:** las hojas son opacas y de dos caras, y solo los tipos con `alpha_scissor` hacen discard.

**Medido** en una Mac M4 a 1280×720, renderer Compatibility, vsync apagado, en el ejemplo. La calidad MEDIUM instancia unas 200 000 hojas, 175 000 a la vista:

| Qué | Costo |
|---|---|
| El pasto | unos 5,4 ms por cuadro |
| Las sombras del sol sobre él | unos 1,1 ms de eso |
| Las matas | 0,4 ms |
| Cuatro segmentos contra uno | 1,4 ms |

**Qué ajustar:**
- el costo escala con `density` y `radius`, así que un preset es la primera perilla;
- `cast_shadows` queda apagado;
- un tipo de hoja suma una draw por celda donde crece.

Con un depth prepass (Forward+) el shader de vértices de cada hoja corre dos veces; un juego con mucho pasto puede medir con `rendering/driver/depth_prepass/enable` apagado.

**WebGL y la web.** Nada usa `instance uniform`, que WebGL limita: las hojas leen custom data del MultiMesh y uniforms del material (un test lo chequea).

**No se dibuja nada headless ni en un servidor dedicado.** `can_draw()` lo dice, y los tests ponen `GrassField3D.draw_anywhere`.

## De dónde salen las ideas

La charla del pasto de Ghost of Tsushima (Eric Wohllaib, GDC 2021) y sus análisis dieron forma a casi todo el render:
- hojas Bézier con inclinación y curva;
- matas de Voronoi que ponen altura, tono e inclinación;
- un solo viento de ruido desplazado, compartido por todo, más un vaivén por hoja;
- hojas que caen y se ensanchan con la distancia, y vértices de LOD mezclados antes de un cambio;
- engrosado en espacio de vista y normales redondeadas que tienden a una común a lo lejos;
- suelo lejano que toma el color del pasto.

El pigmento desde el color del suelo sigue a The Witcher 3. Breath of the Wild no tiene una fuente técnica pública; su aspecto (colores planos de base a punta, matas, olas de viento que se leen de lejos) es la referencia de los valores por defecto.

Las herramientas del editor siguen lo que la gente ya conoce de otras:
- las teclas de Terrain3D y su barra de ajustes bajo la vista;
- mapas de densidad pintados por tipo, como la pintura de detalles de Unity y las capas de detalle de HTerrain, con el Shift y el Ctrl de Unity;
- los pinceles de pintar y borrar de Spatial Gardener;
- un pincel que pinta hacia un valor objetivo, como la densidad de pintura del follaje de Unreal.

## Tests

```bash
godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd
```

El resultado es `GRASSKIT TESTS PASS (n)`. Los tests cubren:

- **la calidad**: la curva de densidad, tiers que son prefijos, presets (y sus botones), la cuenta del anillo;
- **las celdas y las hojas**:
  - el anillo cubre su círculo;
  - el patrón compartido se reparte parejo en cualquier prefijo, y cada tier es un prefijo de él;
  - los tipos se reparten las hojas por peso, y un tipo que crece por un mapa suma las suyas;
  - los segmentos se reducen a la mitad y se mezclan donde una celda puede cambiar;
- **el suelo**:
  - plano;
  - escrito desde los datos del juego (una función, o una imagen, y cuánto más rápida es la imagen);
  - horneado desde los colliders, y vuelto a hornear en una parte;
  - raíces a menos de 5 cm del suelo exacto a 30° y 60°;
  - cambios en un cuadro subidos una vez;
  - el costo del horneado;
  - un rayo que lo encuentra;
- **pintar**:
  - un toque y su caída;
  - borrar, suavizar, y un ruido que es el mismo cada vez;
  - color aplicado encima y destapado;
  - un mapa hecho en el primer toque;
  - una textura hecha en otro lado copiada, nunca cambiada;
  - mapas guardados dentro del suelo;
  - un trazo que se devuelve;
  - llenar, limpiar, importar y exportar;
  - el área cambiada de tamaño dejando lo pintado en su lugar;
- **el campo**:
  - celdas que siguen a la cámara sin mallas nuevas, y límites que se ajustan al suelo;
  - las cuentas y las draws por tipo, enabled apagado;
  - un look nuevo sin reconstruir, tipos de hoja con sus shaders;
  - una parte del suelo que cambió;
  - claros, pisoteo, el ancho propio de cada cuerpo, pasto pisado que se vuelve a levantar;
  - dónde se centra el anillo, un tamaño pintado;
  - el mapa pintado de un tipo llegando a sus hojas, y celdas despintadas que no dibujan nada;
  - el suelo bajo el pasto;
  - armado solo, ajustado a los colliders;
  - el viento (compartido, suave, congelado, detenido por la pausa);
  - nada headless;
- **los looks listos**, el `changed` de un claro;
- **ningún instance uniform** en los shaders;
- **el ejemplo, de punta a punta.**

Las herramientas del editor tienen su propio chequeo en un editor real, usadas como las usa una persona:
- **el pasto y el suelo:**
  - el pasto alrededor de la cámara de la vista 3D;
  - el aviso de suelo plano;
  - Bake ground, su archivo y su deshacer;
- **pintar:**
  - seleccionar el campo muestra la barra; los sliders ajustan el pincel;
  - el pincel apunta donde está el mouse, el pasto lo sigue, y un clic pinta en vez de seleccionar;
  - Ctrl + arrastrar borra;
  - el trazo se deshace y se rehace, igual que el mapa que crea un primer trazo;
  - `]` agranda el pincel;
  - guardar la escena conserva el mapa;
- **el menú:**
  - el pincel Kind le pone nombre a un tipo y pinta dónde crece;
  - Fill y Clear, y su deshacer;
- **las asas:**
  - el lado del área arrastrado hacia adentro y hacia afuera, el sendero pintado quedando donde estaba, la parte nueva horneada, deshecho;
  - el radio de un claro;
- **el armado:** un campo nuevo se arma solo, se ajusta a las lomas y hornea; el botón Low de la calidad se deshace.

```bash
GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab
```

Imprime `EDITOR CHECK PASS`. Los shaders en sí (la hoja, la recortada, el suelo del ejemplo) y el círculo del pincel y el mapa superpuesto se chequean en una ventana, en Forward+ y Compatibility, corriendo el ejemplo y el editor.

## Lo que no está en el kit

Son del juego:

- qué significa el pasto para el juego (esconder unidades, frenarlas);
- su terreno, y cuándo cambia;
- su clima, que pone el viento;
- el menú de opciones que pone la calidad.
