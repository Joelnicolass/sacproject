# 061V — Cómo se ven en el original los hechizos de 061f y 061g

Este informe junta los hechos para el arte final de 061f (zonas: Explosion, Frozen Ground, Demonic Rift, Healing Aura) y 061g (muros: Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence). No trae diseño ni código. El plan está en `rfcs/plans/061-spells-master-plan.md` (piezas `GroundZone` y `SpellWall`) y los números de juego en `rfcs/research/061R-abilities-structures.md`. El usuario pidió **arte final desde el inicio**. El formato es el de `061V-spell-visuals-d-e.md`.

## Fuentes y etiquetas

- **[SAC archivo:línea]** sacengine (`sacengine/source/`, GPL, solo lectura). Se describe lo que hace; no se copió código. Si no se nombra el archivo, es `state.d`. sacengine carga texturas y mallas de las WAD originales, pero los números de dibujo (energía, transparencia, cantidad de partículas) los decidió su autor.
- **[TXTR]** texturas y mallas leídas de las WAD de la instalación (`SAC_INSTALL`) con el lector del port (`tools/import/sac_formats/`: `wad.py`, `txtr.py`, `models.py`). Se miraron tamaño, grilla (perfil de luminancia por fila y columna), color medio y alfa.
- **[SPEL]** **Fuente nueva de este informe.** El registro SPEL de cada hechizo (`spells.wad`, 314 bytes) trae, después de los números, dos tablas:
  - **Sonidos** (desde el byte ≈114): entradas `[bandera][' ' o '!'][etiqueta]`. `!` coincide con los sonidos que sacengine reproduce en lazo. Qué significa cada bit de la bandera: **NO VERIFICADO**.
  - **Recursos** (desde el byte ≈140): pares clave/valor. Las claves llevan prefijo `t` (etiqueta de textura, malla o partícula), `f` (float) o `i` (int).
- **[EXE 0xDIR]** `Sacrifice.exe` (GOG, sha256 `a53ebb53…abcb`, base 0x400000). Se usó el método de 061V d-e: cada `push imm32` que es una etiqueta, con el comienzo de función tomado de la tabla 0x4cbba8 (272 nombres) más todos los destinos de `call rel32`. **Mejora de este informe:** se desensamblaron con `objdump` (Apple LLVM, sin Ghidra) los tramos que importan. El patrón es siempre `push valor_por_defecto; push clave; push spel; call 0x4502e0` (lee una etiqueta) o `call 0x450320` (lee un float). Consecuencia: **las etiquetas que empuja el EXE son valores por defecto, y el registro SPEL los reemplaza.** Por eso varias atribuciones de 061V b-c y d-e se corrigen abajo.
- **[WEB]** se buscó una descripción de estos hechizos, sin resultados útiles. El texto de `MANUAL.PDF` no se pudo extraer (fuentes codificadas; en el entorno no hay `pdftotext` ni `pypdf`). No se vieron videos: **ninguna afirmación de este informe sale de una captura**.
- **[PORT]** código y datos del port (`game/…`).
- Precedencia: SPEL/EXE > sacengine > manual > web. Lo que no se pudo confirmar dice **NO VERIFICADO**.

Unidades: 60 ticks por segundo. sacengine anima los sprites a 30 cuadros por segundo (`updateAnimFactor = 2`).

### Correcciones a los informes anteriores

| Lo que se dijo | Lo que es | Prueba |
|---|---|---|
| `fbal`/`glo2` son de Healing Aura (b-c) | `fbal` es solo el **valor por defecto** de la clave `tcld` en `sub_42c460`. El SPEL `haur` pone `tcld = haur`. `glo2` sí son las partículas de Healing Aura | [SPEL haur], [EXE 0x42c460] |
| `quk1`/`mud1` son de Wall of Spikes (b-c) | Son valores por defecto (`tscr = quk1`, `ttex = mud1`/`spik`). El SPEL `swal` pone `ttex = jspk` y `tscr = gscr` | [SPEL swal], [EXE 0x446fb0, 0x447600] |
| `rift`/`tdmn` son de Wailing Wall (b-c) | `rift` es el valor por defecto de `tdmn`. El SPEL `wwal` pone **`tdmn = wlsp`**, que es lo mismo que usa sacengine | [SPEL wwal], [EXE 0x433580] |
| `fbal` también es de Explosion (d-e) | `fbal` es el valor por defecto de `ttex` en `sub_426760`. El SPEL `fexp` pone **`ttex = exeg`** | [SPEL fexp], [EXE 0x426760] |
| sacengine: la burbuja del poste de Fence es `scri` | `scri` es un ojo verde (otra cosa). El SPEL `fenc` pone **`tisp = bubl`** (burbuja violeta) y `tosp = cst0` | [SPEL fenc], [EXE 0x420d60] |

La misma lectura vale para los hechizos ya investigados. Antes de importar algo por una etiqueta de `push`, conviene mirar su SPEL. Script de lectura: abajo, en «Cómo se leyó».

### Banderas de dibujo del EXE (hipótesis)

Las funciones crean sus objetos de dibujo con una palabra de banderas (`call *0x4bf504`). Si se cruzan las banderas con lo que sacengine eligió para el mismo recurso, sale esta tabla:

| Bandera | Se usa con | sacengine lo dibuja |
|---|---|---|
| `0x1a012008` (y `0x12012008`) | `firy`, `glo2`, `cst0`, `cfx1`, `rif3`, `rift`, `fwal`, `exp2`, `exeg` | aditivo |
| `0x0a011008` / `0x02011008` | `shrd`, `frck`, `dirt`, `bubl`, `icec`, `wwal` | alfa (`icec`, `wwal`, la burbuja: Transparent) |
| `0x1a010401` | borde de Demonic Rift (`rif2`); el sprite XS con `iXS+ = 2` | aditivo con **energía −3** (oscurece) |
| `0x10001` | `jspk`, `vine` (mallas con luz) | material con luz |

Lectura probable: bit `0x2000` = aditivo, `0x1000` = alfa, `0x0400` = oscurecer. **NO VERIFICADO**: falta leer `0x4bf504`.

### Luces

Varias funciones llaman a `0x44ca20` con un radio y un color (lo comparten Manalith, portales y llamas: es casi seguro una luz dinámica). Healing Aura: 50 m, amarilla (1, 1, 0). Firewall: 100 m, naranja (1, 0,5, 0). Cada espíritu de Demonic Rift: 30 m, violeta (0,9, 0, 1). Explosion: amarilla. La regla del proyecto es que **el brillo del original sale de sprites aditivos, sin charcos de luz**. Estas luces quedan como dato, no como pedido.

