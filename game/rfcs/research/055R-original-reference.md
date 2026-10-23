# 055R — Referencia del original para RFC-055 (hechizos, estructuras, terreno, doctores, giro, aldeanos, voladores)

Investigación de hechos, sin diseño. Fuentes:

- **[SAC]** sacengine (`sacengine/source/`, GPL, solo lectura; se describe el comportamiento, no se copia código).
- **[DATOS]** datos del juego ya horneados en el port (`game/data/catalog/...`, salidos de las WAD originales).
- **[PORT]** código del port (`game/scenes/...`).
- **[PREV]** investigaciones previas (`game/rfcs/research/poblados-npc.md`, `game/rfcs/RFC-030-full-bestiary.md`).
- **REA** no hizo falta: sacengine y los datos fueron inequívocos en las 7 preguntas. Donde algo no se pudo confirmar se marca **NO VERIFICADO**.

---

## 1. Inventario completo de hechizos

### 1.1 Estructura del libro en el original

- El libro de cada dios se arma con tres listas fijas [SAC `nttData.d:1243-1258`]:
  - **creatureSpells**: `manahoar` (neutral) + 10 criaturas del dios.
  - **normalSpells**: `speedup` y `heal` (neutrales) + 9 hechizos del dios.
  - **structureSpells** (comunes a todos): `manalith`, `guardian`, `convert`, `desecrate`, `teleport`, `shrine`.
- Total: **53 hechizos no-criatura distintos** (2 neutrales + 5×9 de dioses + 6 de estructura) y **51 criaturas invocables** (Manahoar + 5×10). El Sac Doctor, Familiar y Zyzyx son "neutral creatures" en el enum [SAC `nttData.d:1015-1018`] pero no entran en ningún libro.
- **Nivel** = `spell_order / 100` [SAC `sacspell.d` `castingTime`: `spellLevel=spellOrder/100`]; `spell_order` sale del SPEL/CRE8/STRC de la WAD [DATOS `data/catalog/spells/*.tres`].
- Tipos de objetivo: decodificados de `flags` del SPEL [SAC `spells.d` `SpelFlags`; DATOS]. `self` = sin objetivo (se lanza sobre el mago).

### 1.2 Cómo se implementa un hechizo en el port

- Todos los 53 hechizos tienen su `SpellType` en `data/catalog/spells/<tag>.tres` [DATOS] y aparecen en el libro del dios (`data/gods/*.tres`). Pero **solo se pueden lanzar los que tienen una `SpellAction`** [PORT `scenes/spells/caster.gd:134-145`]: un hijo de `Caster/Actions` en `scenes/wizards/wizard_body.tscn` o el campo `action` del `.tres` (ningún `.tres` lo tiene hoy). Sin acción, el lanzamiento se rechaza ("no implementado").
- Acciones existentes [PORT `wizard_body.tscn:176-230`]: Manalith, Desecrate, Convert, Guardian, Teleport, Pups (Speed Up), Heal, Rock, Wrath, Fireball, Lightning, Swarm (Insect Swarm). **12 de 53.**
- Las 51 criaturas se invocan con el `Summoner` genérico (no necesitan acción) y RFC-030 está cerrado [PREV `RFC-030-full-bestiary.md:3`]; algunas habilidades de criatura siguen diciendo «No implementado» (fuera del alcance de esta tabla).

### 1.3 Tabla: hechizos (no criatura)

Columnas: Nv = nivel (spell_order/100). Objetivo según flags [DATOS]. "Terreno" = deforma la altura del suelo en el original (ver §3). Línea `cast*` = función de lanzamiento en `sacengine/source/state.d`.

#### Neutrales y estructura (todos los dioses)

| Tag | Hechizo | Nv | Objetivo | Qué hace (original) | Terreno | Port | Archivo del port |
|---|---|---|---|---|---|---|---|
| htlm | Manalith | 1 | estructura + solo manantial | Construye una torre de maná del dios sobre un manantial libre (`StructureCasting`, state.d:10072-10086) | no | sí | `scenes/spells/actions/manalith_action.gd` |
| pups | Speed Up | 1 | aliado (mago/criatura) | Acelera a una criatura aliada (dur. 30 s) | no | sí | `actions/pups_action.tscn` |
| ndrg | Guardian | 1 | criatura | Pone a una criatura a custodiar un altar/manalith (`castGuardian` 10366) | no | sí | `actions/guardian_action.gd` + `spells/guardian/` |
| ccas | Convert | 1 | alma enemiga | Sac Doctors revive el cuerpo y lo llevan al altar propio (`castConvert` 10181) | no | sí | `actions/convert_action.gd` + `scenes/sacrifice/` |
| ucas | Desecrate | 1 | criatura propia | Sac Doctors llevan una criatura propia al altar enemigo para profanarlo (`castDesecrate` 10200) | no | sí | `actions/desecrate_action.gd` |
| elet | Teleport | 1 | estructura aliada | Teletransporta al mago a una estructura propia (`castTeleport` 10230) | no | sí | `actions/teleport_action.gd` |
| laeh | Heal | 1 | aliado | Cura a un aliado (`castHeal` 10438) | no | sí | `actions/heal_action.tscn` |
| pcas | Shrine | 3 | estructura + solo manantial (mismos flags que Manalith, `flags=2064`) | Construye un santuario del dios (mismo camino `StructureCasting`, modelos `pcsh/pasp/jsac/stsp/casp`) | no | **no** | — |

