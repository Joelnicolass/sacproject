# RFC-049 — Equipos (2v2) y mapa elegido por la sala

Estado: 049a–049h hechos (F290–F297); 049i (F298) con las guías y los documentos al día, pendiente del playtest con ventana y de `all --no-window`. Plan del tech lead (Opus). Arquitectura **estándar** (RULES §Arquitectura). MP **online con dedicado por partida** (RFC-034): no cambia el modelo. Solo crecen los asientos, se agregan los equipos y el mapa de la sala llega al dedicado.

- **Pedido del usuario (2026-10-19):** «2v2 completo y que la sala elija el mapa en red».
- **Features:** F290–F298 (049a–049i). Las asigna el orquestador. La última en uso es F282.
- **Autoridad:** pedido del usuario 2026-10-19 > PRD > FEATURES > RULES > VISUAL > RFC-034/044 > este plan.

### Contradicciones (gana el pedido del usuario)

- **`PRD.md` §Fantasía:** dice «Dos magos en High Noon». **§Fuera del primer corte:** dice «Más de un rival IA, alianzas … tampoco entran en el modo solo». Las dos frases se editan (§8).
- **RFC-034 §12:** saca del alcance «más de 2 asientos por sala (High Noon tiene dos inicios)» y «salas con IA». Este RFC trae las dos cosas. Sigue siendo cierto que High Noon tiene dos inicios (§3.4): el 2v2 se juega en un mapa de 4 inicios.
- **F262:** «`SacrificeFlow.max_players` sigue en 2 … el 2v2 completo es de otro RFC». Ese RFC es este.
- **HOWTO §Un mapa:** dice «Pendiente: lo está dejando listo el RFC-044», pero RFC-044 ya cerró (F260–F263). Se completa en 049i con `test_flat4` como ejemplo.

## 1. Objetivo (criterios de aceptación)

- **La sala elige el mapa.** La opción `world` de la sala pasa al ticket y de ahí al dedicado, que carga esa `MapDefinition`. Los clientes cargan el mismo mapa porque el dedicado se lo dice. Solo, «Contra la IA» y «Servidor local» también eligen mapa. El selector lista los mapas con `room_selectable`. El servidor de salas rechaza un mapa desconocido o con menos inicios que el modo (`bad_options`).
- **Modos de juego como Resource.** `GameMode` (`.tres`) define los asientos, el equipo de cada asiento y la victoria (último equipo en pie). Hay cuatro: `1v1` (el default), `2v2`, `ffa3` y `ffa4`. Un modo nuevo es un `.tres`, sin código.
- **Equipos en la simulación.** Dos asientos del mismo equipo son aliados en `SideRelations`: el fuego amigo usa la opción que ya existe, no se apuntan entre sí, comparten almas libres y visión como en el original, y ganan juntos. Los NPC no cambian.
- **Asientos IA.** En una sala, el anfitrión puede poner una IA en un asiento libre (2 humanos contra 2 IA, o 1 humano con IA aliada contra 2 IA). «Contra la IA» en solitario llena con IA todos los asientos del modo.
- **2v2 de punta a punta.** Cuatro clientes en una sala 2v2 entran al mismo dedicado. El resultado es por equipo (`winner_slots`) y vuelve a la sala. La reconexión y el abandono funcionan por asiento, como hoy.
- **El 1v1 no se mueve.** El modo por defecto es `1v1`. `run_determinism.sh quick --no-window` da los digests de `agent/det_baseline.txt` en todos los cortes. Ningún digest se regraba por este RFC. Hay casos nuevos del banco para 2v2 IA contra IA.

## 2. Hoy (leído del código)

- **Mapa por proceso.**
  - `MapCatalog.current_tag()` (`scenes/map/map_catalog.gd`) lee `--map=` una sola vez y guarda solo el tag en un estático. `MapCatalog.use(tag)` lo cambia.
  - `MatchWorld._attach_map()` (`scenes/match/match_world.gd`) instancia `MapCatalog.active()` en `_enter_tree`.
  - `SideRelations._ensure()` vuelve a leer las filas del mapa si cambia el tag activo.
- **El ticket trae `world` y nadie lo aplica.**
  - `SacrificeRoomRules.build_ticket` pone `world` (de `worlds()` = `MapCatalog.room_tags()`).
  - `MatchTicketGlue.setup_from_ticket` solo lee `options` y `seed`.
  - El launcher no pasa `--map`. El dedicado y los clientes juegan siempre High Noon.
- **Conflicto de nombres.** `SacrificeFlow` usa el flag `--world=` para la **ruta de una escena** (`world_path`). La clave `world` del ticket es un **tag de mapa**. Este RFC no toca `--world=`: el tag del mapa viaja como `map` en el snapshot y como `--map=` en los flags.
- **Asientos.**
  - `MpLobbyConfig.seats_per_room = 2` es global: todas las salas tienen la misma cantidad (`MpLobbyRooms.create_room`, `room.seats.resize(config.seats_per_room)`).
  - Ya existe `choose_seat` / `set_slot`, para cambiarse de asiento.
  - `room_view.gd` ya arma una fila por asiento, con cualquier cantidad.
- **Cupo de jugadores.**
  - `SacrificeFlow.max_players = 2`.
  - `MpIds.bind_client` rechaza un slot mayor que `max_players`.
  - Con `--ai-slots`, `max_players` = el primer slot IA − 1.
- **Bandos.** `SideRelations`: los asientos son los primeros `player_starts` slots y toman los bandos con `assignment != 0`, **ordenados por id de bando**. `stance()` sale solo de los SIDS del mapa. No hay equipos.
- **Victoria.**
  - `DefeatRule._decide_winner`: queda **un slot** vivo entre los dueños de altar y gana.
  - `MatchState.winner_slot` es un solo int.
  - `MatchState.sides()` = los slots con altar, aunque no haya mago.
- **Lugares que comparan `owner_slot` en vez de preguntar la postura** (con equipos, un aliado contaría como enemigo):
  - `Health._side_factor`: solo el mismo slot cuenta como aliado para el fuego amigo.
  - `SoulSystem._stance`: OWN / NEUTRAL / ENEMY, sin ALLY.
  - `SacrificeSystem`: profanar cualquier altar ajeno (l. 114); convertir cualquier cadáver ajeno (l. 179).
  - `UnitManaSupport`: el maná del manahoar va solo al mago propio y solo cuenta los manalitos propios (l. 44, 63).
  - `MinimapMarkers`: solo lo propio se muestra siempre (l. 58–87).
  - `UnitHealthBar._own`: propio o enemigo.
