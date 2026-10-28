# 061R — Habilidades del mago, de las criaturas y estructuras: qué hace cada una en el original y qué falta en el port

Investigación de hechos, sin diseño (el diseño es del tech lead). Corrige y completa `055R-original-reference.md` §1–§2.

Fuentes y etiquetas:

- **[SAC archivo:línea]** sacengine (`sacengine/source/`, GPL, solo lectura). Se describe el comportamiento; no se copió código. Si no se dice otra cosa, el archivo es `state.d`.
- **[DATOS]** datos horneados de las WAD originales: `game/data/catalog/spells|abilities|creatures|buildings/*.tres` y el export crudo `game/assets/original/data/*.json` (incluye `amount3`, que el `SpellType` del port no guarda).
- **[DOC]** manual oficial del juego (`MANUAL.PDF` de la instalación GOG, texto extraído con PDFKit).
- **[WEB]** wiki de fans `sacrifice-shiny.fandom.com` (la página devuelve 402 a la descarga directa; los números se tomaron de los extractos del buscador, por eso cuentan como la fuente más débil).
- **[PORT]** código del port (`game/scenes/...`).
- **[REA 0xDIRECCIÓN función]** el ejecutable original (`Sacrifice.exe` de GOG, sha256 `a53ebb53…abcb`, x86 PE, base 0x400000), analizado con REA 6.5.0 sobre Ghidra 12.1.4 (segunda pasada, 2026-10-24). Cómo se lee el exe:
  - La lógica de cada hechizo vive en funciones con nombre propio: una tabla de 272 entradas `{nombre[28], función, hash del nombre}` en **0x4cbba8**, registrada por `FUN_00442460` (por ejemplo `ChainLightningRun` → 0x420220). Los nombres de este informe salen de esa tabla. Las funciones a las que solo llega la tabla no las define el autoanálisis de Ghidra. Por eso se crearon en la dirección de la tabla y se desensamblaron con el mismo Ghidra; las que el análisis sí define se leyeron con `rea instructions` (por ejemplo `FUN_00420010`, `FUN_0042caf0`, `FUN_00428030`, `FUN_004650d0` y `FUN_004651f0`). Las instrucciones sueltas del Halo se confirmaron con `rea inspect-native-instruction`. Las constantes `double` citadas se leyeron de los bytes del exe.
  - El SPEL en memoria es el registro del archivo corrido **+8 bytes**: `amount` +0x4c, `amount2` +0x68, `amount3` +0x6c, `damageRange` +0x44, tipo de daño +0x48, `speed` +0x50 (guardado **por tick**: valor del archivo / 60), `acceleration` +0x54, `duration` +0x58 y `effectRange` +0x5c. Se comprobó con Heal, que cura `[+0x4c]` = 1000, y con Death, que cuenta `[+0x6c]` = 8.
  - El tiempo del juego va en ticks de 60 por segundo: duraciones = `duration × 60` (0x420871) y rampas de `dt / 60`.
  - Tipos de daño (`tipo & 7`, «Illegal damage ID» si es mayor que 4): 0 cuerpo a cuerpo, 1 hechizo directo, 2 hechizo de área, 3 distancia directo, 4 distancia de área (es el orden de las 5 resistencias del CRE8; `FUN_0044d810` reparte salpicadura solo para los tipos 2 y 4).
  - Daño continuo (`vtable+0x78`, `FUN_00454810`): suma `amount × dt` a un acumulador y cada 16 ticks aplica `acumulado / 60` (`FUN_00454870`). Es decir, el `amount` de un daño continuo se mide **por segundo**.
- Regla de precedencia: ejecutable/datos originales > sacengine > manual > web.

Convenciones de las tablas:

- **Nv** = `spell_order / 100` [SAC `sacspell.d:93-102`].
- **Lanz.** = tiempo de lanzamiento en segundos tal como lo hornea el port: `frames / (1,35·60)` [SAC `sacspell.d:93-102`; DATOS `casting_time_s`]. Baja hasta un 50 % con 5 niveles de mago por encima del hechizo.
- **Enfr.** = enfriamiento en s [DATOS `cooldown_s`].
- **Objetivo** sale de `flags` decodificados con `SpelFlags` [SAC `spells.d:168-183`]: `enemigo` = disallowAlly (bit 13); `aliado` = onlyAlly (bit 12); `suelo` = targetGround (bit 14); `no volador` = disallowFlying (bit 16); `manantial` = onlyManafounts (bit 11).
- `amount` es el daño o la cura por golpe; `amount2` es el total y vale `amount × amount3` cuando hay varios golpes [DATOS spells.json].
- Las constantes `enum` citadas están en la `struct` del efecto [SAC 2600-5330].
- Multiplicadores de daño recibido por escudo [SAC 8962-8969]: Life Shield ×0,5, Rockform ×0,05, petrificado ×0,2, **Skin of Stone ×0,25**, **Air Shield ×0,5**, **Protective Swarm ×0,75**. El daño `peirceShield` los ignora. **VERIFICADO REA** para los tres escudos de nivel 2. Skin of Stone usa la constante 0,25 [REA 0x446a79 `StoneDamageInterrupt`]. Air Shield y Protective Swarm multiplican por la `speed` de su SPEL, que en memoria va dividida por 60: 30/60 = 0,5 y 45/60 = 0,75 [REA 0x41f6f1 `AirShieldTargetDamaged`, 0x433095 `PSwarmTargetDamaged`]. Air Shield, además, vuelve a multiplicar por 0,5 el daño a distancia (tipos 3 y 4), así que ese daño entra ×0,25. sacengine no tiene ese segundo factor.
- Efectos de estado [SAC `stats.d:31-99`]: `shielded` = lifeShield, skinOfStone, etherealForm, fireform, protectiveSwarm o airShield. `ccProtected` = shielded, petrificado, congelado, ringsOfFire, slimed o vined. Un cuerpo `ccProtected` no acepta Freeze, Rings of Fire, Slime ni Grasping Vines [SAC 10688, 10728, 10746, 10768].
- Factor de velocidad [SAC `stats.d:121-124`]: Slime 0,2ⁿ en tierra; ranas 0,6ⁿ; Wailing Wall 0,75; Wall of Spikes 0,5; además de los que ya existen en el port (blightmites 0,8ⁿ, sticky bomb 0,75ⁿ y carga de rayo ×1,5).
- Duración de un CC sobre una criatura: `1000 / vida máx × duración` (sobre el mago `0,25 × duración`). Así lo hacen Freeze, Slime, Grasping Vines y Speed Up [SAC 10699, 10756, 10802, 10431].

---

## 1. Resumen ejecutivo

| Bloque | Total en el original | Hecho en el port | Parcial | Falta |
|---|---|---|---|---|
| Hechizos del mago (no criatura) | **53** (2 neutrales + 6 de estructura + 9 × 5 dioses) | **12** (Manalith, Guardian, Convert, Desecrate, Teleport, Speed Up, Heal y el nivel 1 de cada dios) | 0 | **41**: Shrine y los niveles 2 a 8 de los cinco dioses (8 por dios) |
| Habilidades activas de criatura | **19** tags (`useAbility`, SAC 13505-13561) | **19**, en el catálogo `data/abilities/ability_catalog.tres` | — | 0 |
| Pasivas de criatura | **12**: `hmba`, `korq`, `ahtf`, `gcil` (3 criaturas), `rifl`, `goc@`, `cen@`, `tum@`, `eniv` (Dragon), `zerf` (Yeti), la regeneración continua del Troll y las llamas de mano `tdhg`/`tfhg` | 10 | 1 (`tdhg`/`tfhg`: puro visual, NO VERIFICADO en el port) | **1**: regeneración continua del Troll (`continuousRegeneration`, SAC `nttData.d:820`) |
| Ataques a distancia con efecto propio | 30 tags de disparo | 30 (RFC-030, cortes 030h a 030n) | — | 0 |
| Uso de habilidades por la IA | En sacengine solo por orden (13660, 13766); que la IA del mago las pida está NO VERIFICADO | — | — | La IA del port nunca usa habilidades de criatura (RFC-030 §9 lo deja fuera) |
| Estructuras de escaramuza/MP | 4 roles: altar, manantial, Manalith y Shrine (más refugios de aldeanos) | 3 (altar, manantial y Manalith) | Manalith: vida 3000 en el código frente a 5000 del BLDG (el exe usa el BLDG, VERIFICADO REA) | **Shrine** (tiene modelo y datos, pero no tiene acción, maná, sitio de ritual ni papel de destino de Convert) |

