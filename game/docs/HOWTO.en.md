**English** | [Español](HOWTO.md)

# How to add and change things

A short guide. All paths are from `game/`. General rule: content is `.tres` files in `data/` (one file per type, edited in the inspector) and behavior is scenes and nodes in `scenes/<domain>/`. No `match tag` in code. Every folder has its `README.md`.

The in-game interface and the **Project > Tools > Sacrifice** menu are in Spanish: labels are quoted as they appear, with an English gloss.

After any content change, run the validator (last section).

## A creature

For a creature that does not exist in the original, go straight to «Create your own creature from Blender». These steps are for the catalog ones.

1. Duplicate a sibling in `data/catalog/creatures/` (for example `ahcr.tres`) and name it `<tag>.tres`. The file name is the `tag`.
2. In the inspector: `tag`, `display_name`, `god`, `model` (the tag of the model in `assets/original/models/<model>.glb`), health, speed, resistances, `ability_tags` and the animations.
3. The body size goes in `data/catalog/body_sizes/<model>.tres` (`BodySize`: box, `height`, `radius`, `reach`). If another creature already uses the model, it already exists.
4. The model's scene is `scenes/bodies/models/<model>.tscn`. If it is missing, bake it: **Project > Tools > Sacrifice: Hornear modelos que faltan** (Bake missing models) (or `tools/bake/bake_body_scenes.gd`). It only writes the missing ones; what you already edited is not overwritten. That is where you change which clip each role plays (`AnimationTree`).
5. So that the player can summon it, put it in the god's book: `data/gods/<god>.tres` → `book` → `creatures` (and a line in `unlocks` with the wizard level at which it comes in).
6. Abilities: `ability_tags` points to `data/catalog/abilities/`; the logic of each one is a node in `scenes/units/abilities/`.

## Create your own creature from Blender

A new enemy or character needs nothing from the original game (neither `index.json` nor the WADs): it comes from a `.glb`.

