# RFC-024 — Single player: magos y criaturas controlados por la IA

> **Adenda vigente:** ver `RFC-024-addendum-poblados.md` (poblados y NPC). Reemplaza las secciones 1.4, 2, 3.1, 3.2, 3.3, 5.2, 6, 7, 8 y 9 de este documento; manda la adenda.

Estado: plan del tech lead, falta el OK. Arquitectura **estándar**. MP **online con dedicado** (MpKit, sin tocar el addon). Autoridad: PRD > FEATURES > RULES > VISUAL > RFC > este plan.
Pedido del usuario: «el modo single player. Necesitamos que la IA juegue también. Basate en sacengine, en el juego original, y usa REA si necesitas».
Fuentes:
- **[S]** sacengine `source/` (archivo:línea).
- **[O]** `Sacrifice.exe` original (`/Users/joelsartori/Downloads/sacgame/Sacrifice/Sacrifice.exe`). Su sha256 `a53ebb533e5b5f66…` es el mismo de `.rea-snapshots/sacrifice-exe`.
- **[P]** el port (`game/`).

Features reservadas: F71 a F76 (F70 la tiene reservada el pasto, `RFC-022e-grass.md` §12).

## 0. Contradicciones entre artefactos (gana el primero)

1. **El PRD no tiene IA.** Su fantasía es «Dos magos en High Noon. Cada uno manda desde su cliente», y fuera del primer corte deja «Campaña…». Gana el PRD. **Antes de implementar hay que sumar este pedido al PRD con `manage-changes`.** Este RFC queda como propuesta hasta entonces.
2. **RULES dice que la victoria vive fuera de `mp_kit`.** La IA también va fuera: sin RPC nuevos en el addon y sin tocar `MpSlotSpawner`.
3. **`SacrificeFlow.max_players = 2` choca con un dedicado que tenga un asiento IA.** Se resuelve en el glue del juego (§4), no en el addon.

## 1. Hallazgos

### 1.1 La IA del original en sacengine [S]: `bots/shiny.d`

Verificado: el archivo dice «port of the original ai (excavated from thaum.exe)». Cita direcciones de función del ejecutable, y los interruptores `beta*` separan la versión comercial (`Sacrifice.exe`, por defecto) de la beta (`thaum.exe`) (`shiny.d:381-412`). Este port sigue la **versión comercial**: todos los `beta*` en falso.

- **Una IA por bando.** Corre en cada tick de 60 fps (`state.d:15`, `29341` `updateBots`) con 6 ranuras de planificación.

  | Ranura | Período | Qué hace |
  |---|---|---|
  | k0 | 12 ticks | `updateStatus` |
  | k1 | 60 | `updateStance` |
  | k2 | 6 | `updateNtts` |
  | k3 | 6 | `updateGroups` |
  | k4 | 60 | `updateReplan` |
  | k5 | 12 | `updateTasks` |

  Fuente: `shiny.d:459-500`. Los eventos del juego adelantan las ranuras (`forceFlags`, `notifyEvent` `517-546`): muerte, aparición, edificio dañado o destruido, sacrificio, mago enemigo a 100 m de un edificio.
- **Percepción: qué sabe la IA.**
  - Al empezar hace `scanGlobal`, una sola vez: todos los edificios, magos y criaturas del mapa (`1175-1183`; «config is 0x10 at all three AI-creation call sites… runs once at setup», `1158`).
  - Después agrega lo propio por eventos y lo enemigo **solo cuando lo ve** (`botSeen` `616-635`, sobre `markVisibleNTTs` `state.d:12901`: alcance de vista, campo de visión, alerta y línea de vista).
  - Saca lo enemigo que no ve hace tiempo, salvo las criaturas, y saca a los magos fantasma (`discover` `1373-1401`).
  - Lo que ya sigue lo lee con la **posición real** (`updateBase` `1024-1038`).
  - Sigue solo lo que está en su misma región del pathfinder (`shouldTrack` `754-775`).
  - **Conclusión: no ve todo el mapa siempre, pero sabe todo al empezar.**
- **Evaluadores.** Cada criatura o mago se mide con 5 valores: cuerpo a cuerpo, habilidades, vida contra cuerpo a cuerpo, vida contra distancia y velocidad (`fillStats` `251-263`, `rate` `214`, `rateWithBase` `221-227`). Usan los números del CRE8 en la escala de archivo (`typeStats` `230-242`).
- **Postura y amenaza.**
  - `updateStance` (`1220-1288`) suma por categoría (propio, aliado, neutral, enemigo): maná, almas, Manaliths y proporción de fuerzas.
  - La **amenaza** del mago (`updateWiz` `1061-1085`) es la influencia enemiga dividida por la total, en un radio de 10 a 280 m y cada 8 ticks.
- **Tareas.** Se planifican (`replan*` `2096-2238`) y después se asignan criaturas (`claim*` `2240-2346`), en orden captura → guardia → ocio:
  - **CAPTURE**: manantial libre (construir Manalith); Manalith enemigo; **altar enemigo** (`flags 9`, rama del desecrado).
  - **GUARD**: edificio propio dañado, con amenaza o **bajo profanación** (puntaje 1.0).
  - **IDLE**: el resto.
