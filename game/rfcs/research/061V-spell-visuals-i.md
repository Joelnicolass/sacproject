# 061V-i — Cómo se ven en el original los hechizos de nivel 8 sobre un blanco (061i)

Este informe junta los hechos para el arte final de 061i: Charm, Blind Rage, Intestinal Vaporization, Bovine Intervention y Death. No trae diseño ni código. El plan está en `rfcs/plans/061-spells-master-plan.md` (pieza `SpellCarrier`) y los números de juego en `rfcs/research/061R-abilities-structures.md`. El usuario pidió **arte final desde el inicio**. El formato es el de `061V-spell-visuals-f-g.md` (mismo método: la tabla de recursos del registro SPEL manda sobre las etiquetas por defecto del exe).

## Fuentes y etiquetas

- **[SAC archivo:línea]** sacengine (`sacengine/source/`, GPL, solo lectura). Se describe lo que hace; no se copió código. Si no se nombra el archivo, es `state.d`. Los números de dibujo (energía, mezcla, tamaño del sprite) los decidió su autor.
- **[TXTR]** texturas y mallas leídas de las WAD de la instalación (`SAC_INSTALL`, exportado solo en el shell del que investiga) con el lector del port (`tools/import/sac_formats/`: `wad.py`, `txtr.py`, `models.py`).
- **[SPEL]** registro SPEL de cada hechizo (`spells.wad`, 314 bytes). Los sonidos están en la tabla que empieza en el byte 112 (`[bandera][' ' o '!'][etiqueta al revés]`) y los recursos en pares de 8 bytes desde el byte 142 (clave al revés con prefijo `t`/`f`/`i` y su valor). `tools/import/export_stats.py::spel_args` ya los lee igual. Los nombres de archivo del registro son los de los tags del port al revés (`chrm` = `mrhc`, `rage` = `egar`, `ivap` = `pavi`, `bovi` = `ivob`, `deat` = `taed`).
- **[WEB]** no se buscó: no hay nada que 061R no haya dicho ya. **Ninguna afirmación de este informe sale de una captura de video.**
- **[PORT]** código y datos del port (`game/…`).
- Precedencia: SPEL/EXE > sacengine > manual > web. Lo que no se pudo confirmar dice **NO VERIFICADO**. **No se abrió Ghidra ni REA para este informe**: la lectura del exe de f-g (banderas de dibujo) sigue sin confirmar y aplica igual acá.

Unidades: 60 ticks por segundo. sacengine anima los sprites a 30 cuadros por segundo (`updateAnimFactor = 2`).

## Los cinco registros SPEL

| Hechizo | Sonidos del SPEL | Recursos del SPEL | Qué dice |
|---|---|---|---|
| Charm `chrm` | `cchm` (1), `schm` (2), `hchm` (4) | `ttex = rift`, `ilen = 60`, `fwid = 0,25`, `thrt = hrot`, `tcst = hrot`, `tluv = hart`, `tSPK = hrot` | La cinta de cada espíritu usa la tira `rift` (la de Demonic Rift), 60 posiciones, 0,25 de ancho. Los corazones son `hrot` (partículas) y `hart` (el corazón grande sobre la criatura) |
| Blind Rage `rage` | `rfst` (4), `rhnd` (2) | `ttex = swrl`, `trng = peri`, `thnd = swrl`, `trg2 = per2`, `tcst = swrl` | El puño, su estela y el lanzamiento usan `swrl`. El anillo de la explosión es `per2` (sacengine) o `peri` (el exe llama `trng` al otro: **NO VERIFICADO**) |
| Intestinal Vaporization `ivap` | `ivph` (4), `ivpx` (4, lazo), `ivpf` (16) | `tstx = iva2`, `ilen = 30`, `fwid = 0,25`, `tcst = cfx1`, `ttex = gut1`, `tgut = gut2` | El proyectil es `gut1`, las tripas que giran en el blanco son `gut2`, el lanzamiento tira `cfx1` (anillos violetas de Charnel). `iva2` (64×64) no lo usa sacengine |
| Bovine Intervention `bovi` | `cow_` (2), `cowh` (4) | `tcst = dirt`, `iCHg = 1`, `iCH+ = 0` | El lanzamiento tira `dirt` (tierra de James). La vaca es la malla `bovi` |
| Death `deat` | `deth` (11), `Xbld` (4) | `tcst = cfx1`, `tcld = dth2` | El lanzamiento tira `cfx1`. La nube que rodea a la Muerte es `dth2`. La Muerte es la malla `deth` |

