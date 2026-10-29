# 061V — Cómo se ven en el original los hechizos de 061h (las nubes)

Este informe junta los hechos para el arte final de 061h: Rain of Frogs, Rain of Fire, Plague, Cloudkill y Bombardment (con daño y sin abolladuras). No trae diseño ni código. El plan del corte está en `docs/archive/rfcs/plans/061h-clouds-plan.md` y los números de juego en `docs/archive/rfcs/research/061R-abilities-structures.md`. El usuario pidió **arte final desde el inicio**. El formato y el método son los de `061V-spell-visuals-f-g.md` (la tabla de recursos del registro SPEL manda sobre las etiquetas por defecto del exe).

## Fuentes y etiquetas

- **[SAC archivo:línea]** sacengine (`sacengine/source/`, GPL, solo lectura). Se describe lo que hace; no se copió código. Si no se nombra el archivo, es `state.d`. Los números de dibujo (energía, transparencia, cantidad de partículas) los decidió su autor.
- **[SPEL]** registro de cada hechizo en `spells.wad` (314 bytes): tabla de sonidos (desde el byte 112) y tabla de recursos (pares clave/valor desde el byte 136; clave y valor van al revés en el archivo, la clave con prefijo `t` etiqueta, `f` float, `i` int). El nombre del registro es el tag del port leído al revés: `grfr` es el registro `rfrg`, `rifr` es `rfir`, `galp` es `plag`, `likc` es `ckil`, `rtem` es `metr`.
- **[TXTR]** texturas y mallas leídas de las WAD con el lector del port (`tools/import/sac_formats/`). Se miraron tamaño, grilla, color medio, alfa y se vieron como imagen.
- **[EXE 0xDIR]** `Sacrifice.exe` (GOG). Se desensamblaron con `objdump` las funciones `RainFrogRun` 0x42d650, `RainOfFireRun` 0x429210, `PlagueBombRun` 0x432c10, `PlagueRun` 0x432eb0, `MeteorShowerRun` 0x445fd0 y `CloudKillBoltRun` 0x420600 (límites de función de la tabla 0x4cbba8) y se leyeron los `push imm32` que son etiquetas. Son **valores por defecto** de una clave del SPEL: si el SPEL trae la clave, manda el SPEL.
- **[REA]** lo ya verificado en 061R §Cloudkill (`CloudKillRun` 0x420a30, `CloudKillBoltRun` 0x420600). Este informe no repite ese trabajo.
- Precedencia: SPEL/EXE/REA > sacengine > manual > web. Lo que no se pudo confirmar dice **NO VERIFICADO**. No se vieron videos: ninguna afirmación sale de una captura del original.

Unidades: 60 ticks por segundo. sacengine anima los sprites a 30 cuadros por segundo (`updateAnimFactor = 2`).

## Lo que comparten las tres nubes de lluvia (Rain of Frogs, Rain of Fire, Plague)

**La nube** [SAC sacobject.d:2778-2794; renderer.d:451-463, 2459-2499]:
- Es una esfera ruidosa **negra y translúcida**, sin textura: una imagen de 8×8 negra con alfa 0,15. La malla (24×25) tiene 20 copias deformadas (el fondo morfa entre ellas en 8 s por copia) y se dibujan las 20 apiladas, con mezcla de transparencia, sin escribir profundidad y con culling de caras traseras. Con 20 capas de 0,15 el centro queda casi opaco.
- Escala (1,3; 1,3; 0,4) × radio × (0,5 + 0,5 × `cloudScale`), con alfa = `cloudScale`. El radio es `effectRange` (50 m) en Frogs y Plague y la **mitad** (25 m) en Rain of Fire.
- Nace con el inicio del lanzamiento (`...Casting` guarda la nube) y `cloudScale` sube a 0,5 por segundo (2 s para llegar a 1) [state.d:3475-3477, 19362]. Al terminar la duración (o si se corta el lanzamiento) baja a 1 por segundo y se borra al llegar a 0 [state.d:19391-19392, 3477].
- Flota a **90 m** sobre el suelo del clic (`cloudHeight`, state.d:11026, 11036, 11046).
- Las gotas no esperan a que la nube termine de crecer: empiezan cuando el lanzamiento termina bien (`finished`, state.d:19354-19356) y siguen `duration × 60` ticks.

