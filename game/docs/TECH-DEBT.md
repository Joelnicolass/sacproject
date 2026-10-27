# Deuda técnica conocida

Lo que se sabe que está mal o fuera de lugar y todavía no tiene corte. Cada entrada dice qué pasa, qué se sospecha y qué haría falta para cerrarla.

## Nav: «2 edge errors» en el servidor dedicado de Linux

- Qué pasa: el dedicado de Linux (x86) avisa «2 edge errors» al sincronizar el navmesh del mapa.
- Hipótesis (NO VERIFICADA): el navmesh unido de `NavZones` trae vértices duplicados o casi iguales en las costuras entre zonas, y con el redondeo de x86 el rasterizador del mapa ve dos aristas en la misma celda.
- Arreglo candidato: soldar los vértices de la unión, cuantizados a `cell_size` (`data/nav/nav_bake.tres`), en la pieza que une las zonas (`NavZones` / `NavService`).
- Cómo se mide: un chequeo que cuente aristas compartidas por más de dos polígonos y vértices a menos de `cell_size / 2` en el `nav.res` de cada mapa; después, un dedicado de Linux sin el aviso.
- Costo: hay que rehornear los `nav.res` de todos los mapas (`tools/bake/bake_nav.tscn`).

## IA: `AiAudit` vive en `scenes/ai/`

- Qué pasa: `scenes/ai/ai_audit.gd` (más de 300 líneas, C1b) es el digest del banco de determinismo y está cableado en el producto (`ai_side`, `ai_command_port`, `ai_cast_out`…). Varios de sus métodos solo los usan los chequeos.
- Por qué se queda por ahora: sacarlo cambia cómo se calcula el digest; no es una limpieza.
- Qué haría falta: un plan aparte que lo convierta en un observador inyectado (un nodo que el banco agrega y que escucha señales de la IA), de modo que el producto no lo conozca.
