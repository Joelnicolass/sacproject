> **Decisiones del usuario (2026-10-24):** plan aprobado. **SCAR (marcas de quemado y cráter) va dentro de 061k** como sub-corte 061k-5 (lector + marcas de Explosion, Chain Lightning, Wall of Spikes, Volcano, Bombardment), investigado con REA en paralelo. Navegación como el original (solo los agujeros cambian los caminos). 4 sub-cortes + 061k-5. La lava y la erupción llevan luz de su color.

# Plan 061k: terreno deformable (Erupt `tpre`, Volcano `clov`, Bore `erob`, abolladuras de Bombardment `rtem`)

No edité el repo. El lint está en verde y no cambió ningún conteo (C1a 103, C16 41, C21 5…).

## 0. Antes de empezar: contradicciones y dependencias

- **No hay RFC-057 escrito.** Solo aparece en `game/docs/archive/rfcs/plans/061-spells-master-plan.md:48`, en la fila 061k. Hasta que el RFC exista, este plan hace de RFC. Lo que aprueben de acá hay que copiarlo a `docs/archive/rfcs/RFC-057-*.md`.
- **055R §3.3 quedó desactualizado.** Dice que la colisión se crea en `_ready` con `create_trimesh_shape`. El código actual dice otra cosa: `Collision` es un hijo guardado que trae el `terrain.glb` (`scenes/map/terrain/terrain.gd:1-6`). Gana el código, porque RFC > research.
- **061h todavía no está.** No existe `ZoneDropper` ni el meteorito de Bombardment. Las abolladuras van en el último sub-corte y se enganchan a la escena del meteorito cuando 061h la cree.
- **Formato SCAR:** sacengine no lo implementa (deja `// TODO: scar` en `state.d:11460`, `18435`, `18490`, `19186`). No hay qué portar sin investigar el ejecutable con REA (ver pregunta 1).

## 1. Objetivo (criterios de aceptación)

- **Erupt:** el suelo sube hasta 15 m en un radio de 50 m mientras se lanza (máx. 4 s) y hasta los 4,2 s. Después cae en 0,15 s y sale una onda de 90 m en 1 s. Hace 600 de daño a ≤15 m, lanza a ≤42,5 m y la onda aturde entre 50 y 75 m. A los 5,2 s el desplazamiento vuelve a 0. Fuente: SAC `state.d:3229-3289`, `18377-18530`.
- **Volcano:** mientras se lanza, aplana 33×33 vértices hacia la altura del centro (plano hasta 80 m, transición hasta 164 m) y suma 0,2× `volc.DATA` escalado por el progreso. Al erupcionar cava un cráter de 25 m de radio y 10 m de profundidad. Durante `duration` (60 s) el monte baja hasta el 25 % y eso queda **permanente**. Si se interrumpe el lanzamiento, no queda nada. Fuente: `state.d:4307-4370`, `7323-7335`, `22308-22375`.
- **Bore:** a los 10 s abre agujeros reales (quita vértices) a lo largo de una espiral. A un cuerpo sin suelo lo lanza y cae. Al llegar espera 3 s + 2 ticks y después repone un vértice cada 30 ticks. Nunca quita un vértice del borde del mapa ni uno a menos de 11 m de un edificio. Fuente: `state.d:3298-3334`, `18636-18705`, `28986-29058`.
- **Bombardment:** cada meteorito resta para siempre `sqrt(1−d²/15²)·1,2 m`. Fuente: `state.d:4077-4083`, `7303-7315`.
- **En todos:** host autoritativo. Servidor, clientes y un cliente que entra tarde tienen la misma deformación permanente y los mismos agujeros. Alturas, `GroundRay`, colisión, flora y render coinciden entre sí. No se reconstruye la malla del mapa.

## 2. Escena de prueba

**`res://debug/spells/cast_terrain.tscn`** (F6) es una copia de `cast_zones.tscn`: los mismos `zones_setup.gd` y Targets, sin `.gd` nuevo.

