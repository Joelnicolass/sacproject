# Auditoría: qué falta para que Sacrifice sea un proyecto Godot «normal»

2026-10-28. Medido con scripts sobre `git ls-files` (sin `addons/`, salvo donde se dice). Objetivo: que un dev de Godot que nunca vio el proyecto lo abra, entienda qué es cada cosa y cambie algo sin leer RFCs ni el código del original.

Referencia de «normal»: la [guía de estilo de GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) y la [organización de proyectos](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) de la documentación oficial. Más las prácticas comunes: los recursos se identifican por su archivo, los nodos se referencian con `@export` o `%Unique`, el código va en un solo idioma, hay tests con GUT y un README que explica la arquitectura.

## Resumen

El proyecto ya cumple lo más caro de cumplir. Lo que lo vuelve ilegible es otra cosa: **identidades heredadas del original y el historial del desarrollo metidos en el código**.

| | Estado |
|---|---|
| Tipado estático | **Bien**: 5 392 funciones, todas con tipo de retorno; 8 116 `var`, ninguna sin tipo |
| `class_name` | **Bien**: 775 de 825 scripts |
| Datos en `.tres` editables, composición por nodos, enums con nombre (`AiUse`, `AiPhase`) | **Bien** |
| Archivos y nodos en snake_case / PascalCase | **Casi**: 291 archivos fuera de snake_case (códigos del original, `!`, `@`) |
| Identidad de las cosas por código de 4 letras | **Mal** (§1) |
| Historial de RFCs y citas al original en los comentarios | **Mal** (§2) |
| Scripts sueltos que no aparecen en ninguna escena | **Mal** (§3) |
| Idioma mezclado en el código | **Mal** (§4) |
| Acoplamiento por texto (rutas, grupos, `get_node("…")`, `.call("…")`) | **Regular** (§5) |
| Tests, CI y lint estándar | **Falta** (§6) |
| Documentación | **Sobra y está dispersa** (§7) |

## 1. Tags que no dicen nada

Las cosas del juego se identifican con el código de 4 letras del WAD del original: `ctug` es la Abomination, `brif` el Fireball, `ca_a` el altar de Charnel.

- **En los datos:** 376 campos `tag` y 151 `model`/`model_id` con códigos (456 códigos distintos). Son 188 edificios, 185 entradas del catálogo, gods y modes.
- **En los nombres de archivo**, cuántos de cada carpeta están nombrados por código:

  | Carpeta | Nombrados por código |
  |---|---|
  | `data/catalog/spells` | 53 de 53 (`brif.tres`, `ccas.tres`…) |
  | `data/catalog/abilities` | 57 de 63 (`!nur.tres`, `cen@.tres`, `HRba_2.tres`) |
  | `data/shots` | 33 de 34 |
  | `data/fx` | 32 de 138 |
  | `data/audio/cues` | 22 de 112 |
  | `scenes/bodies/materials` | 515 de 822 (`AArc_001.tres`) |
  | `scenes/structures/buildings` | 12 de 243 |

  Los íconos de `assets/original/ui/icons/` también (`ctug.png`).
- **En el código:** 98 usos de `.tag` en 49 scripts, como clave de diccionarios, para comparar o en `match`. Los más cargados son `spell_command.gd`, `caster.gd`, `game_catalog.gd` y `shot_spawner.gd`.
- **Lo que ve un dev:** abre `data/catalog/spells/` y encuentra 53 archivos con nombres sin sentido. Para saber cuál es la bola de fuego tiene que abrirlos uno por uno.

**Estándar Godot:** un recurso se identifica por su archivo y se referencia arrastrándolo a un `@export`. El nombre del archivo es humano (`fireball.tres`). Si un importador necesita el código del original, va en un campo aparte (`source_tag`, en un grupo «Original» del inspector) que solo leen las herramientas de importación.