Conclusión: lo que falta es **casi todo el libro del mago a partir del nivel 2 (40 hechizos) más el Shrine**. El bestiario está completo salvo por un detalle pasivo del Troll y por la IA.

---

## 2. Hechizos del mago (los 53)

Estado: «hecho» = acción en `scenes/wizards/wizard_body.tscn:187-233` (`Caster/Actions`). «Falta» = sin `SpellAction`: el `Caster` lo rechaza con «no implementado» [PORT `scenes/spells/caster.gd`]. Los 53 tienen su `SpellType` en `data/catalog/spells/<tag>.tres` [DATOS]. Las funciones `cast*` se despachan en SAC 9925-10070.

### 2.1 Neutrales y estructura (todos los dioses)

| Tag | Hechizo | Nv | Maná | Lanz./Enfr. | Objetivo | Qué hace (números verificados) | Fuentes | Port |
|---|---|---|---|---|---|---|---|---|
| htlm | Manalith | 1 | 800 | 11,1/10 | estructura sobre manantial (2064) | Construye la torre del dios sobre un manantial libre. Vida 5000 y regeneración de 83,3/s (se llena en 60 s) (ver §4). Da 33,3 de maná/s a 50 m al bando y sus aliados; los Manahoar lo usan a distancia. **VERIFICADO REA** (vida, maná, radio y regeneración, §4) | SAC 10066-10076, `sacobject.d:1004-1008`, 28581-28588; DATOS `buildings/_mana.tres`; [DOC] p. 48; [REA 0x465200 `FUN_004651f0`, 0x465910] | hecho, `spells/actions/manalith_action.gd` (vida 3000: ver §6) |
| pups | Speed Up | 1 | 300 | 0,74/1 | aliado | ×1,75, que vuelve a ×1 en el último segundo. En una criatura dura 30·1000/vida + 0,5 s; en el mago, 30·0,2 + 0,5 s | SAC 10419-10436 | hecho, `actions/pups_action.tscn`, `spells/speedup_effect.gd` |
| laeh | Heal | 1 | 300 | 0,37/1 | aliado | Cura 1000 a 240 vida/s; dos Heal suman tiempo y se quedan con la tasa más alta | SAC 10443-10458 | hecho, `actions/heal_action.tscn`, `spells/heal_effect.gd` |
| ndrg | Guardian | 1 | 300 | 1,1/2 | criatura propia, no héroe | Ata la criatura a un altar, Manalith o Shrine propio: daño ×1,5, cura 1000/min, recibe ×0,5 del daño de hechizo y ×0,25 del de distancia, pierde la habilidad activa y recibe el daño del edificio | SAC 10366-10416, 8884, 9006-9009, 14411, 1414; [DOC] p. 52 | hecho, `actions/guardian_action.gd`, `spells/guardian/` |
| ccas | Convert | 1 | 800 | 2,2/2 | alma enemiga | Los Sac Doctors llevan el alma al **Shrine o altar propio más cercano** (`closestShrine`); sin ninguno, el hechizo no se puede lanzar | SAC 10181-10198, 28050-28130, 29563 | hecho, `actions/convert_action.gd`, `scenes/sacrifice/` (solo altares) |
| ucas | Desecrate | 1 | 1000 | 5,6/5 | criatura propia | Los Sac Doctors llevan una criatura propia al altar enemigo (≤75 m) | SAC 10200 y siguientes, 28084 | hecho, `actions/desecrate_action.gd` |
| elet | Teleport | 1 | 800 | 1,2/15 | estructura propia (4112) | Lleva al mago a una estructura propia a cualquier distancia | SAC 10230-10290 | hecho, `actions/teleport_action.gd` (sin Shrine) |
| pcas | **Shrine** | **3** | 800 | 11,1/10 | estructura sobre manantial (2064) | Mismo camino que Manalith (`StructureCasting`, modelos `pcsh/pasp/jsac/stsp/casp`). Vida 5000, regeneración de 83,3/s; da **8,33 de maná/s** (¼ del Manalith y ½ del altar) a 50 m al bando y sus aliados. **VERIFICADO REA** (§4). Sirve de destino de Convert y de ritual, y admite Guardian | SAC 10066-10076, 28592-28594, 28063-28066, 10379; DATOS `buildings/_pcsh.tres`; [REA 0x4650d0, 0x465910, 0x4651f0] | **falta** (modelo y `SpellType`; el `RitualSite.Kind.SHRINE` existe sin uso, `map/props/ritual_site.gd:9`) |

### 2.2 Persephone

| Tag | Hechizo | Nv | Maná | Lanz./Enfr. | Objetivo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|---|---|---|
| oalf | Wrath | 1 | 300 | 0,74/10 | enemigo | Proyectil guiado: 550 de daño y salpicadura de 5 m | SAC 10493 y siguientes, 16392-16580 | hecho, `actions/wrath_action.tscn` |
| mrfe | Ethereal Form | 2 | 400 | 0,99/30 | self | 15 s: el mago **no puede recibir daño** (`canDamage` falso), queda translúcido (alfa 0,36) y entra y sale en 30 cuadros. Se corta si el mago no puede «llevar escudo» | SAC 10606-10620, 8918, 17143-17185; [DOC] el maná se puede drenar | **falta** (alfa reutilizable de `abilities/stealth.tscn`) |
| eniv | Grasping Vines | 3 | 500 | 1,2/20 | enemigo no volador | Clava al blanco al suelo durante 40·1000/vida s (sobre un mago, 10 s). Le bloquea la regeneración y lo deja ccProtected | SAC 10766-10812, 17852-17876 | **falta** como hechizo; el estado ya existe: `units/afflictions/vined.gd` (pasiva del Dragon) |
| wobr | Rainbow | 4 | 300 | 0,37/10 | aliado | Arco de cura que salta de aliado en aliado. **VERIFICADO REA:** son **6 golpes** (el inicial y 5 saltos). El tope es la constante 6 del código: el exe no lee `amount3`. Antes del golpe n (0 a 5) busca el siguiente blanco a (6−n)/6 × `effectRange`: 50 m, 41,7 m, … 8,3 m. **Cada golpe cura toda la vida máxima del blanco**, con el mismo mecanismo de cura en el tiempo que Heal y a su misma tasa. No usa el `amount` 600 (sacengine: 600 por golpe) | SAC 10832-10842, 18129-18157, 3136; [REA 0x42cb39 `FUN_0042caf0` (`cmp 6`), 0x42cc8d `FUN_0042cc70` (radio), 0x42cdea `FUN_0042cdb0` (cura `[blanco+0x8fe]` = vida máx.)] | **falta** |
| grfr | Rain of Frogs | 5 | 1000 | 2,5/50 | suelo | Nube a 90 m de altura que suelta 10 ranas/s durante 20 s en un radio de 50 m. Cada rana salta hasta 8 veces hacia criaturas; si se pega, frena ×0,6 por rana y a los 5 s explota: 90 de daño más salpicadura de 5 m | SAC 11025-11033, 19367-19505, `stats.d:122` | **falta** |
| ruah | Healing Aura | 6 | 1200 | 3,0/40 | aliado | La lleva un aliado durante 20 s. Él y los de su bando a ≤30 m se curan a 60 vida/s (temporizador de 256 cuadros que se renueva) | SAC 11076-11094, 19681-19737 | **falta** |
| lawv | Vinewall | 7 | 1500 | 3,7/80 | suelo, no volador | Muro perpendicular a la línea mago→clic que crece hasta 55 m por lado en 4 s (se corta en edificios y en el vacío). Mide 7,5 m de alto y 5 de espesor y dura 50 s. Al enemigo que cruza (≤35 % del espesor) le aplica Grasping Vines con lo que quede de duración; enfriamiento de 6 s por blanco | SAC 11156-11169, 20370-20470, struct 3790 | **falta** |
| mrhc | Charm | 8 | 1800 | 5,2/240 | criatura enemiga | Espíritus vuelan al blanco y, tras 5 s, la criatura **cambia de bando para siempre** y vuelve al mago. No sirve contra magos; las neutrales dependen de `charmNeutralCreatures` | SAC 11265-11330, 21915-21935, 21953-22022 | **falta** |
| rter | Meanstalks | 8 | 1800 | 4,4/240 | suelo | 4 tallos (`amount3`=4) en un anillo de 9 a 21,6 m alrededor del punto, durante 60 s. Cada uno agarra, daña 500 por golpe y lanza (catapult) | SAC 11441-11468, 22574-22706 | **falta** |

### 2.3 Pyro