Las etiquetas que sacengine empuja a mano coinciden con el SPEL en todos los casos (`swrl`, `gut1`, `gut2`, `rift`, `hrot`, `hart`, `dth2`, `per2`, `cfx1`, `dirt`). Los tres nombres de sonido de Charm, Blind Rage (el segundo) y Death (el segundo) están **comentados** en sacengine (`//playSoundAt("mhcc"…)`, state.d:11296, 11325, `dnhr` 11250, 21581 usa `tsfr`); el SPEL los declara igual.

## Charm (`mrhc`, Persephone)

**Assets.**
- `rift` (Daniel · `DanC.WAD!/char.FLDR`, tira 1×8): **ya está en el port** (`fx/rift.png`) y lo dibuja `RiftRibbon`.
- `hrot` (shawn · `shwn.WAD!/pers.FLDR/text.FLDR`, **128²**, 4×4): partícula `heart` y `bouncingHeart`, 1 m, energía 20, aditiva. No está importada.
- `hart` (misma carpeta, **256²**, 4×4): el corazón grande sobre la criatura, 1 m × 1,5 × escala, energía 24, aditiva. No está importado.
- `cfx1`: ya está.

**sacengine** [SAC 4176-4226 (estructuras), 11288-11329 (lanzar), 21821-22034 (actualizar), 15915-15950 (el cambio); renderer.d:2517-2563, 2898-2915; sacobject.d:3260-3273]:
- **Lanzamiento.** Tres espíritus (cintas) rodean al mago mientras lanza: cada uno recorre puntos al azar de un disco de radio `1,0 + 1,1 × escala` alrededor del **centro del mago**, con interpolación a 1,5 por segundo. Cada tick sueltan un corazón (`heart`, 0,5 m, vida 63 ticks).
- **Vuelo.** Al terminar el lanzamiento salen hacia el blanco a `speed` (30 m/s) con predicción de la posición. Cada espíritu va a 0,2 m del centro del blanco, desfasados 120°. Si llegan y la criatura ya no se puede encantar, el hechizo termina sin efecto.
- **Encantamiento (`charming`).** Los tres espíritus giran alrededor del blanco durante `duration` = **5 s** (radio `0,95 × tamaño` del blanco). Si el blanco deja de ser encantable (`canCharm`), pasa directo al final sin cambiar nada.
- **El cambio** (`charm`, 21915-21950): la criatura **cambia de bando para siempre**: vacía su cola de órdenes, deja la selección y los grupos, adopta el bando del mago, recibe la orden `retreat` hacia el mago, entra en la selección del mago. 128 partículas `bouncingHeart` (con gravedad, vida 95) y un `CharmHeart` sobre su cabeza (crece y se achica en 2/3 s, dura 10 s).
- **Quién se puede encantar** (11304-11313): no el propio bando, **no un mago**, solo si el modo lo permite (`canCharm`: vivo, también quieto, lanzando, bajo `stunned`, etc.; **no** muerto, muriendo ni reviviendo), y solo si el bando del blanco **tiene un mago** (opción `charmNeutralCreatures`, por defecto apagada; state.d:29565 lo comprueba también al armar el hechizo). 061R: «las neutrales dependen de `charmNeutralCreatures`». No mira `ccProtected`.
- Las cintas siguen 4 s más después del cambio y se apagan.

**Qué reutilizar del port.** `RiftRibbon` (cinta de las últimas 120 posiciones, una de cada 3) con ancho 0,25; el patrón de `SpellCarrier` GUIDED; `data/fx/*.tres` para las partículas; `UnitBody.owner_slot` para el bando. **Qué falta:** importar `hrot` y `hart`; las dos `ParticleType` de corazones; el sprite del corazón grande; el cambio de bando de una criatura viva (no existe; los de Convert/Sacrificio son de almas).