#### Persephone

| Tag | Hechizo | Nv | Objetivo | Qué hace (original) | Terreno | Port | Archivo |
|---|---|---|---|---|---|---|---|
| oalf | Wrath | 1 | enemigo | Proyectil dirigido (`castWrath` 10493) | no | sí | `actions/wrath_action.tscn`, `wrath_strike.tscn` |
| mrfe | Ethereal Form | 2 | self | Forma etérea del mago, 15 s (`castEtherealForm` 10606) | no | no | — |
| eniv | Grasping Vines | 3 | enemigo no volador | Enredaderas inmovilizan, 40 s (`castGraspingVines` 10766) | no | no | — |
| wobr | Rainbow | 4 | aliado | Arco iris curativo entre aliados (`castRainbow` 10832) | no | no (solo datos reusados por `units/abilities/devour.gd`) | — |
| grfr | Rain of Frogs | 5 | suelo/área | Lluvia de ranas en un área, 20 s (`castRainOfFrogs` 11025) | no | no | — |
| ruah | Healing Aura | 6 | aliado | Aura de curación, 20 s (`castHealingAura` 11076) | no | no | — |
| lawv | Vinewall | 7 | suelo, no volador | Muro de enredaderas en línea, 50 s (`castVinewall` 11156) | no | no | — |
| mrhc | Charm | 8 | criatura enemiga | Toma control de una criatura enemiga (`castCharm` 11314) | no | no | — |
| rter | Meanstalks | 8 | suelo | Tallos agresivos en un área, 60 s (`castMeanstalks` 11441) | no | no | — |

#### Pyro

| Tag | Hechizo | Nv | Objetivo | Qué hace (original) | Terreno | Port | Archivo |
|---|---|---|---|---|---|---|---|
| brif | Fireball | 1 | enemigo | Bola de fuego (`castFireball` 10519) | no | sí | `actions/fireball_action.tscn`, `fireball_projectile.tscn` |
| mrff | Fireform | 2 | self | Forma de fuego del mago, 40 s (`castFireform` 10622) | no | no (datos reusados por `units/passives/fire_shield.gd`) | — |
| rapf | Rings of Fire | 3 | enemigo | Anillos de fuego sobre el objetivo, 10 s (`castRingsOfFire` 10726) | no | no | — |
| rifd | Dragonfire | 4 | enemigo | Fuego de dragón canalizado (`castDragonfire` 10926) | no | no | — |
| pxef | Explosion | 5 | suelo/área | Explosión en área (`castExplosion` 10960) | no | no | — |
| lwrf | Firewall | 6 | suelo, no volador | Muro de fuego, 30 s (`castFirewall` 11118) | no | no | — |
| rifr | Rain of Fire | 7 | suelo/área | Lluvia de fuego, 20 s (`castRainOfFire` 11045) | no | no | — |
| egar | Blind Rage | 8 | criatura enemiga | Furia ciega (ataca a cualquiera), 30 s (`castBlindRage` 11235) | no | no | — |
| clov | Volcano | 8 | suelo | Levanta un volcán, erupciona, quema y deja cráter y residuo, 60 s (`castVolcano` 11364) | **sí, permanente** | no | — |

#### James

| Tag | Hechizo | Nv | Objetivo | Qué hace (original) | Terreno | Port | Archivo |
|---|---|---|---|---|---|---|---|
| kcor | Rock | 1 | enemigo | Roca lanzada (`castRock` 10548) | no | sí | `actions/rock_action.tscn`, `rock_projectile.tscn` |
| niks | Skin of Stone | 2 | self | Piel de piedra (defensa), 80 s (`castSkinOfStone` 10591) | no | no | — |
| pmcd | Soul Mole | 3 | alma aliada | Topo que arrastra almas hacia el mago (`castSoulMole` 10814) | no | no | — |
| tpre | Erupt | 4 | suelo/área | El suelo se eleva y estalla, lanza y aturde (`castErupt` 10905) | **sí, temporal** | no | — |
| olah | Halo of Earth | 5 | self | Rocas orbitan al mago, 35 s (`castHaloOfEarth` 11015) | no | no (la habilidad de criatura `HRba` existe aparte: `units/abilities/halo_of_earth.gd`) | — |
| laws | Wall of Spikes | 6 | suelo, no volador | Muro de pinchos, 40 s (`castWallOfSpikes` 11175) | no (pinchos son objetos, no desplazamiento) | no | — |
| rtem | Bombardment | 7 | suelo/área | Lluvia de meteoritos, 20 s (`castBombardment` 11055) | **sí, permanente (abolladuras)** | no | — |
| ivob | Bovine Intervention | 8 | criatura enemiga | Cae una vaca sobre el objetivo (`castBovineIntervention` 11263) | no | no | — |
| erob | Bore | 8 | suelo | Un taladro abre agujeros en el terreno (`castBore` 10914) | **sí, agujeros temporales** | no | — |