### Partículas de sacengine que se repiten abajo

(sacobject.d:1413-1660; gravedad sacobject.d:1298-1340)

| Tipo | TXTR (WAD/carpeta) | Sprite | Energía | Mezcla | Gravedad | En el port |
|---|---|---|---|---|---|---|
| `firy` | `firy` (main/bits, 4×4) | 0,5 m | 8 | aditiva | no | `fx/firy.png`, `firy_a.png`, `data/fx/fire.tres` |
| `fireball` | `fbal` (main/bits, 3×3) | 0,5 m | 8 | aditiva | no | **falta** |
| `firewall` | `fwpt` (charlie/Pyro/txtr, 4×4: lenguas de fuego sobre negro) | 1 m | 8 | aditiva | no | **falta** |
| `explosion` | `xplo` (main/bits, 5×5: nubes de blanco a marrón, con alfa) | 3 m | 8 | aditiva | no | **falta** |
| `explosion2` | `exp2` (main/bits, 4×4: estallidos sobre negro) | 3 m | 8 | aditiva | no | **falta** |
| `ashParticle` | `frck` (charlie/Pyro/txtr, 4×4: brasas de blanco a naranja, con alfa) | 0,3 m | 10 | aditiva | sí | **falta** |
| `smoke` | `smok` (charlie/Pyro/txtr, 4×4: humo negro, alfa) | 1,5 m | 1 | alfa | no | **falta** |
| `shard`, `snowballShard` | `shrd` (charlie/Stra/txtr) | 1 m | 3 | aditiva | sí | `data/fx/freeze_shards.tres` |
| `lightningCasting` | `cst0` (main/bits) | 1 m | 3 | aditiva | no | `fx/cst0.png` |
| `heal` | `glo2` (main/bits) | 1 m | 4 | aditiva | no | `data/fx/heal.tres` |
| `castCharnel2` | `cfx1` (Daniel/DanC/char, 4×4: anillos violetas) | 1 m | 5 | aditiva | no | **falta** |
| `castPersephone2` | `cst1` (main/bits, 4×4: estrellas verdes) | 1 m | 5 | aditiva | no | **falta** |
| `castJames` | `cstj` (charlie/Jame/tex) | 1 m | 2 | aditiva | no | `fx/cstj.png`, `data/fx/cast_james.tres` |
| `dirt` | `dirt` (main/bits) | 1 m | 1 | alfa | no | `data/fx/dirt.tres` |

---

## 061f — Zonas en el suelo

### Explosion (`fexp`, Pyro; 061R: `pxef`)

**SPEL.** `ttex = exeg`, `tcst = firy`, `iCHg = 2`, `fXSa = 0,5`, `fXSe = 0,0`. Sonidos: `Xfir` (lazo; set `spel` = `sfx/comn/flp1..5.wav`) y `flam` (`sfx/pyro/flam.wav`).

**Assets.**
- `exeg` (charlie, `Bloo.WAD!/Pyro.FLDR/txtr.FLDR`): 256², atlas 4×4 de lava o fuego naranja opaco, con chispas. Es la textura de las 5 bolas que crecen mientras se lanza. No está importada.
- `xplo`, `exp2`, `frck`, `smok`: el estallido (tabla de arriba). No están importadas.
- `bold` (`MODL.WAD!/bold.MRMC`): roca de 151 vértices y 224 caras, caja ≈3,9 m, textura `M000` 128² marrón. Son los escombros. No está importada.
- `scar` (charlie, `Pyro.FLDR/scar.FLDR`, SCAR, 6344 bytes): la quemadura en el suelo. **No hay lector de SCAR.**

**El EXE** (`PyroExplosionRun` 0x426910 y sus funciones):
- `sub_426760` crea la bola del lanzamiento con `ttex` (= `exeg`), bandera aditiva, ángulos y giros al azar, un vector 6,0 (¿escala?) y alfa 255. También le pone una luz amarilla de radio 25 (`0x44ca20`, color (1, 1, 0) en 0x4cb8ec).
- Al estallar (0x426b2a en adelante), en orden:
  - `0x43afe0` crea el objeto genérico de explosión. Ese objeto es `INERT_StartExplosion` (0x43b280): ceniza `frck` (clave `tXbt`), sonido `fbxp` (`sfx/pyro/fbxp.wav`), el centro `ExplosionCenterStart` (0x43b090, `exp2` aditivo) y la quemadura `scar` (clave `tXsc`) puesta con `sub_453550`. `INERT_RunExplosion` (0x43b160) pone la cicatriz (`sub_44cb90`) y lee `iXsm` (¿humo?, **NO VERIFICADO**).
  - `0x439f10`, el sprite «XS» (abajo).
  - `0x438760(…, 8, 0,25, 'bold', 0,2, aditivo, 'firy', …, 5,0)`: **8 escombros** de la malla `bold` a escala 0,2, con estela `firy` (sacengine tira 15).
  - `0x44d9a0(…, 10, 20, 1/3, 7, 5, …)`: lo comparten Air Shield, Volcano, Erupt, la creación de edificios y el Sacrificio. Lectura probable: temblor de pantalla. **NO VERIFICADO**.

**El sprite «XS»** (`sub_439f10` → objeto `sub_439e50`, que se mueve con 0x439d60):
- Lo comparten Fireball, Dragonfire, Phoenix, las destrucciones de choza y de Manalith, el Gunhead y el Fire Clawpult.
- Lee `tXSt` (por defecto **`fwal`**; el SPEL de Explosion no lo cambia), `iXS+` (por defecto 1: bandera aditiva) y `fXSa`/`fXSe` (recortados a [0, 1] y ×255).
- Cada tick avanza t de 0 a 1 y luego se borra. Pasa los cuadros del atlas. Escala uniforme = lerp(inicio, fin, t). Color/alfa = lerp(`fXSa`, `fXSe`, t³), escrito en los cuatro canales.
- En Explosion, la escala final es 1,5 × `[spel+0x5c]` (effectRange 20 m, o sea **30 m**) y la vida es 0,5 s. Coincide con la esfera de sacengine que crece hasta 30 m (abajo).
- **NO VERIFICADO:** qué malla dibuja el objeto (esfera, anillo o sprite) y la vida exacta (el mapeo de argumentos se hizo a mano).