| Tag | Hechizo | Nv | Maná | Lanz./Enfr. | Objetivo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|---|---|---|
| brif | Fireball | 1 | 300 | 0,74/10 | enemigo | Bola guiada: 625 de daño y salpicadura de 10 m | SAC 10519, 16584-16706 | hecho, `actions/fireball_action.tscn` |
| mrff | Fireform | 2 | 400 | 0,99/45 | self | 40 s: quema a todo no aliado cuya caja toque la del mago (+2 m) a 250/s (`ignite`, peirceShield). **No reduce el daño** recibido. **VERIFICADO REA el daño:** continuo de `amount` = 250/s con el tipo del SPEL, a los que pasan el filtro de bando (`vtable+0x6c`). El alcance que mide el exe es `effectRange` = 5 m entre las cajas (`FUN_004027c0`); sacengine usa +2 m | SAC 10621-10641, 17254-17295; [WEB] «no damage protection»; [REA `FireformRun` → `FUN_00427350` → 0x42732e `FUN_004272c0`] | **falta** (aura parecida: `units/passives/fire_shield.gd`, `rifl`) |
| rapf | Rings of Fire | 3 | 500 | 1,2/10 | enemigo | 10 s de fuego sobre el blanco a 95/s, que ignora escudos. El blanco queda ccProtected y sin regeneración | SAC 10726-10742, 17687-17704 | **falta** (fuego: `units/status/burning.gd`) |
| rifd | Dragonfire | 4 | 800 | 2,3/40 | enemigo | Dragón de fuego guiado (18 m/s) que encadena hasta 5 blancos a ≤50 m. Explota con 700 de daño y salpicadura de 5 m, prende fuego y quema a 175/s lo que atraviesa | SAC 10926-10939, 18737-18871, 3359 | **falta** |
| pxef | Explosion | 5 | 1000 | 2,0/30 | suelo | 5 explosiones (una en el punto y 4 al azar a ≤20 m) que estallan 3,8 s después de lanzar. Cada una hace 600 de daño en 10 m y prende fuego; lanza a todos a 5-20 m/s según la distancia | SAC 10960-11013, 19037-19064 | **falta** |
| lwrf | Firewall | 6 | 1200 | 3,0/50 | suelo, no volador | Muro como el de Vinewall: 55 m por lado, 7,5 m de alto, 5 de espesor, 30 s. Daña a quien esté dentro. **Corregido con REA:** daño continuo de **`amount` (625) por segundo × una rampa del muro**. La rampa sube de 0 a 1 en 3 s (`dt/180` por tick) desde que el muro termina de levantarse y es una sola para todo el muro, no por blanco. En el exe no existe el 1200/s fijo de sacengine con su 400/800 por blanco. El tipo de daño es el del SPEL (`[+0x48]`) y el ally-filter es el normal del daño | SAC 11118-11135, 20000-20090; [REA 0x428053 `FUN_00428030` (`amount × [muro+0x60]`), 0x42845f `FireWallRun` (rampa `[+0x48] += dt·1/180`, tope 1)] | **falta** |
| rifr | Rain of Fire | 7 | 1500 | 3,7/70 | suelo | Nube a 90 m que suelta 3 gotas/s durante 20 s en un radio de 50 m: 500 de daño directo, salpicadura de 5 m y fuego | SAC 11045-11053, 21099-21155 | **falta** |
| egar | Blind Rage | 8 | 1800 | 4,4/80 | criatura enemiga | Un puño vuela al blanco y, al llegar, todas las criaturas no-mago en 30 m quedan 30 s fuera de control: sin orden, sin disparo (`rangedAttack` nulo) y **atacan a la criatura más cercana de cualquier bando** | SAC 11235-11258, 21562-21622, 1143-1155, 1390-1393, 12946-12948 | **falta** |
| clov | Volcano | 8 | 1800 | 4,4/360 | suelo | Levanta un volcán durante 60 s: 1000/s con caída lineal de 20 a 50 m, empuja y prende fuego; arroja bolas de lava (1000 en 10 m). **Deforma el terreno de forma permanente** (ver 055R §3) | SAC 11364-11376, 22328-22500, 4307-4370 | **falta** |

### 2.4 James

| Tag | Hechizo | Nv | Maná | Lanz./Enfr. | Objetivo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|---|---|---|
| kcor | Rock | 1 | 300 | 0,74/8 | enemigo | Roca lanzada: 650 de daño | SAC 10548, 16712-16855 | hecho, `actions/rock_action.tscn` |
| niks | Skin of Stone | 2 | 400 | 0,99/110 | self | 80 s: el daño recibido baja a ×0,25 (VERIFICADO REA) | SAC 10591-10604, 17074-17105, 8966; [WEB] 75 %; [REA 0x446a79 `StoneDamageInterrupt`] | **falta** (factor de daño: patrón de `units/passives/life_shield.gd`) |
| pmcd | Soul Mole | 3 | 50 | 0,37/1 | alma (4098) | Un topo tarda 4,5 s en llegar al alma, la suelta de su cuerpo (`severSoul`, `preferredSide` = mago) y en 4,5 s más la arrastra hasta el mago. **Aturde** a todo lo que pasa a ≤10 m (no hace daño: amount 0) | SAC 10814-10830, 17925-18044 | **falta** |
| tpre | Erupt | 4 | 800 | 1,1/30 | suelo | El suelo sube 15 m en un radio de 50 m durante 4,2 s y cae en 0,15 s: 600 de daño en 15 m y lanza a lo que está a ≤42,5 m. Luego una onda de 90 m en 1 s aturde entre 50 y 75 m. **Deformación temporal** | SAC 10905-10912, 18361-18525, struct 3223-3289 | **falta** (onda visual: `abilities/quake_wave.gd`) |
| olah | Halo of Earth | 5 | 1000 | 2,5/40 | self | Rocas orbitan al mago durante 35 s y cada una se lanza contra el enemigo más cercano a ≤50 m (`effectRange`): 600 de daño. **VERIFICADO REA: 6 rocas.** Salen escalonadas mientras crece el hechizo, `ftol((progreso + 0,1) × 6,0)` con el progreso de 0 a 1. Es una constante: el exe no lee `amount3` (5) | SAC 11015-11023, 19102-19321, 3455; [REA 0x4459a2 `HaloOfEarthRun` (constantes 0,1 en 0x4bfb40 y 6,0 en 0x4bfdd8), roca `HaloRockRun` 0x445590] | **falta** como hechizo del mago; la versión de criatura (`HRba`, Rhinok) existe: `abilities/halo_of_earth.gd` |
| laws | Wall of Spikes | 6 | 1200 | 3,0/50 | suelo, no volador | Muro de pinchos: 55 m por lado, 5 m de alto, 5 de espesor, 40 s. Al que cruza: aturdido, 625 de daño y ×0,5 de velocidad durante 6 s. Sin filtro de bando en el muro; el daño sí aplica el filtro normal | SAC 11175-11188, 20540-20670 | **falta** (pinchos visuales: `fx/spike_field.gd`, `impacts/spike_wave.gd`) |
| rtem | Bombardment | 7 | 1500 | 4,0/70 | suelo | Durante 20 s caen 2 meteoritos/s (12 s de caída) en un radio de 50 m: 400 de daño, salpicadura de 5 m, aturdimiento y sacudida de pantalla. Cada uno deja una **abolladura permanente** de 15 m × 1,2 m | SAC 11055-11063, 21216-21420, 4077-4083 | **falta** |
| ivob | Bovine Intervention | 8 | 1800 | 4,4/80 | criatura enemiga | Una vaca sale del suelo a 15 m delante del mago y cae en 12 s sobre el blanco: lo **gibea** (muerte instantánea; el alma queda) si `canBovinelyIntervene`, y luego revienta con escombros | SAC 11263-11309, 21749-21820, 8341-8355 | **falta** |
| erob | Bore | 8 | 1800 | 4,4/360 | suelo | Un taladro recorre una espiral (radio de 5 a 50 m). A los 10 s abre agujeros reales, quitando vértices; los que caen se gibean. Pasados 3 s repone un vértice cada 0,5 s | SAC 10914-10924, 18593-18705, 3298-3334 | **falta** |

### 2.5 Stratos