#### Stratos

| Tag | Hechizo | Nv | Objetivo | Qué hace (original) | Terreno | Port | Archivo |
|---|---|---|---|---|---|---|---|
| ntil | Lightning | 1 | enemigo | Rayo (`castLightning` 10464) | no | sí | `actions/lightning_action.tscn` |
| dlhs | Air Shield | 2 | self | Escudo de aire, 60 s (`castAirShield` 10664) | no | no | — |
| zerf | Freeze | 3 | enemigo | Congela al objetivo, 20 s (`castFreeze` 10687) | no | no (datos reusados por `units/attacks/freeze_touch.gd`) | — |
| ntlc | Chain Lightning | 4 | enemigo | Rayo que salta entre objetivos (`castChainLightning` 10844) | no | no | — |
| dnws | Soul Wind | 5 | alma aliada | Viento que lleva almas (`castSoulWind` 10941) | no | no | — |
| zorf | Frozen Ground | 6 | suelo/área | Suelo helado en un área, 30 s (`castFrozenGround` 11103) | no (efecto de superficie, sin desplazamiento) | no | — |
| cnef | Fence | 7 | suelo, no volador | Cerca eléctrica en línea, 35 s (`castFence` 11194) | no | no | — |
| likc | Cloudkill | 8 | suelo/área | Nube venenosa, 30 s (`castCloudkill` 11331) | no | no | — |
| nrot | Tornado | 8 | suelo | Tornado que arrastra unidades, 25 s (`castTornado` 11470) | no | no | — |

#### Charnel

| Tag | Hechizo | Nv | Objetivo | Qué hace (original) | Terreno | Port | Archivo |
|---|---|---|---|---|---|---|---|
| mrws | Insect Swarm | 1 | enemigo | Enjambre dirigido (`castSwarm` 10576) | no | sí | `actions/swarm_action.tscn`, `swarm_projectile.tscn` |
| rwsp | Protective Swarm | 2 | self | Enjambre protector, 40 s (`castProtectiveSwarm` 10643) | no | no | — |
| htel | Slime | 3 | enemigo | Babosa que frena/penaliza al objetivo, 30 s (`castSlime` 10744) | no | no | — |
| deda | Animate Dead | 4 | alma aliada | Revive una criatura propia muerta (`castAnimateDead` 10859) | no | no | — |
| tfir | Demonic Rift | 5 | mago/criatura | Grieta demoníaca (`castDemonicRift` 11065) | no | no | — |
| laww | Wailing Wall | 6 | suelo, no volador | Muro de lamentos, 60 s (`castWailingWall` 11137) | no | no | — |
| galp | Plague | 7 | suelo/área | Plaga en un área, 20 s (`castPlague` 11035) | no | no | — |
| pavi | Intestinal Vaporization | 8 | criatura enemiga | Vaporiza a una criatura (`castIntestinalVaporization` 11217) | no | no | — |
| taed | Death | 8 | suelo/objetivo | Muerte (`castDeath` 11347) | no | no (solo nombrado en `ai/brains/ai_spell_eval.gd:67`) | — |

Nota: las descripciones son de una línea, derivadas del nombre del efecto que crea cada `cast*` y de los flags/duración del SPEL; el detalle exacto de daño/forma de cada uno **no se verificó** aquí y debe leerse en su `update*` cuando se implemente.

### 1.4 Lista exacta de faltantes ("faltan habilidades del mago") — 41

- **Neutral/estructura (1):** Shrine (pcas).
- **Persephone (8):** Ethereal Form, Grasping Vines, Rainbow, Rain of Frogs, Healing Aura, Vinewall, Charm, Meanstalks.
- **Pyro (8):** Fireform, Rings of Fire, Dragonfire, Explosion, Firewall, Rain of Fire, Blind Rage, Volcano.
- **James (8):** Skin of Stone, Soul Mole, Erupt, Halo of Earth, Wall of Spikes, Bombardment, Bovine Intervention, Bore.
- **Stratos (8):** Air Shield, Freeze, Chain Lightning, Soul Wind, Frozen Ground, Fence, Cloudkill, Tornado.
- **Charnel (8):** Protective Swarm, Slime, Animate Dead, Demonic Rift, Wailing Wall, Plague, Intestinal Vaporization, Death.

