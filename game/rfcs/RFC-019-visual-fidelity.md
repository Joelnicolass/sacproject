# RFC-019 — Fidelidad visual: terreno, modelos, fuentes, altar y bioma por dios (plan del tech lead)

Estado: plan, sin código. Cinco sub-cortes independientes, cada uno con criterio y verificación propios. Numeración propuesta en `FEATURES.md`: F52 (019a) a F56 (019e); F49–F51 siguen reservados para 018c–e.

Fuentes: **[SE]** = `sacengine/source/…` (archivo:línea). **[CACHE]** = medido sobre `game/cache/` (exportado de la instalación). **[SONDA]** = sonda headless de esta sesión (scripts en el scratchpad `tl019/`; resultados copiados acá). Ghidra no se corrió: en los cinco puntos sacengine alcanzó (ver 019d).

---

## 0. Hallazgos

### 019a — Terreno facetado
- `tools/export_high_noon_terrain.py:158-171` (`push_tri`) escribe **3 vértices propios por triángulo con la normal de la cara**. `terrain.gd:_load_mesh` las pasa tal cual a `ARRAY_NORMAL`. Resultado: sombreado plano.
- [SONDA sobre CACHE] `high_noon_terrain.bin`: 20 586 vértices, 5 846 triángulos de suelo, 1 016 de pared, 3 174 posiciones de suelo. **Solo 29 posiciones tienen una única normal**; 1 769 tienen 6 distintas, 648 tienen 5. El ángulo entre la normal de cara y la suavizada: mediana 3,8°, p90 10,3°, p99 19,8°, máx 33,9°. Ese salto por arista es lo que se ve.
- [SE] `sacmap.d:720-744` (`generateNormals`): una normal **por vértice de la grilla**, suma de los productos cruz sin normalizar de las caras que lo tocan (pondera por área), normalizada. Se copia a los 4 vértices de cada baldosa (`sacmap.d:885-886`). Las paredes del acantilado llevan normal plana por cuadrilátero (`sacmap.d:795-801`) y son otra malla: el quiebre suelo/pared no se suaviza. El port tiene que hacer lo mismo.
- No se pueden compartir vértices en la malla (cada triángulo lleva en `COLOR` su baldosa y su UV local), pero sí **igualar la normal de todos los vértices que caen en la misma posición**.
- **Segundo defecto, mismo archivo de shader** — `sacrifice_ground.gdshader:19`: `vec2 light_uv = vec2(VERTEX.x, VERTEX.z) / 2560.0;` dentro de `fragment()`. En Godot 4 `VERTEX` en `fragment()` está en **espacio de vista**, no de mundo: el lightmap del mapa se muestrea con coordenadas relativas a la cámara, casi siempre cerca de (0,0). El sombreado suave que el mapa trae horneado (LMAP, [SE] `sacmap.d:207`; `terrain2.d`: `totalColor = 0.5*diffuse*(1+detail)*colorColor`) hoy no se aplica bien, así que lo único que modela el relieve es la luz por cara. No lo medí con una captura (hace falta ventana): se confirma en el paso 1 moviendo la cámara. Ver pregunta abierta 1.

### 019b — Modelos de costado y flotando
Causa única, de **datos horneados + cómo se combinan con los clips**, no de la escena:
- `tools/export_bodies.py:77` exporta cada SAXS **sin animación** (`export:` con `Pose.init`, [SE] `app.d:464`, `saxs2obj.d:10-14`): la pose de enlace, que en muchos modelos está acostada. El original nunca dibuja esa pose.
- `tools/bake_bodies.gd:66-73` **adivina** si está acostado con una proporción del AABB (`LYING_RATIO 1.6` + dos listas a mano) y guarda `upright_fix` y `foot_offset` de esa pose de enlace.
- `ClipPosePlayer._apply_frame_mesh` (`clip_pose_player.gd:147-158`) reemplaza la malla por el cuadro del clip real (exportado con `export-all-frames`, [SE] `app.d:493-504`, ya posado: de pie, origen en el suelo) **pero deja la rotación y el `foot_offset` de la pose de enlace**. Un modelo con `upright_fix = 90°` queda acostado en cuanto arranca su clip; uno con `foot_offset = 1,2` flota 1,2 m.
- [SE] sacengine no corrige nada por modelo: el origen del SAXS posado es el punto de apoyo y la caja sale de los huesos en `stance1` cuadro 0 (`sacobject.d:286-320`, `450`).
- Además, 5 cuerpos (`AArc`, `eorc`, `gobl`, `huma`, `humn`) y el manantial `pcfn` tienen `rotation_offset [0,90,0]` **editado a mano dentro de `cache/baked/*.json`**: un re-horneado lo borra y no está en git.
- Claves en minúscula: `export_stats.py:483,519` guarda los clips con `model.lower()` (`aarc`, `abrx`, `yogo`) y `ClipPosePlayer._clip_for_role` busca con el tag real (`AArc`, `ABRX`, `YOGO`): esos tres no animan nunca.
- Frostwolf (`gobl`): sus cuadros exportados están a **+25,4 m** (`GBi1`) y +18,4 m (`GBrn`). El exportador de sacengine usa el desplazamiento crudo (`saxs.d:313-314`), el juego lo corrige con la altura de referencia del clip (`sxsk.d:128-139`, `frameOffset`). Hoy no se nota solo porque la rotación equivocada lo tumba.

[SONDA] Cuadro 0 del clip idle con la pose que hoy aplica `BodyCatalog.pose`, por modelo (roster de `books.json` + 15 magos). «Flota» = y mínima > 0,15 m; «de costado» = el eje vertical del clip deja de ser vertical. Las voladoras llevan `flying_height` aparte y no se cuentan por flotar.

