# RFC-024 · Adenda 1: poblados y NPC (revisión del tech lead)

Estado: propuesta, falta el OK del usuario. **Reemplaza** las secciones 1.4, 2, 3.1, 3.2 (se suman filas), 3.3 (se suma), 5.2 (se suman campos), 6, 7, 8 y 9 de `RFC-024-single-player-ai.md`. Las demás (0, 1.1, 1.2, 1.3, 4, 5.1, 5.3, 5.4, 10) quedan como están.

Pedido del usuario: «agregar los poblados, son parte importante del gameplay, matar a los "npc" son parte de la economía de almas». Dato del usuario: «hay "casas" y "criaturas" que no atacan pero pueden ser atacadas para quedarse con sus almas». Regla del usuario para la investigación: **usar REA, buscar en la web, no inventar nada**. Hay una investigación aparte en curso (`docs/archive/rfcs/research/poblados-npc.md`); donde difiera de esta adenda, manda la investigación con evidencia.

**Qué cambia respecto de lo que dijo el usuario**
- Confirmado en parte: las criaturas pasivas existen (26 Farmer, que nunca atacan). Pero **las casas no dan almas**: destruir un edificio no deja alma en sacengine (`state.d:8376-8380`).
- El mapa trae además **6 Taurock** hostiles a todos: pegan, 1920 de vida, 2 almas cada uno.
- **Esas almas no se juntan caminando.** En sacengine el alma de un NPC es roja para los dos jugadores y queda pegada al cadáver. Se obtiene con **Convert**, o reventando el cadáver (sacengine solo lo hace con la opción `alwaysGib`). Pregunta 5.
- **La IA original no tiene tarea «cazar aldeanos».** Sus criaturas los atacan cuando los ven y el mago convierte esas almas: comportamiento emergente. Pregunta 6.
- Nuevo corte **024b2 «Poblados y NPC»** antes del cerebro. Features: F71 = 024a, F72 = 024b, F73 = 024b2, F74 = 024c, F75 = 024d, F76 = 024e, F77 = 024f. F70 sigue reservada para el pasto.
- Riesgo de rendimiento nuevo: 32 cuerpos más; `BodySeparation` ya cuesta ~7 ms/tick con 60; con ~92 se estima ~16 ms/tick (estimación, no medido). 024b2 trae grilla espacial.

## 1.4 Lo que ya existe en el port y se reutiliza *(reemplaza)*

- Lanzar, convocar y estructuras: `Caster.request_cast`, `request_summon`, `request_structure` (en servidor o solo corren `_try_*` con las mismas validaciones: maná, almas, enfriamiento, blanco, `SpellAction.check`).
- Hechizos de Estructuras: Manalith, Guardian, Convert (F61), Desecrate, Teleport.
- Órdenes: `Orders._apply` valida el dueño; por unidad, `UnitOrders`. `WizardBody.begin_walk`.
- Fantasma (F31), maná por fuente (F22).
- Almas (F30): `SoulSystem` crea el alma al caer el cadáver; el color depende de quién mira; la roja pegada al cadáver no se junta. Convert (F61) convierte cualquier alma roja.
- Ritual, derrota y cartel: F57, F59, F60. `MatchBiome`. `WizardSpawner.spawn_slot(slot)` (público). `UnitSpawner` instancia `unit.tscn`. Suite `debug/rules_suite`.
- **Datos de NPC ya en caché:** `cache/data/creatures.json`: Peasant (`saep`), Snowman (`zepa`), Zombie (`zepd`), Farmer (`zepe`), Slave (`zepf`): 1 alma, 500 de vida, 7,25 m/s, agresividad 0, vista 50, `behavior_flags 256`. Taurock (`raeb`): 2 almas, 1920 de vida, agresividad 1000, vista 100. Mallas `epez`, `peas`, `eber` horneadas en `cache/baked/bodies`.

**No existe:**
- La carga de criaturas y edificios del NTTS (hoy solo widgets: `tools/export_high_noon_widgets.py`; `grep jhut|bld1|epez` en `scenes/`, `tools/`, `data/` no encuentra nada).
- Modelos de casas de James (`jhut`, `bld*`, `jcc*`…); solo están horneados los props de Persephone (`huta`, `pch2`, `pch3`, `silo`…).
- El comportamiento de campesino (encogerse, huir, rencor).
- La relación entre bandos del mapa (hoy cualquier otro `owner_slot` es enemigo).
- `%Creature` de `high_noon.tscn` es la malla quieta de F5, no un NPC.

Gotchas: `Orders.request()` usa `MpKit.local_slot()` (0 en el dedicado). Azar sin semilla: `unit_body.gd:209`, `ghost_form.gd:69`, `body_separation.gd:172-178`, `match_biome.gd:49`.

