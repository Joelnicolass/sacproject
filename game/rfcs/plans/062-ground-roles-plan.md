# 062 — Suelo por dios con roles, PBR completo y variación de flora (plan, pendiente de aprobación)

## Plan del tech lead: rediseño del suelo por dios, PBR completo y variación de la flora

**La propuesta del orquestador se sostiene, con 5 cambios:**
1. Los roles son 4, no 5 (abierto, tierra, roca, camino). El borde de vacío no es un rol: ya lo dibuja la textura `edge` del dios.
2. El mapa de roles se genera desde la tierra **propia** de cada mapa. Hoy se genera desde los ids traducidos a James, y esa doble traducción es la que pone colores raros.
3. El "clásico" no es una opción aparte del material: son las baldosas del dios, puestas como texturas de cada rol. Así queda un solo camino.
4. El light map es del mapa, no del dios.
5. Las texturas se arman como `Texture2DArray` para no pasar de 16 samplers (lo necesita el port web).

### Lo que verifiqué en el código y los datos
- **Light map equivocado.** Los 5 `assets/original/themes/<dios>/ground_classic.tres` apuntan a `assets/original/maps/high_noon/light.png`. Todos los mapas salvo el tutorial (que usa `NativeGround`) se ven con la luz horneada de High Noon.
- **Baldosas sin rol (celdas que caen en un hueco del atlas).** Medido con los `tiles.png` contra el atlas de cada dios:

| Mapa | Celdas sin baldosa (con Persephone, Pyro, Stratos y Charnel) |
|---|---|
| peasantville | 725 |
| alpine_meadow | 31 |
| tutorial_valley | 5 |
| high_noon | 0 |
| James, en cualquier mapa | 0 |

- **Cuadrados grises de la captura.**
  - Corrección: High Noon es tierra de **James** (`MAP_GOD = "james"` en `land_themes.py`). La captura es High Noon con el look de Persephone.
  - No son ids sin rol. Son **19 celdas sueltas** de roca de James (MG03; ids 210, 215, 194, 42, 217…) que `NATIVE_ROLES` manda a la piedra pálida de Persephone (MG01). Sobre las lomas de tierra quedan como cuadrados grises.
  - Mismo patrón que lo de Peaks en blanco: en ambos casos manda la traducción de roles.
- **Persephone tiene dos caminos de suelo.** `ground_pbr.gdshader` + `GroundSet` solo lo tiene Persephone (`persephone_ground.tres`) y el perfil no lo usa. `TileLayerMap` existe solo para High Noon, y además lo usa el pasto.
- **Variación de la flora.** Solo hay escala uniforme (`scale_range` 0,9–1,1) y yaw por hash (`FloraPlacement.cell_instances`). No hay color por instancia.
- **Ya fuera de las convenciones.** `mesh_planter.gd` tiene 522 líneas (C1b). `terrain_ground_material.gd` tiene la ruta `assets/original/...` en `scenes/` (C13).

### 1. Árbol de archivos ([+] nuevo, [~] cambia, [-] se borra)