**La tasa** [SAC 19374; 20948; 21107]: cada tick suelta `rate / 60` gotas enteras más una con probabilidad `(rate % 60) / 60`. Frogs 10/s, Plague 3/s, Rain of Fire 3/s, Bombardment 2/s.

**El desvío hacia criaturas** [SAC 19379-19386; 20953-20960; 21113-21120; 21311-21318]: cada gota nace en un punto al azar de un disco de radio `effectRange` alrededor del eje de la nube. Se busca la criatura viva más cercana a ese punto (de cualquier bando, dentro de `effectRange` del suelo bajo la nube). Si queda a menos de `shortJumpRange` = **10 m** (en horizontal) la gota se corre a la criatura; si queda a menos de `jumpRange` = **25 m**, se corre con probabilidad 2/3. Sacengine marca esas dos distancias con `TODO: correct?`: **NO VERIFICADO** contra el exe.

**Sonidos de nube del SPEL** (etiquetas de `sfx/…`; `!` = sacengine las toca en lazo): `clod` (`sfx/pers/clod.wav`), `cldf` y `cldl` (`sfx/comn/cldf.wav`, `cldl.wav`). Los trae el SPEL de Rain of Fire (`clod`, `cldf`, `cldl!`) y el de Cloudkill (`cldf`, `cldl!`). Qué evento los toca y qué significa cada bit de bandera: **NO VERIFICADO**. sacengine no toca ninguno [búsqueda en state.d: 0 resultados].

## Rain of Frogs (`grfr`, registro `rfrg`, Persephone)

**SPEL.** `tSPK = brst`, `ttex = fhop`, `fSPa = 255`, `iSP# = 32`. Sonidos: `Xfrg` (bandera 0x0c) y `Xfrx` (0x10), del set `spel`: `sfx/pers/frg1..2.wav` y `frx1..2.wav`. No trae `tcst`: la partícula de lanzar es el valor por defecto del exe `frgl` [EXE 0x42d710 `RainFrogRun`: `push 'frgl'` con la clave `tcst`], igual que sacengine.

**Assets** [TXTR]:
- `fhop` (charlie, `Bloo.WAD!/Pers.FLDR/tex.FLDR`): 256², atlas 4×4 de 16 cuadros del salto de una rana verde con alfa (31 % opaco). Es el sprite de la rana, **mezcla de transparencia**, sprite 0,75 m, energía 3, 1 cuadro cada 2 ticks [SAC sacobject.d:2821-2835; renderer.d:530-540]. **Falta importarlo.**
- `frgl` (main, `bits.FLDR`): 256², atlas 4×4 de destellos verdes con borde oscuro (66 % opaco). Partícula `rainOfFrogsCasting`: 1 m, energía 7,5, aditiva, sin gravedad, alfa `min(1, vida/(1,5 cuadros))`, escala `min(1, 0,4 + 0,6·vida/(1,5 cuadros))` [SAC sacobject.d:1618-1623, 1850-1851, 1913-1914]. **Falta importarlo.**
- `brst` (charlie, `Pers.FLDR/tex.FLDR`): 256², atlas 4×4 casi negro con chispas azules y verdes. Partícula `frogExplosion`: 1 m, energía 5, aditiva, con gravedad, retardo 1 [SAC 1624-1629, 1299-1323, 1911-1912]. **Falta importarlo.**

**El lanzamiento** [SAC animateRainOfFrogsCasting, state.d:19324-19338]: 6 partículas `frgl` por tick, a 1,1 × la caja del mago, que suben hasta 0,3 a 0,6 (o 1,5 a 2,5, una de cada tres) alturas del mago, con vida al azar en [0, 2] ciclos.