## 1.5 Poblados y NPC *(nueva)*

### Verificado en los datos del mapa [O]
Del NTTS y SIDS de `/Users/joelsartori/Downloads/sacgame/Sacrifice/maps/(2) High Noon.scp` (estructura de `ntts.d`, `sids.d:31-41`):
- **Criaturas:** 26 `zepe` (Farmer, malla `epez`) en el bando 2; 6 `raeb` (Taurock, malla `eber`) en el bando 3. Sin flags.
- **Edificios en el bando 31 (neutral):** 5 manantiales `jfnt` (los 2 altares `jaal` son de los bandos 0 y 1) y 69 más: `jhut` ×5, `bld1` ×3, `bld2` ×6, `bld3` ×3, `bon1` ×2, `bon2` ×2, `bon4` ×2, `bon5` ×1, `bon6` ×3, `jcc1` ×11, `jcc2` ×6, `jcc3` ×8, `jcc4` ×6, `jeg1` ×1, `jeg2` ×3, `jeg3` ×1, `jwg1` ×6. Casas `jhut` en (1070,1075), (1255,1214), (1313,1239), (1239,1300), (1293,1317) (ejes sacengine x, y); la mayoría forma una aldea alrededor del manantial central (1270,1270). Qué son `bld*`, `bon*`, `jcc*`, `jeg*`, `jwg*` está **inferido por el nombre** (edificios, huesos, cercas, huevos, carros); se confirma en 024b2.
- **Relaciones (SIDS):**

| Bando | Aliados | Enemigos | Asignación |
|---|---|---|---|
| 0 | — | 14 (bandos 1, 2, 3) | 33 (un jugador + jugador 1) |
| 1 | 2 | todos menos él | 2 |
| 2 (Farmers) | 4 | todos menos él | 0 |
| 3 (Taurocks) | 8 | todos menos él | 0 |
| 31 | neutral | — | — |

Los Farmers y los Taurocks son enemigos de los dos jugadores y entre sí.

### Verificado en sacengine [S]
- **Campesinos:** tags `zepa`, `zepd`, `zepe`, `zepf`, `saep` (`nttData.d:133`, `sacobject.d:672`). No seleccionables (`state.d:1135`). Caja de golpe ×1,6 en planta (`sacobject.d:468-471`). 250 de experiencia (`sacobject.d:200`; fuera de alcance).
- **Comportamiento sin orden** (`updateCreatureAI`, `state.d:13732-13752`): con **refugio** a ≤ 50 m (`shelterDistance` 13610) busca al enemigo más cercano a ≤ 50 m (`scareDistance` 13611) y **corre en sentido contrario**; sin enemigo se queda quieto. **Sin refugio**, se **encoge** (`startCowering`). Refugio = edificio con flag `shelter` (1<<15, «TODO: correct?» en `bldg.d:11`) **o un altar** (`sacobject.d:968-970`). **No atacan nunca** (`patrol` exige `isAggressive`; agresividad 0).
- **Rencor** (`dealDamage` 8933-8936, `absorbHerdGrudges` 13634-13645): el primer golpe con vida llena anota al bando del atacante; los del mismo costo de maná a ≤ 80 m comparten el rencor y huyen de ese bando.
- **Almas:** al morir sale un alma con `Cre8.souls` (1 por campesino, 2 por Taurock), creada por `spawnSoul` (8382-8396) con `preferredSide` = bando del muerto. Para cualquier jugador es **roja** (`color` 1621-1630). **No se junta pegada al cadáver** (14951). Se libera con **Convert** (el ritual revienta la criatura y da las almas al lanzador: 16027-16032; rondas `int(vidaMáx/550)+1`: 1 para un Farmer, 4 para un Taurock) o **reventando** el cadáver (queda sin bando, azul, la junta cualquier mago: `gib` 8340-8365; `side` 1612-1615). sacengine solo revienta al morir con `alwaysGib` (9039-9046). No hay daño a cadáveres.
- **Solo los magos juntan almas, a 5 m**; las criaturas no (`canCollectSouls` 14895-14899, `collectDistance` 14939).
- **Los NPC no reaparecen** (no hay código que los cree tras cargar el mapa).
- **Edificios:** reciben daño si `maxHealth` ≠ 0. `destroy` (8376-8380) solo agrega el derrumbe: **destruir una casa no da almas**. Que una casa neutral sea blanco válido de ataque está **inferido**.
- **IA original (`shiny.d`):** `scanGlobal` sigue a todas las criaturas al empezar, Farmers y Taurocks incluidos, como categoría enemiga (1175-1183, `relation` 739-745). Sus criaturas los atacan por `patrol` al verlos. `wizAttack` incluye a cualquier criatura enemiga en `(1−amenaza)·280` m, peso ×0,5 o ×1/3 (3060-3071). **`wizRetreat` convierte** las almas que no puede juntar tocándolas (`findBestNear`, `enemyFlag=0`, 3005-3025, 3098-3114). **No hay tarea «cazar aldeanos»**: `CAPTURE` y `GUARD` apuntan a manantiales, Manaliths y altares (2118-2230). Almas azules: las junta el mago en `(1−amenaza)·100+80` m (3330-3337).