- **Grupos.** Agrupa por cercanía con radio `30·min(1+0.1n, 1.8)` (`canAccept` `1702-1709`).
- **Cerebro del mago (`wizBrain` `3303-3387`).**
  - Replanifica cada 16 ticks. `weightTriple` (`2953-2966`) reparte el peso entre atacar, apoyar y convertir según la agresividad y la proporción de fuerzas.
  - Fases: `wizAttack` (hechizo contra criaturas enemigas a `(1−amenaza)·280` m; el Sac Doctor pesa ×10), `wizSupport` (cura o acelera a las propias), `wizRetreat` (Convert sobre almas rojas), `wizSacrifice` (Manahoar de emergencia o **convocar la mejor criatura** que puede pagar, solo con amenaza < 0.6; `3115-3172`).
  - Cola de lanzamientos ordenada (`enqueueCast` `2638-2662`). `executeBestCast` (`3201-3280`) se acerca si está fuera de alcance, **solo lanza lo que puede pagar** (`lightCanCast` `3174-3199`: maná, almas, enfriamiento, nivel, altar) y usa el mismo `startCasting` que el jugador.
  - Recoge almas a `(1−amenaza)·100+80` m.
  - **Desecrar:** si el registro apunta a un altar enemigo sin ritual en curso, elige la criatura propia con más almas (`pickGuardCreature` `3026-3050`), la acerca a 0.9 del alcance y lanza `ucas` (`3348-3370`).
  - **Manalith:** si el blanco es un manantial libre y la amenaza es < 0.9, lanza el primer hechizo de estructura de tipo manantial (`castCachedInRange` `3285-3301`).
  - **Fantasma:** se queda quieto y lo reviven sus Manahoars; si no tiene ninguno a 256 m, va al edificio de maná propio. Esto último es un **desvío declarado de sacengine** (`3306-3326`).
- **Cerebros de criatura.**
  - `t4oBrain` (`2557-2570`): si le falta maná, va a la mejor fuente propia (`autoCapture` `2546-2555`); si no, guardia o «interact» según la tarea.
  - `mahoBrain` (`2572-2608`): el Manahoar sigue al grupo con más déficit de maná.
  - Órdenes: **las mismas del jugador** (`issueOrder` `2350-2391`: move, retreat, guardArea, attack, advance, guard), con ostates traducidos.
- **No hay dificultad.** `aggression = 1.0` fija (`380`, `662`); ningún punto del código la cambia. Los bots se activan con `--bot-slots=`, `--bot-gods=` y `--bot-names=` (`app.d:253-276`, `lobby.d:81-95`). **No hay bonificación de recursos.**
- **Azar:** el `rand()` de MSVC (`ShinyRand` `31-38`), con semilla por bando. Divisiones protegidas contra NaN para que la red sea determinista (`safediv` `199-206`).

### 1.2 Micro de criaturas en sacengine [S] frente al port [P]

| Comportamiento | sacengine | port |
|---|---|---|
| Patrulla y autoataque | `patrol` `state.d:13029` | sí (`UnitBody._idle`, «más cercano») |
| Elección de blanco con puntaje | `updateTarget` `state.d:12943+`: `(1−0.75·d/100)²` (o `0.25·100/d` lejos), ×1.25 si no es edificio, ×1.2 último atacante, ×1.3 blanco actual, × factor de peligro, filtrado por **visible para el bando** | **no**: elige el más cercano |
| Huir del peligro | `retreatFromDanger` `12982`: `DangerGrid` ≥ 9 → se mueve 25/50 m a la celda menos peligrosa | **no** |
| Pathfinding | `PathFinder` grilla 512×512, componentes y `findPath` (`state.d:675-880`) | **no**: en línea recta; F57 anotó el mago trabado contra un manantial |
| Visión por bando | `markVisibleNTTs` y `lastSeenTick` | **no** |
| Cobardía o huida por vida baja | **no existe** (solo los campesinos se encogen) | — |
| Escolta, guardia, retirada, avance, ataque | `updateCreatureAI` `13647` | sí (`unit_orders.gd`) |

### 1.3 Juego original [O]

Verificado con `strings` sobre el ejecutable (mismo hash que el snapshot de REA):
- Están `AITASK_CAPTURE`, `AITASK_GUARD` y la consola `AI <side#> [START|STOP] [[+|-]INACTIVE] [[+|-]SHOWSTANCE] [[+|-]SHOWGROUPS]…`. Coinciden con las tareas y los grupos de §1.1.
- **No hay textos de dificultad** (easy/hard/difficult).
- High Noon es `(2) High Noon.scp`: 2 jugadores.

Inferido, sin verificar:
- Que no exista dificultad. La ausencia de textos no prueba nada.
- Que los magos de campaña (James, Pyro, Stratos, Persephone, Charnel) usen esta misma IA más guiones de misión (`trig.d`). La campaña queda fuera.
- Que el comportamiento por dios salga **solo del libro** (`wizSpellRebuild` `2610-2636`), sin personalidad propia.

REA no se corrió en este plan; el MCP no está conectado en la sesión. Uso en los cortes: comprobar con Ghidra (`.tools/ghidra_12.1.4_PUBLIC`) las constantes que sacengine marca como versión comercial frente a beta antes de fijarlas en `.tres`: 280 frente a 180, 100/80, 0.9 y 3620. Cada una queda marcada «verificado [O]» o «según [S]».