## Blind Rage (`egar`, Pyro)

**Assets.**
- `rage` (`MODL.WAD!/rage.MRMC`): puño. **608 vértices, 998 caras, 12 cuadros** de morfo, caja ≈0,6 × 1,0 × 0,5 m, textura `M000` 256². No está importado. Los cuadros: 0-5 el puño se abre y cierra (lanzamiento), 3-6… vuelo, 7-11 el puño se cierra (sacengine usa los índices `castFrame`, `flyFrame`, `fistFrame`: 6, 4 y 4 pasos de transición de 13 ticks).
- `swrl` (charlie · `Bloo.WAD!/Pyro.FLDR/txtr.FLDR`, 128², 4×4): es la partícula `castPyro2` (energía 15, 1 m, aditiva). Lanzamiento, estela y las que giran alrededor de cada criatura enfurecida. No está importada.
- `per2` (misma carpeta, 256², 4×4): el anillo de la explosión (malla de anillo de 16×32 segmentos, 0,4 de alto, 16 cuadros de textura, aditiva, **energía 10**; la usa también la destrucción del altar). No está importada.
- `peri` (misma carpeta): el exe la llama `trng`; sacengine no la usa: **NO VERIFICADO**, no se importa.

**sacengine** [SAC 4112-4153, 11231-11255, 21518-21662; sacobject.d:3143-3230; renderer.d:2808-2882; 1143-1157, 1390-1394, 12945-12948, 13671-13683]:
- **Lanzamiento.** El puño aparece delante del mago (`hitbox y + 0,6`) apuntando adelante y crece de 0 a 1,5 mientras lanza (animación de apertura y cierre en vaivén). El mago tira `castPyro2` (`swrl`).
- **Vuelo.** Sale a `speed` 30 m/s hacia un punto a **4 m sobre el suelo** debajo del blanco (con predicción), girando a π rad/s. Tres partículas `swrl` por tick en la cola (vida 31). Mínimo 4 pasos de transición (52 ticks) de vuelo.
- **Formar el puño.** Al llegar, 52 ticks formando el puño, y luego 30 ticks bajando de 4 m a 0 sobre el suelo (`numHitFrames`). Total 82 ticks. Sonido `tsfr` (`rfst`) al terminar.
- **Explosión.** 128 ticks: el anillo `per2` crece de 0 a **30 m** (escala lineal con el cuadro; **sube 7 m**: 3 m que sube el estado, `position.z += maxExplosionHeight/128` por tick, state.d:21636, y 4 m que suma el dibujo, `maxOffset`, renderer.d:2849; corregido 2026-10-25, antes decía 4). A la vez, **el efecto**: todas las criaturas dentro de `effectRange` = **30 m** del puño (de **cualquier bando**, incluidas las propias) que no son magos y están en un modo `canCC` reciben `numBlindRages += 1` y se les borra la cola de órdenes. **No daña. No mira `ccProtected`** (los escudos no la frenan).
- **Furia (`BlindRageEffect`).** Dura `duration` = **30 s** (o hasta que la criatura muera o deje de estar en un modo `canCC`). Mientras dura (`isBlindlyRaging`): excepto Manahoar y Sac Doctor, **no obedece órdenes** (se borran cada tick y no camina por orden), **es agresiva aunque sea pacífica**, **no dispara** (`rangedAttack` es nulo) y **su blanco es la criatura más cercana de cualquier bando** (`closestCreatureInRangeExcept` su propio id). Alrededor de su caja giran partículas `swrl` (0,5 m, vida 32 ticks): 0 a 2 por tick, en un elipsoide de `2 × 2 × 1,5` veces la caja; giran una vuelta cada 0,75 s × (0,1 + radio). Al terminar `stop()`.