- **Instancia:** HighNoon, el mago con `wizard_god = james` (Erupt, Bore, Bombardment) o `pyro` (Volcano), un Trogg enemigo a 10 m, otro a 45 m y otro a 60 m, una casa a 30 m (para probar la regla de los 11 m de Bore) y un `VegetationPatch` de helechos a 25 m.
- **Estado inicial:** suelo sin deformar.
- **Lo que todavía no está** (el resultado del criterio): el monte, el cráter y los agujeros.
- **Acción:** `spell_N` del libro y clic en el suelo.

Para la red: `debug/net/terrain_late_join.tscn` (headless, dos procesos). No hace falta un atajo `.tres` extra: el dios elige el hechizo.

## 3. Árbol de archivos y responsabilidades

```
scenes/map/terrain/
  terrain_shape.gd        MOD  sigue siendo el único que responde altura y agujero; suma la deformación;
                               emite changed(rect) (ya declarado, nadie lo emite hoy)
  terrain_rules.gd        MOD  height_in / triangle_in aceptan desplazamiento por vértice y agujeros
                               (arrays vacíos = camino actual)
  terrain_displacement.gd NEW  RefCounted puro: grilla permanente 256×256 (float), bitset de agujeros,
                               suma de los sellos vivos; region_dirty()
  terrain_deformer.gd     NEW  Node `Deformer` (hijo de Terrain); ÚNICO escritor: commit(delta), set_live,
                               drop_live, remove/restore_vertex; @rpc + snapshot para late join
  hole_rules.gd           NEW  static: can_remove(i, j) (borde, ya ausente, <11 m de edificio, máscara de suelo)
  terrain_stamp.gd        NEW  Node3D @tool genérico: un «sello» con hijo Reach (CollisionShape3D, cilindro:
                               radio = alcance, alto = altura pico, con gizmo)
  stamp_profile.gd        NEW  Resource embebido: radial (Curve), ring_travel (Curve), ring_width (Curve),
                               timeline (Curve en s), heightmap (Texture2D) + heightmap_m, flatten (Curve), keep
  stamp_rules.gd          NEW  static: evalúa un perfil en (d, t) sobre una región de la grilla
  terrain_collision.gd    NEW  StaticBody3D `Collision` (reemplaza el del glb): shape owners por trozo de
                               8×8 celdas (1024), ConcavePolygonShape3D; rehace solo los trozos sucios
  hole_walls.gd           NEW  MeshInstance3D: paredes alrededor de los agujeros dinámicos
                               (QUÉ: sacmap.d:235-366 dynamicEdgeMesh)
  falling_chunk.tscn/.gd  NEW  presentación: el pedazo que cae al quitar un vértice (FxBus.broadcast_scene)
  README.md               MOD  (Debug: → Check:)
scenes/map/maps/*/map.tscn  MOD  9 mapas: Terrain/Deformer, Terrain/Collision (TerrainCollision), Terrain/HoleWalls;
                               se apaga el Collision del glb
tools/import/scaffold_map.py MOD  los mapas nuevos ya nacen con esos 3 nodos
scenes/look/ground/
  terrain_deform.gdshaderinc   NEW  global uniform sampler2D terrain_deform_map (RG: alto, agujero),
                                    deform_vertex(), discard por agujero
  sacrifice_ground.gdshader    MOD  include + discard
  ground_pbr.gdshader          MOD  include + discard
  terrain_deform_texture.gd    NEW  Node en Look: escucha shape.changed y sube la textura 256² RGF
                                    una vez por cuadro si cambió
project.godot [shader_globals] MOD  terrain_deform_map, terrain_deform_on
scenes/look/vegetation/
  flora_field.gd   MOD  escucha shape.changed → planters.replan(rect) con `replan_every_s` (0,25)
  mesh_planter.gd  MOD  replan(rect) reusando _touches / set_clears
  README.md        MOD  (Debug: → Check:)
scenes/map/nav/nav_service.gd  MOD  deformer.holes_changed → _baked_changed + _request_rebake (camino existente)
scenes/spells/zones/
  erupt_zone.tscn    NEW  GroundZone + Stamps (Mound, Rebound, Wave) + ZoneBlast (600 a 15 m, lanza ≤42,5)
                          + ZoneBlast de anillo (aturdir 50-75 m) + debris_piece de roca + polvo
  volcano_zone.tscn  NEW  GroundZone + Stamps (Mound: flatten + volc ×0,2, keep 0,25; Crater: 25 m × 10 m, keep 1)
                          + ZoneBlast de quemadura (1000/s, cae de 20 a 50 m, IGNITE) + empuje 10-50 m + ZoneDropper
                          (bola de lava, 1/32 por tick; 061h) + look: lava, nube, salpicadura, ceniza
  volcano_lava.gdshader  NEW  atlas 4×2 (sprt) y extensión por uniform
  volcano_cloud.gdshader NEW  atlas 4×4 (vsmk); un efecto por archivo
  volcano_meshes.res     NEW  tubo y anillo horneados (knots/radii de sacobject.d:3401-3472)
  bore_zone.tscn     NEW  GroundZone + taladro (malla de roca, renderer.d:2036-2040) en espiral + HoleCutter
  hole_cutter.gd     NEW  Node3D servidor: quita el vértice bajo él desde start_s (10), anota y repone
                          (restore_delay_s 3,03, restore_every_s 0,5)
  zone_blast.gd      MOD (si hace falta) un anillo inner_m/outer_m, en vez de una clase nueva
  README.md          MOD
scenes/spells/actions/{erupt,volcano,bore}_action.tscn  NEW  instancias de ZoneAction
match.tscn            MOD  SpellSpawner.zones + los 3 kinds
data/gods/james.tres, pyro.tres  MOD  tpre, erob, clov en el libro
tools/import/import_terrain_stamps.py  NEW  volc.DATA (XMNU.WAD) → assets/original/terrain/volcano_shape.png
                                            (33×33 L8 exacto); sprt (MAIN.WAD bits), vsmk y sptr (Bloo.WAD Pyro)
                                            → assets/original/fx. Avisa que necesita el original
tools/bake/bake_volcano_meshes.gd      NEW  tubo de lava, nube y anillo de salpicadura → volcano_meshes.res
debug/spells/cast_terrain.tscn         NEW  (sección 2)
debug/suite/terrain_cases.gd           NEW  + registro en rules_suite
debug/net/terrain_late_join.tscn       NEW
(061k-4, después de 061h) la escena del meteorito de 061h + un hijo TerrainStamp `Dent` (keep 1, al impactar)
```

