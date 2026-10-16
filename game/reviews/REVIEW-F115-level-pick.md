# REVIEW F115 — Elegir el nivel (RFC-030, corte 030d)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS.** Sin bloqueantes.

- **El nivel no queda pegado entre partidas:** `play_solo`, `play_vs_ai`, `host_lan` y `return_to_boot` lo reasignan.
- **En red decide solo el servidor:** el nivel no viaja por canales del cliente y el spawn es del servidor.
- **Boot:** la fila está junto a `%AiGod` y el valor por defecto sale del `.tres`. No se muta ningún `.tres`.

## Nits
1. Hay un 9 por defecto duplicado en `boot.gd`.
2. El spawner lee el autoload `SacrificeFlow`, con lo que queda acoplado al flujo.
3. El árbol de 030d en el RFC todavía nombra `character_select` (corregido por el orquestador).
4. La fila «Nivel del mago» se ve también en «Solo», que la ignora.