**Cada rana** [SAC 19428-19504; struct 3489-3507]:
- Cae con velocidad inicial −45 m/s (90 m en 2 s) y gravedad 30 m/s² (`fallingAcceleration` por defecto de sacengine; **no es dato del SPEL**, sacespell.d:120-127). Cuadro de caída: el 11 del atlas.
- Al tocar el suelo se sienta 0,5 s (`sitTime = 30` ticks) y salta. Cada salto va hacia la criatura viva más cercana a ≤ 50 m con velocidad 4,5 m/s más una desviación de 0,5 m/s al azar y la componente vertical que da el arco (tope 10 m/s). Sin criatura salta a 5 m/s en dirección al azar y 10 m/s hacia arriba. Un salto de cada cinco suena `frog` (`Xfrg`, ganancia 1) [SAC 19467].
- El cuerpo de la rana mide 0,5 m. Si toca el cuerpo de una criatura que se puede infectar (`canBeInfectedByMites`, el mismo filtro de Sticky bomb), **se pega** y queda en ese cuerpo, en su posición relativa, con el cuadro 15 [SAC 19488-19499].
- Pegada: **frena ×0,6 por rana** [stats.d:122; 061R] y a los 5 s (`infectTime = 300`) explota. Si no se pega, explota después del salto 7 en el cuadro 10 de la animación (o en el 8.º salto) [SAC 19449].
- Al explotar: 90 de daño de hechizo al cuerpo al que está pegada (directo, con la bandera de salpicadura) y salpicadura de 5 m sobre el punto (`amount × (1 − d/r)`, el mismo reparto del resto del port), más 200 partículas `frogExplosion` a 2,5-7,5 m/s con una subida media de 0,5, escala 0,75-1,5, vida 31 [SAC 19405-19427]. No hay sonido de explosión en sacengine; el SPEL trae **`Xfrx`**, que por el nombre (`Xfbx` fireball, `Xrxp` rock, `Xfrx` frog) es la explosión: **NO VERIFICADO**.

**Reutilizar del port.** `Clinging` (la rana pegada es una pieza más, como la Sticky bomb), `SplashDamage`, `SpellAction` con `cast_fx`, `ParticleType` (`frog_cast`, `frog_burst` nuevos), `MatchSeed`.

## Plague (`galp`, registro `plag`, Charnel)

**SPEL.** `iacc = 500`, `fspd = 0,7`, `freg = 0,0`, `tcst = cfx1`. Sonidos: `dish` (bandera 8) y `bldx` (bandera 4), muestras sueltas `sfx/char/dish.wav` y `bldx.wav`. `iacc`, `freg` y `fspd` tienen los mismos nombres que los argumentos de `poison()` en sacengine [SAC 11601-11614: `ires`, `freg`, `iacc`]; **sacengine los ignora** en Plague y pasa `0, 1,0, 0` [SAC 20988]. El SPEL manda: la gota deja `freg = 0` (el envenenado **no regenera**). `iacc = 500` (precisión) y `fspd = 0,7` (¿velocidad?): el port no los modela y el significado de `fspd` es **NO VERIFICADO**.

**Assets.**
- `cfx1` (Daniel/DanC, `char.FLDR`): anillos violetas, partícula `castCharnel2` (1 m, energía 5, aditiva). **Ya está en el port** (`fx/cfx1.png`). Es la partícula de lanzar del SPEL (`tcst`), pero sacengine dibuja otra cosa (ver abajo).
- `pois` (main, `bits.FLDR`): 256², atlas 4×4 de bocanadas verde oliva con alfa. **Ya está** (`fx/pois.png`, `data/fx/poison.tres`). El exe crea **la bomba de Plague** (`PlagueBombRun`) como un sprite de textura `pois` con bandera de alfa 0x0a011008 [EXE 0x432cf1-0x432cfc]. Tamaño y demás argumentos: **NO VERIFICADO**.
- `blud` (main): sangre. Ya está. sacengine dibuja la gota como **2 partículas `blood` por tick** (0,75 m, escala 0,5 × (1,5 − d) × 1,5 m, con la velocidad de la gota) [SAC 21016-21029].

