# 055i-a — Identidad por recursos en la UI, el lobby y `sacrifice_flow` (plan, pendiente de aprobación)

> **Aprobado por el usuario (2026-10-25)** con todas las recomendaciones: SacrificeFlow como escena autoload; regla C18b; `offered` en GodType y WizardType; hechizos con nombre humano (a4) al cerrar 061; bake_catalog congelado y borrado en 055z; `model` se mantiene en el pick hasta 055s; tag vacío = nombre del archivo en contenido nuevo; uid en el catálogo si el paso 0 lo confirma. La cámara sigue siendo 055k y el audio es 055o. Los cortes se implementan sin Godot y se prueban juntos al final.

Fuente: RFC-055 §13.2 (fila `CreatureType`, «Herramientas de bake») y §13.2b fila **C-1**; auditoría `docs/archive/rfcs/research/055R-legacy-audit.md` §3.1 (C18) y §5.1 (decisión del usuario: 055i en dos partes). Plan del tech lead; no hay código escrito. Conteos de `main` al 2026-10-25 (`bash tools/lint/conventions.sh --verbose`, C18 = 131, base 132).

Alcance: **UI (`scenes/ui/`), lobby (`scenes/net/` + las pantallas de salas y de servidor local) y `scenes/core/flow/`**. La parte de unidades, IA de combate y audio (`CreatureType`, `wizard_body`, `SoundLibrary`, `HudIcons`) es **055i-b** y va con 055c1: no se toca acá salvo las 3–4 líneas de frontera que se nombran abajo. `addons/mp_kit/` no se toca (es genérico; no sabe qué es un mago ni un dios).

> **Contradicción a resolver (pregunta 1).** El pedido dice «055k (audio)». RFC-055 §13.2b (C-8a) y el orden de §13.2b dicen que **055k es la cámara** y que el audio por tag es **055i-b / 055x** (C-8d). Gana el RFC (autoridad RFC > plan). Este plan coordina con los dos: con la cámara no comparte ningún archivo; con el audio comparte `data/audio/wizards/` (ver §8).

---

## 1. Objetivo (criterios del RFC, sin extras)
- Ninguna pantalla, picker, texto del lobby ni `sacrifice_flow.gd` busca contenido por tag de texto: reciben y guardan `WizardType`, `GodType`, `MapDefinition`, `GameMode` (C18 baja **54**: 131 → **≤ 77**).
- El tag queda **solo como id de red/snapshot**, leído del recurso (`resource.tag`) y convertido de vuelta en **un único lugar de frontera** (`scenes/net/match_wire.gd` + los catálogos de `scenes/core/catalog/`).
- Lo que viaja por la red es **byte a byte lo mismo que hoy** (mismos canales, mismas claves, mismos ids): late join, salas, tickets y servidor local siguen andando sin subir versión.
- Los magos se llaman por su nombre (`data/catalog/wizards/jadugarr.tres`, no `cwa0.tres`), con una herramienta portable que renombra y reescribe referencias sin el juego original. `bake_catalog` queda congelado.
- Un humano agrega, quita, renombra o crea un dios, un mago, un mapa o un modo **sin código y en 1–2 lugares** (tabla §3).

## 2. Escena de prueba
**No hay escena debug nueva** (como en 061a: el usuario va a borrar `debug/`). El criterio empieza en la escena que abre el jugador:
- `res://scenes/core/boot.tscn` (F5): selección de mago y dios, «Jugar», «Contra la IA» (picker de dios IA, mapa, modo, tierra), «Salas online» y «Servidor local».
- Headless, ya existentes: `debug/ui/team_screens_check.tscn` (instancia boot, room view, seat list, local host view y el cartel de resultado con una sala 2v2 falsa), `debug/net/lobby_cases.tscn`, `debug/net/lobby_net_cases.tscn`, `debug/net/local_server_e2e.tscn`, `debug/net/vs_ai_mode.tscn`, `debug/net/late_join.tscn`, `debug/suite/catalog_cases.gd`, `debug/suite/god_edit_cases.tscn`, `rules_suite`.
- Estado inicial: el pick por defecto (Jadugarr · James) sale del recurso por defecto del flujo, no de un diccionario en código.
- Lo que **no** está todavía (resultado del criterio): que un dios duplicado a mano (`data/gods/zeus.tres`) aparezca solo en los cuatro pickers; que el `.tres` de un mago tenga nombre humano.
- Acciones del playtester: clics de mouse en los botones de la pantalla (no hay acción nueva en el InputMap). El flujo `agent/flows/f21_pick.json` ya existe y sigue valiendo: los nombres únicos de los botones siguen siendo `Wizard_<id>` / `God_<id>` (el id de red no cambia).

---

## 3. Inventario (C18 y lo calcado)

### 3.1 C18 en el alcance (54 líneas)
| Archivo | Líneas (C18) | Qué hace hoy | Sub-corte |
|---|---|---|---|
| `scenes/core/flow/sacrifice_flow.gd` | 77, 79, 113, 134, 135, 147, 151, 153, 155, 159, 161, 163, 164, 166, 167, 173, 174, 184, 187, 192, 195, 237, 238, 277, 329 (**25**) | `pick: Dictionary` de tags; `sanitize_pick` resuelve por `GameData.wizard/gods`; el mapa y el modo se eligen con `MapCatalog.use(tag)` / `GameModeCatalog.use(tag)` y se validan por texto; snapshot por tag; asientos por `seats_of(tag)` | a2 (2), a3 (23) |
| `scenes/core/boot.gd` | 43 (1) | `%Choice` vuelve a buscar el mago por tag; el dios se muestra como `tag.capitalize()` | a2 |
| `scenes/ui/character_select/character_select.gd` | 27, 29, 30, 51, 65 (5) | botones por tag; `GameData.wizard(tag)`, `GameData.god(tag)`, `GameData.book(tag)` | a2 |
| `scenes/ui/ai_picker/ai_god_picker.gd` | 21, 22 (2) | metadata = tag; `GameData.god(tag)` para el nombre | a2 |
| `scenes/ui/lobby/lobby_text.gd` | 72, 82 (2) | `pick_text`/`bot_text` buscan por tag; dios como `capitalize()` | a2 |
| `scenes/ui/local_server/local_join_view.gd` | 36 (1) | igual que boot | a2 |
| `scenes/ui/hud/match_result.gd` | 64 (1) | nombre del ganador por tag | a2 |
| `scenes/ai/ai_roster.gd` | 57, 59, 83 (3) | `AiSeat.wizard: String`, `AiSeat.god: StringName`; sorteo por índice en la lista de tags | a2 |
| `scenes/ui/map_picker/map_picker.gd` | 29, 37, 40, 41 (4) | metadata = tag; `MapCatalog.shared().find(tag)` | a3 |
| `scenes/ui/mode_picker/mode_picker.gd` | 23, 24, 26 (3) | metadata = tag | a3 |
| `scenes/ui/lobby/room_view.gd` | 118, 121 (2) (+124 no contado: `GameCatalog.shared().god(tag)`) | texto de la sala por tag | a3 |
| `scenes/ui/lobby/seat_list.gd` | 55 (1) | modo por tag | a3 |
| `scenes/ui/local_server/local_host_view.gd` | 93 (1) | modo por tag | a3 |
| `scenes/map/map_catalog.gd` | 31 (1) | el catálogo se nombra a sí mismo (falso positivo: está fuera de `scenes/core/catalog/`) | a0 |
| `scenes/match/game_mode_catalog.gd` | 21, 76 (2) | idem | a0 |