| Modelo | Nombre | Hoy | Detalle |
|---|---|---|---|
| maho | Manahoar | de costado + flota 0,45 | `upright_fix 90°` |
| humn | Druid | de costado + flota 0,57 | fix 90° + giro a mano |
| huma | Ranger | de costado + flota 0,22 | ídem |
| eorc | Trogg | de costado + flota 0,54 | ídem |
| gobl | Frostwolf | de costado; clip a +25 m | ídem + desplazamiento |
| xwiz | The Ragman (mago) | de costado + flota 0,83 | fix 90° |
| rigl | Grakkus (mago) | de costado + flota 0,73 | fix 90° |
| fdzy | Cog | flota 0,94 | `foot_offset` de enlace |
| fklp / eklp / dklp | Flame Minion / Earthfling / Fallen | flotan 0,75 | ídem |
| ddiz | Scythe | flota 0,67 | ídem |
| jnwr | Jadugarr (mago) | flota 1,36; cápsula 4,08 vs modelo 3,06 | ídem |
| mrdk | Marduk | flota 2,27 | ídem |
| quil, gret, hero, buta, shkt, brod | Acheron, Sorcha, Eldred, Buta, Shakti, Hachimen | flotan 1,06 / 1,03 / 1,21 / 0,93 / 0,77 / 1,58 | ídem |
| sage | Mithras | flota 1,27; cápsula 2,31 vs 1,83 | ídem |
| lhbt, fhbt, ehbt, bugz, sbob | Shrike, Spitfire, Gargoyle, Locust, Brainiac (vuelan) | +0,9 a +1,2 **de más** sobre `flying_height` (sbob +3,06) | mismo `foot_offset`; no es error de «flotar», pero se corrige solo |
| AArc, ABRX, YOGO | Sylph, Abraxus, Yogo | sin clip (clave en minúscula): quietos en pose de enlace | datos |
| serx, spdr | Seerix, Charlotte | **bien** | `foot_offset` ≈ 0 |

26 de 31 mal; 2 bien; 3 sin clip. **Todo es error de datos horneados** (exportador / horneado / clave). La colocación en la escena (`Tilt/Mesh`, `Mesh`, cápsula con `col.position.y = alto/2`) es correcta y no se toca: con el cuadro idle crudo, los pies quedan en y ∈ [−0,28; +0,22] en todos los modelos salvo `gobl` y `sbob`.

### 019c — VFX de los manantiales
Qué hace el original [SE]:
- **Manantial libre** (`state.d:27984-27991`, `animateManafount` 27769-27792): 4 partículas por cuadro de simulación (60 Hz → 240/s), tipo `manafount`: textura `MAIN.WAD!/bits.FLDR/elec.TXTR`, atlas 4×4, **6 × 6 m**, energía 20, con gravedad 15 (`sacobject.d:1300`, `1393-1397`). Nacen en el tope del modelo (centro de la caja + 0,75), en un disco de 0,5 m que gira 0,25 m a 1,5 Hz; salen hacia arriba a 15–25 m/s abiertas ~14–27° de la vertical; viven hasta 2,67 s (distribución cuadrática) y se apagan al final (`getAlpha`, `sacobject.d:1818-1819`). Es un **chorro continuo** que sube ~10–18 m y cae.
- **Con Manalith**: el manantial queda inactivo (`state.d:1723`, `27983`): **sin chorro**. El Manalith emite `manalith` (`animateManalith` 27793-27811): `fb_g.TXTR`, atlas 3×3, 12 × 12 m, 240/s, suben rectas a 10–20 m/s desde +15 m en un disco de 3,5 m, alfa ≤ 0,07, **teñidas con el color del bando** (`manaColor(side)`, `state.d:30104-30116`). El altar y el Shrine usan la misma textura a 4 × 4 m desde +3 m (`animateShrine`, `sacobject.d:1403-1406`).
- El modelo del manantial es un componente estático de edificio: **no tiene animación**.

Qué hace el port (`manafount_body.gd`, `manafount.tscn`):
1. **Efecto equivocado**: `fx_name = "wrath_particle"` (chispas del hechizo Wrath, atlas `prth`, 0,3 m).
2. **Ráfaga, no chorro**: `SpriteParticles` es one-shot; se dispara cada 1,2 s.
3. **Lo emite el servidor por red**: `FxBus.broadcast` cada 1,2 s × 5 manantiales, también en el dedicado. Un loop decorativo no es un evento.
4. **No se apaga con un Manalith encima** (`_physics_process` no mira `is_free()`), y el Manalith no tiene efecto propio.
5. **Atlas ausentes**: `tools/export_particles.py` no exporta `elec` ni `fb_g`.
6. **Altura y escala**: +1,4 m fijo y 0,3 m, contra tope del modelo y 6 m.
7. **`ClipPose` muerto**: `pcfn` no tiene clips en el caché; `_first_clip_tag` devuelve vacío siempre. Son ~45 líneas y un nodo que no hacen nada.
8. **No se ve en el editor**: no hay nodo de efecto en la escena; todo sale por código.

