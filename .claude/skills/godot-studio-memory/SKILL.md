---
name: godot-studio-memory
description: >-
  Notas que sobreviven entre sesiones (Claude Code o Cursor) para un proyecto Godot de
  estudio: decisiones, bugfixes, gotchas, preferencias del usuario, próximo
  paso. Usa Engram MCP si esas tools existen; si no, .studio/MEMORY.md junto
  a project.godot. Usar al iniciar sesión, al recordar trabajo previo, tras
  una decisión importante o antes de cerrar una sesión.
---

# Memoria entre chats

PRD/RFC son la verdad de producto. Esto es el **cuaderno del estudio**: por qué se eligió X, un bug que no hay que reabrir, “la próxima vez empezá por acá”.

No instales nada. Si en este chat hay tools `mem_search` / `mem_save` / `mem_context` / `mem_session_summary` (**Engram**), usalas. Si no, `{carpeta_con_project.godot}/.studio/MEMORY.md`.

No guardes secretos. No dumps de diffs ni de tool calls.

## Cuándo

| Momento | Acción |
|---------|--------|
| Arranque, o “acordate / qué hicimos” | Leer contexto (MCP: `mem_context` luego `mem_search`; si no, MEMORY.md) |
| Antes de re-decidir un patrón | Buscar; no contradigas una decisión ya escrita sin decirlo |
| Bugfix, decisión, gotcha, preferencia del usuario | Anotar **ya** |
| Antes de “listo” si hubo trabajo de producto | Un párrafo: qué se hizo, qué sigue, archivos clave |

Formato de una nota (MCP `mem_save` o un heading en el archivo):

```text
**What**: una frase buscable
**Why**: pedido / bug / feel
**Where**: path
**Learned**: gotcha (si hay)
```

En el archivo, decisiones que evolucionan van bajo el mismo heading (`### auction/must-open-bid`). Sesiones: append al final (`## 2026-09-15`).

Si una nota cambia el producto, actualizá también PRD / RULES / VISUAL / RFC.

## Engram (opcional)

Binario + MCP, no parte de este repo. Solo si el usuario quiere: `brew install gentleman-programming/tap/engram` y en el juego `.mcp.json` (Claude Code; o `claude mcp add engram -- engram mcp`) o `.cursor/mcp.json` (Cursor), mismo contenido:

```json
{ "mcpServers": { "engram": { "command": "engram", "args": ["mcp"] } } }
```

Con eso alcanza. No hace falta TUI, git-sync ni el resto del ecosistema.
