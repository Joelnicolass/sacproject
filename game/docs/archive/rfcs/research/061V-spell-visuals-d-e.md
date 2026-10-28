# 061V — Cómo se ven en el original los hechizos de 061d y 061e

Investigación de hechos para el arte final de 061d (almas: Soul Mole, Animate Dead, Soul Wind) y 061e (saltos y dirigidos: Chain Lightning, Rainbow, Dragonfire, Halo of Earth). No tiene diseño ni código. El plan es `rfcs/plans/061-spells-master-plan.md`, los números de juego están en `rfcs/research/061R-abilities-structures.md`, y el usuario pidió **arte final desde el inicio**. Formato y método iguales a `061V-spell-visuals-b-c.md`.

## Fuentes y etiquetas

- **[SAC archivo:línea]** sacengine (`sacengine/source/`, GPL, solo lectura). Se describe lo que hace; no se copió código. Si no se nombra el archivo, es `state.d`. sacengine carga texturas y mallas de las WAD originales, pero los números de dibujo (energía, transparencia, cantidad de partículas) son decisiones de su autor. Donde el ejecutable dice otra cosa, se avisa.
- **[TXTR]** texturas y mallas leídas de las WAD de la instalación (`SAC_INSTALL`) con el lector del port (`tools/import/sac_formats/`: `txtr.py`, `wad.py`; cabecera MRMM según SAC mrmm.d:47-71). Se miraron tamaño, grilla, color y, en las mallas, cuadros, caras y caja.
- **[EXE 0xDIR]** `Sacrifice.exe` (GOG, sha256 `a53ebb53…abcb`, base 0x400000). Igual que en 061V b-c: cada `push imm32` de `.text` cuyo inmediato es una etiqueta de 4 letras. **Mejora de método en este informe:** además de la tabla de funciones con nombre de **0x4cbba8** (272 entradas), se tomaron como comienzo de función todos los destinos de `call rel32` (E8) del `.text`. Así cada etiqueta cae en su función real (con nombre o `sub_XXXXXX`), y se sigue quién la llama. Esto corrige atribuciones del método viejo: por ejemplo, `fbal` «de Dragonfire» está en `sub_426760`, que llama `PyroExplosionRun`; `rif3` «de AnimateDeadRun» está en `sub_42f840`, que llama `DeathPortalEffect`; `rock` «de HaloOfEarthRun» está en `sub_445b40`, que llama `MeteorRun`. Sigue valiendo la advertencia: una etiqueta prueba que el original usa ese recurso en esa función, no qué dibuja. No se desensamblaron instrucciones con REA/Ghidra en esta pasada (no se abrió Ghidra; no quedó ninguno corriendo).
- **[SPEL]** **Agregado el 2026-10-24 (método de 061V f-g).** El registro SPEL de cada hechizo (`spells.wad`) trae una tabla de sonidos (`!` = lazo) y una tabla de recursos clave/valor. El EXE lee cada recurso con `0x4502e0(spel, clave, valor_por_defecto)`: **las etiquetas que empuja el EXE son valores por defecto y el SPEL las pisa**; una etiqueta empujada **sin** clave (directo a un cargador) es fija. Precedencia nueva: SPEL > EXE > sacengine. Las fichas corregidas lo dicen en un bloque «SPEL».
- **[WEB]** se buscó en la web («Soul Mole», «Soul Wind», «Halo of Earth» de Sacrifice) sin resultados útiles. El texto del `MANUAL.PDF` no se pudo extraer en esta pasada (fuentes codificadas). No se vieron videos: **ninguna afirmación de este informe sale de una captura.**
- **[PORT]** código y datos del port (`game/…`).
- Precedencia: EXE/datos > sacengine > manual > web. Lo que no se pudo confirmar dice **NO VERIFICADO**.

Unidades: 60 ticks por segundo; sacengine anima los sprites a 30 cuadros por segundo (`updateAnimFactor = 2`), así que un atlas 4×4 con `delay` d dura 32·d ticks.

Partículas de sacengine que se repiten abajo (mezcla según [SAC dagonBackend.d:2672-2683]; `dust` además con alfa 0,25):

| Tipo sacengine | TXTR (WAD/carpeta) | Sprite | Energía | delay | Mezcla | Gravedad | En el port |
|---|---|---|---|---|---|---|---|
| `dust` | `dust` (shawn/jams/text) | 1 m | 1 | 1 | alfa (×0,25) | no | `fx/dust.png`, `data/fx/rock_dust.tres` |
| `rock` | `rock` (main/bits) | 1 m | 1 | 1 | alfa | sí | `data/fx/rock.tres`, `petrify_rocks.tres` |
| `dirt` | `dirt` (main/bits) | 1 m | 1 | 2 | alfa | no | `data/fx/dirt.tres`, `dirt_cast.tres` |
| `heal` | `glo2` (main/bits) | 1 m | 4 | 1 | aditiva | no | `data/fx/heal.tres` |
| `lightningCasting`, `chainLightningCasting` | `cst0` (main/bits) | 1 m | 3 | 1 / 2 | aditiva | no | `fx/cst0.png` (`needle.tres` lo usa) |
| `spark` | `sprk` (charlie/Stra/txtr) | 2 m | 15 | 2 | aditiva | sí | **falta** (el port usa `styx_spark` de reserva) |
| `rainbowParticle` | `prbw` (charlie/Pers/tex) | 1 m | 5 | 2 | aditiva | sí | `data/fx/rainbow.tres` |
| `castCharnel2` | `cfx1` (Daniel/DanC/char) | 1 m | 5 | 1 | aditiva | no | **falta** (también lo pide 061c) |
| `firy` | `firy` (main/bits) | 0,5 m | 8 | 1 | aditiva | no | `fx/firy.png`, `firy_a.png` |
| `fireball` | `fbal` (main/bits, 3×3) | 0,5 m | 8 | 1 | aditiva | no | **falta** |

(Tabla: sacobject.d:1425-1430, 1467-1478, 1563-1566, 1582-1587, 1612-1617, 1660-1671, 1775-1787; energías de `sparkAnimation` sacobject.d:1516-1520.)

