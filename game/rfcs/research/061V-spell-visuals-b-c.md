# 061V — Cómo se ven en el original los hechizos de 061b y 061c

Investigación de hechos para el arte final de 061b (escudos de nivel 2) y 061c (control sobre un blanco). No tiene diseño ni código. El plan es `rfcs/plans/061-spells-master-plan.md`, y el usuario pidió **arte final desde el inicio**.

## Fuentes y etiquetas

- **[SAC archivo:línea]** sacengine (`sacengine/source/`, GPL, solo lectura). Se describe lo que hace; no se copió código. Si no se nombra el archivo, es `state.d`. sacengine es una reimplementación: las texturas y las mallas las carga de las WAD originales, pero los números de dibujo (energía, transparencia, cantidad de partículas) son decisiones de su autor. Donde el ejecutable dice otra cosa, se avisa.
- **[TXTR]** texturas leídas de las WAD de la instalación (`SAC_INSTALL`) con el lector del port (`tools/import/sac_formats/txtr.py`). Se miraron el tamaño, la grilla y el color. Las carpetas reales de la WAD dicen `tex.FLDR` donde sacengine dice `tex_ZERO_.FLDR`.
- **[EXE 0xDIR]** `Sacrifice.exe` (GOG, sha256 `a53ebb53…abcb`, base 0x400000). Se buscó en `.text` cada `push imm32` cuyo inmediato es una etiqueta de 4 letras (los tags se guardan al revés: `push 'hsap'` = `pash`). **Reatribuido el 2026-10-24 (método de 061V d-e):** el comienzo de cada función sale de la tabla de funciones con nombre de **0x4cbba8** (272 entradas, ver 061R) **más** todos los destinos de `call rel32` (E8) del `.text`. Cada etiqueta cae así en su función real (con nombre o `sub_XXXXXX`), y se sigue quién llama a esa función. La primera versión asignaba cada etiqueta a la entrada con nombre anterior, y cuatro atribuciones estaban mal (Skin of Stone, Ethereal Form, Protective Swarm y Grasping Vines: abajo). Una etiqueta prueba que el original usa ese recurso en esa función, pero no prueba qué dibuja. No se leyeron instrucciones con REA/Ghidra; no quedó ningún Ghidra corriendo.
- **[DOC]** manual oficial (`MANUAL.PDF` de la instalación, texto extraído). **[WEB]** guía polaca de gry-online.pl (páginas de hechizos por dios). No se vieron videos: ninguna afirmación de este informe sale de una captura.
- **[PORT]** código y datos del port (`game/…`).
- Precedencia: EXE/datos > sacengine > manual > web. Lo que no se pudo confirmar dice **NO VERIFICADO**.

Unidades: 60 ticks por segundo. sacengine anima los sprites a 30 cuadros por segundo (`updateAnimFactor = 2`). Un atlas de 4×4 con `delay` d muestra cada cuadro 2·d ticks, así que su ciclo dura 32·d ticks [SAC sacobject.d:1772-1811].

Partículas de sacengine que se repiten abajo. Mezcla según [SAC dagonBackend.d:2672-2683]; gravedad 15 m/s² donde dice «sí» [SAC sacobject.d:1300-1340; PORT `fx_catalog.py`].

| Tipo sacengine | TXTR (WAD/carpeta) | Sprite | Energía | delay | Mezcla | Gravedad | Alfa en función de la vida | En el port |
|---|---|---|---|---|---|---|---|---|
| `firy` | `firy` (main/bits) | 0,5 m | 8 | 1 | aditiva | no | 1 | `fx/firy.png` y `firy_a.png` |
| `fire` | `firy` | 1 m | 8 | 2 | aditiva | no | min(1,(v/64)²) | `data/fx/fire.tres` (firy_a MIX, energía 1: decisión del port por la nieve) |
| `heal`, `ghost` | `glo2` (main/bits) | 1 m | 4 | 1 (`ghost`: 2) | aditiva | no | heal: min(1,(v/0,75N)²) | `fx/glo2.png`, `data/fx/heal.tres`; `ghost` no tiene `.tres` |
| `freeze`, `etherealFormSpark` | `cst0` (main/bits) | 1 m | 3 | 1 / 2 | aditiva | freeze no; spark sí | min(1,(v/0,5N)²); escala min(1, v/0,5N) | `fx/cst0.png`, `cst0_a.png`; `data/fx/frost_breath.tres` usa cst0_a MIX |
| `shard` | `shrd` (charlie/Stra/txtr) | 1 m | 3 | 1 | aditiva | sí | 1 | `data/fx/freeze_shards.tres` (MIX con rampa azul) |
| `dirt` | `dirt` (main/bits) | 1 m | 1 | 2 | alfa | no | min(1, v/0,25N) | `data/fx/dirt.tres`, `dirt_cast.tres` |
| `rock` | `rock` (main/bits) | 1 m | 1 | 1 | alfa | sí | min(1, v/1,5N) | `data/fx/rock.tres`, `petrify_rocks.tres` |
| `slime` | `lth2` (Daniel/DanC/char) | 1 m | 1 | 2 | alfa | sí | min(1, v/0,75N) | **falta** |
| `castPersephone2` | `cst1` (main/bits) | 1 m | 5 | 1 | aditiva | no | 1 | **falta** |
| `castCharnel2` | `cfx1` (Daniel/DanC/char) | 1 m | 5 | 1 | aditiva | no | 1 | **falta** |