### 1.4 Lo que ya existe en el port y se reutiliza

- Lanzar, convocar y estructuras: `Caster.request_cast`, `request_summon` y `request_structure`. Del lado servidor o en solo corren `_try_*` con las mismas validaciones: maná, almas, enfriamiento, blanco y `SpellAction.check`.
- Hechizos de Estructuras: Manalith, Guardian, Convert, Desecrate y Teleport.
- Órdenes: `Orders._apply` valida el dueño. Por unidad, `UnitOrders`.
- `WizardBody.begin_walk`.
- Fantasma (F31), almas (F30) y maná por fuente (F22).
- Ritual, derrota y cartel: F57, F59, F60, F61.
- `MatchBiome`.
- `WizardSpawner.spawn_slot(slot)`, que es público.
- Suite `debug/rules_suite`.

Gotchas:
- `Orders.request()` usa `MpKit.local_slot()`, que vale 0 en el dedicado. La IA necesita una entrada con su propio slot.
- Fuentes de azar sin semilla:
  - `unit_body.gd:209` (`randomize`)
  - `ghost_form.gd:69`
  - `body_separation.gd:172-178` (`randi()` global)
  - `match_biome.gd:49`

## 2. Alcance

Entra:
- Partida en High Noon de **1 humano contra 1 mago IA**, con los 5 dioses y el sorteo de bioma que ya existe.
- Victoria y derrota por profanación (F60) y por desvanecimiento (F57). Reaparición como fantasma (F31).
- Un botón «Contra la IA» en `boot.tscn`.
- IA de criaturas: elección de blanco con puntaje, pathfinding y visión por bando.
- Perfiles de dificultad como `.tres`.
- Banco IA contra IA sin ventana y con semilla.
- IA en el dedicado: un humano contra la IA, como prueba de humo.

Fuera, para otros RFC:
- Mapas de 3 y 4 jugadores; con eso, N rivales.
- Alianzas y equipos.
- Modos `--slaughter`, `--domination` y `--soul-harvest` de sacengine.
- Campaña y guiones.
- `DangerGrid` y `retreatFromDanger`. Necesitan que los hechizos de área pinten peligro; van a un RFC de micro avanzado.
- Niveles y experiencia del mago.
- Hechizos del libro todavía «No implementado».
- Minimapa.
- Sonido.

## 3. Arquitectura por composición

La IA es un **jugador más**:
- No tiene RPC ni autoridad propia.
- Todo sale por un solo puerto, que llama a lo mismo que `match_command`.
- Existe solo donde se simula (servidor o solo).
- Sacar un hijo apaga ese comportamiento.

### 3.1 Árbol de archivos

```text
scenes/world/ai/
├── ai_side.tscn                 # un bando IA; hijos = piezas
├── ai_side.gd                   # AiSide: reloj de 6 ranuras, sockets, mide ms por tick
├── ai_roster.gd                 # AiRoster (nodo en high_noon): por asiento → pick + mago + AiSide
├── ai_audit.gd                  # AiAudit: registro de pedidos, motivos, costos y maná/almas antes y después → informe
├── perception/
│   ├── ai_perception.gd         # AiPerception: scanGlobal, alta/baja por eventos y visión, discover
│   └── ai_track.gd              # AiTrack (RefCounted): entidad seguida (pos, extrap, vel, flags, status, acc)
├── stance/ai_stance.gd          # AiStance: stanceRecs, strengthRatio, amenaza del mago, acc1/acc2
├── groups/ai_groups.gd          # AiGroups: formGroups4/5 y agregados
├── tasks/
│   ├── ai_task_board.gd         # AiTaskBoard: replan → claim → update, en orden de hijos
│   ├── ai_task.gd               # AiTask: contrato mínimo (replan, claim, cmd)
│   ├── ai_record.gd             # AiRecord (RefCounted): blanco, ancla, miembros, puntaje
│   ├── capture_task.gd          # CAPTURE: manantial, Manalith enemigo, altar enemigo
│   ├── guard_task.gd            # GUARD: edificio propio amenazado o profanado
│   └── idle_task.gd             # IDLE
├── brains/
│   ├── wizard_brain.gd          # AiWizardBrain: replan cada 16 ticks, weightTriple, almas, desecrar, Manalith
│   ├── cast_queue.gd            # AiCastQueue (RefCounted): forzados primero, puntaje, sin repetir tag
│   ├── phases/attack_phase.gd   # wizAttack
│   ├── phases/support_phase.gd  # wizSupport
│   ├── phases/convert_phase.gd  # wizRetreat (Convert)
│   ├── phases/summon_phase.gd   # wizSacrifice (Manahoar de emergencia + mejor criatura)
│   ├── creature_brain.gd        # t4oBrain + autoCapture
│   └── manahoar_brain.gd        # mahoBrain
├── command/ai_command_port.gd   # AiCommandPort: ÚNICA salida al juego
├── math/
│   ├── ai_rater.gd              # static: fillStats, rate, rateWithBase, combine, divide
│   ├── ai_field.gd              # static: probOr, densityGroups, influenceGroups, lerp, caídas
│   └── ai_rand.gd               # AiRand (RefCounted): rand() de MSVC
└── data/
    ├── ai_profile.gd            # AiProfile (Resource): constantes de la versión comercial, con cita
    ├── ai_difficulty.gd         # AiDifficulty (Resource): escala de reacción, agresividad, ruido
    └── ai_seat.gd               # AiSeat (Resource): slot, dios, mago, dificultad, perfil
scenes/world/nav/
├── nav_grid.gd                  # NavGrid: 512×512 (5 m), libre/ocupado desde Terrain, componentes, AStarGrid2D
├── nav_service.gd               # NavService (nodo %Nav en high_noon): arma la grilla una vez, find_path, component_at
└── path_follower.gd             # PathFollower: hijo de unit.tscn y wizard_body.tscn; meta → waypoints
scenes/world/vision/side_vision.gd      # SideVision (%Vision): último tick visto por bando y entidad
scenes/world/units/target_picker.gd     # TargetPicker: hijo de unit.tscn; puntaje de updateTarget
data/ai/
├── profile_original.tres        # números de shiny.d (versión comercial)
├── difficulty_easy.tres / difficulty_normal.tres / difficulty_hard.tres
└── seat_vs_ai.tres              # asiento por defecto de «Contra la IA» (slot 2, dios al azar, normal)
debug/
├── ai_match.tscn / ai_match.gd  # corredor: semilla, minutos, informe JSON; con o sin ventana
├── ai_side_trivial.tscn         # heredada de ai_side.tscn SIN CaptureTask ni AttackPhase (bot trivial)
├── nav_cross.tscn  target_pick.tscn  ai_summon.tscn  ai_defend.tscn  ai_guard.tscn  ai_endgame.tscn
└── rules/ai_duel_seeded.tres  ai_vs_trivial.tres  ai_vs_ai.tres  ai_perf60.tres  ai_easy_vs_normal.tres …
agent/flows/pt024{a..f}_*.json   # flows del playtester
tools/ai_baseline.md (opcional)  # cómo se sacó la línea base de sacengine (§5.3)
```