### Inferido, sin verificar en el exe
- Que el original no tenga daño a cadáveres (podría ser un hueco de sacengine). Verificar con REA en 024b2.
- Qué edificios son refugio (flag marcado «TODO»).
- Que los Farmers usen la FSM de campesino (sacengine enciende el rencor solo si el FSM del CRE8 es `saep`; los Farmer tienen `behavior_flags 256`). Verificar leyendo `behaviorFSM` del CRE8 de `zepe`.

## 2. Alcance *(reemplaza)*

Entra: partida en High Noon de 1 humano contra 1 mago IA con los 5 dioses y el sorteo de bioma; victoria/derrota por profanación (F60) y desvanecimiento (F57), fantasma (F31); **poblados y NPC del mapa** (26 Farmers y 6 Taurocks con sus bandos; 69 edificios neutrales con modelo, vida y refugio según su BLDG; campesinos que se encogen, huyen y guardan rencor; almas al morir, obtenidas con Convert; sin reaparición); economía de almas medida para el jugador y la IA; botón «Contra la IA»; IA de criaturas con elección de blanco, pathfinding y visión por bando; dificultades como `.tres`; banco IA contra IA sin ventana con semilla; IA en el dedicado como prueba de humo.

Fuera: mapas de 3–4 jugadores y N rivales; alianzas; modos `slaughter`/`domination`/`soul-harvest`; campaña; `DangerGrid`; experiencia y niveles (los 250 de XP del campesino no hacen nada todavía); reventar cadáveres con daño (salvo opción B/C de la pregunta 5); sonido; arte nuevo (las casas usan el modelo del instalador por bioma; si falta, placeholder con aviso, como F37).

## 3.1 Árbol de archivos *(reemplaza; ★ = poblados)*

```text
tools/
├── export_high_noon_ntts.py ★   # NTTS (criaturas + edificios + bando) y SIDS → cache/high_noon_ntts.json
└── export_stats.py (mod) ★      # + BLDG: maxHealth, flags (shelter), componentes → cache/data/buildings.json; + drain en CRE8
scenes/world/map/ ★
├── map_population.gd            # MapPopulation (%Population en high_noon): pone NPC y edificios del NTTS; criaturas solo en servidor o solo
├── side_relations.gd            # SideRelations (RefCounted): matriz aliado/enemigo/neutral del SIDS; si falta, «otro slot = enemigo»
└── map_building.tscn / .gd      # MapBuilding: modelo por componentes BLDG, Health si maxHealth > 0, refugio, owner_slot 0
scenes/world/units/
├── peasant.tscn ★               # heredada de unit.tscn: + PeasantBehavior, idle_aggro apagado
├── peasant_behavior.gd ★        # encogerse / huir del enemigo a ≤ 50 m con refugio a ≤ 50 m; rencor
├── grudge_memory.gd ★           # bandos anotados al primer golpe; se comparte con la manada a ≤ 80 m
└── target_picker.gd             # (sin cambios)
scenes/world/ai/ …               # árbol de §3.1 original
├── brains/phases/convert_phase.gd   # también cubre almas de NPC (misma regla de wizRetreat)
└── ai_audit.gd                      # + libro de almas: inicio, juntadas, convertidas, gastadas y origen (npc / criatura / mago)
scenes/world/nav/, scenes/world/vision/   # sin cambios
scenes/world/body_separation.gd (mod) ★  # grilla espacial (riesgo 6), mismo resultado dentro del empate sembrado
data/ai/                          # sin cambios
debug/
├── village.tscn ★                # High Noon + village.tres: mago humano a 30 m de la aldea central, NPC en pausa
├── rules/village.tres ★  village_cower.tres ★  village_taurock.tres ★  ai_no_souls.tres ★  ai_vs_trivial.tres …
└── (ai_match, ai_side_trivial, nav_cross, target_pick, ai_summon, ai_defend, ai_guard, ai_endgame)
agent/flows/pt024b2_*.json ★
```

