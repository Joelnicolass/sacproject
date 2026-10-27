# Scapex: cómo el editor original creaba el terreno (investigación 2026-10-26)


No edité nada. Solo dejé dos archivos de trabajo en el scratchpad: el texto extraído de los PDF (`(scratchpad de la sesión) pdf/MANUAL.PDF.txt`) y las cadenas UTF-16 de `scapex.exe` (`(scratchpad de la sesión) scapex_u16.txt`). Para leer los PDF usé `pypdf` dentro de un venv en el scratchpad.

**Cómo cito:**
- **MAN pN:** página del PDF del manual. La página impresa es N−1.
- **EXE@offset:** desplazamiento decimal de la cadena dentro de `scapex.exe`.
- **Límite de licencia:** la licencia de Scapex (`ReadMe.txt`, cerca de la línea 621) prohíbe descompilar el editor. Por eso de `scapex.exe` leí solo cadenas de interfaz y no lo desensamblé.
- **Fuentes que no aportaron:** `Scapex.wad` (2 KB) solo trae el «default trigger chunk», o sea los triggers de victoria por kills, almas y manalitos (`Scapex.wad`@20). `RefCard.pdf` es solo el mapa de teclas del juego.

### 1. Herramientas de altura
- **Crear el mapa.** En *File > New* se elige «Generate fractal map», con «Steepness» de 0 (plano) a 4 (montañoso), «initial size» y tileset (MAN p57; EXE@273562, @273854).
  - El tutorial usa un tamaño de 256x256.
  - El resto de opciones de tamaño sale de una lista con formato `%u x %u` (EXE ASCII@234708). Qué valores trae: NO VERIFICADO.
- **Malla.** Es una grilla de vértices y cada vértice se une con sus 8 vecinos. El LOD dinámico funciona también dentro del editor (MAN p57).
  - sacengine lo confirma: cada celda se parte en 2 triángulos y la diagonal se elige según los huecos (`sacengine/source/sacmap.d:529-543`).
  - El vértice cae en `10*i, 10*j`, o sea 10 m (`sacmap.d:518`, `:717`).
- **Subir y bajar (Terrain tool, F5).** Se mantiene el clic izquierdo y se mueve el mouse arriba o abajo; al soltar, el terreno queda a esa altura. Es un arrastre vertical, no se pinta (MAN p58; EXE@307712).
- **Pincel compartido (Brush Bar).** Tiene:
  - *Thickness*, el tamaño: el tutorial usa 24 y 8.
  - *Falloff*: cuanto más alto, más suave el borde; con falloff bajo salen cañones.
  - *Shape*: Square, Circle, Cross y «Cross with radius».
  - *Density*, que solo usan los widgets.

  Fuentes: MAN p58 y p62; EXE@313622; cadenas «Square/Circle», «Cross» y «Cross with radius» (EXE@312788, @315974, @315986).
- **Suavizar y aplanar (Smooth tool, F6).** Arrastrando, suaviza. Con Shift, aplana a la altura del punto donde se empezó, y todo lo que se toca durante el arrastre queda a esa altura (MAN p58; EXE@308766).
  - El manual dice que el uso principal es dejar plano el lugar de los altares: «Altars must have all 4 pillars levels» (MAN p58).
- **No encontré** pinceles de ruido, de erosión ni de terraza. En las cadenas no aparecen (NO VERIFICADO que no existan).
- **Importar y exportar heightmap: sí existía.**
  - Menú *File*: «Import Map Images…» y «Export Map Images…» (EXE@271392).
  - El diálogo de *New* tiene «Import Image Maps >>», con estos campos:
    - **Height Map**, un archivo de imagen con un spinner «Height Multiplier»;
    - **Edge Map**;
    - **Tile Map**, con la tabla «Image Palette Index Mappings»: índice de paleta → *Tile/Group*.

    Fuente: EXE@274170 a @274586.
  - *Export Image Maps* escribe el height map (con multiplicador), el edge map y el light map. Los nombres por defecto son `hmap.tga`, `emap.tga` y `lmap.tga`, en Targa (EXE ASCII@234196-234220; EXE@280442).
  - El diálogo «Import Edge Map» advierte: «Height and tile map information are retained. This action is not undoable» y «Any items that are off the edge… are deleted» (EXE@281054-281794).
  - Errores que puede dar: «Please specify a heightmap/edgemap/tilemap filename».
  - Profundidad de bits del TGA de altura: NO VERIFICADO.