Quedan en `scenes/ui/` **4** que no son de este corte: `hud/hud_icons.gd:48` (ícono por tag de criatura → 055h + 055i-b), `selection_roster/selection_roster.gd:235` (habilidad por `ability_tag` → 055i-b, necesita `CreatureType.abilities`), `character_select/wizard_preview.gd:47,48` (`BodyCatalog` por `model` → 055s, cuerpo como escena).

Búsquedas por texto que el regex de C18 **no ve** (por eso la pregunta 3): `room_view.gd:124` y `biome_picker.gd:23` (`GameCatalog.shared().god(tag)`, `BiomeRules.has_look(tag)`) y `ai_side.gd:90` (`AiProfile.for_god(tag)`): las tres se van en este corte. Fuera del alcance quedan `match_biome.gd` ×4, `biome_rules.gd:24`, `ai_profile.gd:125`, `caster.gd:405` y los tres `SoundLibrary.creature/wizard(tag)` del audio.

En `scenes/net/` (permitido por C18, es la frontera) hay más búsquedas por tag: `sacrifice_room_rules.gd` (`is_valid_pick`, `is_valid_bot`, `clean_options`), `match_ticket_glue.gd` (`world_is_valid`, `match_setup`, `_report`). Se quedan en la frontera, pero pasan por `MatchWire` para que la conversión texto ↔ recurso viva en un solo archivo.

### 3.2 Lo calcado 1 a 1 del original en este alcance
- **Ids del WAD como nombre de archivo e identidad:** los 15 magos `cwa0…cwl2.tres` (`tag = "cwa0"`), `spell_tag = "0awc"` (el tag del WAD al revés), `model = "jnwr"`. Los sonidos de mago están en `data/audio/wizards/cwa0.tres`, porque `SoundLibrary.type_file` usa el nombre de archivo del `WizardType`. Los 53 hechizos `brif.tres`, `ccas.tres`… son el mismo caso.
- **Pick por defecto en código:** `{"wizard": "cwa0", "model": "jnwr", "god": "james"}` (`sacrifice_flow.gd:11`), `AiSeat.wizard := "cwa0"` y el respaldo `"jnwr"` de `ai_roster.gd:61`.
- **El dios mostrado como su tag** (`str(god).capitalize()` en `boot.gd:45`, `lobby_text.gd:74`, `local_join_view.gd:38`): «James» sale del id, no de `GodType.display_name`.
- **`GameData.book` / `GodBook.up_to`** «como `getSpells` de sacengine» (el comentario abre citando, C9). La regla (libro por nivel) es diseño del juego y **se mantiene**; solo se reescribe el comentario.
- **Flags de línea de comando** (`--level`, `--souls`, `--friendly-fire`) copiados de `app.d`: **razonable, se mantiene** (es la interfaz del dedicado). Las citas pasan a `## Ref:` al final.
- `room_name = "High Noon"` fijo en `sacrifice_flow.gd:39`: menor, pasa a salir del mapa activo.

---

## 4. Diseño

### 4.1 Tres piezas nuevas, un dueño cada una
- **`WizardPick`** (`Resource`): lo que eligió un jugador. `@export var wizard: WizardType`, `@export var god: GodType`. Reemplaza el `Dictionary {wizard, model, god}`. `model` deja de ser un campo: se deriva de `wizard.model`.
- **`ActiveMatch`** (`RefCounted` con estáticos tipados, en `scenes/core/catalog/`): **el único dueño** de «qué mapa y qué modo juega este proceso». Hoy son dos dueños: `MapCatalog._active_tag` y `GameModeCatalog._active_tag`, más la regla de encaje repetida en el flujo. `choose(map, mode)` aplica el encaje (si el mapa no tiene inicios para el modo, juega el modo por defecto). `forget()` vuelve a lo que diga la línea de comando o al valor por defecto. `map()` y `mode()` son las lecturas. Es idempotente: llamarlo dos veces da lo mismo (hoy `_apply_match_choice` corre en tres lugares).
- **`MatchWire`** (estático, en `scenes/net/`): **la frontera**, el único código de producto que pasa de texto a recurso y de vuelta para picks, opciones de sala, bots, snapshot del flujo y ticket. `encode_pick(pick) -> Dictionary`, `decode_pick(d) -> WizardPick` (null si es inválido), `encode_choice() / decode_choice(d)`, `options_of(setup) / setup_of(options)`, `bot_of(meta)`.

