# 061S — Marcas en el suelo (SCAR): formato, cómo las usa el original y cómo llevarlas a Godot

Este informe es para el sub-corte **061k-5** (`docs/archive/rfcs/plans/061k-terrain-plan.md`). Trae los hechos y una propuesta, pero no código. sacengine no implementa las SCAR: deja `// TODO: scar` en `state.d` 11460 (Meanstalks), 16377 (rayo), 18435 y 18490 (Erupt), 18558 (restos de Erupt), 19186 (Halo), 20045 (Firewall), 20536 (Wall of Spikes), 21297 (Bombardment), 21746 y 21785 (Bovine), 24499, 25600 (aceite) y 25734 (Quake).

## Fuentes y etiquetas

- **[WAD]** las 19 SCAR de la instalación (`SAC_INSTALL`), leídas con `tools/import/sac_formats/wad.py` y decodificadas a mano (el script está en «Cómo se leyó»).
- **[G3D 0x…]** `game3d.dll` (base 0x16000000). **Hallazgo:** la DLL **exporta con su nombre C++** todas las funciones de cicatrices de la clase `LAND`: `ApplyScarring`, `ApplyScarringToTile`, `ApplyScarringToTileProcedural`, `GetFreeScarTexture`, `ReleaseScar`, `ReleaseScarTexture`, `ClearScars`, `MakeScarLUT`, `GetScarTileUnder`, `SaveScars`/`LoadScars`. El dibujo de las cicatrices está en esa DLL, no en el EXE.
- **[EXE 0x…]** `Sacrifice.exe` (base 0x400000). Para los nombres de función se usó la tabla de 0x4cbba8 (272 entradas de 36 bytes: nombre[28], función, hash), igual que en 061R/061V, más los destinos de `call rel32`.
- Herramienta: el `objdump` de Apple (LLVM) sobre las dos binarias. **No hizo falta Ghidra ni REA**, porque los exports nombrados y la tabla alcanzaron.
- **[SPEL]** el registro SPEL de `spells.wad` (tabla de recursos clave/valor, leída con `spel_args` de `tools/import/export_stats.py`). Como dicen las fichas 061V, la etiqueta que empuja el EXE es solo el **valor por defecto**, y la tabla del SPEL la reemplaza.
- Precedencia: SPEL/EXE/G3D > sacengine. Lo que no se pudo confirmar dice **NO VERIFICADO**. Ninguna afirmación sale de una captura de pantalla del juego.

---

## 1. El formato binario SCAR

### 1.1 Disposición

| Offset | Tamaño | Campo | Prueba |
|---|---|---|---|
| 0 | u32 | siempre 0 | las 19 SCAR [WAD] |
| 4 | u32 | tamaño total del recurso en bytes (= largo del payload) | las 19 coinciden |
| 8 | u32 | ancho `w` en píxeles | `ApplyScarring` lee `[scar+8]` como ancho y paso de fila [G3D 0x16045938, 0x16045b07] |
| 12 | u32 | alto `h` en píxeles | `[scar+0xc]` [G3D 0x1604595f] |
| 16 | 256 × 4 | **paleta propia**: B, G, R, 0 (el 4.º byte siempre es 0) | `[scar+0x10]` [G3D 0x16045b17, 0x16045b35] |
| 1040 | w × h × 2 | píxeles **intercalados** por fila: `índice u8`, `alfa u8` con **valores de 0 a 8** | `[scar+0x410]`; el bucle lee `byte[p]` = índice y `byte[p+1]` = alfa, y avanza 2 [G3D 0x16045ce7-0x16045ceb, 0x16045dd1] |

`tamaño = 16 + 1024 + 2·w·h`, y lo cumplen las 19.