- **Formato en el .scp** (sacengine `maps.d:13-30`):
  - HMAP es `u16 ancho, u16 alto`, más `u16` por vértice.
  - **El bit 15 marca «vacío» (hueco).** Los otros 15 bits son la altura × 0.1 m, así que el paso es de 10 cm y el máximo, unos 3276 m.
  - Al cargar, sacengine resta la altura mínima de la tierra visible (`sacmap.d:186-187`).

### 2. Texturas y tiles
- **Organización.** Hay un tileset por dios, partido en grupos (rock, sand…) de hasta 12 variantes que encajan entre sí. Cada textura cubre una celda de 10x10 m (MAN p59).
- **Mezcla.** Las transiciones entre grupos son **«join groups» automáticos y ocultos al usuario**.
  - No todos los pares de grupos tienen transición, porque las combinaciones eran demasiadas. La mayoría mezcla con el grupo primario; en James es «cracked earth».
  - Si la mezcla sale cortada, es que se está mezclando contra un tile ya mezclado, y se arregla separando más (MAN p59).
  - En el exe aparece la función `FindJoinGroup` (EXE ASCII 0x372a4).
- **Pincel de tiles (F3).** Si se elige un grupo, toma una variante al azar en cada trazo; también se puede elegir una variante fija (MAN p60).
- **Mapa nuevo.** El mapa generado ya llega texturizado por reglas de altura (MAN p60).
- **Formato.** El TMAP guarda 1 byte por celda en 256x256 (`maps.d:42-48`).
- **Light brush (F4).** Tiñe o oscurece por celda «quitando color», con sliders RGB. Shift toma el color del terreno (cuentagotas).
  - El manual lo propone para sombras de nubes, bordes y caminos (MAN p60; EXE@313622).
  - Ctrl+L recalcula el lightmap y la «striation». Existe «Revert Lightmap to Default», que no se puede deshacer (MAN p58; EXE@315558).
  - Formato LMAP: 256×256 RGBA (`maps.d:82-86`).
- **Otros pinceles:**
  - **Scar brush (F9):** sangre y quemaduras; Shift borra. Las marcas van en un buffer que el juego recicla (MAN p60-61).
  - **Widget brush:** pasto y arbustos sembrados en grupos según thickness, falloff y density. Se dibujan solo cerca de la cámara (MAN p62).

### 3. Huecos, acantilados, agua y tamaño
- **Edge tool (F7).** «Cuts an edge into the landscape»; con Shift vuelve a pintar tierra. No admite falloff (MAN p59; EXE@308084).
  - Las islas se hacen recortando el cuadrado. El tutorial pide primero un borde alrededor de todo el mapa.
- **Los huecos conservan la altura oculta.** Al rellenarlos, la tierra vuelve a la altura de antes (MAN p59).
  - Truco documentado: un monte alto escondido estira la «striation», las bandas de color por altura.
  - Defecto documentado: aparecen «spikes or sharp slithers» cerca de los bordes, que se arreglan rellenando bien y suavizando (MAN p59).