(N = ciclo del atlas en ticks; v = vida que le queda. Líneas de la tabla: sacobject.d:1413-1424, 1461-1466, 1479-1490, 1539-1544, 1582-1587, 1660-1665, 1684-1689, 1720-1725, 1824-1878.)

**Transparencia del original.** El material «shadeless» de sacengine pinta `textura · color · energía` y usa `alfa = textura.a · transparency` [SAC dagon shadeless.d:105-109, 184-200]. Una energía alta es un brillo HDR que el tonemap recorta. En el port, el brillo del original sale de sprites aditivos y no de bloom (memoria del proyecto). Sobre nieve, el port ya pasó algunos aditivos a MIX (`firy_a`, `cst0_a`): es una decisión del port, no del original, y se repite en cada ficha.

---

## 061b — Escudos de nivel 2

### Skin of Stone (`niks`, James)

**Qué dice el original.** [DOC] «Encases you in a shielding layer of stone». [WEB] Lo mismo: el mago convierte su piel en piedra.

**Lanzamiento** [SAC 17035-17072, 10591-10597]:
- La duración es `castingTime`, en ticks, la que da `getCastingTime` (≈ `casting_time_s`·60 = 59; el valor exacto depende de la animación, **NO VERIFICADO** al tick).
- Cada tick nacen 30 partículas `dirt` en un anillo a ras del suelo, de radio 2·(s+0,5) alrededor de los pies. `s` = semidiagonal horizontal de la caja grande en pose de reposo (`getScale(obj).length`, SAC 408-416).
- El anillo se cierra hacia el centro de la caja a medida que avanza el lanzamiento: en xy llega al 90 % del camino y en z al 100 %.
- Las partículas no tienen velocidad, miden 2·s y viven 12 ticks. Si se interrumpe el lanzamiento, viven 31.
- Además, una `dirt` por mano.
- [EXE 0x446a90 `SkinOfStoneCasting`]: `push 'dirt'` + `ttex` (coincide).

**Mientras dura** [SAC stats.d:91; renderer.d:1438-1440; dagon bone.d:189-192]:
- El cuerpo se dibuja con el sombreador de piedra: brillo = (r+g+b)/3, color = 0,3 + 0,7·brillo·(1, 1, 0,8), rugosidad y metal 0,5. Es el mismo aspecto que Petrify.
- No hay malla extra ni partículas.

**Fin** [SAC 17074-17106]:
- Suena `ksts`.
- 64 `rock` nacen en la caja ×0,9 y salen en direcciones al azar a 2,5–3 m/s. Miden 1–2,5 y viven 95 ticks, con gravedad.
- Termina por tiempo (80 s) o cuando el cuerpo deja de poder escudarse (`canShield`).

**El EXE no agrega nada** [EXE 0x446d10 `SkinOfStoneStart`: solo `PROT` y `thit`]:
- **Corrección:** `quk1` (0x447030) y `mud1` (0x447040), junto a `tscr` y `ttex`, están en `sub_446fb0`, que llama **`SpikeWallStart`** (0x4473e9). Son de Wall of Spikes, no de Skin of Stone.
- Skin of Stone no deja grieta ni pinta el cuerpo con `mud1`. Manda sacengine: tierra al lanzar, sombreador de piedra, rocas al terminar.

**Sonido.** `ksts` = `assets/original/audio/sfx/jams/stsk.wav` (fin). Al lanzar y al prender no hay sonido propio en sacengine (**NO VERIFICADO** en el EXE).

**Qué reutilizar del port.**
- `scenes/look/stone_look.gd` y `stone.gdshader`: ya son la fórmula exacta del sombreador de piedra. Hoy los maneja `Afflictions`, y su doc dice que Skin of Stone debe ser una fuente más de ese mismo `StoneLook`, no un segundo. Con `Wards` habrá que decidir un único dueño del look (§2c).
- `data/fx/petrify_rocks.tres` (rock, MIX, con gravedad): sirve para el estallido del final, ajustando los números (64, 2,5–3 m/s, vida 1,58 s).
- `data/fx/dirt_cast.tres` sirve de base para el anillo del lanzamiento. Es un anillo que se cierra, así que conviene un `SpriteEmitter` con forma de anillo o un `.tres` nuevo.

**Qué falta.** Nada por importar.

### Air Shield (`dlhs`, Stratos)

**Qué dice el original.** [DOC] «A mini-tornado that offers shielding properties». [WEB] Una bola de aire que gira alrededor del mago.

**Assets.**
- `shld` (charlie, `Bloo.WAD!/Stra.FLDR/txtr.FLDR`): 256², atlas de **4×2** remolinos azules en espiral con un hueco oscuro al medio.
- `pash` (misma carpeta): 256², atlas 4×4 de destellos en estrella blanco-azulados sobre negro.
- [EXE `sub_41f730`, la llama `RunAirShield` en 0x41f8d2]: `push 'icec'` + `ttex` (una textura), `push 'cst0'` + `tcst` (partícula del lanzamiento) y `push 'pash'`. Confirma los destellos `pash` y las partículas `cst0` del lanzamiento.
- **`shld` no aparece en ningún `push` del EXE.** En su lugar, la función del escudo carga `icec` como textura (`ttex`). `icec` (charlie, Stra/txtr, 128²) es hielo claro y lechoso. Lectura probable: la burbuja del original usa **`icec`** y no `shld`, o `shld` llega por otro camino. **NO VERIFICADO**: conviene importar los dos y decidir con una captura.
- Ninguno de los tres está importado.