### 019d — El altar: maná sí, vida directa no
[SE], tres lugares coincidentes:
- Maná (`state.d:28578-28593`, `ManaProximity`): manantial libre 33,3/s a cualquiera; Manalith 33,3/s al bando aliado; **altar 16,67/s** al bando aliado; Shrine 8,33/s; radio 50 en todos. Lo reciben mago **y criaturas** (`updateCreatureStats`, `state.d:14408-14409`).
- Vida (`state.d:14400-14407`): la única curación pasiva es `regeneración × maná/maná_máximo` cuando el cuerpo está quieto y sin recibir golpes (`isRegenerating`, 1429-1435), más 16,67/s a los **guardianes** de un edificio (hechizo Guardian) y 30/s a quien se hace el muerto. Los edificios se curan a sí mismos (27982). **Ningún edificio cura a un cuerpo cercano.**
- Fantasma (`giveMana`, `state.d:8828-8832`): el maná que recibe un mago fantasma se convierte en vida × 4,2. Así «revive» junto a su altar (≈70 de vida/s) o a un manantial.

El port ya hace las tres cosas (`ManaSource` kind ALTAR, `_regenerate` en `wizard_body.gd:360` y `unit_body.gd:510`, `ghost_form.gd:156`, `MatchRules.altar_rate/altar_radius/ghost_health_per_mana`). **El original no cura de forma directa en el altar.** El pedido del usuario contradice a sacengine, que el PRD nombra árbitro de la simulación → pregunta abierta 2 (bloquea 019d).

### 019e — Bioma por dios
- Hoy `MatchBiome` sortea en el servidor y lo manda por el canal `biome`; `ThemeApplier.apply` toca cielo (`Sky`), `Environment`, `Sun` y `Terrain.set_tileset_dir`.
- **Es solo presentación** (verificado en código): `set_tileset_dir` cambia el material, la colisión se arma una vez en `_load_mesh`; `MatchBiome._apply` sale si es dedicado; nadie más lee `MatchBiome.god`; las reglas leen el `god` del pick del mago, no el del bioma.
- Cada cliente ya conoce su pick sin esperar al servidor: `SacrificeFlow.pick_for(MpKit.local_slot())` devuelve el `pick` local (`sacrifice_flow.gd:53-58`) y `slot_picks` se replica a todos.
- [SE] En el original el suelo es del mapa, no del dios (`levl.d:43-52`, ya anotado en F32): el bioma por dios es un invento del port ya aceptado; este corte solo cambia quién lo elige.
- Look por dios de altar / manantial / vegetación: **no hay dato**. `cache/baked/props.json` tiene 71 props, todos de Persephone (`alba/alpi/alto`, `pcfn`, `pc*`). Quedan igual.

---

## 1. Objetivo y criterios de aceptación

### 019a (F52) — Suelo suavizado
- En el suelo, todos los vértices que comparten posición tienen la misma normal, calculada como `sacmap.d:720-744`. Las paredes del acantilado conservan su normal plana y el borde suelo/pared sigue marcado.
- `Terrain` expone `smooth_ground` (on por defecto) en el inspector; apagarlo vuelve al facetado, también en el editor.
- No cambia la colisión, `ground_height`, `is_on_ground` ni el `.bin`: no hace falta re-exportar.
- (Si se aprueba la pregunta 1) el lightmap del mapa se muestrea en coordenadas de mundo.

### 019b (F53) — Modelos de pie y apoyados
- Ningún modelo del roster convocable ni mago queda de costado; los no voladores tienen los pies en |y| ≤ 0,3 m con su clip idle; las voladoras quedan a `flying_height` sin extra.
- La cápsula mide el alto del modelo posado (±25 %).
- Sylph, Abraxus y Yogo animan.
- Un technical artist corrige giro, desplazamiento, escala y cápsula de un modelo **desde el inspector**, en un `.tres` commiteado; un re-horneado no lo pierde. `cache/baked/*.json` deja de editarse a mano.
- Una escena de banco muestra modelo + cápsula + suelo + flecha de frente, en el editor.

### 019c (F54) — Chorro del manantial
- Manantial libre: chorro continuo con el atlas `elec`, desde el tope del modelo, que sube y cae; se ve al abrir `props/manafount.tscn` en el editor.
- Con un Manalith encima: el chorro se apaga y aparece la columna `fb_g` teñida con el color del dueño; al destruirse el Manalith vuelve el chorro. En todos los clientes.
- El efecto es un nodo de la escena con un `ParticleType` `.tres`: tasa, tamaño, velocidad, altura y color se ajustan en el inspector.
- El servidor no manda nada por red para este efecto; el dedicado no crea partículas.

### 019d (F55) — Vida en el altar (sujeto a la pregunta 2)
- Opción fiel: sin cambio de reglas; se documenta en `FEATURES.md` que el altar da maná y que la vida sale de la regeneración por maná y del fantasma.
- Opción pedido: un mago o criatura del dueño, vivo, a menos de `altar_heal_radius` de su altar recibe `altar_heal_rate` de vida por segundo, en el servidor. No aplica al enemigo ni al fantasma (el fantasma ya se cura por maná). Con `altar_heal_rate = 0` el juego queda como el original. Manantial, Manalith y Shrine no curan.

### 019e (F56) — El dios elegido define suelo y cielo
- Cada cliente ve el cielo, la luz y el suelo del dios **que eligió él**. El servidor no decide ni envía el bioma en este modo.
- `MatchRules.biome_mode` conserva el sorteo del servidor como opción; `biome_god` no vacío sigue forzando (lo usan las escenas debug).
- `MatchBiome` tiene `editor_preview_god`: elegirlo en el inspector pinta ese tema en el editor; guardar la escena no deja colores ni texturas del tema en el `.tscn`.
- Altar, manantial y vegetación siguen con el look de Persephone.

---

## 2. Escenas de prueba y verificación headless