1. **Model and animate.** An armature with the skinned mesh and **one action per animation**, named by role (capitals, separators and Blender's `.001` do not matter):
   `idle` (required), `run` (or `walk`), `attack`, `shoot`, `cast`, `hit`, `death`, `fly`, `takeoff`, `land`, `hover`, `knock`, `get_up`. A role without a clip resolves by itself (`walk`→`run`, `shoot`→`attack`, `hit` and anything missing→`idle`; without `death` the body falls with a Tween).
   **Strike variants:** up to three attack clips, `attack`, `attack2`, `attack3` (or `attack_a`, `attack_b`, `attack_c`), each with its own mark (`attack2_at60`). The game picks at random between `attack` and `attack2` on each strike; `attack3` is the downward strike (against a much lower target). Each strike plays its own clip and hits at its own moment. With only `attack3` and no `attack2`, the second of the pair repeats `attack`.
   The **moment of the hit** goes in the name: `attack_at45` = at 45 % of the clip, `attack_f18` = at frame 18; without a mark it is the middle (50 %). (Blender does not export markers to glTF.) Make it face **-Y** in Blender (it ends up facing +Z, like the game) with the feet at Z = 0.
2. **Export** to `game/assets/custom/models/<tag>.glb` (File > Export > glTF 2.0, GLB format, *Animation* > **Actions** mode; the file name is the `tag`: lower case, no spaces). Open the project in the editor once (or `$G --headless --path . --import`) so that Godot imports it. Full example: `tools/blender/make_test_creature.py`.
3. **Create the creature**: **Project > Tools > Sacrifice: Nueva criatura desde modelo…** (New creature from model…) and pick the `.glb`; or from the console:
   ```bash
   $G --headless --path . --script res://tools/bake/new_creature.gd -- <tag> --name="Name" --god=pyro
   ```
   It writes three files and **overwrites none that exist** (`--force` redoes all three): `scenes/bodies/models/<tag>.tscn` (the model with its `AnimationTree` and the hit event), `data/catalog/body_sizes/<tag>.tres` (box, height, radius and reach measured from the mesh) and `data/catalog/creatures/<tag>.tres` (stats from `data/templates/creature.tres` plus the clip data). It also draws the **HUD icon** (book and selection): if `assets/custom/icons/<tag>.png` exists it uses it as is (it never overwrites it; it is yours, 32×32); otherwise it renders it from the model (idle pose, camera over its box, dark disc with a golden ring) and saves it there. Drawing needs a window: from the plugin one opens by itself for a moment; from the console, drop `--headless` (`--resolution 256x256`) or run `$G --path . --script res://tools/bake/creature_icon.gd -- <tag>` afterwards (`--force` redoes it). You can also assign a texture to the creature's `icon` field in the inspector (it beats everything). `--icon` redraws it in `new_creature.gd`; `--no-icon` skips it. It prints which clip it took for each role and which ones it did not use.
4. **Tune in the inspector.** Stats, mana and soul cost, `display_name` in the creature's `.tres`; size in the `body_sizes` (`reach` is how far the strike gets). Which clip each role plays: the states of the `AnimationTree` in the model's scene (if you change a state's clip, set its `timeline_length` to the new clip's seconds); the hit frame: the `attack` key of the `Events` player's animation. If you touched roles or the hit, **Project > Tools > Sacrifice: Sincronizar criatura con su modelo…** (Sync creature with its model…) (or `new_creature.gd -- <tag> --sync`) reads the scene again and updates the times the rules use (hit, shot, stun, flight); your stats are not touched.
5. **Put it in a book**: `data/gods/<god>.tres` → `book` → `creatures` (drag the `.tres`) and a line in `unlocks` with the wizard level. Run the validator: `CATALOG PASS` (it also warns if a named clip does not exist in the `.glb`).
6. **Sounds** (optional): drop `death_1.wav`, `swing_1.wav`… in `assets/custom/sounds/creatures/<tag>/` before step 3, or afterwards with «Hornear sonidos» (Bake sounds). See «Your own sounds».

End-to-end test (a Blender creature, summoned, walks, hits on the strike and dies): `$G --headless --fixed-fps 600 --path . res://debug/units/custom_creature.tscn` prints `CUSTOM_CREATURE PASS` (it counts which strike variant each swing used and when it fell, and checks the icon).

## Your own sounds

They need nothing from the original game. They work for any creature (including one of yours from Blender), wizard or set.

1. **Drop the files** (`.ogg` or `.wav`) in `assets/custom/sounds/<type>/<tag>/<event>[_n].ogg`. For example, `assets/custom/sounds/creatures/mibicho/death_1.wav` and `swing_1.wav`. `<type>` is `creatures` or `wizards`, and `<tag>` is the creature's or the wizard's. Each file of the same event is a variant (`death_1`, `death_2`…), and the game picks one at random.
2. **Event names** (those of `SoundEvent`, in `scenes/audio/sound_event.gd`):
   - Creature: `summon` (when summoned), `swing` (strike), `shoot` (shot; without it, it uses `swing`), `damaged` (takes damage), `death`, `selected` (you pick it), `ack` (acknowledges a move), `attack_ack` (acknowledges an attack), `annoyed` (you picked it many times).
   - Wizard: `incantation` (casts), `damaged`, `death`, `ghost` (rises as a ghost).
   - `selected`, `ack`, `attack_ack`, `annoyed` and `incantation` go to the `Voice` bus; the rest, to `SFX`. A name that is not in the list is baked anyway, but the game does not play it, and the bake warns.
3. **Bake:** **Project > Tools > Sacrifice: Hornear sonidos** (Bake sounds) (or `$G --headless --path . --script res://tools/bake/bake_sound_sets.gd -- --only=custom`). It writes `data/audio/custom/<type>/<tag>.tres`, which wins over the original's. It does not overwrite one that exists: `--force` redoes it and loses what you edited. If the creature is new, «Nueva criatura desde modelo…» (New creature from model…) bakes its `creatures/<tag>/` folder in one go.
4. **Review:** open the `.tres` in the inspector. There is one cue per event, and ▶ on a stream plays it. Volume, `cooldown_s` and `max_voices` are tuned there. In the game, the lab `debug/audio/f360_audio_lab.tscn` (F6 and the `debug_audio_event` action) shows each event that sounds and its file. Without a window, the test is `bash agent/runs/run_audio_cases.sh`; the `lab_052i` case bakes two test `.wav` files for `testmonster` and plays them.

More detail (FX sounds, music and ambience per god): `data/audio/README.md`.

## A spell

A spell is two things: the data and, if it has its own procedure, a scene.

1. **Data.** Duplicate a `SpellType` from `data/catalog/spells/` as `<tag>.tres` (mana, range, cooldown, cast time, damage). Put it in the god's `book` → `spells` (or `structures` if it is a structure).
2. **Action.** If the spell does more than the common cast, create a scene in `scenes/spells/actions/` with a script that extends `SpellAction` (or `AimedAction` for a strike on a body under the cursor). Fill in `tag` (the `SpellType`'s), `pick` (ground, own creature, soul, own building) and `prompt` in the inspector; the editor warns if something is missing.
3. **Registration.** Instance the scene as a child of `Caster/Actions` in `scenes/wizards/wizard_body.tscn`. Removing the node turns the spell off («No implementado», Not implemented, in the book).
4. Visual effects are requested by name from `FxBus` (see «An FX»).

## A god

1. Duplicate `data/gods/pyro.tres` as `<god>.tres` (`GodType`): `tag`, `display_name`, `sort_order`, and the theme (`data/themes`), look (`data/look`) and cast FX (`data/fx`) `.tres` files.
2. `ai_profile`: an `AiProfile` from `data/ai/` (duplicate `profile_pyro.tres`).
3. `book`: a `GodBook` with `creatures`, `spells`, `structures` and `unlocks`. They are references to the `.tres` files in `data/catalog/`: adding something to the book is dragging it into the list.
4. The character picker and the catalog pick it up by themselves (`GameData`).

## A building

- **Type.** `data/buildings/<name>.tres` (`BuildingType`: name, max health, whether it gives shelter, and the ruin). The scene with the same name in `scenes/structures/buildings/` is the building you drag into a map (root `MapBuilding`, parts saved under `Visuals`). A new one is made by duplicating a `.tres` and its scene; «Ajustar a las partes» (on the root) measures the box that holds the parts, which you can also drag with the handles of `Collision`.
- **On the map.** Drag `scenes/structures/buildings/<name>.tscn` under `Buildings` in the map scene. Move and rotate it with the gizmo: the transform is the truth and the model shows in the editor; with «Editable Children» you see and move the parts of that instance. With `max_health` 0 it is indestructible.
- **As a structure spell** (the Manalith): it is a `SpellType` in the book's `structures` plus an action in `Caster/Actions`; the body is `scenes/structures/structure.tscn`.

## An NPC

1. Instance `scenes/map/npc_spawn.tscn` under `Npcs` of the map scene.
2. Drag the creature (`data/catalog/creatures/<tag>.tres`) to `creature` and set `side` (the side no player takes: the seats are sides 0..N-1). The marker's position is where it is born; the transform's rotation is where it faces; in the editor you see a ghost of the creature.
3. `MapPopulation` turns them into units when the match starts (on the server or in single player).

## An FX

- **Particles.** A `ParticleType` in `data/fx/<name>.tres` (atlas, frames, size, life, gravity, count). It is played with `FxBus.play("<name>", position)`; the name is the file's.
- **Beam.** A `BeamType` in `data/fx/beams/` and `FxBus.play_beam(...)`.
- **Something with its own shape** (rings, spikes, portal): a packed scene in `scenes/fx/` with its shader, and `FxBus.play_scene(path, position, parameters)`. One effect, one scene, one shader.
- The effect's lights: `data/fx/lights/`.

## A map

A map is a folder `scenes/map/maps/<tag>/` with its `map.tscn` (root `MapRoot`), its `MapDefinition` `<tag>.tres` (scene, terrain, tiles, light and navmesh, typed) and the `nav.res`; buildings and NPCs are nodes of `map.tscn` (`Buildings`, `Npcs`); its data from the original goes in `assets/original/maps/<tag>/`. `MapCatalog` finds the folder by itself and `--map=<tag>` picks it. More in `scenes/map/README.md`.

**Import one from the original** (RFC-050; the list of the 31 with seats and size: `python3 tools/import/import_map.py --list`). From `game/`. **Requires the original game installed** (`SAC_INSTALL`, see «Configure paths» below): `import_map.py` and `import_themes.py` read it; `scaffold_map.py` does not. `G` is the Godot binary and `<Name>` the `.scp`'s name without the `(N)`, for example `Peaks` or `WinterWonder` (the tag comes out by itself: `winter_wonder`).

```bash
G="${GODOT_BIN:-godot}"   # see «Configure paths» below
python3 tools/import/import_map.py --map=<Name> --terrain-bin=/tmp/<tag>.bin   # tiles, light, ntts, widgets + the terrain bin
python3 tools/import/scaffold_map.py --map=<Name>                              # MapDefinition, map.tscn (starts with their WizardSpot), empty nav.res
python3 tools/import/import_themes.py                                            # adds the map's tile ids to the other gods' atlases
bash agent/harness/godot_run.sh $G --headless --path . --script res://tools/bake/import_terrain.gd -- --map=<tag> --bin=/tmp/<tag>.bin
bash agent/harness/godot_run.sh $G --headless --path . --import                  # imports tiles.png (the glb reads it)
bash agent/harness/godot_run.sh $G --headless --path . --script res://tools/bake/terrain_glb_export.gd -- --map=<tag> --force
bash agent/harness/godot_run.sh $G --headless --path . --import                  # once more: terrain.glb
bash agent/harness/godot_run.sh $G --headless --path . res://tools/bake/bake_nav.tscn -- --map=<tag>
bash agent/harness/godot_run.sh $G --headless --path . res://tools/bake/bake_nav.tscn -- --map=<tag> --check   # twice
bash agent/harness/godot_run.sh $G --headless --path . res://tools/audit/check_map_starts.tscn -- --map=<tag>  # the starts land on ground and in one region
bash agent/runs/run_050_maps.sh <tag>                                            # smoke: AI vs AI for 0.5 min
```

After importing, `map.tscn` and `<tag>.tres` are edited by hand (the scene is the truth). Careful with `--force`: it overwrites what you edited. The plants of a map that is not James's stay empty until the models of its widgets exist. `room_selectable = false` in the definition takes it out of the rooms.

**A map of one god's land with its own tiles** (RFC-059: `tutorial_valley`, `alpine_meadow`, Persephone's). `import_map.py --native-tiles` also writes `tiles_native.png` (the ids the `.scp` stores) and `atlas_native.png` (the tiles of the map's land that it uses, each at its id); `scaffold_map.py` hangs them as `ground_native.tres` (`NativeGround`) from the definition (`native_ground`) and from the map's `Look`: a biome of that god (`LookProfile.god`) paints the ground with them; with another biome the ground is the god's atlas, as always. A `.scp` outside the folder (the tutorial) goes as `--scp="Tutorial/(tu02).scp" --tag=tutorial_valley`; `--no-npcs` leaves `Npcs` empty and `--not-playable` sets `playable = false` (no room or menu offers it; `--map=<tag>` and the debug scenes still open it). Plants: `scaffold_map.py --map=<Name> --wire-flora` writes a density PNG per species (`scenes/map/maps/<tag>/flora/`) and hangs a `FloraLayer` per species under a `Vegetation` node of the map.tscn (import the project once afterwards); paint the PNGs or add a `VegetationPatch` by hand. The Godot steps that read the definition (`import_terrain.gd`, `terrain_glb_export.gd`) need the map to load: pass `--out=` to the first and write the `.glb` once with `export_data` before `--import`, or they would write into High Noon.

**Make one by hand** (example: `test_flat4`, the 4-seat test map, in `scenes/map/maps/test_flat4/`):

1. Copy the folder of a similar map (`test_flat/` or `test_flat4/`) to `scenes/map/maps/<tag>/`. The terrain can be its own (`terrain.glb` from Blender) or a reference to another map's: `test_flat4` uses `test_flat`'s `terrain.res` without copying it.
2. In `map.tscn`, one `PlayerStart` per seat under `MapProps/Starts` (`Start1`…`Start4`, with `slot` 1..N without repeats) and its altar; move each start's `WizardSpot` with the gizmo (the wizard appears there, facing where it faces); the fountains under `MapProps/Founts`. A building is dragged under `Buildings`. In `test_flat4`, seats 1 and 2 are on the same side and 3 and 4 opposite, because `2v2` puts 1+2 against 3+4.
3. The sides come from the nodes: each `PlayerStart` is a seat (`slot`; a `team` above 0 allies the seats that share it, 0 = enemy of everyone) and each `side` of an `NpcSpawn` is a side no player takes. The teams of a mode are set by the mode.
4. `<tag>.tres` (`MapDefinition`): `tag`, `display_name`, `map_scene`, `terrain`, `nav` (and `tiles`/`light` if it has them) dragged from the inspector, and `player_starts` (= number of `PlayerStart`). `room_selectable = false` if it is only for testing (the rooms offer it with `--room-test-maps`).
5. There is no list to edit (`MapCatalog` scans the folder). Bake the navmesh («Hornear navmesh» button of `NavRegion`) and run the validator: it fails if the `PlayerStart`s do not match `player_starts`.

A map only shows up in a mode if it has one start per seat: High Noon (2) offers `1v1`; `winter_wonder` and `test_flat4` (4) also offer `2v2`, `ffa3` and `ffa4`.

## A mode

A mode (how many seats, which team each one is on, how you win) is a `GameMode` `.tres` in `data/modes/`. It has no code.

1. Duplicate a similar one (for example `2v2.tres`) and name it `<tag>.tres`.
2. In the inspector: `tag` (the one of `--mode=<tag>` and of the room), `display_name` (a key of `data/i18n/strings.csv`, like `MODE_2V2`; add yours with its text), `team_of_seat` (the team of each seat, seat 1 first: `[0,1]` is 1 against 1, `[0,0,1,1]` is 2 against 2, `[0,1,2]` three against everyone; teams go from 0 without gaps) and `room_selectable`.
3. Add it to `modes` in `data/modes/mode_catalog.tres`.
4. Run the validator. It warns if no map has starts for all the mode's seats; without such a map, the screens do not offer it.

To try it without the screens: `--map=test_flat4 --mode=<tag>`.

## Play 2 against 2

You need a 4-seat map: `winter_wonder`, or `test_flat4` for testing.

- **Alone, against the AI:** in the boot screen pick the «2 contra 2» (2 against 2) mode and the map, and press «Contra la IA» (Against the AI). The AI plays your ally and both rivals (their god comes from the «Dios de la IA» (AI god) picker). In a debug build the boot screen also offers the test maps.
- **In a room:** start the room server (for the test maps, with `--room-test-maps`):
  ```bash
  $G --headless --path . res://scenes/net/room_server.tscn -- --room-server --lobby-config=res://data/net/lobby_config_local.tres --room-test-maps
  ```
  In the editor, **Debug > Customize Run Instances** with 2 instances and F5. A presses «Salas online» (Online rooms), creates a room with the «2 contra 2» mode and the map. B sits in seat 2 (same team). A, the host, picks god and difficulty in «IA nueva:» (New AI) and presses «Agregar IA» (Add AI) on seats 3 and 4. Both press «Listo» (Ready). At the end, the room says «Ganó tu equipo» (Your team won) or «Ganó el otro equipo» (The other team won). Changing team is changing seat.
- **Local server:** in «Servidor local» (Local server) → «Crear servidor local» (Create local server), pick mode and map and, for each seat that is not yours, a person or an AI. Each person's seat has its code: give each one theirs, with the address and the port.

## Change the balance

- **A creature, a spell, a wizard, a building:** open its `.tres` in `data/catalog/<type>/` and change the number in the inspector. There is no JSON or separate table; the game reads the file.
- **Match rules** (duration, friendly fire, caps): `data/match_rules.tres` (`MatchRules`).
- **AI and difficulty:** `data/ai/`.
- **Graphics quality:** `data/look/quality_*.tres`.
- A `.tres` is not mutated at runtime. After touching numbers, the determinism bench will change its fingerprint on purpose: `agent/det_baseline.txt` is the baseline: re-record it only if the balance change is what you wanted (`agent/README.md`).

## Run the tests and the validator

Everything runs from `game/` and one Godot at a time (the queue is `agent/harness/godot_run.sh`).

```bash
G="${GODOT_BIN:-godot}"   # see «Configure paths» below

# Conventions lint (grep/awk, no Godot, ~1 s; fails if a count goes above tools/lint/baseline.txt)
bash tools/lint/conventions.sh

# Catalog validator: prints CATALOG PASS or CATALOG FAIL with the failing file
bash agent/harness/godot_run.sh $G --headless --path . --script res://debug/suite/catalog_cases.gd

# Rules, without a window
bash agent/harness/godot_run.sh $G --headless --fixed-fps 600 --path . res://debug/suite/rules_suite.tscn

# Quick determinism bench, against agent/det_baseline.txt
bash agent/run_determinism.sh quick --no-window
```

From the editor, **Project > Tools > Sacrifice** runs the validator, re-bakes the navmesh and bakes the missing models, and shows the output in a dialog. The minimap has a «Re-hornear minimapa» (Re-bake minimap) button in the inspector of `MinimapTerrainBake`.

The console bakes (without `--force` they do not overwrite hand edits):

```bash
$G --headless --path . --script res://tools/bake/bake_body_scenes.gd        # only the missing ones
$G --headless --path . --script res://tools/bake/bake_body_scenes.gd -- --force   # redoes all (overwrites your changes)
$G --headless --path . res://tools/bake/bake_nav.tscn                      # navmesh
```

A new test goes in `debug/<domain>/` (and in `agent/det_cases.txt` if it is a bench case).

## Tools that need the original game

Paths are relative to `game/`.

| Tool | Needs the original? | What it produces |
|---|---|---|
| Play (F5), `godot --path game`, the room server | **No** | Nothing: the assets are already in `game/assets/original/` (LFS) |
| Tests: `agent/run_determinism.sh`, `rules_suite`, `agent/runs/*.sh`, AgentKit flows | **No** | PASS/FAIL, screenshots in `agent/out/` |
| `tools/import/export_stats.py` | **Yes** | `assets/original/data/*.json` (creature, spell, wizard, building stats) |
| `tools/import/export_skeletal.py` | **Yes** | `assets/original/models/*.glb` + `index.json` (skeleton and animations) |
| `tools/import/export_skeletal_reference.py` | **Yes** | Reference OBJ in `agent/out/skeletal_ref/` (not versioned) |
| `tools/import/import_textures.py` | **Yes** | `assets/original/textures/*.png` |
| `tools/import/import_props.py` | **Yes** | `assets/original/props/*.glb` (buildings and plants) |
| `tools/import/import_themes.py` | **Yes** | `assets/original/themes/<god>/` (ground, sky, light) |
| `tools/import/import_ui.py` | **Yes** | `assets/original/ui/` and `assets/original/fx/` (HUD, icons, cursors, particles) |
| `tools/import/import_map.py` (includes `--list`) | **Yes** | `assets/original/maps/<tag>/` (tiles, light, entities, terrain) |
| `tools/import/import_audio.py` | **Yes** | `assets/original/audio/` (WAV effects, Ogg voices or WAV without ffmpeg, MP3 music) + `index.json`. Already in the repo (LFS) |
| `tools/audit/check_original_assets.sh` | **Yes** | Parity of `assets/original/` with the original (`ASSETS PARITY PASS/FAIL`) |
| `tools/import/scaffold_map.py` | No: uses what `import_map.py` already left | `MapDefinition`, `map.tscn`, empty `nav.res` |
| `tools/import/classify_ground_tiles.py`, `sample_grass_palette.py` | No: they use `assets/original/` | `high_noon_tiles.tres`, proposed grass palette |
| `tools/bake/*` (navmesh, catalog, `bake_body_scenes`, `new_creature`, `bake_sound_sets`, terrain) | No: `bake_body_scenes` uses the repo's `.glb` files and `index.json`; `import_terrain.gd` reads the `.bin` written by `import_map.py` | Scenes, `.tres` and navmesh |
| **Project > Tools > Sacrifice** menu | Only «Listar mapas del original» (List the original's maps) and «Importar audio del original» (Import the original's audio); they are marked «(requiere juego original)» (requires the original game) in the menu | Output in a dialog |

These tools read the `.wad` and `.scp` files of the installed game; **the original is not in the repo** (it is the commercial game). If it is missing, they print a message in Spanish that explains which folder is needed and how to point to it, and exit with an error. All of them start their header and their `--help` with «Requiere el juego original instalado (SAC_INSTALL)» (requires the original game installed) or with «No necesita el juego original» (does not need the original game).

### Import the original's audio

Almost nobody needs it: the already imported audio is in the repo through Git LFS (`assets/original/audio/`: WAV effects, Ogg voices, MP3 music), with its sets baked in `data/audio/`. It is only re-run if the importer changes.

1. It needs the original game installed. Point to the folder with the `.wad` files as in «Configure paths»: `SAC_INSTALL`, `tools/import/local.cfg` or **Editor Settings > sacrifice > original_install_path**.
2. **Project > Tools > Sacrifice: Importar audio del original** (Import the original's audio) (or `python3 tools/import/import_audio.py`; `--check` shows what would change without writing).
3. Voices are compressed to Ogg with ffmpeg. Without ffmpeg in the `PATH`, it warns and saves them as WAV (about four times heavier). `--codec=wav` asks for WAV on purpose.
4. Afterwards, «Hornear sonidos» (Bake sounds) writes the missing sets. The bake no longer needs the original: it reads `assets/original/audio/index.json`.

### Configure paths

**The original game** (only for the tools in the table above). You need the folder that holds the `.wad` files (for example `spells.wad`, `models.wad`, `main.wad`), usually named `data`, with the `maps/` folder (the `.scp` files) next to it. It is looked up in this order, with no default path:

1. The environment variable `SAC_INSTALL` (the folder with the `.wad` files) or `SAC_ROOT` (the game's root, the one with `data/` and `maps/`). `SAC_MAPS` is optional if `maps/` is somewhere else.
2. The file `game/tools/import/local.cfg` (not versioned): copy `local.cfg.example` and fill in `SAC_INSTALL=`.
3. From the Godot editor: **Editor > Editor Settings > sacrifice > original_install_path**. The «Sacrifice» plugin passes it as `SAC_INSTALL` to the processes it launches.

Typical install locations: GOG on Windows (`C:\GOG Games\Sacrifice\data`), Steam on Windows (`...\steamapps\common\Sacrifice\data`), and on macOS or Linux the `drive_c/.../Sacrifice/data` folder inside the Wine prefix or the CrossOver bottle. The folder is checked for `spells.wad`, `models.wad` and `main.wad`.

```bash
export SAC_INSTALL="/path/to/Sacrifice/data"
cd game && python3 tools/import/import_map.py --list
```

**Godot and Blender** (the scripts in `game/agent/` and `game/tools/`). All of them read `agent/harness/env.sh`, which computes the project root from its own location and picks:

- `GODOT_BIN`: the environment variable if set; otherwise `godot` from the `PATH`; otherwise the macOS one (`/Applications/Godot.app/Contents/MacOS/Godot`).
- `BLENDER_BIN`: the environment variable if set; otherwise `blender` from the `PATH`; otherwise the macOS one (`/Applications/Blender.app/Contents/MacOS/Blender`).

```bash
export GODOT_BIN="/path/to/Godot_v4.7.2"   # optional if godot is in the PATH
export BLENDER_BIN="/path/to/blender"      # only for tools/blender/ and your own creature from Blender
```