**El lanzamiento.** sacengine: 4 partículas `poison` por tick con el mismo movimiento que Frogs [SAC 20897-20912]. El SPEL pide `cfx1` (`tcst`); sacengine tiene el comentario «TODO: standard castCharnel2 animation on top of this?». Se hacen las dos cosas: `cfx1` como el resto de Charnel y `poison`.

**Cada gota** [SAC 20971-21053]: cae como la rana (−45 m/s, gravedad 30), caja de 1,5 m. Explota contra el suelo o la primera criatura que se pueda infectar que toque.
- Sonido `bldx` (ganancia 1) y, si hay blanco, `dish` sobre él.
- Al blanco: veneno de `0,1 × amount` por segundo (62,5/s) durante 10 s, **contagioso**, con tipo hechizo+salpicadura. A cada otra criatura a ≤ 5 m de caja: `0,1 × amount × 0,1 × (1 − d/r)` por segundo, 10 s, también contagioso [SAC 20988, 20997].
- 50 partículas `poison` en la caja del blanco ampliada ×2, a 0,25-0,75 × tamaño de caja, vida 95-127 [SAC 21003-21013].

**Reutilizar.** `Poisoning.dose_body` (con `infectious`, `regen_factor`), `data/fx/poison.tres`, `blood.tres`, `SplashDamage.bodies_within`.

## Rain of Fire (`rifr`, registro `rfir`, Pyro)

**SPEL.** `tcst = firy`, `iCHg = 2`. Sonidos: `clod`, `Xfir!` (lazo; `sfx/comn/flp1..5.wav`), `cldf`, `Xmhb` (`sfx/pyro/mhb1..3.wav`, `rfst.wav`) y `cldl!`.

**Assets.**
- `bbrd` (charlie, `Pyro.FLDR/txtr.FLDR`): 256², atlas 4×4 de una bola de fuego naranja opaca sobre negro (todo opaco, color medio 48-28-13). Es el sprite de **la gota**: 2,75 m × 2,5 = **6,9 m**, aditivo, energía 20, 16 cuadros a 1 cuadro por 2 × 2 ticks [SAC sacobject.d:4316-4328; renderer.d:981-991, 3329-3335]. **Falta importarlo.**
- `firy` (cola y lanzar, ya está), `fbal` (3×3, ya está, `fireball`), `xplo`, `exp2`, `frck`, `smok` (ya importadas por 061f).
- El exe, además, crea partículas `frck` (ceniza) alrededor de la nube [EXE 0x429464 `RainOfFireRun`]; sacengine lo deja como `TODO: ash particles in the air` [SAC 21103]. Cantidad: **NO VERIFICADO**.
- `sptr` (charlie, Pyro): textura de 256². El exe la empuja como valor por defecto de `tspl` en `RainOfFireRun`: para qué (¿salpicadura?): **NO VERIFICADO**. No se usa.

**El lanzamiento.** `firy` con `animateCasting` más 6 partículas por tick que suben a 1,5 a 2,5 alturas del mago (mismo patrón de Frogs) [SAC 21055-21070].

**Cada gota** [SAC 21099-21196]:
- Nace a una altura de la nube (90 m) en un punto al azar de un disco de **0,5 × `effectRange`** (25 m) alrededor del eje de la nube, y vuela en línea recta, **sin gravedad**, hasta un punto al azar del disco de `effectRange` (50 m) a la altura del suelo (con el desvío hacia criaturas), en **1,4 s**. Velocidad = (destino − origen) / 1,4.
- Cola: cada tick, 8 partículas entre la posición anterior y la nueva (7 `firy` y 1 `fireball`), escala 4, vida 31, desviadas 0,6 m [SAC 21155-21171].
- Caja de 1,5 m. Explota contra el suelo o la primera criatura que se pueda infectar que toque.
- Explosión [SAC 21142-21154]: sonido `explodingFireball` (`Xfbx`, ganancia 3). Al blanco, 500 de daño de hechizo con salpicadura e ignición y fuego de 1 s (60 ticks, sin daño propio). A los otros a ≤ 5 m: salpicadura `amount × (1 − d/r)` con ignición y el mismo fuego de 1 s. Luego `animateFireballExplosion` (escala 1): 200 `explosion` (`xplo`) y 800 `explosion2` (`exp2`) a 1,5-6 m/s (×1,5 las de `exp2`), 300 `ashParticle` (`frck`) a 7,5-15 m/s, 75 `smoke` (`smok`); vida 31, 31, 95 y 127 [SAC 16631-16665].