Se modifican además: `high_noon.tscn` (+ `%Population`); `unit_body.gd` (`is_foe`/`_is_valid_foe` consultan `SideRelations`; un pacifista con agresividad 0 no ataca, como hoy); `unit_spawner.gd` (`spawn_map_creature(tag, slot, transform, scene)` elige `peasant.tscn` si el tag es de campesino); `soul_system.gd` (el alma de los slots 3 y 4 es roja para todos; revisar que no suponga dos jugadores); `convert_action.gd` (acepta almas de slot no jugador; verificar); `side_colors.gd` (slots 3 y 4 sin color de jugador); `ai_perception.gd` (NPC como enemigos, como `relation`).

**Slots del port:** slot = bando de sacengine + 1: jugadores 1 y 2, Farmers 3, Taurocks 4. Edificios neutrales: `owner_slot 0`.

## 3.2 Filas que se suman al mapa de responsabilidades

| Pieza | Responsabilidad | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `export_high_noon_ntts.py` | sacar NPC, edificios y bandos a caché | Herramienta | No se commitean datos del original |
| `MapPopulation` | poner lo del NTTS en el mundo al cargar | Nodo | `map_props` pone a mano; mezclar confunde |
| `SideRelations` | ¿A y B son enemigos? | RefCounted | Lo consultan unidad, almas, IA y visión |
| `MapBuilding` | una casa: modelo, vida, refugio | Packed | 69 instancias de la misma escena |
| `peasant.tscn` | variante de la unidad para campesinos | Packed heredada | Sin `PeasantBehavior` = unidad pasiva común |
| `PeasantBehavior` | encogerse o huir | Nodo hijo | `unit_body.gd` ya tiene 832 líneas |
| `GrudgeMemory` | rencor por bando y manada | Nodo hijo | Lo usan `PeasantBehavior` y quizá `TargetPicker` |
| Libro de almas (`AiAudit`) | origen y destino de cada alma | Nodo | Base de los criterios de economía |

## 3.3 Resource, nodo, @export *(se suma)*

Los números de campesinos van como `@export` en `PeasantBehavior` con cita: `shelter_distance 50`, `scare_distance 50`, `herd_range 80`. Los tipos de NPC ya son `CreatureType` desde `GameData`. No se commitea nada del original: posiciones, bandos y BLDG salen de `cache/`. `@export` de instancia: en `MapPopulation` `ntts_path`, `spawn_creatures` (por defecto encendido solo en `high_noon.tscn`), `building_scene`, `peasant_scene`; en `MapBuilding` `tag`, `max_health`, `shelter`, con aviso si falta el modelo.

## 5.2 Campos que se suman al informe de `ai_match`

Por bando: `souls_ledger{start, collected, converted, spent, now, by_origin{npc, creature, wizard}}` con criterio fijo `now == start + collected + converted − spent`; `npc_kills{farmer, taurock}`, `npc_alive_end{farmer, taurock}`. Del mundo: `npc_spawned{farmer, taurock}`, `buildings_placed`, `shelters`.

## 6. Cortes *(reemplaza)*

Orden de cada corte: developer → reviewer (vuelve a correr los mismos comandos y compara el `digest`) → playtester con ventana (`--max-fps 60`, un proceso) → el orquestador mira las capturas.

### 024a — Semilla y banco (F71). Sin IA.
Igual que la versión aprobada: `debug/ai_match.tscn` con `rules/ai_duel_seeded.tres` (6 Trogg vs 6 Druid a 60 m, en pausa hasta `check_tick`); dos corridas `--seed=7 --minutes=2` dan el mismo `digest`, `--seed=8` otro; ≤ 60 s y RSS ≤ 1,5 GB; `rules_suite` PASS; `f26_duel` y `f27_orders` AGENT_OK. Playtest: Enter → pelean → «Terminado · semilla 7».

### 024b — Navegación, visión y elección de blanco (F72)
Sin cambios respecto de la versión aprobada.