**Qué es cada cosa:**
- **Resource de tipo:** `StampProfile` va embebido en la escena del hechizo, para no armar cadenas de `.tres`. Los números del hechizo quedan en `data/catalog/spells/*.tres`.
- **Nodos:** Deformer, Collision, HoleWalls, TerrainStamp, HoleCutter y TerrainDeformTexture.
- **`@export` de instancia:** `refresh_ticks` (Collision, 3), `chunk_cells` (8), `replan_every_s` (flora), `keep`, `start_s`.
- **Radio y alto:** son el `Reach` de cada sello (C20).

## 4. Dueños, red y orden por tick

**Estado y dueño:**
- La grilla permanente y los agujeros los escribe solo `TerrainDeformer`, y solo en el servidor (o en solo).
- Los sellos vivos (temporales) son una función pura de (perfil, centro, ticks). Se recalculan, nunca se acumulan, así que no hay deriva.
- `TerrainShape` es el único que responde `height_at` / `is_on_ground` / `sampler()`. Pide al desplazamiento que se refresque de forma perezosa e idempotente: una sola vez por tick, solo la región sucia.

**Red:**
- **`commit`:** el servidor calcula la región en float32 y manda por RPC confiable `(rev, rect, PackedFloat32Array delta)`. Una abolladura son unos 16 floats; Volcano, 1089 floats (unos 4 KB). El cliente aplica los bytes exactos, sin recalcular, así que la arquitectura no le cambia el resultado.
- **Agujeros:** `(rev, vertex_id, removed)` por RPC.
- **Late join:** con `MpKit.push_snapshot` (el patrón de `match_state.gd:7-9`) el snapshot trae la grilla entera con `compress()`. Es casi todo cero, así que pesa unos pocos KB. Trae también el bitset de agujeros y `rev`. El cliente ignora los RPC con `rev ≤` la del snapshot.
- **Sellos vivos:** el cliente avanza localmente los ticks del sello. El servidor sincroniza `Stamp:ticks` y `Stamp:target_y` (la altura del aplanado de Volcano, que se captura una vez en el servidor) con el `MpReplicate` de la zona, cada 0,25 s. Así un cliente que entra a mitad de un Volcano ve el progreso correcto.
- **Sello con `keep > 0`:** en el cliente no se borra cuando la zona sale del árbol. Lo borra el Deformer cuando llega el `commit` con la misma `key` (el nombre de la zona). Esto evita el parpadeo y no depende de parches de orden.