**Qué hacer:**
1. Renombrar los archivos a nombres humanos. Ya existe la herramienta, `tools/migrate/rename_resources.py --from-display-name`, que reescribe todas las referencias.
2. Pasar `tag` → `source_tag` en el grupo «Original».
3. Que el código use el recurso como clave, no su texto.
4. Que los 23 literales de código que quedan en `.gd` (`"dkba"`, `"guls"`…) pasen a ser `@export` de recurso.

## 2. Comentarios que cuentan la historia en vez de explicar el código

- **Comentarios con historial:** 571 de 825 scripts tienen comentarios `##` que citan un RFC, un número de feature (`F143`), un corte (`034g`) o el código del original (`Ref: state.d:14912`).
- **Citas:**
  - 1 106 líneas con citas al original, en 533 archivos;
  - 928 citas a RFC o F###, en 321 archivos.
- **Densidad:** 12 225 líneas de comentario en 73 802 líneas, un 17 %. Muchas explican *por qué se decidió en tal RFC* o *qué hacía el original*, no qué hace el código.

**Estándar Godot:** `##` documenta la API (qué hace la clase o la función, qué significan sus parámetros) y se ve en el panel de ayuda del editor. El historial va en git. La equivalencia con el original, si hace falta, va en un solo documento.

**Qué hacer:**
1. Una pasada mecánica que saque los IDs de RFC, F### y cortes.
2. Mover las citas al original a `docs/original-mapping.md`, una tabla de sistema → archivo/línea del original.
3. Dejar solo la frase que explica qué hace el código.

Es la mejora más barata y la que más se nota.

## 3. Scripts sueltos

Son 214 de 825 scripts, un 26 %, que no están en ninguna escena ni recurso:

| Base | Cuántos | Qué son |
|---|---|---|
| `RefCounted` | 182 | Funciones `static` de ayuda (`RagdollPose`, `TicketPlan`, `OnlineTicket`, `GroundRay`…) |
| `Node` / `Node3D` | 25 | Nodos que se crean desde código (`MatchTicketGlue.attach()`, `AiAudit`, `GameData`) o clases base |
| Otros | 7 | `Resource`, `FsmState`… |

Por carpeta: ai 38 · map 33 · units 31 · spells 26 · look 25 · audio 10 · core 10.

**Por qué molesta:** la lógica que importa no se ve en el árbol de escena. Un dev abre `unit.tscn`, ve los nodos y no sabe que la mitad del comportamiento vive en helpers estáticos que llaman otros scripts.

**Estándar Godot:** el comportamiento vive en nodos de una escena, con sus valores en el inspector. Los helpers estáticos son pocos y genéricos (matemática, formato).

**Qué hacer** (triage por caso, no en bloque):
- **Helper que usa un solo dueño:** pasa a ser una función privada de ese dueño. Probablemente es la mayoría.
- **Comportamiento con estado o valores ajustables:** pasa a ser un nodo hijo en la escena, con `@export`.
- **Nodo creado desde código:** pasa a ser un nodo en la `.tscn`, siguiendo la regla «todo en el editor».
- **Lo genérico de verdad:** queda en `scenes/core/util/`, con un README.

## 4. Idioma mezclado

- Los identificadores y los comentarios están en inglés.
- 337 de los 512 textos de `print`, `push_error`, `push_warning` y avisos del inspector están en español («sacrificio: el portador de slot 1 llegó al altar»).
- Los textos para el jugador ya pasan por `tr()` y `strings.csv`, y eso está bien.

**Estándar:** el código, los logs y los avisos de desarrollador van en un solo idioma, en general inglés. Lo que ve el jugador pasa por traducción. **Decisión tuya:** ¿logs y avisos en inglés? El jugador sigue viendo español.

## 5. Acoplamiento por texto

| Patrón | Cuántos | Estándar |
|---|---|---|
| `load("res://…")` / `preload` en código | 157 (126 como `const`) | `@export var x: PackedScene` / `Resource`, arrastrado en el inspector |
| `get_node("Nombre")` a otro nodo | 176 | `@export var x: Tipo` o `%Unico` |
| Grupos por texto (`"wizard"`, `"unit"`, `"corpse"`…) | 144 llamadas, 22 nombres | Una clase `Groups` con constantes, o señales de registro |
| `.call("metodo")` / `has_method` | 36 / 31 | Tipo explícito (`if x is Health`) o señal |
| `print(` frente a `DebugLog.on` | 187 / 120 | Un solo camino de log |