- **Orden BGR**, confirmado de dos maneras. (1) Al decodificar como BGR, `fire` sale naranja y `blud` sale rojo; como RGB salen azules. (2) `ApplyScarringToTile` mezcla el byte +2 de la paleta de la SCAR con el byte +6 (= +4+2) de la paleta del paisaje, y los dos van a los bits altos del índice de la LUT de 15 bits. O sea, las dos paletas guardan los canales en el mismo orden [G3D 0x16045d23-0x16045da5].
- **El alfa va de 0 a 8**, y cada paso es 1/8 de mezcla. `MakeScarLUT` arma 9 tablas de 256 con `T[a][c] = (c·a) >> 3`, para a = 0..8 [G3D 0x16045561-0x1604558d]. Ninguna SCAR pasa de 8.
- **No hay color clave.** El único píxel que se salta es el de alfa 0 [G3D 0x16045cf1-0x16045cf7]. Consecuencia: `quk1` tiene el índice 0 = magenta (FF00FF) con alfa 1-2 en el borde, así que el original le pone **un halo rosado de 12-25 %** a la grieta del Firewall. No se miró en pantalla: **NO VERIFICADO**.
- **No hay mipmaps ni cuadros de animación.** Es una sola imagen; las cabeceras no dejan lugar para más.

### 1.2 Forma: no es decal ni malla

Una SCAR es **una imagen que se pinta dentro de la textura del suelo**. El píxel de la SCAR coincide con el texel del paisaje y no se escala: 6,4 texels por metro (constante −6,4 en [G3D 0x16045862]; 0,15625 = 1/6,4 en [G3D 0x160458a3]), así que **1 píxel = 0,15625 m**. El paisaje está hecho de **baldosas de 64×64 texels (10 m)** (`sar 6` y `and 0x3f` en [G3D 0x160459bb, 0x16045a0c]; 0,1 por metro para el índice de baldosa en [G3D 0x160458e1]).

- La imagen va **centrada en (x, y) del mundo**, alineada a los ejes. **No rota ni se escala**: `ApplyScarring(float pos[2], SCAR*, int src_offset[2], int size[2], short priority, int flags, int* only_tile)` no recibe ángulo [G3D 0x16045850; firma del export `?ApplyScarring@LAND@@QAEXQAMPBUSCAR@@QAH2FHPAH@Z`].
- Como queda horneada en la textura del suelo, **sigue el relieve sola**, la ilumina el lightmap del suelo como al resto, y no pinta criaturas, edificios ni flora.

### 1.3 Ejemplos decodificados

| SCAR | WAD · carpeta | Cabecera (hex) | w×h | Metros | Contenido |
|---|---|---|---|---|---|
| `scar` | charlie · `Bloo.WAD!/Pyro.FLDR/scar.FLDR` | `00000000 c8180000 34000000 33000000` (6344 B) | 52×51 | 8,1×8,0 | Los 2652 píxeles tienen el índice 254 (negro, 0,0,0); solo varía el alfa (0-8, con 1235 píxeles en 0). Es **una máscara negra con forma de mancha de quemado**: oscurece el suelo y no le agrega color |
| `gscr` | shawn · `shwn.WAD!/jams.FLDR/scar.FLDR` | `00000000 90100000 28000000 28000000` (4240 B) | 40×40 | 6,25×6,25 | Grieta en estrella, marrón grisácea (p. ej. el índice 0 vale B40 G49 R58 = RGB 88,73,64). 256 índices; alfa 0-8 |
| `quk1` | main · `MAIN.WAD!/scar.FLDR` | `00000000 10060000 10000000 10000000` (1552 B) | 16×16 | 2,5×2,5 | Paleta web de 6 niveles (el índice 0 es magenta). Usa solo 2 índices: 216 (centro oscuro, alfa 1-7) y 0 (borde, alfa 0-2). Es una muesca chica y oscura |
| `volc` | charlie · `Pyro.FLDR/scar.FLDR` | `00000000 10040200 00010000 00010000` (132112 B) | 256×256 | 40×40 | Cráter de roca agrietada azul-gris oscuro con borde irregular. Alfa casi siempre 8 en el disco y 0 afuera |

### 1.4 Inventario completo (19 SCAR)