**Mallas «de línea» de sacengine** [SAC sacobject.d:2189-2227]. Varios efectos de este informe (rayos, arcoíris, estelas de Animate Dead) usan la misma malla: una cadena de `n` segmentos, cada uno con **3 aletas** a 120° que salen del eje hasta una distancia `size`. Cada anillo es un hueso, y el código pone los huesos sobre la curva. Con `repeat` la textura se repite en cada segmento; sin `repeat` se estira a lo largo de toda la cadena. El port ya tiene esta forma: `scenes/fx/beam_fx.gd` + `BeamType` (`width_m` = `size`, `segments`, `bolts`).

---

## 061d — Almas

### Soul Mole (`pmcd`, James)

**Qué dice el original.** No se encontró descripción (manual y web, ver Fuentes). La forma general sale de sacengine.

**Assets.**
- En `models.wad` **no hay ningún modelo de topo** (las carpetas MRMC son `bess bold bovi dfir loca mrph rage rock rokm roks sbll`), ni en otra WAD (se buscó `mol*`). En `spells.wad` el SPEL está como `dcmp`.
- sacengine dibuja en la posición del topo la **malla `rock`** (`MODL.WAD!/rock.MRMC`, 503 vértices, caja ≈2×2×2,2 m) a escala 1, sin rotar y en la altura del suelo: una roca medio enterrada que se desliza [SAC renderer.d:2012-2044, 1043].
- ~~[EXE] El candidato es `BurrowRun`: el topo no se ve~~ **Corregido (SPEL `dcmp`, 2026-10-24).** El SPEL de Soul Mole se llama `dcmp` = **Decompose**, y su función es **`DecomposeStart` (0x444060)** → `sub_443e80`, no `BurrowRun`. `sub_443e80` lee `tmod` con **`rock`** por defecto (el SPEL no lo cambia) y lo carga con el cargador de mallas (`sub_469230`, el mismo de Dragonfire y Frozen Ground); `ttrl` = `dust` (estela, bandera alfa), `tbit` = `rock` (piedritas) y llama a `sub_4591a0(10, 0)` (¿aturdir?). `DecomposeStart` tira `dirt` (1,2; 1,2; 0,5; 3) y comparte la rutina del recorrido con Soul Wind (`sub_423980`). **El topo es la malla `rock` visible, como en sacengine.**
- **SPEL `dcmp`:** `ttrl = dust`, `tcst = dirt`, `iCHg = 1`, `iCH+ = 0`. Sonidos: `Xquk` en lazo (bandera 1) y `sstl` (bandera 4). **Confirma** los sonidos de sacengine (`bore` = `Xquk`, `sstl`).

**Recorrido** [SAC 10814-10830, 17938-18028]:
- Nace en los pies del mago al **empezar** a lanzar y ya se mueve mientras el mago lanza.
- Ida en 270 ticks (4,5 s) por una curva de Hermite (`cintp2`) desde el mago hasta el alma. La tangente final es 0,75·distancia, **perpendicular** a la recta mago→alma: el camino se curva hacia un costado.
- Al llegar suena `ltss` (= `sfx/char/sstl.wav`, ganancia 5), corta el alma del cadáver (que empieza a disolverse) y la arrastra.
- Vuelta en 270 ticks más hasta el mago (el que está ahora), con el alma pegada al topo. Fin a los 540 ticks (9 s).
- La altura es siempre la del terreno.
- Aturde (`stunWithCooldown`) a todo lo que esté a ≤ `effectRange` del topo, cada tick (061R).

**Partículas** [SAC 17896-17922]:
- Si está sobre tierra: 2 `dust` por tick repartidas entre la posición anterior y la nueva, ±0,6 m al azar, escala 2, vida 31, sin velocidad. Es una nube de polvo pegada al suelo.
- Siempre: 2 `rock` por tick que salen del topo en dirección al azar a 5–10 m/s, escala 0,5–2, vida 63, con gravedad. Es un chorro de piedritas.
- Lanzamiento del mago: `animateRockCasting`, una `dirt` por mano por tick, en direcciones al azar [SAC 17877-17894; `animateRockCasting`].

**Sonido.** Lazo `bore` (`Xquk` del set `spel` = `sfx/jams/eqk1..3.wav`, ganancia 5) mientras se mueve; `sstl.wav` al tomar el alma. **Confirmado por el SPEL** (`Xquk` en lazo, `sstl`).

**Qué reutilizar del port.**
- `data/fx/rock_dust.tres` (dust) y `data/fx/rock.tres` (rock con gravedad) para el rastro.
- `props/rock.glb` (MODL `rock`, importado por `tools/import/import_props.py`, `SPELL_MODELS`) si se quiere la roca de sacengine.
- Mover el alma: `scenes/souls/soul.gd` y `scenes/units/abilities/rend_soul.gd` / `strikes/soul_strike.gd` (ya cortan y mueven almas).
- Aturdir: `scenes/units/afflictions/stunned.gd`.

**Decisión (resuelta por el SPEL/EXE).** El topo es la **roca `rock` visible** (`props/rock.glb`), como en sacengine, con estela `dust` y piedritas `rock`. No se modela ningún topo.

**Qué falta.** Nada por importar. El surco era de `BurrowRun` (otro hechizo): Soul Mole no deja grieta.

### Animate Dead (`deda`, Charnel)

**Qué dice el original.** No se encontró descripción en esta pasada. sacengine: revive al instante la criatura de esa alma.