Archivos que se modifican:
- `high_noon.tscn`: suma `%Nav`, `%Vision` y `%AiRoster`.
- `unit.tscn` y `wizard_body.tscn`: suman `PathFollower`; `unit.tscn` suma además `TargetPicker`.
- `unit_body.gd`: delega `closest_foe` en `TargetPicker` si existe; si no, conserva el comportamiento actual. Semilla derivada.
- `orders.gd`: `apply_for(slot, units, command, point, target)`, solo en servidor o en solo; reutiliza `_apply`.
- `match_rules.gd`: `match_seed` y `ai_seats: Array[AiSeat]`.
- `sacrifice_flow.gd`: `solo_ai_seats`, pick de la IA en `slot_picks`, `--ai-slots=` y `--ai-god=` en el dedicado.
- `boot.tscn` y `boot.gd`: `%VsAi` y `%AiGod` (OptionButton). `%Solo` no cambia.
- Semillas: `match_biome.gd`, `body_separation.gd` y `ghost_form.gd`.
- `game_data.gd` y `creature_type.gd`: `drain` (ya está en `creatures.json`) y lo que el evaluador pida de habilidades.

### 3.2 Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `AiSide` | reloj de ranuras y medición; no decide | Nodo | Si decidiera, sería el god-node |
| `AiPerception` | qué sabe el bando y desde cuándo | Nodo | Se cambia la regla de visión sin tocar decisiones |
| `AiStance` | números agregados: fuerzas y amenaza | Nodo | La consumen tareas y cerebro |
| `AiGroups` | grupos por cercanía | Nodo | Lo usan Manahoar, guardia y postura |
| `AiTaskBoard` + `*Task` | qué objetivos valen y quién va | Nodo + hijos | Sacar `CaptureTask` = bot que no expande |
| `AiWizardBrain` + fases | qué lanza o convoca el mago y cuándo | Nodo + hijos | Sacar `AttackPhase` = mago pacífico |
| `CreatureBrain` / `ManahoarBrain` | órdenes por criatura | Nodo | Micro de la IA, distinto de la de la unidad |
| `AiCommandPort` | traduce intención → `request_*` y `apply_for` | Nodo | Única costura con el juego: así se audita que no haga trampa |
| `AiAudit` | registro y totales para el informe | Nodo | Se quita en release sin afectar la IA |
| `AiRater`, `AiField` | cuentas puras de shiny.d | `static func` | Prueba unitaria sin escena |
| `AiProfile`, `AiDifficulty`, `AiSeat` | números y asiento | Resource `.tres` | Otra dificultad = otro `.tres` |
| `AiRoster` | arma los asientos IA al cargar | Nodo | El spawner de MpKit no sabe de IA |
| `NavService` + `NavGrid` | camino y región (`sameRegion`) | Nodo + RefCounted | Lo usan jugador, IA y percepción |
| `PathFollower` | seguir waypoints con `begin_walk` | Nodo hijo | Quitarlo = camina recto como hoy |
| `SideVision` | «¿el bando B vio a X?» | Nodo | Lo usan `TargetPicker` y `AiPerception` |
| `TargetPicker` | puntaje de blanco de la criatura | Nodo hijo | `unit_body.gd` ya tiene 832 líneas |