```
game/scenes/look/ground/
  [+] god_ground.gd              GodGround (Resource): los 4 GroundRole embebidos + mezcla/macro/relieve/luz horneada
  [+] ground_role.gd             GroundRole: albedo, normal, ORM, detalle; tinte, tile_m, variantes, reglas, triplanar, estocástico
  [~] ground_material.gd         GodGround + mapa de roles + light map -> uniforms (≤150 líneas)
  [+] ground_textures.gd         Texture2DArray por tipo de mapa (caché por GodGround) + ruidos (sale de ground_material)
  [+] ground.gdshader            ÚNICO shader del suelo
  [+] ground_roles.gdshaderinc   pesos de rol: PNG + ruido de borde + mezcla por altura + pendiente/altitud
  [+] ground_sample.gdshaderinc  muestreo: variante de baldosa por celda, triplanar, estocástico, detalle DT
  [~] ground_scars.gdshaderinc   sin cambios de lógica (to_linear = true: todo albedo es sRGB)
  [~] grass_paint.gdshaderinc    lee los pesos de rol en vez de zone_splat
  [+] terrain_deform.gdshaderinc viene de la rama sin integrar (se incluye, no se duplica)
  [~] terrain_layer.gd           un solo material, sin classic/override; `show_roles` (solo editor) tiñe por rol
  [-] sacrifice_ground.gdshader, ground_pbr.gdshader, ground_common.gdshaderinc, zone_splat.gdshaderinc
  [-] ground_set.gd, ground_layer.gd, native_ground.gd, tile_layer_map.gd
game/scenes/map/terrain/
  [~] terrain.gd                 @export ground_roles: Texture2D, @export light_map: Texture2D (con warnings)
  [~] terrain_ground_material.gd un material + guarda de guardado del editor; sin DEFAULT_GROUND (baja C13)
game/scenes/map/map_definition.gd  [~] fuera native_ground
game/scenes/look/
  [~] look_profile.gd            ground: GodGround; fuera ground_classic
  [~] look_rig.gd                fuera tile_map y native_ground
  [~] look_quality.gd            ground_layers -> ground_maps (solo albedo / +normal+ORM), triplanar, estocástico, macro
  [~] grass/grass_type.gd, grass/grass_field.gd   altura del pasto por rol; splat = terrain.ground_roles
  [~] README.md                  línea Ground y `Check:`
game/scenes/look/vegetation/
  [~] vegetation_species.gd      grupo «Variation» (ver §2)
  [~] flora_placement.gd         tinte, inclinación y estiramiento por instancia + manchas por ruido de celda; instance_transform()
  [~] mesh_planter.gd            usa instance_transform() e INSTANCE_COLOR; balance de líneas ≤ 0 (ya está en C1b)
  [~] patch_planner.gd           misma función
  [~] README.md                  `Debug:` -> `Check:`
game/data/look/<dios>.tres x5    [~] GodGround embebido como sub-recurso (un archivo por dios)
game/data/look/ground/           [-] persephone_ground.tres, high_noon_tiles.tres, layers/*.tres (pasan a embebidos)
game/assets/original/themes/<dios>/
  [+] roles/{open,earth,rock,path}.png       hoja de variantes base del dios (64 px = 10 m)
  [+] roles/{open,earth,rock,path}_detail.png  grano DT del grupo
  [-] atlas.png, detail.png, detail_ids*.png, ground_classic.tres (al cerrar la migración)
game/assets/original/maps/<m>/ground_native.tres  [-]
game/scenes/map/maps/<m>/ground_roles.png x9 [+] RGBA = open/earth/rock/path, 256², 1 px = 10 m (test_flat*: todo «open»)
game/tools/import/
  [+] bake_ground_roles.py       necesita el original y lo avisa; corre una vez; tabla tierra -> rol; filtro de celdas sueltas
  [+] bake_role_sheets.py        necesita el original; hojas por dios desde sus grupos MAPG
  [+] ground_roles_table.json    la ÚNICA tabla grupo MAPG -> rol, por tierra (absorbe NATIVE_ROLES y JAMES_ROLES)
  [+] check_ground_roles.py      sin el original ni ventana: cobertura, celdas sueltas, roles completos por dios
  [~] measure_ground.py          modo --roles (media de cada rol pesada por el PNG del mapa)
  [~] land_themes.py             fuera land_remap, base_mapping, build_atlas, map_tiles, NATIVE_ROLES y JAMES_ROLES
game/debug/look/
  [+] ground_roles_lab.tscn      High Noon, cámara fija en las lomas de la captura, preview_god por dios
  [~] persephone_compare.tscn    se reutiliza tal cual para la calibración
```

**Árbol de nodos.** No se agregan nodos de juego: `map.tscn/Terrain` gana 2 knobs y `Look/Layers/Ground` (TerrainLayer) sigue siendo el único que escribe el material. La escena de prueba es `debug/look/ground_roles_lab.tscn`. Instancia `scenes/map/maps/high_noon/map.tscn` y una `Camera3D` fija sobre las lomas de la captura. Estado inicial: el mapa con el look de Persephone. El criterio que se mira (cero cuadrados sueltos, roles completos por dios) se cambia con el `Preview god` del rig desde el inspector; no hace falta una acción de InputMap. La calibración usa la escena existente `persephone_compare.tscn`.

**Qué es cada cosa**
- **Resources de tipo:** `GodGround` y `GroundRole` (embebido), `VegetationSpecies`.
- **Datos del mapa:** `ground_roles.png` y `light_map` como `@export` de instancia del `Terrain`.
- **Nodos:** `TerrainLayer`, `Terrain`, `FloraLayer`.