### 024b2 — Poblados y NPC (F73) ★ nuevo, antes del cerebro
- **Piezas:** exportadores NTTS/SIDS/BLDG; `MapPopulation`, `SideRelations`, `MapBuilding`; `peasant.tscn`, `PeasantBehavior`, `GrudgeMemory`; grilla espacial en `BodySeparation`; ajustes de `SoulSystem`, `SideColors`, `ConvertAction` para slots 3 y 4. Antes de fijar números: comprobar con REA el flag de refugio y si existe daño a cadáveres; cada número queda «verificado [O]» o «según [S]».
- **Escena:** `debug/village.tscn` (High Noon con `rules/village.tres`): mago humano Persephone (1000 de maná, 0 almas, más el Druid propio `Hunter` seleccionado) a 30 m de la casa `jhut` (1255,1214); NPC en pausa «Aldea en pausa». Variantes: `village_cower.tres` (un Farmer suelto a > 50 m de todo refugio), `village_taurock.tres` (`Taurock1` a 70 m de `Hunter`; a 80 m no elige blanco, ver Taurock). Corrección tras 024b2: el altar propio de High Noon queda a cientos de metros de la aldea, así que **Convert se demuestra en `village_cower`** (Farmer6 sin refugio, mago a 15 m, altar propio movido a (1085, 1090) en esa escena); en `village` el Farmer huye y muere lejos del mago.
- **Acciones:** `check_tick` (Enter) despierta a los NPC; `order_units` sobre un Farmer; pestaña Estructuras → `spell_3` → clic en el alma roja.
- **Criterios:**
  - Carga, sin ventana: consola `npc farmer 26 slot 3 · taurock 6 slot 4 · edificios 69 · refugios <n>` coincidente con el NTTS; posiciones a ±0,5 m; en un cliente del dedicado la cantidad de `%Units` es la misma.
  - Pasivos: 120 s con `Hunter` pegándole a un Farmer → 0 golpes del Farmer; vida máxima 500 (Hunter lo puede matar); velocidad 7,25 ± 0,2 m/s.
  - Huida: con refugio y `Hunter` a ≤ 50 m, el Farmer se aleja ≥ 10 m en 3 s.
  - Encogerse: con `village_cower`, modo COWER y se mueve < 0,5 m en 10 s.
  - Rencor: el primer golpe pone el slot 1 en la `GrudgeMemory` de todos los Farmers a ≤ 80 m en ≤ 1 s.
  - Taurock: **elige blanco** a `Hunter` en ≤ 5 s cuando está a ≤ 70 m. El corte del puntaje de 024b (patrulla 0,25, peso de criatura 1,25) es 100·(1−0,447)/0,75 = 73,7 m [S state.d:12925-12935]; los 100 m son su vista, no el alcance de la elección. Medido: a 80 m no elige en 20 s; a 70 m elige en 0,12 s. El primer golpe llega cuando lo alcanza (6 m/s: ~12 s a 70 m).
  - Almas: un Farmer muerto deja un alma de 1, roja para slots 1 y 2; el mago parado encima no la junta («Almas 0» 10 s); con Convert en `village_cower`, «Almas 0» → «Almas 1» en ≤ 60 s desde el clic (medido 38,8 s); un Taurock convertido da +2; el libro de almas cuadra.
  - Casas: destruir una `jhut` con vida > 0 da 0 almas; si su BLDG dice vida 0, es indestructible y la consola lo informa.
  - Sin reaparición: tras matar a todos los Farmers, `npc_alive_end.farmer == 0` a los 10 min.
  - Rendimiento: `ai_match` con NPC + 60 criaturas, `sep_ms` medio ≤ 4 ms, informado junto a la medida previa.
  - Regresión: `f22_mana`, `f30_souls`, `pt61b`, `pt60`, `f20_solo` AGENT_OK; las escenas que no quieren NPC los apagan con `spawn_creatures = false`.
- **Playtest:** capturas de la aldea con Farmers y casas, un Farmer huyendo y otro encogido, el alma roja sobre el cadáver, y la conversión con «Almas 1».

### 024c — Cerebro mínimo: convoca, ataca y defiende (F74)
Piezas, escenas y criterios como en la versión aprobada, más: **sin almas no convoca** (`rules/ai_no_souls.tres`, 0 almas, sin NPC muertos a mano, sin ventana, semilla 1, 3 min: `summons == 0` incluido Manahoar que cuesta 1 alma; `rejections["Sin almas"] == 0`; libro de almas cuadra); **percepción de NPC** (desde t = 0 los 26 Farmers y 6 Taurocks están en `AiPerception` como enemigos por `scanGlobal`; un NPC que muere sale en ≤ 1 s); **ataque a NPC** (en `ai_summon`, una criatura de la IA ataca a un Farmer que entra en su vista en ≤ 2 s).