**La burbuja** [SAC sacobject.d:2467-2537; renderer.d:322-331, 2144-2182]:
- **Malla.** Una esfera de radio 0,5 (24 anillos × 25 sectores) en 16 variantes deformadas por ruido: cada vértice se mueve hasta 0,12 con ruido suavizado entre vecinos.
- **Animación de forma.** La forma se transforma de una variante a la siguiente (morph) y recorre las 16 en 480 ticks (8 s), unos 30 ticks por variante.
- **Mapeo.** Cada celda del atlas se proyecta en polar: el centro de la imagen cae en los polos y el borde en el ecuador. Así el remolino «envuelve» la esfera desde arriba y desde abajo.
- **Capas.** Se dibujan 3 capas superpuestas, cada una desfasada 20 ticks en el morph, con la misma celda de textura.
- **Textura animada.** La celda cambia cada 8 ticks: 8 celdas, ciclo de 64 ticks (≈1,07 s).
- **Material.** Sin sombreado, mezcla **alfa** (no aditiva), energía 5, transparencia **0,075** por capa, sin escribir profundidad y con las caras traseras descartadas.
- **Tamaño.** `escala · (2, 2, 1,5) · caja`. La caja es la grande de la pose actual, con x = y = √((x²+y²)/2). Va centrada en el centro de la caja y gira con el cuerpo.
- **Latido.** La escala oscila ±0,05 a 2 Hz.

**Destellos** [SAC 17458-17525; renderer.d:2170-2178]:
- Cada tick nacen 0, 1 o 2 (en promedio 1) sprites `pash`: 0,75 m, **aditivos**, energía 10, 16 cuadros de 2 ticks. Mueren al terminar el ciclo (32 ticks).
- Altura h al azar en [-1, 1] sobre el centro de la caja, con amplitud ±0,5·alto. Radio = √(1−h²)·U(0,05; 1,25)·0,5·ancho.
- Giran alrededor del eje vertical: cada tick suman 2π/(0,75·60·(0,1+radio)) radianes. Los de radio chico giran más rápido.
- Su posición es relativa a los pies, gira con el cuerpo y se multiplica por la escala del escudo. El tamaño del sprite también es la escala del escudo.

**Aparece y desaparece:**
- Durante el lanzamiento la escala crece de 0 a 1 en `castingTime` ticks (≈44).
- Al terminar se achica de 1 a 0 en 15 ticks. Empieza 15 ticks antes de los 60 s, o al perder `canShield`.
- Si se interrumpe el lanzamiento, se achica desde donde llegó.

**Lanzamiento.**
- Las partículas de lanzamiento de Stratos salen de las manos (`animateStratosCasting`, SAC 16208).
- Además, 2 partículas `freeze` (cst0, aditivas) por tick nacen en la caja ×4 del **propio mago** y convergen a su centro, relativas al cuerpo (`animateFreezeCastingTarget` sobre el lanzador, SAC 17527-17543, 17435-17456).

**Sonido.** `dhsa` = `sfx/stra/ashd.wav`, con ganancia 2, al lanzar, al prender y al apagar [SAC 10663-10685, 17516].

**Qué reutilizar del port.**
- `scenes/units/passives/shield_bubble.tscn` + `life_shield.gd`: ya hacen crecer y achicar la burbuja en 15 ticks desde `shown` replicado. El plan los mueve a `Ward`.
- `fx/cst0.png` (y `cst0_a`) para las partículas del lanzamiento.

**Qué falta.**
- Importar `shld` y `pash` (agregarlos a `fx_catalog.ATLASES`; `pash` también como `ParticleType` aditivo), y `icec` como textura de malla para compararla con `shld` (también la pide Freeze).
- La deformación por ruido: lo idiomático en Godot es un shader de vértices sobre `SphereMesh`, con ruido 3D animado y amplitud 0,12·radio. No hace falta Blender: es una divergencia declarada de «16 mallas con morph» y el resultado se ve igual.
- El mapeo polar del atlas se hace en el mismo shader.
- Las 3 capas: 3 `MeshInstance3D` en la escena, o un shader con 3 pasadas.

### Ethereal Form (`mrfe`, Persephone)

**Qué dice el original.** [DOC] «The caster becomes a ghost, immune to attack». [WEB] Forma inmaterial.

**Según sacengine:**
- **Lanzamiento** [SAC 17108-17124]. Una partícula `heal` (glo2, aditiva) quieta en cada mano por tick.
- **Al prender** [SAC 10612-10619, 17126-17142]:
  - Suena `vniw` = `sfx/pers/winv.wav`, más un sonido del tipo «lightning» (`Xltn`: `sfx/stra/ltn1..6.wav`) con ganancia 2.
  - 64 `etherealFormSpark` (cst0, aditivas, energía 3, delay 2, con gravedad) nacen en la caja ×0,9. Salen al azar a 1–2 m/s, con la velocidad vertical ×1,5 y +1,5 m/s, así que suben antes de caer.
  - Miden 1–2,5 y viven 63 ticks. Se achican y se apagan en la segunda mitad del ciclo.