**Reutilizar.** `data/fx/explosion_blast*.tres`, `explosion_ash.tres`, `explosion_smoke.tres` (los de Explosion, 061f; cantidades más chicas), `Burning.ignite`, `SplashDamage`, `wards/fire_cast`.

## Bombardment (`rtem`, registro `metr`, James)

**SPEL.** `ttrl = dirt`, `tRE3 = gscr`, `tRS4 = ecrk`, `tcst = dirt`, `tRT1 = dirt`, `iCHg = 1`, `iCH+ = 0`. Sonidos: `Xmht` (`sfx/jams/mht1..3.wav`), `spt3` (muestra `sfx/jams/spt3.wav`) y `Xquk!` (lazo; `sfx/jams/eqk1..3.wav`).

**Assets.**
- `rock` (`MODL.WAD!/rock.MRMC`): 503 vértices y 960 caras, caja ≈ 2 m. **Ya está** (`BodyCatalog.mesh("rock")`, el de Rock). sacengine dibuja cada meteorito con esta malla a **escala 1,875** (≈ 3,8 m) girando [SAC renderer.d:2080-2083].
- `rokm` (`MODL.WAD!/rokm.MRMC`): 62 vértices y 100 caras, caja ≈ 1,1 m. Es el valor por defecto de `tmod` en `MeteorShowerRun` [EXE 0x4462af-0x4462b4]; el SPEL no trae `tmod`. Es probable que sea la malla que el exe dibuja y que escale más; sacengine usa `rock`. **NO VERIFICADO** cuál es y a qué escala. Se usa `rock` ×1,875 (el tamaño coincide con la caja de choque de 3 m); el `.tscn` guarda la malla como `@export`, así que cambiar a `rokm` es un campo.
- `dirt`, `rock` (sprites, ya están), `dust` (ya está).
- `gscr` y `ecrk` (`shawn.wad`, `jams.FLDR/scar.FLDR`, 4240 y 5648 bytes): son formato **SCAR**, las marcas quemadas en el suelo. **No hay lector de SCAR** y el corte no toca el terreno: no se dibujan (declarado). sacengine tampoco: `TODO: scar` [SAC 21297, 21376].

**El lanzamiento.** `dirt` con `animateCasting!(false, 1)` más 6 partículas `bombardmentCasting` (la textura `rock`, 1,5 m, no aditivas, gravedad no) que suben como las de Frogs [SAC 21198-21214]. El lanzamiento no tiene nube: la posición del hechizo está a 90 m pero **nada se dibuja arriba** [SAC 4055-4067, sin `cloudScale`].