**Qué reutilizar del port.** `SpellCarrier` GUIDED (el puño), `CarrierPulse`/`SplashDamage.bodies_within` para buscar las criaturas a 30 m, `SpellAffliction` (capas y reloj), el patrón de `GuidedFlight` para el vuelo con altura mínima; `quake_ring.tscn` como referencia del anillo. **Qué falta:** importar `rage` (12 cuadros), `swrl`, `per2`; un estado `BlindRaged` en las unidades; que `UnitBody`/`Targeting` lo respeten; un anillo con malla que crece (shader aditivo).

## Intestinal Vaporization (`pavi`, Charnel)

**Assets.**
- `gut1` (charlie · `Bloo.WAD!/Char.FLDR/tex.FLDR`, 256², 4×4): el proyectil, sprite de 1,75 m, mezcla **alfa** (Transparent), energía 3, 16 cuadros a 4 ticks. No está importado.
- `gut2` (misma carpeta, 256², 4×4): las 7 tripas que giran alrededor del blanco: sprite de 1,25 m × la escala del blanco (acotada a [0,75, 3]), alfa, energía 3. No está importado.
- `cfx1`: ya está (el lanzamiento).

**sacengine** [SAC 4086-4110, 11217-11229, 21423-21516; sacobject.d:3114-3141; renderer.d:2776-2807; sacspell.d:215]:
- **Lanzamiento.** El mago tira `castCharnel2` (`cfx1`). El proyectil `gut1` ya existe desde el comienzo, pegado al mago (`hitbox + …`), y sale al terminar.
- **Vuelo.** 30 m/s, con predicción, hasta 0,25 m + medio tamaño del blanco. Si el blanco ya no está en un modo `canIntestinallyVaporize` (o `dying`), no pasa nada.
- **Hinchazón.** Al llegar suena `hpvi` (`ivph`) y nacen 7 efectos `gut2` que **orbitan** el centro del blanco (disco de radio `2 × escala`, velocidad `3 × escala`, interpolación a 1/s). Durante `duration`: el blanco se **aturde** con enfriamiento de 3 s (se repite) y se **infla**: `bulk` pasa de `2 − 0,75ⁿ` (n = almas comidas) a `2,5 + (bulk − 1)` linealmente con el progreso. Al final suena `xpvi` (`ivpx`) y **se gibea**: explota en sangre (`gibAnimation`) y **su alma queda** (nace `emerging`).
- **Duración.** El SPEL dice **5 s** (061R). sacengine la fuerza a **8,5 s** (sacspell.d:215): se usa el dato (como en Frozen Ground).
- **Quién:** `canIntestinallyVaporize` (vivo; incluye `firewalk`; **no** `dying`, `reviving`, etc.). Un mago no es blanco válido (`flags` = `0x2004`: criaturas, no aliados).

**Qué reutilizar del port.** `SpellCarrier` GUIDED, `Stunned.stun_with_cooldown`, `DevourGrowth` (único dueño de la escala por hinchazón), `Soul`/`SoulSystem` para el alma que queda, `hover_blood`+`blood` para el estallido (los usa `UnitBody._gib_fallen`). **Qué falta:** importar `gut1`, `gut2`; el estado `Inflated`; el gibeo con alma (`UnitBody` solo conoce el gibeo sin alma por caer a un agujero).

## Bovine Intervention (`ivob`, James)

**Assets.**
- `bovi` (`MODL.WAD!/bovi.MRMC`): la vaca. **455 vértices, 893 caras, 65 cuadros** de morfo, caja ≈1,5 × 1,9 × 2,1 m (se dibuja ×4), textura `M000` 256². No está importada. Cuadros: 0-9 rumia y tambaleo (se repiten 4 veces), 10-42 arranque, **43-50 salto** (se repite 3 veces), 51-54 caída y 55-64 los últimos diez (en lazo mientras cae).
- `dirt` y `rock`: ya están. `dust` (la partícula `slowDust`) ya está. Las rocas de los escombros son la malla `rock` (ya está: `assets/original/props/rock.glb`).

