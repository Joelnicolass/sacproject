# Poblados y habitantes pasivos de Sacrifice (Shiny, 2000): investigación con evidencia

Regla del usuario: «usa REA, busca en la web, no inventes nada». Cada hecho lleva fuente y estado.

Etiquetas: [REA] visto en `Sacrifice.exe` con REA (Ghidra 12.1.4, JDK 21, heap 3 GB, un solo proceso, pico ~1,5 GB RSS); [DATOS] leído a mano de los archivos originales (`maps/*.scp`, `data/*.wad`) con los scripts de `game/tools` (sin interpretar); [SAC archivo:línea] código de sacengine (`/Users/joelsartori/Development/sacproject/sacengine/source`); [DOC] documento oficial del juego (`~/Downloads/sacgame/Sacrifice/ReadMe.txt` y `MANUAL.PDF`, texto extraído con PDFKit); [WEB url]; [NO ENCONTRADO].

## (a) Resumen

1. **Confirmado, con matices.** Hay criaturas «indígenas» pasivas (Peasant, Farmer, Zombie, Snowman, Slave según el reino) que no atacan (agresividad 0) y que se matan para quedarse con sus almas. El manual oficial lo dice: «son almas esperando ser convertidas» y en multijugador «no dudes en volarlas para juntar sus preciadas almas» [DOC].
2. **Refutado: las casas no dan almas.** Destruir un edificio no genera alma [SAC state.d:8376-8380, 9156 solo da XP]. Las casas son el **refugio**: los campesinos huyen solo cerca de su aldea y en las afueras se encogen (cower) y esperan [DOC]. Las casas sí se pueden destruir (hay una función de script `DestroyHut` en el ejecutable [REA 0x4cc04c]; vida máx. 5000 [DATOS]).
3. **Matiz clave sobre las almas.** El alma de un campesino es **roja**, no azul: no se junta caminando; hay que **convertirla** (hechizo Convert, Sac Doctor) [DOC, SAC state.d:14946-14962, 1622-1630]. Solo es azul (la toma cualquier mago) si la criatura revienta (gib) [DOC, SAC state.d:8341-8362]. Por eso «matar NPC» alimenta la economía **vía Convert o gib**, no por recogida directa.
4. **Cantidad.** High Noon: 26 Farmer (1 alma c/u) en el bando 2, 5 `jhut` + 6 `jwg1` como refugio (11), más 6 Taurock hostiles (2 almas c/u) que **no** son pasivos [DATOS].
5. **IA original.** No se encontró ninguna tarea «cazar campesinos» en la IA (shiny.d, portada de la IA original). Las criaturas atacan al enemigo que ven; el bando 2 es enemigo de todos, así que los atacan de forma emergente [SAC bots/shiny.d, state.d:13732+]. Inferencia, no verificada en el exe.
6. **No se pudo verificar en el exe** el significado exacto del bit de refugio ni la regla de huida de campesinos (sacengine tiene `TODO`); sí se verificaron los estados del FSM (ver tabla).

## (b) Tabla de hechos

### Qué son los poblados