| Tag | Hechizo | Nv | Maná | Lanz./Enfr. | Objetivo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|---|---|---|
| ntil | Lightning | 1 | 200 | 0,37/3 | enemigo | Rayo: 750 de daño | SAC 10464-10491 | hecho, `actions/lightning_action.tscn` |
| dlhs | Air Shield | 2 | 400 | 0,74/70 | self | 60 s: el daño recibido baja a ×0,5 (`speed` 30/60), **y a ×0,25 el daño a distancia** (tipos 3 y 4: el exe aplica ×0,5 una vez más; sacengine no lo hace). Aparta a los no propios a ≤5 m (½·`effectRange`) con fuerza 20 | SAC 10663-10686, 17458-17525, 8967; [REA 0x41f6e0 `AirShieldTargetDamaged`] | **falta** (empuje: `impacts/push_impact.gd`, `body_nudge.gd`) |
| zerf | Freeze | 3 | 400 | 0,74/20 | enemigo | Congela durante 20·1000/vida s (sobre un mago, 5 s). Al deshelarse hace 150 de daño | SAC 10687-10724, 17579-17614 | **falta** como hechizo; el estado existe: `units/afflictions/frozen.gd` (Yeti, Silverback) |
| ntlc | Chain Lightning | 4 | 800 | 2,0/30 | enemigo | Rayo que salta al no aliado más cercano. **VERIFICADO REA: 7 golpes** (el inicial y 6 saltos) de `amount` = 600 cada uno, con salpicadura `damageRange`. Cada golpe daña antes de mirar el contador. Corta cuando el contador llega a 6 (constante del código): el exe no lee `amount3` (5). Antes del salto n (0 a 5) busca a (6−n)/6 × `effectRange`: 50 m, 41,7 m, … 8,3 m. Si no hay blanco, cae en un punto al azar | SAC 10844-10857, 18270-18294, 3185; [REA 0x42001f `FUN_00420010` (`cmp 6`), 0x42008a `FUN_00420070` (radio `(6−n)·r/6`), 0x4201c0 → 0x435a60 (daño `amount × 1,0`)] | **falta** (rayo: `abilities/lightning_strike.gd`) |
| dnws | Soul Wind | 5 | 500 | 0,49/2 | alma (4098) | Como Soul Mole, pero en el aire: va al alma y la trae (ida y vuelta de 9 s). Por el camino aturde y hace 400 de daño a cada no aliado a ≤30 m (una vez por blanco) | SAC 10941-10958, 18999-19018 | **falta** |
| zorf | Frozen Ground | 6 | 1200 | 1,5/30 | suelo | Una bola de nieve cae en el punto. En 0,5 s **congela** (con los datos de Freeze) a todo lo que está en tierra a ≤15 m; a los 30 s el hielo se rompe en 6 anillos y hace 800 a quien siga encima | SAC 11103-11116, 19831-19900 | **falta** |
| cnef | Fence | 7 | 1400 | 2,5/60 | suelo, no volador | Hasta 12 postes en línea (55 m por lado), durante 35 s. Cada poste tira rayos de 625 a cada criatura a ≤10 m con probabilidad de 0,9/s; hay arcos entre postes y descargas al suelo | SAC 11194-11208, 20755-20895 | **falta** |
| likc | Cloudkill | 8 | 1600 | 4,0/60 | suelo/blanco | **VERIFICADO REA:** nube de tormenta que **persigue al blanco**. Apunta a la posición del blanco + **22 m** de altura (sacengine dice 25) y se mueve con `speed` 3 m/s y `acceleration` 0,3. Dura `duration × 60` ticks (30 s). En cada actualización suelta un rayo con probabilidad (dt+1)/60, **≈ 2 rayos/s** a un tick por actualización (sacengine: 5/3). El rayo cae dentro de `effectRange` (50 m) y hace `amount` = 900 con salpicadura de `damageRange` = 5 m. **No es veneno** (055R lo llamaba «nube venenosa») | SAC 11331-11339, 22074-22108; [REA 0x420b4b `CloudKillRun` (`rand()%60 ≤ dt`), 0x420850 (duración ×60 en 0x420871), 0x4206f0 (altura 22,0 en 0x4bfa20), 0x4207c0, `CloudKillBoltRun` 0x420600 → 0x435a60] | **falta** |
| nrot | Tornado | 8 | 1800 | 3,7/360 | suelo | Tornado de 25 s que vaga dentro de 50 m de su punto (6 m/s) y levanta y lanza (catapult) a lo que está a ≤30 m de su eje. No tiene daño directo: el daño es el de la caída | SAC 11470-11500, 22760-22885 | **falta** |

### 2.6 Charnel

| Tag | Hechizo | Nv | Maná | Lanz./Enfr. | Objetivo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|---|---|---|
| mrws | Insect Swarm | 1 | 300 | 0,74/10 | enemigo | Enjambre guiado: 550-600 de daño | SAC 10576, 16866-17033 | hecho, `actions/swarm_action.tscn` |
| rwsp | Protective Swarm | 2 | 400 | 0,99/50 | self | 40 s: el daño recibido baja a ×0,75 (`speed` 45/60, VERIFICADO REA). Pica a los no aliados a ≤4 m de la caja a 75/s y el mago **se cura el 50 %** de lo que inflige | SAC 10643-10661, 17376-17430, 8968; [REA 0x433095 `PSwarmTargetDamaged`] | **falta** |
| htel | Slime | 3 | 500 | 1,2/30 | enemigo | Durante 30·1000/vida s (sobre un mago, 7,5 s): velocidad en tierra 0,2ⁿ, ataques y disparos 5ⁿ veces más lentos, precisión 0,2ⁿ, +0,2 de resistencia por capa y sin regeneración | SAC 10744-10764, 17766-17786, 1381-1383, 9237, 8950, `stats.d:84,122` | **falta** (velocidad: `status/pace_factors.gd`) |
| deda | Animate Dead | 4 | 300 | 0,37/1 | alma propia (4098) | Revive al instante la criatura de esa alma con `revive` (sin `fast`), en su `reviveTime` | SAC 10859-10903, 18335-18352 | **falta** (resurrección: `abilities/fast_revive.gd`, Dragon) |
| tfir | Demonic Rift | 5 | 1000 | 2,5/40 | sale del mago | Grieta en la posición del mago que suelta hasta 24 espíritus (uno cada 1/3 s). Cada uno busca al enemigo más cercano a ≤75 m y le hace 500. Se cierra cuando se acaban los espíritus | SAC 11065-11074, 19507-19646 | **falta** |
| laww | Wailing Wall | 6 | 1200 | 2,0/70 | suelo, no volador | Muro como los anteriores: 6 m de alto, 60 s. Al que lo cruza le **drena todo el maná** (maxMana/s) y le pone un espíritu durante 8 s que lo frena a ×0,75. Sin filtro de bando en el código | SAC 11137-11154, 20126-20312, `stats.d:122`; [DOC] «saps the life and mana» | **falta** |
| galp | Plague | 7 | 1500 | 3,7/70 | suelo | Nube a 90 m que suelta 3 gotas/s durante 20 s en un radio de 50 m. Cada gota envenena 62,5/s durante 10 s, de forma **contagiosa**, al tocado y menos a los que están a ≤5 m | SAC 11035-11043, 20941-21015, 11601-11609 | **falta** (veneno contagioso: `status/poisoning.gd`) |
| pavi | Intestinal Vaporization | 8 | 1800 | 4,4/80 | criatura enemiga | Proyectil (30 m/s). Al llegar, el blanco se infla 5 s, aturdido, y luego se **gibea** (el alma queda) | SAC 11217-11233, 21444-21490; [WEB] deja almas azules | **falta** |
| taed | Death | 8 | 1800 | 4,4/420 | suelo/blanco | Aparece una Muerte (2 s) que camina a 18 m/s hacia la **criatura más cercana, de cualquier bando, salvo magos** y la mata al instante. Hasta **8** muertes (`maxNumTargets`, `amount3`=8; **VERIFICADO REA**: el exe toma el contador de `[SPEL+0x6c]` = `amount3` y lo baja en 1 por muerte) o 40 s | SAC 11347-11362, 22153-22275, 4299-4330; [WEB] «ocho veces más»; [REA `DeathSpellRun` 0x4300a0] | **falta** (solo nombrado en `ai/brains/ai_spell_eval.gd:67`) |

Faltan **41**: Shrine; Persephone 8 (Ethereal Form, Grasping Vines, Rainbow, Rain of Frogs, Healing Aura, Vinewall, Charm, Meanstalks); Pyro 8 (Fireform, Rings of Fire, Dragonfire, Explosion, Firewall, Rain of Fire, Blind Rage, Volcano); James 8 (Skin of Stone, Soul Mole, Erupt, Halo of Earth, Wall of Spikes, Bombardment, Bovine Intervention, Bore); Stratos 8 (Air Shield, Freeze, Chain Lightning, Soul Wind, Frozen Ground, Fence, Cloudkill, Tornado); Charnel 8 (Protective Swarm, Slime, Animate Dead, Demonic Rift, Wailing Wall, Plague, Intestinal Vaporization, Death). Coincide con la lista de 055R §1.4.

