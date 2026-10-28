**English** | [Español](README.es.md)

# Sacrifice — a Godot 4 port

An unofficial, fan-made port of **Sacrifice** (Shiny Entertainment, 2000) to **Godot 4.7**. The goal is to play against the AI and online as in the original, with the whole game editable from the Godot editor: map, creatures, spells, animations and effects.

> **Legal notice.** This project is not affiliated with Interplay, Shiny Entertainment or the current owners of Sacrifice. The models, textures, maps and interface in `game/assets/original/` come from the original game and belong to their owners. The port's code is independent: [sacengine](https://github.com/tg-2/sacengine) (GPL) was used only as a reading reference and no code was copied.

> **Language of the game.** The in-game interface is in Spanish. This README quotes menu labels as they appear on screen, with an English gloss.

![Match against the AI on High Noon, with the minimap](docs/screenshots/match.jpg)

## What's there today

- **A full match against the AI** on High Noon. There are 15 wizards and 5 gods (Persephone, Pyro, James, Stratos and Charnel), each with its biome and its book of creatures and spells. The AI plays by the same rules as the player, without cheating.
- **Living villages:** 26 villagers, 6 taurocks and 69 buildings. Souls are collected and sacrificed at the altar.
- **71 creatures** with skeletons and animations, **53 spells**, Manalith, teleport and structures.
- **The original's interface:** spell book, selection panel, cursors and icons.
- **A minimap** that turns with the camera and has a compass. A right click on the minimap gives an order.
- **The original's sound:** 3D effects, creature, wizard and advisor voices, music per god (calm, battle, sacrifice, victory) and ambience, with per-bus volume in «Opciones → Sonido» (Options → Sound). Your own sounds go in `game/assets/custom/sounds/` (see `game/docs/HOWTO.en.md`).
- **A radial order menu and 8 formations.** Hold the right button, pick the formation and release: the units go there in that formation.
- **Server-authoritative multiplayer:**
  - «Salas online» (Online rooms): a player hosts the room from their PC and friends join with its code, through a relay;
  - «Servidor local» (Local server) to play from your PC without a VPS;
  - ENet or WebSocket transport;
  - reconnecting to the match with the same ticket.

| Menu | Pick a wizard and a god |
|---|---|
| ![Main menu](docs/screenshots/menu.jpg) | ![Wizard and god selection](docs/screenshots/pick.jpg) |

| Radial menu and formations | Minimap |
|---|---|
| ![Radial menu with the wedge formation highlighted](docs/screenshots/radial.jpg) | ![Minimap with compass and view wedge](docs/screenshots/minimap.jpg) |

## Clone and play