| # | Hecho | Fuente | Estado |
|---|---|---|---|
| 1 | No existe una entidad «poblado». Un poblado es el conjunto de refugios (BLDG con la marca `shelter`) y campesinos cerca. | [SAC state.d:1712, 28844-28851; sacobject.d:968-969] | Verificado en código |
| 2 | Refugio = BLDG con flag bit 15 (`BldgFlags.shelter`, `bldg.d:11`, comentario `TODO: correct?`) **o** un altar. | [SAC bldg.d:11, sacobject.d:969] | Verificado en código; la marca es hipótesis del autor |
| 3 | BLDG del original con ese bit (cabecera `+0`): `jhut`, `jwg1`, `hut1`, `HUT_`, `cht1`, `cht2`, `sht1`, `pht1`, `pht2`, `silo`, `maus`, `mas2`, `pch2`, `pch3`, `pcwm`, `prt_`, `pwhr`, `sig1`, `stst`, `ctc_`, `jmrq` (21). Es decir, chozas, silos, mausoleo y similares; consistente con «refugio de aldea». | [DATOS wads `data/*.wad`, BLDG offset 0, bit 1<<15] | Verificado en datos; el significado del bit no está confirmado en el exe |
| 4 | High Noon, refugios: 5 `jhut` en (1070,1075), (1255,1214), (1313,1239), (1239,1300), (1293,1317); 6 `jwg1` en (1102,1521), (1529,1498), (1492,1048), (1466,1039), (1127,1502), (1496,1500). Todos en el bando 31 (neutral, sin relaciones). Cabecera `0xa0c0`, vida máx. 5000. | [DATOS `(2) High Noon.scp` NTTS, STRC; BLDG `jhut`/`jwg1`] | Verificado en datos |
| 5 | High Noon, otras estructuras no refugio, bando 31: `jfnt` ×5 (manantiales), `bld1/2/3` ×3/6/3, `bon1/2/4/5/6` ×2/2/2/1/3, `jcc1..4` ×11/6/8/6 (vida 1000, flags `0x20c8`), `jeg1/2/3` ×1/3/1. Los nombres/uso (casas, huesos, etc.) **no** están confirmados. Altares `jaal` en bandos 0 y 1. | [DATOS] | Conteo verificado; significado [NO ENCONTRADO] |
| 6 | Cada refugio es destructible: existe la función de script `DestroyHut` junto a `DestroyManalith`, `DestroyAltarPillar`, `DestroyAltarRing`, `RunCreateBuilding`. | [REA string 0x4cc04c `DestroyHut`, 0x4cc028, 0x4cc100-0x4cc148] | Verificado en exe (existencia); qué hace al destruirse no decompilado |
| 7 | Al destruirse un edificio solo se otorga XP (5000, `// TODO: ok?`) y arranca `BuildingDestruction`; no hay alma. | [SAC sacobject.d:972, state.d:9156, 8376-8380, 15157] | Verificado en código |
| 8 | Otros mapas con campesinos (bando = n.º de jugadores): Alpine Meadow 8 Peasant; Cathedral 24; Faceoff 16; Ferry 20 Snowman; Fork In The Road 24; High Noon 26 Farmer; Peasantville 53 Farmer; Roads 16 Slave; Trial 12 Peasant; Firefight 6 Slave; Gladiator 11 Zombie; Molehill 13 Snowman; This Island Burnt 18 Slave; Triad 24 Peasant; Devil's Tails 24 Zombie; Exe 20 Farmer; Faceoff Returns 32 Peasant; Genie 32 Zombie; Iron Cross 40 Snowman; Joust 32 Slave; Kirwan 20 Farmer; Pinched 16 Zombie; Snowy Plains 24 Snowman; Star 40 Zombie; WinterWonder 12 Snowman. Sin NPC: Closest Combat, Peaks, Stone's Throw, Trenches, Web, Hamburger Hill (solo criaturas), Valley of the Dead (criaturas de todos los tipos, no campesinos). | [DATOS NTTS de cada `.scp`] | Verificado en datos |
| 9 | La variante depende del reino: `saep` Peasant, `zepa` Snowman (Stratos/nieve), `zepd` Zombie (Charnel), `zepe` Farmer (James), `zepf` Slave (Pyro). Manual: «peasants, zombies, farmers». | [SAC nttData.d:133, 651; DATOS creatures.json; DOC manual 9.5 / «The Locals»] | Verificado |

### Bandos y relaciones

| # | Hecho | Fuente | Estado |
|---|---|---|---|
| 10 | SIDS de High Noon: bando 0 (enemigos: 1,2,3), 1 (aliado 2 = sí mismo; enemigo de todos), **2 = campesinos** (aliado solo de sí mismo; enemigo de todos), **3 = Taurock** (idem), 31 = neutral (sin relaciones). Los bandos 2 y 3 no tienen jugador asignado. | [DATOS SIDS; SAC sids.d, state.d:30051-30060] | Verificado |
| 11 | Los campesinos son «neutrales» solo en el sentido de pasivos: por stance son **enemigos** de los dos magos, así que cuentan como blanco válido y como enemigo para las criaturas. | [DATOS SIDS; SAC state.d:28812-28818] | Verificado en datos/código |
| 12 | Un refugio solo cuenta para un campesino si su bando no es enemigo suyo (los del bando 31 pasan; los altares enemigos no). | [SAC state.d:28844-28848] | Verificado en código |

### Habitantes y comportamiento