### 2. Dónde edita un humano cada cosa

| Qué | Dónde |
|---|---|
| Persephone: textura, normal y ORM de un rol (p. ej. pasto) | `data/look/persephone.tres` → Ground → Roles → Open → albedo/normal/orm; se ve en vivo con `Look` → `Preview god` en cualquier `map.tscn` |
| Persephone: tinte, escala, nitidez de borde, luz horneada | mismo `.tres` → GroundRole.tint/tile_m · GodGround.blend_depth/edge_noise · baked_light_base/gain |
| James, Pyro, Stratos, Charnel | `data/look/<dios>.tres` → Ground (misma forma, 4 roles) |
| Qué suelo hay en un lugar del mapa | `scenes/map/maps/<m>/ground_roles.png`, pintable en Krita o Aseprite (R abierto, G tierra, B roca, A camino); `Look/Layers/Ground.show_roles` lo tiñe en el editor |
| Luz horneada del mapa | `map.tscn` → Terrain → `light_map` |
| Calidad (mapas PBR, triplanar) | `data/look/quality_*.tres` |
| Variación de una planta | `data/vegetation/species/<x>.tres` → grupo Variation: `scale_range` (más amplio), `height_jitter`, `tint_dark`/`tint_light`, `tint_cluster_m` (0 = por planta; >0 = manchas), `tilt_max_deg` |

### 3. Dueños e interacciones
- **Bioma en partida.** `MatchBiome` → `map.look.apply_profile(god.look)` → `TerrainLayer.apply_look` es el único escritor del material del terreno. Hace `GroundMaterial.build(profile.ground, terrain.ground_roles, terrain.light_map, preset)`. El pasto y `grass_paint` leen el mismo `ground_roles`. No queda ningún otro escritor: se van `set_classic_material`, `set_ground_override` y `NativeGround.dress`.
- **Red.** Es solo presentación. El dedicated y el headless no construyen el material. No hay RPC nuevo: el dios elegido ya viaja.
- **Calidad.** `apply_quality` solo cambia uniforms y la caché de arrays. Los 4 roles siempre se dibujan; en calidad baja se apagan normal/ORM, el triplanar y el estocástico.
- **Editor / `preview_god`.** Es el mismo camino que en partida. `GodGround` reemite `changed` cuando cambia un rol embebido, así que editar un rol refresca el viewport. El material nunca se guarda en la escena (se mantiene la guarda PRE_SAVE).
- **Flora.** Es determinista: el hash de (seed, tag, tx, tz, i) suma salts de tinte, inclinación y estiramiento. Las manchas salen de un ruido de valor por celda, función pura, sin `randi()`. El color va por `MultiMesh.use_colors`.

### 4. Migración sin perder la calibración
- **Corte 1 (solo herramientas, no cambia el juego).** `bake_ground_roles.py` lee la TMAP de cada mapa en su **propia** tierra con `ground_roles_table.json`.
  - Los pesos salen de las 4 esquinas de cada baldosa: una transición da 50/50.
  - Las celdas sueltas se absorben en el rol mayoritario de sus vecinas.
  - Escribe los 9 PNG. `check_ground_roles.py` en verde.
  - Las tablas de Persephone, James y Charnel salen del código actual. Las de Pyro y Stratos las infiere el script, las imprime y quedan como NO VERIFICADO hasta que un humano las mire.
- **Corte 2 (Persephone).**
  - Hojas de rol desde los grupos MAPG 3, 4, 2 y 1 (los del tutorial).
  - `light_base` 0,3 y `light_gain` 0,55 pasan a `GodGround`.
  - `detail_strength` 1,0 pasa al rol.
  - Se mide con `measure_ground.py --roles` y con capturas de `persephone_compare.tscn`, antes de borrar nada.
- **Corte 3.** Los otros 4 dioses, el pasto lee los roles y el `light_map` por mapa. Se borra todo lo [-]. Se mide `measure_seams.py` en las 9 vistas de `--views=ground`.
- **Corte 4.** Variación de la flora.
- **Corte 5.** Se integra `terrain_deform.gdshaderinc` cuando entre su rama.