### 4.2 Qué es Resource de tipo, qué es nodo, qué es `@export` de instancia
| Cosa | Forma | Dónde |
|---|---|---|
| Un mago, un dios, un mapa, un modo | Resource de tipo (ya existen) | `data/catalog/wizards/<nombre>.tres`, `data/gods/<nombre>.tres`, `scenes/map/maps/<nombre>/<nombre>.tres`, `data/modes/<nombre>.tres` |
| Lo que eligió un jugador | `WizardPick` (Resource chico, sin lógica) | en memoria; el pick por defecto en el inspector del flujo (`sacrifice_flow.tscn`, sub-recurso embebido: sin `.tres` suelto) |
| Asiento de IA | `AiSeat` con `wizard: WizardType` y `god: GodType` (null = sorteado) | `data/ai/seat_vs_ai.tres` y los 26 `.tres` que lo usan |
| Qué juega este proceso | estado estático tipado (`ActiveMatch`) | sin nodo: sobrevive al `change_scene`, igual que hoy |
| Lista de lo que ofrecen las pantallas | `GameCatalog.shared()` (listas tipadas, ya existe para dioses y magos) + `modes` y `maps()` nuevos | `scenes/core/catalog/game_catalog.gd` |
| Pickers | nodos `OptionButton` (ya existen); la metadata del ítem **es el recurso**; `selected() -> MapDefinition / GameMode / GodType` | `scenes/ui/*_picker/` |
| Pick por defecto y asiento «Contra la IA» | `@export var default_pick: WizardPick`, `@export var vs_ai_seat: AiSeat` | el autoload pasa a ser escena `scenes/core/flow/sacrifice_flow.tscn` (pregunta 2) |

Listar el catálogo (`GameCatalog.shared().gods`) **no** es buscar por tag: devuelve recursos y el ítem elegido lleva el recurso. Las búsquedas por id (`find(tag)`, `GameData.x(tag)`, `.god(tag)`) solo pasan en `scenes/core/catalog/`, `scenes/net/` y los spawners, como dice C18.

### 4.3 `sacrifice_flow.gd` (424 → ≤ 200 líneas)
- Guarda `pick: WizardPick`, `slot_picks: Dictionary[int, WizardPick]` y `setup: MatchSetup` (tipado).
- La elección de mapa y modo es `ActiveMatch.choose(setup.map, setup.mode)` en un solo `_apply_match_choice()`. Los cuatro `reset()` pasan a ser un `ActiveMatch.forget()`.
- Los canales `pick` y `slot_picks`, `snapshot_for_joiner` y `_on_flow_snapshot` llaman a `MatchWire`.
- `_read_dedicated_ai` y `MatchSetup.from_cli` se mudan a **`LaunchFlags.read() -> LaunchPlan`** (`scenes/net/launch_flags.gd`). `_arm_ticket_glue` se muda a **`TicketPlan.read(glue) -> LaunchPlan`** (`scenes/net/ticket_plan.gd`). Las dos son funciones puras que devuelven datos: `setup`, `ai_seats`, `picks`, `max_players`, `wait_for_picks`. El flujo aplica el plan, así que las llamadas siguen bajando.
- Los `print` que leen los scripts de `agent/runs/*.sh` y `debug/net/*` (`slot %d pick %s %s`, `mapa de la partida …`, `dedicado listo puerto`) **conservan el texto exacto**. Se mudan con su código y no cambian C14.

### 4.4 Los ids
- `tag` sigue en cada `.tres` como **id de red**. Los existentes **no cambian** (`cwa0`, `james`, `high_noon`, `1v1`), así que salas, tickets y fixtures viejos siguen valiendo.
- Para contenido nuevo, un `tag` vacío toma el nombre del archivo (`id()` en el tipo, pregunta 7). `GameCatalog` y `catalog_cases` fallan si dos archivos reclaman el mismo id.
- `catalog_cases` deja de exigir «el archivo se llama como el tag» para magos (y para hechizos en a4). Exige id único y nombre de archivo en `snake_case`.

---

