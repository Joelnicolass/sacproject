# Architecture

One page on how the game is put together today. Conventions and checks are in [`../CONTRIBUTING.md`](../CONTRIBUTING.md);
step-by-step recipes (a creature, a spell, a map) in [`HOWTO.en.md`](HOWTO.en.md). Old design records are in
[`archive/`](archive/README.md) and do not describe the current code.

## Folders

| Folder | What lives there |
|---|---|
| `scenes/<system>/` | Scenes and the scripts attached to them, one folder per game system |
| `data/` | `.tres` resources edited in the inspector: `catalog/` (creatures, spells, wizards, abilities, buildings), `gods/`, `ai/`, `fx/`, `audio/`, `look/`, `modes/`, `net/`, `ui/`, `i18n/strings.csv`, `match_rules.tres` |
| `assets/` | Imported art and sound. `original/` comes from the original game (Git LFS, read-only); `custom/` is your own content; `cc0/`, `mm/` (Material Maker) and `surfaces/` (normal maps) are extra textures |
| `addons/` | `mp_kit` (network), `fsm_kit` (state machines), `agent_kit` (automated captures), `gut` (tests) and the editor plugins of this game (`sacrifice_tools`, `terrain_tools`, `surface_maps`) |
| `tools/` | Import, bake, audit and lint scripts. The game never loads anything from here |
| `test/unit/` | GUT tests |

## Autoloads

| Autoload | For |
|---|---|
| `SacrificeFlow` (`scenes/core/flow/sacrifice_flow.tscn`) | Takes the player from the menu to a match and back: solo, «Contra la IA», online rooms, «Servidor local», LAN. Holds the local pick (wizard + god) and the AI seats. Extends the kit's `MpFlow` |
| `FxBus` (`scenes/fx/fx_bus.tscn`) | Plays visual effects (`ParticleType`, `BeamType` or an `FxScene`) from pools, locally or broadcast to every peer |
| `SoundBus` (`scenes/audio/sound_bus.tscn`) | Owns the audio players: 2D, 3D, voices, music and ambience. Client only, closed on a dedicated server |
| `MpKit`, `MpLobby` (`addons/mp_kit/`) | The network kit: peers, slots, snapshots, rooms |
| `AgentKit` (`addons/agent_kit/`) | Captures and scripted clicks for automated checks; it does nothing in normal play |

State that belongs to one match never lives in an autoload: it is a node of `match.tscn`. `ActiveMatch`
(`scenes/core/catalog/active_match.gd`) is a static holder of the map, mode and seed this process plays. The type catalog
(`data/catalog/`, `data/gods/`) is the static `GameCatalog.shared()`, not an autoload.

## The life of a match

1. `scenes/core/boot.tscn` is the main scene: the menu. Its buttons call `SacrificeFlow` (`play_solo`, `play_vs_ai`,
   `host_online_room`, `join_online`, `join_local_server`…).
2. `SacrificeFlow` stores the choice in a `MatchSetup` and `ActiveMatch`, shows `LoadingScreen` and loads
   `scenes/match/match.tscn` through the kit's world loader.
3. `MatchWorld` (`match_world.gd`, root of `match.tscn`) instances the map of the active `MapDefinition` as `World/Map`
   (a `MapRoot`) and plugs the systems into its sockets (terrain, navmesh, starts, buildings, NPC spawns).
4. `Warmup` (`scenes/look/warmup/`) draws every material once behind the loading screen; then the world reports it is ready
   and the kit's match gate starts the match when every seat has loaded.
5. `MatchState` (`match_state.tscn`) holds the altars, the defeated sides and the winner. Its child `Defeat` (`DefeatRule`)
   decides on the server: a side whose last altar falls is out; the last side standing wins. Its child `Net`
   (`MatchStateNet`) sends the snapshot to clients.
6. `MatchState.finished` → the HUD shows `MatchResult`; leaving calls `SacrificeFlow.return_to_boot()` (or goes back to the
   room screens).

## `match.tscn`

The root's children are five plain group nodes; every system is placed in the scene under one of them:

- **`World`** (`Node3D`): `Map` (added at runtime as its first child, from the active map), `Camera` (`WorldCamera`),
  `MatchBiome` + `BiomeLink` (which god's land is drawn), `Wizards` + `WizardSpawner`, `Units` + `UnitSpawner`,
  `Population` (the map's villagers and NPCs), `Spells` + `SpellSpawner`, `Shots` + `ShotSpawner`,
  `Structures` + `StructureSpawner`, `DamageNumbers`, `SprayMarks`, `DropletRain`, `Ping`, `PostFx`.
- **`Systems`** (`Node`): `LocalSeat`, `Warmup`, `LoadReport`, `SoulSystem` (`scenes/souls/`), `SacrificeSystem`
  (`scenes/sacrifice/`), `MatchState`, `Nav` (`NavService`), `AiRoster`, `GraphicsApplier`, `UiScaleApplier`.
- **`Input`** (`Node`): `Selection`, `Orders`, `MatchCommand` (one child per kind of input: keys, pointer ray, armed spell,
  minimap clicks, group keys), `OrderRadial`, `Inspector`.
- **`Hud`** (`CanvasLayer`): spell book, roster, wizard stats, minimap, radial menu, result, target info, `PauseMenu`.
- **`Audio`** (`Node`): `ListenerFocus`, `CommandVoice`, `AdvisorVoice`, `CombatGauge`, `MusicDirector`, `AmbienceDirector`.

Nodes reference each other by `@export` set in the scene or by `%UniqueName`, so a node can move between groups.

Round numbers (souls, mana, times) are in `data/match_rules.tres`; the reaches of places (an altar, a fount, a soul) are
shapes in `scenes/match/reach_places.tscn`.

## A creature

A creature is `scenes/units/unit.tscn`: a thin `UnitBody` (`CharacterBody3D`) plus one child per responsibility.

- **Type:** `UnitSpawner` sets `UnitBody.type`, a `CreatureType` from `data/catalog/creatures/<name>.tres` (stats, body,
  sounds, ranged attack, ability, passives), before the unit enters the tree. Types are shared: never write to them.
- **Components:** `Health`, `ManaPool`, `Afflictions` (stun, freeze, vines…; `units/afflictions/afflictions.tscn`), `Wards`,
  `Weapons` (`Melee`, `Ranged`: the first child that wants the foe is used), `Abilities`, `Vision`, `Locomotion`,
  `Engagement` (current target), `Corpse`, `Captive`, and the presentation nodes (`BodyMount`, `CorpseLook`, `UnitSounds`,
  `BloodFx`, `HealthBar`).
- **States:** `States` is a `UnitStates` (`FsmKit` `FsmMachine`) with one `UnitState` per mode: `Idle`, `Move`, `Chase`,
  `Attack`, `Shoot`, `Dead`, `Summoning`, `RockForm`, `Held`, `Reviving`, `Cower`. `UnitBody.mode` is the only writer of
  the mode; the body runs the current state inside its own physics step.
- **Body:** the size and sockets (muzzle, feet, center) are a `BodyFrame` scene in `scenes/units/bodies/`; the model and
  its animations are in `scenes/bodies/models/` and only clients build them.
- **Orders:** the player (`scenes/orders/`) and the AI give orders through the unit's `Orders` node
  (`unit_orders.gd`), the same path for both.

Villagers (`scenes/units/villager/`) are units with an extra `VillagerBrain` FSM. Wizards (`scenes/wizards/wizard_body.tscn`)
share most components and add `Spellbook`, `Caster`, `Summoner`, `SoulPurse`, `GhostForm` and `Drive` (movement).

## From the book to the effect

1. Each god (`GodType`, `data/gods/<god>.tres`) has a `GodBook` that lists its creatures, spells and structures and the
   wizard level that unlocks each. `Spellbook` (child of the wizard) builds the book of the current level and owns the cooldowns.
2. Every entry is a `BookEntry` resource: a `SpellType` (`data/catalog/spells/<tag>.tres`), a `CreatureType` or an
   `AbilityType`. A `SpellType` points at its `action`, a scene in `scenes/spells/actions/`.
3. The HUD (`scenes/ui/spell_book/`) or a click through `MatchCommand` calls `Caster.request_cast` / `request_summon` /
   `request_structure`. On a client this becomes a `submit_*` RPC; the server (or solo) runs the cast.
4. `Caster` checks mana, target, range and cooldown, then calls the `SpellAction` child (`check`, `begin`, `finish`,
   `cancel`). The action spawns what the spell needs through `SpellSpawner`: a projectile, a `GroundZone`, a wall, a
   carrier, a ward on a body. Each kind has its own subfolder in `scenes/spells/`.
5. Damage goes through the target's `Health`; states through `Afflictions`; visuals through `FxBus`; sounds through `SoundBus`.

## Multiplayer

- The host or the server simulates; clients only draw and send orders. A node that simulates checks
  `is_multiplayer_authority()`. Solo runs the same code with no network.
- `addons/mp_kit` is an external kit (do not edit it here): peers and slots, `MpActor` (buffered poses for units, wizards
  and doctors), `MpReplicate` and `MpSpawner` for short-lived things, world loading and the start gate.
- Game-specific glue lives in `scenes/net/`: `MatchWire` (ids ↔ resources on the wire), `PickBoard` (picks by seat),
  `BiomeLink`, `MatchStateNet`, launch flags and tickets.
- **«Salas online»:** a player hosts a room; others join with its code or from the public list. Rooms are found through
  the issuer in `data/net/online_config.tres`, and players connect through its relay (`scenes/ui/online/`).
- **«Servidor local»:** the player's PC runs one dedicated match of the same game and gives the rival an address and a
  code (`scenes/net/local_server_host.gd`, `scenes/ui/local_server/`). See [`servidor_local.en.md`](servidor_local.en.md).
- A dedicated server is the same binary with `--dedicated`; it draws nothing and plays no sound.

## The AI

`AiRoster` (in `match.tscn`) seats one `AiSide` (`scenes/ai/ai_side.tscn`) per AI seat, only where the game is simulated.
The side plays like a player: `Perception` keeps what its bodies saw, `Groups` and `Stance` sum up the field, `Brain`
picks spells by phase (attack, support, convert, summon), `Tasks` give work to its creatures, and `Port` sends the
orders and casts through `Caster` and `Orders`. It never cheats. Difficulty and tactics are `data/ai/*.tres`.

## Run, test, lint

Open `game/project.godot` with Godot 4.7.2 and press F5. Formatting, lint, unit tests and the project checks are listed in
[CONTRIBUTING §9](../CONTRIBUTING.md#9-tools-and-checks).