| # | Hecho | Fuente | Estado |
|---|---|---|---|
| 13 | Stats (original): Peasant/Snowman/Zombie/Farmer/Slave: vida 500, agresividad 0, 1 alma, vista 50 m, `behaviorFlags` 256 (bit 8 «villagers»), vel. 7.25 m/s, fuerza melé 0. | [DATOS `spells.wad` CRE8 → `game/cache/data/creatures.json`; comentario en SAC spells.d:62] | Verificado en datos |
| 14 | El FSM de comportamiento del campesino es `saep`; no hay FSMC `saep` en `fsm.wad` (solo `norm`, `ofly`, `sacd`, `fami`): los estados de campesino viven en el FSM `norm`. | [DATOS `fsm.wad`; SAC sacobject.d:60-62] | Verificado |
| 15 | En el FSM `norm` hay estados: **Cower**, **Working the fields** (acción `PeasantSetWorkAnimation`), **Talking**, **Disgusted**, **Laughter**, **Double take**, **Sorrow**, **Ambivalence**. | [DATOS `fsm.wad` entrada `norm` offsets 0xacc-0x10ec; REA string 0x4cf144 `PeasantSetWorkAnimation`] | Verificado (nombres); la lógica de transición no se decompiló |
| 16 | Animaciones de campesino reutilizan campos de vuelo: cower, pull, pull 2, dig, pull down, talk/cower. | [SAC animations.d:33-38, 63; nttData.d:141] | Verificado en código |
| 17 | Al iniciarse, los campesinos reciben `behaviorFlags |= 0xc000` (bit 14: máscara de rencor; bit 15: alarma a los del mismo bando en 100 m). | [SAC state.d:1076; spells.d:62 comentario] | Verificado en código; semántica de bits = comentario del autor |
| 18 | Sin orden (`CommandType.none`) el campesino: absorbe rencores de su manada (rango 80, mismo `manaCost`); si hay refugio a ≤50 m, deja de encogerse y, si un enemigo está a ≤50 m, corre en dirección contraria; si no hay enemigo se queda quieto; **si no hay refugio a ≤50 m se encoge (cower)** y espera. | [SAC state.d:13610-13611, 13634-13642, 13732-13760] | Verificado en código; el autor anota `TODO: figure out the original rule` |
| 19 | Manual: «huyen solo cerca de su aldea; en las afueras se encogen y esperan ser sacrificados». Coincide con 18. | [DOC ReadMe 9.5; MANUAL.PDF «Soul Advice»] | Verificado |
| 20 | Si algo los daña con vida llena, el bando agresor entra en su `grudgeMask` y huyen de él. | [SAC state.d:8934-8936, 12438, 13740] | Verificado en código |
| 21 | Los campesinos no se pueden seleccionar ni ordenar; tienen conducta programada. | [DOC Scapex, MANUAL.PDF «Orders»] | Verificado |
| 22 | No atacan (agresividad 0, fuerza 0). | [DATOS; SAC isAggressive] | Verificado |
| 23 | Algunos NPC hablan («The Locals») y son esenciales para misiones; el cursor se vuelve una boca. En multijugador conviene matarlos. | [DOC MANUAL.PDF «The Locals»] | Verificado |

### Almas