- **Lo que ya usa la postura:** `TargetRules.is_valid_foe_of`, `AiPerception`, `pull`, `fire_shield` y `peasant_behavior`.
- **IA.**
  - `AiRoster` sienta `MatchRules.ai_seats` o `SacrificeFlow.solo_ai_seats`.
  - `AiSeat` tiene `slot`, `wizard`, `god`, `difficulty`.
  - El banco (`debug/ai/ai_match.gd`) sienta sus propios asientos desde las reglas.
- **Inicios.**
  - `WizardSpawner._start_for(slot)` busca el `PlayerStart` con ese `slot`; si no lo encuentra, comparte inicios en orden.
  - High Noon y `test_flat` tienen `Start1`/`Start2` y `player_starts = 2`.
- **Mapas del original.** `tools/import/import_map.py` está fijo en `"(2) High Noon.scp"`. La instalación tiene 13 mapas `(2)`, 6 `(3)` y 12 `(4)` (Devil's Tails, Exe, Faceoff Returns, Genie, Hamburger Hill, Iron Cross, Joust, Kirwan, Pinched, Snowy Plains, Star, Web, WinterWonder).

## 3. Cómo lo hace el original (sacengine, solo lectura, GPL: descrito, no copiado)

### 3.1 Equipos y alianzas

- **Partida y equipos.** `lobby.d` (`gameInit`, l. 9–112) arma la partida con `numSlots` y `teamSizes`.
  - `--2v2` da `teamSizes = [2,2]` y `--ffa` da `[1]` (`app.d:362-366`).
  - El equipo de cada slot sale de la lista de tamaños en orden: slots 0,1 → equipo 0 y slots 2,3 → equipo 1. Sin `teamSizes`, cada jugador trae su `team` en `Settings`.
- **Posturas.** Después de sentar a los magos, para cada par de slots con mago se pisa la postura de bando a bando: **aliado si tienen el mismo equipo, enemigo si no** (`stanceSettings`).
  - Se aplica con `Sides.setStance` al iniciar (`state.d:31510-31513`).
  - Los NPC y las casas siguen con los SIDS del mapa.
- **Asiento → bando.** `Sides.multiplayerSide(i)` es el bando cuyo `assignment & 31 == i + 1` (`state.d:30060-30066`). Es el número de jugador, no el orden por id.
  - High Noon: bando 0 → jugador 1 (assignment 33 = 32 | 1) y bando 1 → jugador 2.
  - Los mapas `(4)` (Joust, Star, Faceoff Returns, leídos de sus SIDS) tienen 4 bandos de jugador (assignment 1–4), enemigos de todos, y un bando NPC.
  - Un mapa trae FFA por defecto; los equipos los pone la partida.

### 3.2 Victoria compartida

- **Quién cuenta.** `altarSides` = los bandos **que tienen un mago sentado** (`state.d:31493-31514`), no los que tienen un altar en el mapa.
- **Quién gana.** Un bando gana cuando no queda ningún bando enemigo vivo dentro de `altarSides` (`getNewVictories`, `state.d:30483-30492`). Los aliados vivos ganan juntos. `computeTeams` (`state.d:30562-30574`) agrupa por la máscara de aliados para las estadísticas.
- **Detalle.** En el original, un aliado ya derrotado queda «derrotado» aunque su equipo gane. Ver P3.

### 3.3 Colores, visión, almas y maná

- **Colores.** Cada bando tiene **su** color de paleta (el campo `color` de los SIDS, `sids.d:9-16`; `Sides.sideColor`). No hay color de equipo.
  - El minimapa y las barras de las criaturas usan el color del bando (`renderer.d:3821, 4011, 4674`).
  - El port ya colorea por slot (`SideColors.PALETTE[slot % 8]`: 1 azul, 2 verde, 3 amarillo, 4 violeta). Se mantiene.
- **Visión compartida.** `alliedVision = true` por defecto (`options.d:95`). Cuando un bando marca algo como visto, lo marcan también sus aliados (`markAsVisible`, `state.d:29658-29665`).
  - El minimapa muestra lo aliado sin niebla (`minimapVisibleToSide`, `state.d:29694-29698`).
  - `fogOfWar` está apagado por defecto (`options.d:93`), así que el efecto real es que **las IA aliadas comparten lo que vieron**.
  - `alliedBeamVision = true` comparte los resaltados de selección. En el port eso es presentación pura: queda fuera (§11).
- **Almas.**
  - `collectAlliedSouls = false` y `greenAllySouls = false` por defecto.
  - Las almas de las criaturas aliadas se ven **rojas** para mí, igual que las enemigas (`color`, `state.d:1620-1630`).
  - Al recoger un alma libre, la prioridad es propia > aliada > neutral > enemiga (`CollectStance`, `state.d:14926-14955`).
- **Maná.** El manahoar suma por los manalitos **aliados**, no solo los propios (`state.d:28598-28606`). Las fuentes de maná con la marca `allies` le dan maná a los aliados (`state.d:28549`).
- **Fuego amigo.** Entre aliados aplica `friendlyFire` y `sideDamageMultiplier` (`state.d:8961, 9005, 28892-28899`). El port ya tiene la opción (RFC-031); falta que «aliado» sea la postura y no «el mismo slot».
- **HUD.** `renderStats` y `renderSpellbook` dibujan solo el mago local. No hay panel de aliados.
  - En el minimapa, los **edificios aliados** muestran flecha en el borde como los propios (`renderer.d:4641-4643`).

### 3.4 Mapas e inicios

- **High Noon** es `(2)`: dos bandos de jugador y dos `PlayerStart`. **No admite 4 jugadores.**
- **Los mapas `(4)`** del original sí, con un bando por jugador. Traer uno es trabajo de importación (`.scp` → terreno, tiles, luz, layout de NTTS, navmesh, minimapa, tema de suelo) y hoy el importador nombra High Noon a mano. Va en un RFC aparte (P1).

## 4. Diseño

### 4.1 `GameMode` (Resource) y su catálogo

```text
GameMode (class_name, Resource, @tool)
  tag: StringName              # 1v1, 2v2, ffa3, ffa4
  display_name: String         # clave tr() (MODE_1V1…)
  team_of_seat: PackedInt32Array  # [0,1] · [0,0,1,1] · [0,1,2] · [0,1,2,3]; seats = size()
  victory: Victory = LAST_TEAM_STANDING   # enum de un valor por ahora
  room_selectable := true
  func seats() -> int
  func team_of(seat: int) -> int     # seat 1-based; fuera de rango = -seat
  func has_allies() -> bool          # algún equipo con ≥ 2 asientos
  _get_configuration_warnings: vacío, equipos sin huecos (0..T-1)

GameModeCatalog (class_name, Resource)  data/modes/mode_catalog.tres
  modes: Array[GameMode]
  static current_tag() / active() / use(tag) / reset()  # --mode=<tag>, default &"1v1"
  func find(tag); func room_tags() -> PackedStringArray
```

- **Mismo patrón que `MapCatalog`.** El estático guarda **solo el tag**, porque un estático que retiene un Resource de su propio script no se libera. No se lee en el editor.
- **Por qué no `MatchRules`.** `MatchRules.tres` son las reglas de ronda: daño, tiempos, fuego amigo. El modo es una elección de la sala, como el mapa, y necesita un catálogo listable. `MatchRules` gana un solo knob nuevo: `allied_vision := true` (§4.4).
- **Equipos 2v2 como el original.** El default de `2v2.tres` es `[0,0,1,1]`, igual que `--2v2`: asientos 1 y 2 contra 3 y 4. En la sala, cambiarse de equipo es cambiarse de asiento (`choose_seat`), así que el jugador también elige su inicio.

### 4.2 Equipos en `SideRelations`

- **Overlay de equipos.** Se agrega un overlay de equipos encima de los SIDS, como `stanceSettings`:
  - `_team_of_seat` sale de `GameModeCatalog.active()`;
  - se instala **solo si `mode.has_allies()` o `mode.seats() > 2`**. En `1v1` no se instala y el código hace el mismo camino de hoy.
- **`stance(a, b)` con los dos slots en asientos ocupados por el modo:** el mismo equipo da ALLY y otro equipo da ENEMY. Lo demás (NPC, neutral) sale de los SIDS.
- **`team_of(slot) -> int`:** el equipo del modo, o `-slot` si no está en el modo, es NPC o no hay overlay. Así cada slot es su propio equipo y la regla vieja queda igual.
- **`_ensure()`:** refresca si cambia el tag del mapa **o** el del modo.
- **Asiento → bando como el original.** Los bandos de jugador se ordenan por `assignment & 31` y no por id. En High Noon y `test_flat` el orden es el mismo, así que no cambia ningún digest. En los mapas `(4)` también coincide, pero así queda bien.
- **`seat_count()`:** sigue siendo `MapDefinition.player_starts`. La numeración de los NPC depende del mapa, no del modo. Un 1v1 en un mapa de 4 inicios deja los asientos 3 y 4 sin mago.

### 4.3 Victoria por equipo

- **`MatchState.sides()`:** los slots dueños de altar **con mago sentado**, igual que `altarSides`.
  - El dueño es `MatchState.mark_seated(slot)`. Lo llama `WizardSpawner._place` en la autoridad, para humanos e IA. `seated_slots` va en el snapshot.
  - El altar de un asiento vacío queda en el mapa y no cuenta para la victoria (P4).
- **`DefeatRule._decide_winner`:** agrupa a los vivos por `SideRelations.team_of`. Si queda un solo equipo, llama `end_match_team(slots_vivos_del_equipo)`; si no queda ninguno, `end_match(0)`. Con `team_of(slot) = -slot` (1v1) da exactamente lo de hoy.
- **`MatchState` agrega:**
  - `winner_slots: Array[int]` y `winner_team: int`;
  - `winner_slot` queda como el menor slot del equipo ganador, por compatibilidad con la sala y el banner;
  - `won(slot) -> bool`;
  - el snapshot suma `winners`.
- **Resultado a la sala:** `{winner_slot, winner_slots, winner_team, defeated_slots, reason, picks, seed, ticks}`. `LobbyText.result_text` usa `winner_slots` si está.

### 4.4 Reglas entre aliados (preguntar la postura, no comparar slots)

| Lugar | Hoy | 049c |
|---|---|---|
| `Health._side_factor` | mismo slot | `SideRelations.stance(from, me) == ALLY` (el mismo slot también es ALLY) |
| `SoulSystem._stance` | OWN/NEUTRAL/ENEMY | + `ALLY`, prioridad own > ally > neutral > enemy; las almas pegadas a criaturas aliadas no se recogen (rojas) |
| `SacrificeSystem` l. 114 | cualquier altar ajeno | solo altar **enemigo** |
| `SacrificeSystem` l. 179 | cualquier cadáver ajeno | ajeno **y no aliado** (se verifica en sacengine al hacer el corte; si el original deja convertir aliados, gana el original) |
| `UnitManaSupport` l. 63 | manalitos propios | manalitos **aliados** (`state.d:28603`) |
| `SideVision.mark` | por bando | con `MatchRules.allied_vision`, también marca a los aliados (`state.d:29658-29665`) |

- **Sin cambio de digest en 1v1.** En High Noon y `test_flat`, ningún par de slots distintos es ALLY: los SIDS solo se tienen de aliado a sí mismos. Cambiar la comparación por la postura da el mismo número.

### 4.5 Presentación (local, sin simulación)

- **Colores por slot**, como el original: sin color de equipo.
- **`UnitHealthBar`:** tres estilos (propio, aliado, enemigo) en el `.tres` de tema de la barra.
- **`MinimapMarkers`:** lo aliado se muestra siempre, igual que lo propio (visión aliada). Los edificios aliados llevan flecha de borde, como en el original.
- **`MatchResultBanner`:** «Victoria» si `won(local_slot)`. Con equipos, una línea extra: «Ganó el equipo de …» con los nombres.
- **Sin panel de magos aliados en el HUD**, como el original (P5).

### 4.6 Mapa y modo de la partida: un dueño

- **`MatchSetup`** suma `map_tag` y `mode_tag` (vacío = el de `--map` o `--mode`, o el default).
- **`SacrificeFlow._apply_match_choice()`** es el **único** que llama `MapCatalog.use` y `GameModeCatalog.use`, siempre antes de cargar el mundo:
  - **Solo / Contra la IA:** lo que eligió el boot (`play_solo(chosen)` / `play_vs_ai(..., chosen)`).
  - **Dedicado con ticket:** `ticket.world` y `ticket.mode`, validados de nuevo. Si no son válidos, error en el log, `report_result({reason:"bad_ticket"})` y salida.
  - **Dedicado directo:** `--map` / `--mode`, como hoy.
  - **Cliente:** el dedicado manda `{map, mode}` en `snapshot_for_joiner()` (override de `SacrificeFlow`). `_begin_match` empuja el snapshot **antes** de `broadcast_load_world` y a un cliente tardío o que vuelve se lo empuja en `_on_peer_joined`. El cliente aplica `use()` al recibirlo.
  - **`return_to_boot`:** `MapCatalog.reset()` y `GameModeCatalog.reset()`.
- **`max_players`** = `mode.seats()`:
  - en el dedicado con ticket se calcula en `_arm_ticket_glue`, que ya corre antes de `super._ready()`;
  - en el dedicado directo, con `--mode`;
  - en solitario no importa.
  - `MpIds.bind_client` acepta slots 1..`seats` y los asientos IA nunca se admiten (no tienen token).
- **`--ai-slots=2,3,4`:** acepta varios slots dentro de `mode.seats()`. En el modo directo los humanos toman los slots más bajos, así que los slots IA tienen que ser la cola (como hoy: `max_players = min(ai) − 1`).

### 4.7 Sala: asientos por modo y asientos IA

**Kit (`addons/mp_kit/lobby/`, genérico, sin nombres de Sacrifice):**
- `MpLobbyRooms.seat_count_for: Callable(options) -> int`. Vacía, usa `config.seats_per_room`. Con tope en `config.max_seats_per_room` (default 8).
- **Asientos bot**, un concepto genérico («agregar bot» de cualquier lobby):
  - `set_seat_bot(session_id, seat, meta) -> String` y `clear_seat_bot(session_id, seat)`;
  - solo el **anfitrión** de la sala, que es el creador; si se va, pasa al siguiente asiento humano;
  - errores `not_host`, `seat_taken`, `bad_meta`.
  - Un bot cuenta como asiento ocupado y siempre listo. La cuenta arranca con todos los asientos ocupados y todos los humanos listos.
- **Snapshot:** `seat: {seat, bot:true, meta}`. **`room_list`:** `seats_used` cuenta los bots.
- **`MpLobbyServer`:** RPC `set_seat_bot(seat, meta)` / `clear_seat_bot(seat)` con `bot_validator: Callable`. `proto_version` 1 → 2.
- **`MpLobbyClient`:** `set_seat_bot`, `clear_seat_bot`.
- **`MpLobbyRooms._launch`:** las filas bot van al `ticket_builder` con `bot: true` y sin token.
- **`MpMatchAgent`:** una fila sin `token_sha256` no se admite nunca. Esto es genérico.

**Pegamento (`scenes/net/`):**
- **`SacrificeRoomRules`:**
  - `OPTION_KEYS` suma `mode`;
  - `clean_options` valida `mode ∈ GameModeCatalog.room_tags()` y `MapDefinition(world).player_starts ≥ mode.seats()`;
  - `seat_count_for(options) = mode.seats()`;
  - `is_valid_bot(meta)`: `god` vacío (sorteo) o un dios, `difficulty` (`easy|normal|hard`) y `wizard` opcional;
  - `build_ticket` pone `team` en cada fila, saca los bots a `ai_seats: [{slot, wizard, god, difficulty}]` y agrega `mode` al ticket.
  - Con `--room-test-maps` (solo pruebas), `worlds()` también lista los mapas con `room_selectable = false` (P6).
- **`MatchTicketGlue`:**
  - `_seat_metas` = solo humanos. `ai_seats` se convierten en `AiSeat` (`difficulty` → `data/ai/difficulty_*.tres`) y van a `SacrificeFlow.solo_ai_seats`.
  - La espera de carga espera solo a los humanos.
  - **Abandono por equipo:** un humano ausente más de `rejoin_grace_s` cae con `DefeatRule.defeat(slot)` y la partida sigue.
  - Si con eso queda un solo equipo **presente** (las IA cuentan siempre como presentes), se reporta `reason:"abandon"` con `winner_slots` de ese equipo. Si no queda nadie, `empty`.
  - En 1v1 da lo mismo que hoy (`winner_slot` = el que quedó, `abandon`), así que `run_034e` no cambia.
- **«Servidor local» (034m):** elige mapa, modo y asientos IA. Lleva un código por cada asiento humano abierto (`open_picks` ya es una lista) (P7).

**Ticket (v2):**
```text
{match_id, port, room_pid, expires_ms, world, mode, options, seed,
 seats: [{slot, token_sha256, meta, team}],
 ai_seats: [{slot, wizard, god, difficulty}]}
```

### 4.8 Mapas con 4 inicios

- **`test_flat4` (049d, barato y recomendado):**
  - `scenes/map/maps/test_flat4/` reusa `terrain.res` de `test_flat` (ref, sin copia).
  - Tiene 4 `PlayerStart` (slots 1–4) con su altar, en las esquinas: 1 y 2 del mismo lado, 3 y 4 enfrente, a la distancia del 1v1 de `test_flat`.
  - 4 manantiales (uno por pareja más dos centrales) y su `sides.tres` (4 bandos de jugador, assignment 1–4, enemigos de todos, sin NPC).
  - `player_starts = 4` y `room_selectable = false`. El navmesh se hornea con `bake_nav -- --map=test_flat4`.
  - Sirve para el banco, la e2e y el playtest.
- **Validador (`debug/suite/catalog_cases.gd`, F225):**
  - para cada `MapDefinition`, la cantidad de `PlayerStart` del `map.tscn` es igual a `player_starts`, con slots 1..N únicos;
  - para cada `GameMode`, los equipos son 0..T−1 sin huecos y existe al menos un mapa `room_selectable` con `player_starts ≥ seats` (si no, aviso, no falla: hoy `2v2` solo tiene `test_flat4`).
- **Mapa real de 4:** se importa un `(4)` del original en un RFC aparte (P1).

## 5. Escena de prueba

- **Lógica (049b y 049c), sin red: `res://debug/match/team_cases.tscn`** (`team_cases.gd`, dentro de `rules_suite`).
  - **Qué instancia:** `scenes/match/match_state.tscn` (con `DefeatRule`) y cuatro altares de `scenes/map/props/` bajo un `Node3D`. Usa `data/modes/2v2.tres` y `ffa4.tres` por `GameModeCatalog.use()` y el `MapDefinition` de `test_flat4` por `MapCatalog.use()`.
  - **Estado inicial:** 4 slots sentados, ningún derrotado, sin resultado.
  - **Qué no está todavía (el criterio):**
    - `stance(1,2) = ALLY` y `stance(1,3) = ENEMY` en 2v2;
    - `team_of(5)` es NPC;
    - derrotar 1 no da resultado; derrotar 3 y 4 da `winner_slots = [1,2]`;
    - en FFA4 gana el último;
    - en 1v1 sin overlay `stance` da lo de hoy;
    - fuego amigo entre 1 y 2 (×0 apagado, ×0,5 encendido);
    - recoger un alma libre aliada antes que una neutral.
  - Headless, sin InputMap. Imprime `PASS`/`FAIL` por caso y entra en `rules_suite`.
  - Los atajos son otros `.tres` de modo, no otro `.gd`.
- **Banco (049d):** `debug/ai/ai_match.tscn`, la escena de siempre, con `--rules=res://debug/rules/ai_2v2_flat4.tres --map=test_flat4 --mode=2v2`. Es otro `.tres` de `MatchRules` con 4 `AiSeat`, no un script nuevo.
- **Sala (049f y 049g):** no hay escena de debug.
  - Corre la escena de producto `scenes/net/room_server.tscn` con `--lobby-config=res://data/net/lobby_config_local.tres --room-test-maps`.
  - Los clientes son los headless de `debug/net/room_e2e_client.gd`, con un `.tres` de guion nuevo (`room_e2e_2v2.tres`).
- **Pantallas (049h):** el criterio empieza en el boot (F5) que abre el jugador. El playtester pulsa la UI y `ui_cancel`. No hay acción nueva de InputMap.

## 6. Árbol de archivos y responsabilidades

```text
game/
├── addons/mp_kit/lobby/                      # GENÉRICO
│   ├── mp_lobby_config.gd       [~] 049f  max_seats_per_room; proto_version 2
│   ├── mp_lobby_rooms.gd        [~] 049f  seat_count_for; anfitrión; set/clear_seat_bot; bots listos; filas bot sin token
│   ├── mp_lobby_server.gd       [~] 049f  RPC set_seat_bot/clear_seat_bot; bot_validator
│   ├── mp_lobby_client.gd       [~] 049f  set_seat_bot/clear_seat_bot; espejo de bot en asientos
│   └── mp_match_agent.gd        [~] 049f  filas sin token no se admiten
├── data/
│   ├── modes/                   [+] 049b  mode_catalog.tres, 1v1.tres, 2v2.tres, ffa3.tres, ffa4.tres
│   ├── maps/map_catalog.tres    [~] 049d  + test_flat4
│   ├── match_rules.tres         [~] 049c  allied_vision = true (explícito)
│   └── i18n/strings.csv         [~] 049h  MODE_*, MAP picker, equipo, «Agregar IA», resultado por equipo
├── scenes/
│   ├── match/
│   │   ├── game_mode.gd         [+] 049b  class_name GameMode (Resource)
│   │   ├── game_mode_catalog.gd [+] 049b  class_name GameModeCatalog (estático por tag, --mode=)
│   │   ├── match_state.gd       [~] 049b  mark_seated/seated_slots; sides() = sentados; winner_slots/winner_team; won(); snapshot
│   │   ├── defeat_rule.gd       [~] 049b  _decide_winner por equipo
│   │   └── match_rules.gd       [~] 049c  allied_vision
│   ├── map/
│   │   ├── side_relations.gd    [~] 049b  overlay de equipos; team_of(); orden por assignment&31; refresh por modo
│   │   └── maps/test_flat4/     [+] 049d  map.tscn (4 Start, 4 altares, 4 fuentes), test_flat4.tres, sides.tres, nav.res
│   ├── wizards/wizard_spawner.gd [~] 049b mark_seated en _place (autoridad)
│   ├── components/health.gd     [~] 049c  _side_factor por postura
│   ├── souls/soul_system.gd     [~] 049c  Stance.ALLY y prioridad
│   ├── sacrifice/sacrifice_system.gd [~] 049c altar enemigo; cadáver no aliado
│   ├── units/unit_mana_support.gd [~] 049c manalitos aliados
│   ├── units/targeting/side_vision.gd [~] 049c marca aliados con allied_vision
│   ├── core/flow/
│   │   ├── match_setup.gd       [~] 049a  map_tag, mode_tag (+ --map/--mode ya leídos por los catálogos)
│   │   └── sacrifice_flow.gd    [~] 049a/e  _apply_match_choice (único dueño de use()); snapshot {map,mode}; max_players = seats; --ai-slots varios
│   ├── core/boot.tscn/.gd       [~] 049a/h selector de mapa (049a) y de modo (049h) para Solo / Contra la IA
│   ├── net/
│   │   ├── sacrifice_room_rules.gd [~] 049a/f mode; validación mapa↔modo; seat_count_for; is_valid_bot; ticket v2; --room-test-maps
│   │   ├── match_ticket_glue.gd [~] 049a/f world/mode del ticket; ai_seats → AiSeat; espera solo humanos; abandono por equipo
│   │   ├── room_server.gd       [~] 049f  conecta seat_count_for y bot_validator
│   │   └── local_server_host.gd [~] 049h  mapa, modo, IA, un código por asiento humano
│   └── ui/
│       ├── lobby/room_create.*  [~] 049a/h selector de mapa (room_tags) y de modo
│       ├── lobby/room_view.*    [~] 049h  asientos agrupados por equipo; «Agregar IA»/«Quitar IA» (anfitrión)
│       ├── lobby/seat_row.*     [~] 049h  fila bot (dios, dificultad)
│       ├── lobby/lobby_text.gd  [~] 049f  result_text por winner_slots; códigos not_host/bad_bot
│       ├── local_server/*       [~] 049h  selectores y lista de códigos
│       ├── hud/match_result.gd  [~] 049h  won(local_slot); línea de equipo
│       ├── minimap/minimap_markers.gd [~] 049h aliados siempre visibles; flecha de edificio aliado
│       └── (unit_health_bar en scenes/units/) [~] 049h estilo aliado
├── debug/
│   ├── match/team_cases.tscn/.gd [+] 049b/c  casos de §5 (en rules_suite)
│   ├── rules/ai_2v2_flat4.tres  [+] 049d  4 AiSeat (Normal), match_seed fijo
│   ├── rules/ai_ffa4_flat4.tres [+] 049d  4 AiSeat FFA
│   ├── net/lobby_cases.gd       [~] 049f  casos de asientos por modo y bots
│   ├── net/room_e2e_2v2.tres    [+] 049g  guion de 4 clientes (mismo script room_e2e_client.gd)
│   └── suite/catalog_cases.gd   [~] 049d  inicios = player_starts; modos válidos
├── agent/
│   ├── det_cases.txt            [~] 049d  s2v2_flat4 (quick=fixed), sffa4_flat4 (set=all)
│   ├── det_baseline.txt         [~] 049d  solo se AGREGAN las líneas nuevas
│   ├── runs/run_049a.sh         [+] 049a  sala 1v1 con world=test_flat → dedicado y clientes en test_flat
│   ├── runs/run_049e.sh         [+] 049e  dedicado directo --mode=2v2 --ai-slots=2,3,4 + 1 cliente
│   ├── runs/run_049g.sh         [+] 049g  salas + 4 clientes en una sala 2v2 + variante 2+2 IA
│   └── runs/run_pt049.sh        [+] 049i  playtest: 1 ventana + 1 headless + 2 IA en 2v2
├── docs/HOWTO.md                [~] 049i  «Un mapa» (test_flat4) y «Un modo»
├── PRD.md / FEATURES.md / RULES.md [~] 049i  §8
└── docs/archive/rfcs/RFC-049-teams-and-room-map.md [+]
```

**Mapa de responsabilidades (un dueño por estado):**

| Estado | Dueño |
|---|---|
| Qué mapa y qué modo juega este proceso | `SacrificeFlow._apply_match_choice` → `MapCatalog.use` / `GameModeCatalog.use` (nadie más los llama en producto) |
| Qué es un modo (asientos, equipos, victoria) | `GameMode` `.tres` |
| Quién es aliado de quién | `SideRelations` (SIDS + overlay del modo) |
| Quién está sentado y quién ganó | `MatchState` (lo decide `DefeatRule`) |
| Asientos, anfitrión, bots y listo de la sala | `MpLobbyRooms` |
| Mapa y modo válidos, bot válido y ticket | `SacrificeRoomRules` |
| Ticket → picks, IA, mapa, modo, abandono | `MatchTicketGlue` |
| Qué IA juega en qué slot | `AiRoster` (lee `solo_ai_seats` / `MatchRules.ai_seats`) |
| Qué ve el jugador | vistas de lobby, HUD, minimapa (solo leen) |

## 7. Resource, nodo, `@export`

- **Resource de tipo:**
  - `GameMode` (×4), `GameModeCatalog`;
  - `MapDefinition`/`MapSides` de `test_flat4`;
  - `debug/rules/ai_2v2_flat4.tres` y `ai_ffa4_flat4.tres` (`MatchRules` con `AiSeat`);
  - `room_e2e_2v2.tres` (guion).
  - Ninguno se muta en runtime: el `AiSeat` del ticket es una instancia nueva y la de un `.tres` se `duplicate()`, como hoy.
- **Nodos:** `MatchState`, `DefeatRule`, `WizardSpawner`, `AiRoster`, `MatchTicketGlue`, `SacrificeRoomRules` y las vistas. No hay nodos nuevos en la partida.
- **`@export` de instancia:**
  - `MatchRules.allied_vision`;
  - `UnitHealthBar` (estilo aliado en su tema);
  - `MinimapMarkerStyle` (flecha aliada);
  - `RoomCreate` (`%MapPicker`, `%ModePicker`);
  - `RoomView` (`seat_scene`, encabezados de equipo);
  - `SacrificeRoomRules.include_test_maps` (lo prende `--room-test-maps`).
- **Estático:** `GameModeCatalog` (tag), `SideRelations` (overlay). Siguen el patrón de `MapCatalog`.

## 8. Ediciones a PRD, FEATURES y RULES (049i)

- **PRD §Fantasía:** «Dos magos en High Noon» → «Dos a cuatro magos, en 1v1, 2v2 o todos contra todos, en el mapa que elige la sala. Cada uno manda desde su cliente o lo juega la IA. El servidor dedicado simula.»
- **PRD §Fuera del primer corte:** se borra «Más de un rival IA, alianzas … modo solo». Quedan fuera solo los modos `slaughter`, `domination` y `soul-harvest`.
- **PRD §Modo solo:** se agrega «Contra la IA admite los modos con varios asientos: la IA llena los demás (aliada o rival)».
- **RULES §Red:** se agrega «El mapa y el modo de una partida en red los elige la sala y viajan en el ticket. El cliente los recibe del dedicado; nunca los elige él».
- **RULES §IA:** se agrega «Un asiento IA de sala es un asiento sin token; el dedicado lo sienta con `AiRoster`».
- **FEATURES:** append de F290–F298 (049a–049i). Un mapa real de 4 queda como Should apuntando al RFC de importación (P1).

## 9. Cortes (en serie)

### 9.0 Medición común

- **Godot:** solo el orquestador (headless) y el playtester (ventana), por `agent/harness/godot_run.sh`. Los developers no ejecutan Godot.
- **Clases nuevas:** `GameMode`, `GameModeCatalog`. Hacen falta `--import` una vez, exclusivo, en 049b.
- **`quick --no-window` igual a `det_baseline.txt` en cada corte.** Si un digest viejo se mueve, es un bug de este RFC: **no se regraba**. Lo único que entra a la base son las líneas nuevas de 049d.
- **Sesiones cortas:** cada e2e dura ≤ 120 s con `rejoin_grace_s = 5` y derrota forzada. `rules_suite` corre con `--fixed-fps 600`. Vigía de 15 min por corrida.
- **Procesos:** la e2e de 4 clientes es server + 4 clientes (`--no-flow`, sin mundo) + 1 dedicado = **6 headless**, con `HEADLESS_SLOTS=5`, `GODOT_MAX=6` y tope de RSS (como `run_034e`). El playtest es 1 ventana + server + dedicado + 1 headless = **4**.
- **Ventana:** solo en 049i (lo visible se junta al final, por pedido). Los demás cortes cierran con banco, casos o e2e headless.
- **Review:** 049b, 049c y 049f (comportamiento y kit). Los demás son cortes chicos: developer y verificación del orquestador.

| Corte | Qué | Criterio medible |
|---|---|---|
| **049a** La sala elige el mapa (F290) | `MatchSetup.map_tag`; `SacrificeFlow._apply_match_choice` (Solo, Contra la IA, ticket, directo, cliente por snapshot `{map}`); `MatchTicketGlue` aplica `ticket.world` y lo revalida; `SacrificeRoomRules --room-test-maps`; `%MapPicker` en `room_create` (de `room_tags()`) y en el boot; `reset()` al volver; `run_049a.sh` | (1) `run_049a.sh` (server + 2 clientes + 1 dedicado, `--room-test-maps`): sala con `world=test_flat` → el dedicado imprime `mapa test_flat` y los dos clientes `en mapa test_flat` (cargan el mundo; vale como humo); una sala con `world="foo"` da `bad_options`; ticket con `world` desconocido escrito a mano → `bad_ticket` y el dedicado sale. (2) `run_034e.sh` PASS sin cambios (default High Noon). (3) `quick` igual |
| **049b** Modo y equipos en la simulación (F291) | `GameMode`, `GameModeCatalog`, 4 `.tres`; `SideRelations` (overlay, `team_of`, orden por `assignment&31`, refresh por modo); `MatchState` (`mark_seated`, `sides()` sentados, `winner_slots`, `won`, snapshot); `DefeatRule` por equipo; `WizardSpawner` marca sentados; `debug/match/team_cases` | `team_cases` PASS (postura, `team_of`, victoria 2v2 y FFA4, 1v1 sin overlay = hoy) dentro de `rules_suite` PASS. `quick` igual (los 27 digests). Review: ningún `use()` de producto fuera de `SacrificeFlow` (`rg "GameModeCatalog.use\|MapCatalog.use" scenes` = solo flow) |
| **049c** Reglas entre aliados (F292) | Tabla §4.4: `Health`, `SoulSystem`, `SacrificeSystem`, `UnitManaSupport`, `SideVision` + `MatchRules.allied_vision` | `team_cases` con los casos de aliados: fuego amigo apagado ×0 y encendido ×0,5 entre 1 y 2, ×1 entre 1 y 3; alma libre aliada antes que neutral; no profana altar aliado; manahoar suma el manalito aliado; marca de visión pasa al aliado. `rules_suite` PASS. `quick` igual. Review (cambia comportamiento) |
| **049d** Mapa de 4 y banco 2v2 (F293) | `scenes/map/maps/test_flat4/` + navmesh (`bake_nav -- --map=test_flat4`); `map_catalog.tres`; `catalog_cases` (inicios, modos); `ai_2v2_flat4.tres`, `ai_ffa4_flat4.tres`; `det_cases.txt` + líneas nuevas en la base | (1) `catalog_cases` → `CATALOG PASS` (y FAIL a propósito con un `.tres` de prueba de 3 inicios declarando 4, en el scratchpad). (2) `run_determinism.sh s2v2_flat4 fixed fixed2` → mismos digests en los dos modos y `AI_REPORT` con `winner_slots` de un equipo o tiempo cumplido sin error; cada IA ataca solo slots del otro equipo (contador de golpes a aliados = 0 en el reporte, con fuego amigo encendido). (3) `sffa4_flat4 fixed fixed2` igual. (4) `quick` igual en los 27 viejos + `s2v2_flat4` |
| **049e** IA y cupo en dedicado y solitario (F294) | `max_players = mode.seats()`; `--mode`; `--ai-slots=2,3,4`; «Contra la IA» con modo (IA en todos los demás asientos); `run_049e.sh` | `run_049e.sh`: dedicado directo `--map=test_flat4 --mode=2v2 --ai-slots=2,3,4` + 1 cliente AgentKit headless → slot 1, tres `ia slot N lista`, `--force-defeat-slot=3` y `=4` → `partida terminada` con `winner_slots [1,2]`. Un humano que intenta un quinto slot queda afuera. `quick` igual |
| **049f** Sala con asientos por modo y bots (F295) | Kit: `seat_count_for`, `max_seats_per_room`, anfitrión, bots, `proto_version 2`, agente ignora filas sin token. Pegamento: `mode`, validación mapa↔modo, `is_valid_bot`, ticket v2, `MatchTicketGlue` (ai_seats, espera humanos, abandono por equipo); `lobby_text` | `LOBBY CASES PASS` con casos nuevos: sala 2v2 tiene 4 asientos; 1v1 sigue en 2; `ffa4` en `high_noon` → `bad_options`; solo el anfitrión pone o saca bots (`not_host`); 2 humanos listos + 2 bots → `COUNTDOWN`; el ticket tiene 2 filas con token y 2 `ai_seats`; el anfitrión se va → pasa al otro humano. `run_034d.sh` PASS (protocolo, stub). `rg -n "Sacrifice\|wizard\|god\|[áéíóú]" addons/mp_kit/lobby` vacío. `quick` igual. Review |
| **049g** 2v2 de punta a punta (F296) | `run_049g.sh` + `room_e2e_2v2.tres` | Corrida A (6 headless): 4 clientes en una sala 2v2 sobre `test_flat4`; cada uno en el slot de su asiento (uno se conecta tarde y queda en el suyo); `slot picks` de los 4; `mapa test_flat4 modo 2v2`; el slot 3 se va → a los 5 s `bando 3 derrotado` **y la partida sigue**; el 4 se va → `result.json {winner_slots:[1,2], reason:"abandon"}`; los 4 reciben `session_ended`; la sala muestra el resultado a los 4. Corrida B: 2 humanos + 2 bots → `ia slot 3/4 lista`, derrota forzada de 3 y 4 → `winner_slots [1,2]`, `reason:"result"`. Rejoin: el slot 2 sale y vuelve con su token dentro de la gracia → mismo slot. Sin huérfanos. `run_034e.sh` PASS. `quick` igual |
| **049h** Pantallas y HUD (F297) | `room_create` (modo), `room_view` (equipos, «Agregar IA»), `seat_row` bot, boot (modo), «Servidor local» (mapa, modo, IA, códigos), banner por equipo, minimapa y barras de aliado, textos `tr()` | Sin ventana: cada vista con F6 sola muestra «Sin conexión» sin errores (orquestador, `--headless` + `--quit-after`); validador de textos (`strings.csv`) sin claves faltantes. La prueba visual va en 049i |
| **049i** Cierre (F298) | Playtest; `all --no-window`; HOWTO «Un mapa» y «Un modo»; PRD, FEATURES, RULES (§8) | **Playtest (1 ventana + 3 headless):** el jugador abre el boot → «Jugar en línea» → crea sala «2v2» en `test_flat4` (con `--room-test-maps`) → un headless se sienta en el asiento 2 → el jugador pone IA en 3 y 4 → «Listo» → cuenta → partida. Capturas: sala con dos equipos y dos IA; HUD con la barra del aliado en su estilo; minimapa con el mago aliado; banner «Victoria» + línea de equipo tras la derrota forzada de 3 y 4; de vuelta en la sala con el resultado del equipo. Más: Solo «Contra la IA» 2v2 en `test_flat4` arranca con tres IA. `all --no-window` PASS; `quick` 1 vez más |

**Orden:** a → b → c → d → e → f → g → h → i. 049a no depende del modo y se puede cerrar solo (el pedido «la sala elige el mapa» queda listo antes). 049b y 049c son simulación pura. 049d mide los dos con IA. 049e–049g suben al dedicado y a la sala. 049h y 049i son lo visible.

## 10. Riesgos

- **Orden snapshot → load_world.** Si el `{map}` del snapshot llega después de la orden de cargar el mundo, el cliente carga High Noon. 049a lo mide: los clientes de `run_049a` cargan el mundo e imprimen el mapa.
  - **Plan B:** `SacrificeFlow` difiere `goto_world` en el cliente hasta tener `map`, o el kit suma un payload genérico a `load_world`.
- **Estáticos que no se liberan (F262).** `GameModeCatalog` guarda solo el tag y no se lee en `_ready` del autoload en el editor (`Engine.is_editor_hint()`). `max_players` se calcula con el ticket o con el flag, sin cargar el catálogo durante el import.
- **Digests.** `sides()` por sentados, la postura en `Health`/`SoulSystem` y el orden por `assignment` tienen que dar lo mismo en 1v1. Mitigación:
  - el overlay está apagado en 1v1;
  - el orden de High Noon por `assignment` es el mismo que por id;
  - `quick` en cada corte, y un digest que se mueve se arregla en el corte, no se regraba.
- **El banco con 4 IA.** `ai_match.gd` y `AiAudit` pueden asumir dos magos (reporte, `sides_report`). 049d lo revisa; si hace falta se cambia el reporte, no la simulación. Memoria: 4 IA en `test_flat4` sin NPC debería pesar menos que High Noon con NPC; se mide RSS en la primera corrida.
- **Procesos.** La e2e de 4 clientes pasa el tope de 4. Va con el permiso de RFC-034 (topes subidos solo en esa prueba, tope de RSS y `kill_tree` por pid). Ninguna ventana corre en paralelo.
- **Que entren reglas del juego al kit.** Los bots y el anfitrión son genéricos; los equipos **no** entran al kit (son asientos y nada más). El `rg` de 049f lo controla.
- **Compatibilidad del lobby.** `proto_version 2`: un cliente viejo recibe `version`, que ya se traduce. Esto se acepta.
- **2v2 sin un mapa de verdad.** `test_flat4` es plano y sin poblado. Sirve para probar, no para jugar. Ver P1.

## 11. Fuera de alcance

- Importar un mapa `(4)` del original (RFC aparte, P1).
- Color de equipo, niebla de guerra, `alliedBeamVision` (resaltados del aliado), chat de equipo y en partida, señales al aliado en el minimapa, compartir almas o maná a pedido.
- Los modos `slaughter`, `domination` y `soul-harvest`, `mirrorMatch` y los `shuffle*` de sacengine.
- Mezclar equipos al azar, más de 4 asientos por sala (el kit admite 8; el juego ofrece hasta `ffa4`), espectadores y ranking.
- Cambiar el modo o el mapa con la sala ya creada (P8).

## 12. Cómo verifica un humano

1. **Inspector:** abrir `data/modes/2v2.tres` (`team_of_seat = [0,0,1,1]`) y `ffa4.tres`. Duplicar `1v1.tres` como `3v3.tres` con 6 asientos: el validador avisa que no hay mapa con 6 inicios.
2. **F6 en `scenes/map/maps/test_flat4/map.tscn`:** se ven 4 inicios con altar y 4 fuentes. El `.tres` dice `player_starts = 4`.
3. **F6 en `debug/match/team_cases.tscn`:** termina en PASS.
4. **Solo:** boot → mapa «Test flat 4» (debug build), modo «2 contra 2», «Contra la IA». El mago propio está con un aliado IA del mismo lado. El minimapa muestra al aliado. Al ganar, el banner dice «Victoria».
5. **En red local:** en la terminal, `Godot --headless --path game res://scenes/net/room_server.tscn -- --room-server --lobby-config=res://data/net/lobby_config_local.tres --room-test-maps`. En el editor, Run Multiple Instances (2) y F5 en cada una. A crea una sala 2v2 en `test_flat4` y pone IA en 3 y 4; B se sienta en el 2; los dos marcan «Listo». Juegan del mismo lado. Al terminar, la sala muestra «Ganó tu equipo».
6. **1v1 de siempre:** una sala 1v1 en High Noon se ve y juega igual que antes.

## 13. Preguntas abiertas (con recomendación)

1. **¿Qué mapa de 4 para jugar en serio?**
   - (a) `test_flat4` en este RFC y un RFC-050 que generaliza `import_map.py` (`--scp=`, `--tag=`) e importa **un** `(4)` del original (Joust o Star: 4 bandos de jugador y 1 NPC, como se leyó de sus SIDS) **[recomendado]**.
   - (b) Importarlo dentro de 049. El importador, el layout de NTTS, el tema de suelo y el minimapa son trabajo de mapa, no de equipos.
   - (c) Hacer un mapa de 4 a mano en el editor.
2. **Equipos del 2v2.**
   - (a) Asientos 1 y 2 contra 3 y 4, como `--2v2` del original; en la sala uno elige equipo eligiendo asiento **[recomendado]**.
   - (b) Equipos libres por jugador (un `team` en la meta del asiento).
3. **Resultado del aliado caído.**
   - (a) Gana todo el equipo, también el aliado que cayó antes (banner «Victoria»; `winner_slots` = todo el equipo) **[recomendado]**. Es lo que espera un jugador de hoy.
   - (b) Como el original: el aliado derrotado queda «Derrota» aunque su equipo gane.
4. **Altar de un asiento vacío** (1v1 en un mapa de 4).
   - (a) Queda en el mapa, no cuenta para la victoria (como `altarSides`) y no se puede profanar **[recomendado]**.
   - (b) Se quita al empezar.
5. **Barras de los magos aliados en el HUD.**
   - (a) No, como el original: el aliado se ve en el mundo y en el minimapa **[recomendado]**.
   - (b) Una tira chica con vida y maná de cada aliado (sería un corte 049h2).
6. **Mapas de prueba en las salas.**
   - (a) `--room-test-maps` solo para pruebas; en producción las salas ofrecen solo `room_selectable` (hoy solo High Noon, así que el 2v2 en red real espera a P1) **[recomendado]**.
   - (b) Marcar `test_flat4` `room_selectable = true` hasta que haya un mapa de 4 real.
7. **«Servidor local» con 2v2.**
   - (a) Mapa, modo, IA y un código por asiento humano, en 049h **[recomendado]**: el ticket ya admite `open_picks` como lista.
   - (b) «Servidor local» queda en 1v1 y el 2v2 es solo de salas.
8. **Cambiar modo o mapa con la sala creada.**
   - (a) No: se eligen al crear la sala, como hoy el nivel **[recomendado]**.
   - (b) El anfitrión puede cambiarlos y eso quita el «Listo» de todos (kit: `set_options`).
9. **Visión aliada.**
   - (a) `allied_vision = true` por defecto (el original); hoy solo cambia que las IA aliadas comparten lo que vieron **[recomendado]**.
   - (b) Opción de sala.
10. **Convertir el cadáver de un aliado.**
    - (a) Se sigue lo que diga sacengine al hacer 049c (si no hay regla explícita, solo enemigos y neutrales) **[recomendado]**.
    - (b) Permitirlo siempre.

## Decisión 2026-10-19 (orquestador; el usuario pidió «todo resuelto»)

Se aplican las recomendaciones P1–P10. El mapa real de 4 jugadores (Joust o Star del original) va en RFC-050, después de 049.