**Assets.**
- `and2` (Daniel.wad, `DanC.WAD!/char.FLDR`): 256², tira de **1×8** cuadros. Cada cuadro es un arco fantasmal gris con una cabeza verde brillante que avanza por el arco, y una cola violeta difusa. No está importado.
- `cfx1` (misma carpeta): partículas del segundo nivel de Charnel. No está importado.
- [EXE 0x42f040 `AnimateDeadStreamerRun`]: `push 'and2'` + `tstx` (textura de estela) e `ilen` (largo). **Confirma** las estelas con `and2`.
- **SPEL `aded` (2026-10-24):** `iadd = 0`, `tstx = and2`, `tcst = cfx1`, **`tSPK = cfx1`**. Sonidos: `sac0` en lazo (bandera 2), `Xanm` (bandera 4, `sfx/char/anm1..2.wav`), `sac9` (bandera 8) y `anme` (bandera 16, `sfx/char/anme.wav`). `AnimateDeadRun` llama a la rutina común de chispas (`0x438ff0` → `0x438e30`, clave `tSPK`): **el estallido `cfx1` sobre la criatura está confirmado**, igual que el lanzamiento `cfx1`. `AnimateDeadStreamerRun` lee `tstx` (= `and2`, aditiva) e `ilen` (por defecto 20; el SPEL no lo trae; sacengine usa 31 segmentos). `Xanm` y `anme` no los usa sacengine.
- [EXE 0x42f4f0 `AnimateDeadRun`]: `push 'glo2'` **fijo** (sin clave) con la bandera `0x1a010401` (la que en 061V f-g se lee como «oscurecer»). Llama a `sub_41b200`, `sub_41b290`, `sub_41b300` y `sub_41b7c0`, las mismas que usa `ResurrectRun` (0x41b8b0, que también empuja `glo2`). Lectura probable: el original revive con la misma rutina que la resurrección y con partículas `glo2`, donde sacengine usa `cfx1`. **NO VERIFICADO** qué dibuja cada una.

**Al lanzar** [SAC 10859-10903, 18296-18311]:
- En sacengine la reanimación ocurre al **empezar** el lanzamiento (`castAnimateDead` llama `animateDead` antes de crear el casting); mientras dura el lanzamiento solo hay partículas `castCharnel2` en las manos.
- Sobre la criatura: 128 `castCharnel2` (cfx1, aditivas, energía 5) en su caja ×1,2, con velocidad horizontal unitaria hacia afuera y 0–2 m/s hacia arriba, escala 2, vida 31. Es un estallido violeta.
- Suena `0cas` = `sfx/sacr/sac0.wav` (ganancia 2).
- La criatura pasa a `reviving` (no `fastReviving`) [SAC 14101-14131]: dura `reviveTime` entero. Sube `reviveHeight` en la primera mitad, gira **2 vueltas** (4π) en total, hace las animaciones `corpse` → `float_` y al final cae (`tumbling`) y queda en reposo.

**Las estelas** [SAC 18328-18352; renderer.d:400-409, 2332-2359; sacobject.d:2674-2688]:
- Mientras dura la reanimación, cada 2 ticks con probabilidad 1/2 (≈15 por segundo) nace una estela del mago a la criatura.
- **Camino.** Curva de Hermite del punto de origen del mago (centro de su caja a 0,8 del alto) al centro de la criatura. Tangente de salida 2·dist·normal((0,0,3) + 2·dir al azar): sube. Tangente de llegada 2·dist·normal((0,0,−3) + 2·dir al azar): cae sobre la criatura. Cada estela hace un arco distinto.
- **Tramo visible.** Una fracción U(0,15; 0,5) de la curva, que viaja del mago a la criatura en 128 ticks (2,1 s): un cometa.
- **Malla.** Cadena de 31 segmentos, aletas de 0,6 m, textura estirada a lo largo (sin `repeat`). Cuadro de `and2` cada 4 ticks (ciclo de 32).
- **Material.** Sin sombreado, **aditivo**, energía 10, sin escribir profundidad, sin descarte de caras.
- **Sonido.** Lazo `9cas` = `sfx/sacr/sac9.wav` (ganancia 2) sobre la criatura, con intervalos al azar.

**Qué reutilizar del port.**
- `scenes/units/abilities/fast_revive.gd`: ya hace la subida y el giro. Para Animate Dead cambian los knobs: `revive_ticks` = `reviveTime`·60, `rise_ticks` = la mitad, `turns` = 2 (sin `fast`).
- `BeamFx`/`BeamType` para las estelas, con un camino curvo de Hermite (hoy solo dibuja segmentos rectos con ruido; hace falta un modo curva), 1 aleta-cadena, `jitter_m` 0, `width_m` 0,6, `segments` 31, atlas `and2` 1×8.
- La misma curva sirve para Rainbow (abajo): conviene un único «camino del rayo» en `BeamType`.

**Qué falta.** Importar `and2` y `cfx1` (Daniel.wad; el archivo real es `Daniel.wad`, con mayúscula).

### Soul Wind (`dnws`, Stratos)

**Qué dice el original.** No se encontró descripción en esta pasada. sacengine: como Soul Mole, pero un remolino.

**Assets.**
- `swnd` (charlie, `Bloo.WAD!/Stra.FLDR/txtr.FLDR`): 64², textura continua de vetas diagonales azul grisáceas (viento). No está importada.
- [EXE] `SpiritWindRun` (0x423590, el nombre interno) llama a:
  - `sub_422e00`: `push 'swnd'` **dos veces**, con `ttx1` y `ttx2` (dos capas de textura), y `dirt` con `ttrl` (rastro de tierra).
  - `sub_4232b0`: `push 'Xltn'` (sonido de rayo).
  - **Confirma** `swnd` y el rayo. Diferencias con sacengine: el original tiene **dos capas** de `swnd` (sacengine una; `ttx1`/`ttx2`, las dos `swnd` porque el SPEL no las cambia, bandera alfa). **NO VERIFICADO** cómo combina las dos capas.
  - **Corregido (SPEL `swnd`, 2026-10-24):** `dirt` es solo el valor por defecto de `ttrl`; el SPEL pone **`ttrl = wdst`** (charlie, `Bloo.WAD!/Stra.FLDR/txtr.FLDR`, 256² con alfa: polvo gris muy tenue). El rastro es **`wdst`**, ni `dirt` ni `dust`.
  - SPEL completo: `tmod = skul`, `ttex = swnd`, `ttrl = wdst`, `tcst = cst0`, `fCHs = 0,25`. `skul` es una malla de Daniel.wad (`DanC.WAD!/char.FLDR/skul.MRMC`), pero **ninguna** de las lecturas de `tmod` del EXE está en el camino de Soul Wind (solo Frozen Ground, Fireball, Volcano, Bore, Decompose y Rock): probablemente no se usa. **NO VERIFICADO.**
  - Sonidos del SPEL: `Xfbl` (bandera 6) y `shld` en lazo (bandera 2; no hay sample `shld` en el índice del port). **El `fireball` de sacengine no es provisorio: está en el SPEL.** El lazo del viento queda **NO VERIFICADO** (`shld` no se resuelve a un archivo).