Cada dios tiene hoy **solo su hechizo de nivel 1** más los 7 comunes implementados; del nivel 2 al 8 no hay ninguno.

---

## 2. Inventario de edificios y estructuras

### 2.1 Original

- Un edificio es un **BLDG** (datos, no código): cabecera con flags, máscara `ground` 8×8 (el suelo cambia bajo él), vida máxima, tileset, y una lista de componentes (modelo, modelo destruido, posición, giro, hechizo) [SAC `bldg.d:8-37`].
- Flags conocidos: `shelter` (bit 15, refugio de aldeanos, marcado `TODO: correct?`) y `ground` (bit 31) [SAC `bldg.d:8-12`]. Vida 0 = indestructible.
- Los roles de juego se deciden por el **tag del primer componente** [SAC `sacobject.d:950-970`, `nttData.d:25-33`]:
  - **Manafount** (manantial): 1 componente, tags por dios (`pcfn`, `jfnt`, `cafn`, `pfon`, `stmf` invertidos).
  - **Manalith**: 1 componente; **Shrine**: 1 componente; **Altar**: base de altar (`altarBaseTags`, incluye el altar etéreo `b_ae` y el de Stratos `tprc`).
  - **Peasant shelter**: flag `shelter` o cualquier altar [SAC `sacobject.d:968-969`].
- Estructuras especiales de campaña nombradas en código: `pyrodraulicDynamoTag` y `pyrosMagnifryerTag` [SAC `nttData.d:34-35`] (rol **NO VERIFICADO**).
- Destruir un edificio da XP, no almas [PREV `poblados-npc.md:10`]. Destruir un altar dispara `AltarDestruction` [SAC `state.d:13314-13385`].

### 2.2 Port: catálogo y modelos

- `data/catalog/buildings/` tiene **196 BuildingType** (uno por BLDG de las WAD) [DATOS]; `BuildingType` guarda flags, `shelter`, `ground`, `max_health`, componentes [PORT `scenes/structures/building_type.gd`].
- Clasificación hecha con un script sobre los `.tres` (tags de §2.1):

| Categoría | Cantidad | Rol en el juego | Modelos presentes | Comportamiento en el port |
|---|---|---|---|---|
| Altar | 11 (`alt1`, `ca_a`, `cua_`, `ealt`, `jaal`, `jaua`, `pua_`, `pyal`, `pyua`, `stal`, `stua`) | Base del mago: ghost/respawn, destino de Convert/Desecrate, refugio de aldeanos | sí (todos) | sí (rituales, guardian, sacrificio: `scenes/sacrifice/`, `spells/guardian/`) |
| Manafount | 5 (`cafn`, `font`, `jfnt`, `pfon`, `stmf`) | Lugar donde se construye Manalith/Shrine | sí | sí (destino de Manalith) |
| Manalith | 5 (`mana`, `pyma`, `jman`, `stam`, `cama`), vida 5000 | Regenera maná, estructura propia | sí | sí (`manalith_action.gd`, `structure_body.gd`) |
| Shrine | 5 (`pcsh`, `pasp`, `jsac`, `stsp`, `casp`), vida 5000 | Estructura propia (cuenta como "shrine" para rituales en sacengine `closestShrine`) | sí | **modelo sí, hechizo no** (sin acción `pcas`) |
| Refugio (shelter) | 20 | Aldeanos huyen cerca de él | sí | sí (`units/peasant_behavior.gd`) |
| Destructible genérico | 50 | Escenografía con vida | sí | daño/destrucción genérica (no auditado en detalle) |
| Indestructible | 100 | Escenografía | sí | estático |

- **Modelos faltantes: 0.** Todos los componentes de los 196 BLDG tienen `.glb` en `assets/original/props/` (importados en c95abc5a: «161 modelos nuevos… altares, manalitos y santuarios de Pyro, Stratos y Charnel»).
- **Uso en mapas:** 82 de 196 tags aparecen en los mapas del port (`assets/original/maps/*/ntts.json` y escenas); Manalith y Shrine no aparecen porque se crean al lanzar el hechizo. El resto (~114) son de mapas/campaña no portados: **importados pero sin uso**.

---

## 3. Hechizos que deforman el terreno y el sistema de terreno

### 3.1 Qué deforma el terreno en el original