---

## 3. Habilidades de criaturas

Lista por dios y nivel según SAC `nttData.d:1245-1250` y `state.d:2138-2172` (nivel 1: tres criaturas; niveles 2 a 7: una por nivel; nivel 9: la última). Números de `data/catalog/abilities/<tag>.tres` [DATOS]. Estado según el cierre de RFC-030 (2026-10-17) y el código citado. «Disparo» = ataque a distancia con efecto propio (RFC-030, cortes 030h a 030n, todos hechos). Las 19 activas son las del `switch` de `useAbility` [SAC 13505-13561]; en el port, `data/abilities/ability_catalog.tres` tiene las 19 y `active_ability.gd` responde «No implementado» solo para un tag sin escena.

### 3.1 Neutrales y fuera del libro

| Criatura | Habilidad | Tipo | Qué hace (números) | Fuentes | Port |
|---|---|---|---|---|---|
| Manahoar (oham) | Manahoar channelling `hmba` | pasiva | Toma maná de cada Manalith aliado a distancia: `max(0, min(0,4·d, 20/950·(1000−d)))` por Manalith, y lo da en un radio de 40 m | SAC 28595-28609; DATOS `hmba.tres` | hecho, `units/unit_mana_support.gd` |
| Sac Doctor (dcas) | regeneración continua | pasiva | Se regenera en cualquier modo | SAC `nttData.d:690-693`, 1428-1434 | hecho, `sacrifice/doctor_body.gd:297` |
| Familiar (imaf), Zyzyx (tnem), Ghost (tshg) | `tsg@` (Zyzyx, Ghost) | — | Fuera de los libros (campaña). `tsg@` no figura en `SpellTag`: rol **NO VERIFICADO** | SAC `nttData.d:1015-1018`; DATOS | fuera de alcance (campaña) |

### 3.2 Persephone

| Criatura (Nv) | Habilidad | Tipo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|
| Druid nmuh (1) | Life Shield `hsba` | activa | 50 de maná, 20 s de enfriamiento: escudo de 20 s con daño ×0,5 que cuenta como `shielded` | SAC 13092-13100, 25122, 8963 | hecho, `abilities/life_shield_ability.tscn`, `passives/life_shield.gd` |
| Ranger amuh (1) | Divine Sight `eesd`; disparo `wobf` (120) | activa | Ojo volador durante 30 s que ilumina 75 m y sigue al enemigo más cercano a ≤250 m | SAC 13102-13109, 25161-25214 | hecho (F165), `abilities/divine_sight.gd` |
| Shrike tbsh (1) | Life Shield `hsba`; disparo `absh` (150) | activa | Igual que el del Druid | SAC 13092 | hecho |
| Scarab cara (2) | disparo «Healing web» `slba` (150) | disparo | Cura a los de su bando en 5 m y elige al aliado más herido | SAC 11616, 23609-23627 | hecho (030h2) |
| Troll lort (3) | **regeneración continua** | pasiva | Regenera 29,2/s **también al moverse, pelear o recibir golpes** (`continuousRegeneration`); el resto solo lo hace quieto o encogido | SAC `nttData.d:817-821`, 1428-1434; [DOC] «regenerate life extremely quickly» | **falta**: `unit_body.gd` regenera solo en Idle, Cower, Rockform y Play Dead (`states/idle_state.gd:20`) y no tiene caso para el Troll |
| Gnome plfl (4) | disparo `plfa` (600) | disparo | Rayo | SAC 11724 | hecho (030m) |
| Gremlin lrps (5) | Web pull `psla` | activa | 60 de maná: arrastra al blanco hasta él | SAC 13176, 25434-25519 | hecho, `abilities/web_pull.tscn` |
| Mutant cbab (6) | disparo `babt` (425, 10 m); al morir `tum@` | pasiva | Healing Shower: cura toda la vida a los de su bando a ≤30 m | SAC 13603, 25674-25697 | hecho (030g, 030h) |
| Ent mtsl (7) | Protector `HSba` | activa | 300 de maná: Life Shield de 20 s para sí y sus aliados a ≤30 m | SAC 13196-13202, 25698-25713 | hecho, `abilities/protector.gd` |
| Dragon grdg (9) | Breath of life `filb`; al golpear `eniv`; al morir `tum@` | activa y pasivas | Revive rápido un cadáver aliado; sus golpes enredan (Grasping Vines) | SAC 13238-13248, 25943-25975, 14421-14432 | hecho, `abilities/breath_of_life*.gd`, `afflictions/vined.gd` |

### 3.3 Pyro

| Criatura (Nv) | Habilidad | Tipo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|
| Cog zidf (1) | al morir `goc@` Steam Cloud | pasiva | Nube de vapor: 300 de daño en 10 m durante 2 s | SAC 13595, 25216 | hecho (030g), `death_clouds/steam_cloud.gd` |
| Flame Minion fplk (1) | Run Away `!nur`; disparo `fkba` (160) | activa | 50 de maná: velocidad ×1,75 durante 10 s | SAC 13048 | hecho, `abilities/run_away.tscn` |
| Spitfire sohf (1) | disparo `fhba` (150) | disparo | Manguera de fuego | SAC 11533, 23026 | hecho |
| Tickferno craf (2) | disparo `sfba` (237) | disparo | Rayo de calor | SAC 11648 | hecho (030l) |
| Firefist lrtf (3) | `ahtf` | pasiva | Daño cuerpo a cuerpo × (1 + 1,5 × (1 − vida relativa)) | SAC 8886-8890 | hecho, `passives/damage_passive.gd` |
| Pyromaniac plff (4) | disparo `lffa` (960) | disparo | Cohete | SAC 11700, 24290 | hecho (030l) |
| Pyrodactyl kacf (5) | Viscous Oil `kcfa` | activa | 60 de maná: aceite que ciega y vuelve inflamable; prendido, hace 500 | SAC 13189, 25588-25672 | hecho, `abilities/viscous_oil.tscn` |
| Bombard wlcf (6) | disparo `cfba` (575, 10 m) | disparo | Lob | SAC 11770 | hecho (030l) |
| Warmonger nugf (7) | Firewalk `wfhg`; disparo `fhga`; llama `tfhg` | activa | 250 de maná: se vuelve fuego y viaja a un punto (≤200 m) quemando lo que pisa | SAC 13213-13217, 25761-25850 | hecho (030o), `abilities/firewalk.gd`; la llama `tfhg` (`warmongerFlame`, 13832) es visual: NO VERIFICADO en el port |
| Phoenix grdr (9) | disparo `rdra` (800); `rifl` Phoenix Shield; al morir `goc@` | pasiva | Quema a quien toque su caja ×1,5 | SAC 13899-13919 | hecho (F163), `passives/fire_shield.gd` |

### 3.4 James

| Criatura (Nv) | Habilidad | Tipo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|
| Trogg ycro (1) | — | — | Cuerpo a cuerpo | — | hecho |
| Earthfling palk (1) | Rockform `dihk`; disparo `ekba` (120) | activa | Se hace roca: daño ×0,05 mientras dura | SAC 13052, 25040, 8964 | hecho, `abilities/rockform.gd` |
| Gargoyle sohe (1) | disparo `ehba` (125) | disparo | — | SAC 11540 | hecho |
| Basilisk guls (2) | disparo `dpsf` (150) | disparo | Petrifica (daño ×0,2, inmóvil) | SAC 11623, 23686-23775 | hecho (030i-b) |
| Taurock raeb (3) | `korq` | pasiva | Daño recibido × (0,25 + 0,75 × vida relativa) | SAC 9010-9016; DATOS `passives/korq.tres` | hecho, `passives/damage_passive.gd` |
| Flummox wlce (4) | disparo `crba` (350, 8 m) | disparo | Lob que aturde | SAC 11690, 24092 | hecho (030h, 030i) |
| Ikarus kace (5) | Sticky bomb `acia` | activa | 60 de maná: hasta 10 bombas (`amount3`), velocidad ×0,75ⁿ | SAC 13179, 25531-25586 | hecho, `abilities/sticky_bomb.tscn` |
| Boulderdash llab (6) | disparo `emba` (500 × 3) | disparo | — | SAC 11794, 24676-24758 | hecho (030n) |
| Jabberocky mtse (7) | Quake `kauq` | activa | 300 de maná: onda de 50 m que lanza y aturde | SAC 13204-13207, 25716-25759 | hecho, `abilities/quake.gd` |
| Rhinok gard (9) | Halo of Earth `HRba`; disparo `hrba` (anillos de pinchos) | activa | 650 de maná: rocas en órbita durante 35 s que van a enemigos a ≤50 m (600 cada una; sacengine 6 rocas, `amount3`=5. En el hechizo del mago el exe usa 6 como constante, VERIFICADO REA; para el Rhinok, NO VERIFICADO: ver §6 fila 5) | SAC 13232-13236, 19284-19321, 24942-25037 | hecho (030p), `abilities/halo_of_earth.gd`, `impacts/spike_wave.gd` |