### 3.3 Resource de tipo, nodo y `@export` de instancia

- **Resource:**
  - `AiProfile`: constantes de la versión comercial (280, 100/80, 0.9, 3620, 16/8 ticks, períodos 12/60/6/6/60/12, radios 10/140/180/280).
  - `AiDifficulty`: escala de períodos, agresividad, retraso de reacción y `resource_bonus`, que por defecto es 0 y está bloqueado en 0 salvo decisión del usuario.
  - `AiSeat`.
  - Los `.tres` no se mutan en tiempo de juego.
- **Nodo:** todas las piezas con estado por partida (registros, cola, grupos, tiempos).
- **`@export` de instancia:**
  - En `AiSide`: `slot`, `seat: AiSeat`, `active` (las escenas de prueba arrancan en pausa) y `log_level`.
  - Sockets: `world`, `caster`, `orders`, `nav` y `vision`, con avisos de configuración si faltan.
  - En `NavService`: `cell_m = 5`, `max_slope`.
  - En `PathFollower`: `repath_s` y `arrive_m`.

## 4. Red y autoridad

- `AiRoster` corre **solo si `not MpKit.is_networked() or MpKit.is_server()`**. Los clientes nunca instancian `AiSide`.
- El mago IA sale de `WizardSpawner.spawn_slot(slot)`: se replica como cualquier mago y `is_local()` da falso en todos los procesos.
- El pick de la IA va a `SacrificeFlow.slot_picks[slot]` y se publica por el canal `slot_picks` que ya existe.
- Los comandos van directo a `_try_*` en el servidor, por `request_*`, que en servidor o en solo no manda RPC. Las órdenes van por `Orders.apply_for(slot, …)`.
- No hay RPC nuevo y no se toca `mp_kit`.
- Dedicado con IA: `--ai-slots=2 [--ai-god=pyro]` hace que `SacrificeFlow._ready` ponga `max_players = 1` antes de `super._ready()`. Así MpKit le da el slot 1 al único humano y el 2 queda para la IA.
- Sin la marca, el dedicado queda igual que hoy, con dos humanos.

## 5. Determinismo y banco reproducible

Se define primero, para no iterar a ojo.

### 5.1 Semilla

- `MatchRules.match_seed`: si vale 0 se sortea y se imprime `semilla <n>`.
- Con ella se siembran:
  - `seed()` global, para `body_separation`.
  - `MatchBiome`.
  - Cada `UnitBody`, `GhostForm` y `AiRand`, con `hash([match_seed, name])` o `hash([match_seed, slot])`.
- Alcance de la garantía: **mismo binario, misma máquina, sin ventana y con `--fixed-fps 60`**. No entre arquitecturas: es un riesgo anotado.

### 5.2 Corredor `debug/ai_match.tscn`

Comando único, igual para el developer, el reviewer y el orquestador:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/joelsartori/Development/sacproject/game \
  --fixed-fps 60 res://debug/ai_match.tscn -- --rules=res://debug/rules/<caso>.tres --seed=<n> --minutes=<m> \
  --out=agent/out/ai/<caso>_s<n>.json