| Corte | Escena | Estado inicial | Qué no está cumplido al abrir | Acción | Headless equivalente |
|---|---|---|---|---|---|
| 019a | La que abre el jugador: `scenes/world/high_noon.tscn` (no hace falta debug) | `Terrain.smooth_ground` on | Para ver el antes: apagar `smooth_ground` | Editor: tildar/destildar en el inspector. F6: `move_forward` y mirar el relieve | `Godot --headless --path game --script res://debug/terrain_normals_probe.gd` imprime `suelo posiciones 3174 con_normal_unica 3174 paredes_planas 1016/1016` |
| 019b | NUEVA `debug/body_pose_bench.tscn` (editor) + existente `debug/unit_parity_gallery.tscn` (F6) | Banco: un `gallery_body.tscn` con `model = eorc`, cápsula translúcida, piso en y = 0, flecha +Z. Galería: roster del libro | Banco: abre con el override vacío (lo que dio el horneado). Galería: arranca en idle | Banco: cambiar `model` en el desplegable; editar la entrada en `data/bodies/pose_overrides.tres`. Galería: `debug_anim_cycle` | `--script res://tools/audit_body_pose.gd` imprime la tabla del punto 0 y termina en `POSE AUDIT PASS` (hoy: 26 fallas) |
| 019c | Existentes `debug/mana_fount.tscn` (chorro) y `debug/structure_siege.tscn` (cambio a Manalith) | Mago a 120 m del manantial / sin estructura | El chorro está lejos; no hay Manalith | `move_forward` hasta verlo; en siege: pestaña Estructuras + `spell_1` + clic | `--script res://debug/fount_fx_probe.gd`: `fx.json` tiene `manafount` y `manalith` con su PNG; en `manafount.tscn` `%FreeFx.emitting` true y `%ManalithFx.emitting` false; tras `occupy()` se invierten; tras `release()` vuelven |
| 019d | NUEVA `debug/altar_heal.tscn` = `high_noon.tscn` + `debug/rules/altar_heal.tres` (`start_health` 300, `start_mana` 0) + `mana_probe.gd` mostrando también la vida | Mago a 80 m de su altar (fuera del radio), vida 300, maná 0 | La vida no sube | `move_backward` / `move_forward` hasta entrar al radio: sube ≈16,7/s | La misma escena en headless imprime `vida/s` fuera (≈0) y dentro (≈ tasa); caso `altar_heal` en `debug/rules_suite` (propio sí, enemigo no, fantasma no) |
| 019e | La que abre el jugador: `scenes/ui/boot.tscn` → elegir Pyro → Jugar solo. `debug/biome_pick.tscn` sigue probando el forzado | Pantalla de selección | Todavía no se eligió dios | Elegir dios y entrar | Solo: imprime `bioma pyro origen pick`. Dedicado + 2 clientes con dioses distintos: cada cliente imprime el suyo; el dedicado imprime `bioma por jugador` y no manda el canal `biome`. Editor: `--headless --editor` + guardar → `git diff` vacío |

---

## 3. Árbol de archivos

```text
game/
├── tools/
│   ├── bake_bodies.gd                 MOD 019b  hornea desde el cuadro 0 del idle; sin adivinar
│   ├── export_stats.py                MOD 019b  clave con el tag real; desplazamiento con altura de referencia
│   ├── audit_body_pose.gd             NUEVO 019b  sonda headless (sale de tl019/probe_bodies.gd)
│   └── export_particles.py            MOD 019c  + elec, fb_g; entradas manafount / manalith
├── data/
│   ├── bodies/pose_overrides.tres     NUEVO 019b  correcciones por modelo (commiteable)
│   ├── fx/manafount.tres              NUEVO 019c  ParticleType del chorro
│   ├── fx/manalith.tres               NUEVO 019c  ParticleType de la columna
│   └── match_rules.tres               MOD 019d (altar_heal_*) · 019e (biome_mode)
├── scenes/data/
│   ├── body_pose_override.gd          NUEVO 019b  Resource: una entrada por modelo
│   ├── body_pose_overrides.gd         NUEVO 019b  Resource: la lista + búsqueda por modelo
│   └── match_rules.gd                 MOD 019d · 019e
├── scenes/fx/
│   ├── sprite_atlas.gd                NUEVO 019c  @tool estático: catálogo, textura, material, quad
│   ├── sprite_particles.gd            MOD 019c  delega en SpriteAtlas (sigue siendo la ráfaga)
│   ├── sprite_emitter.gd / .tscn      NUEVO 019c  @tool: emisor continuo de un ParticleType
│   └── particle_type.gd               MOD 019c  + rate_per_s, lifetime_randomness, fade_out, tint
├── scenes/world/
│   ├── terrain.gd                     MOD 019a  _smooth_ground_normals + @export smooth_ground
│   ├── sacrifice_ground.gdshader      MOD 019a  (pregunta 1) lightmap en mundo
│   ├── body_catalog.gd                MOD 019b  aplica overrides encima del horneado
│   ├── body_visual.gd                 MOD 019b  se refresca cuando cambia el .tres de overrides
│   ├── components/clip_pose_player.gd MOD 019b  (solo si la clave no se arregla en el exportador)
│   ├── heal_source.gd                 NUEVO 019d  (opción pedido) hermano de ManaSource
│   ├── match_biome.gd                 MOD 019e  modo por jugador + editor_preview_god
│   └── props/
│       ├── manafount.tscn             MOD 019c  + FreeFx, ManalithFx; − ClipPose
│       ├── manafount_body.gd          MOD 019c  prende/apaga emisores; − clips, − FxBus
│       ├── altar.tscn                 MOD 019d  + HealSource
│       └── player_start.gd            MOD 019d  una línea (si 017a no llegó antes)
└── debug/
    ├── terrain_normals_probe.gd       NUEVO 019a
    ├── body_pose_bench.tscn           NUEVO 019b
    ├── capsule_preview.gd             NUEVO 019b  @tool, dibuja la cápsula del catálogo
    ├── gallery_body.tscn              MOD 019b  + Capsule (capsule_preview)
    ├── unit_parity_gallery.gd         MOD 019b  colisiones visibles
    ├── fount_fx_probe.gd              NUEVO 019c
    ├── fx_gallery.*                   (sin cambio: toma manafount/manalith del catálogo)
    ├── altar_heal.tscn                NUEVO 019d
    ├── rules/altar_heal.tres          NUEVO 019d  mismo script MatchRules, otros números
    ├── mana_probe.gd                  MOD 019d  + línea de vida
    └── rules_suite.gd                 MOD 019d  + caso altar_heal
```