**Cada meteorito** [SAC 21235-21298, 21300-21421]:
- Nace **bajo la tierra** (1 m) en un punto al azar del disco de **0,25 × `effectRange`** (12,5 m) alrededor del **mago** [SAC 21236-21241], y se lanza en un arco de **12 s** (`fallDuration`) hasta un punto al azar del disco de 50 m alrededor del clic (con el desvío hacia criaturas) a la altura del suelo. Con gravedad **20** (sacengine, no dato del SPEL): velocidad = (destino − origen) / 12 más 0,5 × 20 × 12 hacia arriba, es decir, el arco que aterriza justo a los 12 s.
- Al salir de la tierra [SAC 21259-21298]: sonido `spt3` (ganancia 3), temblor de pantalla (30 ticks, 0,25, 40 m), 20 partículas `rock`, 8 `dust` (3 × tamaño/2) y 24 `dirt` (escala 2,5).
- En vuelo: 4 partículas `dirt` por tick entre la posición anterior y la nueva, escala 2,5, vida 31 [SAC 21380-21394]. Gira a 0,05-0,2 vueltas por segundo en un eje al azar [SAC 21322-21323]; la malla gira `2π × U(0,2; 0,8)` rad/s [SAC 21251].
- Solo choca mientras **baja** (`velocity.z < 0`), con una caja de 3 m, contra el suelo o contra una criatura que se pueda infectar [SAC 21395-21421].
- Impacto [SAC 21343-21379]: sonido `bombardmentHit` (`Xmht`, ganancia 3); 400 de daño de hechizo directo al blanco; a todos los de ≤ 5 m, salpicadura y **aturdimiento** con el enfriamiento de 8 s (`stunCooldownFrames = 480`, state.d:8561); 100 partículas `rock` a 15-30 m/s en cualquier dirección (escala 1,5-2,25, vida 95); 20 `dirt` quietas (escala 5,6, vida 63-0); **temblor de pantalla** (60 ticks, 0,75, 250 m); y la **abolladura** del terreno (15 m × 1,2 m) si el blanco estaba en tierra: **no entra en este corte** (061k).
- Interpretación de los números del temblor (`screenShake(position, frames, amplitud, distancia)`): **NO VERIFICADO**; en el port ya existe `data/fx/shake_map.tres` por nombre de efecto.

**Reutilizar.** `dirt_cast.tres` (el lanzamiento con `dirt`), `rock_emerge.tres`, `rock_dust.tres`, `rock.tres`, `dirt.tres`, `Stunned.stun_with_cooldown`, `SplashDamage`, `BodyCatalog.mesh("rock")`, `data/fx/shake_map.tres`.

## Cloudkill (`likc`, registro `ckil`, Stratos)

**SPEL.** `ttex = ltn2`, `ffps = 30`, `fSPa = 255`, `tscr = scar`, `ilif = 1800`, `tcld = clou`, `tcst = cst0`, `fCHs = 0,25`. Sonidos: `Xltn` (0x0c; `sfx/stra/ltn1..6.wav`), `cldf`, `cldl!`.

**Assets** [TXTR].
- `clou` (charlie, `Stra.FLDR/txtr.FLDR`): 256², atlas 4×4 negro azulado con venas eléctricas azules (100 % opaco, color medio 1-3-7). Es la piel de la nube: esfera ruidosa de radio 5 m, 20 capas morfeando (como las otras) pero con textura, **mezcla de transparencia con energía 20 y transparencia 0,15**, alfa `0,15 × cloudScale`, escala (1,3; 1,3; 0,5) × 5 m × (0,5 + 0,5 × `cloudScale`) × (1 − 0,3/20 × capa), cuadro de atlas nuevo cada 8 ticks [SAC sacobject.d:2796-2819; renderer.d:464-475, 1830-1858]. **Falta importarlo.**
- `ltn2` (main, `bits.FLDR`): la textura del rayo (SPEL `ttex`). **Ya está** y es la que usa el `BeamType` `lightning` de Call Lightning: el rayo de Cloudkill se ve igual.
- `cst0`: partícula de lanzar. Ya está.
- `scar`: la cicatriz del rayo en el suelo (SPEL `tscr`). Sin lector de SCAR: no se dibuja.