**El remolino** [SAC 10941-10958, 18873-19034; renderer.d:427-437, 2409-2429; sacobject.d:2711-2748]:
- **Malla.** Un embudo de 32 lados × 32 anillos, alto 3 m. El radio del anillo i va de 0 a 1,5 m (`1,5·(i/32 + 0,05·sin(2πi/32))`), con un ensanche arriba de +0,75·(i/32)⁴. El eje se curva: cada anillo se corre 0,5·radio en dirección (cos θ, sin θ) con θ = π·i/32. Es un tornado estrecho abajo, abierto arriba y torcido.
- **Textura.** `swnd` repetida 2 veces alrededor y 2 a lo alto, y la v se desplaza media repetición cada 32 ticks: el viento **sube** por el embudo.
- **Giro.** Una vuelta cada 4 s alrededor del eje vertical.
- **Material.** Sin sombreado, mezcla **alfa**, energía 5, transparencia **0,75**, sin escribir profundidad, sin descarte de caras.
- **Anclaje.** La base va en la posición del viento, a la altura del terreno. No escala: aparece y desaparece de golpe.
- **Recorrido.** El mismo que Soul Mole (ida 4,5 s con curva perpendicular, vuelta 4,5 s con el alma). Al llegar al alma suena `fireball`.
- **Polvo.** Sobre tierra, 2 `dust` por tick, ±0,3 m, escala 1, vida 31.
- **Golpe.** Una vez por blanco no aliado a ≤ `effectRange` (30 m): lo aturde, le hace 400 de daño y dibuja un **rayo** (`SoulWindEffect`: 2 rayos de 10 segmentos con la malla y el material del Lightning, 32 ticks, sin viaje, forma nueva cada 4 ticks) desde 1 m sobre la base del remolino hasta el centro del blanco, con sonido de rayo [SAC 18990-19034; renderer.d:1923-1930].
- **Lanzamiento del mago.** `chainLightningCasting` (cst0) en las manos.

**Sonido.** `fireball` (`Xfbl` = `sfx/pyro/fbal.wav`, `fba2..5.wav`, ganancia 2) al lanzar y al tomar el alma; `Xltn` (`sfx/stra/ltn1..6.wav`) en cada golpe. sacengine marca los dos `fireball` como provisorios (TODO). En `sfx/stra/` hay `gust.wav`, `torn.wav`, `sqls.wav` y `sqlh.wav`, que por nombre podrían ser el lazo del viento: **NO VERIFICADO** (el EXE no los empuja).

**Qué reutilizar del port.**
- El rayo: `BeamType` `data/fx/beams/lightning.tres` (ltn2) con `life_s` 32/60, `travel_s` 0, `change_s` 4/60. Es otro `.tres`, no código.
- Alma, aturdido y recorrido: lo mismo que Soul Mole (un portador común, `SpellCarrier` en el plan).
- `rock_dust.tres` o `dirt.tres` para el rastro.

**Qué falta.**
- Importar `swnd` como textura de malla (`EXTRA_FX`).
- La malla del embudo: es geometría fija, así que lo idiomático es **Blender CLI** (`soul_wind.glb`, 32×32, UV ×2) o un `ArrayMesh` guardado como recurso `.tres` hecho por una herramienta. El desplazamiento de la v y el giro van en un shader y en el `AnimationPlayer`/`Tween` de la escena.

---

## 061e — Saltos y dirigidos

### Chain Lightning (`ntlc`, Stratos)

**Qué dice el original.** No se encontró descripción en esta pasada. Rayo que salta entre enemigos (061R: 7 golpes).

**Assets.**
- sacengine usa para **todos** los rayos `ltn2` (main/bits, 4×4, blanco-celeste) [SAC sacobject.d:2281-2295].
- [EXE] Los rayos del original empujan **`ltng`**, no `ltn2`. `ChainLightningRun` (0x420220) llama a `sub_4355a0` (`push 'ltng'`, la usan 6 funciones: es la rutina común del rayo), y esta a `sub_435a60` (`push 'scar'` + `tscr`). `ChainLightningStart` (0x420320) empuja `cst0` y llama a `sub_436160` (`ltng`). `ltn2` solo lo empujan el Sacrificio (`SACDOCRunBeam`, `SACDOCUnitGlobeRun`) y `sub_416180`.
- `ltng` (charlie, `Bloo.WAD!/Stra.FLDR/txtr.FLDR`): 256², atlas 4×4 del mismo estilo que `ltn2` pero **azul más profundo y oscuro**. No está importado.
- `scar` (charlie, `Bloo.WAD!/Pyro.FLDR/scar.FLDR`, SCAR): lectura probable, una **quemadura en el suelo** donde pega el rayo. sacengine lo deja como TODO («scar», SAC 16377).
- Conclusión anterior: «lo más probable es `ltng`». **Matiz (SPEL `cltn`, 2026-10-24):** el SPEL trae **`ttex = ltn2`**, pero `sub_4355a0` pasa `'ltng'` **fijo** (sin clave) a `sub_4355e0`, y no se encontró ninguna lectura de `ttex` en el camino de Chain Lightning. Las dos fuentes se contradicen: **NO VERIFICADO**. Se decide con captura (`ltng` contra `ltn2`); el SPEL da un motivo para dejar `ltn2`, que es lo que usa el port.
- **SPEL `cltn`:** `ttex = ltn2`, `ffps = 30`, `tscr = scar` (confirmado: `sub_435a60` lee `tscr` con `scar` por defecto), `tcst = cst0`, `fCHs = 0,25`, `fSPa = 255`. Sonidos: `Xltn` (bandera 14) y `Xcnj` en lazo. Cada salto (`sub_4201c0`) llama a la rutina común de chispas; como el SPEL no trae `tSPK`, son **`sprk`** (valor por defecto): **confirma** las chispas de sacengine.