`manafount.tscn` al terminar 019c:

```text
Manafount (StaticBody3D, manafount_body.gd)
├── Visual (BodyVisual, pcfn)
├── Collision
├── ManaSource
├── FreeFx (sprite_emitter.tscn, type = manafount.tres)      %FreeFx, en el tope del modelo
├── ManalithFx (sprite_emitter.tscn, type = manalith.tres)   %ManalithFx, y = 15, emitting off
└── GroundSnap
```

## 4. Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Nuevo/Mod | Por qué no se fusiona |
|---|---|---|---|---|
| `terrain.gd::_smooth_ground_normals` | Iguala la normal de los vértices de suelo que comparten posición (suma ponderada por área); deja las paredes | Función privada + `@export smooth_ground` | Mod | En el exportador obligaría a re-exportar y no se podría comparar en el inspector. Si `terrain.gd` (288 líneas) molesta, sale a un estático `TerrainNormals` |
| `sacrifice_ground.gdshader` | Albedo del suelo: atlas × lightmap | Shader | Mod | Mismo efecto, mismo archivo: solo pasa la posición de mundo por `varying` |
| `bake_bodies.gd` | Malla base y medidas de cada cuerpo **desde el cuadro 0 del idle** (de pie, origen en el suelo, `upright_fix` y `foot_offset` en 0, alto = tope del AABB); la heurística queda solo para cuerpos sin clip y marca `pose_source` | Herramienta | Mod | Es donde nace el dato equivocado |
| `export_stats.py` | Clips por modelo con la clave real y el desplazamiento corregido | Herramienta | Mod | Sin esto Frostwolf queda a 25 m y tres modelos no animan |
| `BodyPoseOverride` | Corrección de **un** modelo: `model`, `rotation_degrees`, `position_offset`, `model_scale`, `capsule_height`, `capsule_radius` (0 = usar horneado), `note` | Resource | Nuevo | Es un tipo de dato editable; no es dato original |
| `BodyPoseOverrides` | La lista y `for_model(tag)` | Resource `.tres` único | Nuevo | Un solo archivo que el TA abre; `BodyCatalog` es estático y necesita una ruta fija |
| `body_catalog.gd` | Horneado + override = pose y medidas finales | Estático `@tool` | Mod | Único lugar que ya lee `rotation_offset/position_offset/model_scale`; deja de leerlos del JSON |
| `body_visual.gd` | Mostrar un modelo; re-aplicar si cambia el `.tres` | Nodo `@tool` | Mod | Escucha `changed` del recurso: el TA ve el ajuste en vivo |
| `audit_body_pose.gd` | Tabla por modelo y `PASS/FAIL` | Script headless | Nuevo | `audit_unit_parity.py` audita clips, no pose; no carga mallas |
| `capsule_preview.gd` + `body_pose_bench.tscn` | Ver cápsula, piso y frente junto al modelo en el editor | Debug `@tool` | Nuevo | No entra al release; el cuerpo real no necesita dibujar su cápsula |
| `SpriteAtlas` | Catálogo `fx.json`, textura, material y quad por `ParticleType` | Estático `@tool` | Nuevo | Segundo caller (ráfaga y emisor); el emisor corre en el editor y `SpriteParticles` no es `@tool` |
| `SpriteParticles` | Ráfaga one-shot que se libera sola | Nodo | Mod | Sigue igual hacia afuera; `FxBus` no cambia |
| `SpriteEmitter` | Emisor **continuo** de un `ParticleType`: `type`, `emitting`, `tint`, `wobble_radius`, `wobble_hz`; avisa si falta `type` o el atlas | Packed `@tool` (CPUParticles3D) | Nuevo | Vive con su dueño y se prende/apaga; la ráfaga nace y muere. Lo reusarán altar y Shrine |
| `ParticleType` | Tipo de partícula | Resource | Mod | Campos nuevos con default que no cambia los 21 `.tres` existentes |
| `manafount.tres` / `manalith.tres` | Números del chorro y de la columna | `.tres` | Nuevo | Otra skin = otro `.tres` |
| `manafount_body.gd` | Estado libre/ocupado: apaga `ManaSource`, alterna `%FreeFx` / `%ManalithFx`, tiñe con el slot del ocupante | Nodo | Mod | Pierde clips y `FxBus`; no pinta partículas, solo conmuta hijos |
| `HealSource` | Cura a los cuerpos del dueño dentro del radio, en el servidor | Nodo componente | Nuevo (opción pedido) | Extender `ManaSource` con un segundo recurso lo vuelve «fuente de dos cosas»; como hijo aparte se apaga sacándolo y lo reusa el Shrine |
| `MatchRules` | Reglas de ronda: `altar_heal_rate`, `altar_heal_radius`, `biome_mode` | Resource | Mod | Números de ronda, no del nodo |
| `match_biome.gd` | Decide qué tema ve **este** proceso y lo aplica; vista previa en editor | Nodo `@tool` | Mod | Ya es el dueño del bioma; `ThemeApplier` sigue siendo el que pinta |

