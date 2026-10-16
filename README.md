# Sacproject — Copilot slash commands en VS Code

Este repo publica skills y slash commands para Copilot desde **`.github/skills/`**. También mantiene una copia espejo en **`skills/`** y **`commands/`** para compatibilidad con el flujo original de `godot-studio-skills`.

## Regenerar skills/prompts

```bash
./scripts/sync-vscode-prompts.sh
```

El script sincroniza:

- `skills/` (skills base del repo upstream)
- `commands/` (comandos markdown del repo upstream)
- `.github/skills/` (skills base + command-skills invocables con `/`)
- `.github/prompts/` (compatibilidad de prompts GitHub)
- `.vscode/prompts/` (compatibilidad con VS Code)

## Uso en VS Code

Los slash commands de este proyecto vienen de **`.github/skills/`**. Si recién clonaste o cambiaste el contenido de `skills/` o `commands/`, corré el script y luego recarga la ventana:

1. Ejecutá `./scripts/sync-vscode-prompts.sh`
2. En VS Code, hacé **Developer: Reload Window**
3. En el chat de Copilot, probá comandos como `/add-juicy`, `/add-platformer-2d` o `/workflow-status`

Si no aparecen, revisá que la carpeta `.github/skills/` exista y que `settings.json` del workspace permita el uso de Copilot Chat con habilidades.