## 5. Árbol de archivos
```
scenes/core/
  [~] README.md                          5 líneas What/Not/Talks to/Edit/Check (hoy no las tiene)
  [~] boot.gd                            %Choice = pick.wizard.display_name · pick.god.display_name; _setup() con MapPicker/ModePicker/BiomePicker.selected()
  catalog/
    [+] active_match.gd                  ActiveMatch: map(), mode(), choose(map, mode), forget(); lee --map/--mode solo como valor por defecto (≤ 80)
    [~] game_catalog.gd                  + modes (de data/modes/mode_catalog.tres), + maps() perezoso (lo que hoy da MapCatalog.maps); dioses y magos con `offered`
    [~] map_catalog.gd     (← scenes/map/)      solo catálogo: find(id), room_tags, playable_tags, all_tags. [-] _active_tag, use, reset;
                                                active()/current_tag() quedan como una línea que delega en ActiveMatch (puente para los 12 lectores del mundo, 055i-b)
    [~] game_mode_catalog.gd (← scenes/match/)  idem: [-] _active_tag, use, reset, active_seats; seats_of/team_of_slot/map_fits_mode por id se quedan (los usa la frontera)
    [~] game_data.gd                     comentario de book() sin abrir con sacengine (C9); sin cambios de API (debug lo usa)
  flow/
    [~] sacrifice_flow.gd                ver §4.3; [-] Dictionary de pick, sanitize_pick, _read_dedicated_ai, _arm_ticket_glue, _vs_ai_seat por StringName
    [+] sacrifice_flow.tscn              raíz = sacrifice_flow.gd; default_pick (WizardPick embebido: Jadugarr · James), vs_ai_seat = data/ai/seat_vs_ai.tres
    [+] wizard_pick.gd                   WizardPick (Resource): wizard, god; is_complete(); ≤ 30 líneas
    [~] match_setup.gd                   map: MapDefinition, mode: GameMode, biome: GodType (null = el de siempre / sorteado); [-] from_cli (→ LaunchFlags);
                                         apply_to escribe rules.biome_god = biome.tag (puente: MatchRules/MatchBiome son 055i-b)
scenes/net/
  [~] README.md                          5 líneas; «MatchWire es la única conversión id ↔ recurso del producto»
  [+] match_wire.gd                      MatchWire (estático, ≤ 140): encode/decode de pick, bot, opciones, snapshot (map, mode); mismas claves que hoy
  [+] launch_flags.gd                    LaunchFlags.read() -> LaunchPlan: --level, --souls, --friendly-fire, --drop-soul, --match-seed, --biome, --map, --mode, --ai-slots, --ai-god
  [+] ticket_plan.gd                     TicketPlan.read(glue) -> LaunchPlan (lo que hoy hace _arm_ticket_glue, sin tocar al flujo)
  [+] launch_plan.gd                     LaunchPlan (RefCounted): setup, ai_seats, picks, max_players, wait_for_picks
  [~] sacrifice_room_rules.gd            is_valid_pick/is_valid_bot/clean_options/build_ticket por MatchWire; acepta solo dioses y magos `offered`
  [~] match_ticket_glue.gd               _report: picks = MatchWire.encode_pick por slot (mismo JSON); world_is_valid por MatchWire
  [~] local_server_host.gd               start(host_pick: WizardPick, …): codifica con MatchWire
scenes/ui/
  [~] README.md                          5 líneas; «los pickers devuelven recursos; el id de red solo lo arma MatchWire»
  character_select/[~] character_select.gd   botones ligados al recurso (_on_wizard.bind(wizard)), libro = god.book.up_to(1), confirma con SacrificeFlow.set_pick(WizardPick)
  ai_picker/[~] ai_god_picker.gd             metadata = GodType; selected() -> GodType (null = «Aleatorio»)
  biome_picker/[~] biome_picker.gd           metadata = GodType; filtra type.look != null (sin BiomeRules por tag)
  map_picker/[~] map_picker.gd               metadata = MapDefinition; selected(); lista GameCatalog.shared().maps()
  mode_picker/[~] mode_picker.gd             metadata = GameMode; selected()
  lobby/[~] lobby_text.gd                    pick_text/bot_text decodifican con MatchWire; dios = display_name
  lobby/[~] room_view.gd                     _meta_text con MatchWire.setup_of(options); set_pick(MatchWire.encode_pick(pick))
  lobby/[~] seat_list.gd                     _build(mode: GameMode, …)
  lobby/[~] room_create.gd                   options = MatchWire.options_of(setup armado con los pickers)
  local_server/[~] local_host_view.gd        host_pick = SacrificeFlow.pick; modo = %HostMode.selected(); opciones por MatchWire
  local_server/[~] local_join_view.gd        %JoinChoice desde el pick tipado
  hud/[~] match_result.gd                    _name_of(slot) = SacrificeFlow.pick_for(slot).wizard.display_name   (archivo compartido con 055h, 1 función)
scenes/ai/
  [~] ai_roster.gd                       seat.wizard/seat.god tipados; sorteo sobre GameCatalog.shared().gods ofrecidos; set_ai_pick(slot, WizardPick)
  [~] ai_side.gd                         perfil = seat.god.ai_profile si no hay seat.profile (sin AiProfile.for_god por id)
  data/[~] ai_seat.gd                    wizard: WizardType, god: GodType (null = sorteado); [-] "cwa0" y &"james" como texto
scenes/wizards/
  [~] wizard_body.gd                     solo _apply_pick (3 líneas): lee el WizardPick y escribe sus ids replicados (wizard_tag/model/god siguen siendo el cable, 055i-b)
  [~] wizard_type.gd                     + @export var offered := true; + id(); el tag de solo lectura en el inspector
scenes/gods/
  [~] god_type.gd                        + @export var offered := true; + id()
data/
  catalog/wizards/[~] 15 .tres           cwa0.tres → jadugarr.tres … (renombrados con la herramienta; `tag` sin cambios)
  audio/wizards/[~] 15 .tres             mismos nombres nuevos (SoundLibrary.type_file sigue funcionando sin tocar código)
  ai/[~] seat_vs_ai.tres                 wizard = ExtResource(jadugarr.tres), god vacío (sorteado) o ExtResource
  [~] match_rules.tres + 24 .tres de debug/rules/ y debug/ai/ con AiSeat   migrados por el script de asientos
  modes/[~] mode_catalog.tres            ruta del script movido (game_mode_catalog.gd)
project.godot
  [~] [autoload]                         SacrificeFlow="*res://scenes/core/flow/sacrifice_flow.tscn"   (pregunta 2)
tools/
  migrate/[+] rename_resources.py        renombrado portable (ver §7); Python 3 sin dependencias; ensayo por defecto
  migrate/[+] typed_seats_055i.py        de una sola vez: AiSeat de texto a ExtResource (se borra en 055z)
  bake/[~] bake_catalog.gd               congelado: sale con un mensaje si data/catalog/ ya tiene archivos (pregunta 8)
  lint/[~] conventions.sh                + C18b (búsquedas por id que C18 no ve), con su propia base (pregunta 3)
  lint/[~] baseline.txt                  --update-baseline al cerrar cada sub-corte
debug/
  suite/[~] catalog_cases.gd             magos: id único + archivo snake_case (no «archivo = tag»); `offered`; ids duplicados
  ai/[~] ai_match.gd, map/[~] nav_cross.gd, net/[~] local_server_e2e.gd, units/[~] rock_hit.gd   escriben/leen WizardPick (o MatchWire.decode_pick de sus ids)
  ui/[~] team_screens_check.gd           + chequeos: el texto del dios es display_name; un GodType sin ofrecer no aparece
agent/
  harness/match_shots/[~] match_shots.gd, fixtures/[~] pt034f_peer.gd   set_pick(MatchWire.decode_pick({wizard, god})) con los mismos argumentos
```

### Nodos afectados
- `sacrifice_flow.tscn` (nueva): `SacrificeFlow (Node, sacrifice_flow.gd)` con `default_pick` y `vs_ai_seat` en el inspector. `MatchTicketGlue` sigue como hijo creado solo en el dedicado de un ticket (allowlist de C15 sin cambios: hoy ya se crea así).
- `boot.tscn`, `character_select.tscn`, `room_view.tscn`, `room_create.tscn`, `local_host_view.tscn`: **no se editan** (los pickers y los `%UniqueName` son los mismos). Los `.tscn` de `scenes/ui/` quedan para 055h.