## 5. Resource, nodo, `@export`

- **Resource de tipo:** `BodyPoseOverride(s)`, `ParticleType` (`manafount.tres`, `manalith.tres`), `MatchRules`, `GodTheme` (sin cambios).
- **Nodo:** `SpriteEmitter`, `HealSource`, `MatchBiome`, `Terrain`.
- **`@export` de instancia:** `Terrain.smooth_ground`; `SpriteEmitter.type / emitting / tint / wobble_*`; posición de `%FreeFx` y `%ManalithFx` en `manafount.tscn` (la altura la mueve el TA con el gizmo); `HealSource.kind / rules / rate / radius / owner_slot / target_groups` (mismo contrato que `ManaSource`); `MatchBiome.editor_preview_god` (enum de los 5 dioses + «ninguno», mismo criterio que `Terrain.editor_preview_recenter`: solo editor).
- **`MatchRules`:** `altar_heal_rate := 16.667`, `altar_heal_radius := 50.0` (inventos del port, comentados como tales; ver pregunta 2); `biome_mode: BiomeMode { PLAYER_GOD, MATCH_RANDOM } = PLAYER_GOD`.
- **Valores de partida de los `.tres`** (de [SE], ajustables): `manafount`: atlas `elec` 4×4, `size` 6×6, `energy` 20, `frame_s` 0,0333, `rate_per_s` 240, `lifetime_s` 2,67 con `lifetime_randomness` 1, velocidad 15–25, `spread` 27°, `gravity` 15, `emission_radius` 0,5, `fade_out` on. `manalith`: atlas `fb_g` 3×3, `size` 12×12, `rate_per_s` 240, `lifetime_s` 1,5, velocidad 10–20, `spread` 0, sin gravedad, `emission_radius` 3,5, alfa máx 0,07, `tint` = color del slot.

## 6. Editor, runtime y dedicado

| Pieza | Editor | Cliente / solo | Dedicado |
|---|---|---|---|
| Normales del suelo | Sí (`terrain.gd` es `@tool`) | Sí | Se puede saltear (no dibuja); la colisión no las usa |
| Overrides de pose | Sí, en vivo | Sí | Lee solo medidas (cápsula): **el override de cápsula afecta la simulación**, por eso va en git y es igual para todos |
| Horneado / auditoría | Línea de comandos | — | — |
| `SpriteEmitter` | Sí, emite en la escena abierta | Sí | No crea material ni emite (`BodyCatalog.loads_meshes()` como guarda) |
| Conmutar chorro/columna | — | Local, por `occupy/release` | Corre el estado, sin partículas |
| `HealSource` | — | Apagado en clientes (`set_physics_process(false)`) | Cura; la vida llega por el `MultiplayerSynchronizer` que ya existe |
| `MatchBiome` | Solo `editor_preview_god` (sin `MpKit`: en el editor es `Nil`) | `PLAYER_GOD`: lee `SacrificeFlow.pick_for(local_slot)`, escucha `slot_picks_changed`. `MATCH_RANDOM`: como hoy | `PLAYER_GOD`: no sortea ni envía. `MATCH_RANDOM`: como hoy |

## 7. Riesgos

- **019a** — Arreglar el UV del lightmap cambia el brillo general del suelo (las constantes `0.62 + light * 1.6` se calibraron con el muestreo roto). Por eso va como paso aparte con captura antes/después, y puede necesitar retocar esas dos constantes. Orientación del lightmap (eje V) a confirmar en esa captura.
- **019b** — (1) El frente del modelo posado debería ser +Z por construcción (sacengine mira a +y; `saveObj` escribe (x, z, −y); el horneado espeja Z), así que los giros a mano `[0,90,0]` **no se migran**; se confirma con la flecha del banco y, si alguno falla, va al `.tres`. (2) La corrección de desplazamiento de Frostwolf es aritmética sobre las cabeceras SXSK/SXMD (`crudo = disp·escala`, z × `zfactor`; `correcto = disp·escala·zfactor/alturaRef`): si no cierra, plan B = restar al clip su y mínima cuando supera 1 m, marcado en el JSON. No se edita sacengine. (3) Cambia la cápsula de casi todos los cuerpos (Jadugarr 4,08 → 3,06): cambia alcance de melee (`reach`, `height`) y separación; correr `rules_suite` y los flows de combate. (4) `pcfn` pierde su giro a mano al re-hornear: pasa a `pose_overrides.tres` si hace falta. (5) Un recurso estático cargado por `BodyCatalog`: en el editor hay que reconectar `changed` tras `refresh()`.
- **019c** — (1) `manafount_path` tiene que llegar a los clientes para que `occupy()` corra ahí; si el spawn no lo lleva, se agrega al estado de spawn de la estructura (una propiedad, sin RPC nuevo). (2) 240 partículas/s × 2,67 s × 5 manantiales de 6 m con mezcla aditiva: costo de fill-rate; `rate_per_s` es el knob. (3) Un `CPUParticles3D` no reproduce la vida cuadrática del original: es aproximación visual, no regla.
- **019d** — Desvío de sacengine si se elige la opción pedido; queda en un número que vale 0 para volver al original.
- **019e** — (1) Dos jugadores ven mundos distintos: la niebla (`fog_end`, densidad) cambia cuánto se ve a lo lejos; es visual pero da una diferencia leve de lectura. (2) En el editor `ThemeApplier.apply` escribe en el `Environment` y en `Sun` de la escena: hay que restaurar en `NOTIFICATION_EDITOR_PRE_SAVE` y re-aplicar en `POST_SAVE` (patrón de `terrain.gd`), y comprobar `git diff` vacío. (3) El pick puede llegar después de `mundo listo`: re-aplicar en `slot_picks_changed`.