La altura efectiva de cada vértice es `altura base + Displacement(i,j)`, y `Displacement` suma [SAC `state.d:28911-28934`]:
1. `permanentDisplacement` (rejilla 256×256 de floats, uno por vértice, nunca se resetea) [SAC `state.d:7294-7342`],
2. los efectos vivos `eruptCastings`, `erupts`, `quakes` (y `testDisplacements`, que es de depuración: `state.d:13421`).

Además existe un segundo mecanismo: **quitar vértices** (agujeros, "edges").

| Origen | Tipo | Mecanismo | Duración | Fuente |
|---|---|---|---|---|
| **Volcano** (Pyro, nv 8) | hechizo | Mientras se lanza, aplana un parche de 33×33 vértices (330 m) hacia la altura del centro (plano hasta 80 m, transición hasta 164 m) y suma 0.2× una forma de volcán (`SacVolcano.volc`) escalada por `progress`. Al erupcionar, `volcanoDent` cava un cráter de radio 25 m y 10 m de profundidad. Luego `progress` baja hasta `residual=0.25`. Si se interrumpe el lanzamiento, se deshace todo | **Permanente**: queda el 25 % del monte + el cráter | `state.d:4307-4370`, `7323-7335`, `22300-22375` |
| **Bombardment** (James, nv 7) | hechizo | Cada meteorito que cae suma una abolladura esférica de radio 15 m y 1.2 m de profundidad a `permanentDisplacement` | **Permanente** | `state.d:4077-4083`, `7305-7315`, `21378` |
| **Erupt** (James, nv 4) | hechizo | Displacement temporal: el suelo sube hasta 15 m en radio 50 m durante 4.2 s, cae en 0.15 s, y una onda sale hasta 90 m en 1 s. Lanza unidades (throwRange 42.5) y aturde entre 50 y 75 m | Temporal (~5.2 s) | `state.d:3223-3289` |
| **Bore** (James, nv 8) | hechizo | Un taladro avanza; a los 10 s aparece un `BoreHole` que **quita vértices** por donde pasa (agujeros reales). Al llegar espera ~3 s y repone un vértice cada 0.5 s | Temporal (agujeros) | `state.d:3298-3334`, `18620-18695` |
| **Quake** (habilidad `kauq` del Jabberocky) | habilidad de criatura | Onda temporal de 50 m de radio y 0.5 s | Temporal | `state.d:5187-5225`, `13204`; DATOS `catalog/creatures/mtse.tres` |

No deforman terreno (verificado por ausencia de uso de `Displacement`/`removeLandVertex`): Tornado, Wall of Spikes, Frozen Ground, Firewall, Vinewall, Wailing Wall, Fence, Rain of Fire, Explosion y el resto.

### 3.2 Cómo reaccionan colisiones, caminos y render en el original

- **Mapa:** rejilla de 256×256 vértices separados 10 m (`getVertex` = `10*i, 10*j, heights[j][i]`) más una matriz `edges` (vértice ausente = agujero) [SAC `sacmap.d:143-144`, `517-518`, `717`].
- **Altura de criaturas/proyectiles/rayos:** `getHeight`, `getGroundHeight`, `moveOnGround`, `collideRay`, `terrainLineOfSight` siempre suman `Displacement` [SAC `state.d:28935-28985`]. Es decir, todo lo que pisa el suelo sigue la deformación en el mismo tick; no hay malla de colisión aparte.
- **Agujeros:** `removeLandVertex` no deja quitar un vértice del borde, uno ya ausente, uno a <11 m de un objeto estático de edificio o bajo la máscara `ground` de un edificio [SAC `state.d:28986-29012`]. Al quitarlo crea un `FallingLandChunk` (el pedazo cae, solo visual/efecto) y lanza (`catapult`) a las criaturas en tierra que ya no tienen suelo [SAC `state.d:29013-29058`].
- **Pathfinding:** rejilla 512×512 con paso 5 m (`directWalkDistance`) [SAC `state.d:575`, `675-760`]. Sus alturas se calculan **una sola vez** con `ZeroDisplacement` (ignora Volcano/Bombardment/Erupt). Lo único que recalcula es la libertad de cada celda cuando cambia el hash de `edgeChanges` (agujeros de Bore): `updateEdges` reconstruye `free` y las componentes conexas [SAC `state.d:728-741`, `29118-29122`]. Conclusión: **los caminos solo reaccionan a agujeros, no a montes ni cráteres**.
- **Render:** el backend sube `permanentDisplacement` como textura de desplazamiento cuando cambia su hash y aplica los efectos temporales por shader [SAC `dagonBackend.d:2128-2152`].

### 3.3 Cómo es el terreno del port hoy (restricciones)