**Orden dentro de un tick:**
1. Prioridad −1: `GroundZone` y después sus hijos `TerrainStamp` / `HoleCutter` (orden del árbol). Llaman `set_live` / `commit` / `remove_vertex` y marcan un rect sucio.
2. Prioridad 0: las unidades y los efectos leen `height_at`, que refresca la región sucia la primera vez.
3. `TerrainCollision` junta los rects y aplica en el `physics_frame` siguiente, cada `refresh_ticks`. Un agujero se aplica en ese mismo tick.
4. En `_process` (presentación, no existe en el dedicado): la textura una vez por cuadro y la flora con su límite de frecuencia.
5. `NavService`: con `holes_changed` usa el re-horneado de siempre, con el cambio en un tick contado (`rebake_swap_frames`).

## 5. Cómo se actualiza cada representación y cuánto cuesta (estimado, se mide en la suite)

| Representación | Mecanismo | Costo |
|---|---|---|
| **Alturas** | `height_in` suma el desplazamiento de las 3 esquinas del triángulo (los vértices caen en la grilla de 10 m) y descarta los triángulos que tocan un vértice quitado. `sampler()` lleva copias copy-on-write | +3 lecturas por llamada; refrescar Erupt (19×19 × 3 sellos) o Volcano (33²) ≈ 0,3-0,6 ms por tick, solo en la región |
| **Colisión** | 1024 trozos de 80 m con shape owners en un solo `StaticBody3D`; se rehacen solo las caras de los trozos tocados (paredes incluidas, desplazadas por xz) | Al cargar ≈ 150-300 ms en un hilo (si pasa de 300 ms se hornea como `nav.res`). Erupt: hasta 16 trozos × ≈0,2 ms cada 3 ticks |
| **`GroundRay`** | Sin cambios: lee la colisión | — |
| **Navmesh** | Como el original (`state.d:728-741`): el relieve no se re-hornea; `closest_land` es 2D (`nav_regions.gd:108-133`) y los puntos toman la altura de `height_at`. Los agujeros sí disparan el re-horneado completo que ya existe, que lee la colisión por trozos (`nav_source`) | ≈2 s en un hilo (High Noon) + `parse_ms` en el hilo principal (se mide); se juntan mientras corre (`_dirty`). `EdgeClamp` ya frena en el borde del agujero |
| **Render** | Desplazamiento del vértice por shader con una textura global 256² RGF (R alto, G agujero) y normal corregida con diferencias centrales. Agujero: la G interpolada es mayor que 0 en todo triángulo que toca un vértice quitado, y ahí se descarta. `HoleWalls` es una malla chica con las paredes nuevas | Subida de 512 KB ≤1 ms solo si cambió. 5 `texelFetch` por vértice. La malla del mapa nunca se reconstruye |
| **Flora** | `changed(rect)` → `replan` de las celdas de 32 m tocadas, en hilos, con el presupuesto existente | Erupt ≈36 celdas, máx. 4 veces por segundo; abolladuras y cráter, una vez |
| **Pasto** | Fuera de alcance (apagado; ver memoria). El mismo `changed` lo engancha después | — |