**sacengine** [SAC 4155-4174, 11257-11286, 21665-21819; sacobject.d:3232-3258; renderer.d:2883-2897, 2064-2066, 25716-25759]:
- **Lanzamiento.** Un punto del suelo **15 m delante del mago** (en su dirección). Durante el lanzamiento: 3 partículas `dirt` por tick (radio 3 m, `castJames2`) y un temblor de pantalla que crece.
- **Salida.** La vaca nace **4 m bajo tierra** en ese punto: 64 rocas, 16 `slowDust`, 24 `dirt`, sonido `cow_` y temblor de 0,5 s. Se dibuja ×4, mirando al blanco.
- **Viaje.** **12 s** (`travelTime`). Altura: del punto a la del blanco en parábola con **200 m** de pico (`4 × 200 × t × (1 − t)`); en horizontal avanza `(blanco − vaca)/tiempo restante` (el doble hasta los últimos 2 ticks).
- **Llegada.** A los 12 s la vaca está en el centro del blanco: suena `hwoc` (`cowh`) y, si el modo lo permite (`canBovinelyIntervene`: vivo o muriendo, también `firewalk`), la criatura **se gibea** (**su alma queda**). La vaca sigue cayendo.
- **Impacto.** Cuando atraviesa el suelo (o a `gibDepth` si no hay suelo): 16 escombros `rock` ×0,4 (≈20 m/s, rotando) + `gibAnimation` + 100 rocas + 100 `slowDust` y una **onda de choque** (`Quake`): **aturde** a todo el que cruza la onda hasta **25 m** del centro (8 s de enfriamiento por cuerpo). **No daña**. La vaca se borra.
- 061R dice «cae sobre el blanco: lo gibea… y luego revienta con escombros». El gibeo del blanco es lo único con efecto de daño; el daño `amount` 3000 del SPEL no se lee.

**Qué reutilizar del port.** `QuakeWave` (`scenes/units/abilities/quake_wave.gd`, parámetro `stun_max`) para la onda; `debris_piece.tscn` de 061f para los escombros; `rock.tres`, `dirt.tres`, `dust` para las partículas; `ShakeMap` para el temblor. **Qué falta:** importar `bovi` (65 cuadros) y la partícula `slowDust`; el movimiento de caída.

## Death (`taed`, Charnel)

**Assets.**
- `deth` (charlie · `Bloo.WAD!/Char.FLDR/modl.FLDR/deth.MRMC`): la Muerte. **131 vértices, 201 caras, 27 cuadros** de morfo, caja ≈5,4 × 12,5 × 6 m (**12 m de alto**), textura `M000` 256². No está importada. Cuadros: 0-4 aparece/desaparece, 5-9 camina, 10-26 guadaña (el golpe cae al 70 %, cuadro 12 de 17).
- `dth2` (Daniel · `DanC.WAD!/char.FLDR`, 256², 4×4): la nube que la rodea. **sacengine invierte los colores de la textura** (`255 − rgb`) y la dibuja con energía **negativa** (−0,25/3): oscurece, no ilumina. No está importada.
- `cfx1`: ya está. Los rayos son `ltng` (ya está).

**sacengine** [SAC 4250-4305, 11341-11362, 22111-22300; sacobject.d:3275-3337; renderer.d:1968-1982, 2916-2998]:
- **Lanzamiento.** La Muerte aparece donde se hizo clic en el suelo; si se hizo clic sobre una criatura, **10 m delante del mago** de ese punto. Durante el lanzamiento está en su pose de caminata, mirando al mago. Aparece en 2 s: una **disolución vertical** (sombreador de «construcción»: la malla se revela de abajo hacia arriba en una banda de 1,2 m, de 0 a 12 m). Sonido `deth` (`hted`, ganancia 4). El mago tira `cfx1`.
- **Caza.** Cuando termina el lanzamiento: cada tick busca la **criatura más cercana de cualquier bando que no sea un mago** (`closestCreatureIgnoringWizards`, desde 6 m sobre el suelo). Gira hacia ella a π rad/s y avanza a `speed` = **18 m/s** hasta quedar a `2 m + escala`. Si está a ≤ `4 m + escala` y bien orientada, ataca (golpe de 17 pasos de 12 ticks; el golpe cae al 70 %). Sonido `deth`.
- **El golpe.** Si en ese momento está a ≤ `6 m + escala`, **mata** a la criatura (`kill`: muerte normal con su cadáver y su alma; ignora escudos y resistencias), 3 rayos `DeathEffect` alrededor (largo `max(6, 1,5 × ∛volumen)`, 32 ticks, 12 de ida y 12 de vuelta, desplazamiento vertical de 10 m, ancho 0,75), sonido `blade`. Cuenta un blanco y espera (`pausing`) hasta que mira al siguiente.
- **Fin.** Se va (5 pasos de transición, 1 s) cuando pasan `duration` + el tiempo de lanzamiento (**40 s + 4,44 s**) o cuando mató `maxNumTargets` = **8** criaturas. 061R: `amount3` del SPEL es 8 y el exe lo lee [REA `DeathSpellRun` 0x4300a0]. Un mago nunca es blanco (ni el propio).
- **Nube (`SacDeathAura`).** 3 esferas con ruido (24×25, radio 0,5, ruido 0,06, 16 deformaciones) de `2,4 × 2,4 × 1,9` veces la altura (12 m), escala 0 → 1 cada 2 s (rotando 20 ticks entre capas), aditiva con energía `−0,25/3 × (1 − escala)²`.

