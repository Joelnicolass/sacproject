# Plan 071: navegación por zonas (re-horneado local del navmesh)

Tech lead, 2026-10-27. Estado: **aprobado** por el usuario 2026-10-27 (D1–D6 con las recomendaciones, más la unión de lados de NavRegions como obligatoria). Reemplaza RFC-035 P4 («un solo navmesh») y la nota «tile dropped» de `NavRebake`.

## 1. Problema
Cada cambio (Bore, cráter, edificio caído, torre, altar) re-hornea el navmesh del mapa entero en un worker: High Noon ~1,4 s, un mapa sólido de 256² del editor ~12 s. Desde c76a6b0e el swap no bloquea, pero en mapas sólidos las criaturas tardan ~12 s en ver un agujero y el swap cae fuera del tick fijo.

## 2. Criterios
- Un cambio re-hornea solo las zonas cuya caja de horneado (zona + borde) toca.
- Mapa sólido 256²: re-horneado local < `rebake_swap_s` (ideal < 1 s): el swap vuelve al tick fijo.
- Sin costuras: plano sólido = 1 componente de `NavRegions`; un camino que cruza bordes de zona ≤ 1,02 × la recta; `same_region` verdadero a los dos lados de un borde; sin `navmesh_edge_merge_errors`.
- Re-hornear las zonas tocadas da el mismo navmesh que hornear todas (mismo hash).
- Los 10 mapas del original se re-hornean por zonas con componentes grandes iguales a hoy o la diferencia explicada.

## 3. Diseño
- **Una región, un navmesh (D1).** `MapNavRegion` sigue siendo un `NavigationRegion3D`; su `navigation_mesh` es la unión de las piezas. `NavMeshBackend`, `MapRoot.nav_region` y la búsqueda de caminos (`NavigationServer3D.query_path`) no cambian.
- **Grilla fija:** origen (0,0), `zone_m` 160 m (16×16 en 2560 m), `zone_border_m` 8 m, múltiplos de `cell_size`; alto de caja fijo (`floor_m`, `ceiling_m`). Técnica oficial de Godot (demo `navigation_mesh_chunks`): parse una vez, cada zona con `filter_baking_aabb` = zona + borde y `border_size` = borde, vértices redondeados a `cell_size × 0,1`.
- **Fuente mínima (D2):** `nav.res` sigue siendo un solo `NavigationMesh`; las piezas por zona se derivan en el worker (`NavZones.split`).
- **Celda única (D3):** fuera `fit_to` y `max_grid_cells`; todo mapa a `cell_size` 0,5.
- **Tamaños (D4):** 160 m / 8 m; `rebake_swap_s` baja de 3 s a 1 s si la suite mide p95 < 0,5 s.
- **Islas sin falsos cortes (usuario 2026-10-27):** `NavRegions` une dos polígonos cuando sus lados se solapan sobre la misma línea dentro del margen de Godot (`edge_connection_margin`), no solo cuando comparten los dos vértices. Así `same_region` (IA: `creature_brain`, `ai_souls`, `ai_track_upkeep`) nunca ve dos islas donde Godot encuentra camino. `use_edge_connections` queda prendido como red de seguridad.
- **Dueños:** `NavChanges` (qué cambió desde el último horneado; reemplaza `_baked_signature`/`_baked_changed`/`_pending_signature`), `NavRebake` (las piezas vigentes; las nuevas valen en `finish()`), `NavService` (cuándo y en qué tick), `NavBakeSettings` (los números). Un horneado a la vez; los cambios que llegan mientras tanto se juntan en `NavChanges`.
- **Red:** solo la autoridad corre `NavService`; los clientes cargan `nav.res`.

## 4. Árbol
```
scenes/map/nav/nav_zones.gd          [+] grilla, zones_touching(rect), split(navmesh), baked(geometry, zones), stitched()
scenes/map/nav/nav_changes.gd        [+] reset(entries), add_area(Rect2), take(entries) -> Array[Rect2]
scenes/map/nav/nav_rebake.gd         [~] start(root, areas): solo las zonas tocadas; bake_now = todas
scenes/map/nav/nav_service.gd        [~] pasa las áreas de holes_changed/kept a NavChanges; sin firma; no crece
scenes/map/nav/nav_regions.gd        [~] une lados colineales solapados dentro del margen
scenes/map/nav/nav_bake_settings.gd  [~] + zone_m, zone_border_m, floor_m, ceiling_m; - fit_to, max_grid_cells
scenes/map/nav/map_nav_region.gd     [~] aviso si zone_m o el borde no son múltiplos de cell_size
scenes/map/nav/README.md             [+]
data/nav/nav_bake.tres               [~]
tools/bake/bake_nav.gd               [~] hornea con NavZones (varias zonas a la vez) y une
scenes/map/maps/*/nav.res            [~] re-horneados (nico_map_test_creator no se versiona, D6)
debug/suite/nav_zone_cases.gd        [+] costura, islas, local = todas, tiempos, zona no tocada
debug/suite/rules_suite.gd           [~]
debug/nav/zone_probe.gd              [+] sonda descartable de Z0
```

## 5. Cortes
| Corte | Contenido | Cuándo |
|---|---|---|
| Z0 | sonda headless: ms por zona, concurrencia, componentes, camino que cruza bordes, local = todas, zona vacía (D5) | primero |
| Z1 | NavZones + settings + bake_nav + README | después de Z0 |
| Z2 | NavChanges + NavRebake + NavService | en paralelo con Z1 |
| Z3 | nav_zone_cases + rules_suite | en paralelo con Z1 y Z2 |
| Z4 | NavRegions une lados solapados (obligatorio) | en paralelo, ya |
| Z5 | re-hornear los mapas, regrabar la base de determinismo, pasada final | al final |

## 6. Riesgos
Costuras (alto fijo, grillas alineadas, redondeo, Z4); determinismo (si un horneado local pasa `rebake_swap_s` el swap llega tarde, como hoy pero mucho menos probable); hornear todo el mapa en el editor (~256 zonas: varias a la vez); mapas del original (más polígonos por los cortes en los bordes); edificio caído (orden del apagado de la colisión; si falla, su área entra explícita en NavChanges); seguridad entre hilos de hornear varias zonas a la vez (NO VERIFICADO, lo mide Z0).

## 7. Pruebas
Por corte sin Godot: lint, greps, tamaños. Final: suites nav/bore/deform/ai y `nav_zone_cases`, `check_map` en los mapas, determinismo quick (regrabado), y la línea `nav: re-bake … swap` sin «tarde» en un mapa sólido.