### 3.5 Stratos

| Criatura (Nv) | Habilidad | Tipo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|
| Frostwolf lbog (1) | Run Away `!nur` | activa | ×1,75 durante 10 s | SAC 13048 | hecho |
| Sylph ahcr (1) | Stealth `ivni`; disparo `aaba` (120) | activa | Casi invisible (alfa 0,06), no ataca | SAC 13083, 25078 | hecho, `abilities/stealth.tscn` |
| Brainiac bobs (1) | disparo `bsba` (200) | disparo | — | SAC 11513 | hecho |
| Vortick craa (2) | disparo `cita` (150) | disparo | Vórtice que lanza | SAC 11655, 23922 | hecho (030j), `impacts/vortex.gd` |
| Squall alab (3) | disparo `amba` (520) | disparo | Empuja 15 m | SAC 11670, 24017 | hecho (030j), `impacts/pushback.gd` |
| Storm Giant rgos (4) | Call lightning `gsba`; `gcil` | activa y pasiva | Rayo del cielo sobre sí mismo (750); la carga de rayo da ×1,5 a la velocidad y al cuerpo a cuerpo | SAC 13121-13129, 25342-25399, 8885, `stats.d:122` | hecho (030s), `abilities/call_lightning.gd`, `passives/lightning_charge.gd` |
| Seraph grps (5) | Cage pull `psaa` | activa | Como Web pull | SAC 13177 | hecho, `abilities/cage_pull.tscn` |
| Flurry wlca (6) | disparo `caba` (400) | disparo | Implosión que lanza | SAC 11781, 24579-24670 | hecho (030j) |
| Yeti ycrp (7) | `zerf` al golpear | pasiva | Congela al golpear, con enfriamiento de 10 s | SAC 14421-14432, 10709-10724 | hecho (030u), `attacks/freeze_touch.gd` |
| Silverback grdb (9) | disparo `rdba` (Icy Breath, congela); Run Away `!nur`; `gcil` | activa y pasiva | Según los datos, también tiene Lightning Charge (`gcil` como pasiva al recibir daño). La tabla de RFC-030 §3 no la lista | DATOS `creatures/grdb.tres` | disparo y Run Away: hecho. `gcil`: el componente es genérico por tag (`passives/lightning_charge.gd:39`), pero **NO VERIFICADO** en partida para el Silverback |

### 3.6 Charnel

| Criatura (Nv) | Habilidad | Tipo | Qué hace | Fuentes | Port |
|---|---|---|---|---|---|
| Scythe dzid (1) | — | — | Cuerpo a cuerpo | — | hecho |
| Fallen dplk (1) | Play Dead `dedp`; disparo `dkba` (125) | activa | Se hace el muerto y regenera 30/s | SAC 8306, 14407-14408 | hecho, `abilities/play_dead.tscn` |
| Locust pazb (1) | disparo `zbba` (Drain Essence, 200) | disparo | — | SAC 11527, 22995 | hecho |
| Necryl glsd (2) | disparo `cena` (veneno); al morir `cen@` | pasiva | Nube venenosa con debuffs | SAC 11594, 25235 | hecho (030k-a, 030g) |
| Blight kacd (3) | Bilemites `liba` | activa | Hasta 10 ácaros (`amount3`), velocidad ×0,8ⁿ | SAC 13111, 25271 | hecho, `abilities/bilemites.tscn` |
| Netherfiend crpd (4) | Devour `ifna` | activa | Come un alma azul y gana regeneración | SAC 13138-13175 | hecho, `abilities/devour.gd` |
| Deadeye plfd (5) | disparo `lfda` (720, veneno) | disparo | — | SAC 11737, 24338 | hecho (030k) |
| Abomination ctug (6) | disparo `tugt` (425, gotas) | disparo | — | SAC 11759, 24432-24505 | hecho (030h3) |
| Styx nugd (7) | Rend Soul `dner`; disparo `dhga`; llama `tdhg` | activa | 100 de maná: arranca el alma de un cuerpo (2500) | SAC 13226-13230, 25853-25890 | hecho, `abilities/rend_soul.gd`; la llama `tdhg` (`styxFlame`, 13848) es visual: NO VERIFICADO en el port |
| Hellmouth nomd (9) | Devour `ifna`; disparo `mhba` (800, veneno) | activa | Igual que el del Netherfiend | SAC 13138 | hecho |

Tags en los datos sin dueño en el libro: `rifb` «Breathe fire» (600, 40 m), `othg` (efecto «elec») y `dhsf`. No los usa ninguna de las 51; su rol está **NO VERIFICADO** (probablemente son de campaña o restos).

---

## 4. Estructuras

En escaramuza y multijugador, los roles de juego los decide el tag del primer componente del BLDG [SAC `sacobject.d:950-970`]. Maná que da cada fuente [SAC 28578-28594, 28539-28556]: la tasa se suma por fuente, para todo cuerpo vivo a menos del radio (distancia 3D), filtrando bando o aliados.

**Cómo lo hace el exe (VERIFICADO REA).** La tasa de maná **no es una constante del código**: sale del BLDG.
- Al crear el edificio, `FUN_004651f0` copia del header del BLDG la vida máxima (`+0x44`, en 0x465200) y la tasa de maná (`+0x54` × 65536/1,8, en 0x465260; la constante está en 0x4c0400). Si el BLDG tiene el flag 0x100, copia también la regeneración: `vida máx. / (BLDG[+0x50] × 60)` por tick (0x46524c).
- Cada 8 ticks, `FUN_00465910` busca a los cuerpos que están a **≤50 m** (`push 50,0` en 0x465abe y 0x465ae5; el contador de ticks está en `[+0x4f8]`, 0x465a0b). Con el flag 0x800, a cualquiera (`FUN_00492230`); con el flag 0x400, solo al bando y sus aliados (`FUN_00492300` sobre los bandos con relación).
- A cada uno, `FUN_004650d0` le suma `stat20 × 0,001 × ticks × tasa` de maná en punto fijo 16.16 (0x465137-0x465150). `stat20` es el `unknown20` del CRE8/WIZD y vale 1000 en los magos. En la práctica son **33,3 × BLDG[+0x54] de maná por segundo**.
- La regeneración solo corre con el edificio terminado (`[+0x444]` = 1,0) y sin edificio padre.

Valores leídos de las WAD (BLDG `+0x54` / flags / `+0x50`):

| Fuente | BLDG `+0x54` | Maná/s | Flags | Regeneración |
|---|---|---|---|---|
| Manantial (`cafn`, `font`, `jfnt`, `pfon`, `stmf`; `wadex` MANF) | 1,0 | 33,3 | 0x80002810 (0x800: para cualquiera) | — (vida 0) |
| Manalith (`mana`, `pyma`, `jman`, `stam`, `cama`; MANL) | 1,0 | 33,3 | 0x55a0 (0x400 aliados, 0x100 regenera, 0x4000) | 5000 / (60 × 60) por tick = **83,3/s** |
| Altar (`alt1`, `ca_a`, `cua_`, `ealt`, `jaal`, `jaua`, `pua_`, `pyal`, `pyua`, `stal`, `stua`; ALTR) | 0,5 | 16,7 | 0x80001407 / 0x1407 (0x400) | — |
| Shrine (`pcsh`, `pasp`, `jsac`, `stsp`, `casp`; SACP) | **0,25** | **8,33** | 0x15a6 (0x400, 0x100; **sin** 0x4000) | **83,3/s** |

Los Manahoar solo cuentan los edificios con el flag **0x4000**, y ese flag lo tienen solo los Manalith: `FUN_00490f80`, llamado desde `ManahoarRunFlames` 0x4911c0 con radio 1000. Queda VERIFICADO que el Shrine no alimenta a los Manahoar.

