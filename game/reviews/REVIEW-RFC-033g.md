# REVIEW RFC-033g (F173): datos de juego a assets/original/data

Veredicto: **APPROVE**, sin bloqueantes (review corta, Sonnet, 2026-10-17; el revisor era de solo lectura y el orquestador guardó el informe).

1. **Simulación sin `cache/`: PASS.** Lo que sigue leyendo `cache/` es cliente (`body_catalog.gd:14,17`, `wizard_preview.gd:5`, `wizard.gd:7`), clips con guarda `file_exists` (`structure_body.gd:8`, `clip_pose_player.gd:29`), checks de debug con `cache/tick_*_ref.txt` (fuera de ai_match y high_noon) y tools (`bake_bodies`, `bake_clips`, `audit_body_pose` clips, `agent/tools/f127`/`f129` terreno). Todo es de 033h/033i o RFC-023.
2. **`export_stats.py --out`: PASS.** Con `--out`, `ASSETS_ONLY` salta f36/f37, modelos y catálogo (`export_stats.py:880-883`); sin `--out` el flujo queda igual.
3. **Un dueño: PASS.** `GameData`, `MapBuilding` y `body_gallery` usan `OriginalAssets.DATA_DIR`. Nit corregido por el orquestador: `tools/audit_body_pose.gd` ya no hardcodea la ruta. Las rutas relativas de los `agent/tools/*.py` son aceptables.
4. **Para 033h/i:** `audit_body_pose.gd:16` y los demás lectores de `anim_mesh_clips_f37.json` se migran junto con ese archivo.