| SCAR | WAD · carpeta | w×h | Metros | Quién la usa (§3) |
|---|---|---|---|---|
| `scar` | charlie · `Pyro.FLDR/scar.FLDR` | 52×51 | 8,1 | Explosion, rayos (Lightning, Chain Lightning, Cloudkill, MM_Bolt), Gunhead |
| `volc` | charlie · `Pyro.FLDR/scar.FLDR` | 256² | 40 | Volcano |
| `oils` | charlie · `Pyro.FLDR/scar.FLDR` | 64² | 10 | Viscous Oil (habilidad `kcfa`) |
| `mean` | charlie · `Pers.FLDR/tex.FLDR` | 64² | 10 | Meanstalks (`rter`) |
| `bovs` | charlie · `Jame.FLDR/tex.FLDR` | 128² | 20 | Bovine Intervention |
| `quk1` | main · `scar.FLDR` | 16² | 2,5 | Firewall; valor por defecto de Wall of Spikes |
| `blud` | main · `scar.FLDR` | 8² | 1,25 | sangre de las partículas (G3D) |
| `rcrk` | main · `scar.FLDR` | 64² | 10 | ningún `push` en el EXE ni en la DLL: **NO VERIFICADO** (¿datos de mapa? §2.5) |
| `air_` `deth` `erth` `fire` `life` | main · `scar.FLDR` | 128² | 20 | Emblemas de los cinco dioses en un disco. Ningún `push`: **NO VERIFICADO** (¿datos de mapa? §2.5) |
| `tscr` | shawn · `jams.FLDR/scar.FLDR` | 40² | 6,25 | Burrow; valor por defecto de los impactos de roca; Rock (`tRE3`) |
| `gscr` | shawn · `jams.FLDR/scar.FLDR` | 40² | 6,25 | Wall of Spikes, Bombardment (`tRE3`), Rock y Halo (`tRS4`), restos de roca de criaturas |
| `escr` | shawn · `jams.FLDR/scar.FLDR` | 256² | 40 | Erupt (rojo oscuro) |
| `bscr` | shawn · `jams.FLDR/scar.FLDR` | 16² | 2,5 | Bore |
| `ecrk` | shawn · `jams.FLDR/scar.FLDR` | 48² | 7,5 | Bombardment (`tRS4`); valor por defecto de Meanstalks |
| `jm2d` | shawn · `jams.FLDR/scar.FLDR` | 48² | 7,5 | ningún `push`: **NO VERIFICADO** |

Nota: `mean` y `bovs` están en carpetas `tex.FLDR`, no en `scar.FLDR`. El cargador busca por etiqueta y tipo (`'SCAR'`) en todas las WAD, así que la carpeta no importa.

---

## 2. Cómo el original crea, dibuja y saca una SCAR

### 2.1 Dónde se pinta (game3d.dll)

1. **`LAND::ApplyScarring`** [G3D 0x16045850]. Pasa el centro a texels (`6,4·x − w/2`), marca las baldosas tocadas con `TilesChanged` [G3D 0x1604592f] y recorre la imagen por trozos de baldosa de 64×64. Para cada baldosa toma una textura privada con `GetFreeScarTexture` y pinta su trozo con `ApplyScarringToTile`, o con `…Procedural` si `flags & 1`.
2. **`GetFreeScarTexture`** [G3D 0x16045680]. Cada baldosa de 10 m del mapa tiene un id de textura de 16 bits (mapa en `[LAND+0x38]`, ancho `[LAND+0x20]`). Las ids < 0x100 son las del tileset y las ≥ 0x100 son copias con cicatriz.
   - Si la baldosa **ya tiene** copia, se reutiliza: solo se actualizan la prioridad (sube, nunca baja) y la marca de tiempo `[LAND+0x332c]`.
   - Si no tiene, toma un registro libre del pool. Cuando no queda ninguno, **desaloja** el de menor prioridad y, si empatan, el más viejo; a esa baldosa le devuelve su id original. Después copia las propiedades de la baldosa (12 bytes en `[LAND+0x1b1c]`), crea si hace falta una textura de 64×64 de 8 bits con la paleta del paisaje (`push 0x40, 0x40`, [G3D 0x160457f5-0x160457fd]) y le pone la nueva id al mapa.
   - Si la baldosa tiene el **bit 2** en sus propiedades, no se le pinta cicatriz [G3D 0x16045693]. Qué baldosas lo tienen (¿agua?, ¿lava?): **NO VERIFICADO**.
3. **`ApplyScarringToTile`** [G3D 0x16045c00]. Si la textura es nueva, primero copia los 64×64 texels de la baldosa original (`rep movsd`, [G3D 0x16045c4b-0x16045c70]). Después, por cada píxel con alfa `a` > 0:
   - `color = T[a][scar_pal[i]] + T[8−a][land_pal[texel]]` por canal, o sea `scar·a/8 + suelo·(8−a)/8`;
   - lo vuelve a cuantizar a la paleta del paisaje con una LUT RGB 5:5:5 de 32768 entradas (la del color más cercano, la arma `MakeScarLUT`).

   Por último regenera los mipmaps (`CreateMipMaps`, [G3D 0x16045e4e]).