| Estructura | Cómo aparece | Vida / regen. | Maná que da | Otras reglas | Fuentes | Port |
|---|---|---|---|---|---|---|
| **Altar** (11 BLDG: `alt1`, `ca_a`, `cua_`, `ealt`, `jaal`, `jaua`, `pua_`, `pyal`, `pyua`, `stal`, `stua`) | Lo pone el mapa, uno por mago | Según BLDG; destruirlo dispara `AltarDestruction` | 16,7/s (1000/60) a 50 m, para el bando y sus aliados (VERIFICADO REA: BLDG `+0x54` = 0,5) | Fantasma y reaparición del mago; destino de Convert y Desecrate; refugio de aldeanos; acepta Guardian | SAC 28589-28591, 13296-13385, 28063-28084 | hecho, `map/props/altar.gd`, `scenes/sacrifice/`, `mana_source.gd` (Kind.ALTAR) |
| **Manantial** (5: `cafn`, `font`, `jfnt`, `pfon`, `stmf`) | Lo pone el mapa | Indestructible | 33,3/s (1000/30) a 50 m, **para cualquiera** (VERIFICADO REA: flag 0x800, `+0x54` = 1,0) | Base de Manalith y Shrine; vuelve a estar libre al destruirse lo que tenía encima | SAC 28578-28580, 15175; [DOC] p. 48 | hecho, `map/props/manafount_body.gd` |
| **Manalith** (5: `mana`, `pyma`, `jman`, `stam`, `cama`) | Hechizo htlm | **5000** (VERIFICADO REA: el exe toma la vida del BLDG), **83,3/s** (se llena en 60 s; sacengine 75/s; la versión anterior de este informe decía «75/min» por error) | 33,3/s a 50 m, para el bando y sus aliados (VERIFICADO REA); además alimenta a los Manahoar aliados a distancia | Admite Guardian (el daño se reparte entre los guardianes); cuenta para Domination | SAC 28581-28588, `sacobject.d:1004-1008`, 9100 y siguientes; DATOS `buildings/_mana.tres` | hecho, `structures/structure_body.gd`, pero con **vida 3000** (`MANALITH_MAX_HEALTH`, ver §6) |
| **Shrine** (5: `pcsh`, `pasp`, `jsac`, `stsp`, `casp`) | Hechizo pcas (nivel 3) | **5000**, **83,3/s** (VERIFICADO REA, igual que el Manalith) | **8,33/s** (1000/120) a 50 m, para el bando y sus aliados: **VERIFICADO REA**, BLDG `+0x54` = 0,25, la mitad del altar. El manual se equivoca con «al ritmo del altar». Los Manahoar **no** lo usan (VERIFICADO REA: falta el flag 0x4000) | Es `closestShrine` para Convert: los doctores llevan ahí el alma y se hace el ritual. Admite Guardian, es destino de Teleport y sale con «+» en el minimapa. Al destruirse, el manantial vuelve a quedar libre. Que **no sirva para revivir al mago** lo dice solo la web: NO VERIFICADO | SAC 28592-28594, 28050-28130, 10181-10198, 10379, 15175; DATOS `buildings/_pcsh.tres`; [DOC] pp. 41, 49; [WEB] Shrine; [REA 0x4650d0, 0x465910, 0x4651f0, 0x490f80] | **falta**: hay modelo, `BuildingType` y `RitualSite.Kind.SHRINE`, pero no hay acción ni rama en `structure_body.gd` (con un tag que no es Manalith da 0 de maná, vida 1 y no regenera: `structure_body.gd:108-128`), ni rama en `sacrifice_system.closest_own_altar` (solo busca `Altar.GROUP`) |
| Refugio de aldeanos (20 BLDG con flag `shelter` + todos los altares) | Mapa | Según BLDG | — | Los aldeanos huyen si hay uno a ≤50 m | SAC 968-969; 055R §6 | hecho, `units/peasant_behavior.gd` |
| Destructibles e indestructibles (≈150) | Mapa | Según BLDG | — | Destruirlos da XP, no almas | 055R §2.2 | daño genérico |
| De campaña: Dynamo, Magnifryer (`yrfm`/`brfm`), altar etéreo | Mapas de campaña | — | — | Magnifryer es un cañón (efecto propio) | SAC `nttData.d:34-35`, 8484-8499, 2588 | fuera de alcance (campaña) |

Nota: en el port, `wizard_brain.gd:167-176` llama `shrine_spell` al primer hechizo con `onlyManafounts`, que hoy es Manalith; no es el Shrine.

---

## 5. Agrupación por mecánica y orden recomendado

Criterio: (1) lo que más se juega en multijugador (High Noon arranca en nivel 3, `multiMinLevel` 3, RFC-030 §2.1, así que los niveles 1 a 3 están siempre); (2) lo que reutiliza piezas que ya existen; (3) terreno deformable al final. No es un diseño: solo se nombran las piezas reutilizables.

| Orden | Grupo (mecánica compartida) | Hechizos | Piezas del port que se reutilizan |
|---|---|---|---|
| 1 | **Estructura Shrine** | pcas | Camino de `manalith_action.gd` y `StructureBody`/`StructureSpawner`; `ManaSource` (Kind.CUSTOM, rate 8,33); `RitualSite.Kind.SHRINE`; `sacrifice_system.closest_own_altar` (ampliar a shrines); `teleport_action`/`guardian_action`, que ya mencionan «shrine» |
| 2 | **Auto-buffs del mago** (nivel 2, uno por dios) | Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm; después Halo of Earth (nivel 5) | El factor de daño de `passives/life_shield.gd` (lo pide `Health`); generalizar «shielded» (deuda de RFC-030: solo Life Shield cuenta como escudo); alfa de `abilities/stealth.tscn`; aura que quema de `passives/fire_shield.gd`; `abilities/halo_of_earth.gd` (Rhinok); empuje de `movement/body_nudge.gd` |
| 3 | **CC sobre un blanco** (niveles 3 a 8) | Freeze, Grasping Vines, Rings of Fire, Slime; después Blind Rage y Charm | `afflictions/frozen.gd` y `vined.gd` (ya existen con los mismos datos `zerf`/`eniv`); `status/burning.gd`; `status/pace_factors.gd` (Slime 0,2ⁿ); `Afflictions.cc_protected()`; `aimed_action.gd` para apuntar; para Charm/Blind Rage, cambio de bando y blanco en `targeting/` |
| 4 | **Rebotes y proyectiles dirigidos** | Chain Lightning, Rainbow, Dragonfire, Intestinal Vaporization, Bovine Intervention | `abilities/lightning_strike.gd`; `spells/heal_effect.gd`; `thrown_action.gd` y `spell_projectile.gd`; el gib que ya usa el port al caer bajo tierra |
| 5 | **Muros en línea** (nivel 6 y 7, uno por dios) | Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence | Una sola pieza «WallPosition» (centro, dirección, crece hasta 55 m por lado, se corta en edificios y vacío, espesor 5 m) como en SAC 19935-20000; efectos: `burning`, `stunned` + `pace_factors`, drenaje de `mana_pool`, `vined`, `lightning_strike`; pinchos visuales `fx/spike_field.gd` |
| 6 | **Áreas en el suelo con duración** | Rain of Frogs, Rain of Fire, Plague, Cloudkill, Frozen Ground, Explosion, Demonic Rift, Healing Aura; Bombardment **sin** abolladuras | Las tres «nubes que sueltan cosas» comparten forma (nube a 90 m, tasa por segundo, radio 50 m, 20 s, desvío hacia criaturas a ≤25 m): SAC 19367, 20941, 21099, 21300. `spells/splash_damage.gd`; `status/poisoning.gd` (contagio); `death_clouds/*` (patrón de nube con vida); `afflictions/frozen.gd`; `abilities/lightning_strike.gd` (Cloudkill); `status/clinging.gd` (rana pegada, como la sticky bomb) |
| 7 | **Almas y resurrección** | Soul Mole, Soul Wind, Animate Dead | `scenes/souls/`; `abilities/rend_soul.gd` (mover almas); `abilities/fast_revive.gd`; `afflictions/stunned.gd` |
| 8 | **Últimos sin terreno** | Death, Meanstalks, Tornado | `afflictions/tumbling.gd` (catapult); kill de `Health` |
| 9 | **Terreno deformable** | Erupt, Bombardment (abolladuras), Volcano, Bore | Ver 055R §3: hoy hay tres representaciones del suelo que no se sincronizan (índice de `ground_height`, trimesh de colisión y navmesh); `NavRebake` vuelve a hornear todo el mapa; `QuakeRing` y `quake_wave.gd` son solo visuales. Erupt y Bombardment podrían entrar antes con su daño sin la deformación, como divergencia declarada (decide el tech lead) |
| — | **Bestiario** | Regeneración continua del Troll; verificar `gcil` del Silverback; llamas `tdhg`/`tfhg` | `unit_body.gd:615-622` y los estados que llaman a `regenerate` |