| # | Hecho | Fuente | Estado |
|---|---|---|---|
| 24 | Almas por muerte = `Cre8.souls` del tipo: campesinos 1, Taurock 2. Aparece un alma al terminar la animación de muerte (`spawnSoul`), crece 3 s y luego se puede juntar. | [DATOS creatures.json; SAC sacobject.d:173-176, state.d:8382-8396, 14016, 14982] | Verificado |
| 25 | Solo el mago vivo recoge almas (`canCollectSouls`): a ≤5 m. Las criaturas no recogen. El Sac Doctor las lleva por Convert. | [SAC state.d:14895-14897, 14939-14975; DOC] | Verificado |
| 26 | Color: azul si no tiene lado o es del mismo bando; roja si es de otro bando (las de campesinos son rojas para los dos jugadores). Rojas pegadas al cadáver no se juntan caminando. | [SAC state.d:1612-1630, 14946-14956; DOC «All about souls»] | Verificado |
| 27 | Roja → hay que usar Convert (Sac Doctor se la lleva al altar, resucita la criatura, se suma al contador). | [DOC ReadMe 7.5; MANUAL; SAC state.d:10181-10196, 29538-29550] | Verificado |
| 28 | Gib: destruye el cadáver y da un alma **azul** que cualquier mago toma. Opción «Always gib» y «Gib chance» en el original; sacengine solo implementa `alwaysGib`. | [DOC manual; SAC state.d:8341-8362, 9040-9046, 29383] | Verificado; «Gib chance» sin equivalente en sacengine |
| 29 | Las casas no dan almas. | [SAC state.d:8376-8380] | Verificado en código |
| 30 | Economía: las almas se gastan al convocar (1 o más según criatura) y son **finitas**: «Unlike mana, souls are limited in quantity». No hay regeneración. Existen almas iniciales configurables (`options.d:191` 12 por defecto en sacengine) y un mago pierde su cuenta si cae banished (queda libre). | [WEB https://en.wikipedia.org/wiki/Sacrifice_(video_game); DOC manual «Starting Souls», «Soul advice»; SAC options.d:191] | Verificado |
| 31 | Tope por mago: en el exe, la rutina de depuración «dar almas» llena hasta 32 (`cmp [wizard+0xb44], 0x20`, `32 - actuales`) y avisa «Wizard has too many souls» si ya tiene ≥32. Es el único indicio de un tope; no se probó que el juego normal limite. | [REA bytes en 0x403ea0-0x403f00 (código sin función en Ghidra); strings 0x4c68c4-0x4c68f4] | Parcial: interpretación del compilado, no decompilado |
| 32 | «Cannot enable collecting red souls» / «Wizard can now collect red souls»: orden de depuración que **habilita** recoger rojas; confirma que por defecto no se pueden. | [REA strings 0x4c687c, 0x4c68a0] | Verificado (cadenas) |
| 33 | XP al matar un campesino: 250 estimado (`// estimated from XP bar screenshots`). | [SAC sacobject.d:200] | Estimado, no verificado |
| 34 | Modos de victoria con almas: Soul Harvest (primero en juntar N almas) y Slaughter. | [DOC manual] | Verificado |

### IA original

| # | Hecho | Fuente | Estado |
|---|---|---|---|
| 35 | `shiny.d` (portado del código «thaum» del exe, con direcciones) no tiene ninguna tarea ni mención de campesino, aldea ni refugio. | [SAC bots/shiny.d: grep peasant/shelter/villag/zepe/saep sin resultados] | Verificado (ausencia en sacengine) |
| 36 | La IA rastrea **almas** como nodos (`NodeKind.cre`), con máscara de recogida por bando: puede recoger las propias/sin lado (`pickupMask`) y trata las que no puede tocar como objetivo de Convert (`findBestNear`, `convertSlots`). Por eso sus convertires de almas rojas incluyen las de campesinos muertos. | [SAC shiny.d:2998-3030, 3112, 676] | Verificado en código |
| 37 | La IA no tiene objetivo «matar aldeanos». Las criaturas propias atacan lo que ven (el bando 2 es enemigo), así que los matan y el mago convierte las almas. | [SAC state.d:13732+ patrol; shiny.d] | Inferencia razonable; no verificado en el exe |

### Estado del port (`game/`)

| # | Hecho | Fuente | Estado |
|---|---|---|---|
| 38 | Almas F30 (`SoulSystem`): alma al caer el cadáver, azul/roja, juntar a 5 m, P suelta; Convert F61. La roja pegada al cadáver no se junta. Sin tope ni regeneración. | `game/FEATURES.md` F30, F61 | Verificado (documentado) |
| 39 | `map_props.gd` solo coloca **widgets** (plantas) del NTTS; no carga estructuras ni criaturas. `grep jhut|bld1|epez` en `scenes/`, `tools/`, `data/` sin resultados. No hay campesino, casas, bandos 2/3 ni los 6 Taurock. | `game/scenes/world/map_props.gd`; `rfcs/RFC-024-addendum-poblados.md` §1.4; `rfcs/RFC-018-editable-map.md` | Verificado |
| 40 | Datos de NPC ya en caché (`creatures.json`); mallas `epez`, `peas`, `eber` horneadas. Modelos de casas de James (`jhut`, `bld*`, `jcc*`, `jwg1`) **no** horneados. | RFC-024 addendum §1.4 | Verificado |

## (c) No encontrado o dudoso

- **Wiki de la comunidad** (`sacrifice-shiny.fandom.com`): WebFetch devolvió HTTP 402 y las búsquedas no trajeron una página de peasants/villages. [NO ENCONTRADO] en la wiki. Tampoco GameFAQs (HTTP 403 en el review y en la Boon Guide; el buscador menciona misiones «matar a todos los Peasants» y «no convertir las almas de la aldea», sin poder leerlas).
- Significado confirmado del bit `shelter` (1<<15) en el exe: no decompilado. La correlación con chozas/silos sí está en datos.
- Regla exacta de huida/encogerse (distancias 50 m, 80 m, 100 m) en el exe: no decompilada. Los nombres de estados sí están.
- Qué es `bld*`, `bon*`, `jcc*`, `jeg*` (¿decoración? ¿también refugio?): solo `jhut` y `jwg1` tienen el bit de refugio.
- Qué ocurre exactamente al destruir una choza en el original (`DestroyHut`): no decompilado.
- Tope de almas por mago en juego normal: solo el indicio 31.
- Almas exactas por tipo de NPC en mapas de otros reinos: todos 1 (datos).
- Cuántos habitantes «hablan» y cuáles son misión: solo campaña.
- Capturas del original: no hay evidencia visual.
- XP por matar campesino: estimada.
- Los 6 Taurock: pegan, vida 1920, 2 almas; su rol (guardianes de aldea) no está documentado; solo se sabe que están en el bando 3.

## (d) Consecuencias para el diseño de IA y del port

Datos necesarios y ya disponibles:
- High Noon: 26 Farmer (bando 2), 5 `jhut` + 6 `jwg1` (refugios, bando 31), 6 Taurock (bando 3), con posiciones exactas en (2) High Noon.scp NTTS (script de lectura en `game/tools/export_high_noon_widgets.py`, mismo formato de `ntts.d`). Cada Farmer está a 12-57 m de un refugio, así que casi todos cumplen «refugio a ≤50 m».
- Almas por muerte: Farmer 1, Taurock 2; se juntan por Convert (rojas) o por gib (azul).
- Quién recoge: el **mago** (a ≤5 m) las azules y las sin lado; las rojas, el **Sac Doctor** vía Convert.

Para la IA del port:
1. Los campesinos son un recurso de almas finito por mapa (26 en High Noon, más 12 de los Taurock). Sumarlos a `maxSoulsSeen`/nodos de la IA como fuente de almas rojas.
2. La IA no debería tener una tarea explícita «cazar aldeanos» (no hay evidencia); basta con que sus criaturas ataquen al bando 2 como a cualquier enemigo y que su mago convierta las almas rojas (ya cubierto por `findBestNear`).
3. Los campesinos necesitan bandos 2 y 3 enemigos de todos (hoy cualquier otro `owner_slot` es enemigo), comportamiento pasivo (agresividad 0), encogerse sin refugio a ≤50 m, huir del enemigo a ≤50 m con refugio, rencor y alarma (bits 14 y 15).
4. Cargar estructuras: 11 refugios con vida 5000 y flag refugio; decidir qué pasa al destruir una choza (el original tiene `DestroyHut`, comportamiento sin decompilar).
5. Rendimiento: 32 cuerpos NPC extra; `BodySeparation` ya cuesta ~7 ms/tick con 60 cuerpos.
6. Decisiones pendientes para el usuario: tope de almas (indicio de 32), si se implementa «Gib chance» del original, y si el campesino da XP.

## Cómo se obtuvo la evidencia de REA

- `GHIDRA_INSTALL_DIR=.tools/ghidra_12.1.4_PUBLIC`, `JAVA_HOME` = openjdk@21 de Homebrew (el sistema solo trae JDK 17; Ghidra exige 21+), `GHIDRA_HEADLESS_MAXMEM=3G`, un comando por vez.
- El snapshot existente `.rea-snapshots/sacrifice-exe` dio «evidence_integrity_mismatch» al copiarlo y no sirvió; se analizó de cero con snapshot nuevo en el scratchpad (`snap2.json`), sin tocar el original. Cada comando tarda ~50 s y usa ~1,5 GB.
- Comandos: `search` (1576 cadenas y todos los procedimientos), `xrefs`, `decompile`, `instructions`. Las referencias a `DestroyHut` y `PeasantSetWorkAnimation` no resolvieron por `xrefs` (se registran por tablas de cadenas sin referencias directas); quedó como evidencia de existencia.