Ninguno de estos rompe nada, pero cada uno obliga a buscar texto para entender quién usa qué.

## 6. Tests, CI y lint

- **Tests:** no hay ninguno versionado; el banco se borró el 2026-10-27. Un proyecto normal tiene GUT con tests de reglas (daño, maná, almas, rituales), que corren headless.
- **CI:** no hay un workflow que importe el proyecto y corra los tests en cada PR.
- **Lint:** `tools/lint/conventions.sh` tiene 25 reglas propias (C1–C25) con baselines. Lo estándar es `gdtoolkit` (`gdformat` + `gdlint`); de las propias conviene conservar 3 o 4, las que el estándar no cubre.

**Qué hacer:**
1. Agregar GUT (`addons/gut`) con unos 10 tests de reglas puras.
2. Agregar una GitHub Action que importe, corra gdlint y corra GUT.
3. Sumar `gdformat` y dejar solo las reglas propias que valgan.

## 7. Documentación

- Hay 316 archivos `.md` con 39 257 líneas:
  - PRD, RULES, CONVENTIONS, FEATURES y VISUAL;
  - 40 RFCs y 53 planes;
  - `docs/CHANGELOG-features.md` de más de 3 000 líneas;
  - unos 63 READMEs de carpeta.
- Un dev nuevo no sabe por dónde empezar, y gran parte describe decisiones de proceso, no cómo funciona el juego hoy.

**Estándar:**

| Archivo | Contenido |
|---|---|
| `README.md` | Qué es y cómo se corre |
| `CONTRIBUTING.md` | Convenciones y cómo se prueba |
| `docs/architecture.md` | Una página: escenas principales, autoloads, flujo de una partida, red |
| `rfcs/` | Pasa a `docs/archive/` |

Los READMEs de carpeta quedan solo donde dicen algo que el código no dice.

## 8. Menores

- **Autoloads:** `AgentKit`, que es una herramienta de agentes, es un autoload del producto, y `MpLobby` está cargado aunque el servidor de salas está apagado. Lo normal es que las herramientas de desarrollo no carguen en el juego exportado.
- **Escenas grandes:** `unit.tscn` tiene 126 nodos y `match.tscn` 74. No es un error, pero `unit.tscn` pide subescenas por sistema (combate, visión, cuerpo, audio).
- **Scripts grandes:** 3 de más de 500 líneas, 11 de más de 300 y 84 de más de 150. El peor es `tools/bake/new_creature.gd`, con 895. Está aceptable comparado con el 23-10, cuando había 5 de más de 500.

## Plan propuesto (cortes chicos, cada uno con su árbol antes)

| Fase | Qué | Riesgo | Tamaño |
|---|---|---|---|
| **A** | Comentarios: sacar RFC/F/cortes, mover citas al original a `docs/original-mapping.md` (§2) | Nulo (solo comentarios) | Grande pero mecánico |
| **B** | Nombres humanos: renombrar archivos con códigos, `tag` → `source_tag` (§1) | Medio (referencias): la herramienta existe | Medio |
| **C** | Docs: README + CONTRIBUTING + `architecture.md`, archivar RFCs (§7) | Nulo | Chico |
| **D** | Scripts sueltos: triage de los 214 (§3) | Medio | Grande, por carpeta |
| **E** | Acoplamiento por texto → `@export`, `%Unico`, `Groups` (§5) | Medio | Medio, por carpeta |
| **F** | GUT, CI y gdtoolkit (§6) | Bajo | Chico |
| **G** | Idioma de logs (§4), si decidís inglés | Bajo | Mecánico |

Orden recomendado: **A → C → B → F → D → E → G**. A y C cambian lo que lee un dev sin tocar comportamiento. B es lo que más ayuda en el editor. F da la red de seguridad para D y E, que son las que tocan comportamiento.