**Lanzamiento** [SAC 18198-18248]:
- Cada tick, 2 `lightningCasting` (cst0, aditivas, energía 3) relativas al cuerpo, en una caja de ±0,25 m en el punto de salida: 0,75 m delante del frente de la caja y 0,5 m sobre la cabeza.
- Con probabilidad 1/2 por tick, un **rayito vertical**: nace en un punto al azar de la caja ×1,5 y sube 1,5–3,25 m. Es medio rayo (escala 0,5), forma con ruido 0,5, 32 ticks, viaje 24, forma nueva cada 6. Con 1/4 de probabilidad suena un rayo.
- Además, `chainLightningCasting` (cst0, delay 2, se apaga y achica en la segunda mitad) en las manos.

**Cada salto** [SAC 18270-18294, 10474-10491, 16349-16386; renderer.d:264-274, 1868-1907]:
- Un salto cada **20 ticks**. Cada uno crea un `Lightning` completo del punto anterior al blanco: 2 rayos de 10 segmentos, aletas de 0,3 m, ruido de 2,5 m, forma nueva cada 6 ticks, 64 ticks de vida, la punta llega en 12 y la cola se va en los últimos 12.
- Material aditivo, energía con latido 0,375 + 14,625·(0,5 + 0,25 cos 7a + 0,25 sin 11a).
- Como cada rayo vive 64 ticks y se salta cada 20, se ven hasta **4 tramos a la vez**: la cadena queda dibujada un momento.
- Al llegar (tick 12): daño y `sparkAnimation`: 192 `spark` (sprk, aditivas, energía 15, 2 m) en la caja ×1,2, hacia afuera y 2–6 m/s hacia arriba, escala 0,5–1,5, vida 63, con gravedad.
- Sonido de rayo (`Xltn`, ganancia 4) por salto.
- Sin blanco, el salto cae en un punto del suelo (061R).

**Qué reutilizar del port.**
- `scenes/units/abilities/lightning_strike.gd` (`LightningStrike`, un rayo con daño a los 12 ticks) y `BeamType` `lightning.tres`: cada salto es un `LightningStrike` sin `retarget`. El salto es lógica de `ChainHop` (plan).
- `lightning_action.gd` para el origen del primer rayo (el mismo punto que en sacengine).
- `cst0.png` y `needle.tres` como base del `.tres` del lanzamiento.

**Qué falta.**
- Importar `sprk` (Stra/txtr, 4×4) como `ParticleType` `spark` (aditivo, gravedad). Hoy `LightningStrike` usa `styx_spark` de reserva.
- Importar `ltng` y decidir con una captura de cámara fija (`ltng` contra `ltn2`).
- La quemadura `scar` necesita el lector de `SCAR` (pendiente desde 061V b-c).

### Rainbow (`wobr`, Persephone)

**Qué dice el original.** No se encontró descripción en esta pasada. Arco de cura que salta de aliado en aliado (061R: 6 golpes, cada uno cura toda la vida).

**Assets.**
- `rnbw` (main, `MAIN.WAD!/bits.FLDR`): 64², degradé **vertical** de arcoíris, de rojo arriba a violeta abajo, opaco y sin alfa. No está importado.
- `prbw` (charlie, Pers/tex): 4×4 de destellos de colores. Ya está importado (`data/fx/rainbow.tres`).
- [EXE] `sub_42c990` (la llaman `RainbowRun` y `sub_42caf0`) empuja `glo2` y `rnbw` + `ttex`: **confirma** la textura del arco y las partículas `glo2`. `RainbowStart` (0x42d070) empuja `glo2` + `tcst` (partículas del lanzamiento): **confirma**. ~~`prbw` no aparece en ningún `push`: el estallido es de sacengine~~ **Corregido (SPEL `rbow`, 2026-10-24):** el SPEL pone **`tSPK = prbw`** y `fSPa = 255`, y `RainbowRun` → `sub_42cdb0` llama a la rutina común de chispas: **el estallido `prbw` al curar existe en el original.** SPEL completo: `ttex = rnbw`, `tsfx` (valor no textual), `flif = 0,5` (lo lee `RainbowRun`), `tcst = glo2`, `tSPK = prbw`. Sonidos: `rbow` en lazo y `Xcnj` en lazo. `RainbowRun` empuja además `flif` (probablemente una bandera de «vida»).

**Lanzamiento** [SAC 18047-18063]:
- `heal` (glo2) en las manos.
- Además, 6 `heal` por tick nacen en la huella del mago ×1,1, a una altura al azar, escala 2, y suben a velocidad constante 0,3–0,6 o 1,5–2,5 veces el alto de la caja en una vida (64 ticks).
- El arco sale 0,75 m delante del frente y 0,5 m sobre la cabeza del mago (igual que Chain Lightning).

**El arco** [SAC 18129-18195; renderer.d:389-398, 2287-2331; sacobject.d:2661-2672]:
- **Forma.** Un **semicírculo vertical** de un blanco al siguiente: el centro es el punto medio y el radio, la mitad de la distancia horizontal. La altura del medio del arco es la mitad de esa distancia; las alturas de los extremos se mezclan en línea recta.
- **Malla.** Cadena de 31 segmentos, aletas de **0,7 m**, textura repetida por segmento. La v va del eje (abajo de la imagen, violeta) al borde de la aleta (arriba, rojo): **cada aleta es una banda de arcoíris**. Cada hueso se inclina con el arco.
- **Material.** Sin sombreado, **aditivo**, energía 10, sin escribir profundidad, sin descarte de caras.
- **Tiempo.** La punta tarda **64 ticks** en llegar (1,07 s), el arco queda entero 32 ticks y la cola se recoge en 64 más: 160 ticks en total. Es el mismo patrón punta/cola del rayo (`travel` = 64, `life` = 160).
- Cada salto empieza cuando llega el anterior, así que los arcos se encadenan y se superponen.
- **Destellos en la punta.** Mientras crece, 3 `heal` por tick a ±0,7 m de la punta, escala 0,5–1,5, vida 63, quietas.
- **Al curar** [SAC 18112-18127]: 128 `rainbowParticle` (prbw, aditivas, energía 5, delay 2, con gravedad, rebotan en el suelo) en la caja ×0,9, con velocidad 1,5·U(0,5; 2)·(desvío horizontal al azar dentro de la caja, 2,5), escala 0,5–1,5, vida 63.
- **Sonido.** `wobr` = `sfx/pers/rbow.wav` (ganancia 2) en lazo, siguiendo la punta y después en el blanco.
- Sin blanco, el arco sigue en la misma dirección y cae a hasta `effectRange` (061R).