- **Transición** [SAC 2956-2965, 17143-17185]. En 30 ticks el alfa del mago baja de 1 a **0,36** y la energía sube de 1 a **10**. El cuerpo pasa a la pasada transparente sin sombreado (`RenderMode.transparent`, SAC 13071) y no proyecta sombra.
- **Mientras dura.** Cada tick nace una partícula `ghost` (glo2, aditiva, energía 4, delay 2, sin velocidad, cuadro inicial al azar, vida de un ciclo = 64 ticks) en un punto al azar de la caja. A diferencia del fantasma de la muerte, la ven **todos los bandos** (`animateGhost!false`, SAC 13798-13806).
- **Fin** (15 s o al perder `canShield`). El alfa y la energía vuelven a 1 en 30 ticks, y siguen naciendo partículas `ghost`. No hay chispas al salir.

**El EXE no contradice** [EXE 0x42b5b0 `EtherealFormRun`: solo `PROT`]:
- **Corrección:** `forb` (0x42b9a0, con `trng`) está en `sub_42b980` y `flao` (0x42b9f8, con `ttex`) en `sub_42b9f0`. Las dos las llama **`FlashOrbRun`** (0x42bc63 y 0x42bb2c), no Ethereal Form.
- Ethereal Form no empuja ninguna textura propia (tampoco `cst0` ni `glo2`: las partículas ya cargadas no necesitan `push`). Manda sacengine.

**Qué reutilizar del port.**
- `scenes/wizards/ghost_form.gd` ya tiene `GHOST_ALPHA = 0.36`, `GHOST_ENERGY = 10` y el paso a sin sombreado (`_look.set_shadeless`). El plan conecta `EtherealForm.shown_changed → GhostForm.set_ethereal`, así que GhostForm sigue siendo el único dueño de la transparencia.
- `fx/glo2.png` y `fx/cst0.png` ya están importados. Faltan solo los `.tres` (`ghost`, `ethereal_spark`).

**Qué falta.** Nada por importar.

### Fireform (`mrff`, Pyro)

**Qué dice el original.** [DOC] «A shield of flame that burns any enemies it touches». [WEB] La guía no lo describe.

**Lanzamiento** [SAC 17187-17252]:
- 3 partículas `firy` por mano y por tick suben desde la mano entre 0,5 y 1,5 m a lo largo de su ciclo. Viven una fracción al azar del ciclo (32 ticks).
- La cuota de llamas del cuerpo (ver abajo) sube de 0 a 10 por tick a medida que avanza el lanzamiento.
- Suena `1ngi` = `sfx/pyro/ign1.wav` (ganancia 4) y empieza el lazo `5plf` = `flp5.wav`, con ganancia 4.
- Hay dos `flp5.wav`, en `sfx/comn/` y en `sfx/pyro/`. Cuál usa el original: **NO VERIFICADO**.

**Mientras dura** [SAC 17206-17222, 17263-17295]:
- Cada tick nacen **10** partículas `fire` (firy 1 m, aditiva, energía 8, delay 2) en la superficie de un elipsoide alrededor del centro de la caja de la pose actual. El elipsoide mide max(x, y)+1 en x e y, y el alto de la caja +0,5 en z.
- Escala de la partícula = 0,5·max(1, ∛volumen). No tienen velocidad y viven 31 ticks, la mitad del ciclo: se ven los primeros 8 cuadros. Son relativas al cuerpo y lo siguen.
- El cuerpo se sigue dibujando normal: no hay tinte ni malla.
- Al quemar a alguien (`ignite`, SAC 17254-17261): 3 partículas de fuego sobre la víctima y `1ngi` (como mucho uno cada 1/3 s).

**Fin.** A los 40 s o al perder `canShield` se corta en seco. No hay partículas ni sonido de cierre en sacengine.

**El EXE** [EXE 0x427590 `FireformRun`]. No hay ningún `push` de etiqueta, ni en la función ni en sus auxiliares (`sub_427880` … `sub_427cd0`): usa partículas ya cargadas. No contradice, pero tampoco confirma.

**Qué reutilizar del port.**
- `data/fx/fire.tres` (firy_a, MIX, energía 1) más un `SpriteEmitter` (`scenes/fx/sprite_emitter.gd`) con tasa 600/s y emisión en una caja o esfera escalada a la caja.
- `scenes/units/passives/fire_shield.gd` ya quema con la `ignite` del Phoenix.

**Decisión pendiente.** El original es **aditivo, energía 8**. El port pasó el fuego a MIX por la nieve. Para «el look del original manda», conviene una captura de las dos variantes con criterio numérico.

**Qué falta.** Nada por importar.

### Protective Swarm (`rwsp`, Charnel)

**Qué dice el original.** [DOC] «A protective shield of swarming insects». [WEB] Insectos que giran alrededor del mago y atacan al que se acerca.

