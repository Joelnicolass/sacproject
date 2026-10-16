---
name: godot-studio-workflow
description: >-
  Orquesta un juego Godot 4 de la idea a una base simple y escalable:
  entrevista al usuario (Clean vs estándar, tipo de multiplayer, 2D/3D, MCP
  Aseprite/Blender), corre commands de producto (GDD corto opcional, features,
  rules, RFCs), itera con /implement-feature y delega en tech-lead /
  developer / reviewer (tester, playtester y visual opcionales). Usar al
  arrancar un juego, un proyecto Godot, implementar una feature, PRD, RFC, o
  cuando el usuario quiere el workflow / la orquestación del estudio.
---

# Godot studio — orquestador

El **agente principal de este chat** es el orquestador. Habla con el usuario. No descarga el producto entero en un solo subagente.

Cargar: [spec-loop.md](spec-loop.md), [compact-rules.md](compact-rules.md), [file-tree.md](file-tree.md), [godot-layered-architecture](../godot-layered-architecture/SKILL.md), [godot-composition-first](../godot-composition-first/SKILL.md). Memoria entre chats: [godot-studio-memory](../godot-studio-memory/SKILL.md). Red: [godot-mp-kit](../godot-mp-kit/SKILL.md) **solo** si hay multiplayer. Capturas / flows: skill `godot-agent-kit` del módulo [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) (`./install.sh` de este kit la trae). Tests: [godot-testing](../godot-testing/SKILL.md) **solo** si el usuario los pide o RULES los exige. Feel jugoso: [godot-juicy](../godot-juicy/SKILL.md) + `/add-juicy`. FSM: [godot-fsm](../godot-fsm/SKILL.md) + `/add-state-machine`. Plataformas 2D: [godot-platformer-2d](../godot-platformer-2d/SKILL.md) + `/add-platformer-2d`.

Objetivo: un juego Godot 4 con **base chica y clara**. Prioridades: capas limpias, composición, editor/`@export`, componentes reutilizables.

Roles (tool de subagentes — `Agent` en Claude Code, `Task` en Cursor — con `subagent_type` = su `name`):

| Rol | Subagente | Cuándo |
|-----|-----------|--------|
| Tech lead | `studio-tech-lead` | Plan de un RFC / feature **antes** de código; **incluye árbol** |
| Desarrollador | `studio-developer` | Implementar **un** RFC o un cambio acotado |
| Reviewer | `studio-reviewer` | Después de implementar (un pase) |
| Tester | `studio-tester` | **Solo** si el usuario pide tests o RULES.md los exige |
| Playtester | `studio-playtester` (módulo [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)) | Después del review, sobre `res://debug/` o la escena del jugador. No pide un segundo OK |
| Visual | `studio-visual` | **Solo** si el usuario quiere pase UI; exige `VISUAL.md` / refs |

Cada prompt de subagente lleva el bloque de [compact-rules.md](compact-rules.md). Los subagentes **no** ven este chat, **no** le preguntan al usuario y **no** lanzan otros subagentes: si a un rol le falta una decisión (arte, MCP, alcance), la devuelve y el orquestador pregunta.

Si el subagente `studio-playtester` **no existe** (el módulo playtest no está instalado), no lo inventes ni lo simules con otro rol: ofrecé playtest manual (el usuario corre F5 y vos pasás los criterios del slice como checklist) o saltear el paso.

Al lanzar `studio-playtester`: pasale el path `res://debug/…` y la acción del InputMap que quedaron en el `F<n>` o el RFC. El playtester **juega** esa escena; no la construye y no usa `call()` para armarla. Si esa escena no está, tiene que devolver `NEED_SETUP`, no inventar un mundo. Ordenale leer `harness.md` de `godot-agent-kit` **antes** de escribir un `.gd`. Al volver, el diff del playtest solo puede tocar `agent/` (flows, out). Si tocó `src/`, `scenes/` o `debug/`, **FAIL de proceso** — pedí revert.