**sacengine** [SAC 10960-11013; 19032-19064; struct 3405-3424; 15084-15091; 27611-27681; 16631-16670; 15054-15082]:
- **Lanzamiento.** Las 5 posiciones son el punto del clic y 4 al azar en un disco de radio `effectRange`, a la altura del suelo. En cada una, una **esfera ruidosa** (`SacExplosionEffect`, sacobject.d:2752-2774: 24×25, ruido 0,24, 16 deformaciones morfeadas, atlas `exeg` 4×4 a 1 cuadro por 2 ticks) apoyada en el suelo:
  - radio = escala·1 m, escala (1,1; 1,1; 0,9);
  - gira media vuelta por segundo;
  - **3 capas** desfasadas 20 cuadros;
  - aditiva, energía 8, transparencia 0,5, sin escribir profundidad [renderer.d:439-449, 2430-2457].
- La escala sube de 0 a 1 durante el lanzamiento. Si se interrumpe, baja a 2/s. Cada bola tiene su lazo de sonido `flp5`. El mago tira `firy` (`animateCasting!(false,4,true)`).
- **Estallido** a los 38/10 s = **3,8 s** (`totalDelay`). En cada una de las 5 posiciones:
  - 150 `ashParticle` (`frck`) a 15–30 m/s, escala 1,75–4, vida 95;
  - 15 `Debris` (malla `bold` ×0,2) a ≈20 m/s con gravedad 30, que rebotan y dejan 3 `firy` por tick [renderer.d:1567-1575];
  - `explosionAnimation` a 1 m de altura: sonido `fbxp` (ganancia 1,75); dos esferas `Explosion` (`exeg` sobre una esfera 24×25 de 16 cuadros, aditiva, energía 1), una crece a 40 m/s hasta 30 m y otra a 10 m/s hasta 5 m, escala (1,1; 1,1; 0,9) [renderer.d:169-178, 1595-1605]; 200 partículas, mitad `explosion` y mitad `explosion2`, a 1,5–6 m/s, vida 31;
  - `animateFireballExplosion!10` a escala 2: 20 `explosion`, 80 `explosion2`, 30 `ash` y 7 `smoke`.
- Prende fuego a los blancos (el fuego del cuerpo ya existe). Los que están a ≤ effectRange + damageRange salen despedidos a 5–20 m/s.

**Qué reutilizar del port.**
- `scenes/spells/splash_damage.gd` para el daño.
- `scenes/units/impacts/burn_impact.gd` y el fuego del cuerpo para prender.
- `data/fx/fire.tres` / `firy` para la estela de los escombros.
- `scenes/spells/wards/air_bubble.gdshader` (061b ya hizo una esfera de ruido en capas) para las bolas `exeg`.
- `data/fx/shake_map.tres` para el temblor.
- **Ojo:** el Fireball del port estallaba con `wrath_explosion1/2` (`flao`/`wrth`), no con `xplo`/`exp2`. **Corregido el 2026-10-25:** `fireball_projectile.tscn` lleva su propia estela (`fireball_trail` = `firy` ×7 y `fireball_trail_core` = `fbal` ×1, escala 1,5) y su explosión (`fireball_blast`/`blast2`/`ash`/`smoke`: `xplo`, `exp2`, `frck`, `smok`).

**Qué falta.**
- Importar `exeg`, `xplo` (5×5), `exp2`, `frck`, `smok` y `fbal` (`fx_catalog.py`: `ATLASES`/`EXTRA_FX`).
- Importar la malla `bold` (`SPELL_MODELS` en `sac_formats/props.py`).
- La quemadura `scar` necesita un lector de SCAR.

### Frozen Ground (`froz`, Stratos; 061R: `zorf`)

**SPEL.** `tmod = sbll`, `tcst = cst0`, `fCHs = 0,25`. Sonidos: `Xfrz` (`sfx/stra/frez.wav`, `frz2..5`), `Xice` (`ish1..4`) y `Xcnj` (lazo, `sfx/comn/cnj1..6`).

**Assets.**
- `sbll` (`MODL.WAD!/sbll.MRMC`): bola de nieve de **132 vértices y 128 caras**, caja ≈1,15 × 1,23 × 1,17 m, textura `M000` 128² blanco celeste **con alfa**. No está importada.
- `icec` (charlie/Stra/txtr, 128², hielo celeste continuo). **Ya está en el port** (`fx/icec.png`).
- `shrd`: ya está.

**El EXE.**
- `FrozenGroundStart` (0x422050) → `sub_421c20` lee `tmod` (por defecto `bold`; el SPEL pone `sbll`), con un giro de 1/180 por tick. Tira `cst0` aditivas (2 por tick, 0,5) y `sub_439400` (`shrd`). Pasa `'frez'` a `sub_4535b0` (probable sonido).
- `FrozenGroundRun` (0x4225f0) lee `ttex` por defecto **`icec`** (el SPEL no lo cambia), con bandera alfa `0x02011008` y los números 10, 0,5, 2,5, 5, 1 y 0,05. `sub_422550` hace el estallido de `shrd` (256, 64, 20, 10, 0,25).
- El significado de cada número: **NO VERIFICADO**.

**sacengine** [SAC 11079-11116, struct 3599-3653, 19739-19900; renderer.d:1016-1025, 1109, 3369-3411; sacobject.d:2930-2943; dagonBackend.d:2803-2870]:
- **Lanzamiento.** La bola aparece 0,75 m delante del mago y sube del suelo hasta 0,5 m sobre su cabeza mientras crece de 0 a 1. Gira sobre un eje al azar a 0,5–1,5 vueltas/s. Se dibuja aditiva con energía 10. Sonido `Xcnj`. El mago tira `cst0` (`lightningCasting`).
- **Vuelo.** Tiro parabólico de **2 s** hasta el punto, gravedad 25. Estela: 2 `cst0` por tick, ±0,25 m, escala 1,5–2,5, vida 31.
- **Impacto.** 150 `shard` (15–30 m/s, vida 31) y 150 `snowballShard` (11–22 m/s, vida 63, con gravedad). Sonido `Xfrz` (ganancia 4).
- **El suelo helado.** Un anillo pegado al terreno a 0,5 m de altura (`GroundPatch`: 32 lados × 32 anillos). La u da 12 vueltas de textura alrededor y la v se repite 6 veces del centro al borde. Textura `icec`, mezcla **alfa**, energía 10, transparencia 0,2. El radio crece hasta `effectRange` en 0,5 s con curva √(1−(1−t)²).
- **La rotura.** Al vencer, el hielo se rompe de afuera hacia el centro en **6 anillos**, uno cada 5 ticks (0,5 s en total). Cada anillo:
  - 150 `shard` que suben a 10 m/s, escala 2–4, vida 31;
  - el sonido `Xice` con ganancia creciente.