**Qué reutilizar del port.** `LightningStrike`/`FxBus.broadcast_beam` para los 3 rayos; `Health`/`UnitBody` para la muerte (mismo camino que cualquier muerte: cadáver + alma); `noisy_sphere.gdshaderinc` (061f) para la nube; el blanco más cercano que no sea mago es una búsqueda por grupos (`SplashDamage.bodies_within`). **Qué falta:** importar `deth` (27 cuadros) y `dth2`; un sombreador de disolución vertical (la «construcción»); un movimiento de caza para el portador.

## Resumen: qué importar y con qué herramienta

Las texturas van con `tools/import/import_ui.py` (`EXTRA_FX`); salen a `assets/original/fx/`. Las mallas con cuadros de morfo van con un importador nuevo parecido a `import_dragonfire.py` (Blender CLI, solo para convertir: no se modela nada) y salen a `assets/original/props/` como `.glb` con blend shapes. Hace falta el original (`SAC_INSTALL`). Se comprobó que todo existe en la instalación.

| Tag | WAD / carpeta | Tamaño / grilla | Uso | Hechizo |
|---|---|---|---|---|
| `hrot` | shawn · `shwn.WAD!/pers.FLDR/text.FLDR` | 128², 4×4 | corazones | Charm |
| `hart` | ídem | 256², 4×4 | corazón grande | Charm |
| `swrl` | charlie · `Bloo.WAD!/Pyro.FLDR/txtr.FLDR` | 128², 4×4 | puño, estela, furia | Blind Rage |
| `per2` | ídem | 256², 4×4 | anillo de la explosión | Blind Rage |
| `gut1` | charlie · `Bloo.WAD!/Char.FLDR/tex.FLDR` | 256², 4×4 | proyectil | Intestinal Vaporization |
| `gut2` | ídem | 256², 4×4 | tripas que giran | Intestinal Vaporization |
| `dth2` | Daniel · `DanC.WAD!/char.FLDR` | 256², 4×4 | nube de la Muerte | Death |
| `rage` | models · `MODL.WAD!/rage.MRMC` | 608 vért., 12 cuadros | puño | Blind Rage |
| `bovi` | models · `MODL.WAD!/bovi.MRMC` | 455 vért., 65 cuadros | vaca | Bovine Intervention |
| `deth` | charlie · `Bloo.WAD!/Char.FLDR/modl.FLDR/deth.MRMC` | 131 vért., 27 cuadros | la Muerte | Death |

**Ya están en el port:** `rift`, `cfx1`, `rock` (y su malla), `dirt`, `dust`, `blud`, `ltng`. **Los sonidos nombrados** están todos en `assets/original/audio/sfx/` (`cchm`, `schm`, `hchm`, `rfst`, `rhnd`, `ivph`, `ivpx`, `ivpf`, `cow_`, `cowh`, `deth`, `gib1..4`). Hay que darles una clave en `data/audio/fx_sounds.tres`.