## 6. Mapa de responsabilidades (un dueño por estado)
| Estado | Dueño | Lo leen |
|---|---|---|
| Pick local | `SacrificeFlow.pick: WizardPick` | boot, selección, salas, servidor local |
| Picks por slot | `SacrificeFlow.slot_picks` (el servidor escribe, publica por `slot_picks`) | `WizardBody._apply_pick`, `MatchResult`, ticket `_report` |
| Mapa y modo de este proceso | `ActiveMatch` (solo lo escribe `SacrificeFlow._apply_match_choice` y `MatchWire.decode_choice` en un cliente) | mundo (vía `MapCatalog.active()` puente), pickers como valor inicial |
| Lo que eligió el creador de la partida | `MatchSetup` (tipado) | flujo, `HighNoon.apply_to` |
| Texto ↔ recurso | `MatchWire` + catálogos de `scenes/core/catalog/` | red, salas, ticket, línea de comando (`LaunchFlags`) |
| Qué se ofrece | `GodType.offered`, `WizardType.offered`, `MapDefinition.room_selectable/playable`, `GameMode.room_selectable` | pickers, `SacrificeRoomRules` |

## 7. Cómo lo hace un humano
| Verbo | Ejemplo | Qué abre y toca | Lugares |
|---|---|---|---|
| **Entender** | ¿qué magos y dioses ofrece el lobby? | FileSystem → `data/catalog/wizards/` (`jadugarr.tres`, `seerix.tres`…) y `data/gods/`; el inspector muestra `display_name`, `book`, `look`, `offered`. `scenes/core/README.md` dice quién habla con quién | 1 |
| **Modificar** | renombrar un hechizo en la UI | `data/catalog/spells/<hechizo>.tres` → `display_name`. Hoy el archivo se llama `brif.tres`; con a4 se llama `fireball.tres` | 1 |
| | cambiar el mago con el que arranca el menú | `sacrifice_flow.tscn` → `default_pick` → arrastrar `seerix.tres` a `wizard` | 1 |
| | renombrar un archivo | FileSystem → Renombrar (Godot reescribe las dependencias). El id de red (`tag`) no cambia | 1 |
| **Agregar** | un dios nuevo al lobby | duplicar `data/gods/james.tres` → `zeus.tres`; vaciar `tag` (toma «zeus»); cambiar `display_name`, `book`, `look`. Aparece en la selección, el picker de IA, la tierra y las salas | 1 (2 si trae un `LookProfile` propio) |
| | un mago | duplicar `jadugarr.tres` → `nuevo.tres`; `display_name`, stats, `model` (texto hasta 055s) | 1 |
| | un mapa | carpeta `scenes/map/maps/<nombre>/` con su `<nombre>.tres` (ya es así) | 1 |
| | un modo | `data/modes/3v3.tres` + arrastrarlo a `data/modes/mode_catalog.tres` | 2 |
| **Quitar** | un dios del lobby sin romper referencias | su `.tres` → `offered` = off. Desaparece de los pickers y las salas lo rechazan; los `.tres` que lo nombran siguen cargando | 1 |
| | una criatura del bestiario | `data/gods/<dios>.tres` → `book` → `creatures`: quitar la fila. Su línea de `unlocks` queda huérfana y `catalog_cases` lo avisa | 1 |
| **Crear** | un mago propio hecho en Blender | duplicar un `.tres` de mago, apuntar `model` al modelo nuevo (con 055s: arrastrar la escena del cuerpo) | 1–2 |
| **Escalar** | 12 dioses, 8 asientos | sin código: las listas salen del catálogo, los pickers se llenan solos, el id de red sale del `.tres` y `seats` sale del `GameMode` | 0 código |

Ningún verbo pide código. «Agregar un modo» toca dos lugares (está en el límite; ver pregunta 9).

## 8. Cómo llega a la red
- **Lo que se manda (sin cambios, byte a byte):**
  - canal `pick` (cliente → servidor): `{"wizard": "cwa1", "model": "serx", "god": "persephone"}`. `MatchWire.encode_pick` arma `model` desde `wizard.model`, así que el diccionario es el mismo que hoy (pregunta 4).
  - canal `slot_picks` (servidor → todos): `{"picks": {slot: <el mismo dict>}}`.
  - snapshot del flujo: `{"map": "high_noon", "mode": "1v1"}`.
  - salas: `meta` del asiento = el dict del pick; opciones `world/mode/biome` = ids; bot `{god, difficulty}`; ticket v2 sin cambios.
  - El `MultiplayerSynchronizer` de `WizardBody` (`wizard_tag/model/god`) no se toca (055i-b).
- **Lo que no se manda nunca:** rutas `res://`, nombres de archivo ni `display_name`. Renombrar un `.tres` no cambia nada en la red.
- **Snapshot y late join:**
  - El que entra tarde recibe el snapshot. `MatchWire.decode_choice` → `ActiveMatch.choose(map, mode)` corre **antes** de la orden de cargar el mundo (mismo canal confiable que hoy). Después le llegan los `slot_picks` y `decode_pick` arma un `WizardPick` por slot.
  - Un id que el cliente no conoce da `push_error` y se ignora, como hoy.
  - El dedicado valida igual que la sala, porque `SacrificeRoomRules.is_valid_pick` y el ticket usan el mismo `decode_pick`.
- **Determinismo:** no cambia nada de la simulación. Se corre solo el humo del banco (memoria «sin banco de determinismo»: lint + `rules_suite` + capturas).

## 9. Renombrar los `.tres` sin romper referencias
- **Estado real:** los `.tres` de `data/catalog/` **no tienen `uid`** en la cabecera (0 de 15 magos, 0 de 53 hechizos), y quien los nombra lo hace por `path=` (por ejemplo `data/gods/james.tres` → `res://data/catalog/spells/brif.tres`, sin uid). Mover el archivo a mano rompería esas rutas. Los que sí tienen uid (`data/gods/*.tres`) no se renombran.
- **Herramienta `tools/migrate/rename_resources.py`.** Python 3, sin el juego original y sin Godot:
  1. Arma la tabla vieja → nueva desde `display_name` (`--from-display-name data/catalog/wizards`) o desde un CSV a mano. `--with data/audio/wizards` renombra los archivos compañeros con el mismo nombre base.
  2. Rechaza el renombrado si dos destinos chocan, también sin distinguir mayúsculas (macOS ya obligó a `EHTH_2`), o si el destino existe.
  3. `git mv` de cada archivo. Si el archivo trae uid en la cabecera, viaja con él.
  4. Reescribe `res://<viejo>` → `res://<nuevo>` en `*.tres`, `*.tscn`, `*.gd`, `*.json`, `*.cfg`, `*.txt` y `*.sh` de `game/`. Excluye `.godot/`, `docs/archive/rfcs/` (historia) y `assets/original/`.
  5. Después de aplicar, busca la ruta vieja y falla (exit 1) si queda alguna. Imprime la tabla.
  6. Por defecto es un ensayo; `--apply` escribe.