- sacengine fuerza la duración a 15 s (sacspell.d:214, decisión suya). El dato del SPEL (061R) son 30 s.

**Qué reutilizar del port.**
- `scenes/units/afflictions/frozen.gd` (el bloque de hielo `icec` del congelado).
- `fx/icec.png`, `data/fx/freeze_shards.tres`, `fx/cst0.png` / `needle.tres`.
- `scenes/spells/spell_projectile.gd` para la parábola.

**Qué falta.**
- Importar `sbll` (`SPELL_MODELS`).
- El anillo de hielo en el editor: un `Decal` de Godot no da la proyección polar de 12×6 de sacengine. Lo idiomático es una malla de anillo hecha con **Blender CLI** (32×32, UV polar) más un shader que lo pegue al terreno y recorte los radios interior y exterior. La otra opción es un `Decal` con la textura en cuadrícula (divergencia menor; se decide con captura).

### Demonic Rift (`rift`, Charnel; 061R: `tfir`)

**SPEL.** `frad = 2,5`, `ffht = 1,5`, `tftx = rif2`, `tdtx = rift`, `idln = 45`, `tcst = cfx1`. Sonidos: `srft`, `crft`, `rfts` y `rfth` (`sfx/char/*.wav`, existen).

**Assets** (todos en Daniel.wad, `DanC.WAD!/char.FLDR`; ninguno importado):
- `rif2`: 256², tira **1×8** de llamas o estrías gris-blancas. El borde de la grieta.
- `rif3`: 256², 4×4, remolino violeta. El sprite que sube de la grieta.
- `rift`: 256², 1×8, estela violeta. Los espíritus.
- `cfx1`: 4×4, anillos violetas. El lanzamiento.

**El EXE.**
- `DemonicRiftRun` (0x430840) → `sub_430550`: `tftx` (por defecto `fwal`; el SPEL pone `rif2`), `frad` 2,5, `ffht` 1,5, bandera **`0x1a010401`** (la que se lee como oscurecer), los números 0,1, 1 y 0,25, y `rif3` aditivo (`sub_43a5e0`).
- `sub_430b40` (los espíritus, `DemonicRiftDemonRun`): `tdtx` = `rift` aditivo, `idln` 45 (¿largo de la estela?), luz violeta de 30 m.
- **Confirma** las cuatro texturas de sacengine.

**sacengine** [SAC 11065-11074, structs 3509-3580, 19507-19646; renderer.d:541-573, 2517-2598; sacobject.d:2837-2902]:
- **Borde.** Un cilindro abierto de 128 caras, radio `radius` (sacengine 2; SPEL 2,5) y alto 0,5·radio·`heightScale` (SPEL `ffht` 1,5). La v de `rif2` pasa por los 8 cuadros, uno cada 4 ticks. Va aditivo con **energía −3**, o sea que **oscurece**: es una boca negra, no un brillo. El alfa es `heightScale²`. Emerge a 0,5/s (2 s) y se cierra a 1/s.
- **Remolinos.** 6 por segundo: un sprite `rif3` 4×4 de 2,5 m (`makeSpriteMeshes!(B,true)`: el `true` pide doble cara) en el centro. Sube de 0,25 a 1,5 m, encoge en 2 s, con energía 20·escala⁴ (aditivo).
- **Espíritus.** Hasta 24, uno cada 1/3 s. Cada uno es una estela (malla de línea de 31 segmentos con aletas de 0,6 m, `rift` 1×8 estirado sin repetir, aditiva, energía 20, sin descarte de caras) por las últimas 120 posiciones.
  - Sale del borde hacia el blanco. Al pegar, **sube en espiral** 5 vueltas y 7,5 m en 4 s.
  - Después se va a un punto al azar 20 m arriba, vuelve a la grieta y se hunde mientras se achica.
  - Sonidos: `rfts` al nacer (el primero y 1 de cada 3), `rfth` al pegar.
- **Lanzamiento.** `cfx1` en las manos (`castCharnel2`). La grieta ya emerge mientras se lanza.

**Qué reutilizar del port.**
- `scenes/fx/fx_trail.gd` o `BeamFx`/`BeamType` para las estelas (la misma decisión de «camino curvo» de 061V d-e).
- `scenes/fx/portal_disc.gd` + `portal_disc.gdshader` como base del cilindro con atlas animado.
- `sprite_particles` para los remolinos `rif3`.

**Qué falta.**
- Importar `rif2`, `rif3`, `rift` y `cfx1`.
- El borde es un cilindro: un `CylinderMesh` abierto con shader de atlas alcanza, sin Blender.
- Para el oscurecimiento: `blend_mode = sub` o un `mul` en el shader. Se decide con captura de cámara fija.

### Healing Aura (`haur`, Persephone; 061R: `ruah`)

**SPEL.** `tcld = haur`. Sonido: `aura` en lazo (`sfx/pers/aura.wav`).

**Assets.** `haur` (charlie, `Bloo.WAD!/Pers.FLDR/tex.FLDR`): 256², atlas 4×4 opaco. Cada cuadro es amarillo dorado con un círculo verde oscuro en el centro y destellos. No está importado.

**El EXE** (`sub_42c460` ← `HealingAuraRun`): `tcld` (= `haur`), luz amarilla de 50 m, partículas `glo2` aditivas (3, 1,5, 2, 0,5, 2, 1), un objeto de escala 6 y alfa 255, y `sub_43f610` (`HEAL`: 256, 64, 256), la misma cura que usan Heal y Rainbow.

**sacengine** [SAC 11076-11094, 19648-19737; renderer.d:575-585, 2599-2625; sacobject.d:2904-2928]:
- **La aura** va pegada a la criatura aliada elegida, no al suelo. Es una **esfera ruidosa** (radio 0,5, ruido 0,06, 16 deformaciones morfeadas, 3 capas desfasadas) centrada en la criatura.
  - Mide (1,9; 1,9; 1,45) × su caja (el ancho, promediado en x e y). La escala va **negativa**: se ve por dentro.
  - Textura `haur` 4×4 con delay 2. Aditiva, energía 5, **transparencia 0,075**: un velo dorado muy tenue.
  - Crece en 30 ticks y se apaga en otros 30. Se apaga si la criatura ya no puede llevarla o se acaba la duración.