### 024d — Economía, captura y profanación (F75)
Piezas como la versión aprobada; `ConvertPhase` cubre las almas de NPC. Criterios con `ai_match` + `rules/ai_vs_trivial.tres` (NPC encendidos), semillas 1–5, 30 min: primer Manalith ≤ 6 min en ≥ 4/5; victoria de la IA por ritual ≤ 30 min en ≥ 4/5; **economía de almas:** `npc_kills` de la IA ≥ 5 a los 10 min en ≥ 3/5, `souls_ledger.by_origin.npc` ≥ 3 a los 10 min en ≥ 3/5, libro exacto en 5/5, ninguna convocatoria con almas insuficientes, toda alma de NPC llega por Convert (o tocándola si rige la opción B de la pregunta 5); `ai_guard` ≥ 2 criaturas defienden en ≤ 5 s; ningún `Desecrate` rechazado por «Blanco inválido». Las cifras de NPC son de partida: si la línea base de sacengine (§5.3) las desmiente, se ajustan con evidencia. Playtest: la IA convirtiendo un alma de Farmer y el final con `ai_endgame`.

### 024e — Dificultades y perfiles por dios (F76)
Como la versión aprobada, y el rendimiento `ai_perf60` (`ai_ms` medio ≤ 0,5, p99 ≤ 2, máx ≤ 6) ahora **con los 32 NPC presentes**; libro de almas exacto en las tres dificultades.

### 024f — Partida contra la IA completa (F77)
Como la versión aprobada, más: en la partida del jugador se ven la aldea y los NPC; en el dedicado el cliente ve los 32 NPC; regresión `f20_solo`, `f21_pick`, `f24_cast`, `f25_summon`, `f30_souls`, `f31_ghost`, `pt60`, `pt61b`, `pt64` AGENT_OK.

## 7. Riesgos *(reemplaza)*
1. Tamaño de `shiny.d` (3442 líneas): fidelidad de comportamiento, no de bits.
2. Pathfinding: cambia también el movimiento del jugador (pregunta 3); regresión de flows.
3. Determinismo de la física: solo en la misma máquina; verificar el motor 3D.
4. Datos que faltan: `drain`, `amount2`; BLDG (vida, refugio, componentes).
5. Visión aproximada (sin línea de vista ni campo de visión al principio).
6. **Rendimiento con NPC ★:** ~92 cuerpos; `BodySeparation` O(N²) ≈ 7 ms/tick con 60 (F66), ≈ 16 ms con 92 (estimado). Grilla espacial en 024b2; medir también los sincronizadores en el dedicado.
7. **Supuestos de dos jugadores ★:** slots 3 y 4 pueden romper colores, HUD, `DefeatRule.kill_creatures`, selección y almas; el reviewer de 024b2 busca cada `owner_slot ==` y `% 8`.
8. **Reglas inciertas ★:** refugio (flag «TODO» en sacengine), daño a cadáveres, FSM de los Farmers: verificar con REA; si no alcanza, quedan «según [S]».
9. **Modelos de las casas ★:** los props `j*` de James no están horneados y el bioma cambia el tileset; tabla por bioma o placeholder con aviso.
10. Línea base de sacengine con ventana: proceso pesado, corre solo.

## 8. Preguntas para el usuario (decisiones tomadas: 5 → A, 6 → A)
Aprobadas: 1 (dificultades Fácil/Normal/Difícil sin trampa), 2 (1 rival IA), 3 (pathfinding también para el jugador), 4 (IA en el dedicado como humo). Nuevas (**RESUELTAS por el usuario, 2026-10-14: 5 = A, 6 = A**):
5. **¿Cómo se consiguen las almas de los NPC?** A (recomendada, fiel a sacengine): matar y **convertir** con el Sac Doctor; el alma queda roja y pegada al cadáver. B: las almas de los bandos NPC salen azules y el mago las junta caminando (más cerca de «matarlos para quedarse con sus almas», pero es un desvío). C: A más reventar cadáveres con daño de área, si REA confirma que el original lo hace.
6. **¿La IA caza aldeanos a propósito?** A (original, recomendada): no hay tarea de caza; sus criaturas atacan a los NPC que ven y el mago convierte las almas; los criterios de 024d miden si alcanza. B: sumar `HuntTask` con puntaje a aldeas cercanas cuando tiene pocas almas (desvío declarado, con `.tres` para apagarlo).

## 9. Orden de implementación *(reemplaza)*
1. 024a: semillas, corredor e informe con libro de almas.
2. 024b: `NavGrid`, `NavService`, `PathFollower`, `SideVision`, `TargetPicker`.
3. 024b2: (1) comprobación REA de refugio y daño a cadáveres; (2) exportadores NTTS, SIDS, BLDG; (3) `SideRelations` en `is_foe`; (4) `MapBuilding` y `MapPopulation` (primero edificios, después criaturas); (5) `peasant.tscn` con `PeasantBehavior` y `GrudgeMemory`; (6) ajustes de almas, colores y Convert para slots 3 y 4; (7) grilla de `BodySeparation`; (8) `village.tscn` y sus `.tres`; (9) regresión.
4. 024c: datos, cuentas puras, percepción con NPC, postura, grupos, puerto de comandos, registro, tareas Idle y Guard, cerebro con Summon y Attack, cerebro de criatura, `ai_summon`, `ai_defend`, `ai_no_souls`.
5. 024d: `CaptureTask`, `ManahoarBrain`, `ConvertPhase` con almas de NPC, `SupportPhase`, almas y fantasma, bot trivial, `ai_guard`, `ai_endgame`.
6. 024e: dificultades, perfiles y rendimiento con NPC.
7. 024f: asientos, `AiRoster`, botón y selector en boot, dedicado y regresión.