Un typo, un `@export` o un bug con repro y 1–3 archivos: **este chat**, sin RFC nuevo. Feature nueva: `/implement-feature` (FEATURES crece). RFC solo si el corte es grande o el usuario pide contrato. Alcance que se mueve a mitad de un RFC: `/manage-changes`.

## 1. Arranque (vos preguntás y ejecutás)

Si el usuario quiere un juego / feature nueva, **no esperes** a que tipee el slash: ejecutá el command correspondiente (Claude Code: tool `Skill` con el nombre del command; si no está, leé `../../commands/<nombre>.md` — `~/.claude/commands/` o `~/.cursor/commands/`, o los del proyecto — y seguilo).

**Iterar gana a un PRD con todo definido.** Un slice jugable esta semana vale más que un GDD de 20 páginas. `/create-prd` es opcional y **corto**; no entrevistas el título entero antes de código.

Si el repo ya tiene PRD/RULES, leelos y `/workflow-status` si hace falta; no regeneres artefactos.

Orden para un **juego nuevo**:

1. Arquitectura Clean vs estándar — **preguntar** (skill layered). Sin respuesta: no scaffoldear.
2. Multiplayer — **preguntar** (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está), **antes** de copiar `addons/mp_kit` o de escribir RPCs:
   - **Sin multiplayer** — no instales MpKit. Sin RPCs, sin `MultiplayerSpawner`.
   - **Local / WiFi** (mismo dispositivo o LAN) — `MpKit.host()` listen-server (el host es jugador).
   - **Online** (internet / VPS) — **dedicated server** en el mismo proyecto: `MpKit.host_dedicated()`, clientes `join(ip)`. Desarrollá dedicated + clientes desde el día uno. Steam/WebRTC/matchmaking solo si el producto los pide después. No fingir que un listen detrás de NAT es online.
   Sin respuesta: no copies el addon.