**Asset.** `pswm` (charlie, `Bloo.WAD!/Char.FLDR/tex.FLDR`): 256², atlas 4×4 de un escarabajo marrón con patas, con un halo amarillo en algunos cuadros (batir de alas). No está importado. En el EXE no aparece en ningún `push`: lo carga otro camino (**NO VERIFICADO**).

**Los bichos** [SAC sacobject.d:2378-2390; renderer.d:311-319, 2123-2143; state.d:17297-17433]:
- **Sprite.** `pswm` de 0,5 m, mezcla **alfa**, energía 1, sin escribir profundidad y sin sombra. 16 cuadros de 4 ticks (ciclo de 64), cada bicho con un cuadro inicial al azar.
- **Cuántos.** 150 en total. Nacen en las manos repartidos a lo largo del lanzamiento: ⌈(150 − n)/ticks restantes⌉ por tick.
- **Escala.** 0,25·max(1, ∛vol)·U(0,5; 1,75) por bicho.
- **Zona.** Un elipsoide con las medidas de la caja de la pose actual: max(x, y)+2 en x e y, y el alto +1 en z. Va centrado en el centro del cuerpo y gira con él.
- **Movimiento.** Cada bicho va en línea recta de su punto a otro punto de la superficie del elipsoide (el punto actual más 2,5 en una dirección al azar, normalizado y escalado). Tarda 20 ticks (`progress += 3/60`); al llegar elige otro. El resultado es un enjambre que zumba alrededor del cuerpo.
- **Fin.** A los 40 s o al perder `canShield`, los bichos siguen volando y el alfa baja de 1 a 0 en 2 s. Si se interrumpe el lanzamiento, se dispersan igual.

**Sonido.**
- Lazo `3rws` = `sfx/char/swr3.wav`.
- Al picar, el tipo `swarm` (`Xswr`: `sfx/char/swr1..3.wav`), como mucho uno cada 1/3 s por víctima.
- Lanzamiento: partículas del lanzamiento de Charnel.

**El EXE** [EXE 0x433470 `ProtectiveSwarmStart`]:
- `push 'fb_g'` + `ttex` (0x433507) y `PROT`. `fb_g` (main/bits, ya importado: el brillo del Manalito) es una textura que sacengine no usa aquí. Lectura probable: un resplandor al prender el enjambre. **NO VERIFICADO** qué dibuja.
- **Corrección:** `rift` + `tdmn` están en `sub_433580`, que llama **`WailingWallDemon`** (0x4337dd). Son de Wailing Wall, confirmado.

**Qué reutilizar del port.** Nada específico. `scenes/fx/sprite_particles.gd`/`sprite_emitter.gd` dibujan atlas, pero los bichos tienen trayectorias propias. Lo natural en Godot es un `GPUParticles3D` con un shader de proceso que mueva cada partícula entre puntos al azar de un elipsoide, en coordenadas locales.

**Qué falta.** Importar `pswm` con `fx_catalog`/`import_ui.py`.

---

## 061c — Control sobre un blanco

### Freeze (`zerf`, Stratos)

**Qué dice el original.** [DOC] «Encases enemies in a block of ice». [WEB] Un bloque de hielo alrededor de la unidad.

**Lanzamiento** [SAC 17527-17577]:
- Sobre el blanco, 2 partículas `freeze` (cst0, aditivas) por tick nacen en su caja ×4 y convergen al centro, relativas al cuerpo.
- Sobre el mago, 2 por tick salen de su centro hacia la caja ×4.

**El bloque** [SAC 3037-3045, 10693-10708; sacobject.d:2554-2600; renderer.d:344-354, 2183-2207]:
- **Malla.** Un **cubo** de 1×1×1 (6 caras con UV de 0 a 1), escalado a la caja grande de la pose actual (en coordenadas de mundo, sin girar con el cuerpo) y centrado en su centro.
- **Textura.** sacengine usa **`frez`** (charlie, Stra/txtr, 128², hielo azul con cristales, sin canal alfa).
- **Aparición.** El cubo crece de 0 a 1 en 30 ticks.
- **Material.** Sin sombreado, mezcla **alfa**, energía 5, transparencia **0,2**, sin escribir profundidad, dos caras visibles. Se ve un velo de hielo muy brillante a través del cual se ve el cuerpo.
- Sonido al congelar: `3zrf` = `sfx/stra/frz3.wav`, con ganancia 4.

**Deshielo** (por tiempo o por un golpe) [SAC 17585-17614]:
- El cubo **desaparece de golpe**.
- 30 `shard` nacen en la caja ×1,05 con velocidad horizontal unitaria hacia afuera y 3 m/s hacia arriba. Miden 0,75·max(1, ∛vol), viven 31 ticks y caen con gravedad.
- Sonido `breakingIce` (`Xice`: `sfx/stra/ish1..4.wav`).

**El EXE no coincide con la textura:**
- En `FreezeSpellInterrupt` (0x4216e0) hay `push 'icec'` en 0x42178f, y en `FreezeSpellRun` (0x4217c0) `push 'shrd'` en 0x42194b. En el Freeze **no aparece `frez`**: el original solo empuja `frez` en `SilverbackIcespray` (0x414146) y en `FrozenGroundStart` (0x422491).
- `icec` (charlie, Stra/txtr, 128²) es hielo más claro y lechoso que `frez`.
- Lectura probable: el bloque del hechizo Freeze del original usa **`icec`**, y `frez` es el del aliento del Silverback y de Frozen Ground. **NO VERIFICADO** (falta desensamblar). Los dos son baratos de importar: conviene traer los dos y decidir con una captura.