**Qué reutilizar del port.**
- `data/fx/rainbow.tres` (prbw, 128): ya es el estallido de la cura. Lo usa el Devour de criatura (`scenes/units/abilities/devour.gd`, que cura con `wobr`).
- `scenes/spells/heal_effect.gd`: la cura en el tiempo de Heal (061R: cura la vida máxima).
- `data/fx/heal.tres` para el lanzamiento y los destellos de la punta.
- `BeamFx`/`BeamType` con `atlas_tag` `rnbw` 1×1, `bolts` 1, `segments` 31, `width_m` 0,7, `jitter_m` 0, `life_s` 160/60, `travel_s` 64/60, energía fija 10 (`energy_min` = `energy_max`), ADD. Le falta el **camino en semicírculo** (el mismo «modo curva» que pide Animate Dead).

**Qué falta.** Importar `rnbw` (main/bits) con `fx_catalog`/`import_ui.py`.

### Dragonfire (`rifd`, Pyro)

**Qué dice el original.** No se encontró descripción en esta pasada. Un dragón de fuego guiado que encadena hasta 5 blancos (061R).

**Assets.**
- `dfir` (`models.wad`, `MODL.WAD!/dfir.MRMC`): MRMM de **97 vértices, 325 caras y 5 cuadros** de animación por vértices, con 2 texturas de 128² con alfa:
  - `M000` (cuerpo): llamaradas naranjas con un núcleo blanco-azulado.
  - `M001` (alas): llamas naranjas en abanico.
  - El dragón mira hacia +y (cabeza delante); las alas (`M001`) baten a lo largo de los 5 cuadros. Caja del cuadro 0: 3,1 × 3,8 × 5,4 m (x, y, z).
- [EXE 0x426430 `Dragonfire`]: `push 'dfir'` y dos `firy`. **Confirma** el modelo y las llamas. `PhoenixRebirthRun` (`sub_428730`) también empuja `dfir`: el renacer del Phoenix usa el mismo dragón (dato para RFC de criaturas).
- El `fbal` + `ttex` que el método viejo atribuía a Dragonfire está en `sub_426760`, que llama **`PyroExplosionRun`**: no es de Dragonfire.
- `dfir` no está importado. El importador de mallas del port (`tools/import/sac_formats/models.py`, `mrmm_obj`) solo lee el primer cuadro.

**El dragón** [SAC renderer.d:422-425, 2384-2408; sacobject.d:637, 2690-2709; dagonBackend.d:2584-2589]:
- **Animación.** sacengine intercambia los dos últimos cuadros y recorre la secuencia ida y vuelta (0,1,2,3,4,3,2,1) en **90 ticks** (1,5 s), mezclando dos cuadros por vez (morph lineal). Las alas baten sin parar.
- **Material.** Las dos partes, sin sombreado, mezcla **alfa**, transparencia **0,5**, energía **20**, sin escribir profundidad y sin descarte de caras. Muy brillante y semitransparente.
- **Orientación.** +y del modelo hacia la dirección de vuelo, con cabeceo.
- **Escala.** Mientras se lanza, crece de 0 a 1 con el progreso del lanzamiento. Al terminar, si no encuentra más blancos, se achica de 1 a 0 en 1 s.

**Lanzamiento** [SAC 18698-18752]:
- El dragón aparece junto al mago y **sube en espiral**: una vuelta completa durante el lanzamiento, hasta 4 m sobre la cabeza. El radio es 0,5·(tiempo de lanzamiento)·velocidad/(2π)·(0,5 + 0,5·progreso).
- 2 `firy` por tick nacen en un cubo alrededor del dragón y vuelan hacia donde estará un ciclo después. Su escala es 0,5·`damageRange`·(0,5 + 0,5·escala).
- El mago hace las partículas del lanzamiento de Pyro (`animatePyroCasting`).

**Vuelo** [SAC 18754-18871]:
- A `speed` (18 m/s), girando hasta π rad/s hacia el blanco, a ≥1 m del suelo.
- **Estela.** Cada tick, 8 partículas entre la posición anterior y la nueva, 0,7·escala detrás y ±0,3·escala al azar: 1 `fireball` (fbal) y 7 `firy`, escala 2·escala, vida 31, quietas.
- Prende fuego a lo que atraviesa.
- **Al llegar.** Daño en `damageRange` y prende al blanco (`setAblaze`). Suena `2ifd` = `sfx/pyro/dfi2.wav` (ganancia 4). No hay explosión dibujada en sacengine: el fuego lo pone el blanco que arde.
- **Siguiente blanco.** El no aliado más cercano a ≤ `effectRange`. Suena otra vez `dfi2.wav`. Si no hay, se va a un punto al azar y, al segundo fallo, se achica y desaparece.

**Sonido.** `sfx/pyro/dfi2.wav` al soltarlo, en cada blanco nuevo y en cada golpe. **SPEL `dfir` (2026-10-24):** el original usa **cuatro**: `dfi3` (bandera 1), `dfi2` (bandera 12), **`dfi4` en lazo** (bandera 2: el vuelo) y `dfi5` (bandera 2). Qué evento es cada bandera: **NO VERIFICADO**. SPEL completo: `tmdl = dfir`, `ttex = firy`, `tcst = firy`, `iCHg = 2`; **confirma** la malla y las llamas (`Dragonfire` empuja `dfir` fijo).