**Fuera de alcance:** partículas del altar y del Shrine (reusarán `SpriteEmitter`, otro corte); sonido en loop del manantial (`tnof`); modelos de altar/manantial/vegetación por dios (no hay dato exportado); cajas de colisión desde huesos como sacengine; hornear los cuadros de clip a `.res` (hoy se parsean OBJ en runtime); los 53 cuerpos que no están en el roster (quedan con la heurística, listados por la auditoría); recalibrar la luz del suelo más allá del UV; NPC y poblados (018c).

## 8. Conflictos con RFC-017 y RFC-018, y paralelismo

| Corte | Archivos compartidos | Con quién | Qué hacer |
|---|---|---|---|
| 019a | ninguno (`terrain.gd`, shader) | 018e mueve el nodo `Terrain` de escena, no el script | Libre |
| 019b | `unit_body.gd` no se toca; `body_visual.gd` / `body_catalog.gd` | 018c los **usa** (NPC), no los edita; 017b toca una línea de `unit_body.gd` | Libre. Conviene antes de 018c: los NPC nacen ya bien parados |
| 019c | `props/manafount.tscn` | 018d agrega máscaras de vegetación cerca de los manantiales | No en paralelo con 018d sobre ese archivo: 019c primero |
| 019d | `props/altar.tscn`, `player_start.gd`, `match_rules.gd/.tres` | **017a** (script `altar.gd`, `Visuals`, socket `mana_source`); 017b y 019e en `match_rules` | **Después de 017a**: `Altar` propaga `owner_slot` y apaga `HealSource` al destruirse, igual que `ManaSource` |
| 019e | `match_biome.gd`, `match_rules.gd/.tres`; `high_noon.tscn` solo si se guarda un `editor_preview_god` | 018e cambia la ruta del terreno en `theme_applier.gd` (019e no lo edita); 017a agrega `%Match` a `high_noon.tscn` | Antes de 018e. No en paralelo con 019d por `match_rules` |

**En paralelo sin tocarse:** 019a ∥ 019b ∥ 019c (tres desarrolladores, cero archivos comunes). 019e puede ir con ellos. 019d va solo, después de 017a.

**Orden recomendado entre todos:** 019a + 019b + 019c ahora (son lo que el usuario vio roto y no dependen de nada) → 019e → 017a → 019d → 018c → 018d → 017b → 018e.

## 9. Orden de implementación

**019a**
1. `terrain.gd`: tras leer el `.bin`, por cada triángulo que no es pared (`_flat_cross` ya lo distingue) sumar su producto cruz sin normalizar, orientado hacia arriba, en un diccionario por posición; segunda pasada: escribir la suma normalizada en los vértices de suelo. `@export var smooth_ground := true` con setter que rehace la malla.
2. `debug/terrain_normals_probe.gd`.
3. (Pregunta 1) shader: `varying vec3 world_pos` en `vertex()` y usarlo para `light_uv`; captura antes/después; retocar constantes si hace falta.

**019b**
1. `tools/audit_body_pose.gd` (punto de partida: 26 fallas).
2. `export_stats.py`: clave con el tag real; corrección de desplazamiento; re-exportar los clips afectados.
3. `bake_bodies.gd`: base desde el cuadro 0 del idle (tag de `creatures.json` / `wizards.json`); sin `FORCE_*` para esos modelos; re-hornear.
4. `BodyPoseOverride(s)` + `data/bodies/pose_overrides.tres` vacío; `body_catalog.gd` lo aplica y deja de leer esas claves del JSON; `body_visual.gd` escucha `changed`.
5. `capsule_preview.gd`, `gallery_body.tscn`, `body_pose_bench.tscn`; colisiones visibles en `unit_parity_gallery`.
6. Auditoría en `PASS`; lo que quede, al `.tres`. `rules_suite` + flows de combate.

**019c**
1. `export_particles.py`: `elec`, `fb_g`, entradas `manafount` y `manalith`; correrlo.
2. `sprite_atlas.gd` (extraer de `sprite_particles.gd`); `fx_gallery` sigue igual.
3. `particle_type.gd` + `sprite_emitter.gd/.tscn`; `manafount.tres`, `manalith.tres`.
4. `manafount.tscn`: `%FreeFx`, `%ManalithFx`; quitar `ClipPose`. `manafount_body.gd`: conmutar en `_set_active`, teñir con el slot del ocupante; borrar clips, `fx_name`, `fx_interval_s` y la llamada a `FxBus`.
5. Confirmar `manafount_path` en clientes. `fount_fx_probe.gd`.

**019d** (tras la pregunta 2 y 017a)
1. `heal_source.gd`; campos en `MatchRules`.
2. `altar.tscn` + propagación de `owner_slot`.
3. `debug/altar_heal.tscn`, regla debug, `mana_probe.gd`, caso en `rules_suite`.