3. 2D / 3D — **preguntar** (o ambos).
   - **2D**: sprites vía Aseprite MCP **solo** si el usuario quiere (referencias). Skill [godot-animation](../godot-animation/SKILL.md) (12 principios; Tween o AnimationPlayer según el clip).
   - **3D**: **preguntá** si quiere el MCP de Blender ([docs oficiales](https://www.blender.org/lab/mcp-server/)). Si sí: instalalo, pedí referencias, exportá `.glb` al juego. Si no: placeholder 3D. Guía: [assets.md](../godot-composition-first/assets.md).
4. Slice vertical: `/implement-feature` (o un RFC-001 si piden contrato). Pilares + loop + una escena. No hace falta FEATURES de todo el juego.
5. Si quieren un GDD escrito: `/create-prd` → `PRD.md` **corto y vivo** (solo el slice + no-goals). No definas sistemas futuros.
6. Si ya hay estilo o refs: `/create-visual-guide` → `VISUAL.md`. Si no, **preguntá** antes de cualquier pase visual.
7. RULES.md cuando el stack ya se eligió (`/generate-rules` o unas viñetas a mano). `godot-mp-kit` solo si hay MP.
8. Features siguientes: otra vez `/implement-feature`. `/generate-rfcs` solo si quieren un backlog de contratos.
9. `/test-strategy` solo si el usuario quiere tests o el PRD los pide
10. `/workflow-status` cuando pida “dónde estamos”

Investigación (API Godot, un patrón, un addon, un shader): subagente de exploración (`Explore` en Claude Code, `explore` en Cursor) o lectura puntual (Godot Shaders, Shadertoy). Sprites 2D: **preguntá** si quiere MCP/arte y pedí referencias. Si es **3D**: **preguntá** e instalá el MCP de Blender solo con OK + referencias. El orquestador resume al usuario; no pegues dumps.

Cambios de alcance a mitad de un RFC grande: `/manage-changes`. Feature nueva chica: `/implement-feature`.

## 2. Tubería de una feature (o de un RFC)

Una feature / un RFC a la vez. Predecesores listos.

Corte chico (un componente, un `@export`, sin escena de prueba que pueda hacer trampa): el plan queda en este chat. No lances tech lead.

Corte con árbol o con `res://debug/`:

```
orquestador
  → studio-tech-lead     plan + árbol + res://debug/   [sin código]
  → el usuario ve el árbol (una sola vez) y da OK
  → studio-developer     producto + res://debug/
  → studio-reviewer      un pase
  → studio-playtester    juega esa escena; no pide otro OK
  → orquestador          clasifica el informe y cierra
```

Varios developers solo si las features no comparten escena. Nunca developer y reviewer a la vez sobre el mismo corte.

### Vuelta de un FAIL

No reabre el tech lead salvo que el corte o la escena de prueba estén mal planteados.

| Informe | Vuelve a |
|---------|----------|
| El criterio no se cumple, o el PNG muestra otra cosa que la pedida (cambió un número, pero lo que se ve no es lo nombrado) | `studio-developer`, una corrección |
| `res://debug/` ya muestra el resultado | `studio-reviewer` (la escena hace trampa) |
| Cache (`CACHE_STALE`) o el CLI no pudo correr | Este chat. Un `--import` y se relanza el playtester |
| Falta `res://debug/` (`NEED_SETUP`) | Este chat completa el plan. No la inventa el playtester |

Cerrar la iteración **deja rastro** siempre (no es opcional): el `F<n>` en `FEATURES.md` con sus criterios, y — si está la skill `godot-studio-memory` — decisión tomada + próximo paso. En un chat nuevo, `/workflow-status` reconstruye desde esos archivos; sin rastro, no reconstruye nada.

El prompt al subagente incluye: ruta del repo, id de feature o RFC, estilo de arquitectura, **tipo de MP**, compact rules, y que lea RULES / VISUAL / FEATURES / el RFC si existe.

No lances developer y reviewer en paralelo sobre el mismo corte. Tech-lead de features independientes sí puede ir en paralelo.

Sin [árbol](file-tree.md) no hay “OK, implementá”.

## 3. Qué no hacer

- Definir el juego entero en un PRD antes de un slice jugable.
- Un `studio-developer` “hacé el juego”.
- Regenerar PRD / FEATURES / RFCs cuando pedís **una** feature (`/implement-feature`).
- Inventar capas Clean si eligieron estándar, o al revés.
- Copiar `addons/mp_kit` si eligieron sin multiplayer.
- Tratar un listen-server detrás de NAT como multiplayer por internet.
- Meter puntaje, copy o netcode de título en `addons/mp_kit`.
- Un segundo OK para playtest: el árbol ya incluía `res://debug/` y la acción. El pase visual sí se pregunta, y sin `VISUAL.md` no hay look.
- Pase visual sin estilo/referencias: no inventar look.
- Instalar MCP (Aseprite, Blender, Engram) o crear arte sin preguntar.
- Feel hardcodeado. Elegí Tween o `AnimationPlayer` por clip, no por costumbre. Feel jugoso: `/add-juicy`, no un `World.gd` de partículas.
- `enum` + `match` de estados en el actor: `/add-state-machine`.
- Platformer sin coyote/buffer: `/add-platformer-2d`, no un `is_on_floor()` pelado.

## 4. Listo cuando (checklist de salida por iteración)

No cierres una iteración “de sensación”. Verificá:

- [ ] El proyecto parsea headless: `godot --headless --path . --quit` sin `SCRIPT ERROR` / `ERROR`.
- [ ] La escena de la feature corre con F5/F6 y la acción del slice se ejerce.
- [ ] El `F<n>` nombra la escena (`res://debug/…` o la del jugador), la acción del InputMap y el observable. El RFC solo si el corte es grande.
- [ ] Cada criterio tiene evidencia del review y, si hubo playtest, del flow en `res://agent/`.
- [ ] `FEATURES.md` actualizado; memoria con decisión + próximo paso si está la skill.

El norte sigue siendo el mismo: el slice se juega, cada feature es escena/componente/`Resource` chico, y un humano puede abrir el inspector y seguir.