**Requirements**
- [Godot 4.7.2](https://godotengine.org/download) (standard; .NET is not needed).
- [Git LFS](https://git-lfs.com). The assets go through LFS (about 190 MB). **Without LFS, the game does not load.**

```bash
git lfs install
git clone https://github.com/Joelnicolass/sacproject.git
```

If you already cloned without LFS, go into the folder and fetch the assets:

```bash
git lfs pull
```

**First time:** open `game/project.godot` with Godot and wait for the import; it takes a few minutes. Then press F5 to play. From the terminal:

```bash
godot --path game --import
```

```bash
godot --path game
```

In the menu: **Cambiar personaje** (Change character) to pick a wizard and a god, and **Jugar solo** (Play alone) or **Contra la IA** (Against the AI).

**Playing does NOT need the original game installed:** the models, textures, maps and interface are already in `game/assets/original/` (through LFS). The original is only needed for the tools that re-import from it (see [Tools that need the original game](#tools-that-need-the-original-game)).

### Main controls

| Action | Key |
|---|---|
| Move and turn the wizard | `W` `A` `S` `D` or the arrows |
| Select / selection box | left click / drag |
| Order (move, attack, escort) | right click |
| Radial menu of orders and formations | hold right click or `Tab` |
| Direct formation | `Alt+1` … `Alt+8` |
| Attack / guard / retreat | `Ctrl+R` / `Ctrl+A` / `Ctrl+Space` |
| Groups | `Ctrl+1…0` sets, `1…0` picks |
| Summon creatures and cast spells | the keys the book shows on screen |
| Zoom | wheel (over the minimap, it zooms the minimap) |
| Show or hide the minimap | `M` |
| Pause | `Esc` |

## Useful commands

Run them **from `game/`** (`cd game` after cloning). `godot` stands for your Godot 4.7.2 binary: put it in the `PATH`, or replace it with the full path (on macOS, `/Applications/Godot.app/Contents/MacOS/Godot`). The `tools/` scripts take it from `GODOT_BIN` (see [Configure paths](#configure-paths)). Run one Godot at a time.

**Git LFS**

```bash
git lfs install            # once per machine: enables the LFS hooks
git lfs pull               # fetches the assets if you cloned without LFS
git lfs ls-files | head    # "*" = file downloaded, "-" = still a pointer
```

**Play and edit**

```bash
godot --path . --import    # first import (or after pulling new assets); takes a few minutes
godot --path .             # play the game
godot --path . --editor    # open the project in the editor
```

**Bakers** (they do not need the original; without `--force` they never overwrite hand edits)

```bash
godot --headless --path . --script res://tools/bake/bake_body_scenes.gd                  # body scenes of the models that lack one
godot --headless --path . res://tools/bake/bake_nav.tscn                                 # navmesh
godot --resolution 256x256 --path . --script res://tools/bake/new_creature.gd -- <tag> --name="Name" --god=pyro   # a creature from assets/custom/models/<tag>.glb
```

The same tools are in the editor under **Project > Tools > Sacrifice**.

**Importers that need the original install** (`SAC_INSTALL`; see [Configure paths](#configure-paths))

```bash
cp tools/import/local.cfg.example tools/import/local.cfg   # then fill in SAC_INSTALL= (the file is git-ignored)
export SAC_INSTALL="/path/to/Sacrifice/data"               # or use the environment variable instead
python3 tools/import/import_map.py --list                  # the original's maps with seats and size
python3 tools/import/import_map.py --map=Peaks --check     # what importing a map would change, writes nothing
python3 tools/import/import_audio.py --check               # what re-importing the audio would change, writes nothing
python3 tools/import/export_stats.py                       # creature, spell, wizard and building stats to assets/original/data/
bash tools/audit/check_original_assets.sh                  # parity of assets/original/ with the original: ASSETS PARITY PASS / FAIL
```

## How the port was made

The port was built in stages. Each large change has its RFC in [`game/rfcs/`](game/rfcs/) and its entry in [`game/docs/CHANGELOG-features.md`](game/docs/CHANGELOG-features.md) (the current state per area is in [`game/FEATURES.md`](game/FEATURES.md)). To add content, see [`game/docs/HOWTO.en.md`](game/docs/HOWTO.en.md).

1. **Extract the original's data.** The importers in [`game/tools/`](game/tools/) read the WADs of a local Sacrifice install (which everyone has to own; see [Configure paths](#configure-paths)):
   - models, with their skeleton and all their animations, to `.glb`;
   - textures, terrain, buildings, effects and interface;
   - the stats of creatures, spells, wizards and buildings.

   Everything ends up in `game/assets/original/` and `game/data/catalog/`. The game does not depend on the WADs or on any cache.
2. **Understand how it works.** The rules and numbers (damage, mana, souls, AI, orders) were read from sacengine, an open reimplementation in D, and compared against the original executable with reverse engineering. What gets copied from the original is what you notice while playing: numbers, spells and rules.
3. **Build on standard Godot.** The first port also copied sacengine's physics, navigation and animation. Later everything moved to the engine's own tools (RFC-035 and RFC-036):
   - the terrain is a 256² grid of heights (`heights.png` + `void.png` per map), editable in any image editor or in Blender;
   - villages, buildings and plants are nodes of the scene;
   - the catalog (creatures, spells, wizards) is `.tres` files editable in the inspector;
   - navigation is Godot's navmesh;
   - separation between bodies is Godot's avoidance (`NavigationAgent3D`);
   - each model has its scene with its `AnimationTree`;
   - creatures use a state machine.
4. **Network.** The server has the authority (`MultiplayerSynchronizer`, `CharacterBody3D`): the client sends orders and draws. The generic parts (rooms, tickets, dedicated launcher, transports) live in the [`mp_kit`](game/addons/mp_kit/) addon, separate from the game's rules.
5. **A studio of agents.** The work was done with a flow of AI agents:
   - a tech lead plans each RFC;
   - a developer implements;
   - the orchestrator runs the tests;
   - a playtester plays with a window and takes screenshots.

   The checks are throwaway: an **AgentKit flow** (clicks and screenshots) or harness is regenerated under `game/agent/` when a change needs it, and is not versioned.

   The kit of skills and agents is [godot-studio-skills](https://github.com/Joelnicolass/godot-studio-skills).

### Layout

```
game/
  addons/        mp_kit (network and rooms), agent_kit (tests and determinism), fsm_kit
  assets/original/  assets extracted from the original (LFS)
  data/          catalog, quality presets, rules, navmesh, UI (.tres)
  scenes/        the game: world/, ui/, net/, fx/
  rfcs/          the design of each stage
  tools/         WAD importers and baking tools
docs/screenshots/
```

## Tools that need the original game

Paths are relative to `game/`.

| Tool | Needs the original? | What it produces |
|---|---|---|
| Play (F5), `godot --path game` | **No** | Nothing: the assets are already in `game/assets/original/` (LFS) |
| Throwaway AgentKit flows and captures | **No** | PASS/FAIL and screenshots, not versioned |
| `tools/import/export_stats.py` | **Yes** | `assets/original/data/*.json` (creature, spell, wizard, building stats) |
| `tools/import/export_skeletal.py` | **Yes** | `assets/original/models/*.glb` + `index.json` (skeleton and animations) |
| `tools/import/export_skeletal_reference.py` | **Yes** | Reference OBJ in the system temp folder (`--out` to change it) |
| `tools/import/import_textures.py` | **Yes** | `assets/original/textures/*.png` |
| `tools/import/import_props.py` | **Yes** | `assets/original/props/*.glb` (buildings and plants) |
| `tools/import/import_themes.py` | **Yes** | `assets/original/themes/<god>/` (ground, sky, light) |
| `tools/import/import_ui.py` | **Yes** | `assets/original/ui/` and `assets/original/fx/` (HUD, icons, cursors, particles) |
| `tools/import/import_map.py` (includes `--list`) | **Yes** | `assets/original/maps/<tag>/` (tiles, light, entities) |
| `tools/import/import_audio.py` | **Yes** | `assets/original/audio/` (effects, voices and music) + `index.json`. Already in the repo (LFS) |
| `tools/audit/check_original_assets.sh` | **Yes** | Parity of `assets/original/` with the original (`ASSETS PARITY PASS/FAIL`) |
| `tools/import/scaffold_map.py` | No: uses what `import_map.py` already left | `MapDefinition`, `map.tscn`, empty `nav.res` |
| `tools/import/classify_ground_tiles.py`, `sample_grass_palette.py` | No: they use `assets/original/` | `high_noon_tiles.tres`, proposed grass palette |
| `tools/bake/*` (navmesh, catalog, `bake_body_scenes`, `new_creature`) | No: `bake_body_scenes` uses the repo's `.glb` files and `index.json` | Scenes, `.tres` and navmesh |
| `tools/terrain/heights_from_original.gd` | **Yes** (it reads the `.scp`) | `scenes/map/maps/<tag>/heights.png` + `void.png`, the ground of a map of the original |
| **Project > Tools > Sacrifice** menu | Only «Listar mapas del original» (List the original's maps) and «Importar audio del original» (Import the original's audio); they are marked «(requiere juego original)» (requires the original game) in the menu | Output in a dialog |

These tools read the `.wad` and `.scp` files of the installed game; **the original is not in the repo** (it is the commercial game). If it is missing, they print a message in Spanish that explains which folder is needed and how to point to it, and exit with an error. All of them start their header and their `--help` with «Requiere el juego original instalado (SAC_INSTALL)» (requires the original game installed) or with «No necesita el juego original» (does not need the original game).

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

**Godot and Blender** (the scripts in `game/tools/`). They pick:

- `GODOT_BIN`: the environment variable if set; otherwise `godot` from the `PATH`; otherwise the macOS one (`/Applications/Godot.app/Contents/MacOS/Godot`).
- `BLENDER_BIN`: the environment variable if set; otherwise `blender` from the `PATH`; otherwise the macOS one (`/Applications/Blender.app/Contents/MacOS/Blender`).

```bash
export GODOT_BIN="/path/to/Godot_v4.7.2"   # optional if godot is in the PATH
export BLENDER_BIN="/path/to/blender"      # only for tools/blender/ and your own creature from Blender
```

## Coming up

- **Web port**, on the `web-port` branch: a browser client with WebRTC P2P, signaling in Node and a light preset.
- Grass and visual improvements.

---

### Copilot skills in VS Code

This repo also publishes skills and slash commands for Copilot from `.github/skills/`, with a mirror copy in `skills/` and `commands/`. To regenerate them, run `./scripts/sync-vscode-prompts.sh` and then **Developer: Reload Window** in VS Code.