- **Cura.** A la portadora y a los de su bando a ≤ `effectRange`: un `Heal` de 256 ticks (sonido `laeh` = `sfx/comn/heal.wav` la primera vez).
- **Lanzamiento.** `heal` (`glo2`) en las manos y 6 por tick que suben desde la huella del mago.
- **Sonido.** `aura` en lazo sobre la portadora (ganancia 1).
- **Diferencia con el plan.** El plan la pone en `GroundZone`. En el original y en sacengine **la lleva una criatura**, así que encaja mejor en `BodyAura` (fila 2 del plan, que ya la nombra).

**Qué reutilizar del port.**
- `scenes/spells/heal_effect.gd` / `heal_effect.tscn` y `data/fx/heal.tres`.
- `scenes/spells/wards/air_bubble.gdshader` (esfera de ruido en capas de 061b) con `haur`.
- `BodyAura`/`Ward` de 061b como portador.

**Qué falta.** Importar `haur` (`EXTRA_FX`, 4×4).

---

## 061g — Muros

### Lo común: `WallPosition` y la malla del muro

[SAC 19935-19998, structs 3657-3990; sacobject.d:2996-3047]

- **Recorrido.** El centro es el clic y la dirección es perpendicular a la recta mago→clic. Cada extremo avanza `effectRange / castingLimit` por tick mientras se lanza, y se detiene en un edificio, en el vacío o a `effectRange` del centro. Al cruzar se aplica el efecto con `isInWall` (espesor 5 m).
- **Malla de muro** (`makeWallMesh`, Firewall y Wailing Wall):
  - Una cadena de 16 segmentos de 1 m, y cada segmento es un hueso.
  - Corte transversal en **techo a dos aguas**: dos láminas que van de (±0,5; 0) por (±0,2; 0,4) a (0; 1). Con espesor 5, la base mide 5 m de ancho.
  - La v va de abajo (≈1) a arriba (≈0) pasando 0,6 en el quiebre. La u se invierte en segmentos alternos.
  - Los huesos se reparten en ±(range−2,5)·16/14. Cada hueso se escala a (espesor, 0, alto·`scale(t)`). `scale(t)` = min(0,2·distancia al extremo, 1): **los extremos bajan en rampa a lo largo de 5 m**.
  - Un «fixup» estira la base hasta el punto más bajo del terreno bajo el espesor.
  - El alto ondula ±10 % con fase 0,125·t − tiempo (Firewall) o 0,125·t − 0,25·tiempo (Wailing Wall).
- **Valores del SPEL y del EXE.** El SPEL trae `fwid` (ancho) 5 y `fhgt`/`fHei` (alto) 7,5 en Firewall, Wailing Wall y Vinewall. Los valores por defecto del EXE son `fwid` 10 (Firewall, Wailing Wall, Fence) o 5, y alto 7,5. **Wailing Wall mide 7,5 m de alto según el SPEL**; sacengine usa 6.
- **Lo idiomático en el port.** Una malla de muro (techo a dos aguas, 16 segmentos con huesos) hecha **una vez con Blender CLI** (`wall_strip.glb`, con esqueleto), o un `ArrayMesh` con un shader que la doble por vértice (la u y la v de arriba). Firewall y Wailing Wall comparten la malla y cambian el material. Los extremos, la ondulación y el corte por edificios van en `SpellWall` y en el shader.

### Firewall (`frwl`, Pyro; 061R: `lwrf`)

**SPEL.** `fwid 5`, `tslp = burn` (¿qué es?, **NO VERIFICADO**; no hay sample `burn`), `fhgt 7,5`, `ttex = fwal`, `iCHg 2`, `tptx = fwpt`, `fint 0,1`, `tcst = firy`. Sonidos: `Xfir` en lazo (`flp1..5`), `ign2`, `ign1` y `onf2` (`sfx/pyro/*.wav`).

**Assets** (charlie, `Bloo.WAD!/Pyro.FLDR/txtr.FLDR`; ninguno importado):
- `fwal`: 256², atlas **4×4**. En el perfil son 4 filas de 64 px; cada cuadro es una franja de llamas naranja y amarilla, opaca.
- `fwpt`: 4×4, lenguas de fuego sueltas (las partículas).
- `quk1` (main, `MAIN.WAD!/scar.FLDR`, SCAR 1552 bytes): la grieta. Sin lector.

**El EXE.**
- `sub_428090` lee `ttex` = `fwal` con bandera aditiva y alfa 255, y le pone una luz naranja (1; 0,5; 0) de 100 m. Tira `firy` en el lanzamiento y crea dos objetos hijos:
  - `FireWallBits` (0x427d80): `tptx` = `fwpt`, aditivas, en una caja de ±3 × ±3 × ±1 con velocidad 5 y 0,8;
  - `FireWallEarthEffect` (0x427fb0): `firy` (1,25, 3, 1). También crea el objeto `0x42e990` (`VineWallEarthEffect`, `dirt`), la tierra que se levanta en el frente que avanza, y llama a `sub_45cb90` (sonido `flam`).
- `FireWallRun` deja la **grieta** `quk1` (`tscr` por defecto; el SPEL no lo cambia), igual que Bore.

**sacengine** [SAC 11118-11135, 19901-20090; renderer.d:598-607, 2639-2671; sacobject.d:3049-3062]:
- El muro con la malla común y `fwal` 4×4 (un cuadro cada 4 ticks), **aditivo, energía 15**.
- Alto 7,5. Sube en 2 s, se queda `duration`, y baja en 1 s.
- Partículas `firewall` (`fwpt`): ≈1 por tick en un punto al azar del muro, a 25–75 % del alto, con velocidad hacia arriba proporcional al alto y escala 0,8–3,75 × la rampa del extremo.
- Mientras crece: `firy` grandes (escala 3,5 × 1,5–3,75) en el frente.
- Lazo `ign2` (ganancia 3) a lo largo del muro. El mago tira `firy` y 6 que suben.

**Qué reutilizar del port.**
- `burning`/`burn_impact.gd` y el fuego del cuerpo para el daño (061R: 625/s × rampa de 3 s).
- `data/fx/fire.tres` (`firy`) para el frente.
- `data/fx/firewalk_trail.tres` / `firewalk_burst.tres` como molde de partículas que suben del suelo.

**Qué falta.**
- Importar `fwal` (malla, 4×4) y `fwpt` (`ParticleType` `firewall`, aditivo, 1 m, energía 8).
- La malla de muro (arriba).
- La grieta `quk1` necesita el lector de SCAR.

### Wall of Spikes (`swal`, James; 061R: `laws`)

**SPEL.** `tcst = dirt`, `ttex = jspk`, `tscr = gscr`, `iCHg 1`. Sonidos: `spku`, `spkd` y `spks` (`sfx/jams/*.wav`).

