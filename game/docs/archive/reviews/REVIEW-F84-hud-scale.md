# REVIEW F84 — perilla de tamaño del HUD

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador (rol de solo lectura). No corrió Godot (había procesos ajenos); juzgó por código y capturas.

**Veredicto: PASS, con un NEEDS WORK no bloqueante en composición.** Sin bloqueantes. Falta el playtest con ventana.

## Criterios
- Una sola perilla: los cuatro (`spell_book.gd:30`, `selection_roster.gd:33`, `command_cue.gd:32`, `cursor_skin.gd:20`) exportan `hud_scale` con preload de `data/ui/hud_scale.tres` y usan `hud_scale.factor(alto)`; ningún `.tscn` lo sobrescribe. PASS.
- Por defecto el tamaño del original (0,8): en los side-by-side de 720 y 1080 el panel a 0,8 cae entre las mismas guías que el original; 1,0 se pasa. PASS.
- Rango 0,6–1,4 con `clampf` (`hud_scale.gd:27-29, :39, :45`). PASS.
- Prioridad CLI → settings.cfg → default (`hud_scale.gd:62-69`); la CLI no se guarda. PASS.
- Sin texto indicador nuevo. PASS.
- Nada del original en git (side-by-side ignorados, `visual/refs/original/` ignorado). PASS con salvedad N4.

## 1. Composición — NEEDS WORK no bloqueante
`_scale` runtime dentro del `.tres` compartido funciona (preload + caché; no se serializa; el editor lo ignora con `is_editor_hint`), pero es un singleton global mutable escondido en un Resource. Riesgos: divergencia silenciosa si alguien asigna un `HudScale` embebido/duplicado/local_to_scene o carga con `CACHE_MODE_IGNORE`; fuga entre tests del mismo proceso; cambios de `default_scale` en caliente sin efecto tras la primera lectura. Recomendación: cuando llegue el menú de opciones o un segundo setting, mover valor y persistencia a un autoload `Settings` con `hud_scale_changed`; el `.tres` queda como configuración pura. Mitigación barata ya: warning en `_get_configuration_warnings` de los cuatro si `hud_scale.resource_path != "res://data/ui/hud_scale.tres"`.

## 2. Alineación — PASS
Libro y panel escalan el Control entero con pivote; las celdas quedan sobre los huecos. Icono armado en `at + (-px/2, px·4/32)` (`command_cue.gd:145`), hot spot del cursor `(side/2, 0)` (`cursor_skin.gd:93`): consistente. Cursor limitado a 8–256 px (a 1,4 y 2160 px de alto ~202).
- **N1:** `cursor_skin.gd:77` redondea `px` y `command_cue.gd:142` no, ni limita a 256 el icono y el espejo (desfase de 0,4 px a 720/0,8; sobre ~2740 px de alto a 1,4 el icono crece sin tope). Usar una sola función, p.ej. `HudScale.px(units, height)`.

## 3. settings.cfg — PASS con nits
Ausente → default; fuera de rango → clamp; corrupto → error de parseo y default, sin crash; headless/dedicado sin errores (`CursorSkin` sale con `local_slot() <= 0`).
- **N2 (`hud_scale.gd:68`):** no valida tipo ni finitud: `scale = nan` deja el HUD en NaN; `scale = [1]` da error. Validar `typeof in [INT, FLOAT] and is_finite`, también en la CLI (`:64`).
- **N3 (`hud_scale.gd:50-53`):** `set_scale` no revisa el resultado de `config.save`; si el load previo falló por corrupción, el save descarta el resto del archivo. Loguear el error. `set_scale` no tiene caller ni flow que lo ejercite.

## 4. Texto indicador — PASS. 5. Original en git — PASS
- **N4:** otras capturas de `agent/out/f84/`, `agent/out/f79_*`, `agent/out/f80_*` renderizan arte del original extraído a `cache/look` y no están ignoradas; un `git add -A` las sube. Decisión del orquestador.

## Pendiente para cerrar
1. Playtest con ventana: `--hud-scale=0.6` y `1.4` con el cursor real, y `set_scale` en caliente (que `changed` reacomode los cuatro sin recargar).
2. Pase visual (studio-visual), opcional.
