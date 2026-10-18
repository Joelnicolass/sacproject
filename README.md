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
godot --path game res://debug/ai_match.tscn -- --rules=res://debug/rules/ai_duel_seeded.tres --seed=7 --minutes=10 --npcs --follow=1 --autostart
```

`--follow=2` sigue al otro mago, y con otro `--seed` la partida sale distinta.

### Servidor dedicado (VPS)

La guía de export de Linux, puertos, firewall y systemd está en [`game/tools/deploy/README.md`](game/tools/deploy/README.md). Para probar en local, el servidor de salas arranca con:

```bash
godot --headless --path game -- --room-server
```

## Cómo se hizo el port

El port se armó por etapas. Cada cambio grande tiene su RFC en [`game/rfcs/`](game/rfcs/) y su registro en [`game/FEATURES.md`](game/FEATURES.md).

1. **Extraer los datos del original.** Los importadores de [`game/tools/`](game/tools/) leen los WAD de una instalación local de Sacrifice:
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
godot --headless --fixed-fps 60 --path game res://debug/rules_suite.tscn
```

## En camino

- **Port web**, en la rama `web-port`: cliente en el navegador con WebRTC P2P, señalización en Node y un preset liviano.
- Pasto y mejoras visuales.

---

### Skills de Copilot en VS Code

Este repo también publica skills y slash commands para Copilot desde `.github/skills/`, con copia espejo en `skills/` y `commands/`. Para regenerarlos, corré `./scripts/sync-vscode-prompts.sh` y después **Developer: Reload Window** en VS Code.