**Qué reutilizar del port.**
- `data/fx/fire.tres` / `fx/firy.png` para la estela y el lanzamiento (con la misma decisión pendiente de 061V b-c: aditivo energía 8, o `firy_a` MIX).
- El fuego en el blanco: el `ignite`/`burning` que ya usan Fireform y el Phoenix (`scenes/units/passives/fire_shield.gd`).
- `scenes/spells/spell_projectile.gd` para el vuelo guiado.

**Qué falta.**
- Importar `dfir` **con sus 5 cuadros**. Lo idiomático en Godot es un `.glb` con 4 *shape keys* (blend shapes) y una animación de pesos 0→4→1 en 1,5 s, más las dos texturas `M000`/`M001`. Herramienta: **Blender CLI** (leer los cuadros con un script que use `sac_formats`, crear las shape keys, exportar `dfir.glb`). No hay que modelar nada: el dragón es del original.
- Importar `fbal` (main/bits, 3×3) como `ParticleType` `fireball` (aditivo, energía 8, 0,5 m).

### Halo of Earth (`olah`, James)

**Qué dice el original.** No se encontró descripción en esta pasada. Rocas que orbitan al mago y se lanzan contra los enemigos (061R: 6 rocas, constante del EXE).

**Assets.**
- sacengine dibuja cada roca con la malla `rock` a escala `haloRockSize`/2 = **0,35** (≈0,7 m) [SAC renderer.d:2052-2062; state.d:19067].
- [EXE] `HaloRockRun` (0x445590) llama a `sub_445110`, que empuja **`roks`**. `roks` (`MODL.WAD!/roks.MRMC`) es otra malla del original: **31 vértices, 90 caras, 1 cuadro**, caja ≈0,77 × 0,61 × 0,61 m, con su textura `M000` (256², piedra gris parda con vetas). A escala 1 mide justo lo que sacengine imita con `rock`×0,35 (el comentario de sacengine en state.d:19067 dice que el 0,7 es provisorio). **Confirmado (2026-10-24):** `sub_445110` empuja `'roks'` **fijo** (sin clave del SPEL) al cargador de mallas `sub_469230` (el mismo que carga `dfir` y `sbll`). **La roca del Halo es `roks`.** SPEL `halo`: `tcst = dirt`, `iCHg = 1`, `iCH+ = 0`. Sonidos: `halo` (bandera 2), `Xrxp` (bandera 4) y **`hall` en lazo** (bandera 8, `sfx/jams/hall.wav`), que sacengine no usa (probable: el zumbido de la órbita, **NO VERIFICADO**).
- `HaloRockRun` también llama a `sub_445400` (`push 'dust'`, la estela) y a `sub_439270`. `sub_439270` la usan 6 funciones y empuja `rock`/`tRS1`, `dirt`/`tRS3` y `gscr`/`tRS4`: los restos de piedra, tierra y una **grieta `gscr`** (shawn, `jams.FLDR/scar.FLDR`, SCAR) al romperse la roca. sacengine no dibuja grieta (TODO en SAC 19186).
- [EXE 0x4458d0 `HaloOfEarthRun`]: `push 'dirt'` (la tierra al emerger). El `rock` que el método viejo le atribuía está en `sub_445b40`, que llama **`MeteorRun`**.

**Lanzamiento y aparición** [SAC 19102-19193]:
- Mientras se lanza, las rocas salen escalonadas: con `castingTime/8` de separación, la primera a la mitad de ese intervalo (el EXE: `(progreso + 0,1)·6`, 061R).
- Cada roca nace en un punto al azar de la caja del mago **×2,5**, enterrada 0,25 m.
- Al emerger:
  - Tiembla la pantalla (0,5 s, amplitud 0,5, alcance 25 m).
  - 20 `rock` a 1,05–2,1 m/s, con la vertical ×2,5, escala 0,25–0,75, vida 159.
  - 8 `dust` alrededor, escala 1,05, vida 31.
  - 24 `dirt` que suben a 2 m/s desde hasta 2 m bajo la roca, escala 2, vida 63.
- sacengine no agrega partículas propias del lanzamiento del mago.

**Órbita** [SAC 19212-19229, 19128-19139]:
- Centro: el centro de la caja del mago, **3 m sobre su cabeza**.
- Cada roca va por una curva de Hermite entre puntos al azar de un disco de radio 2 m, con tangentes de 3 m en dirección al azar, a 1,75 puntos por segundo. Gira sobre un eje al azar a 0,2–0,8 vueltas por segundo.
- Dura `duration` (35 s).

**Ataque e impacto** [SAC 19195-19210, 19230-19321, 19076-19100]:
- Al elegir blanco suena `olah` = `sfx/jams/halo.wav` (ganancia 2) en la roca.
- Mientras persigue: 2 `dust` por tick en su estela, escala 0,525, vida 31.
- Al romperse (en el blanco, en el suelo, al chocar o al vencer):
  - Suena `explodingRock` (`Xrxp` = `sfx/jams/rxp1..2.wav`, ganancia 2). La versión de criatura usa `bombardmentHit` (`Xmht`).
  - 50 `rock` a 2,6–5,25 m/s, escala 0,35–0,875, vida 95.
  - 10 `dirt` alrededor, escala 1,05.

**Qué reutilizar del port.**
- `scenes/units/abilities/halo_of_earth.gd` (`HaloOfEarth`, el del Rhinok): ya simula las 6 rocas, la órbita, la persecución, el choque y la vida. Para el mago cambian `spawn_box_scale` 2,5 (ya es knob), la salida escalonada durante el lanzamiento, el temblor de pantalla y el sonido `halo.wav`/`rxp*`. Su doc declara hoy «sin temblor, sin sonido, sin partículas propias».
- `data/shots/halo_rock.tres` (`ShotLook`: `rock` ×0,35, estela `rock_dust`, impacto `rock` + `dirt`): sirve tal cual, o se cambia `model` a `roks` con `model_scale` 1.
- `data/fx/rock_emerge.tres`, `rock.tres`, `dirt.tres`, `rock_dust.tres` y `shake_map.tres` para la aparición.