- **Después:** una sola corrida `--headless --import`, en la cola FIFO, para refrescar la caché del editor. Después, `catalog_cases` y `team_screens_check`.
- **Uids (pregunta 10):** para que de ahí en más se pueda renombrar desde el dock sin la herramienta, conviene estampar uid en los `.tres` de catálogo (re-guardarlos con Godot). **NO VERIFICADO** que `ResourceSaver.save` en headless agregue uid a un `.tres` que no lo tiene: se prueba con un archivo en el paso 0 de a1. Si funciona, va como commit aparte (genera ruido de formato en el diff).
- **Nombres propuestos para los magos** (salen de `display_name`; el `tag` no cambia):

| Viejo | Nuevo |
|---|---|
| `cwa0` | `jadugarr` |
| `cwa1` | `seerix` |
| `cwa2` | `marduk` |
| `cwd0` | `the_ragman` |
| `cwd1` | `acheron` |
| `cwd2` | `sorcha` |
| `cwe0` | `abraxus` |
| `cwe1` | `mithras` |
| `cwe2` | `eldred` |
| `cwf0` | `ambassador_buta` |
| `cwf1` | `grakkus` |
| `cwf2` | `charlotte` |
| `cwl0` | `shakti` |
| `cwl1` | `yogo` |
| `cwl2` | `hachimen` |

- **Lo que depende del nombre de archivo y hay que cuidar:**
  - `SoundLibrary.type_file`: por eso se renombran también los 15 `data/audio/wizards/*.tres`.
  - `bake_catalog.gd` escribe `<tag>.tres` si «falta»: volvería a crear los 15 viejos. Por eso se congela.
  - Los escaneos de carpeta (`bake_body_scenes.gd`, `anim_expect.gd`, `death_ragdoll_wizards.gd`) no dependen del nombre.
  - `TypeRef.creature` usa `creatures/<tag>.tres`: es de 055i-b (criaturas), no se toca.
- **Asientos de IA:** `tools/migrate/typed_seats_055i.py` reescribe `wizard = "cwa0"` → `ExtResource` del mago (ya renombrado) y `god = &"james"` → `ExtResource("res://gods/james/james.tres")` (con su uid). `god = &""` se borra (null = sorteado). Corre una vez sobre `data/match_rules.tres`, `data/ai/seat_vs_ai.tres` y los 24 de `debug/`.

## 10. Criterios medibles
- **Lint** (`bash tools/lint/conventions.sh`):
  - C18 **131 → ≤ 77** (−54): a0 −3, a2 −17, a3 −34.
  - C18b nace en su valor de a0 (13 hoy) y baja ≥ 3.
  - C1b −1 (`sacrifice_flow.gd` ≤ 200; los archivos nuevos ≤ 150).
  - C9 baja en todos los encabezados que se tocan (≥ 15: abren con «RFC-0xx»).
  - Ninguna regla sube; C12 y C14 iguales o menores.
- **Suites que quedan en verde:**
  - headless, sin red: `rules_suite`, `catalog_cases.gd` (CATALOG PASS), `god_edit_cases.tscn`, `catalog_edit_cases.tscn`, `debug/ui/team_screens_check.tscn -- --no-flow --room-test-maps` (TEAM SCREENS PASS, con los chequeos nuevos), `debug/net/lobby_cases.tscn`.
  - con procesos: `lobby_net_cases`, `vs_ai_mode`, `local_server_e2e`, `late_join` (al cerrar a3).
- **El cable no cambió:** en `local_server_e2e` y `vs_ai_mode` con los mismos argumentos, las líneas `slot N pick <model> <god>` y el JSON `picks` del resultado son **iguales antes y después** (diff vacío de esas líneas del log).
- **Capturas** (cámara fija, con AgentKit; la ventana la abre el orquestador, una por vez):
  - Lobby: `agent/flows/f21_pick.json` (selección y «Jugar») más un flujo nuevo `agent/flows/055i_screens.json` sobre `boot.tscn`: Contra la IA con los pickers abiertos, Servidor local → Crear, Salas → Crear sala con `--room-test-maps`.
  - HUD: `match_shots` con `views=wizard`, más el cartel de resultado de `team_screens_check` con `--shots`.
  - Criterio: es un cambio de identidad, así que las capturas son **iguales**. PNG-diff de AgentKit ≤ 0,5 % de píxeles distintos, con la máscara de `%WizardPreview` (gira) y del minimapa.
  - Única diferencia esperada: el dios pasa a mostrarse por su `display_name`. Hoy es «James», igual al tag capitalizado, así que tampoco cambia.
- **Humano:** duplicar `data/gods/james.tres` → `zeus.tres` (tag vacío, `display_name` «Zeus») hace que «Zeus» aparezca en los 4 pickers sin reiniciar el editor. `offered` off lo saca. Al final se borra el archivo.

## 11. Código 1 a 1 que se borra
- `SacrificeFlow.pick: Dictionary` con `"cwa0"/"jnwr"/"james"` en código.
- `sanitize_pick` y su respaldo «si GameData no cargó, aceptar cualquier `model`» (`sacrifice_flow.gd:82-87`).
- Los dos dueños del mapa y el modo activos: `MapCatalog._active_tag/use/reset` y `GameModeCatalog._active_tag/use/reset/active_seats`. Quedan `active()/current_tag()` como puente de una línea para el mundo, con fecha 055i-b.
- La validación por texto de mapa y modo en el flujo (3 `push_error` por tag) y el parseo del snapshot por tag.
- `MatchSetup.map_tag`, `mode_tag`, `biome_god` como `StringName`, y `MatchSetup.from_cli` (se muda tipado a `LaunchFlags`).
- `AiSeat.wizard := "cwa0"`, `AiSeat.god := &"james"` y el respaldo `"jnwr"` de `ai_roster.gd`.
- En la UI: `selected_tag()` y `selected_god()` con metadata de texto; los botones `Wizard_<tag>` que vuelven a buscar el tipo; `GameData.book(tag)` en la selección; `BiomeRules.has_look(tag)` en el picker; el dios mostrado como `tag.capitalize()` (3 lugares).
- La regla de `catalog_cases` «el archivo de un mago se llama como su tag».
- Los 15 nombres de archivo del WAD de `data/catalog/wizards/` y de `data/audio/wizards/`.
- `bake_catalog.gd` como generador que se puede volver a correr (queda congelado; se borra en 055z).