---

## 6. Discrepancias entre fuentes

| # | Tema | Fuente A | Fuente B | Cuál manda / estado |
|---|---|---|---|---|
| 1 | Vida de Manalith (y de Shrine) | DATOS `_mana.tres`/`_pcsh.tres`: 5000 (BLDG) | PORT `structure_body.gd:10`: `MANALITH_MAX_HEALTH := 3000.0` («long time-to-kill») | **Mandan los datos (5000). VERIFICADO REA:** el exe copia la vida máxima del BLDG (`[BLDG+0x44]` → `[edificio+0x490]`, 0x465200 `FUN_004651f0`) y el BLDG del Manalith y del Shrine dice 5000. El port se desvía sin declararlo |
| 2 | Maná del Shrine | SAC 28592: 1000/120 = 8,33/s, la mitad del altar | [DOC] p. 49: «at an altar's rate»; [WEB]: «roughly at an altar's pace» | **VERIFICADO REA: 8,33/s, manda sacengine.** La tasa sale del BLDG (`+0x54`): manantial y Manalith 1,0, altar 0,5 y Shrine 0,25, con 33,3 × tasa de maná/s a ≤50 m. Ver §4. El manual y la web se equivocan |
| 3 | Saltos de Chain Lightning | SAC 3185: `totTargets=7` | DATOS `amount3`=5 (`amount2` 3000 = 5 × 600) | **VERIFICADO REA: 7 golpes, manda sacengine.** El tope es una constante del código (`cmp 6` en 0x42001f) y el exe no lee `amount3`. Además, el radio del salto se achica: (6−n)/6 × 50 m (0x42008a) |
| 4 | Golpes de Rainbow | SAC 3136: 6 | DATOS `amount3`=5 (`amount2` = 5 × 600) | **VERIFICADO REA: 6 golpes** (1 inicial + 5 saltos), constante `cmp 6` en 0x42cb39; no lee `amount3`. **Corrección:** cada golpe cura la vida máxima del blanco y no 600 (0x42cdea) |
| 5 | Rocas de Halo of Earth (mago y Rhinok) | SAC 3455: `numRocks=6` | DATOS `olah`/`HRba` `amount3`=5 (`amount2` 3000 = 5 × 600) | **Mago: VERIFICADO REA, 6 rocas**, constante `(progreso + 0,1) × 6,0` en `HaloOfEarthRun` 0x4459a2; no lee `amount3`. Rhinok: la tabla de funciones solo tiene esa rutina de halo (`HaloOfEarthRun`/`HaloRockRun`), así que probablemente es la misma, pero no se encontró qué despacha `HRba` a ella: **NO VERIFICADO**. El port (Rhinok) usa 6 |
| 6 | Cloudkill | 055R §1.3: «nube venenosa» | SAC 22074-22108: nube de tormenta que tira rayos de 900 y persigue al blanco | **VERIFICADO REA** (`CloudKillRun` 0x420a30): persigue al blanco y tira rayos de `amount` 900 con salpicadura de 5 m. Diferencias menores con sacengine: altura 22 m (no 25) y ≈ 2 rayos/s (no 5/3). **055R estaba mal** |
| 7 | Objetivo de Death | 055R: «suelo/objetivo» | SAC 22160: mata a la criatura más cercana de cualquier bando, salvo magos | Precisión, no contradicción; [WEB] coincide (también mata propias) |
| 8 | Muertes de Death | SAC `maxNumTargets=8`, DATOS `amount3`=8 | [WEB]: «una y luego ocho veces más» | Mandan datos y sacengine (8) |
| 9 | Tiempos de lanzamiento | DATOS: Volcano 4,44 s, Rain of Frogs 2,47 s | [WEB]: 7 s y 5 s | La web probablemente mide con la animación. Mandan los datos (`frames / 81`, SAC `sacspell.d:101`) |
| 10 | Enfriamientos de los escudos | DATOS: Air Shield 70, Fireform 45, Protective Swarm 50, Ethereal Form 30 | [WEB]: 73, 49, 53 y 33 o 30 (la wiki se contradice) | Mandan los datos; la web parece sumar el lanzamiento |
| 11 | Daño de Protective Swarm | DATOS `amount` 75/s (SAC 17397 usa `amount`) | [WEB]: 150/s | Mandan los datos y sacengine |
| 12 | Duración de Rain of Frogs | DATOS 20 s | [WEB] 25 s | Mandan los datos |
| 13 | Daño de Firewall | DATOS `amount` 625 | SAC 20005-20014: fijo en 1200/s (con rampa 400/800) | **Corregido con REA: manda el dato.** El exe hace `amount` (625) por segundo × una rampa del muro que sube de 0 a 1 en 3 s (`FUN_00428030` 0x428053, `FireWallRun` 0x42845f). El 1200/s con 400/800 por blanco de sacengine no aparece en el exe |
| 14 | Pasivas del Silverback | DATOS `grdb`: `!nur` + `gcil` | RFC-030 §3: solo «Run Away», sin pasiva | Mandan los datos; falta verificarlo en el port |
| 15 | Troll | [DOC]: «regenerate life extremely quickly»; SAC `continuousRegeneration` | Port: sin regla especial | Falta en el port |
| 16 | `SpellType` del port | DATOS spells.json trae `amount3` (número de golpes) y `exclusionTags` | `scenes/spells/spell_type.gd` no los guarda | Habrá que hornearlos para Meanstalks, Explosion, Dragonfire y Death (el exe lee `amount3` de Death, VERIFICADO REA). Rainbow, Chain Lightning y Halo **no** usan `amount3`: sus topes son constantes (filas 3 a 5) |
| 17 | REA | Pedido como cuarta fuente | Compilado y usado en la segunda pasada (2026-10-24) | Filas 1 a 6 y 13 cerradas contra el exe. Siguen sin verificar el Halo del Rhinok, que el Shrine no sirva para revivir al mago, y los tags `tsg@`, `rifb`, `othg` y `dhsf` |
| 18 | Regeneración de Manalith y Shrine | SAC `sacobject.d:1006`: 75, aplicado como 75/s (`state.d:27982`). La versión anterior de este informe decía «75/min» | REA: `vida máx. / (BLDG[+0x50] = 60 × 60)` por tick = **83,3/s**, se llena en 60 s (`FUN_004651f0` 0x46524c, `FUN_00465910`) | **Manda el exe (83,3/s)**: sale del BLDG |
| 19 | Cura de Rainbow | SAC 18129-18157: 600 por golpe (`amount`) | REA `FUN_0042cdb0` 0x42cdea: cura `[blanco+0x8fe]` (vida máxima) por golpe, con el mecanismo de cura en el tiempo de Heal (`FUN_0043f610`, tasa 0x100) | **Manda el exe**: cada golpe deja al blanco curado del todo |
| 20 | Air Shield contra daño a distancia | SAC 8967: ×0,5 para todo | REA `AirShieldTargetDamaged` 0x41f6e0: ×0,5 y otro ×0,5 para los tipos 3 y 4 (distancia) | **Manda el exe**: ×0,25 contra el daño a distancia |

Fuentes web consultadas:
- [Rain of Frogs (wiki)](https://sacrifice-shiny.fandom.com/wiki/Rain_of_Frogs?oldid=9786)
- [Volcano](https://sacrifice-shiny.fandom.com/wiki/Volcano), [Level 8 Spells](https://sacrifice-shiny.fandom.com/wiki/Level_8_Spells), [Ultimate Spells](https://sacrifice-shiny.fandom.com/wiki/Ultimate_Spells)
- [Shrine](https://sacrifice-shiny.fandom.com/wiki/Shrine), [Manalith](https://sacrifice-shiny.fandom.com/wiki/Manalith), [Mana Fountain](https://sacrifice-shiny.fandom.com/wiki/Mana_Fountain)
- [Level 2 Spells](https://sacrifice-shiny.fandom.com/wiki/Level_2_Spells)
- [Death](https://sacrifice-shiny.fandom.com/wiki/Death), [Intestinal Vaporization](https://sacrifice-shiny.fandom.com/wiki/Intestinal_Vaporization), [Charm](https://sacrifice-shiny.fandom.com/wiki/Charm)