**Qué falta.**
- Importar `roks` (agregarlo a `SPELL_MODELS` en `tools/import/sac_formats/props.py`; sale como `props/roks.glb`) y decidir con una captura contra `rock`×0,35.
- La grieta `gscr` necesita el lector de `SCAR`.

---

## Resumen: qué importar y con qué herramienta

Las texturas las lee `tools/import/import_ui.py` con `fx_catalog.py` (atlas en `ATLASES`, texturas de malla en `EXTRA_FX`), y la salida va a `assets/original/fx/`. Las mallas estáticas, `tools/import/import_props.py` (`SPELL_MODELS`). Hace falta el original instalado (`SAC_INSTALL`, ver `tools/import/local.cfg.example`). Se verificó que todo existe en la instalación.

| Tag | WAD / carpeta | Tamaño / grilla | Uso | Hechizo |
|---|---|---|---|---|
| `and2` | Daniel.wad · `DanC.WAD!/char.FLDR` | 256², 1×8 | estelas | Animate Dead |
| `cfx1` | ídem | 256², 4×4 | lanzamiento y estallido de Charnel nivel 2 | Animate Dead (y Slime, 061c) |
| `swnd` | charlie.wad · `Bloo.WAD!/Stra.FLDR/txtr.FLDR` | 64² | textura del embudo (2 capas según el EXE) | Soul Wind |
| `sprk` | ídem | 256², 4×4 | chispas al pegar el rayo | Chain Lightning (y Lightning, Storm Giant) |
| `ltng` | ídem | 256², 4×4 | rayo fijo de la rutina común del EXE; el SPEL de Chain Lightning dice `ltn2` (NO VERIFICADO) | Chain Lightning, Soul Wind, Lightning |
| `rnbw` | main.wad · `MAIN.WAD!/bits.FLDR` | 64² | bandas del arco | Rainbow |
| `fbal` | ídem | 256², 3×3 | partícula `fireball` de la estela | Dragonfire (y Fireball, Explosion) |
| `dfir` | models.wad · `MODL.WAD!/dfir.MRMC` (MRMM + `M000`, `M001`) | 97 vért., 5 cuadros | el dragón (shape keys) | Dragonfire (y el renacer del Phoenix) |
| `roks` | models.wad · `MODL.WAD!/roks.MRMC` (MRMM + `M000`) | 31 vért. | roca del Halo (EXE, confirmado) | Halo of Earth |
| `wdst` | charlie.wad · `Bloo.WAD!/Stra.FLDR/txtr.FLDR` | 256², alfa | rastro del remolino (SPEL `ttrl`) | Soul Wind |
| `scar` | charlie.wad · `Bloo.WAD!/Pyro.FLDR/scar.FLDR` (SCAR) | — | quemadura del rayo (EXE, NO VERIFICADO); sin lector | Chain Lightning |
| `gscr` | shawn.wad · `shwn.WAD!/jams.FLDR/scar.FLDR` (SCAR) | — | grieta al romperse la roca (EXE, NO VERIFICADO); sin lector | Halo of Earth |

Ya están en el port: `ltn2`, `cst0`, `glo2`, `prbw`, `dust`, `dirt`, `rock`, `firy`/`firy_a`, la malla `rock` (`props/rock.glb`) y todos los sonidos nombrados (`assets/original/audio/sfx/…`; las etiquetas de sacengine se leen al revés: `ltss` → `char/sstl.wav`, `0cas`/`9cas` → `sacr/sac0.wav`/`sac9.wav`, `2ifd` → `pyro/dfi2.wav`, `wobr` → `pers/rbow.wav`, `olah` → `jams/halo.wav`; los tipos `Xquk`, `Xltn`, `Xfbl`, `Xrxp` están en el set `spel` de `audio/index.json`).

Mallas:
- **Blender CLI:** el dragón `dfir` (5 cuadros del original → shape keys, sin modelar) y el embudo de Soul Wind (32×32, forma de SAC sacobject.d:2711-2748). Un topo de Soul Mole **solo** si el usuario lo pide: el original no trae modelo.
- **Importador existente:** `roks` (`SPELL_MODELS`).
- **Primitivas o BeamFx en la escena:** rayos (Chain Lightning, Soul Wind), arco (Rainbow) y estelas (Animate Dead) con `BeamType`. Rainbow y Animate Dead necesitan un modo de camino curvo en `BeamFx` (semicírculo y Hermite).
- **Aseprite:** no hace falta.

## Pendientes antes de dibujar (NO VERIFICADO)

1. ~~Soul Mole~~ **Resuelto:** es `DecomposeStart` (SPEL `dcmp`); el topo es la malla `rock` visible. `BurrowRun` es otro hechizo.
2. **Rayo.** ¿`ltng` (fijo en la rutina común `sub_4355a0`) o `ltn2` (SPEL de Chain Lightning, sacengine y port)? Afecta a Chain Lightning, Soul Wind, Lightning y Storm Giant. ¿Qué es la `scar` de `sub_435a60`?
3. ~~Halo of Earth~~ **Resuelto:** `roks` a escala 1 (empuje fijo al cargador de mallas).
4. **Animate Dead.** `cfx1` **confirmado** (SPEL `tcst`/`tSPK`). Abierto: qué dibuja el `glo2` fijo con bandera de oscurecer, y si revive al empezar o al terminar el lanzamiento.
5. **Soul Wind.** ¿Cómo combina las dos capas `swnd`? El rastro es `wdst` (SPEL). `Xfbl` está en el SPEL (no es provisorio). Abierto: el lazo `shld` (sin archivo) y si `tmod = skul` se usa.
6. ~~Rainbow: ¿existe el estallido `prbw`?~~ **Resuelto:** sí (SPEL `tSPK = prbw`).
7. **Fuego** (Dragonfire): ¿`firy` aditivo con energía 8 o el `firy_a` MIX del port? Es la misma decisión de 061V b-c. Se decide con capturas de cámara fija y un criterio numérico.
8. Ninguna apariencia se confirmó con un video.