## 12. Sub-cortes y paralelo
| Sub-corte | Qué | Tamaño | Depende | C18 |
|---|---|---|---|---|
| **a0** | mover `map_catalog.gd` y `game_mode_catalog.gd` a `scenes/core/catalog/` (git mv con `.uid`, ruta en `mode_catalog.tres`); `GameCatalog.modes` y `maps()`; regla C18b en el lint con su base. Sin cambio de comportamiento | S | — | −3 |
| **a1** | datos: `rename_resources.py`, 15 magos + 15 sets de audio, `catalog_cases`, `bake_catalog` congelado, prueba de uid | S | — (paralelo con a0) | 0 |
| **a2** | picks tipados: `WizardPick`, `MatchWire` (picks y bots), `AiSeat` tipado + `typed_seats_055i.py`, flujo (pick, slot_picks, canales), `ai_roster`, `ai_side`, `wizard_body._apply_pick`, `sacrifice_room_rules`, `match_ticket_glue._report`, `local_server_host`, y los que leen el pick en la UI (boot `%Choice`, `character_select`, `ai_god_picker`, `lobby_text`, `local_join_view`, `match_result`); autoload como escena | M | a1 (los asientos apuntan a los nombres nuevos) | −17 |
| **a3** | elección tipada: `ActiveMatch`, `MatchSetup` tipado, `LaunchFlags`/`TicketPlan`/`LaunchPlan`, el resto del flujo, pickers de mapa, modo y tierra, `room_create`, `room_view`, `seat_list`, `local_host_view`, `boot._setup` | M | a2 | −34 |
| **a4** | datos: 53 hechizos con nombre humano usando la misma herramienta | S | **061 cerrado** (comparte `data/catalog/spells/` y 24 escenas de `scenes/spells/`) | 0 |

- a0 y a1 van en paralelo (carpetas disjuntas). a2 → a3 en serie (mismo `sacrifice_flow.gd`).
- **Con 055h (HUD nativo):** 055i-a toca en `scenes/ui/` **solo `.gd`, ningún `.tscn`**, así que 055h es dueño de todos los `.tscn` de la UI, del `Theme` y de `scenes/ui/hud/` salvo una función de `match_result.gd`.
- **Con 055k:** si es la cámara (RFC), no hay archivos compartidos. Si es audio (pedido): ver abajo.
- **Con el audio (055i-b / 055x):** a1 renombra `data/audio/wizards/*.tres` y depende de que `SoundLibrary.type_file` use el nombre del archivo del `WizardType`. El corte de audio no debe renombrar ni reemplazar esos sets mientras a1 está abierto. Si llega antes con `WizardType.sounds: SoundSet`, a1 solo renombra los magos.
- **Archivos compartidos a coordinar:**

| Archivo | Lo comparte con | Cómo se coordina |
|---|---|---|
| `tools/lint/baseline.txt` | todos | regenerar con `--update-baseline` tras el rebase; nunca resolver el conflicto a mano |
| `project.godot` (`[autoload]`) | 055h (`[display]` stretch) | secciones distintas |
| `scenes/ui/hud/match_result.gd` | 055h | 1 función |
| `scenes/core/boot.gd` | 055h, si toca la pantalla | `.gd` acá, `boot.tscn` allá |
| `scenes/ui/README.md` | 055h | — |
| `data/audio/wizards/` | audio (ver arriba) | — |
| `scenes/wizards/wizard_body.gd` | 055i-b | 3 líneas en `_apply_pick` |
| `scenes/ai/ai_side.gd` | 055f | 1 línea |
| `debug/suite/catalog_cases.gd` | 055i-b, 061 | — |
| `data/match_rules.tres` | 055r (radios), 055u | — |

- Godot: cola FIFO, como mucho 3 headless y 1 ventana. Una sola `--import` después de a1 y otra después de mover catálogos en a0.

## 13. Riesgos
1. **Autoload que nombra tipos `@tool`** (`GameModeCatalog` avisa: «a script of an autoload that holds that type is left unfreed by the import»). `MatchSetup` tipado con `GameMode`/`MapDefinition` dentro del autoload podría repetirlo.
   - Paso 0 de a3: `--headless --import` y buscar «leaked» o «unfreed».
   - Si aparece, el estado tipado vive solo en `ActiveMatch` (estático, fuera del autoload) y `MatchSetup` guarda `Resource` con lectura tipada en `ActiveMatch`.
2. **Los scripts de `agent/runs/` y `debug/net/` leen el log:** se conserva el texto exacto de cada `print` que se muda.
3. **El árbol de trabajo tiene ~80 `.import` modificados sin commitear** (git status): el developer trabaja en worktree y no los incluye.
4. **API de `set_pick` cambia:** los 6 llamadores de `debug/` y `agent/` (listados en el árbol) se actualizan en a2. `agent/out/*` es borrador y no se toca.
5. **El sorteo del dios de la IA** usa el índice en la lista: filtrar por `offered` solo lo cambia si alguien desmarca un dios. Con los 5 de hoy, el mismo seed da el mismo dios.
6. **`GameCatalog.maps()` carga todos los mapas:** es lo mismo que ya hacen hoy los pickers (`MapCatalog.maps`). No se llama desde el autoload.

## 14. Fuera de alcance (otros cortes)
- `CreatureType`/`AbilityType` por referencia, criaturas y habilidades con nombre humano y `TypeRef.creature` por nombre de archivo: **055i-b + 055c1**.
- `WizardBody`/`Health`/`kill_estimate`/`ghost_form` por `wizard_tag`, `WizardType.spell_tag`, sonidos por tag: **055i-b** (`WizardType.sounds: SoundSet`).
- `MatchRules.biome_god` y `MatchBiome` tipados, y los 12 lectores del mundo de `MapCatalog.active()`: **055i-b** (o 063 para el mapa).
- `HudIcons` (055h), `selection_roster` por `ability_tag` (055i-b), `wizard_preview` por `BodyCatalog` (055s), `spellbook` por `GameData.book` (055e).
- Los 114 edificios con nombre `<dios>_<tag>`: un **055i-c** con la misma herramienta, después de que a1 la pruebe.
- Traducir `display_name` (hoy en inglés): no es identidad.