**Assets.**
- `jspk` (shawn, `jams.FLDR/text.FLDR`, 128², remolino marrón como corteza). **Ya está en el port** (`fx/jspk.png`; lo usa `SpikeField`).
- `gscr` (shawn, `jams.FLDR/scar.FLDR`, SCAR 4240 bytes): grieta. Sin lector.
- `spik` (main/bits, 128²) es una **foto de cielo con nubes**. Es el valor por defecto que el SPEL pisa, **no** la textura del pincho. Si el original lo usaba como reflejo (el material de sacengine es metálico): **NO VERIFICADO**.

**El EXE.**
- `SpikeWallStart` → `sub_446fb0`: `fwid` 5, `fHei` 7,5, `tscr` (= `gscr`), `ttex` (= `jspk`) con bandera de malla con luz `0x10001`, y el objeto de tierra `0x42e990`.
- `sub_4470b0` pone pinchos al azar en ±5 m, con ángulos π/2–π (inclinación) y escalas 0,5–2–5, y deja la grieta (`sub_44cb90`).
- `SpikeWallHitNTT` → `sub_447600`: pincho `jspk`, `dirt` (0,5, 3), grieta `gscr` y `sub_4591a0` (10, 1) (¿aturdir?).
- No hay malla `tmod`: **los pinchos son geometría generada**, como en sacengine.

**sacengine** [SAC 11175-11188, 20473-20670, structs 3875-3936; renderer.d:587-596, 2626-2655; sacobject.d:2945-2994]:
- **180 pinchos** repartidos durante el lanzamiento, cada uno cerca de un extremo que avanza (≤1,5 m) y a ±2,5 m del eje.
- Cada pincho es la malla `makeSpikeMesh(32; 0,6; 0,75; 0,3; 0,25)` con `jspk` y material con luz (especular, metálico 0,5, rugosidad 1). Escala 1,5. Eje inclinado: un punto de un disco de 3 m más 0,4–1,6 × 3 m de alto.
- Cada pincho crece en 0,5 s y se hunde en 1 s al final. Al nacer, 5 `dirt` en anillo (escala 1,875).
- **Al cruzar:** un `Spike` suelto sube y baja en 2/3 s debajo del blanco, hasta 1,5 × 3 m o hasta su centro. Suena `spks` y salen 25 `dirt` (vida 63).
- Sonidos: `spku` al lanzar, `spkd` al hundirse.

**Qué reutilizar del port.**
- `scenes/fx/spike_field.gd` + `spike_field.tscn`: **ya dibuja exactamente esta malla con `jspk`** (Rhinok). El pincho del golpe es un `SpikeField` de un pincho.
- El muro necesita un modo «pinchos fijos que crecen y se hunden» (hoy suben y bajan en 2/3 s). Son knobs (`lifetime_s`, escala sostenida), no un script nuevo.
- `scenes/units/afflictions/stunned.gd` y `status/pace_factors.gd` (×0,5).
- `data/fx/dirt.tres`, `cast_james.tres`.

**Qué falta.** Solo el lector de SCAR (`gscr`). No hay nada que modelar.

### Wailing Wall (`wwal`, Charnel; 061R: `laww`)

**SPEL.** `fwid 5`, `tcst = cfx1`, `fhgt 7,5`, `ttex = wwal`, `tdmn = wlsp`. Sonidos: `cwwl`, `lwwl` (lazo) y `Xwal` (`sfx/char/wal1..5.wav`).

**Assets** (ninguno importado):
- `wwal` (main/bits): 256², 4 filas de **caras que gritan** en marrón rojizo, con alfa. Grilla 4×4 según la malla de sacengine.
- `wlsp` (charlie, `Bloo.WAD!/Char.FLDR/tex.FLDR`): 1×8, estela verde amarillenta.
- `cfx1`.

**El EXE.**
- `sub_433b90` lee `ttex` = `wwal` con bandera **alfa** (`0x02011008`) y alfa **160** (≈63 % opaco), más `tcst` = `cfx1`.
- `WailingWallDemon` → `sub_433580`: `tdmn` = `wlsp` aditivo, con 0,5 y 0,3.
- `WailingWallRun` llama a `sub_436390` → `sub_4363d0`, que dibuja un **rayo `ltng`** (0,35, 0,25, 0,2; lo comparte Death). Lectura probable: el drenaje de maná se ve como un rayo hacia el que cruza. **NO VERIFICADO.** sacengine no lo dibuja.

**sacengine** [SAC 11137-11154, 20092-20312, structs 3728-3803; renderer.d:609-630, 2673-2758; sacobject.d:3065-3095]:
- **Muro.** Malla común con `wwal` 4×4 (un cuadro cada 4 ticks), mezcla **alfa**, transparencia 0,8, energía 1. Alto 6 (el SPEL dice 7,5). Ondula más lento que el Firewall.
- **12 espíritus de patrulla** (`wlsp`: malla de línea de 31 segmentos, 0,6 m, aditiva, energía 20, estela de 90 posiciones). Van de punto en punto a lo largo del muro, a 20–100 % del alto y hasta 1,2× el largo.
- **Al cruzar** (drena maxMana/s): un espíritu orbita al blanco 8 s (curva de Hermite en un disco de radio de su caja + 0,5).
- Al bajar el muro, los espíritus se apagan escalonados en 4 s.
- **Sonido.** Lazo `lwwl` (ganancia 1,5) a lo largo del muro. Un lamento `Xwal` cada ≈0,5 s en un punto al azar. `cwwl` al lanzar. El mago tira `cfx1` y 6 que suben.

**Qué reutilizar del port.**
- `scenes/fx/fx_trail.gd` / `BeamFx` para los espíritus (lo mismo que Demonic Rift).
- `scenes/units/abilities/lightning_strike.gd` y `data/fx/beams/lightning.tres` si se confirma el rayo.
- `status/pace_factors.gd` (×0,75) y el `mana_pool`.

**Qué falta.**
- Importar `wwal` (malla, 4×4, alfa), `wlsp` (1×8) y `cfx1`.
- La malla de muro común.

### Vinewall (`vwal`, Persephone; 061R: `lawv`)

**SPEL.** `fwid 5`, `fhgt 7,5`, `ttex = vine`, `tsfx` (valor no textual), `tdrt = pvin`, `tcst = cst1`. Sonidos: `root`, `vinu` y `vind` (`sfx/pers/*.wav`).

