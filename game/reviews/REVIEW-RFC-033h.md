# REVIEW RFC-033h (F174): refs de prueba, importadores desde WAD, tools

Review corta (Sonnet, 2026-10-17): **CHANGES_REQUESTED**, corregido en una ronda. El revisor era de solo lectura y el orquestador guardó el informe.

1. **Borrados:** `scenes/world/wizard.gd` y `tools/audit_original_assets.gd` ya habían salido en 52e93f7, porque el commit del orquestador arrastró el índice. `wizard_preview.gd` todavía hacía preload de `wizard.gd`, así que el menú quedó roto en `main` hasta este commit. La paridad de assets se perdió; la reemplaza `tools/check_original_assets.sh`.
2. **`run_determinism.sh`:** el veredicto podía dar un PASS falso, con un solo modo o con un `fixed` viejo. Corregido: `fixed` siempre se corre y cada caso necesita al menos 2 modos frescos.
3. **`Terrain.data`:** OK. Todos los caminos reales asignan `data`.
4. **Iconos que chocan en macOS** (`hsba`/`HSba`, `hrba`/`HRba`): defecto real. Corregido con `OriginalAssets.icon_file()`, que escribe cada mayúscula como `_` + minúscula.
5. **`.gitignore`:** OK. La excepción está anclada a `game/agent/fixtures/sacengine/`.