## Archivos citados
`/Users/joelsartori/Downloads/sacgame/Sacrifice/maps/(2) High Noon.scp`; `sacengine/source/{ntts.d, sids.d, nttData.d, sacobject.d, bldg.d, state.d, bots/shiny.d}`; `game/tools/{export_high_noon_widgets.py, export_high_noon_look.py}`; `game/cache/data/creatures.json`; `game/cache/baked/props.json`; `game/scenes/world/units/corpse.gd`; `game/scenes/world/unit_body.gd`.

## Adenda 1.1 — Resultados de la investigación con REA, datos y web (2026-10-15)

Fuente: `docs/archive/rfcs/research/poblados-npc.md`. Donde difiere de lo anterior, manda esto.
- **Confirmado:** hay habitantes pasivos (Peasant `saep`, Snowman `zepa`, Zombie `zepd`, Farmer `zepe`, Slave `zepf`): agresividad 0, 500 de vida, 1 alma, `behavior_flags` 256 [DATOS]. El manual oficial los describe como «almas esperando ser convertidas» y dice que en multijugador conviene matarlos para juntar sus almas [DOC].
- **Refugios (corrige 1.5):** solo las **11 estructuras** `jhut` ×5 y `jwg1` ×6 de High Noon tienen la marca de refugio (bit 15 del BLDG original) [DATOS]. Los demás edificios (`jcc*`, `bld*`, `bon*`, `jeg*`) no la tienen; qué son exactamente: [NO ENCONTRADO]. Casi todos los Farmers están a < 57 m de un refugio.
- **Casas destructibles:** tienen 5000 de vida [DATOS]; el exe tiene la función de script `DestroyHut` [REA 0x4cc04c]. Qué hace al destruirse: [NO ENCONTRADO]. Destruir un edificio da solo XP, no almas [SAC state.d:8376-8380, 9156].
- **Almas:** el alma de un campesino es roja y no se junta caminando; se obtiene con Convert (Sac Doctor). Si la criatura revienta («gib»), deja un alma azul que cualquier mago toma [DOC; SAC]. Solo el mago vivo recoge, a ≤ 5 m. Existe el comando de depuración «Wizard can now collect red souls» [REA 0x4c687c, 0x4c68a0], lo que confirma que por defecto no se pueden recoger.
- **Gib chance:** el original tiene una opción de probabilidad de reventar que sacengine no implementa (solo `alwaysGib`). Es la base posible de la opción C de la pregunta 5, que el usuario descartó (eligió A); queda anotada.
- **Tope de almas:** la única pista es la rutina de depuración «dar almas» del exe, que llena hasta 32 (`cmp [wizard+0xb44], 0x20`, «Wizard has too many souls»), leída de bytes, no de código decompilado. **Inferido**, no verificado para partida normal.
- **Comportamiento:** el FSM `norm` de `fsm.wad` tiene los estados Cower, «Working the fields», Talking, Disgusted, Laughter, Double take, Sorrow, Ambivalence; el exe tiene `PeasantSetWorkAnimation` [REA 0x4cf144]. La lógica de transición no se decompiló. La regla de huida (refugio ≤ 50 m, enemigo ≤ 50 m) es de sacengine, que la marca «TODO: figure out the original rule» (`state.d:13732-13760`); el manual dice que huyen cerca de su aldea y se encogen en las afueras [DOC].
- **IA original:** `shiny.d` no menciona campesinos, aldeas ni refugios; no hay tarea de caza (inferencia consistente con la decisión 6 = A).
- **No confirmado:** significado exacto del bit de refugio y distancias en el exe; el rol de los Taurock; XP por campesino (250 es estimación de sacengine); wiki de fandom (HTTP 402) y GameFAQs (403) no accesibles, así que las misiones de la Boon Guide («matar a todos los Peasants», «no convertir las almas de la aldea») quedan [NO ENCONTRADO].
- **Consecuencia para 024b2:** el criterio «refugios <n>» pasa a ser **11** (5 `jhut` + 6 `jwg1`), no los 69 edificios; el tope de almas del banco se marca «inferido (32)»; los Farmers que viven lejos de un refugio se encogen en lugar de huir.
- **REA:** el snapshot existente dio `evidence_integrity_mismatch`; se analizó el exe de cero con un snapshot nuevo (JDK 21, `GHIDRA_HEADLESS_MAXMEM=3G`, pico ~1,5 GB). `xrefs` no resolvió las cadenas `DestroyHut` y `PeasantSetWorkAnimation`: solo hay evidencia de que existen.