**La nube** [SAC 4228-4248, 22074-22108; REA 061R]:
- Nace a 22 m sobre el centro del blanco (REA; sacengine usa 25) y crece en 4,3 s (`cloudGrowSpeed = 1/4,3`).
- Apunta a la posición del blanco + 22 m en cada tick (el blanco puede ser una criatura o el suelo) y se mueve hacia ahí a `speed` = 3 m/s (REA: `speed` 3 y `acceleration` 0,3; cómo entra la aceleración: **NO VERIFICADO**).
- Dura `duration` = 30 s (SPEL `ilif = 1800` ticks coincide: 0x420871 multiplica `duration × 60`).
- **Rayos**: ≈ 2/s (REA: probabilidad `(dt + 1)/60` por actualización; sacengine pone 5/3). El rayo cae a un punto al azar del disco de `0,95 × effectRange` alrededor del suelo bajo la nube. Si hay un cuerpo cualquiera (también aliados y edificios; sacengine `anyInRangeAndClosestTo`) a ≤ **15 m** del punto, el rayo va al cuerpo; entre 15 y **50 m**, con probabilidad 1/2 [SAC 22087-22101]. Daño `amount` = 900 y salpicadura de 5 m [REA 061R].
- Sonido del rayo: `lightning` (`Xltn`, ganancia 4) en el punto medio [SAC 10487].

**El lanzamiento** [SAC 22036-22073]: cada tick, con probabilidad 1/2, un rayo corto (`chainLightningCastingEffect`) cerca del mago de 1,5 a 3,25 m de alto; una vez cada 30 ticks suena `Xltn` (ganancia 4) en la nube; más `animateChainLightningCasting`. La nube crece mientras tanto.

**Reutilizar.** `LightningStrike` (`scenes/units/abilities/lightning_strike.gd`, el rayo de Call Lightning, con el `BeamType` `lightning`), `SplashDamage`, `noisy_sphere.gdshaderinc`, `lightning_flash` (luz del rayo, ya existe en el port).

## Qué falta importar y qué se reutiliza

| Recurso | Para qué | Estado |
|---|---|---|
| `fhop` (Pers) 4×4 | rana | **falta** (`EXTRA_FX`) |
| `frgl` (bits) 4×4 | lanzar Frogs | **falta** |
| `brst` (Pers) 4×4 | explosión de rana | **falta** |
| `bbrd` (Pyro) 4×4 | gota de Rain of Fire | **falta** |
| `clou` (Stra) 4×4 | nube de Cloudkill | **falta** |
| `pois`, `blud`, `cfx1`, `cst0`, `firy`, `fbal`, `xplo`, `exp2`, `frck`, `smok`, `rock`, `dirt`, `dust`, `ltn2` | partículas y rayo | ya están |
| malla `rock` | meteorito | ya está |
| malla `rokm`, `scar` (`gscr`, `ecrk`, `scar`), `sptr` | alternativas / marcas | no se importan (declarado) |
| sonidos `frg1..2`, `frx1..2`, `bldx`, `dish`, `fbx1..3`, `mht1..3`, `spt3`, `eqk1..3`, `ltn1..6`, `cldf`, `cldl`, `clod`, `mhb1..3` | eventos | **ya importados** (`assets/original/audio`); faltan sus **cues** en `data/audio/fx_sounds.tres` |

## Cómo se leyó (reproducible, sin rutas personales)

- **SPEL:** de `spells.wad` (`wad.walk`) se toman los registros `SPEL` por nombre (el tag del port al revés); los bytes 112-140 son la tabla de sonidos `[bandera][' ' o '!'][etiqueta al revés]` y desde el byte 136 los pares de 8 bytes (clave al revés con `t`/`f`/`i`, valor al revés o `float32`/`int32`). `SAC_INSTALL` exportado solo en el shell.
- **Texturas y mallas:** `sac_formats.txtr.flat_texture` y `sac_formats.models.mrmm_obj` sobre `charlie.wad`, `main.wad`, `models.wad`, `shawn.wad`. Cada textura nueva se vio como imagen sobre un damero.
- **EXE:** `objdump -d -M intel` sobre `Sacrifice.exe`; los límites de función salen de la tabla 0x4cbba8 (36 bytes por entrada: nombre[28], función, hash); cada `push imm32` de 4 caracteres ASCII se lee como etiqueta.
- No se abrió Ghidra ni Godot.
