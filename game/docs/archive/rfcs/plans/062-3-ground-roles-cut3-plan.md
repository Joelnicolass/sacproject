# Plan 062-3: suelo por roles en James, Stratos, Pyro y Charnel, y borrado del suelo viejo

Tech lead, 2026-10-26. Estado: **aprobado** 2026-10-26 («ok a todo con tus recomendaciones»).

## 0. Objetivo
- Los 5 `data/look/<dios>.tres` llevan un `GodGround` con 4 `GroundRole` completos; `LookProfile.ground_classic` deja de existir.
- `grep -rE "sacrifice_ground|ground_pbr|GroundSet|GroundLayer|NativeGround|TileLayerMap|zone_splat|ground_common|ground_classic|land_remap" game/` da 0 fuera de `docs/archive/rfcs/`, `docs/archive/reviews/` y `docs/CHANGELOG`. Queda solo `ground.gdshader`.
- El pasto lee `Terrain.ground_roles` (no `TileLayerMap`).
- Un mapa nuevo desde `_template` tiene suelo en los 5 dioses, sin `tiles.png` ni ids del original.
- Lint: C13 2 → 1 (queda `original_assets.gd` para 055z), C7 −2, ningún conteo sube.

## 1. Hoy (archivo:línea)
- `scenes/look/ground/terrain_layer.gd:26-38` (clásico y copia de NativeGround), `:77-79` (`set_classic_material`), `:88,:94` (`terrain.call("set_ground_override")`, C7).
- `scenes/map/terrain/terrain_ground_material.gd:8` `DEFAULT_GROUND` = `ground_classic.tres` de James (C13).
- `scenes/map/terrain/terrain_mesh.gd:54-67`: classic/override.
- `scenes/map/terrain/terrain.tscn:10,20`: `Mesh.material_override` = clásico de James.
- `scenes/look/look_profile.gd:33` `ground_classic`; `look_rig.gd:38-42` `tile_map`, `native_ground`; `map_definition.gd:30-31` `native_ground`.
- `scenes/look/ground/ground_material.gd:89-101` `splat_texture` (workaround para este corte).
- Pasto: `grass_field.gd` (690 líneas) `:177,:268-269,:244-253,:388`; `grass_bake.gdshader:16,43,46` (`zone_splat`); `grass_type.gd:35-52,112` (`*_by_layer`).
- Datos: `data/look/*.tres:6` → `themes/<dios>/ground_classic.tres`; solo Persephone tiene `GodGround`. `tile_map = high_noon_tiles.tres` en los 9 `map.tscn`; `native_ground` en tutorial_valley y alpine_meadow.
- Minimapa: `scenes/ui/minimap/minimap_terrain_bake.tscn:4` siempre con el clásico de James.
- Hecho (062 cortes 1, 2, 4): `ground_roles.png` en los 9 mapas y `_template`; `Terrain.ground_roles`/`light_map`; hojas de Persephone; `tools/import/ground_roles_table.json` (5 dioses verificados 2026-10-25); `bake_role_sheets.py --god=`, `measure_ground.py --atlas/--roles`, `measure_seams.py`.

