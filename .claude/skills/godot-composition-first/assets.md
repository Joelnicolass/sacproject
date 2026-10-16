# Assets — shaders, 2D y 3D

No inventes arte o FX “de memoria” si hay catálogo o herramienta. El juego (PNG, `.gdshader`, `.glb`) vive en el **proyecto Godot**, no en este framework.

## Shaders

Buscá primero, adaptá, envolvé en un **pass** (packed scene). Un efecto = un archivo `.gdshader`. Knobs en el material (`shader_parameter`), no 80 floats en un autoload.

| Fuente | Uso |
|--------|-----|
| [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) | Preferido: ya está en shading language de Godot. |
| [Shadertoy](https://www.shadertoy.com) | Portar: `mainImage` → `fragment()`, `iTime` → `TIME`, `iResolution` / `fragCoord` → `SCREEN_UV` / `UV`. No pegues GLSL de Shadertoy tal cual. |

Respetá la licencia y la atribución de la página. No copies un FX de otro título (CRT, wrap, plasma) “porque estaba en el ejemplo”.

El pass no conoce puntaje ni sesión. Gameplay tweenea **ese** pass.

## Sprites 2D (Aseprite MCP)

Animación: [godot-animation](../godot-animation/SKILL.md) (12 principios; Tween o `AnimationPlayer` según el clip).

**Preguntá primero.** No uses MCP ni crees sprites hasta que el usuario diga que sí. Pedí **referencias** (imágenes, URLs, paleta, tamaño, ciclos, estilo). Sin referencias y sin OK: placeholder, no arte inventado.

Si dijo que sí: pixel art / spritesheet vía **Aseprite MCP**, no un `ColorRect` eterno ni un PNG en base64.

Repo: [diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp)

1. Usuario OK + referencias.
2. Si las tools MCP **ya están**: usalas. Si **no**: instalá (abajo), sesión nueva, dibujá.
3. Exportá PNG / spritesheet al juego (`res://assets/…`) → `Sprite2D` / `AnimatedSprite2D`. El `.aseprite` puede ir junto al PNG.

Flujo corto: paleta (`generate_color_ramp` o preset) → capas → silueta → `export_frame` a 8× para mirar → iterar → `export_sprite` / `export_spritesheet` al proyecto Godot.

### Instalar el MCP

Requisitos: [Aseprite](https://www.aseprite.org/), Python 3.13+, [uv](https://github.com/astral-sh/uv). `ASEPRITE_PATH` si el binario no está en el PATH.

Cloná el server (una vez, fuera del juego):

```bash
git clone https://github.com/diivi/aseprite-mcp.git
```

Claude Code: `.mcp.json` en la raíz del **juego** (o `claude mcp add`). Cursor: Settings → MCP, o `~/.cursor/mcp.json` / `.cursor/mcp.json` del juego. Mismo contenido:

```json
{
  "mcpServers": {
    "aseprite": {
      "command": "uv",
      "args": ["--directory", "/ABS/PATH/aseprite-mcp", "run", "-m", "aseprite_mcp"],
      "env": {
        "ASEPRITE_PATH": "/ABS/PATH/to/aseprite"
      }
    }
  }
}
```

En macOS el `uv` suele estar en `/opt/homebrew/bin/uv`. Sesión **nueva** después de guardar (en Claude Code, `/mcp` muestra si conectó).

Si el MCP no arranca: no finjas el sprite; avisá qué falta (Aseprite, path, uv) y usá un placeholder `PlaceholderTexture2D` **solo** hasta que el usuario lo habilite.

## Modelos 3D (Blender MCP)

Fuente oficial: [MCP Server — Blender](https://www.blender.org/lab/mcp-server/).

**Preguntá primero** (solo si el juego es **3D** o 2D+3D). No instales el MCP de Blender ni ejecutes código en la escena hasta que el usuario diga que sí. Pedí **referencias** (imágenes, conceptos, escala, poly budget, estilo). Sin OK: `PlaceholderMesh` / caja y seguí con código.

Si dijo que sí:

1. Instalá y configurá el MCP oficial (abajo). Blender tiene que estar **abierto** con el add-on arrancado.
2. Modelá / ajustá en Blender vía MCP. Exportá **glTF 2.0** (`.glb`) a `res://assets/…` del juego.
3. En Godot: `MeshInstance3D` / packed scene. No dejes el `.blend` como único asset de runtime.

El servidor ejecuta Python generado por la IA **sin** sandbox. No lo uses sobre archivos con datos sensibles. Preferí una copia de trabajo.

### Instalar el MCP de Blender

Requisitos (docs oficiales): **Blender 5.1 o más nuevo**, add-on Lab, cliente MCP (Claude Code o Cursor), servidor MCP.

1. Blender → Edit → Preferences → Extensions → Get Extensions. Buscá **MCP** / Blender Lab e instalá el add-on oficial. (Drag & drop del repo Lab: dos veces — primero el repositorio, después el add-on.)
2. En las preferencias del add-on: **Start MCP Server** (suele escuchar `localhost:9876`).
3. En el cliente (Cursor: Settings → MCP; Claude Code: `claude mcp add` o `.mcp.json`). Si el cliente acepta **`.mcpb`**, bajá el bundle de la [página de releases](https://www.blender.org/lab/mcp-server/) y agregalo. Si no: seguí las *setup instructions* de esa misma página (no uses un `uvx blender-mcp` comunitario: es **otro** protocolo).
4. Sesión **nueva**. Verificá que las tools de Blender aparezcan. Si no: Blender abierto + server started + recargar MCP.

Si no arranca: no inventes un mesh; avisá qué falta (versión 5.1, add-on, server, config MCP del cliente).