**019e**
1. `MatchRules.biome_mode`.
2. `match_biome.gd`: rama `PLAYER_GOD` (pick local, `slot_picks_changed`, sin sorteo ni envío); la rama actual queda para `MATCH_RANDOM` y para `biome_god` forzado.
3. `@tool` + `editor_preview_god` con restauración en el guardado.
4. Flows: solo con cada dios; dedicado + 2 clientes con dioses distintos.

## 10. Cómo verifica un humano

1. **019a:** abrir `scenes/world/high_noon.tscn`, encuadrar `Terrain` con F. El relieve se ve continuo; los acantilados siguen con borde neto. Destildar `smooth_ground`: vuelven las facetas. F6 y caminar con `move_forward`.
2. **019b:** abrir `debug/body_pose_bench.tscn`. Trogg de pie, dentro de la cápsula, pies en el piso, mirando la flecha. Cambiar `model` a `maho`, `jnwr`, `gobl`. Abrir `data/bodies/pose_overrides.tres`, agregar una entrada para `eorc` con `position_offset.y = 1`: el modelo sube en el momento. Deshacer. F6 en `debug/unit_parity_gallery.tscn`, `debug_anim_cycle`: nadie se acuesta ni flota al cambiar de clip.
3. **019c:** abrir `scenes/world/props/manafount.tscn`: el chorro corre en el editor. Seleccionar `FreeFx`: cambiar `rate_per_s` o `size` en `manafount.tres` se ve en vivo. Tildar `emitting` en `ManalithFx` para ver la columna. F6 en `debug/structure_siege.tscn`: Manalith con `spell_1` → se apaga el chorro y sube la columna del color del jugador.
4. **019d:** F6 en `debug/altar_heal.tscn`: lejos, la vida no sube; al entrar al radio sube ≈16,7/s. Poner `altar_heal_rate = 0` en la regla: no sube.
5. **019e:** F5, elegir Pyro, Jugar solo: cielo y suelo de Pyro. En `high_noon.tscn`, seleccionar `MatchBiome` y elegir `editor_preview_god = charnel`: el editor cambia; Ctrl+S y `git diff -- game/scenes/world/high_noon.tscn` solo muestra esa línea (o nada si se vuelve a «ninguno»).
6. Correr los comandos headless de la sección 2.

## 11. Preguntas abiertas

1. **¿019a incluye arreglar el muestreo del lightmap?** (no bloquea el suavizado). Es una línea en el mismo shader y hace al mismo síntoma («el suelo se ve duro»), pero cambia el brillo y puede pedir recalibrar. **Recomendación: sí, como paso 3 separado y con captura**; si el resultado no convence se revierte sin tocar el paso 1.
2. **¿El altar cura de forma directa?** (bloquea 019d). sacengine dice que no (`state.d:14400-14409`, `28578-28593`, `8828-8832`): da maná, y la vida sale de la regeneración por maná y de la conversión maná→vida del fantasma, que el port ya tiene. No corrí Ghidra porque las tres rutas de sacengine coinciden; si se quiere certeza sobre el ejecutable, es una consulta acotada (buscar quién llama a la cura cerca de un altar), con el método de `.studio/RESEARCH-doctors.md`.
   - **Opción fiel:** no se toca nada; se anota en `FEATURES.md`.
   - **Opción pedido:** `HealSource` en el altar, `altar_heal_rate = 16,667` vida/s (invento del port; el número es el que sacengine usa para curar a un guardián de edificio, `state.d:14406`, y coincide con la regeneración del mago a maná lleno), radio 50, mago y criaturas del dueño, no fantasma.
   - **Recomendación: opción pedido**, porque lo pidió después de jugar y queda en un número que en 0 devuelve el original; se deja escrito en `FEATURES.md` como desvío de sacengine.
3. **¿Bioma por jugador o uno para todos?** (bloquea 019e). (1) cada cliente ve el de su dios; (2) manda el slot 1; (3) sorteo. **Recomendación: (1) por defecto y (3) como `biome_mode = MATCH_RANDOM`.** (2) ignora la elección del segundo jugador, que es justo lo pedido. Costo de (1): cada jugador ve otro cielo y otra niebla.
4. **¿Dónde vive la corrección de modelos?** (no bloquea). **Recomendación:** un solo `data/bodies/pose_overrides.tres`. Alternativa «menos piezas»: sin Resource, solo arreglar el horneado (alcanza para los 26 casos medidos, pero el TA vuelve a no tener dónde tocar).

¿Está bien el corte, o más/menos piezas? «Menos»: sin `SpriteAtlas` (marcar `sprite_particles.gd` como `@tool`), sin `capsule_preview` (usar «Visible Collision Shapes»). «Más»: `TerrainNormals` estático aparte; emisor del Manalith en `structure.tscn` en vez de en el manantial.

## 12. Decisiones del usuario (2026-10-13)

- Árbol aprobado, con el arreglo del muestreo del lightmap dentro de 019a (pregunta 1: sí).
- Orden: primero 019b (modelos SAXS) y todo lo de sacrificios (RFC-020, ritual fiel de Convert y Desecrate); después 019a y 019c.
- Pregunta 2 (altar): **fiel al original**. El altar no cura de forma directa. 019d queda reducido a documentarlo en `FEATURES.md`; no se crea `HealSource`.
- Pregunta 3 (bioma): **sorteo como hoy**. 019e no se implementa; el bioma lo sigue sorteando el servidor.
- Pregunta 4: se sigue la recomendación (`data/bodies/pose_overrides.tres`).
- Subagentes: Sonnet 5.5 para todos los roles, Opus 5.5 solo para el tech lead.
