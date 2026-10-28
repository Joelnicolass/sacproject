[English](README.md) | **Español**

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
- **Sonido del original:** efectos 3D, voces de criaturas, magos y consejero, música por dios (calma, batalla, sacrificio, victoria) y ambiente, con volumen por bus en Opciones → Sonido. Los sonidos propios van en `game/assets/custom/sounds/` (ver `game/docs/HOWTO.md`).
- **Menú radial de órdenes y 8 formaciones.** Se mantiene el clic derecho, se elige la formación y se suelta: las unidades van ahí en esa formación.
- **Multijugador con autoridad del servidor:**
  - «Salas online»: un jugador hospeda la sala desde su PC y los amigos entran con el código, a través de un relay;
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

**Jugar NO necesita el juego original instalado:** los modelos, texturas, mapas e interfaz ya están en `game/assets/original/` (por LFS). El original solo hace falta para las herramientas que reimportan desde él (ver [Herramientas que necesitan el juego original](game/docs/HOWTO.md#herramientas-que-necesitan-el-juego-original)).

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

## Para desarrolladores

| Leer | Para |
|---|---|
| [`game/docs/architecture.md`](game/docs/architecture.md) | Por dónde empezar: las escenas principales, los autoloads, la vida de una partida, la red (en inglés) |
| [`game/CONTRIBUTING.md`](game/CONTRIBUTING.md) | Cómo se escribe el código y los comandos de formato, lint y tests (§9, en inglés) |
| [`game/docs/HOWTO.md`](game/docs/HOWTO.md) | Recetas: una criatura, un hechizo, un mapa, sonidos propios, las herramientas que necesitan el juego original y cómo apuntarlas |
| [`game/docs/servidor_local.md`](game/docs/servidor_local.md) | Hospedar una partida en «Servidor local» |
| [`game/docs/archive/`](game/docs/archive/README.md) | Registros históricos de diseño; no describen el código actual |

```
game/
  scenes/   el juego, una carpeta por sistema (units, spells, wizards, match, ui, net…)
  data/     recursos .tres que se editan en el inspector (catálogo, dioses, IA, efectos, reglas)
  assets/   arte y sonido; assets/original/ sale del juego original (LFS)
  addons/   mp_kit (red), fsm_kit (máquinas de estados), agent_kit (capturas), gut (tests), plugins del editor
  tools/    importadores, horneadores, auditorías y lint; el juego nunca los carga
  test/     tests unitarios GUT
```

El port toma las reglas y los números del original de [sacengine](https://github.com/tg-2/sacengine) y del ejecutable original, y arma todo lo demás sobre Godot estándar: escenas y nodos, recursos `.tres`, navmesh, `AnimationTree`, máquinas de estados y red con autoridad del servidor. Se hizo con un estudio de agentes de IA; las skills y los agentes están en [godot-studio-skills](https://github.com/Joelnicolass/godot-studio-skills). Las copias para Copilot viven en `.github/skills/`, `skills/` y `commands/` (se regeneran con `./scripts/sync-vscode-prompts.sh`).

**Lo que viene:** el port web en la rama `web-port` (cliente de navegador con WebRTC), pasto y mejoras visuales.