**Qué reutilizar del port.**
- `scenes/units/afflictions/frozen.gd` ya hace la duración, el deshielo y los fragmentos (`data/fx/freeze_shards.tres`).
- **Divergencia declarada en el port:** hoy el hielo es un **tinte** del `StoneLook` (`data/afflictions/frozen.tres look_tint`), no el cubo. Para el arte final, el tinte se reemplaza por el cubo.
- Ese mismo cambio arregla al Yeti (Icy Breath), que en sacengine dibuja el mismo bloque (mismo efecto `Freeze`).
- El cubo es un `BoxMesh` en la escena, con un `StandardMaterial3D` sin sombreado y en mezcla alfa. No hace falta Blender.

**Qué falta.** Importar `icec` y `frez` (Stra/txtr) como texturas de malla (`EXTRA_FX` en `import_ui.py`, igual que `scri`/`aura`).

### Grasping Vines (`eniv`, Persephone)

**Qué dice el original.** [DOC] «a tangle of Grasping Vines may be sent to reach out from the earth and hold fast a single foe». [WEB] Retiene a una unidad.

**Lanzamiento** [SAC 17788-17823]:
- Mago: partículas `castPersephone2` (cst1, aditivas, energía 5) desde las manos, 2 por mano y por tick, en direcciones al azar.
- Blanco: 16 `dirt` por tick en la huella del cuerpo, al ras del suelo. Miden 0,6·s, sin velocidad, y viven 31 ticks.

**Las lianas** [SAC 3077-3104, 10774-10812, 17825-17876; sacobject.d:2614-2658; renderer.d:367-376, 2232-2259]:
- **Cuántas y dónde.** **16 lianas.** La punta de cada una apunta a un punto al azar de la **mitad superior** de la caja. La raíz está en el suelo, a hasta 1 m de la punta en xy y 0,1·escala bajo tierra.
- **Malla.** Un tubo de 19 segmentos y 24 lados (25 vértices por anillo). El radio en la raíz es 0,1·escala de la liana y se afina linealmente a 0 en la punta. Escala de la liana = |tamaño de la caja|/2.
- **Esqueleto.** Cada anillo es un hueso (20 huesos). Los huesos siguen una spline por 4 puntos de control que se mueven como resortes amortiguados: aceleración 90/escala, amortiguación con vida media de 1 s, tope de 20 m/s, y un empujón al azar cuando se frenan. **Las lianas se retuercen sin parar.**
- **Textura.** `vine` (charlie, `Pers.FLDR/tex.FLDR`, 64², degradé vertical: verde oscuro en un extremo, ocre y naranja-rojizo en el otro), con u alrededor del tubo y v a lo largo (v = 0 en la raíz). Qué extremo de la imagen queda abajo: **NO VERIFICADO**, depende del sentido de carga de la imagen.
- **Material.** Material con luz, **opaco** (especular 1, rugosidad 1, metal 0,5).
- **Crecer y desaparecer.** Crecen con `lengthFactor` de 0,1 a 1 en 60 ticks. Al soltar, encogen de 1 a 0 en 60 ticks.
- **Sonido.** `toor` = `sfx/pers/root.wav` (ganancia 4) al agarrar; `dafr` = `sfx/pers/rfad.wav` (ganancia 2) al soltar.

**El EXE** [EXE 0x42c2f0 `GraspingVinesRun`]: `push 'vine'` en 0x42c33d, más `dirt`, `fbal` y `glo2`. Confirma la textura y la tierra. `fbal`/`glo2` sugieren un resplandor o bola que sacengine no dibuja (**NO VERIFICADO**).

**Qué reutilizar del port.**
- `scenes/units/afflictions/vined.gd` ya hace la duración, la crecida y el encogido en 1 s, y el rechazo a voladores.
- **Divergencia declarada:** hoy son 16 tubos en espiral de color verde liso, armados con `SurfaceTool` en tiempo de ejecución. No son lianas de sacengine.

**Qué falta.**
- Importar `vine` (Pers/tex) y `cst1` (main/bits).
- La malla: un tubo de 24 lados y 19 segmentos con una cadena de 20 huesos, hecho con **Blender CLI** (`vine.glb`, afinado lineal y UV como arriba). Así la liana es contenido del editor (§2b, C15) y no geometría armada en código.
- Un script mueve los huesos con la spline-resorte. Las 16 raíces y puntas salen al azar de la caja en cada lanzamiento.

### Rings of Fire (`rapf`, Pyro)

**Qué dice el original.** [DOC] «Envelops an enemy in a pulsating ring of flame». [WEB] El enemigo queda rodeado de anillos de fuego.

**Lanzamiento** [SAC 17617-17660]:
- Blanco: 2 `firy` por tick nacen en su caja ×2 y convergen al centro. Escala max(1, ∛vol), relativas al cuerpo.
- Mago: una `firy` quieta en cada mano por tick.