- **Paredes de los bordes.** El juego las genera solo, con la textura `edge`, a partir del bit de vacío (`sacmap.d:325-350`, `:205`).
- **Huecos en juego.** Se cambian en tiempo real: `applyEdgeChanges` y `removeLandVertex` (`sacmap.d:213-226`; `state.d:29028`).
- **No hay agua ni lava como capa de terreno.** No encontré nada en el manual ni en las cadenas (NO VERIFICADO del todo).
- **Tamaño.** Las 32 mapas multijugador son grillas 256×256:
  - sacengine fija 256 en TMAP y LMAP (`maps.d:46`, `:83`);
  - la tierra visible va de 1254 celdas (Peaks) a 38475 (WinterWonder), o sea entre 2 % y 59 % (`game/tools/import/import_map.py --list`).

  La forma del mapa la da el hueco, no el tamaño de la grilla.

### 4. Objetos y suelo
- **Item tool (F8).** El tutorial pide preparar antes un claro de 12x12 con cracked earth.
- **Base tiles.** Al poner el altar se estampan sus «BASE TILES». Las estructuras que los tienen **se ajustan a la grilla de tiles**; las demás van en cualquier lado (MAN p61).
  - En sacengine es un bloque de 8×8 tiles en el BLDG (`bldg.d:16`), estampado alrededor del vértice más cercano (`state.d:31241-31251`). También bloquea quitar vértices debajo (`state.d:29015-29023`).
- **El suelo NO se aplana solo bajo el edificio.** Lo aplana el diseñador con Shift+Smooth (MAN p58). En sacengine no hay código que aplane al colocar: el único `flatten` es el del volcán (`state.d:4353`).
- **Altura de los objetos.** Se guarda como `x, y, z` en NTTS (`ntts.d:19-23`), la *z* incluida.
- **Rotación.** Hay botones de horario y antihorario. No se recomienda rotar estructuras con base tiles; los árboles rotan bien (MAN p62).
- **Criaturas.** Van en cualquier lugar (MAN p62).
- **Markers.** Son círculos o rectángulos con radio mayor y menor, y definen regiones para los triggers (MAN p63; EXE, diálogo *Marker*).

### 5. Deshacer, vista previa y validación
- **Deshacer.** Ctrl+Z varias veces, pero el manual avisa: «Undo doesn't always work well on certain changes… Save your work frequently» (MAN p58).
  - El exe usa una tabla fija de bloques de undo: `m_undoblocktbl`, `undoblock.cpp` (EXE ASCII@239184, 0x3f19c).
  - Importar el edge map y revertir el lightmap no se pueden deshacer.
- **Vista.** Es la vista en vivo del motor:
  - vuelo con WASD y flechas, mirada con clic derecho;
  - **TAB = «hyper-jump»** al punto bajo el cursor;
  - Ctrl+W wireframe, Ctrl+K cielo;
  - varias vistas a la vez con «New Landscape View»;
  - el pincel se ve como un parche azul que sigue el relieve.

  Fuentes: MAN p57-58, p62; menú *Window*.