**Assets** (ninguno importado):
- `vine` (charlie/Pers/tex, 64²): degradé de verde oscuro a ocre y naranja. Es la misma de Grasping Vines (061V b-c).
- `pvin` (charlie/Pers/tex, 256² con alfa): destellos verdes chicos. La grilla no sale limpia: el perfil da ≈5 columnas y ≈6 filas, **NO VERIFICADO**. Son las partículas de la base de cada liana. Para esa clave el EXE usa por defecto `dirt`, y Grasping Vines usa `dirt`; **Vinewall usa `pvin`**.
- `cst1`.

**El EXE.**
- `sub_42ea60`: `ttex` = `vine` con bandera de malla con luz `0x10001`, y el objeto de tierra `0x42e990`. Ese objeto (`sub_42e870`) lee `tdrt` (= `pvin`) con bandera alfa, 1,25 y 3.
- `sub_42ec10` aplica las lianas al que cruza (`PARA`, `dirt`, `vine`, 5, 8).

**sacengine** [SAC 11156-11173, 20314-20470, struct 3806-3873; renderer.d:2232-2259]:
- **180 lianas**, cada una cerca de un extremo que avanza y a ±2,5 m del eje. Es la misma liana de Grasping Vines (tubo de 19 segmentos y 24 lados, spline con resortes; 061V b-c), de la base a 7,5 m de alto, escala 4,05–4,95.
- Crecen en 1 s, se recogen en 1 s al final y se retuercen sin parar.
- Al nacer cada liana, 5 `castPersephone2` (`cst1`) en anillo, escala 5,6. El EXE usa `pvin` para esto.
- Al cruzar: Grasping Vines sobre el blanco (ya cubierto en 061c), con la animación de lanzamiento de lianas sobre el blanco.
- Sonidos: `root` al lanzar y en cada blanco; `rfad` al recogerse. El SPEL trae `vinu`/`vind`, que por nombre son subir y bajar: **NO VERIFICADO** cuál suena cuándo.

**Qué reutilizar del port.** Todo lo de lianas de **061c** (todavía no implementado): `vine.glb` (Blender CLI, tubo de 24×19 con 20 huesos) y `scenes/units/afflictions/vined.gd`. El muro es esa liana instanciada 180 veces (un `MultiMesh` no sirve con huesos; hacen falta 180 instancias de la escena, o una versión con la animación de resorte en el shader de vértices).

**Qué falta.** Importar `vine`, `cst1` y `pvin`. La malla de liana sale de 061c.

### Fence (`fenc`, Stratos; 061R: `cnef`)

**SPEL.** `tcst = cst0`, `tisp = bubl`, `tosp = cst0`, `fSPa 255`, `fCHs 0,25`. Sonidos: `Xltn` (`sfx/stra/ltn1..6`) y `elcd` (`sfx/stra/elcd.wav`).

**Assets.**
- `bubl` (charlie, `Bloo.WAD!/Stra.FLDR/txtr.FLDR`): **64², una sola burbuja violeta de vidrio** con un brillo, con alfa. No está importada.
- `cst0` (ya está).
- `ltng` / `ltn2` para los rayos (la decisión pendiente de 061V d-e).

**El EXE.**
- `FenceRun` crea **dos objetos `LightningRodRun` (0x420ff0) por paso**. Los postes son «pararrayos».
- `sub_420d60` lee `tisp` (= `bubl`, bandera alfa) y `tosp` (= `cst0`, aditivo). Gira 0,0262 rad/tick (**1,5 vueltas por segundo**) y tira rayos `ltng` con `sub_437370` (0,5, 1,5).
- El lanzamiento usa `sub_436160` (`ltng`, lo comparte Chain Lightning).

**sacengine** [SAC 11194-11211, 20671-20895, structs 3939-3990; renderer.d:632-646, 2759-2772; sacobject.d:3097-3112]:
- **Postes.** Hasta 12, dos cada 32 ticks (uno en cada frente). Cada poste es **un sprite** de 3 m dibujado dos veces: la burbuja (sacengine usa `scri`, mal: es `bubl`) con mezcla alfa, y encima `cst0` 4×4 aditivo con energía 5 (delay 2).
- Flotan entre 2,5 y 5,5 m sobre el suelo con un vaivén de 3,6 s. Crecen en 0,5 s y se apagan en 1 s.
- **Rayos.**
  - Al nacer un poste: 3–5 rayos desde puntos a 10 m.
  - Entre postes vecinos: un arco cuando la carga lo dispara, con 1–2 s de enfriamiento.
  - Descargas al suelo a 5–15 m.
  - Contra criaturas a ≤ `attackRange`, con probabilidad 0,9/s.
  - Todos son `lightning` completos (`Xltn`).
- **Lanzamiento.** Rayitos verticales en la caja del mago ×2 (como Chain Lightning) y `cst0`.

**Qué reutilizar del port.**
- `scenes/units/abilities/lightning_strike.gd` (`LightningStrike`) + `BeamType` `data/fx/beams/lightning.tres` para cada rayo.
- `scenes/units/abilities/call_lightning.gd` como molde de descarga al suelo.
- `sprite_particles` / un `Sprite3D` con billboard para la burbuja y las chispas.

**Qué falta.** Importar `bubl` (64², una imagen). No hay nada que modelar.

---

## Resumen: qué importar y con qué herramienta

Las texturas van con `tools/import/import_ui.py` y `fx_catalog.py` (`ATLASES` para partículas, `EXTRA_FX` para texturas de malla); salen a `assets/original/fx/`. Las mallas, con `tools/import/import_props.py` (`SPELL_MODELS` en `sac_formats/props.py`). Hace falta el original instalado (`SAC_INSTALL`). Se comprobó que todo existe en la instalación.