| Pieza | Hecho | Fuente |
|---|---|---|
| Datos | `MapTerrainData` (vértices, normales, índices) en `assets/original/maps/<mapa>/terrain.res`. Comentario explícito: «Never mutated at runtime». | `scenes/map/terrain/map_terrain_data.gd` |
| Malla visible | `Terrain extends MeshInstance3D`; usa el `terrain.glb` importado si coincide con los datos, si no reconstruye un `ArrayMesh` de una superficie. Rejilla `GRID=256`, `CELL=10.0` m (igual que el original). Paredes de acantilado mezcladas en el índice. | `scenes/map/terrain/terrain.gd:28-29`, `106-125` |
| Altura lógica | `Terrain.ground_height(x,z)` / `height_sampler()` / `height_in()` estático sobre `_ground` (3 vértices por triángulo) y `_cell_triangles` (2 triángulos por celda de 10 m); NaN sobre agujeros. Lo usan ~25 scripts (GroundSnap, FallCheck, EdgeClamp, proyectiles, nav_service, Teleport, Wrath, etc.). | `terrain.gd:260-290`; grep `ground_height\|height_sampler` |
| Colisión física | Un `StaticBody3D` "Collision" con `CollisionShape3D` de `mesh.create_trimesh_shape()` (ConcavePolygonShape3D) creado en `_ready`; no se regenera. | `terrain.gd:454-462` |
| Movimiento | Las unidades son `CharacterBody3D` con `move_and_slide()` sobre esa colisión, más `EdgeClamp` y `FallCheck` que leen `ground_height`. | `scenes/units/unit_body.gd:2`, `576-584` |
| Navmesh | Horneado offline por mapa (`scenes/map/maps/<mapa>/nav.res`) con `tools/bake/bake_nav.gd`; parámetros en `data/nav/nav_bake.tres`: celda 1.0 m, alto 0.25, radio agente 1.0, `max_climb` 3.0, `max_slope` 85°. Fuente: colisionadores estáticos del grupo `nav_source`. | `scenes/map/nav/nav_bake_settings.gd`, `map_nav_region.gd` |
| Re-horneado en partida | `NavRebake`: re-hornea **todo el mapa** en un hilo (el comentario dice «un par de segundos» para High Noon) y lo intercambia en un tick elegido; se dejó de hornear por teselas por costuras. Hoy se dispara cuando aparece/cae un edificio. | `scenes/map/nav/nav_rebake.gd:1-20` |
| Efectos que hoy "simulan" deformación | Solo visuales: `QuakeRing` (anillo de tierra del Quake, «presentation only») y `SpikeField` (pinchos del Rhinok). No cambian altura. | `scenes/fx/quake_ring.gd:1-10`, `scenes/fx/spike_field.gd` |

Restricciones que el tech lead debe tener presentes (hechos, no diseño):
- Hay **tres representaciones** del suelo que hoy no se sincronizan entre sí si cambiara la altura: índice de triángulos para `ground_height`, trimesh de colisión, y navmesh horneado. Más la malla visible.
- El original resuelve la altura con una suma por vértice sobre una rejilla regular de 256×256; el port ya tiene la misma rejilla y paso (256, 10 m), pero su índice es por triángulo, no un heightmap.
- En el original el pathfinding **ignora** el desplazamiento (solo agujeros cambian caminos); igualar eso implicaría que solo Bore exige tocar la navegación.
- Determinismo: la altura es estado de simulación en el original (entra en el hash/serialización: `serialize_.d:950-972`); en el port, cualquier deformación debería ser igual en servidor y clientes (hoy GroundSnap insiste en leer datos, no rayos, por esa razón: `scenes/components/ground_snap.gd:6-8`).

---

## 4. Doctor que lleva una criatura y muere

Flujo del original [SAC `state.d:15508-15815`, `SacDocCarry` 2680-2697]: estados `fall → bounce → walkToTarget → pump → move → shrinking`.

| Momento de la muerte del doctor | Qué pasa con el alma | Qué pasa con la criatura | Fuente |
|---|---|---|---|
| Doctor ya no es válido (cualquier estado) | Si aún hay alma: se libera (vuelve a ser convertible por ese bando, `convertSideMask`) | Si ya había criatura: `freeCreature` sin punto de aterrizaje | `state.d:15616-15633` |
| Durante `walkToTarget` (Convert) | El alma se libera | No hay criatura todavía | `15681-15686` |
| Durante `pump` (Convert: la criatura está en `convertReviving`) | El alma se libera | `freeCreature` → como está en `convertReviving`, **muere de nuevo** (`kill`) y como su modo era `convertReviving` pasa directo a `dead` y `spawnSoul` re-emerge su alma donde está el cuerpo | `15728-15733`; `freeCreature` 10146-10150; `kill` 8270-8283; `spawnSoul` 8382-8395 |
| Durante `move` (la criatura cuelga del doctor, modo `thrashing`, **su alma ya fue removida** al levantarla) | No hay alma: se removió en `startMoving` (`removeLater(soul)`, `soulId=0`) | `freeCreature(criatura, posición del doctor)`: queda **viva**, `stunned` + `tumbling`, con velocidad de caída calculada hacia la posición del doctor (velocidad 5) y cae al suelo; conserva la vida que le dio `convertRevive` (máx(400, 50 % de vida máx), tope vida máx) | `15634-15660`, `15779-15782`; `freeCreature` 10146-10159; `convertRevive` 8668-8684 |
| Ritual ya empezado (`stopRitual`) | — | `freeCreature(criatura, posición inicial del ritual)`; los doctores mueren | `15817-15830` |

