# Sacrifice — port a Godot 4

Port no oficial de **Sacrifice** (Shiny Entertainment, 2000) a **Godot 4.7**, hecho por un fan. El objetivo es jugar contra la IA y en red como en el original, con todo el juego editable desde el editor de Godot: mapa, criaturas, hechizos, animaciones y efectos.

> **Aviso legal.** Este proyecto no está afiliado a Interplay, Shiny Entertainment ni a los dueños actuales de Sacrifice. Los modelos, texturas, mapas e interfaz de `game/assets/original/` salen del juego original y pertenecen a sus dueños. El código del port es independiente: [sacengine](https://github.com/tg-2/sacengine) (GPL) se usó solo como referencia de lectura y no se copió código.

![Partida contra la IA en High Noon, con el minimapa](docs/screenshots/match.jpg)

## Qué hay hoy

- **Partida completa contra la IA** en High Noon. Hay 15 magos y 5 dioses (Persephone, Pyro, James, Stratos y Charnel), cada uno con su bioma y su libro de criaturas y hechizos. La IA juega con las mismas reglas que el jugador, sin trampas.
- **Aldeas vivas:** 26 aldeanos, 6 taurocks y 69 edificios. Las almas se recolectan y se sacrifican en el altar.
- **71 criaturas** con esqueleto y animaciones, **53 hechizos**, Manalith, teletransporte y estructuras.
- **Interfaz del original:** libro de hechizos, panel de selección, cursores e iconos.
- **Minimapa** que gira con la cámara y tiene brújula. Con un clic derecho en el minimapa se da una orden.
- **Menú radial de órdenes y 8 formaciones.** Se mantiene el clic derecho, se elige la formación y se suelta: las unidades van ahí en esa formación.
- **Multijugador con autoridad del servidor:**
  - servidor de salas con lobby y un servidor dedicado por partida;
  - «Servidor local» para jugar desde tu PC sin VPS;
  - transporte ENet o WebSocket;
  - reconexión a la partida con el mismo ticket.

| Menú | Elegir mago y dios |
|---|---|
| ![Menú principal](docs/screenshots/menu.jpg) | ![Selección de mago y dios](docs/screenshots/pick.jpg) |

| Menú radial y formaciones | Minimapa |
|---|---|
| ![Menú radial con la formación en cuña resaltada](docs/screenshots/radial.jpg) | ![Minimapa con brújula y cuña de visión](docs/screenshots/minimap.jpg) |

## Clonar y jugar

**Requisitos**
- [Godot 4.7.2](https://godotengine.org/download) (estándar, no hace falta .NET).
- [Git LFS](https://git-lfs.com). Los assets van por LFS (unos 190 MB). **Sin LFS, el juego no carga.**

```bash
git lfs install
git clone https://github.com/Joelnicolass/sacproject.git
```

Si ya clonaste sin LFS, entrá a la carpeta y bajá los assets:

```bash
git lfs pull
```

**Primera vez:** abrí `game/project.godot` con Godot y esperá a que importe; tarda unos minutos. Después, F5 para jugar. Desde la terminal:

```bash
godot --path game --import
```

```bash
godot --path game
```

En el menú: **Cambiar personaje** para elegir mago y dios, y **Jugar solo** o **Contra la IA**.

**Jugar NO necesita el juego original instalado:** los modelos, texturas, mapas e interfaz ya están en `game/assets/original/` (por LFS). El original solo hace falta para las herramientas que reimportan desde él (ver [Herramientas que necesitan el juego original](#herramientas-que-necesitan-el-juego-original)).

### Controles principales

| Acción | Tecla |
|---|---|
| Mover y girar al mago | `W` `A` `S` `D` o las flechas |
| Seleccionar / rectángulo de selección | clic izquierdo / arrastrar |
| Ordenar (mover, atacar, escoltar) | clic derecho |
| Menú radial de órdenes y formaciones | mantener clic derecho o `Tab` |
| Formación directa | `Alt+1` … `Alt+8` |
| Atacar / guardia / retirada | `Ctrl+R` / `Ctrl+A` / `Ctrl+Espacio` |
| Grupos | `Ctrl+1…0` define, `1…0` elige |
| Convocar criaturas y lanzar hechizos | las teclas que muestra el libro en pantalla |
| Zoom | rueda (sobre el minimapa, hace zoom en el minimapa) |
| Mostrar u ocultar el minimapa | `M` |
| Pausa | `Esc` |

### Mirar una partida IA contra IA

```bash
godot --path game res://debug/ai/ai_match.tscn -- --rules=res://debug/rules/ai_duel_seeded.tres --seed=7 --minutes=10 --npcs --follow=1 --autostart
```

`--follow=2` sigue al otro mago, y con otro `--seed` la partida sale distinta.

### Servidor dedicado (VPS)

La guía de export de Linux, puertos, firewall y systemd está en [`game/tools/deploy/README.md`](game/tools/deploy/README.md). Para probar en local, el servidor de salas arranca con:

```bash
godot --headless --path game -- --room-server
```

## Cómo se hizo el port

El port se armó por etapas. Cada cambio grande tiene su RFC en [`game/rfcs/`](game/rfcs/) y su registro en [`game/docs/CHANGELOG-features.md`](game/docs/CHANGELOG-features.md) (el estado actual por área está en [`game/FEATURES.md`](game/FEATURES.md)). Para agregar contenido, mirá [`game/docs/HOWTO.md`](game/docs/HOWTO.md).

1. **Extraer los datos del original.** Los importadores de [`game/tools/`](game/tools/) leen los WAD de una instalación local de Sacrifice (que cada quien tiene que tener; ver [Configurar rutas](#configurar-rutas)):
   - modelos, con su esqueleto y todas sus animaciones, a `.glb`;
   - texturas, terreno, edificios, efectos e interfaz;
   - las estadísticas de criaturas, hechizos, magos y edificios.

   Todo queda en `game/assets/original/` y `game/data/catalog/`. El juego no depende de los WAD ni de ninguna caché.
2. **Entender cómo funciona.** Las reglas y los números (daño, maná, almas, IA, órdenes) se leyeron de sacengine, una reimplementación abierta en D, y se compararon contra el ejecutable original con ingeniería inversa. Del original se copia lo que se nota al jugar: números, hechizos y reglas.
3. **Construir sobre Godot estándar.** El primer port copiaba también la física, la navegación y la animación de sacengine. Después se pasó todo a las herramientas del motor (RFC-035 y RFC-036):
   - el terreno es un `terrain.glb` editable en Blender;
   - aldeas, edificios y plantas son nodos de la escena;
   - el catálogo (criaturas, hechizos, magos) son `.tres` editables en el inspector;
   - la navegación es el navmesh de Godot;
   - la separación entre cuerpos es la evasión de Godot (`NavigationAgent3D`);
   - cada modelo tiene su escena con su `AnimationTree`;
   - las criaturas usan una máquina de estados.
4. **Red.** El servidor tiene la autoridad (`MultiplayerSynchronizer`, `CharacterBody3D`): el cliente manda órdenes y dibuja. Lo genérico (salas, tickets, lanzador de dedicados, transportes) vive en el addon [`mp_kit`](game/addons/mp_kit/), separado de las reglas del juego.
5. **Un estudio de agentes.** El trabajo se hizo con un flujo de agentes de IA:
   - un tech lead planifica cada RFC;
   - un developer implementa;
   - el orquestador corre las pruebas;
   - un playtester juega con ventana y saca capturas.

   Las pruebas automáticas son de tres tipos:
   - **flows de AgentKit**, que hacen clics y capturas;
   - **casos sin ventana**, en `debug/rules_suite`;
   - un **banco de determinismo**: partidas IA contra IA con semilla, cuya huella (un hash de las posiciones) avisa si un cambio alteró el juego sin querer.

   El kit de skills y agentes es [godot-studio-skills](https://github.com/Joelnicolass/godot-studio-skills).

### Estructura

```
game/
  addons/        mp_kit (red y salas), agent_kit (pruebas y determinismo), fsm_kit
  assets/original/  assets extraídos del original (LFS)
  data/          catálogo, presets de calidad, reglas, navmesh, UI (.tres)
  scenes/        el juego: world/, ui/, net/, fx/
  debug/         escenas y casos de prueba
  agent/         flows de AgentKit y el banco de determinismo
  rfcs/          diseño de cada etapa
  tools/         importadores de los WAD y herramientas de horneado
docs/screenshots/
```

### Correr las pruebas

```bash
cd game && bash agent/run_determinism.sh quick
```

```bash
godot --headless --fixed-fps 60 --path game res://debug/suite/rules_suite.tscn
```

## Herramientas que necesitan el juego original

Las rutas son relativas a `game/`.

| Herramienta | ¿Necesita el original? | Qué produce |
|---|---|---|
| Jugar (F5), `godot --path game`, el servidor de salas | **No** | Nada: los assets ya están en `game/assets/original/` (LFS) |
| Pruebas: `agent/run_determinism.sh`, `rules_suite`, `agent/runs/*.sh`, flows de AgentKit | **No** | PASS/FAIL, capturas en `agent/out/` |
| `tools/import/export_stats.py` | **Sí** | `assets/original/data/*.json` (estadísticas de criaturas, hechizos, magos, edificios) |
| `tools/import/export_skeletal.py` | **Sí** | `assets/original/models/*.glb` + `index.json` (esqueleto y animaciones) |
| `tools/import/export_skeletal_reference.py` | **Sí** | OBJ de referencia en `agent/out/skeletal_ref/` (no se versiona) |
| `tools/import/import_textures.py` | **Sí** | `assets/original/textures/*.png` |
| `tools/import/import_props.py` | **Sí** | `assets/original/props/*.glb` (edificios y plantas) |
| `tools/import/import_themes.py` | **Sí** | `assets/original/themes/<dios>/` (suelo, cielo, luz) |
| `tools/import/import_ui.py` | **Sí** | `assets/original/ui/` y `assets/original/fx/` (HUD, iconos, cursores, partículas) |
| `tools/import/import_map.py` (incluye `--list`) | **Sí** | `assets/original/maps/<tag>/` (tiles, luz, entidades, terreno) |
| `tools/audit/check_original_assets.sh` | **Sí** | Paridad de `assets/original/` con el original (`ASSETS PARITY PASS/FAIL`) |
| `tools/import/scaffold_map.py` | No: usa lo que ya dejó `import_map.py` | `sides.tres`, `MapDefinition`, `map.tscn`, entrada del catálogo |
| `tools/import/classify_ground_tiles.py`, `sample_grass_palette.py` | No: usan `assets/original/` | `high_noon_tiles.tres`, paleta de pasto propuesta |
| `tools/bake/*` (navmesh, catálogo, `bake_body_scenes`, `new_creature`, terreno) | No: `bake_body_scenes` usa los `.glb` y `index.json` del repo; `import_terrain.gd` lee el `.bin` que escribe `import_map.py` | Escenas, `.tres` y navmesh |
| Menú **Project > Tools > Sacrifice** | Solo «Listar mapas del original» (lleva «(requiere juego original)» en el menú) | Salida en un diálogo |

Estas herramientas leen los `.wad` y los `.scp` del juego instalado; **el original no viene en el repo** (es el juego comercial). Si falta, imprimen un mensaje en español que explica qué carpeta hace falta y cómo indicarla, y terminan con error. Todas empiezan su encabezado y su `--help` con «Requiere el juego original instalado (SAC_INSTALL)» o con «No necesita el juego original».

### Configurar rutas

**El juego original** (solo para las herramientas de la tabla de arriba). Hace falta la carpeta que contiene los `.wad` (por ejemplo `spells.wad`, `models.wad`, `main.wad`), normalmente llamada `data`, con la carpeta `maps/` (los `.scp`) al lado. Se busca en este orden, sin ninguna ruta por defecto:

1. Variable de entorno `SAC_INSTALL` (la carpeta con los `.wad`) o `SAC_ROOT` (la raíz del juego, la que tiene `data/` y `maps/`). `SAC_MAPS` es opcional si `maps/` está en otro lado.
2. Archivo `game/tools/import/local.cfg` (no se versiona): copiá `local.cfg.example` y completá `SAC_INSTALL=`.
3. Desde el editor de Godot: **Editor > Editor Settings > sacrifice > original_install_path**. El plugin «Sacrifice» la pasa como `SAC_INSTALL` a los procesos que lanza.

Lugares típicos de la instalación: GOG en Windows (`C:\GOG Games\Sacrifice\data`), Steam en Windows (`...\steamapps\common\Sacrifice\data`), y en macOS o Linux la carpeta `drive_c/.../Sacrifice/data` dentro del prefijo de Wine o de la botella de CrossOver. Se valida que la carpeta tenga `spells.wad`, `models.wad` y `main.wad`.

```bash
export SAC_INSTALL="/ruta/a/Sacrifice/data"
cd game && python3 tools/import/import_map.py --list
```

**Godot y Blender** (los scripts de `game/agent/` y `game/tools/`). Todos leen `agent/harness/env.sh`, que calcula la raíz del proyecto desde su propia ubicación y elige:

- `GODOT_BIN`: la variable de entorno si está; si no, `godot` del `PATH`; si no, el de macOS (`/Applications/Godot.app/Contents/MacOS/Godot`).
- `BLENDER_BIN`: la variable de entorno si está; si no, `blender` del `PATH`; si no, el de macOS (`/Applications/Blender.app/Contents/MacOS/Blender`).

```bash
export GODOT_BIN="/ruta/a/Godot_v4.7.2"   # opcional si godot está en el PATH
export BLENDER_BIN="/ruta/a/blender"      # solo para tools/blender/ y la criatura propia desde Blender
```

## En camino

- **Port web**, en la rama `web-port`: cliente en el navegador con WebRTC P2P, señalización en Node y un preset liviano.
- Pasto y mejoras visuales.

---

### Skills de Copilot en VS Code

Este repo también publica skills y slash commands para Copilot desde `.github/skills/`, con copia espejo en `skills/` y `commands/`. Para regenerarlos, corré `./scripts/sync-vscode-prompts.sh` y después **Developer: Reload Window** en VS Code.