### 5. Criterios de aceptación medibles
1. **Cobertura (sin ventana).** `check_ground_roles.py` sobre los 9 mapas: 0 celdas con suma de pesos < 250/255, y 0 celdas sueltas (un rol dominante > 0,5 sin ninguna de sus 4 vecinas con el mismo rol). Además, cada uno de los 5 `GodGround` tiene los 4 roles con albedo. Equivale a «0 celdas sin rol ni baldosa en 9 mapas × 5 dioses», porque ningún dios depende ya de un id.
2. **Un solo shader.** `grep` de `sacrifice_ground\|ground_pbr\|TileLayerMap\|NativeGround\|land_remap` en `game/` da 0.
3. **Persephone en el tutorial.**
   - `persephone_compare` near, mid y far dan PASS con los umbrales actuales de `measure_ground.py`.
   - La media pesada por roles queda a ≤ 0,03 de saturación, ≤ 0,03 de valor y ≤ 4° de tono de la media actual (atlas nativo pesado por `tutorial_valley/tiles.png`).
4. **Cortes y nitidez.** `measure_seams.py` en las 9 vistas: ratio < 1,2 y laplaciano ≥ 40.
5. **PBR completo.** Con un normal y un ORM CC0 en el rol «rock» de un dios, la captura fija de `ground_roles_lab` cambia la media del laplaciano en ≥ 10 %. Con los mapas vacíos es idéntica a la sin normal (diferencia de PNG < 1 %).
6. **Flora.** En `flora_cases` (headless), dos corridas con la misma semilla dan transforms y colores idénticos. Por especie, el desvío del tinte es > 0 y la escala cubre ≥ 90 % de `scale_range`.
7. **Lint.** `bash tools/lint/conventions.sh` sin subas. C13 baja en 1 o más. Ningún script nuevo pasa de 150 líneas.

### 6. Riesgos
- **Transiciones.** Se pierden las baldosas de transición pintadas a mano del original: el borde pasa a ser una mezcla del shader. El punto 4 de los criterios lo vigila; si falla, se ajustan `edge_noise` y `height_contrast`.
- **Bordes entre variantes de la hoja.** Al cambiar de variante por celda puede aparecer un corte. Se mitiga con el clamp de medio píxel de hoy.
- **Tamaños.** Todos los mapas de un `GodGround` tienen que tener el mismo tamaño para entrar en un `Texture2DArray`; el inspector avisa si no.
- **Instance color de la flora.** No verifiqué que el material de los props multiplique `INSTANCE_COLOR`. El developer lo comprueba en `flora_lab`; si no lo hace, hace falta un material de flora con `vertex_color_use_as_albedo` o un shader mínimo.
- **mesh_planter.gd** ya pasa de 300 líneas: el corte 4 no puede sumarle líneas.
- **Fuera de alcance:**
  - Generar normales desde el albedo clásico con Material Maker.
  - Esculpir o deformar el terreno (RFC-057).
  - Rehornear la malla del terreno (`COLOR.r` queda sin usar salvo en los muros).

### Arreglo inmediato de los cuadrados grises: no lo recomiendo
Habría que tocar `NATIVE_ROLES` o `land_remap` y re-correr `import_themes`, que necesita el original y puede mover la calibración de Persephone medida contra el tutorial. Además ese código se borra en el corte 3. El corte 1 es solo herramientas, sale rápido, y su check ya cubre esas 19 celdas y las 761 sin baldosa (725 + 31 + 5).

### Preguntas al usuario (máx. 3)
1. ¿Se deja de calcar las baldosas exactas del tutorial (`NativeGround`, con sus transiciones pintadas) a cambio de un solo camino por roles con las baldosas de Persephone? **Recomiendo que sí**, siempre que pase el punto 3 de los criterios.
2. ¿Alcanzan 4 roles fijos (abierto, tierra, roca, camino), o querés hasta 8, que costaría un segundo PNG por mapa y más samplers? **Recomiendo 4.** La roca de los acantilados además sale sola por pendiente.
3. ¿Arreglo inmediato de los cuadrados grises en el pipeline viejo? **Recomiendo que no** y arrancar por el corte 1.

**Contradicciones entre artefactos:** ninguna con CONVENTIONS ni con RFC-055. Lo único a corregir es el dato del orquestador sobre la tierra de High Noon (es de James, no de Persephone).

No toqué el repo, así que no corrí el lint. Base actual: C1b=24, C13=40.