## 15. Orden de implementación
1. **a0:** `git mv` de los dos catálogos y sus `.uid`; ruta del script en `mode_catalog.tres`; `GameCatalog.modes` y `maps()`; C18b en `conventions.sh` y en la base; `--import`; `catalog_cases` y `team_screens_check`.
2. **a1:** `rename_resources.py` en ensayo y revisión de la tabla; `--apply` sobre magos y audio; probar el uid con un archivo; `catalog_cases` con la regla nueva; congelar `bake_catalog`; `--import`; `catalog_cases` y `rules_suite`.
3. **a2:**
   1. `WizardPick` y `MatchWire` (pick y bot).
   2. `AiSeat` tipado y `typed_seats_055i.py`.
   3. El flujo con pick tipado y `sacrifice_flow.tscn` como autoload.
   4. `ai_roster`, `ai_side`, `wizard_body._apply_pick`.
   5. `room_rules`, `ticket_glue`, `local_server_host`.
   6. La UI que lee el pick.
   7. Los llamadores de `debug/` y `agent/`.
   8. Suites headless; `vs_ai_mode` y `local_server_e2e` con diff del log.
4. **a3:**
   1. `ActiveMatch` y el paso 0 del riesgo 1.
   2. `MatchSetup` tipado.
   3. `LaunchPlan`, `LaunchFlags`, `TicketPlan`.
   4. El flujo: `_apply_match_choice`, snapshot, ≤ 200 líneas.
   5. Los pickers y los formularios.
   6. `boot._setup`.
   7. Todas las suites, `late_join`, capturas y diff.
5. Al cerrar a3:
   1. Los 3 READMEs con las 5 líneas.
   2. Encabezados sin «RFC-0xx» al frente (C9).
   3. `--update-baseline`.
   4. Tabla §7 revisada por el reviewer.
6. **a4** cuando 061 cierre.

## 16. Cómo lo verifica un humano en el editor
- **FileSystem:** `data/catalog/wizards/` muestra nombres (`jadugarr.tres`…). Al abrir uno, el inspector muestra `tag = cwa0` de solo lectura y `offered`.
- **`data/ai/seat_vs_ai.tres`:** `wizard` y `god` son recursos arrastrados; un `god` vacío dice «sorteado».
- **`sacrifice_flow.tscn`:** cambiar `default_pick → wizard` a Seerix y correr con F5 hace que el menú arranque con Seerix.
- **F5 en `boot.tscn`:**
  - Elegir Seerix + Persephone → «Jugar» → `%Choice` dice «Seerix · Dios: Persephone».
  - «Contra la IA» con el dios IA en «Pyro» → la partida arranca con el bot de Pyro.
  - «Servidor local → Crear» lista modos y mapas que encajan.
- **Duplicar un dios:** `data/gods/james.tres` → `zeus.tres`, vaciar `tag`, `display_name` «Zeus»; F5: Zeus aparece en la selección, en el dios de la IA y en la tierra. Desmarcar `offered`: desaparece. Borrar el archivo.

## 17. Preguntas abiertas (con recomendación)
1. **¿055k es la cámara (RFC) o el audio (pedido)?** Recomiendo que mande el RFC: 055k = cámara, sin archivos compartidos. El audio por tag es 055i-b/055x, y la coordinación de §12 vale igual.
2. **¿`SacrificeFlow` pasa a ser escena autoload (`sacrifice_flow.tscn`) para tener `default_pick` y `vs_ai_seat` en el inspector?** Recomiendo que sí: es la forma Godot de que el valor por defecto sea dato y no código. El riesgo 1 se mide en el paso 0.
3. **¿Regla nueva C18b** para las búsquedas por id que el regex de C18 no ve (`GameCatalog.shared().god(`/`.building(`, `TypeRef.`, `AiProfile.for_god(`, `BiomeRules.has_look(`, `MatchWire.decode_*` fuera de `scenes/net/` y de las pantallas de sala)? Recomiendo que sí, con base propia, para que la baja de C18 no sea mover llamadas a nombres que el grep no cuenta.
4. **¿El cable conserva la clave `model` en el pick?** Recomiendo conservarla en 055i-a (byte idéntico, sin subir versión, fixtures intactos) y sacarla cuando 055s haga del cuerpo una escena.
5. **¿Los hechizos con nombre humano (a4) van ahora o al cerrar 061?** Recomiendo al cerrar 061: hoy 24 escenas de hechizos y 5 dioses los nombran, y 061 sigue agregando.
6. **¿`offered` en `GodType` y `WizardType`** para «quitar del lobby» sin borrar el archivo? Recomiendo que sí: un tilde, mismo patrón que `MapDefinition.room_selectable`.
7. **¿Un `tag` vacío toma el nombre del archivo para el contenido nuevo**, sin cambiar los ids viejos (`cwa0`)? Recomiendo que sí: crear contenido no pide inventar un id de 4 letras, y la red no se entera de los renombrados.
8. **¿`bake_catalog` se congela (sale con un mensaje si `data/catalog/` tiene archivos) o se borra ya?** Recomiendo congelarlo ahora y borrarlo en 055z junto con `catalog_builder.gd`.
9. **¿Los modos se descubren por carpeta (`data/modes/*.tres`, 1 lugar) en vez de `mode_catalog.tres` (2 lugares)?** Recomiendo dejarlo como está: cumple el límite de dos lugares y el orden del array es el orden de la pantalla. Se revisa si alguien pide modos seguido.
10. **¿Estampar uid en los `.tres` del catálogo** (re-guardarlos con Godot, commit aparte con ruido de formato) para poder renombrar desde el dock en el futuro? Recomiendo que sí, si el paso 0 de a1 confirma que headless lo hace. Si no, alcanza con la herramienta.