## 2. Árbol ([+] nuevo, [~] cambia, [-] se borra)
```
scenes/look/ground/
  [~] terrain_layer.gd          un camino: GroundMaterial.build(profile.ground, ...) -> terrain.mesh.set_ground(mat); llamadas tipadas (C7 -2)
  [~] ground_material.gd        fuera splat_texture
  [~] grass_paint.gdshaderinc   solo comentario
  [-] sacrifice_ground.gdshader, ground_pbr.gdshader, ground_common.gdshaderinc, zone_splat.gdshaderinc
  [-] ground_set.gd, ground_layer.gd, native_ground.gd, tile_layer_map.gd (+ .uid)
scenes/map/terrain/
  [~] terrain_ground_material.gd  sin DEFAULT_GROUND ni classic; guarda PRE/POST_SAVE (C13 -1)
  [~] terrain_mesh.gd           set_ground(material) / clear_ground()
  [~] terrain.tscn              material neutro embebido («sin look»)
  [~] README.md
scenes/look/
  [~] look_profile.gd           fuera ground_classic
  [~] look_rig.gd               fuera tile_map y native_ground
  [~] README.md
  [~] grass/grass_field.gd      splat = Terrain.of(self).ground_roles; fuera rama classic (balance de líneas <= 0)
  [~] grass/grass_bake.gdshader lee ground_roles (RGBA open/earth/rock/path)
  [~] grass/grass_type.gd       *_by_layer -> *_by_role (open, earth, rock, path)
  [~] grass/grass_mask.gd, grass/grass.gdshader   comentarios
scenes/map/map_definition.gd    [~] fuera native_ground
scenes/map/maps/*/map.tscn x9   [~] fuera tile_map (y native_ground)
scenes/map/maps/{tutorial_valley,alpine_meadow}/<tag>.tres  [~] fuera native_ground
scenes/map/maps/_template/      [+] light.png (gris plano, mediana medida de los 9); [~] map.tscn light_map
addons/terrain_tools/new_map/new_map_files.gd   [~] copia y asigna light.png
scenes/ui/minimap/minimap_terrain_bake.{gd,tscn}  [~] @export look: LookProfile (james.tres, igual que hoy)
data/look/{james,pyro,stratos,charnel}.tres  [~] GodGround embebido (light_gain 1,10 James, 0,55 el resto)
data/look/*.tres x5             [~] fuera ground_classic
data/look/ground/               [-] carpeta entera
assets/original/themes/{james,pyro,stratos,charnel}/roles/  [+] hojas de rol (bake_role_sheets.py, necesita el original)
assets/original/themes/<dios>/  [-] atlas.png, detail*.png, ground_classic.tres (después de medir)
assets/original/maps/{tutorial_valley,alpine_meadow}/  [-] ground_native.tres, atlas_native.png, tiles_native.png
tools/import/                   [~] land_themes.py, import_themes.py, scaffold_map.py; [-] classify_ground_tiles.py
debug/ y agent/fixtures         [~] lo mínimo para que compilen (grass_lab, scar_cases, grass_bench)
```
Nodos: sin nodos nuevos. `Terrain/Mesh` con material neutro; `Look` sin sockets `tile_map`/`native_ground`; `MinimapTerrainBake` gana `look`. `Look/Layers/Ground` sigue siendo el único escritor del material del suelo.

## 3. Roles de los 4 dioses
Los `ground_roles.png` de los mapas ya existen. Las hojas por dios se generan una vez con `SAC_INSTALL=... python3 -I tools/import/bake_role_sheets.py --god=<dios>` (necesita el original; el script avisa) y se versionan. Pyro: earth = grupos 1+2. Charnel: open = 0, 3, 4, 5.

## 4. Criterio medible
1. Sin ventana, antes de borrar: `measure_ground.py` atlas (hoy) contra roles (después), 4 dioses × 9 mapas: ΔS ≤ 0,03, ΔV ≤ 0,03, Δtono ≤ 4°. Si falla, `GroundRole.tint`.
2. Cámara fija en `debug/look/ground_roles_lab.tscn` (High Noon) por dios: mismos umbrales en la caja del suelo.
3. `measure_seams.py` sobre `match_shots --views=ground`: ratio < 1,2, laplaciano ≥ 40.
4. Mapa nuevo desde `_template`, 5 dioses: shader `ground.gdshader` con 4 `role_albedo` (caso headless).
5. Greps del §0 en 0; C13 = 1, C7 = 46.

## 5. Riesgos
Transiciones pasan a mezcla del shader (vigila 4.3). Fuera de High Noon cada mapa usa su luz (cambio buscado, plan 062 §4). Mapa sin light map → light.png plano del template. `grass_field.gd` debe restar líneas. Minimapa sigue con James. Borrar atlas antes de medir rompe 4.1 (3d va último).

## 6. Sub-cortes
| Corte | Qué | Original | Integra |
|---|---|---|---|
| 3a | hojas de rol de los 4 dioses, medición 4.1, luz plana del template | sí | 1º |
| 3b | GodGround en los 4 `.tres` | no | 2º |
| 3c | código y escenas; borra .gd/.gdshader viejos y `data/look/ground/` | no | 3º |
| 3d | herramientas y assets viejos | no | 4º |
| 3e (recomendado) | fuera `tiles` (`Terrain.tiles`, `GroundTiles.ids`, `COLOR.r`, `MapDefinition.tiles`) | no | 5º |

Sin choque de archivos con 055i-b (no toca `match_biome`, `biome_rules`, `side_relations`, `match_world`, `nav_service`, `spellbook`, `data/buildings`). `tools/lint/baseline.txt` se regenera al integrar el segundo.

## 7. 067 P5
No se suma: el criterio de este corte es «se ve igual». P5 va justo después (slots `normal`/`orm` vacíos en los 5 `GodGround`).

## Preguntas
1. Minimapa siempre con James: **sí**.
2. Borrar `assets/cc0/ground/`: **sí**.
3. Incluir 3e: **sí**.