Consecuencias para la decisión de diseño:
- En el original la criatura cargada **cae viva** al lugar del doctor y **no tiene alma** mientras vive; si después muere, el flujo normal `dying → dead → spawnSoul` crea un alma nueva **donde queda el cadáver** (`state.d:14005-14018`, `8382-8395`). Es decir, «el alma queda donde cae la criatura» se cumple solo si la criatura muere.
- Si el doctor muere en `pump`, la criatura vuelve a morir en el acto y su alma reaparece donde está el cuerpo (no hubo traslado).
- El bando de la criatura no cambia por `convertRevive` (no hay cambio de side en esa función); el cambio ocurre recién al final del ritual, donde la criatura se sacrifica (`gib`) [SAC `state.d:16025-16035`].
- Port actual: `Captive.release()` la deja «caer al suelo, viva y con su dueño» donde cuelga [PORT `scenes/units/captive.gd:108-121`]; `CarryErrand._on_died` delega en el paso (`haul/pump/approach.doctor_died`) [PORT `scenes/sacrifice/carry_errand.gd:129-133`].

---

## 5. Giro al moverse (facing)

- En tierra, la velocidad del cuerpo es **siempre a lo largo de su `facing`**: `direction = rotate(facing, (0,1,0))`, `velocity = direction × speed`, con `speed` con signo (adelante/atrás) [SAC `state.d:14680-14700`]. No existe movimiento lateral ni desacople entre hacia dónde mira y hacia dónde va.
- `MovementDirection` tiene `forward` y `backward` [SAC `state.d:292-296`]. **Marcha atrás solo existe como comando del jugador** (`moveBackward`, control directo del mago: `state.d:29276`, `dagonBackend.d:1567`); los voladores sin `canFlyBackward` no pueden [SAC `state.d:9441-9446`]. La IA de criaturas solo usa `startMovingForward`.
- **Evasión**: la IA esquiva un obstáculo frontal **girando** (`setTurning(left/right)`) mientras sigue `startMovingForward`; si hay un obstáculo al costado del giro, deja de girar y sigue recto [SAC `state.d:12085-12150`]. O sea, esquivar también es "mirar hacia donde vas".
- **Velocidad de giro** (igual para todas las criaturas, no es stat por criatura): en tierra **π rad/s** (180°/s), volando **127π/192 rad/s** (~119°/s) con aceleración angular 3π rad/s² [SAC `stats.d:104-111`]. En tierra el giro es instantáneo a esa velocidad (sin rampa); `face()` limita el paso para no pasarse del ángulo (`rotationSpeedLimitFactor=1`) [SAC `state.d:11887-11905`, `13613`, `14570-14600`].
- **Avanzar mientras gira:** `movingForwardGetsCloserTo` decide si conviene avanzar ya o girar primero según el radio de giro `speed/rotationSpeed` [SAC `state.d:11960-11980`].
- **Empujes externos** (`push`, `pushAll`: volcán, rituales, etc.) mueven la posición sin tocar el facing [SAC `state.d:8604-8612`]; los lanzamientos (`catapult`) pasan a `tumbling` y en ese modo no se rota [SAC `state.d:8582-8599`, `14574-14576`].
- Port: `unit_body.gd` tiene `turn_rate := PI` (coincide en tierra) y `turn_toward()` rota hacia la dirección deseada, pero la velocidad final la reemplaza la avoidance del motor en `_on_avoided` [PORT `scenes/units/unit_body.gd:95`, `563-573`, `635-637`]. Esa es la diferencia con la regla original.

---

## 6. Aldeanos al ser golpeados

Ya investigado en [PREV `poblados-npc.md`, filas 18-22]; se re-verificó el código:

- Si un campesino recibe daño **con la vida llena**, el bando atacante entra en su `grudgeMask` [SAC `state.d:8933-8936`]. La manada comparte rencores (`absorbHerdGrudges`) [SAC `state.d:13732`].
- Sin orden: si hay un **refugio a ≤50 m** (`shelterDistance`), deja de encogerse y, si hay un enemigo o un bando con rencor a ≤50 m (`scareDistance`), **corre en dirección opuesta** al enemigo y reproduce el sonido de huida; si no hay enemigo, se queda quieto. **Sin refugio cerca, se encoge (`cower`)** y espera [SAC `state.d:13610-13611`, `13733-13752`]. sacengine marca la regla con `TODO: figure out the original rule`: **la regla exacta del exe NO está VERIFICADA**.
- Nunca atacan (agresividad 0) [PREV fila 22].
- Port: ya implementado en `scenes/units/peasant_behavior.gd` y `scenes/units/grudge_memory.gd` con las mismas distancias.

---

## 7. Muerte de un volador

[SAC `state.d:13985-14040`]

1. Al morir en el aire reproduce la animación de muerte en vuelo (`flyDeath`) mientras sigue `flying`.
2. Al terminar esa animación pasa a `tumbling` con velocidad de caída **cero** (cae por gravedad desde donde estaba, sin inercia horizontal).
3. Cuando toca el suelo (`isOnGround` y la caída alcanza la altura), pasa a `onGround`; si es volador reproduce `hitFloor`.
4. Al terminar esa animación en el suelo: `dead` y `spawnSoul` → **el alma aparece donde quedó el cadáver en el suelo** (`soulPosition`).
5. Si cae sobre un agujero sigue en `tumbling` (no toca suelo); el port ya gibea a quien cae bajo la tierra [PORT `unit_body.gd:594-603`, cita `state.d:14800-14821`].

El port ya hizo esto en el commit bb324052 («un volador muerto cae… el cadáver y el alma quedan en el suelo»).

---

## Resumen ejecutivo

- El original tiene **53 hechizos no-criatura** (2 neutrales, 6 de estructura, 9 por dios ×5) y **51 criaturas** invocables (Manahoar + 10 por dios).
- El port tiene los 53 en datos, pero solo **12 lanzables**: Manalith, Guardian, Convert, Desecrate, Teleport, Speed Up, Heal y el nivel 1 de cada dios (Wrath, Fireball, Rock, Lightning, Insect Swarm).
- **Faltan 41**: Shrine + los niveles 2 a 8 de los cinco dioses (8 por dios).
- Nivel = `spell_order/100`; los hechizos van del nivel 1 al 8; Shrine es nivel 3.
- **196 edificios** BLDG: 11 altares, 5 manantiales, 5 manalith, 5 shrines, 20 refugios, 50 destructibles y 100 indestructibles. **0 modelos faltantes**; 82 se usan en los mapas portados y unos 114 están importados pero sin uso.
- Shrine: tiene modelo y datos (los mismos flags de objetivo que Manalith: sobre un manantial), pero no tiene acción.
- Deforman terreno: **Volcano** (permanente: queda el 25 % del monte más un cráter de 25 m de radio y 10 m de hondo), **Bombardment** (abolladuras permanentes de 15 m de radio y 1.2 m de hondo), **Erupt** (subida temporal de 15 m durante unos 5 s), **Bore** (agujeros temporales que se reponen) y la habilidad **Quake** del Jabberocky (temporal).
- En el original, la altura es base + un desplazamiento por vértice en una rejilla de 256×256 cada 10 m; todo lo que toca el suelo lo lee en cada tick. El pathfinding (512×512, celdas de 5 m) **ignora el desplazamiento** y solo reacciona a los agujeros.
- El terreno del port es inmutable: datos `MapTerrainData`, colisión trimesh creada una vez, `ground_height` sale de un índice de triángulos y el navmesh se hornea offline. El re-horneado en partida existe, pero es de todo el mapa (un par de segundos en un hilo).
- Doctor muerto mientras carga (`move`): la criatura **cae viva y aturdida** hacia la posición del doctor. Su alma ya se había removido; si después muere, el alma nueva sale donde queda el cadáver.
- Doctor muerto durante `pump`: la criatura revivida **vuelve a morir** ahí mismo y su alma re-emerge en el cuerpo. Si muere antes de recogerla, el alma queda libre y convertible otra vez.
- Regla de giro: en tierra la velocidad **siempre va según el facing**, y esquivar también es girar. Solo el mago puede ir marcha atrás, por comando del jugador; la IA nunca.
- Velocidad de giro igual para todos: **π rad/s en tierra** y unos 119°/s volando (con aceleración angular de 3π rad/s²). Los empujes externos mueven sin girar.
- Aldeanos: un golpe con la vida llena genera rencor, que la manada comparte. Con refugio a ≤50 m huyen del enemigo a ≤50 m; sin refugio se encogen. La regla exacta del exe está **NO VERIFICADA**, y el port ya lo implementa.
- Volador muerto: termina `flyDeath`, cae por gravedad sin inercia, hace `hitFloor`, y el alma aparece en el suelo donde queda el cadáver. El port ya lo tiene (bb324052).