## 6. Qué arma cada hechizo y criterios medibles

**Suite `terrain_cases` (headless):**
- **Erupt:** a los 4,2 s, `height_at(centro) − base = 15,0 ± 0,1` y a 40 m `1,8 ± 0,1` (el perfil Curve contra la fórmula de `state.d:3248-3262`). Un tick después de 5,2 s, |Δ| < 0,01 en toda la región. Un Trogg a 10 m sigue el suelo: `|y − height_at| < 0,5 m` durante la subida. Daño 600 a ≤15 m, lanzado a ≤42,5 m, aturdido a 60 m y no a 45 m ni a 80 m.
- **Volcano:** si se interrumpe, la grilla es exactamente 0. Si termina, centro = `0,25·dmap + cráter` ± 0,1, y a 100 m, el aplanado esperado ± 0,1. Quema 1000/s a ≤20 m.
- **Bore:**
  - El primer agujero aparece a los 600 ± 1 ticks, con `is_on_ground == false` en sus 4 celdas.
  - El cuerpo que queda encima se lanza y `FallCheck.has_fallen`.
  - La casa a 30 m nunca pierde vértices a <11 m.
  - Después del cambio del navmesh, `find_path` no cruza el agujero.
  - Repone 1 vértice cada 30 ticks y termina con 0 agujeros.
- **Bombardment (061k-4):** el vértice del impacto queda en −1,2 ± 0,01 y las abolladuras se suman.
- **Coherencia:** en 50 puntos de la región, `GroundRay.surface_y` (colisión) = `height_at` ± 0,05.
- **Flora:** ninguna planta de las celdas re-planificadas con `|y − height_at| > 0,3` (`flora_cases`).
- **Red** (`terrain_late_join`): crc32 de la grilla y de los agujeros iguales en el servidor, en el cliente y en un cliente que entró después de Bombardment + Volcano. Además, el cliente que entró a mitad de Volcano tiene sus ticks de sello a ±15 de los del servidor.

**Captura:** `match_shots --cast=tpre|clov|erob --views=zone`, con cámara fija, a t = 0 y t = 4,2 s.
- El diff de píxeles fuera de la proyección del rect deformado tiene que ser 0. Eso prueba que no se rehízo el mapa.
- Dentro, la silueta sube ≥ N px (N se fija en la primera corrida).
- Con Bore: se ve cielo o vacío en el agujero (más de 0 píxeles con alfa descartado) y las paredes dibujadas.

**Rendimiento:** el pico de cuadro durante Erupt es ≤4 ms sobre la línea base, y las reconstrucciones de la malla de `Terrain` son 0.

**Lint:** ningún conteo sube. C15: los shape owners y las mallas no son nodos con `.new()`.

## 7. Orden de implementación (4 sub-cortes)

**061k-1 (núcleo + Erupt):**
1. `TerrainDisplacement`, `TerrainRules` y `TerrainShape`, más los casos de altura.
2. `TerrainStamp`, `StampProfile`, `StampRules` y `Deformer` (solo, RPC, snapshot).
3. `TerrainCollision` en los 9 mapas y en `scaffold_map.py`.
4. Shader include, global, `TerrainDeformTexture`.
5. Erupt (escena, acción, libro).
6. Re-planificación de la flora.

**061k-2 (Volcano):**
7. El importador y el horneado de mallas.
8. `volcano_zone` con su look.

**061k-3 (Bore):**
9. `HoleRules`, `HoleCutter`, `HoleWalls`, `FallingChunk`, el enganche con nav y `bore_zone`.

**061k-4 (Bombardment):**
10. El `Dent` en el meteorito de 061h.

**Al cerrar cada sub-corte:** `terrain_late_join`, match_shots, READMEs (`Debug:` → `Check:` en `map/`, `map/terrain/` y `look/vegetation/`) y el lint.