## Adenda 1.2 — Criterios corregidos tras 024d (2026-10-15, decisión del orquestador por delegación del usuario)

- **`ai_no_souls` (024c):** desde 024d la IA puede matar un NPC, convertir su alma y convocar con ella; «`summons == 0`» deja de ser el criterio. Nuevo criterio: toda convocatoria con `souls_before ≥ cost_souls`, `rejections["Sin almas"] == 0`, libro de almas exacto. Para medir «sin almas no convoca» en aislamiento, `ai_no_souls.tres` con `spawn_creatures = false`.
- **Costo de la IA:** el criterio `ai_ms` se mide sobre el tick completo (decisiones + llamadas al juego); `ai_ms.decisions` es diagnóstico.
- **Desvíos de 024d anotados:** escalonado de ranuras k3/k5 (3 y 6 ticks; shiny.d:459-500 los corre juntos); `_check_jam` del mago (workaround del port, no del original; ver REVIEW-RFC-024d §2); rama «cazar al mago enemigo» de `replanCapture` (shiny.d:2147-2151) omitida.

## Adenda 1.3 — Fácil y rendimiento tras 024e (2026-10-16, decisión del orquestador por delegación del usuario)

Medido en 024e: Normal le gana a Fácil 2/5, y Fácil convoca el 124 % de lo que convoca Normal. La causa es que las convocatorias las limita el maná, no el ritmo de decisión, y con agresividad 0,6 Fácil vuelca en criaturas el maná que no gasta en atacar. El `ai_ms` falla en p99 (2,74) y en el máximo (10–11 ms en el tick 0).

1. **Fácil se frena a sí mismo, sin trampa:** se agrega `AiDifficulty.summon_interval_s` (segundos mínimos entre convocatorias; Normal y Difícil 0) y `AiDifficulty.mana_reserve` (fracción del maná máximo que Fácil no gasta en convocar; Normal y Difícil 0). Son límites que la IA se pone a sí misma: no tocan los recursos ni las reglas. Los valores iniciales los elige el developer para cumplir los criterios, con una sola tanda.
2. **Criterios de Fácil, sin cambios:** Normal gana ≥ 4/5 en 20 min, y las convocatorias de Fácil a los 5 min son ≤ 70 % de las de Normal.
3. **Rendimiento:** el máximo se mide desde el tick 60, porque el tick 0 (escaneo inicial del mapa) se reparte en el corte de rendimiento. El p99 ≤ 2 ms y el máximo ≤ 6 ms del tick completo pasan a ser criterio de RFC-027: el exceso lo pone el propio juego (convocatorias y caminos), no la IA. En 024e se exige `ai_ms` p99 ≤ 2 ms **contando solo el cerebro** (`decision_ms`), y se informa el tick completo.

## Deuda de determinismo (2026-10-16, REVIEW-F95 H1)
Lo probó el reviewer de F95 en Godot 4.7.2: `CPUParticles3D.new()` y `restart()` consumen el RNG global, el mismo que siembra `MatchSeed`. En headless no pasa, pero en una partida con ventana (solo o contra la IA) cada efecto visual mueve la secuencia de azar de la simulación. Por eso la misma semilla puede dar otra partida con ventana que en headless.
- **Mitigación parcial:** en F95, las partículas reciben semilla fija desde un RNG propio de `FxBus`.
- **Arreglo de fondo, pendiente:** que la simulación (IA, reglas y spawns) use un `RandomNumberGenerator` propio de `MatchSeed`, nunca el global. Así ningún nodo de presentación puede alterar la partida. Va como corte propio después de F95. El digest va a cambiar y hay que declararlo.

## Adenda 1.4 — Criterio de ejército de Fácil (2026-10-16, orquestador)
El ejército de Fácil se mide contra el humano inactivo (`ai_vs_idle`), no contra Normal: contra Normal, lo que se mide es la presión de Normal.
- **Criterio:** a los 10 min, ≥ 3 criaturas que no sean Manahoar, y que gane más tarde que Normal.
- **Medido con 40 s y reserva 0,15:** 8 Earthfling. Fácil gana a los 13,96 min y Normal a los 9,57.