4. **`ApplyScarringToTileProcedural`** [G3D 0x16045e80]. Lee la imagen con **coordenadas de mundo envueltas**: máscaras `2w−2` y `(h−1)·w·2`, que exigen lados potencia de 2 [G3D 0x16045962-0x16045989]. La SCAR funciona entonces como un **patrón que se repite anclado al mundo**. Solo la usa el cargador de mapa (§2.5). Qué hace en detalle con el alfa: **NO VERIFICADO** (se leyó la mezcla, que es igual a la normal, pero no el origen exacto de cada byte).

**Mezcla:** «encima» con alfa en pasos de 1/8, **sobre el color del suelo, no aditiva**. Las cicatrices que caen en la misma baldosa **se acumulan**, porque cada una se pinta sobre la copia ya pintada. `scar`, toda negra, solo oscurece.

### 2.2 Duración, fundido y desaparición

- **No hay fundido ni temporizador.** En el código de `LAND` no hay nada que dependa del tiempo, salvo la marca que se usa para elegir a quién desalojar.
- Una cicatriz **dura hasta que la desaloja otra**: la baldosa con menor prioridad y, entre iguales, la más vieja. Ese día **desaparece de golpe** (`ReleaseScar` restaura la id original, [G3D 0x16045460]). Todas las llamadas del EXE pasan **prioridad 0**, así que en la práctica el orden es el de antigüedad.
- Se guardan en la partida (`SaveScars`/`LoadScars`, [G3D 0x16042dc0, 0x16042ec0]). `ClearScars` [G3D 0x16045430] las borra todas.

### 2.3 Cuántas a la vez y opciones

Son dos opciones del juego, con descriptores en [EXE 0x4c8ebc] y [EXE 0x4c8edc]:

| Opción | Variable | Por defecto | Rango |
|---|---|---|---|
| «Number of scars» | `0x4dc038` | **256** | 32-256 |
| «Types of scars allowed» | `0x4dc03c` (bits) | **3** | — |

- **«Number of scars»** se pasa a `LAND` al cargar el mapa [EXE 0x456645], y es el tamaño del pool de copias de baldosa (`[LAND+0x3328]`, que recorre `MakeScarLUT`). Que la llamada virtual de 0x456651 sea exactamente la que fija ese valor es lo más probable, pero **NO VERIFICADO**. El límite cuenta **baldosas de 10 m, no cicatrices**: un `volc` de 40 m ocupa hasta 5×5 = 25 de las 256.
- **«Types of scars allowed»** tiene dos bits:
  - **bit 1** (clave de menú `xscr`, [EXE 0x40d9e2]): las cicatrices de hechizos y criaturas. Sin él, `sub_44cb90` sale sin pintar [EXE 0x44cb90].
  - **bit 0** (clave `bscr`, [EXE 0x40d51e]): la sangre. Llega a los sistemas de partículas en [EXE 0x40cc0c-0x40cc4e] (`PARTICLESYSTEM::SetProperty(0x85)`).

### 2.4 Cómo se crea desde el juego (EXE)

- **`sub_44cb90(tag, pos)`** [EXE 0x44cb90] es la única puerta de los hechizos. Si el bit 1 está prendido, carga el recurso `(tag, 'SCAR')` con el gestor de recursos (`[0x4da918]→vtable+0x4c`) y llama a `ApplyScarring(pos, scar, {0,0}, &scar.w, 0, 0, NULL)`: imagen entera, sin repetir, prioridad 0.
- **`sub_44cb50(tag, pos, max_h)`** [EXE 0x44cb50] es la misma, pero solo pinta si `|altura del suelo(pos) − pos.z| < max_h` (`LAND::GetHeight`). Así, un rayo o una roca que explota en el aire no marca el suelo.
- **Sangre** [G3D 0x1602018e-0x160201ed], en `PARTICLESYSTEM::RunParticles`. Si el sistema tiene las banderas `0x20000` y `0x100000`, la partícula que toca el suelo pinta `blud` con un tamaño fijo de 8×8.

