# REVIEW F134 (030e2a): reposo con stance1

**Veredicto: PASS.** Sin bloqueantes. (Revisor de solo lectura: el orquestador guardó este archivo a partir de su informe, 2026-10-16.)

## Criterios
| Criterio | Estado | Evidencia |
|---|---|---|
| C1 | PASS | En la sección HIBRIDA, la mediana va de −0,08 a +0,02 y el mínimo es ≥ −0,30 (Rhinok queda justo en el borde). Phoenix: mínimo −0,03, flota. |
| C2 | Pasa a F135 | Fallan 7 de 10. `info().height` alimenta `MeleeAttack`, así que corregirlo cambia la simulación. La decisión está registrada en el RFC. |
| C3 | PASS (por código) | Las 35 criaturas que cambian tienen todas nivel de libro ≥ 2. En nivel 1, `pose_source == idle`. |
| C4 | Pendiente | Lo cubre el playtest (4 PNG). |
| C5 | Parcial | Solo cambian las 10 filas híbridas de la auditoría. El digest de seed 7 no cambia (`4915c884…`). `RULES SUITE PASS`. Falta correr `f25_flying_summon`. |

## Notas
- **Fidelidad a sacengine:** `state.d:7957-7960` pone `stance1` en cada vuelta, y los gestos idle aparecen 1 de cada 5 veces (fuera de alcance). Ningún reposo nuevo cae en la lista `bad` de `sacobject.d:675-677`.
- **Colaterales:** cambian 35 criaturas, no 3. Son las 10 híbridas más 25 de nivel ≥ 2 que no son híbridas: alab, cara, cbab, craa, craf, crpd, ctug, glsd, guls, llab, lort, lrtf, mtse, mtsl, nugd, nugf, plfd, plff, plfl, raeb, rgos, wlca, wlce, wlcf, ycrp. Todas pasan a `stance1`, lo cual es fiel. El paso de ECi1 a CKst es de Ikarus, no de Gammel: Gammel (`gamm`) no tiene `pose_source` y no cambia. Eso es una brecha anterior, no una regresión.
- **Solo visual:** el tag no se replica. Cada peer lo deriva de los mismos datos.
- **`has_clip`:** es una API razonable y la llama código de producto (`unit_body.gd`).
- **Escenas:** el banco usa `PROCESS_MODE_DISABLED` sobre `%Actors`. El suelo queda en y=0. El estado en vuelo requiere `check_tick`, así que la prueba no se cumple sola.

## No bloqueantes
1. La auditoría sigue en `POSE AUDIT FAIL` (exit 1). Conviene marcar `C2_F135` sin contarlo como falla, para que el rojo no tape regresiones nuevas.
2. `verdict = ["HIBRIDA"]` en la sección 1 tapa `DE_COSTADO` y `SIN_CLIP` del cuadro 0.
3. `has_clip` duplica el chequeo de `_clip_for_role`.
4. `clip_pose_player.gd` quedó fuera del árbol del plan. El cambio es mínimo y está justificado.
5. `rest_hovers` lo lee solo la herramienta.
6. Las voladoras de nivel 1 que aterrizan (tbsh, sohf, sohe, pazb, bobs) quedan fuera de la regla HIBRIDA. Es por diseño, pero no está comentado.
7. Cada `ClipPosePlayer` parsea su propia copia del JSON de 940 KB. Pasaba desde antes.