**Los anillos** [SAC 17662-17704]:
- **Cuándo nace uno.** Cada 25 ticks, más 1/50 de probabilidad en cada tick: en promedio ≈3,5 anillos por segundo (2,4 fijos + 1,2 al azar).
- **Cómo es.** 30 `firy` (aditivas, energía 8) en un círculo horizontal alrededor del cuerpo, a una altura h = U(0,4; 1,2) de la caja grande, así que algunos nacen por encima de la cabeza.
- **Radio.** r = U(1,2; 1,25)·s·h, con s la semidiagonal horizontal de la caja.
- **Escala del sprite.** El sprite de 0,5 m se escala por **r**: los anillos altos tienen llamas más grandes.
- **Movimiento.** Cada partícula va de su punto a los **pies** del cuerpo en d = U(0,8; 1,2) s y muere al llegar. Cada anillo se cierra y baja hasta desaparecer en el suelo. Ese es el «latido» del manual.
- Las partículas son relativas al cuerpo: lo siguen si se mueve.
- **Sonido.** `malf` = `sfx/pyro/flam.wav` (ganancia 4) al prender y lazo `5plf`. sacengine aclara que el original elige entre varios efectos de sonido (**NO VERIFICADO**).

**Fin** (10 s, o si el cuerpo ya no puede seguir afectado):
- 3 anillos más, en coordenadas del mundo (se quedan donde estaba el cuerpo).
- Suena `disableRingsOfFire` (`Xfrd`: `sfx/pyro/frd1..2.wav`).

**El EXE** [EXE 0x4258a0 `ChainsOfFireRun`, el nombre interno]. No hay `push` de etiqueta. No contradice.

**Qué reutilizar del port.** `fx/firy.png` (aditivo) o `firy_a.png` (MIX), con un `ParticleType` nuevo (`ring_of_fire`: 0,5 m, delay 1). Otra opción es que un emisor dispare ráfagas de 30 en anillo con velocidad hacia un punto, local al cuerpo.

**Divergencia del plan.** El plan proponía «3 TorusMesh con material aditivo». El original **no** usa toros: son anillos de sprites `firy` que se cierran hacia los pies. Para el arte final hay que cambiar ese nodo del árbol de 061c.

**Qué falta.** Nada por importar.

### Slime (`htel`, Charnel; nombre interno «Lethargy»)

**Qué dice el original.** [DOC] «A ball of viscous goo that covers an enemy from head to toe»; el aire sobre el enemigo «emanating forth a ball of putrid slime». [WEB] Lanza un pegote de baba sobre el enemigo.

**Assets.**
- `lthg` (Daniel.wad, `DanC.WAD!/char.FLDR`): 128², una textura continua de baba verde oliva.
- `lth2` (misma carpeta): 256², atlas 4×4 de gotas y salpicaduras verdes con alfa.
- `cfx1` (misma carpeta): atlas del segundo nivel del lanzamiento de Charnel.
- [EXE 0x432550 `LethargyRun`]: `push 'lthg'` en 0x4327e4 y `push 'lth2'` en 0x432818, más `TXTR` y `tgoo`. **Confirmado**: el original usa las dos texturas.
- Ninguna está importada.
- El archivo en la instalación se llama `Daniel.wad`, con mayúscula. La tabla del importador hoy escribe los nombres en minúscula; en un disco que distingue mayúsculas hay que usar el nombre real.

**La bola** [SAC 3061-3075, 17711-17728; sacobject.d:2602-2612; renderer.d:356-365, 2208-2231]:
- **Malla.** Una esfera (24×25, radio 0,5) con `lthg`, material **con luz y opaco** (especular 1, rugosidad 1, metal 0,5). Su diámetro es la diagonal 3D de la caja en reposo.
- **Avance.** El progreso avanza 1/`castingTime` por tick (≈74 ticks) y sigue aunque el mago ya terminó de lanzar.
- **Crece arriba.** Hasta el 85 % del progreso, la bola crece de 0 a 1 quieta **10 m sobre el centro** del cuerpo.
- **Cae.** Del 85 % al 100 %, cae en línea recta hasta el centro (≈11 ticks).
- **Lanzamiento del mago.** Partículas `castCharnel2` (cfx1, aditivas, energía 5), 2 por mano y por tick, en direcciones al azar.

**Impacto y mientras dura** [SAC 10753-10764, 17730-17786; renderer.d:1441-1452, 1798-1822]:
- **Al tocar.**
  - Suena `slime` (`Xfrx`: `sfx/pers/frx1..2.wav`, ganancia 4).
  - **128** `slime` (lth2, alfa, con gravedad) nacen en la caja ×1,2 con velocidad horizontal unitaria hacia afuera y 3 m/s hacia arriba: una salpicadura. Miden 0,8·s y viven 63 ticks.
- **Cuerpo bañado.** Mientras dura, **todas las superficies del cuerpo se dibujan con `lthg` en lugar de su textura**, con los mismos UV y la misma luz. No es un tinte: es un cambio de textura. Si el cuerpo además es de piedra, se aplican las dos cosas.
- **Goteo.**
  - Cada 10 ticks, más 1/20 de probabilidad en cada tick, nacen 4 gotas `slime` en la mitad superior de la caja ×0,8, relativas al cuerpo. Miden 0,25·U(0,75; 1)·s y viven 0,8–1,2 s.
  - Caen por gravedad. La velocidad inicial que escribe sacengine es ambigua (un `Vector3f` de 4 componentes, SAC 17760): **NO VERIFICADO**.