### 2.5 Cicatrices puestas por el mapa

Al cargar el mapa, `sub_4567d0` recorre registros `{tipo, tamaño, …}`. El tipo **0x80** hace `ApplyScarring(pos = rec+8, SCAR(rec+0x18), {0,0}, size = rec+0x1c, 0, flags = 1, NULL)`, es decir, **en modo procedural** (patrón repetido) [EXE 0x456a40-0x456a78]. Lo llaman las etapas de carga «Creating landscape» y otras (`sub_4565f0`). Qué mapas traen esos registros y con qué etiquetas (¿los emblemas de dioses, `rcrk`, `jm2d`?): **NO VERIFICADO**, porque los `.scp` están comprimidos y no se buscó adentro.

---

## 3. Quién usa cada SCAR

Las etiquetas de hechizo van como en `sacengine/source/nttData.d` (la forma que usa 061k). «Altura máx.» es el `max_h` de `sub_44cb50`; «—» quiere decir que pinta siempre (`sub_44cb90`). Las claves `tscr`, `tRE3` y `tRS4` se leen del SPEL con `sub_4502e0(spel, clave, por_defecto)`.

| Quién | Dónde [EXE] | Clave · valor por defecto | Valor del SPEL | SCAR final | Altura máx. | Cuándo |
|---|---|---|---|---|---|---|
| **Explosion** `pxef` | `INERT_RunExplosion` 0x43b182; la etiqueta se lee en 0x43b46e | `tXsc` · `scar` | sin clave | **`scar`** | pinta solo si la explosión está a < 10 m del suelo (0x43b44a-0x43b468) y la bandera 0x100 está apagada | una vez; después borra la etiqueta (0x43b18a) |
| **Lightning** `ntil`, **Chain Lightning** `ntlc`, **Cloudkill** `likc`, MM_Bolt | `sub_435a60` 0x435b13 (lo llaman `LightningSpellRun`, `ChainLightningRun` vía `sub_4201c0`, `CloudKillBoltRun` y `MM_BoltRun`) | `tscr` · `scar` | `scar` | **`scar`** | 2,5 m | en cada impacto de rayo |
| Gunhead (rayo) | `GunheadLightningRun` 0x4170b4 | fija | — | **`scar`** | 2,5 m | por descarga |
| **Viscous Oil** (habilidad `kcfa`) | `ViscousOilRun` 0x4138b2 | `tscr` · `scar` | `oils` | **`oils`** | 10 m | — |
| **Firewall** `lwrf` | `FireWallRun` 0x42844d | `tscr` · `quk1` | sin clave | **`quk1`** | — | a lo largo del muro (frecuencia: **NO VERIFICADO**) |
| **Wall of Spikes** `laws` | `SpikeWallStart`→`sub_447240`→`sub_4470b0` 0x447228; `SpikeWallHitNTT`→`sub_447600` 0x44774c | `tscr` · `quk1` | `gscr` | **`gscr`** | — | al brotar cada pincho y al golpear |
| **Volcano** `clov` | `VolcanoEruptRun` 0x42a41a | fija | — | **`volc`** (40 m) | — | en la erupción |
| **Erupt** `tpre` | `EruptRun` 0x444df8 | `tscr` · `escr` | `escr` | **`escr`** (40 m) | — | en la explosión |
| Restos de Erupt | `sub_444950`→`sub_4380f0` 0x4381b3 | `tRE3` · `tscr` | sin clave | **`tscr`** | pinta solo donde el resto choca con el suelo (`sub_44ecd0`) | por resto |
| **Bombardment** `rtem` | `MeteorRun`→`sub_445b40`→`sub_4380f0`; `MeteorRun`→`sub_439270` | `tRE3` · `tscr`; `tRS4` · `gscr` | `tRE3 = gscr`, `tRS4 = ecrk` | **`gscr`** en el impacto, **`ecrk`** al romperse la roca | impacto: suelo; rotura: 5 m | por meteorito. Que `MeteorRun` sea el de `metr` sale de que las claves coinciden: **probable** |
| **Rock** `kcor` | `RockRun`→`sub_4380f0` y `sub_439270` | igual | `tRE3 = tscr`, `tRS4 = gscr` | **`tscr`** / **`gscr`** | igual | igual |
| **Halo of Earth** `olah` | `HaloRockRun`→`sub_445110`→`sub_4380f0`; `HaloRockRun`→`sub_439270` | igual | sin claves | **`tscr`** / **`gscr`** | igual | cuando cae o se rompe cada roca |
| **Bore** `erob` | `BoreRun`→`sub_443190` 0x443225 | `tscr` (el SPEL lo guarda en el objeto `+0x38`) | `bscr` | **`bscr`** (2,5 m) | — | en cada paso del túnel |
| **Bovine Intervention** `ivob` | `BovineInterventionStart` 0x443bcb; también `sub_4380f0` | fija; `tRE3` · `tscr` | sin claves | **`bovs`** (20 m) donde cae la vaca; **`tscr`** en los impactos | — / suelo | — |
| **Meanstalks** `rter` | `DivineRetributionRun` 0x42e146 (nombre interno; el SPEL `rter` trae `ttex = dvin` y `tscr = mean`) | `tscr` · `ecrk` | `mean` | **`mean`** | — | — |
| Burrow | `BurrowRun` 0x418079, 0x41820f | fija | — | **`tscr`** | — | al hundirse y al salir. Qué criatura o hechizo es: **NO VERIFICADO** |
| Gorgon, Rock Clawpult, Klappon | `GorgonAbilityRun`, `RockClawpultStart`, `KlapponRun` → `sub_439270` | `tRS4` · `gscr` | (SPEL de la habilidad; no se leyó) | **`gscr`** por defecto | 5 m | cuando se rompe la roca que lanzan |
| Sangre | `RunParticles` [G3D] | fija | — | **`blud`** (8×8) | toca el suelo | por partícula de sangre |