```

- `--fixed-fps` sin ventana corre más rápido que el tiempo real.
- Un solo proceso a la vez. Vigilar `ps -o rss` y cortar si pasa de 2,5 GB; sin ventana no se cargan mallas.
- Nada de `look_bench`. No tocar el editor abierto del usuario.

El informe es JSON más una línea `AI_REPORT …`:
- `seed`, `minutes`, `winner_slot`, `end_tick`, `end_reason`.
- Por bando:
  - `summons[]`: tick, tag, maná y almas antes y después.
  - `casts[]`, `rejections{motivo: n}`.
  - `manaliths[]`: tick.
  - `desecrations[]`: inicio, fin y resultado.
  - `converts`, `souls_collected`.
  - `mana_in{fount, altar, manalith, manahoar}` y `mana_out`.
  - `perceived_foes_max`, `unseen_leaks`.
- `ai_ms{mean, p99, max}` por bando y `sep_ms` (`BodySeparation`, aparte).
- `digest`: sha256 del registro de eventos más las posiciones redondeadas a 0,1 m cada 60 s.

### 5.3 Línea base de sacengine (opcional, informativa)

Ya hay precedente de marcas `--dump-*` en sacengine (`app.d:304+`). Se agregaría `--dump-ai-out=` con los mismos campos y se correría:

```
3d --map-list=… "(2) High Noon" --bot-slots=0,1 --bot-gods=…
```

con 5 semillas y por los dioses del caso. Necesita ventana: es un proceso pesado que corre solo. Si no se puede correr, los objetivos de §6 se quedan con los números fijos de abajo.

### 5.4 Orden por corte

1. **Developer:** implementa; corre los comandos de §6 del corte y pega los JSON (`digest` incluido); corre `rules_suite`.
2. **Reviewer:** solo lee; **vuelve a correr exactamente los mismos comandos** y compara el `digest` y los números; revisa la composición y que todo pase por `AiCommandPort`.
3. **Playtester**, con ventana: `--max-fps 60`, un proceso, flows `pt024x_*`, capturas en `agent/out/pt024x/`.
4. **Orquestador:** mira las capturas con Read y cierra el F<n>.

## 6. Cortes

### 024a — Semilla y banco (F71). Sin IA.
- **Escena:** `debug/ai_match.tscn` con `rules/ai_duel_seeded.tres`: 6 Trogg contra 6 Druid, a 60 m, sin órdenes. Arranca **en pausa** («Pendiente»); `check_tick` (Enter) lo larga. Sin ventana arranca solo.
- **Criterios:**
  - Dos corridas con `--seed=7 --minutes=2` dan el **mismo `digest`**; `--seed=8`, otro distinto.
  - Duración real ≤ 60 s y RSS ≤ 1,5 GB.
  - `rules_suite` imprime `RULES SUITE PASS`.
  - `f26_duel` y `f27_orders` dan `AGENT_OK`.
- **Playtest:** con ventana, Enter → los grupos pelean y el rótulo pasa a «Terminado · semilla 7».

### 024b — Navegación, visión y elección de blanco (F72). Micro.
- **Piezas:** `NavService`/`NavGrid` (desde `Terrain.is_on_ground`, más los altares y manantiales como bloqueos), `PathFollower` en unidades y magos, `SideVision` (alcance de vista; el campo de visión y la línea de vista quedan marcados «aprox.») y `TargetPicker` (puntaje de `updateTarget`, filtrado por visibilidad).
- **Escenas:**
  - `debug/nav_cross.tscn`: un Trogg propio en `Start1` y un marcador en el inicio de `Start2`; `order_units` sobre el marcador.
  - `debug/target_pick.tscn`: un Trogg, un Druid a 20 m y otro a 60 m que le pega primero; `check_tick` libera.
- **Criterios:**
  - El Trogg llega a ≤ 5 m en ≤ 1,2 × largo del camino / 8,25 s, sin quedar quieto más de 2 s.
  - En `match_defeat`, el mago 2 llega al Druid solo con `order_units`, sin rodear a mano (antes se trababa).
  - Grilla armada en ≤ 300 ms; `find_path` de punta a punta en ≤ 5 ms.
  - Suite `target_score_*`: los puntajes coinciden con la fórmula de §1.2 a ±1e-4 (cerca, lejos, ×1,2 y ×1,3).
  - En `target_pick`, el Trogg elige al Druid de 60 m que le pegó si `0.25·(100/60)²·1.25·1.2` gana, y si no al cercano. Se calcula en la suite y el registro imprime el elegido.
  - Un enemigo detrás del alcance de vista de todo el bando **no** se elige.
  - Regresión: `f25_summon`, `f27_orders`, `pt60` y `pt64` dan `AGENT_OK`.
  - **Desvío de sacengine (024b, tras la review):** en guardia y escolta (`patrolAround`, `state.d:13003`) el umbral es `min(100,d)·0,01`, ≈ 0 con la unidad en el ancla, y `score_cutoff` da INF: se elegiría cualquier blanco visto por el bando a cualquier distancia, y la unidad saldría y volvería sin parar (77 cambios de modo en 30 s). El port exige además que el blanco esté a menos de su `sight_range` del ancla (como `_in_sight` con el blanco actual). ADVANCE no cambia. Caso `target_guard_no_jitter` en la suite.

### 024c — Cerebro mínimo: convoca, ataca y defiende (F73)
- **Piezas:** `AiSide`, `AiPerception`, `AiStance`, `AiGroups`, `AiTaskBoard` con `IdleTask` y `GuardTask`, `AiWizardBrain` con `SummonPhase` y `AttackPhase`, `CreatureBrain`, `AiCommandPort`, `AiAudit`, `AiRater`, `AiField`, `AiRand` y `profile_original.tres`.
- **Escenas:**
  - `debug/ai_summon.tscn`: High Noon, mago humano en `Start1` sin input, asiento IA en el slot 2 y James. Arranca en pausa: «IA en pausa».
  - `debug/ai_defend.tscn`: 3 Druids enemigos a 150 m del mago IA, con `advance` hacia su altar.
- **Criterios**, con `ai_summon` sin ventana, semilla 1 y 3 min:
  - ≥ 3 convocatorias; la primera, ≤ 20 s.
  - En cada convocatoria del registro, maná antes − maná después = costo ±1 y almas −= costo.
  - `rejections["Sin maná"] = rejections["Sin almas"] = 0`: la IA pide solo lo que puede pagar, como `lightCanCast`.
  - `mana_in` sale solo de fuentes.
  - **Percepción:** una criatura enemiga convocada en t = 60 s a 600 m, fuera de toda vista del bando IA, da `unseen_leaks = 0`: no está en `AiPerception` mientras no se la vea. El altar enemigo sí está desde t = 0 (scanGlobal, como el original).
  - **`ai_defend`:** en ≤ 10 s desde que el primer Druid entra a 280 m del mago IA hay ≥ 1 hechizo de ataque del dios con blanco Druid y ≥ 2 criaturas IA en `ATTACK`/`CHASE` contra Druids.
  - Costo: `ai_ms.mean ≤ 0,5`, `p99 ≤ 2`.
- **Playtest:** en `ai_summon`, Enter → se ve a `Wizard2` lanzar y aparecer criaturas; captura del mago con dos criaturas. En `ai_defend`, captura del hechizo saliendo hacia un Druid.

### 024d — Economía, captura y profanación (F74)
- **Piezas:** `CaptureTask` (manantial libre → Manalith; Manalith enemigo; altar enemigo → Desecrate), `ManahoarBrain`, `ConvertPhase`, `SupportPhase`, la ruta de almas del mago, y el fantasma en espera o yendo a la fuente.
- **Escenas:**
  - `ai_match` con `rules/ai_vs_trivial.tres`: el slot 1 es `debug/ai_side_trivial.tscn` (convoca y se queda en su altar; sin captura ni ataque) y el slot 2 es la IA normal.
  - `debug/ai_guard.tscn`: 4 Rangers enemigos atacan un Manalith de la IA.
- **Criterios**, semillas 1 a 5, 30 min de juego:
  - Primer Manalith de la IA ≤ 6 min en ≥ 4/5.
  - **La IA gana por ritual** (`end_reason = "desecration"`, `winner_slot = 2`) ≤ 30 min en ≥ 4/5.
  - Ningún `Desecrate` rechazado por «Blanco inválido».
  - Ninguna convocatoria sin almas.
  - En `ai_guard`, ≤ 5 s después del primer golpe al Manalith hay ≥ 2 criaturas IA con orden de guardia o ataque contra los Rangers.
  - Si existe la línea base de §5.3: primer Manalith dentro de ±50 % de la mediana de sacengine. Es informativo, no bloquea.
- **Playtest:** `ai_match` con ventana, semilla 1, con `--minutes` corto y estado avanzado por `.tres` (almas y maná altos, IA cerca del altar enemigo). Capturas del portador llegando, los 4 doctores y el cartel final; el humano ve «Derrota» si juega el slot 1 en `debug/ai_endgame.tscn`.

### 024e — Dificultades y perfiles por dios (F75)
- **Piezas:** `AiDifficulty` con tres `.tres`. **Normal = los números del original.** Fácil: períodos ×2, agresividad 0,6, retraso de 0,5 s antes de cada pedido. Difícil: períodos ×0,75 y agresividad 1,0, sin trampa salvo que se decida lo contrario (pregunta 1). Un `AiProfile` por dios, con los mismos números de entrada (el original no tiene personalidad); el dios cambia solo por el libro.
- **Criterios** (`rules/ai_easy_vs_normal.tres`, 10 semillas, 30 min):
  - Normal gana ≥ 7/10.
  - Convocatorias de Fácil a los 5 min ≤ 70 % de las de Normal (media).
  - En las tres dificultades, `rejections` por recursos = 0 y `mana_in` solo de fuentes.
  - **Rendimiento** (`rules/ai_perf60.tres`, IA contra IA, 30 criaturas por bando forzadas con almas y maná altos, 5 min): `ai_ms` por bando con media ≤ 0,5, p99 ≤ 2 y máximo ≤ 6; `sep_ms` se informa aparte, sin criterio (es O(N²), F66).
- **Playtest:** la galería de dioses no aplica. Un flow por dificultad que muestra el rótulo de la dificultad del rival en el HUD de debug.

### 024f — Partida contra la IA completa (F76)
- **Escena:** la que abre el jugador. `boot.tscn` → Jugar → «Contra la IA» (`%VsAi`; rival `%AiGod`: Aleatorio o un dios). No hace falta escena debug para el arranque. Para el final, `debug/ai_endgame.tscn`: altar IA a 40 m del humano, una criatura propia y maná 1000.
- **Acciones:** clic en `%Play`, `%VsAi`. En el final, `%StructureTab`, `spell_4` y clic sobre la criatura.
- **Criterios:**
  - A ≤ 120 s de entrar existe `%Wizards/Wizard2` (slot 2) con ≥ 1 criatura del slot 2 en `%Units`.
  - El HUD propio no muestra mensajes del caster de la IA.
  - `ai_endgame`: el humano profana y ve «Victoria». Con `ai_match` y el humano inactivo (semilla 1), «Derrota» en ≤ 30 min de juego, medido sin ventana y confirmado con una captura del cartel.
  - **Dedicado con `--ai-slots=2` y 1 cliente:** el cliente es el slot 1, ve a `Wizard2` moverse y criaturas del slot 2; el dedicado imprime `ia slot 2 lista`.
  - **Sin la marca:** dedicado con dos clientes igual que hoy (`agent/run_pt60.sh` termina «Victoria»/«Derrota»).
  - Regresión: `f20_solo`, `f21_pick`, `f24_cast`, `f25_summon`, `f30_souls`, `f31_ghost`, `pt60`, `pt61b` y `pt64` dan `AGENT_OK`; `%Solo` sigue sin rival.

## 7. Riesgos

1. **Tamaño.** `shiny.d` tiene 3442 líneas de D con listas intrusivas. Se reemplazan por Arrays y RefCounted, y se busca **fidelidad de comportamiento, no de bits**: las peculiaridades de precisión del FPU (f32 contra precisión extendida) se anotan, no se imitan. Mitigación: cortes chicos y la suite compara `AiRater` y `AiField` contra valores calculados a mano desde shiny.d.
2. **Pathfinding.** Sin él, la IA se traba (F57). Cambia también el movimiento del jugador, porque en sacengine también usa camino. Lo mitiga la regresión de flows en 024b; queda `PathFollower` para apagarlo (pregunta 3).
3. **Determinismo de la física.** Hay que verificar qué motor 3D está activo (`project.godot` no lo fija). `move_and_slide` es determinista con un hilo y `--fixed-fps`, pero no entre máquinas. Si el `digest` diverge, el criterio de 024a baja a «registro de eventos idéntico los primeros 2 min» y se investiga.
4. **Datos.** Al evaluador le faltan `drain` (está en el JSON y no en `CreatureType`) y `amount2` de las habilidades (sin mapear en `export_stats.py`). Hay que exportarlos o anotar la aproximación.
5. **Visión aproximada.** Al principio no hay línea de vista ni campo de visión: la IA ve un poco más que en el original. Se marca «aprox.».
6. **Costo en GDScript.** Con 60 unidades está acotado por las ranuras, pero `BodySeparation` ya cuesta unos 7 ms por tick con 60 (F66) y no es de este RFC.
7. **Línea base de sacengine con ventana:** es pesada. Corre sola, nunca a la par de Godot.

## 8. Preguntas para el usuario (con la opción recomendada)

1. **Dificultad.** El original no la tiene (verificado en sacengine, inferido en el exe). **Recomendado:** Fácil, Normal y Difícil **sin trampas**, con Normal = original y Normal por defecto. Alternativas: solo Normal por ahora; o un Difícil con bonificación de maná (trampa, no es del original).
2. **Cantidad de rivales.** High Noon es de 2 jugadores. **Recomendado:** 1 IA ahora, con la arquitectura lista para N, y mapas de 3 y 4 en otro RFC.
3. **¿El pathfinding también para el jugador?** **Recomendado:** sí, como en sacengine. Alternativa: solo para la IA en 024b y para el jugador después.
4. **IA en el dedicado.** **Recomendado:** solo «un humano contra la IA» como prueba de humo en 024f (`--ai-slots=2`). Alternativa: IA solo local en este RFC.

## 9. Orden de implementación

1. 024a: semillas (`MatchRules.match_seed` y siembras), corredor y informe, `ai_duel_seeded.tres`.
2. 024b: `NavGrid`/`NavService`, `PathFollower` en unidad y mago, `SideVision`, `TargetPicker`, casos de suite.
3. 024c: datos (`AiProfile` y `drain`), `AiRater`/`AiField`/`AiRand` con su suite, `AiPerception`, `AiStance`, `AiGroups`, `AiCommandPort` + `Orders.apply_for`, `AiAudit`, tablero con Idle y Guard, cerebro con Summon y Attack, `CreatureBrain`, `AiSide`, `ai_summon` y `ai_defend`.
4. 024d: `CaptureTask` (Manalith, captura, Desecrate), `ManahoarBrain`, `ConvertPhase`, `SupportPhase`, almas y fantasma, `ai_side_trivial.tscn`, `ai_guard`, `ai_endgame`.
5. 024e: dificultades, perfiles por dios, `ai_perf60`.
6. 024f: `AiSeat` en `SacrificeFlow`, `AiRoster` en `high_noon.tscn`, botón y selector en boot, marca del dedicado, regresión.

## 10. Verificación humana en el editor

- `scenes/world/ai/ai_side.tscn`: el inspector muestra `seat`, `active`, `slot` y los sockets, y avisa si falta `caster`, `orders`, `nav` o `vision`. Sacar `Tasks/CaptureTask` o `Brain/AttackPhase` no da errores (F6 de `ai_summon`).
- `data/ai/difficulty_*.tres` y `profile_original.tres`: cada número tiene su comentario con la cita `shiny.d:línea` y la marca «verificado [O]» o «según [S]».
- `debug/ai_summon.tscn` con F6: el rótulo «IA en pausa», Enter, y el mago IA convoca. `debug/nav_cross.tscn`: el Trogg rodea el manantial.
- `high_noon.tscn`: `%AiRoster` con `MatchRules.ai_seats` vacío no hace nada (la partida de dos humanos no cambia).
- No hay GUT: la suite es `debug/rules_suite.tscn` más el corredor `ai_match`.

## Archivos citados

- `/Users/joelsartori/Development/sacproject/sacengine/source/bots/shiny.d`, `state.d`, `lobby.d`, `app.d`
- `/Users/joelsartori/Development/sacproject/sacengine/maps/(2) High Noon.scp`
- `/Users/joelsartori/Downloads/sacgame/Sacrifice/Sacrifice.exe`, `.rea-snapshots/sacrifice-exe`
- `game/scenes/world/{unit_body.gd, orders.gd}`, `units/unit_orders.gd`, `spells/caster.gd`, `wizard/{wizard_body.gd, wizard_spawner.gd}`, `match/defeat_rule.gd`
- `game/scenes/flow/sacrifice_flow.gd`, `game/scenes/ui/boot.gd`
- `game/addons/mp_kit/{mp_slot_spawner.gd, mp_authority.gd}`
- `game/PRD.md`, `FEATURES.md`, `RULES.md`