| Tag | WAD / carpeta | Tamaño / grilla | Uso | Hechizo |
|---|---|---|---|---|
| `exeg` | charlie · `Bloo.WAD!/Pyro.FLDR/txtr.FLDR` | 256², 4×4 | bolas del lanzamiento y esfera del estallido | Explosion |
| `xplo` | main · `MAIN.WAD!/bits.FLDR` | 256², **5×5** | partícula `explosion` | Explosion (y Fireball) |
| `exp2` | main/bits | 256², 4×4 | `explosion2`, centro del estallido | Explosion |
| `frck` | charlie/Pyro/txtr | 256², 4×4, alfa | ceniza | Explosion |
| `smok` | charlie/Pyro/txtr | 256², 4×4, alfa | humo | Explosion |
| `fbal` | main/bits | 256², 3×3 | `fireball` | Explosion (y Dragonfire) |
| `bold` | models · `MODL.WAD!/bold.MRMC` | 151 vért. | escombros ×0,2 | Explosion |
| `sbll` | models · `MODL.WAD!/sbll.MRMC` | 132 vért., alfa | bola de nieve | Frozen Ground |
| `rif2` | Daniel · `DanC.WAD!/char.FLDR` | 256², 1×8 | borde de la grieta | Demonic Rift |
| `rif3` | ídem | 256², 4×4 | remolinos | Demonic Rift |
| `rift` | ídem | 256², 1×8 | espíritus | Demonic Rift |
| `cfx1` | ídem | 256², 4×4 | lanzamiento de Charnel | Demonic Rift, Wailing Wall |
| `haur` | charlie · `Bloo.WAD!/Pers.FLDR/tex.FLDR` | 256², 4×4 | esfera de la aura | Healing Aura |
| `fwal` | charlie/Pyro/txtr | 256², 4×4 | muro de fuego (y sprite XS de las explosiones) | Firewall |
| `fwpt` | charlie/Pyro/txtr | 256², 4×4 | partícula `firewall` | Firewall |
| `wwal` | main/bits | 256², 4×4, alfa | muro de caras | Wailing Wall |
| `wlsp` | charlie · `Bloo.WAD!/Char.FLDR/tex.FLDR` | 256², 1×8 | espíritus | Wailing Wall |
| `vine` | charlie/Pers/tex | 64² | lianas | Vinewall (y Grasping Vines) |
| `pvin` | charlie/Pers/tex | 256², grilla NO VERIFICADA | destellos de la base | Vinewall |
| `cst1` | main/bits | 256², 4×4 | lanzamiento de Persephone 2 | Vinewall |
| `bubl` | charlie · `Bloo.WAD!/Stra.FLDR/txtr.FLDR` | 64², 1 | burbuja del poste | Fence |
| `scar` | charlie · `Pyro.FLDR/scar.FLDR` (SCAR) | — | quemadura | Explosion; sin lector |
| `quk1` | main · `MAIN.WAD!/scar.FLDR` (SCAR) | — | grieta | Firewall; sin lector |
| `gscr` | shawn · `shwn.WAD!/jams.FLDR/scar.FLDR` (SCAR) | — | grieta | Wall of Spikes; sin lector |

**Ya están en el port:** `icec`, `shrd`, `jspk`, `cst0`, `cstj`, `glo2`, `dirt`, `firy`/`firy_a`, `ltn2`. **Todos los sonidos nombrados** están en `assets/original/audio/` (`flam`, `fbxp`, `flp*`, `frez`/`frz*`, `ish*`, `cnj*`, `srft`, `crft`, `rfts`, `rfth`, `aura`, `heal`, `ign1`, `ign2`, `onf2`, `spku`, `spkd`, `spks`, `cwwl`, `lwwl`, `wal1..5`, `root`, `vinu`, `vind`, `rfad`, `ltn*`, `elcd`).

**Mallas.**
- **Importador existente** (`SPELL_MODELS`): `bold` y `sbll`. Del original; no se modela nada.
- **Blender CLI:**
  - la malla de muro (techo a dos aguas, 16 segmentos con huesos), compartida por Firewall y Wailing Wall;
  - el anillo polar de Frozen Ground (32×32), si se elige malla en lugar de `Decal`;
  - la liana `vine.glb` (sale de 061c y la usa Vinewall).
- **Primitivas de Godot o lo que ya tiene el port:** el cilindro de Demonic Rift (`CylinderMesh` abierto), las esferas de ruido de Explosion y Healing Aura (shader de `air_bubble`), los pinchos (`SpikeField`), las estelas (`fx_trail`/`BeamFx`), los rayos (`LightningStrike`) y la burbuja del poste (`Sprite3D`).
- **Lector nuevo:** SCAR, para `scar`, `quk1` y `gscr`. Ya lo pedían 061V b-c y d-e.
- **Aseprite:** no hace falta.

## Pendientes antes de dibujar (NO VERIFICADO)

1. **El sprite XS de las explosiones** (`sub_439f10`, textura por defecto `fwal`): ¿qué malla dibuja (esfera, anillo o sprite), y la vida y escalas exactas? Afecta a Explosion y a Fireball, Dragonfire y Phoenix.
2. **Banderas de dibujo** `0x1a012008` / `0x0a011008` / `0x1a010401`: leer `0x4bf504` para confirmar aditivo, alfa y oscurecer (el borde de Demonic Rift depende de esto).
3. **Wailing Wall:** ¿el rayo `ltng` de `sub_4363d0` es el drenaje hacia el que cruza? ¿Alto 7,5 (SPEL) o 6 (sacengine)? Lo que manda es el dato: 7,5.
4. **Frozen Ground:** el significado de los números de `FrozenGroundRun` (10; 0,5; 2,5; 5; 1; 0,05) frente al anillo de 12×6 de sacengine. Duración: SPEL (061R) 30 s; sacengine fuerza 15 s.
5. **Vinewall:** la grilla de `pvin`, y cuándo suenan `vinu`/`vind`.
6. **Firewall:** qué son `tslp = burn` y `fint 0,1`.
7. **Rayo** `ltng` o `ltn2` (pendiente de 061V d-e): afecta a Fence y a Wailing Wall.
8. **Luces** del EXE (Healing Aura, Firewall, Demonic Rift, Explosion): quedan como dato. Por la regla del proyecto, el brillo va con sprites aditivos.
9. Ninguna apariencia se confirmó con un video. Cada arte nuevo se cierra con una captura de cámara fija y un criterio numérico (CONVENTIONS §2c).

## Cómo se leyó (reproducible, sin rutas personales)

- **SPEL:** de cada registro de `spells.wad` (`wad.walk`), los bytes 96-140 son la tabla de sonidos `[bandera][' '/'!'][etiqueta]`. Desde el byte 136 se buscan pares clave/valor de 8 bytes: la clave es la etiqueta al revés con prefijo `t`/`f`/`i`; el valor es una etiqueta al revés, un float32 o un int32.
- **EXE:**
  - `objdump -d --start-address=… --stop-address=…` sobre el ejecutable;
  - los límites de función salen de la tabla 0x4cbba8 (36 bytes por entrada: nombre[28], función, hash) más los destinos de `call rel32`;
  - `0x4502e0` es «leer etiqueta del SPEL con valor por defecto» y `0x450320` es «leer float».
- **Texturas:** `sac_formats.txtr.folder_texture` sobre cada carpeta; la grilla sale de perfiles de luminancia por fila y columna.
- No se abrió Ghidra ni Godot.