---

## 4. Propuesta para Godot (la decide el usuario)

### 4.1 Qué hay que reproducir

Es lo mínimo para no inventar:

- una imagen alineada a los ejes, de 0,15625 m por píxel, centrada en el punto y sin rotación;
- mezcla «encima» con su alfa, sobre el color del suelo, debajo de unidades y flora, siguiendo el relieve (también el desplazamiento de 061k);
- sin fundido; la más vieja se va de golpe cuando se pasa el tope de baldosas;
- el filtro de altura de cada llamador.

### 4.2 Opción A: `Decal` nativo

Un `Decal` por cicatriz, con `texture_albedo` y `cull_mask` solo en la capa del suelo.

- **Pros:** es un nodo estándar, se ve en el editor y no toca el shader del suelo.
- **Contras:**
  1. Proyecta en todo lo que esté en esa capa. Si la flora o las paredes de agujero (`HoleWalls`) comparten capa con el suelo, también las pinta.
  2. Para el **port web (Compatibility)**, en Godot 4.x los decals no estaban soportados en ese renderer. Si 4.7 ya los soporta: **NO VERIFICADO**.
  3. El tope del original son baldosas, no cicatrices: hay que contar a mano.
  4. 256 decals superpuestos cuestan por fragmento en Forward+.

### 4.3 Opción B (recomendada): capa de cicatrices en el shader del suelo, con un dueño

Es el mismo modelo que el original, con datos de Godot.

- **Nodo `GroundScars`**, hijo de `Terrain`, **único escritor** (regla «un dueño»). Expone `stamp(texture: Texture2D, map_xz: Vector2)`, y el `@export var max_tiles := 256` sale de la opción del original.
  - Guarda un `Texture2DArray` de `max_tiles` capas de 64×64 RGBA8. Cada capa es «lo pintado en esa baldosa de 10 m», con su alfa acumulado.
  - Guarda una `Image` índice de 256×256 (R16: 0 = sin cicatriz, n = capa n−1), al lado del `tile_index` que el shader ya tiene.
  - Al pintar, compone la SCAR **encima** de la capa con `Image.blend_rect`. «Encima» es asociativo, así que acumular en la capa y mezclar en el shader da lo mismo que el original. Después sube solo esa capa (`RenderingServer.texture_2d_update` con `layer`) y la celda del índice.
  - Desaloja la capa más vieja cuando se llena y pone su celda en 0.