**Cómo lo verifica una persona en el editor:**
- Abre `cast_terrain.tscn` con F6.
- Elige el dios en el inspector de Targets y lanza con `spell_N` y clic.
- En `erupt_zone.tscn` mueve el radio y la altura con el gizmo del `Reach`, y edita las curvas en el inspector.
- En `map.tscn`, `Terrain/Collision` muestra los trozos con Debug → Visible Collision Shapes.

## 8. Riesgos y fuera de alcance

**Riesgos:**
- Cargar los 1024 trozos de colisión podría pasar de 300 ms. En ese caso se hornean por mapa.
- `parse_ms` del re-horneado sobre la colisión por trozos se ejecuta en el hilo principal y hay que medirlo.
- Cuerpos sobre un suelo que cae 100 m/s (la caída de 0,15 s de Erupt): de todos modos son lanzados.
- Un `cos` puede diferir entre ARM y x86 en los sellos vivos. Solo afecta lo que se ve: lo permanente viaja en bytes.
- Los edificios y los props no siguen el relieve. El original tampoco los mueve: **NO VERIFICADO**.
- El minimapa no se actualiza.
- `volc.DATA` y las texturas exigen el original al importar, y el importador lo avisa.

**Fuera de alcance:**
- SCAR (pregunta 1).
- Quake `kauq` del Jabberocky. Después es un sello `.tres` más sobre `QuakeRing`.
- El pasto.
- (Corregido por el orquestador 2026-10-24: la lava y la erupción del volcán SÍ llevan luz de su color —regla «cada hechizo ilumina con su color»—: ActorLight naranja en la lava y FxLightSpec en la erupción.)

## 9. Preguntas (con recomendación)

1. **¿Las marcas de quemado y del cráter (SCAR) van en este corte?** sacengine no las tiene, y hacer el lector exige investigar el ejecutable con REA. **Recomiendo** un corte aparte (061k-s). Mientras tanto, el cráter se lee por el relieve y por el arte del volcán.
2. **¿Navmesh como el original (solo los agujeros cambian los caminos) o re-hornear también con los montes y cráteres permanentes?** **Recomiendo** como el original: con `max_climb` 3 m y pendiente de 85° el relieve no corta caminos, y nos ahorramos re-horneados de 2 s.
3. **¿Está bien partir 061k en 4 sub-cortes (núcleo + Erupt, Volcano, Bore, abolladuras después de 061h)?** **Recomiendo** que sí, porque cada uno se juega y se verifica por separado.

## Archivos leídos

- `game/CONVENTIONS.md`
- `game/docs/archive/rfcs/research/055R-original-reference.md` (§3)
- `game/docs/archive/rfcs/research/061R-abilities-structures.md`
- `game/docs/archive/rfcs/plans/061-spells-master-plan.md`
- `game/scenes/map/terrain/terrain_shape.gd`
- `game/scenes/map/terrain/terrain.gd`
- `game/scenes/map/terrain/terrain_rules.gd`
- `game/scenes/map/terrain/terrain_mesh_arrays.gd`
- `game/scenes/map/terrain/ground_ray.gd`
- `game/scenes/map/nav/nav_service.gd`
- `game/scenes/map/nav/nav_rebake.gd`
- `game/scenes/map/nav/nav_mesh_backend.gd`
- `game/scenes/map/nav/nav_regions.gd`
- `game/scenes/units/movement/edge_clamp.gd`
- `game/scenes/units/movement/fall_check.gd`
- `game/scenes/spells/zones/ground_zone.gd`
- `game/scenes/spells/zones/zone_pulse.gd`
- `game/scenes/look/vegetation/mesh_planter.gd`
- `game/scenes/look/ground/sacrifice_ground.gdshader`
- `game/scenes/look/ground/ground_pbr.gdshader`
- `game/scenes/match/match_state.gd`
- `sacengine/source/state.d`
- `sacengine/source/sacmap.d`
- `sacengine/source/sacobject.d`
- `sacengine/source/renderer.d`