- **Iluminación.** El lightmap no se actualiza solo: hay que pulsar Ctrl+L (MAN p58).
- **Validación.** Solo encontré bloqueos de referencias: no se puede borrar un item, variable, objetivo, sample o bando que use un trigger (cadenas del exe, zona @313000-316000).
  - El manual dice que sin altares la partida no arranca (MAN p61).
  - **No encontré ningún chequeo de alcanzabilidad ni de navegación** (NO VERIFICADO que no exista).
  - La guía de 4Gamer pide probar jugando muchas veces ([4Gamer](https://www.4gamer.net/review/live/scapex.html)).

### 6. Web
Las búsquedas de «Sacrifice Scapex editor terrain», «Scapex tutorial» y guías de la comunidad dieron una sola fuente útil: [4Gamer, 2001](https://www.4gamer.net/review/live/scapex.html). El texto llegó con la codificación rota, así que la lectura es aproximada. El orden de trabajo que recomienda es:
1. recortar la forma con el edge tool, usando un boceto del mapa;
2. poner los objetos con moderación;
3. dar desniveles con el smooth tool, cuidando que no compliquen el juego;
4. texturas, widgets y lightmap al final.

No encontré tutoriales ni wikis de la comunidad.

### 7. Qué conviene copiar y qué evitar
**Copiar:**
- export e import de mapas en imágenes, con multiplicador de altura;
- el hueco como bit aparte, que conserva la altura;
- las transiciones de tiles automáticas;
- aplanar a la altura del punto inicial;
- falloff y forma compartidos por todas las herramientas;
- el salto rápido a un punto;
- la siembra de widgets por densidad.

**Evitar:**
- un undo poco confiable y operaciones que no se pueden deshacer;
- que se borren objetos en silencio al importar los bordes;
- pares de tiles que no mezclan, que se descubren probando;
- picos en los bordes de los huecos;
- relucir la luz a mano con Ctrl+L;
- que los edificios no aplanen su base (el altar exige 4 pilares a nivel, y lo hace el diseñador a mano);
- no tener ninguna validación de caminos.

## Ideas para nuestras herramientas

**Ida y vuelta con Blender**
1. **Exportar e importar «map images» además del `.glb`.** Altura en PNG de 16 bits de 256², huecos en una máscara de 1 bit, tiles como PNG con índice y luz en RGBA, con un multiplicador de altura explícito. Blender puede leer la altura como Displace sobre el plano de 256² vértices. *Fuente: EXE@271392, @274170-280442 (`hmap.tga`, `emap.tga`, `lmap.tga`, «Height Multiplier»).*
2. **El hueco va como dato aparte, nunca como altura.** Un atributo o grupo de vértices `void` en Blender que conserve la altura debajo, así rellenar no deja escalones. *Fuente: MAN p59; `maps.d:24-27` (bit 15).*
3. **La validación al importar falla con nombre y no borra en silencio.** Si un objeto queda sobre un hueco, sobre una base sin nivelar o fuera de la grilla, el import se corta nombrando el nodo. Es lo opuesto al «Any items that are off the edge… are deleted» de Scapex. *Fuente: EXE@281794.*
4. **Paso de altura cuantizado y comprobado.** Comparar contra un paso de 0.1 m (como el HMAP original) para detectar deriva de float en la ida y vuelta. *Fuente: `maps.d:27`.*

**Pinceles en el editor**

5. **Un solo recurso de pincel** con tamaño, falloff, forma (círculo, cuadrado, cruz) y densidad, compartido por subir/bajar, suavizar/aplanar, hueco, tiles, luz y widgets. *Fuente: MAN p58, p62; EXE@312788-315986.*
6. **Smooth y Shift = flatten «a la altura donde empezó el trazo»,** más un modo de aplanar la huella del edificio que nivele sola el bloque de 8×8 (o su `BaseTiles`) al soltar un altar o manantial. *Fuente: MAN p58 (pilares del altar), `bldg.d:16`, `state.d:31241`.*
7. **Pincel de hueco con Shift para rellenar, sin falloff,** y suavizado automático del anillo de borde para evitar los picos. *Fuente: MAN p59; EXE@308084.*
8. **Pincel de tiles por grupo con variante al azar y transiciones automáticas,** con un aviso visible si un par de grupos no tiene transición, en vez de descubrirlo probando. *Fuente: MAN p59-60.*
9. **Undo real con `EditorUndoRedoManager` por trazo,** incluidos el import y el revertido de luz, y luz y normales recalculadas solas al soltar el trazo (sin un Ctrl+L manual). *Fuente: MAN p58; EXE@315558, @281362.*
10. **Atajos de navegación:** salto al punto bajo el cursor (TAB) y el pincel como un parche que sigue el relieve. Agregar lo que a Scapex le faltaba: un chequeo de alcanzabilidad sobre el navmesh horneado entre altares y manantiales. *Fuente: MAN p57-58; no encontré validación de caminos en Scapex.*

**Fuentes web:** [4Gamer — Scapex](https://www.4gamer.net/review/live/scapex.html). Las demás búsquedas no trajeron nada de Sacrifice.