- **Shader** (`sacrifice_ground.gdshader` / `ground_pbr.gdshader`): un `#include` nuevo, `ground_scars.gdshaderinc`. Busca la celda de `map_pos.xz`; si tiene capa, `albedo = mix(albedo, scar.rgb, scar.a)` antes de la luz. Con eso sigue el relieve y el desplazamiento de 061k, sale en Compatibility (texture arrays sí están) y no pinta unidades ni flora.
- **Datos:**
  - un campo `ground_mark: Texture2D` en el `SpellType` / `.tres` de cada hechizo o habilidad;
  - un `ground_mark_max_height_m` (2,5, 5, 10 o «siempre») donde el llamador lo pide;
  - el tamaño sale de la textura (px × 0,15625).

  Nada de lookups por etiqueta.
- **Red:**
  - el host emite `stamp(tag, pos)` como evento de presentación (FxBus);
  - quien entra tarde recibe la lista viva de estampas (tope de 256 baldosas) y las repite en orden;
  - las cicatrices no afectan reglas ni navegación.
- **Cicatrices de mapa (§2.5, modo procedural):** fuera de 061k-5 hasta que se verifique qué mapas las traen. Si aparecen, van como nodos `GroundScarPatch` puestos en el `map.tscn` con gizmo (regla «todo en el editor»), no en datos.
- **Sangre (`blud`):** fuera de 061k-5. El sistema de partículas del port tendría que avisar del contacto con el suelo.

**Decidido el 2026-10-25 (el usuario vio el borde magenta en una captura):** el importador de SCAR dibuja el magenta clave (FF00FF) como negro (`tools/import/sac_formats/scar.py`), sin tocar el alfa; el halo rosado ya no existe. Antes: **Lo único que no se puede decidir sin el usuario:** si `quk1` se importa tal cual, con su halo magenta de 12-25 % (fiel al EXE), o con el índice 0 transparente. **Recomiendo** tal cual, y mirarlo en una captura antes de decidir, como manda «Medible».

### 4.4 Qué importar

- **Lector nuevo `tools/import/sac_formats/scar.py`**, chico, al lado de `txtr.py`: `decode_scar(raw) -> (w, h, rgba)`.
  - Cabecera de 16 bytes, paleta BGR0 de 256 entradas, píxeles `(índice, alfa)`.
  - El alfa se convierte con `round(a·255/8)`.
  - Reusa `png.encode`.
- **Script `tools/import/import_scars.py`** (con el aviso «Requiere el juego original instalado (SAC_INSTALL)», como los demás):
  - escribe `assets/original/scars/<tag>.png` sin mipmaps y con filtro lineal;
  - sale por la etiqueta + `'SCAR'` en todas las WAD;
  - lote mínimo para 061k-5: `scar`, `quk1`, `gscr`, `volc`, `escr`, `bscr`, `ecrk`, `tscr`;
  - después, para cuando lleguen esos hechizos: `oils`, `mean`, `bovs`, `blud`;
  - quedan pendientes de verificación: `rcrk`, `jm2d` y los cinco emblemas.

---

## Cómo se leyó

- **Extraer y decodificar:** con `SAC_INSTALL` exportada en la shell, `sac_formats.wad.walk` sobre cada `*.wad`, filtrando `ext == 'SCAR'`. Después `w, h = u32 @8, @12`, `pal = raw[16:1040]` y `px = raw[1040:]`; el píxel `i` es `(px[2i], px[2i+1])` y el color `pal[4·idx+2], pal[4·idx+1], pal[4·idx]` (R, G, B). Se armó una hoja de contacto con las 19 imágenes en BGR, en RGB y con el alfa solo.
- **Desensamblar:** `objdump -d --x86-asm-syntax=intel` sobre `game3d.dll` y `Sacrifice.exe`. Los exports de `game3d.dll` dan los nombres de `LAND::*Scar*`. En el EXE se ubicó la entrada de importación de `ApplyScarring` (IAT 0x4bf260), que tiene 2 llamadores, y la búsqueda de `call 0x44cb90` / `call 0x44cb50` dio 13 + 4 sitios. Cada sitio se asignó a una función de la tabla de 0x4cbba8, subiendo hasta 3 niveles de llamadores.
- **SPEL:** `export_stats.spel_args` sobre los SPEL de `spells.wad` que tienen `tscr`, `tXsc`, `tRE3` o `tRS4`. Las etiquetas se mapearon a nombres con `sacengine/source/nttData.d`.