**Blender CLI** (solo conversión): las tres mallas con cuadros (`import_morph_models.py` reutiliza `read_frames` y el script de Blender de Dragonfire: la malla del cuadro 0 más un *shape key* por cuadro). **Aseprite:** no hace falta. **Primitivas de Godot:** el anillo de la explosión (un `ArrayMesh`/`TorusMesh` plano con el sombreador aditivo), las esferas de la nube de la Muerte (`SphereMesh` con `noisy_sphere.gdshaderinc`).

## Luces (regla del usuario del 2026-10-24: cada hechizo ilumina con su color)

El exe no tiene luces conocidas para estos cinco (la tabla de f-g solo nombra Healing Aura, Firewall, Demonic Rift y Explosion): el color sale del **dominante de la textura** (media de los píxeles ponderada por el cuadrado del brillo, normalizada al canal más alto). Sin sombras, energía y alcance moderados.

| Efecto | Tipo | Color | Fuente |
|---|---|---|---|
| Charm, espíritus en vuelo y en torno al blanco | `ActorLight` hijo del portador | (1, 0,1, 0,3) rosa | `hart` |
| Charm, el cambio de bando (corazones) | `FxLightSpec` de `charm_hearts` | (1, 0,13, 0,13) | `hrot` |
| Blind Rage, el puño | `ActorLight` hijo del portador | (1, 0,3, 0,2) rojo anaranjado | `swrl` |
| Blind Rage, la explosión | `FxLightSpec` de la partícula del anillo | (1, 0, 0) | `per2` |
| Intestinal Vaporization, el proyectil | `ActorLight` hijo del portador | (1, 0,5, 0,47) | `gut1` |
| Intestinal Vaporization, el gibeo | `FxLightSpec` de `vaporize_burst` | (1, 0,5, 0,5) | `gut2` |
| Bovine Intervention, la caída | `FxLightSpec` de las rocas del impacto | (1, 0,8, 0,44) | `dirt` |
| Death, en camino | `ActorLight` hijo del portador | (0,75, 0,05, 1) violeta | `cfx1` (la nube `dth2` oscurece: no se ilumina con ella) |
| Death, el golpe | `FxLightSpec` de la partícula del golpe | (0,75, 0,05, 1) | `cfx1` |

## Pendientes antes de dibujar (NO VERIFICADO)

1. **Sonidos de Charm y la furia:** sacengine los comenta. Se usan `cchm` al empezar, `schm` al soltar los espíritus y `hchm` al cambiar el bando; son nombres del SPEL, no una captura.
2. **`peri`** (la otra textura de anillo de Blind Rage) y `iva2` (la textura que el SPEL de Intestinal Vaporization llama `tstx`): sacengine no las usa.
3. **Banderas de dibujo** del exe (aditivo/alfa/oscurecer) para `gut1`/`gut2`: sacengine dice alfa (Transparent); no se confirmó con el exe.
4. **Duración de Intestinal Vaporization:** el dato (5 s) y sacengine (8,5 s) no coinciden; se usa el dato.
5. **Charm sobre neutrales:** `charmNeutralCreatures` es una opción de sacengine (apagada); el original puede ser distinto. Va como regla de la partida (`charm_neutral_creatures`), apagada.
6. Ninguna apariencia se confirmó con un video. Cada arte nuevo se cierra con una captura de cámara fija y un criterio numérico (CONVENTIONS §2c).

## Cómo se leyó (reproducible, sin rutas personales)

- **SPEL:** de cada registro de `spells.wad` (`wad.walk`), la tabla de sonidos desde el byte 112 y los pares de recursos desde el 142 (8 bytes: clave al revés, valor al revés si es una etiqueta; float32 o int32 si no). La misma lectura que `export_stats.py::spel_args`.
- **Mallas:** `sac_formats.models` y la lectura de cuadros de `import_dragonfire.py::read_frames` sobre `MODL.WAD!/<tag>.MRMC/<tag>.MRMM`.
- **Texturas:** `sac_formats.txtr.flat_texture` sobre cada carpeta; las dimensiones salen del TXTR. La grilla es la de sacengine (`makeSpriteMeshes(4, 4)`).
- No se abrió Godot ni Ghidra.