- **Fin** (`removeSlime`). Otra salpicadura de 128. Cada capa termina por separado (`numSlimes`), pero la textura queda mientras haya al menos una.

**Qué reutilizar del port.**
- La idea de `StoneLook` (un override por superficie que conserva UV y recorte alfa, dueño único en `Afflictions`). Para el baño hace falta otra variante del mismo shader: un uniform `swap_tex` que reemplace el albedo, con luz normal. No hace falta un segundo nodo de look.
- `SpriteEmitter`/`sprite_particles` para la salpicadura y el goteo, con un `.tres` nuevo `slime`.

**Divergencia del plan.** El plan proponía «has_look con tinte verde brillante». El original **cambia la textura** por `lthg`.

**Qué falta.**
- Importar `lthg`, `lth2` y `cfx1` (Daniel.wad).
- La bola es una `SphereMesh` con material `lthg`. No hace falta Blender.

---

## Resumen: qué importar y con qué herramienta

Todo lo de esta tabla lo lee `tools/import/import_ui.py` con `fx_catalog.py` (los atlas en `ATLASES`, las texturas de malla en `EXTRA_FX`), y la salida va a `assets/original/fx/`. Hace falta el original instalado (`SAC_INSTALL`, ver `tools/import/local.cfg.example`). Se verificó que todas existen en la instalación.

| Tag | WAD / carpeta | Tamaño / grilla | Uso | Hechizo |
|---|---|---|---|---|
| `shld` | charlie.wad · `Bloo.WAD!/Stra.FLDR/txtr.FLDR` | 256², 4×2 | textura de la burbuja (sacengine; el EXE no la empuja) | Air Shield |
| `pash` | ídem | 256², 4×4 | destellos aditivos | Air Shield |
| `icec` | ídem | 128² | bloque de hielo (probable según el EXE); posible textura de la burbuja (EXE) | Freeze, Air Shield |
| `frez` | ídem | 128² | bloque de hielo (sacengine), Yeti y Frozen Ground | Freeze |
| `pswm` | charlie.wad · `Bloo.WAD!/Char.FLDR/tex.FLDR` | 256², 4×4 | bichos | Protective Swarm |
| `vine` | charlie.wad · `Bloo.WAD!/Pers.FLDR/tex.FLDR` | 64² | lianas | Grasping Vines (y después Vinewall) |
| `cst1` | main.wad · `MAIN.WAD!/bits.FLDR` | 256², 4×4 | lanzamiento de Persephone de nivel 2 | Grasping Vines |
| `lthg` | Daniel.wad · `DanC.WAD!/char.FLDR` | 128² | bola y cuerpo bañado | Slime |
| `lth2` | ídem | 256², 4×4 | salpicadura y goteo | Slime |
| `cfx1` | ídem | 256², 4×4 | lanzamiento de Charnel de nivel 2 | Slime |

Ya están en el port: `firy`, `firy_a`, `glo2`, `cst0`, `cst0_a`, `shrd`, `rock`, `dirt`, `flao` y todos los sonidos nombrados arriba (`assets/original/audio/sfx/…`; los tags de sacengine se leen al revés: `ksts` → `stsk.wav`).

Mallas:
- **Blender CLI:** solo la liana (`vine.glb`: tubo de 24×19 con 20 huesos, afinado lineal).
- **Primitivas de Godot en la escena:** el cubo de hielo (`BoxMesh`), la bola de baba (`SphereMesh`) y la burbuja de aire (`SphereMesh` + shader de ruido y mapeo polar).
- **Aseprite:** no hace falta. Todas las texturas salen del original.

## Pendientes antes de dibujar (NO VERIFICADO)

1. **Freeze.** ¿`icec` o `frez` para el bloque? Desensamblar el entorno de 0x42178f (crear la función en Ghidra a partir de la tabla, como en 061R) o comparar con una captura.
2. ~~Skin of Stone: `quk1`/`mud1`~~ **Resuelto** (reatribución): son de Wall of Spikes (`sub_446fb0` ← `SpikeWallStart`).
3. ~~Ethereal Form: `forb`/`flao`~~ **Resuelto** (reatribución): son de Flash Orb (`FlashOrbRun`). Manda sacengine.
3b. **Air Shield.** ¿`icec` (lo empuja la función del escudo) o `shld` (sacengine; el EXE no lo empuja) para la burbuja? Captura de cámara fija. ¿Para qué usa `ProtectiveSwarmStart` el `fb_g`?
4. **Grasping Vines.** ¿Para qué usa el original `fbal`/`glo2` en `GraspingVinesRun`? ¿Qué extremo de `vine` queda en la raíz?
5. **Fuego** (Fireform, Rings of Fire): ¿aditivo con energía 8 como el original, o el `firy_a` MIX que ya usa el port? Se decide con capturas de cámara fija y un criterio numérico.
6. Ninguna apariencia se confirmó con un video. El manual y la guía confirman la forma general: piedra, minitornado, enjambre, bloque de hielo, lianas que salen del suelo, anillo de fuego que late y bola de baba que cubre al blanco.
