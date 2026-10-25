# 055s — Sockets y el cuerpo como escena (plan del tech lead, pendiente de aprobación)

> **Aprobado por el usuario (2026-10-25)** con todas las recomendaciones: escena del cuerpo compuesta (no heredada de unit.tscn; RFC-055 §15 queda corregido por esta decisión); apariencia detrás de un InstancePlaceholder más `DedicatedStrip` en el export; objetivo del dedicado exportado ≤3,0 s / ≤380 MB (o lo que mida s0 si es mejor); `CreatureType.icon` se queda; materiales guardados en modelo y props; los props entran (s5a); los 74 modelos se renombran (s6) antes de 055a-5; el cable conserva `model`; la mano visible como pista con RESET; regla C23; valores que el .tscn no conserve exactos como `@export_storage` double. Los cortes se implementan sin Godot; s0 (sondas) lo corre el orquestador.

Fuente: RFC-055 §13.2 (filas «Muerte por Tween» y «Lecturas del original en runtime»), §13.2b **C-5** y **C-8e**, §15 («055s: `BodySockets` con `Marker3D`, `BoneAttachment3D` + `Muzzle`, transform del modelo y `CollisionShape3D` en vez de `BodySize`/`pose_overrides`, cápsula guardada») y §16 (055a-5 va después). Auditorías `research/055R-legacy-audit.md` §3.4, §3.5 y fila «Animación», y `research/055R-editor-gizmo-audit.md` ítems 1–4. Lo que dejaron los planes `055c1-creatures-plan.md` (§16: `hands`, la escena por criatura, `model: String`), `055o-audio-plan.md` (decisión del usuario: si el servidor carga demasiado audio, `CreatureType.sounds` se muda a la escena de la criatura) y `055i-a-identity-plan.md` (`wizard_preview` y `model` en el pick hasta 055s). Medido en `main` = `41177a0a` (2026-10-25). Las rutas son relativas a `game/`. No se escribió código ni se corrió Godot.

**Contradicciones entre artefactos (gana lo que se cita):**
- **¿Escena heredada o compuesta?** RFC-055 §15 pide «una escena **heredada** por criatura, obligatoria (`trogg.tscn` hereda `unit.tscn`)». Tres cosas lo chocan: (1) los magos salen de `MpSlotSpawner` con el auto-spawn de `MultiplayerSpawner`, que manda el índice de la escena en el cable (`addons/mp_kit/mp_slot_spawner.gd:18-20,55`): 15 escenas de mago cambian esos bytes; (2) `unit.tscn` tiene unos 110 nodos y una escena heredada los muestra todos en gris, y eso no es lo que un humano quiere abrir para mover una mano; (3) la skill de composición y CONVENTIONS ponen la composición primero. **Gana el RFC salvo que el usuario diga otra cosa.** Este plan propone la variante compuesta (pregunta 1): una escena chica por criatura y por mago (`BodyFrame`) que el cuerpo instancia según su tipo. En §5.4 está lo que cambia si se elige la heredada.
- **El RFC dice «`Marker3D` en `models/<x>.tscn`»** (055R-editor-gizmo-audit ítem 1). El dedicado no carga los modelos (`body_rig.gd:47`) y la simulación necesita alturas y alcances. Los sockets que lee la simulación van en la escena del cuerpo, que sí carga el servidor. Los que siguen a un hueso (manos, llama del Manahoar, aguja del doctor) van en el modelo, que es solo presentación. Gana el criterio de la simulación, que es la regla de determinismo del RFC (§13.2b C-3, «mantener»).
- **`deploy/README.md` está desactualizado:** dice que el preset es `dedicated_server=false`, pero desde `3626fb2e` es `true` (`export_presets.cfg:7`). Se corrige en s4.

---

## 1. Objetivo (criterios del RFC, sin extras)
- Toda posición y tamaño de un cuerpo es un nodo de una escena que se arrastra con el gizmo: cápsula y huella (`CollisionShape3D`), alcance y puntos de enganche (`Marker3D`), manos y aguja (`BoneAttachment3D`). Se borran `data/catalog/body_sizes/` (396 `.tres`), `data/bodies/pose_overrides.tres`, `BodyCatalog`, `BodySize`, `BodyPoseOverride(s)` y los `hands` de `BodyModel.clips`. **C19 327 → 6** y **C16 39 → 30**.
- **Una escena por criatura y por mago:** `scenes/units/bodies/<nombre>.tscn` y `scenes/wizards/bodies/<nombre>.tscn`, cada una con su apariencia (`<nombre>_look.tscn`) detrás de un `InstancePlaceholder`. Un humano edita una criatura abriendo **su** escena. `CreatureType.model`/`WizardType.model` (texto) pasan a `body: PackedScene`.
- **Presentación fuera del servidor.** El dedicado y el servidor de salas no cargan sonidos, modelos ni pistas de animación: los sonidos y el modelo de cada criatura y mago viven en su apariencia, que solo crea el cliente. El audio y las pistas de hueso que quedan colgando de datos del servidor (`GodType.look`, consejero, FX, bibliotecas de clips) se quitan del build dedicado con un `EditorExportPlugin`, el mismo mecanismo que Godot usa para las mallas y las texturas. **Build dedicado exportado: ≤ 3,0 s y ≤ 380 MB** (hoy 4,2 s y 416 MB; antes de la v2, 2,5 s y 353 MB).
- **`original_material` horneado:** los materiales quedan guardados en las escenas de modelo y en las mallas de los props. Se borra `original_material.gd`; **C13 9 → 6**.
- **La simulación y el cable no cambian:** los 28 digests de `agent/run_determinism.sh quick` son idénticos a `agent/det_baseline.txt`, y el diff de `run_034m`/`run_049e` sale vacío (§8, §9).
- Queda listo lo que necesita 055a-5 (§14).

## 2. Escena de prueba
**No hay escena debug nueva** (como en 061a y 055c1: el usuario borra `debug/` al final). El criterio arranca en escenas reales:
- **Editor:** `scenes/units/bodies/trogg.tscn`.
  - Antes: no existe. El trogg es `unit.tscn` + `model = "eorc"` (texto) + `data/catalog/body_sizes/eorc.tres` (números) + `BodyCollider` (constantes).
  - Después: el viewport muestra el modelo (el `Look`, que el editor dibuja aunque sea placeholder), la cápsula con sus manijas, la huella y los marcadores `Reach`, `Center` y `Top`. Con F6 la escena se ve sola (`BodyFrame` crea su `Look` cuando es la raíz).
  - Lo que **no** está todavía (resultado del criterio): la escena entera.
- **Editor:** `scenes/wizards/bodies/jadugarr.tscn` → `Sockets/Muzzle` a la altura de la mano. `scenes/bodies/models/jnwr.tscn` → `Model/Skeleton3D/HandL` y `HandR`, y en `Clips` › `cast` la pista `HandL:visible = true`.
- **Headless, ya existentes:** `rules_suite`, `debug/suite/catalog_cases.gd`, `debug/suite/clip_facts_cases.gd`, `debug/units/custom_creature.tscn`, `debug/net/late_join.tscn`, `agent/run_determinism.sh quick`, `agent/runs/run_034m.sh`, `agent/runs/run_049e.sh` y `agent/runs/run_audio_cases.sh`.
- **Sondas nuevas** (casos de `rules_suite` o `--script`, se borran con `debug/`): `body_facts_cases`, `presentation_refs_cases`, `clip_strip_cases`, `wire_config_cases` y `prop_facts_cases` (§12).
- **Capturas** (solo el orquestador abre ventana, una por vez): `agent/harness/clip_shots` (74 modelos con cámara fija) y `match_shots` en High Noon.
- **Medición del build:** `agent/runs/run_055s_dedicated_cost.sh` (nuevo, §12).
- Acciones del InputMap: ninguna. Es datos, escenas y build; la partida se prueba con el banco y las corridas de red.

---

## 3. Inventario (en `41177a0a`)

### 3.1 Conteos del lint
| Regla | Hoy | En el alcance |
|---|---|---|
| C1a / C1b | **100** / 21 | `body_catalog.gd` 189, `body_model.gd` 209, `body_rig.gd` 288, `body_visual.gd` 154; tocados sin partir: `unit_body.gd` 785, `wizard_body.gd` 570, `doctor_body.gd` 414 (no pueden crecer) |
| C9 | **292** | `scenes/bodies/` 6 |
| C13 | 9 | `body_catalog.gd:123`, `original_material.gd:37,86` (3) |
| C15 | 39 | `original_material.gd:58` (1) |
| C16 | 39 | 9 de cuerpo (§3.4) |
| C18 | **35** | 23 son `BodyCatalog.info/pose/has_model` (§3.4) |
| C19 | 327 | 320 en `data/catalog/body_sizes/` (16 cuerpos + 304 props con `foot_offset`/`*_offset`) + `data/bodies/pose_overrides.tres` |
| C8 / C18b / C18c / C21 / C22 | 7 / 5 / 0 / 5 / 3 | no pueden subir |

### 3.2 Dónde viven hoy los números de un cuerpo
- **`data/catalog/body_sizes/<tag>.tres`** (`BodySize`, `body_size.gd`): 396 archivos, 85 cuerpos y 311 props. Guardan `box`, `foot_offset`, `height`, `radius`, `reach`, `upright_fix` y `pose_source`. Los horneó `bake_catalog.gd`, los escribe para criaturas propias `new_creature.gd:417-424` (reach = media del lado largo de la caja) y para props `tools/import/import_props.py:352-354`. **Todas las medidas de cuerpo tienen como mucho 3 decimales (mm)**: verificado en los 85.
- **`data/bodies/pose_overrides.tres`** (`BodyPoseOverride`): 15 correcciones a mano (giro, `position_offset`, `capsule_height`, `capsule_height_flying`, `capsule_radius`, `reach`). Ninguna usa `model_scale` ≠ 1.
- **`BodyCatalog.info(model)`** (`body_catalog.gd:72-93`) suma las dos cosas. `pose()` (`:155-171`) arma el transform del modelo.
- **Tres escritores de la cápsula** (viola «un dueño por estado»): `units/movement/body_collider.gd:45-68` (`MIN_HEIGHT 0.6`, `RADIUS_PER_HEIGHT 0.45`), `wizards/wizard_body.gd:243-252` (`_fit_shape`, la misma regla copiada) y `sacrifice/doctor_body.gd:340-343`.
  - **11 cuerpos quedan recortados** por `RADIUS_PER_HEIGHT`: bala, baby, buga, bugf, bugl, ddiz, eclw, estm, sirc, spdr y stmp. En todos ellos el radio crudo sigue mandando para la formación (`unit_orders.gd:254`).
  - En los 85, `reach ≥ radius`, así que `half_size = max(radius, reach) = reach`.
- **Manos:** `BodyModel.clips[tag].hands` (`body_model.gd:57-60`, `:154-155`), aplicadas por clip en `body_rig.gd:270-283`. Medido sobre los 74 modelos:
  - 51 tienen alguna mano encendida;
  - **50 usan un solo hueso y un solo offset en todos sus clips** (solo `bugf` tiene dos juegos);
  - en los 15 magos, la mano se enciende solo en `cast` y `cast_run` (`jw s2`/`r2`, `he s2`/`r2`).
  - Lo único que lee las manos es `HandFx` (partículas de lanzamiento, presentación).

### 3.3 Qué lee la simulación (cambia el digest si se mueve un bit)
| Archivo:línea | Lee | Socket nuevo |
|---|---|---|
| `units/unit_body.gd:283,528` (`melee_profile`, `_setup_melee`) · `units/attacks/melee_attack.gd:199` · `units/status/clinging.gd:171-178` (vía `melee_profile`) | `reach`, `height` | `Reach`, `Bounds/Capsule` |
| `bodies/body_box.gd:11,16` → `units/movement/body_avoidance.gd:81,84`, `melee_attack.gd:100-105`, `look/grass/grass_trample.gd:122`, `units/passives/fire_shield.gd:107-130`, `ui/hover_frame/hover_frame_rules.gd:47` | `max(radius, reach)`, `height` | `Footprint`, `Reach`, `Capsule` |
| `orders/orders.gd:309` (`_half_size`) · `units/unit_orders.gd:254` (radio crudo) | `radius`, `reach` | `Footprint`, `Reach` |
| `units/movement/body_collider.gd:48` · `wizard_body.gd:243-252` · `doctor_body.gd:269,340-343` | `height`, `height_flying`, `radius` (recortado) | `Capsule`, `FlyingCapsule` |
| `spells/actions/aimed_action.gd:14,55-63` (`HAND_HEIGHT 0.65`: de dónde sale la bola del mago) | `height`·0,65 y `reach` | `Muzzle` |
| `units/unit_body.gd:724-731` (`soul_anchor`, donde nace el alma) | `height`·0,5 y `radius` | `Center`, `Footprint` |
| `spells/rock_projectile.gd:147` (frente de la roca, un prop) | `reach` del prop | `@export front_m` de la roca (s5) |

**Solo presentación:** `aimed_action`/`lightning_action.gd:26-30` («Presentation only»), `teleport_action.gd:69,143,166`, `captive.gd:273` (portal), `orders/selection.gd:358`, `fx/damage_numbers.gd:198`, `bodies/hand_fx.gd:64`, `units/unit_body.gd:519` (barra de vida) y `ui/character_select/wizard_preview.gd:41-48`.

### 3.4 Las líneas del lint que este corte baja
- **C16 (9):** `bodies/hand_fx.gd:64`, `fx/damage_numbers.gd:198`, `orders/selection.gd:358`, `spells/actions/aimed_action.gd:14`, `spells/actions/lightning_action.gd:27`, `spells/actions/teleport_action.gd:143,166`, `units/movement/body_collider.gd:20,22`.
- **Quedan en C16 con su dueño:**
  - 055e (proyectiles): `fireball`, `rock`, `swarm`, `wrath`.
  - 055g (ritual): `ritual_fx` ×3 y `captive.gd:179`.
  - 055x (FX en sockets): `rockform`, `timed_state_ability`, `firewalking` ×2, `frozen`, `petrified` y `pull_thread`, que leerán los sockets de este corte.
  - 055x/055r: `altar_collapse`, `soul.gd` ×2 y `soul_strike`. `guardian_bond:30` y `guardian_tether:162` son un 0,9 fijo que lee la regla del lazo: cambiarlo por el `Center` de cada criatura cambia la simulación, así que quedan para 055r.
  - 055k: `world_camera`.
  - 055c: `clinging`, `pulling`.
  - Son falsos positivos del patrón (055z): `grass_field` (texels), `mesh_planter` (celda) y `ground_ray` (largo del rayo).
- **C18 (23):** `body_box.gd:11,16` · `body_visual.gd:93,99,103,115` · `look/vegetation/mesh_planter.gd:138` · `orders/orders.gd:309` · `sacrifice/doctor_body.gd:269` · `spells/actions/aimed_action.gd:61` · `lightning_action.gd:26` · `teleport_action.gd:69` · `spells/rock_projectile.gd:147` · `structures/building_fit.gd:20,24` · `ui/character_select/wizard_preview.gd:47,48` · `units/attacks/melee_attack.gd:199` · `units/captive.gd:273` · `units/movement/body_collider.gd:48` · `units/unit_body.gd:283,528` · `units/unit_orders.gd:254`.
- **Lecturas por texto que el lint no cuenta:**
  - `BodyModel.exists/scene_path(model)` (`body_model.gd:65-71`) y `body_rig.gd:221-226` (`load` de la escena del modelo armada con su tag);
  - `BodyCatalog.mesh(model)`: `body_visual.gd:117`, `units/abilities/rockform.gd:42`, `units/attacks/ranged_shot.gd:75`, `spells/rock_projectile.gd:78`, `spells/zones/debris_piece.gd:34`, `spells/zones/snowball_flight.gd:36`, `spells/carrier/prop_look.gd:21`, `look/vegetation/mesh_planter.gd:121`, `vegetation_patch.gd:105`;
  - `map/npc_spawn.gd:75` (vista previa por `creature.model`), `structures/building_type.gd:53`, `map/props/manafount_body.gd:62`.

### 3.5 Presentación que hoy carga el servidor
| Referencia | Qué trae | Medido |
|---|---|---|
| `CreatureType.sounds` (`creature_type.gd:16`) | 67 `SoundSet` | 24,8 MB de archivos en `data/audio/creatures/` |
| `CreatureType.carried_fx` (`:18`) | la escena de la llama del Manahoar | — |
| `CreatureType.icon` (`:13`) | `Texture2D` | el export dedicado ya la cambia por un placeholder (`3626fb2e`) |
| `WizardType.sounds` (`wizard_type.gd:23`) | 15 `SoundSet` | 6,5 MB |
| `GodType.look` (`god_type.gd:15`) → `LookProfile` | cielo y suelo (texturas, ya placeholders), **música y ambiente** (desde `959336c0`) | unos 26 MB de música (055o §6) |
| `CreatureType.clips` / `WizardType.clips` (`:10`, `:9`) | 85 bibliotecas con las pistas de hueso | unos 46 MB y 770 ms (c1-0, aprobado) |
| `match.tscn`: `AdvisorVoice` (`:492`), `CommandVoice`, `MusicDirector`… · `core/boot.tscn` (`MusicDirector.music = menu`), que también arranca el servidor de salas (`core/boot.gd:18`) | streams del consejero, de la UI y del menú | — |

El modo dedicado de Godot ya cambia mallas y texturas por placeholders, pero **no** el audio ni las pistas de `Animation` (`3626fb2e`). Por eso hoy: 4,2 s y 416 MB contra 2,5 s y 353 MB antes de la v2.

### 3.6 Material del original en runtime
- `bodies/original_material.gd`: parsea `textures/index.json` en cada arranque (`:86`), arma rutas al original (`:37`) y crea un `StandardMaterial3D` (`:58`).
- Lo llaman `bodies/body_model.gd:186` (`apply_to` en cada modelo instanciado, con `surface_parts`) y `body_catalog.gd:123,138` (props).
- Los `.glb` no traen materiales: lo dice el comentario de `apply_to`, y `_subresources={}` en `assets/original/models/eorc.glb.import`.

---

## 4. Diseño

### 4.1 Tres piezas por cuerpo: tipo, escena del cuerpo y apariencia
| Pieza | Qué es | Lo carga | Archivo |
|---|---|---|---|
| **Tipo** (`CreatureType`, `WizardType`) | reglas: vida, velocidad, habilidades, clips (tiempos) | todos | `data/catalog/creatures/trogg.tres` |
| **Escena del cuerpo** (`BodyFrame`) | tamaño y sockets que lee la simulación; el id de red del modelo | todos (es chica: formas, marcadores y un placeholder) | `scenes/units/bodies/trogg.tscn` |
| **Apariencia** (`BodyLook`) | modelo o malla, sonidos, la llama que lleva, manos | **solo el cliente** (`InstancePlaceholder` dentro de la escena del cuerpo) | `scenes/units/bodies/trogg_look.tscn` |

- **`CreatureType.body: PackedScene` y `WizardType.body: PackedScene`** reemplazan `model: String`. La escena del cuerpo **no** apunta a su tipo, para no armar el ciclo `.tres ↔ .tscn` (riesgo 9 de 055c1). La variante «trogg de élite» comparte `body`.
- **`BodyMount`** (nodo hijo de `unit.tscn`, `wizard_body.tscn` y `doctor.tscn`) es **el único dueño** de «qué cuerpo viste este cuerpo»:
  - `wear(scene)` es idempotente: con la misma escena no hace nada.
  - Instancia la escena del cuerpo como hijo `Frame`, guarda `facts := BodyFacts.of(scene)` y emite `worn(frame)`.
  - En el cliente monta la apariencia dentro de `Tilt/Mesh/Rig` (`BodyRig.mount(frame.look)`: `create_instance` del placeholder y lo pasa al `ModelSlot`).
  - `UnitBody` lo llama desde el setter de `type` (el spawner pone el tipo antes de `add_child`, en cada par y en el late join). `WizardBody` lo llama al aplicar el pick. `DoctorBody`, desde su `type`.
  - Así `unit_body.gd`/`wizard_body.gd` no crecen: C1b no sube.
- **`BodyCollider`** pasa a ser el único escritor de la cápsula de los tres cuerpos:
  - escucha `BodyMount.worn` y `Flight.state_changed`;
  - copia `Capsule` (o `FlyingCapsule` en vuelo) a su `Collision`;
  - se borran `_fit_shape` (`wizard_body.gd:243-252`), las líneas `doctor_body.gd:340-343` y las constantes `MIN_HEIGHT`/`RADIUS_PER_HEIGHT`. El migrador ya aplicó el recorte al guardar la cápsula; `new_creature` lo aplica al medir.

### 4.2 Lo que lee la simulación: `BodyFacts` (como `ClipFacts`)
`scenes/bodies/body_facts.gd` (`RefCounted`, ≤ 100 líneas) se calcula **una vez por escena de cuerpo**, con un caché estático `Dictionary[PackedScene, BodyFacts]`. Instancia la escena una vez, lee sus formas y la libera.

| API | De dónde sale | Cómo queda exacto |
|---|---|---|
| `height_m`, `flying_height_m`, `radius_m` (crudo), `reach_m` | `Capsule.height`, `FlyingCapsule.height`, `Footprint.radius`, `Reach.position.z` | Las formas guardan `float` de 32 bits. Todas las medidas de hoy son milímetros exactos (§3.2), así que se decodifican con `roundi(v * 1000.0) / 1000.0`. Una división de un entero por `1000.0` redondea igual que el parser del `.tres`: da **el mismo double** que hoy |
| `half_size_m()` | `maxf(radius_m, reach_m)` | idéntico a `BodyBox.half_size` |
| `muzzle: Vector3`, `center: Vector3`, `top: Vector3`, `feet: Vector3` | `position` **local** de los `Marker3D` | La simulación nunca usa `global_position` (la rotación en float32 movería bits). Usa la misma cuenta de hoy con los valores locales: `pos + Vector3(0, muzzle.y, 0) + facing * muzzle.z`. El migrador escribe `muzzle.y = (Vector3.UP * h * 0.65).y` y `muzzle.z = reach` **calculados por Godot** (float32), que es lo que hoy produce `Vector3.UP * h * HAND_HEIGHT` y `facing * reach`. `center.y = h * 0,5` es exacto en mm |
| `capsule_radius` | `Capsule.radius` | solo lo usa la cápsula de física, que ya es float32 hoy |

- Cada cuerpo guarda `body_facts` cuando lo viste (`BodyMount`). `BodyBox` lee `body.body_facts` y nunca carga nada.
- **Nada por cuadro llama a `load()`, `find()` ni `BodyFacts.of()`.**
- La paridad se prueba antes de borrar `BodyCatalog`: `body_facts_cases` compara bit a bit (`==` y `var_to_bytes`) `BodyCatalog.info` y la cuenta de `hand_origin` de hoy contra `BodyFacts` para las 87 escenas de cuerpo. Tiene que dar `BODY FACTS bodies=87 equal=87 differ=0`.

### 4.3 Las manos, la llama y la aguja: `BoneAttachment3D` en el modelo
- **Cada `scenes/bodies/models/<modelo>.tscn` guarda `Model/Skeleton3D/HandL` y `HandR`** (`BoneAttachment3D`, hueso fijo) con un hijo `Socket` (`Marker3D` en el offset). Es el mismo patrón que el `Ragdoll`, que ya vive bajo `Model/Skeleton3D`.
  - El migrador los escribe desde `BodyModel.clips[*].hands`. En 50 de 51 modelos hay un solo juego.
  - En `bugf` (dos juegos) el segundo juego es `HandL2`, con su propia pista.
- **Cuándo hay mano:** una pista `Skeleton3D/HandL:visible` dentro de cada `Animation` de rol de la biblioteca: `true` en los roles cuya mano estaba encendida y `false` en `RESET`.
  - El `AnimationTree` es determinista desde 4.2: los roles sin pista vuelven al valor de `RESET` (NO VERIFICADO en 4.7; se prueba en s0).
  - `BodyRig.hand_points()` lee los `Socket` visibles del modelo montado. Se borran `HandL`/`HandR` de `body_rig.tscn`, `_bind_hands` y `_apply_hands`.
- **`BodyModel.carried_fx_socket`** ya existe y queda. La aguja del doctor es `HandR/Socket` de `sacd.tscn` (lo que pide 055a-5).

### 4.4 Presentación fuera del servidor: tres mecanismos de Godot, cada uno en su lugar
1. **`InstancePlaceholder` en la escena del cuerpo (estructura).**
   - El nodo `Look` de `trogg.tscn` está marcado «Cargar como placeholder». El editor lo dibuja entero; en ejecución es un `InstancePlaceholder` con la ruta de la apariencia, y solo el cliente llama a `create_instance()`.
   - Ahí viven `sounds` (sale de `CreatureType.sounds` y `WizardType.sounds`), `carried_fx` (sale de `CreatureType.carried_fx`) y el modelo con sus manos.
   - Vale también en las corridas desde el proyecto (`--dedicated`, banco, `run_034m`).
   - Regla: **nada de la apariencia se pisa desde `trogg.tscn`.** Un override en el placeholder sería un `ext_resource` de la escena del cuerpo y la cargaría el servidor. `BodyFrame` avisa en el inspector y `presentation_refs_cases` lo prueba.
2. **Modo dedicado de Godot (ya activo):** mallas y texturas como placeholders. Cubre `CreatureType.icon` (pregunta 4), las texturas del `LookProfile` y el HUD.
3. **`DedicatedStrip`** (`addons/sacrifice_tools/dedicated_strip.gd`, un `EditorExportPlugin` que solo corre en el editor al exportar). Con el feature `dedicated_server`, `_customize_resource` cambia:
   - todo `AudioStream` por un `AudioStreamWAV` vacío, para que las referencias tipadas sigan válidas y `AudioGate` siga cerrado;
   - toda `Animation` de `scenes/bodies/models/*_clips/` por una copia con `length`, `step`, `loop_mode` y **marcadores**, sin pistas.

   Así quedan cubiertos `GodType.look` → música y ambiente, el consejero, los cues de FX y de la UI, y las pistas de hueso de las bibliotecas que `ClipFacts` no lee (`clip_facts.gd:77-82` lee solo `length`, `step` y marcadores). Es el mismo mecanismo con el que Godot quita las mallas en su propio `DedicatedServerExportPlugin`. La partición estructural de `match.tscn` (una rama de presentación como placeholder) queda para un corte posterior **si** la medida no alcanza (pregunta 2).

### 4.5 Props y materiales
- **Materiales horneados** (s3): `tools/bake/bake_materials_055s.gd` (es una herramienta; puede leer el original) escribe un `StandardMaterial3D` por textura y cutout en `scenes/bodies/materials/<archivo>.tres`, con los mismos `ROUGHNESS 0.85` y `ALPHA_SCISSOR 0.4`.
  - **Modelos:** `surface_material_override/<i>` guardado en las `MeshInstance3D` del `.glb` instanciado en cada `models/<x>.tscn` (pregunta 5).
  - **Props:** los materiales van dentro de la malla del prop (ver abajo).
  - Se borran `OriginalMaterial`, `BodyModel.surface_parts`, `_dress()` (solo queda el `custom_aabb`) y la lectura de `index.json`.
- **Props sin `BodySize`** (s5):
  - Cada prop **que alguien usa** se hornea como `scenes/props/meshes/<tag>.res` (`ArrayMesh` con el giro `upright_fix` aplicado a los vértices y sus materiales). El nombre es el del archivo fuente, como los íconos.
  - Lo consumen `@export var mesh: Mesh`:
    - las 243 partes `BodyVisual` de `scenes/structures/buildings/`, que pasan a `MeshInstance3D` con el transform de hoy horneado;
    - `VegetationSpecies` (39), que deja `model: String` por `mesh: Mesh`;
    - `rockform`, `ranged_shot` (`ShotLook`), `rock_projectile`, `debris_piece`, `snowball_flight` y `prop_look`, que cambian solo la fuente de la malla. El nodo `.new()` es de 055e.
  - El frente de la roca pasa a `@export var front_m` exacto en su escena (sim).
  - `BuildingFit` mide con `MeshInstance3D.get_aabb()`, y `import_props.py` escribe la malla en lugar del `BodySize`.

### 4.6 Qué es Resource de tipo, qué es nodo, qué es `@export` de instancia
| Cosa | Forma | Dónde |
|---|---|---|
| Reglas de una criatura o un mago | Resource de tipo (ya existen) + `body: PackedScene` | `data/catalog/creatures|wizards/<nombre>.tres` |
| Tamaño y sockets de la simulación | **nodos**: `Area3D Bounds` (monitoring off, capa 0, como `Reach` en 061a) con `CollisionShape3D`; `Marker3D` bajo `Sockets` | `scenes/units/bodies/<nombre>.tscn`, `scenes/wizards/bodies/<nombre>.tscn` |
| Apariencia (modelo, sonidos, llama) | escena + `@export sounds: SoundSet`, `carried_fx: PackedScene` en `BodyLook` | `<nombre>_look.tscn`, detrás del placeholder |
| Manos, aguja, llama | `BoneAttachment3D` + `Marker3D` en el modelo; cuándo hay mano, pista `visible` en la `Animation` de rol | `scenes/bodies/models/<modelo>.tscn` y `_clips/` |
| Material | `StandardMaterial3D` `.tres` compartido | `scenes/bodies/materials/` |
| Malla de un prop | `ArrayMesh` `.res` | `scenes/props/meshes/<tag>.res` |
| Lo que lee la sim del cuerpo | `BodyFacts` (derivado, en memoria) | `scenes/bodies/body_facts.gd` |
| Qué cuerpo viste | `BodyMount` (nodo, único dueño) | hijo de `unit.tscn`, `wizard_body.tscn`, `doctor.tscn` |
| Recorte de cápsula (`0.6`, `0.45`) | regla de la herramienta que mide (`new_creature`), no del runtime | `tools/bake/new_creature.gd` |

---

## 5. Árbol de archivos
```
scenes/bodies/
  [~] README.md                     5 líneas; Edit: la escena del cuerpo (tamaño, sockets) y la del modelo (manos, materiales)
  [+] body_frame.gd                 BodyFrame (Node3D, @tool ≤ 100): @export capsule, flying_capsule, footprint (CollisionShape3D),
                                    reach, muzzle, center, top, feet (Marker3D), look (el placeholder); model_id (solo lectura, id de red);
                                    warnings si falta Capsule/Center/Top o si el placeholder tiene overrides; F6: crea su Look si es la raíz
  [+] body_look.gd                  BodyLook (Node3D ≤ 60): @export sounds: SoundSet, carried_fx: PackedScene; model() -> BodyModel o malla
  [+] body_facts.gd                 BodyFacts (RefCounted ≤ 100): medidas y sockets locales decodificados; caché por escena
  [+] body_mount.gd                 BodyMount (Node ≤ 120): wear(scene) idempotente; facts; signal worn(frame); monta el Look en el cliente
  [~] body_model.gd                 [-] clips (hands), surface_parts, hands_of, exists, scene_path, _dress de materiales; queda custom_aabb (≤ 150)
  [~] body_rig.gd                   mount(look) en vez de load por tag; hand_points lee HandL/HandR visibles del modelo; [-] _bind/_apply_hands
  [~] body_rig.tscn                 [-] HandL, HandR
  [~] body_visual.gd                sin BodyCatalog: body_height/body_radius desde BodyFacts; [-] show_model(texto), overrides, placeholder
  [~] body_box.gd                   lee body.body_facts (sin texto)
  [~] hand_fx.gd                    respaldo = Sockets/Center del cuerpo (fuera fallback_height)
  [-] body_catalog.gd, body_size.gd, body_pose_override.gd, body_pose_overrides.gd, original_material.gd
  [+] materials/<archivo>.tres      StandardMaterial3D compartidos (los escribe bake_materials_055s)
  models/
    [~] <modelo>.tscn ×74           + Model/Skeleton3D/HandL|HandR (BoneAttachment3D) └ Socket (Marker3D); surface_material_override guardado;
                                    [-] clips (hands), surface_parts, model (tag)
    [~] <modelo>_clips/*.res        + pista Skeleton3D/HandL:visible en los roles con mano; + RESET (visible = false)
scenes/units/
  [~] README.md · [~] creature_type.gd   + body: PackedScene; [-] model, sounds, carried_fx (icon queda: pregunta 4)
  [~] unit.tscn                     + BodyMount; BodyCollider.mount; [-] model en BodyVisual (replication_config sin tocar)
  [~] unit_body.gd                  type setter → mount.wear(type.body); `model` (replicado) = frame.model_id; melee_profile y soul_anchor desde body_facts
  [~] unit_orders.gd:254 · attacks/[~] melee_attack.gd:199 · [~] captive.gd:273 · [~] creature_fx.gd (look.carried_fx y su socket)
  movement/[~] body_collider.gd     único escritor de la cápsula (unidad, mago, doctor); escucha worn y Flight; [-] MIN_HEIGHT, RADIUS_PER_HEIGHT
  bodies/[+] <nombre>.tscn ×72      BodyFrame (los escribe el migrador; testmonster incluido)
  bodies/[+] <nombre>_look.tscn ×72 BodyLook: instancia el modelo (o la malla de los 11 híbridos), sounds, carried_fx
scenes/wizards/
  [~] README.md · [~] wizard_type.gd   + body: PackedScene, model_id() (= body.model_id, para el cable); [-] model, sounds
  [~] wizard_body.gd                mount.wear(wizard_type.body) al aplicar el pick; [-] _fit_shape (243-252); feet_drop desde body_facts
  [~] wizard_body.tscn              + BodyMount; BodyCollider (como unit.tscn)
  bodies/[+] <nombre>.tscn ×15, <nombre>_look.tscn ×15
scenes/sacrifice/[~] doctor_body.gd (:269, :340-343 → BodyMount/BodyCollider) · [~] doctor.tscn (+ BodyMount, BodyCollider)
scenes/audio/[~] unit_sounds.gd:42 · wizard_sounds.gd:47 · command_voice.gd:68   el set del look montado (no del tipo)
scenes/spells/actions/[~] aimed_action.gd (Muzzle; [-] HAND_HEIGHT) · lightning_action.gd (Top) · teleport_action.gd (Feet, Center)
scenes/orders/[~] orders.gd:309 · selection.gd:358 · scenes/fx/[~] damage_numbers.gd:198 (Top)
scenes/ui/character_select/[~] wizard_preview.gd   instancia el look del cuerpo del mago; altura desde BodyFacts
scenes/map/[~] npc_spawn.gd:75 (vista previa = el look del cuerpo de la criatura) · props/[~] manafount_body.gd:62
scenes/structures/[~] building_fit.gd (aabb de la malla) · building_type.gd:53 · buildings/[~] 196 .tscn (243 partes → MeshInstance3D + mesh)
scenes/look/vegetation/[~] vegetation_species.gd (mesh: Mesh), mesh_planter.gd, vegetation_patch.gd
scenes/spells/[~] rock_projectile.gd (mesh, front_m), zones/debris_piece.gd, zones/snowball_flight.gd, carrier/prop_look.gd
scenes/units/abilities/[~] rockform.gd · attacks/[~] ranged_shot.gd, shot_look.gd (mesh: Mesh)
scenes/props/meshes/[+] <tag>.res   un ArrayMesh por prop usado (giro y materiales horneados)
scenes/core/catalog/[~] game_catalog.gd   [-] body_sizes
data/
  catalog/creatures/[~] 72 .tres    body = ExtResource; [-] model, sounds, carried_fx
  catalog/wizards/[~] 15 .tres      body = ExtResource; [-] model, sounds
  [-] catalog/body_sizes/ (396)     [-] bodies/pose_overrides.tres
  vegetation/species/[~] 39 .tres   mesh = ExtResource
addons/sacrifice_tools/[+] dedicated_strip.gd   EditorExportPlugin: AudioStream vacío y Animation sin pistas en el build dedicado; [~] plugin.gd lo registra
tools/
  migrate/[+] bake_bodies_055s.gd   --script, una vez: BodyCatalog.info + pose_overrides + hands → body_frames_055s.json (var_to_str exacto)
  migrate/[+] write_bodies_055s.py  una vez: 87 escenas de cuerpo, 87 de apariencia, body/sounds en las fichas (ext_resource antes de sub_resource)
  migrate/[+] bake_hands_055s.gd    una vez: HandL/HandR en los 74 modelos y la pista visible en los roles
  bake/[+] bake_materials_055s.gd   materiales compartidos + overrides en los modelos (re-ejecutable para modelos propios)
  bake/[+] bake_props_055s.gd       mallas .res de los props usados + reescritura de edificios, especies y proyectiles; informe de huérfanos
  bake/[~] new_creature.gd          escribe modelo (+ HandL/HandR desde empties del .glb), escena del cuerpo medida, apariencia y ficha; [-] BodySize
  bake/[~] bake_ragdolls.gd, creature_icon(_render).gd   por escena del cuerpo, no por tag
  import/[~] import_props.py        malla .res en vez de BodySize · import/[~] export_skeletal.py (sin body_sizes)
  audit/[~] audit_skeletal_center.gd, check_map_models.gd · [-] audit_models.py si queda sin uso
  bake/[~] bake_catalog.gd          congelado (no escribe body_sizes)
  lint/[~] conventions.sh           + C23 (presentación en tipos que lee el servidor), pregunta 10 · [~] baseline.txt
  deploy/[~] README.md              preset dedicated_server=true; DedicatedStrip; cómo medir
debug/  (se borra al final)
  suite/[+] body_facts_cases.gd, presentation_refs_cases.gd, clip_strip_cases.gd, prop_facts_cases.gd · net/[+] wire_config_cases.gd
  suite/[~] catalog_cases.gd (type.body con Capsule/Center/Top; type.clips = biblioteca del modelo del look)
  bodies/[-] capsule_preview, body_pose_bench, f134_hybrid_pose_* (su trabajo pasa a las escenas del cuerpo) · [~] galerías
  units/[~] custom_creature.gd · map/[~] crowd_tipi.gd · [~] 7 .tscn con `model = "…"`
agent/
  runs/[+] run_055s_dedicated_cost.sh   exporta, arranca el .pck dedicado y el de salas, mide tiempo hasta «listo» y RSS
  harness/[~] pt135_capsule.gd, splash_probe.gd · fixtures/f208/[~] f208_poses.gd
```

### 5.1 Árbol de nodos de una criatura
`scenes/units/bodies/trogg.tscn` (lo carga todo par; ningún sonido ni malla):
```
Trogg (Node3D, BodyFrame)           model_id = "eorc" (solo lectura: el `model` replicado de hoy)
├── Bounds (Area3D)                 monitoring/monitorable off, capa y máscara 0: solo da las manijas
│   ├── Capsule (CollisionShape3D)  CapsuleShape3D r 0,35 · h 1,9 (recortada como hoy)   ─► cápsula de física (BodyCollider)
│   ├── FlyingCapsule (…, disabled) solo los híbridos voladores (height_flying)
│   └── Footprint (CollisionShape3D) CylinderShape3D r = radio crudo · h                ─► formación, half_size
├── Sockets (Node3D)
│   ├── Reach (Marker3D)            z = alcance del golpe (frente de la caja)
│   ├── Center (Marker3D)           y = h/2: alma, selección, FX al centro
│   ├── Top (Marker3D)              y = h: barra de vida, números de daño
│   └── Muzzle (Marker3D)           opcional: de dónde sale lo que tira (magos; armas en 055c3)
└── Look  ▢ placeholder → trogg_look.tscn         solo el cliente lo crea
```
`scenes/units/bodies/trogg_look.tscn` (solo cliente):
```
TroggLook (Node3D, BodyLook)        sounds = data/audio/creatures/trogg.tres · carried_fx = (vacío; el Manahoar: su llama)
└── Model (instancia de models/eorc.tscn, BodyModel)
    ├── Model (eorc.glb)            surface_material_override/0..4 = materials/<archivo>.tres
    │   └── Skeleton3D
    │       ├── Ragdoll (PhysicalBoneSimulator3D) …         (los 20 que ya lo tienen)
    │       ├── HandL (BoneAttachment3D, bone_15) └── Socket (Marker3D)
    │       └── HandR (BoneAttachment3D, bone_18) └── Socket (Marker3D)
    ├── Clips (AnimationPlayer)     RESET: HandL/HandR visible = false · los roles con mano: visible = true
    ├── Tree (AnimationTree) · ClipEvents
```
El mago, `scenes/wizards/bodies/jadugarr.tscn`: igual, más `Sockets/Muzzle` (y = altura de la mano calculada por Godot, z = alcance) y `Sockets/Feet`. Su `jadugarr_look.tscn` tiene `sounds = data/audio/wizards/jadugarr.tres`.

En `unit.tscn` (lo que cambia):
```
Unit (UnitBody)  type ─► trogg.tres ─► body ─► scenes/units/bodies/trogg.tscn
├── BodyMount                       body = ..; rig = Tilt/Mesh/Rig        [+]  wear(type.body) → Frame (hijo) + facts
├── Frame (instancia de trogg.tscn) lo agrega BodyMount (no está guardado en unit.tscn)
├── Tilt/Mesh (BodyVisual)/Rig      en el cliente: ModelSlot ◄─ create_instance(Frame/Look)
├── Collision                       la escribe solo BodyCollider (desde Frame/Bounds/Capsule)
├── BodyCollider                    mount = BodyMount; flight = Flight
└── MultiplayerSynchronizer         sin cambios (creature_tag, model, …)
```

### 5.2 Mapa de responsabilidades (un dueño por estado)
| Estado | Dueño | Lo leen |
|---|---|---|
| Tamaño y sockets que lee la sim | la escena del cuerpo (`BodyFrame`), derivado en `BodyFacts` | melee, evitación, formación, mago (`Muzzle`), alma, cápsula |
| Qué cuerpo viste un cuerpo | `BodyMount` (idempotente) | `BodyCollider`, `BodyVisual`, sonidos, FX |
| La cápsula de física | `BodyCollider` (unidad, mago y doctor) | física, `BodyNudge` |
| Apariencia (modelo, sonidos, llama) | la escena de apariencia (`BodyLook`) | `BodyRig`, `UnitSounds`, `WizardSounds`, `CommandVoice`, `CreatureFx` |
| Manos y cuándo hay mano | el modelo (`HandL`/`HandR`) y la pista `visible` de su `Animation` | `HandFx` (solo presentación) |
| Material de una superficie | el override guardado en el modelo / la malla del prop | render |
| Qué no entra al build dedicado | `DedicatedStrip` (export) + el placeholder | — |
| Id de red del modelo | `BodyFrame.model_id` → `UnitBody.model`, `WizardType.model_id()` | `MultiplayerSynchronizer`, pick, logs |

### 5.3 Qué no entra (fuera de alcance)
- Armas como escenas, `shot_height` y `origin_of` (`ranged_attack.gd:268-278`): 055c3, que usa `Sockets/Muzzle`.
- FX puestos en sockets (`rockform`, `firewalking`, `frozen`…): 055x. Los radios del lazo del guardián, el altar y las almas: 055r. La geometría del ritual y `hang_point`: 055g. El ragdoll del cautivo: 055a-5.
- El nodo `MeshInstance3D.new()` de los proyectiles y su escena: 055e. La partición estructural de `match.tscn` (HUD, consejero y directores detrás de un placeholder): pregunta 2.
- Sacar `model` del cable: fase 3 (pregunta 8). Partir `unit_body.gd`/`wizard_body.gd`: 055c.

### 5.4 Si se elige la escena heredada (pregunta 1 = no)
`trogg.tscn` hereda `unit.tscn`, con `Collision`, `Sockets` y `Look` directos. `UnitSpawner._make` instancia `type.body` en vez de `unit_scene` (el paquete y `spawn_function` no cambian). Los magos y el doctor usan igual `BodyFrame` (por el cable). Son dos formas para lo mismo, y por eso no se recomienda.

---

## 6. Cómo lo hace un humano
| Verbo | Ejemplo | Qué abre y toca | Lugares |
|---|---|---|---|
| **Entender** | «¿qué tan grande es el trogg, hasta dónde pega, de dónde sale la bola del mago?» | `scenes/units/bodies/trogg.tscn`: el modelo, la cápsula, la huella y los marcadores en el viewport. El mago: `scenes/wizards/bodies/jadugarr.tscn` → `Sockets/Muzzle` | 1 |
| **Modificar** | «mover dónde una criatura sostiene el arma» (las partículas de la mano) | su modelo `scenes/bodies/models/<modelo>.tscn` → `Model/Skeleton3D/HandR/Socket` → arrastrar con el gizmo (o elegir otro `bone_name`) | 1 |
| | «que la bola del mago salga más arriba» | `jadugarr.tscn` → `Sockets/Muzzle` → arrastrar. Cambia la simulación a propósito | 1 |
| | «cambiar la voz de una criatura» | `trogg_look.tscn` → raíz → `Sounds` → arrastrar otro `SoundSet` | 1 |
| | «más gorda, que choque distinto, que pegue de más lejos» | `trogg.tscn` → manijas de `Bounds/Capsule`, `Footprint` y el marcador `Reach` | 1 |
| | «cambiar la música de un dios» | `data/look/<dios>.tres` (`LookProfile`, 055o) → `Music` | 1 |
| **Agregar** | «que una criatura lleve una llama en la cabeza» | modelo → `BoneAttachment3D` en el hueso + `Marker3D`, asignar `carried_fx_socket`; `trogg_look.tscn` → `Carried Fx` | 2 |
| | «que un híbrido sea más alto en vuelo» | `trogg.tscn` → activar `FlyingCapsule` y estirarla | 1 |
| **Quitar** | «sin partículas en las manos de un mago» | modelo → borrar `HandL`/`HandR` (`HandFx` usa `Center`) | 1 |
| | «que la criatura no suene» | `trogg_look.tscn` → `Sounds` vacío | 1 |
| **Crear** | «una criatura propia desde Blender con sus sockets» | exportar el `.glb` con huesos, acciones con nombre de rol y, si se quiere, empties `HandL`/`HandR` hijos de un hueso → Project › Tools › Sacrifice › «Nueva criatura desde modelo…» escribe el modelo (manos desde los empties, materiales), su biblioteca de clips, `bodies/<nombre>.tscn` (cápsula y sockets medidos de la malla), `<nombre>_look.tscn` y `<nombre>.tres`. Después se ajusta con el gizmo y se arrastra al libro del dios | 2 (el `.glb` y el libro) |
| | «un trogg de élite» | duplicar `trogg.tres`, vaciar el `Tag`, subir stats; `Body` sigue en `trogg.tscn` | 1 |
| **Escalar** | «100 criaturas, 20 magos» | cada uno es una ficha, una escena de cuerpo y una de apariencia (las escribe la herramienta). El servidor carga solo la escena chica; la apariencia, el audio y las pistas nunca entran en él. Sin tablas ni registros | 1 por pieza, 0 código |

**Se rediseñó porque hoy pedía código o más de dos lugares:**
- El tamaño de un cuerpo vive en 3 lugares, todos números: `body_sizes/<tag>.tres`, `pose_overrides.tres` y las constantes de `BodyCollider`, más una copia de la regla en `wizard_body` y otra en `doctor_body`. Con el corte es 1 escena con manijas.
- La mano de un mago está en un `Dictionary` por clip dentro del modelo, que solo escribe el bake, y la bola sale de una constante (`HAND_HEIGHT`). Con el corte es 1 marcador por cosa.
- «Cambiar la voz» ya era 1 lugar, pero colgaba de la ficha que lee el servidor. Ahora es 1 lugar en la apariencia.
- **Excepción declarada:** un **tipo** nuevo de socket que lea el código (por ejemplo, «Cola») es un campo nuevo en `BodyFrame`, o sea código en un lugar. Mover, quitar o reasignar un socket existente nunca lo pide.

---

## 7. Red, snapshot y late join
- **Lo que viaja (sin cambios, byte a byte):**
  - el paquete de `UnitSpawner` (`tag, label, slot, x, y, z, yaw, summoning, npc, peasant, name`; `unit_spawner.gd:38-58`);
  - el `MultiplayerSynchronizer` de `unit.tscn`: `creature_tag` y **`model`** (`properties/4`), con `model = frame.model_id`, el mismo texto `"eorc"`;
  - el de `wizard_body.tscn`: `wizard_tag`, **`model`** y `god` (`properties/3-5`);
  - el pick `{"wizard", "model", "god"}` (`net/match_wire.gd:14`), con `model = wizard.model_id()`;
  - las líneas `slot %d pick %s %s` (`pick_board.gd:68,82`, `ticket_plan.gd:38`) y `pick %s %s` (`sacrifice_flow.gd:69`), con el mismo valor y **el mismo texto**.
- **Nunca viajan** escenas, rutas ni recursos. Las escenas de cuerpo y de apariencia **no tienen** `MultiplayerSynchronizer` ni `MultiplayerSpawner` (lo prueba `wire_config_cases`).
- **Late join:** `spawn_function` (`_make`) pone `type` antes de `add_child`, igual que en el servidor, así que el cuerpo se viste y el cliente crea su apariencia. Los magos se visten con el pick decodificado. Si el id replicado llega antes que el pick, se usa el default de `wizard_body.tscn` y se vuelve a vestir con `slot_picks_changed` (riesgo 5 de 055c1). `wear` es idempotente.
- **Snapshot:** ninguno guarda el cuerpo. La vida, el maná y la posición siguen en los mismos nodos.
- **Cómo se prueba que el cable no cambió** (el método de `run_034m`/`run_049e` de 055i-a y 055c1):
  1. En s0, sobre `main` sin el corte: correr `bash agent/runs/run_034m.sh` y `bash agent/runs/run_049e.sh`, y guardar en `agent/out/055s/` las líneas que matchean `slot [0-9]+ pick`, `"picks"`, `ia slot [0-9]+ lista`, `partida terminada` y `dedicado listo puerto`. Al cerrar s1, s2 y s5 se repite: **diff vacío**.
  2. `debug/net/wire_config_cases.gd` (nuevo; 055c1 lo había planeado y no se escribió) imprime `WIRE CONFIG sha256=<…> props=<n>` sobre la lista ordenada `(escena, nodo, propiedad, spawn, modo)` del `replication_config` de `unit.tscn`, `peasant.tscn`, `wizard_body.tscn`, `doctor.tscn` y las escenas de disparo. Además falla si una escena de `scenes/*/bodies/` tiene un sincronizador. Mismo hash en s0 y al cerrar cada sub-corte.
  3. Estático: `git diff <base> -- '*.tscn' | grep -E '^[+-](properties/|\[sub_resource type="SceneReplicationConfig")'` vacío, y sin cambios en `spawn_unit`, `spawn_map_creature`, `_make`, `MatchWire.encode_pick` ni `MpSlotSpawner`.
  4. `late_join.tscn` y `local_server_e2e` en PASS.
  5. En s4, un cliente del proyecto contra el **dedicado exportado** termina la partida con las mismas líneas del punto 1.

## 8. Determinismo
- **Criterio:** `bash agent/run_determinism.sh quick` da los **28 digests idénticos** a `agent/det_baseline.txt`. Se corre al cerrar s1, s2 y s5. No se regraba la base. Si un caso cambia, el sub-corte no cierra: se biseca por lector (§3.3).
- **¿Algún socket cambia una altura que usa la simulación?** Se mudan de lugar cuatro valores: altura, radio crudo, alcance y altura en vuelo, más el origen de la bola del mago y el centro del alma. **Ninguno cambia de valor.** Se mantienen exactos así:
  1. **Medidas en mm** (`height`, `radius`, `reach`, `height_flying`): la forma guarda float32 y `BodyFacts` decodifica con `roundi(v * 1000.0) / 1000.0`, que da el double que hoy lee el `.tres`. Vale porque las 85 medidas y las 15 correcciones tienen ≤ 3 decimales (§3.2), y el error del float32 (unos 2·10⁻⁶ en 17,78 m) es mucho menor que 0,5 mm.
  2. **Cápsula recortada:** hoy se calcula en double y se guarda en `CapsuleShape3D` (float32). El migrador escribe el mismo float32 (`(CapsuleShape3D.new() con el valor de hoy).radius`). Nada la lee como double.
  3. **`Muzzle` y `Center`:** la sim usa la `position` **local** y la misma cuenta de hoy. El migrador escribe la componente que Godot calcula con la expresión de hoy (`(Vector3.UP * h * 0.65).y`, `h * 0.5`). Como `Vector3 * float` ya pasa por float32, el resultado es el mismo bit.
  4. **Que el `.tscn` conserve el float32 exacto** al guardar y releer es NO VERIFICADO: se prueba en s0 con los 87 cuerpos. Si no lo conserva, va la alternativa de la pregunta 11.
- **Antes de borrar `BodyCatalog`:** `body_facts_cases` con `equal=87 differ=0`, y `quick` idéntico con los lectores ya cambiados.
- **Lo que no toca la sim:** la apariencia, las manos, los materiales, los props visuales y `DedicatedStrip` (que solo actúa al exportar; `clip_strip_cases` prueba que `ClipFacts` da lo mismo sobre la `Animation` recortada: 1 352 roles). La única excepción es el frente de la roca (`rock_projectile.gd:147`): pasa a `front_m` con el double exacto de `body_sizes/<roca>.tres`.
- **Ningún RNG nuevo.** La cantidad de áreas y nodos del cuerpo no entra en el digest (NO VERIFICADO que el digest no cuente nodos; se ve en s1).

## 9. Riesgos (con las lecciones ya aprendidas)
1. **Nada por cuadro lee con `load()` ni `find()`.** `BodyFacts.of()` y `create_instance()` corren solo en `wear()`. `BodyBox`, `HandFx`, `damage_numbers` y `selection` leen variables guardadas. El reviewer busca `BodyFacts.of(`, `load(`, `find_child`, `get_node(` y `create_instance` dentro de `_process`/`_physics_process` de lo tocado: tiene que dar 0. Hoy `BodyCatalog.info` cachea, pero `body_box.gd` lo llama por cuadro desde la evitación; eso desaparece.
2. **Los autoloads que son escena no tienen tipo estático** (`SacrificeFlow`, `SoundBus`). Lo que devuelven se guarda en una variable tipada explícita. No se agrega ningún autoload: `BodyMount` es un nodo y `BodyFacts`, un `RefCounted`.
3. **El modo `--script` no tiene autoloads y siempre termina con `quit()`.** `bake_bodies_055s.gd` y `bake_hands_055s.gd` no instancian escenas cuyos scripts nombren autoloads: leen `BodyCatalog` y `GameCatalog` (estáticos) y los `.tscn` de modelo (`BodyModel` es `@tool` y no nombra autoloads). Cada salida, error incluido, pasa por `quit(code)`. Lo que necesita instanciar el cuerpo entero corre como caso de `rules_suite`.
4. **En los `.tres`/`.tscn` escritos con Python, los `ext_resource` van antes que los `sub_resource`** (`bb1f09db`: Persephone no cargaba). `write_bodies_055s.py` arma la cabecera completa primero y pega los valores con el texto de `var_to_str` que dio Godot, sin reformatear floats. Después, `--headless --import` y `catalog_cases`.
5. **Dos marcadores (o dos claves) en el mismo instante se pisan** (`b428c1df`, testmonster). Las pistas `visible` llevan una sola clave en t = 0 por rol, y en `bugf` la segunda mano es otra pista (`HandL2`), no otra clave en el mismo instante. Los marcadores `hit`/`shoot` no se tocan: el migrador de manos solo agrega pistas, y `clip_facts_cases` (1 352/1 352) lo confirma.
6. **No cambiar el texto de un `print`:** quedan exactos `slot %d pick %s %s`, `pick %s %s`, `partida %s: slot %d pick…`, `NEW_CREATURE …`, `CATALOG PASS`, `CLIP FACTS …` y `dedicado listo puerto`. Las líneas nuevas son solo las de las sondas (`BODY FACTS`, `PRESENTATION REFS`, `CLIP STRIP`, `PROP FACTS`, `WIRE CONFIG`).
7. **`InstancePlaceholder`** (NO VERIFICADO en 4.7, se prueba en s0):
   - que el editor dibuje el contenido;
   - que `ResourceLoader.load` de la escena del cuerpo **no** cargue la apariencia (`ResourceLoader.has_cached` sobre el set de sonidos y el `.glb` debe dar `false`);
   - que `create_instance` funcione bajo un nodo de `MultiplayerSpawner` y en un late join.

   Si falla: `BodyFrame` guarda la apariencia en `@export_storage var look_path` escrita por la herramienta, con allowlist de C21. Es la ruta que guarda el placeholder igual.
8. **Overrides que meten presentación en la escena del cuerpo** (un humano pisa `sounds` desde `trogg.tscn`): warning de `BodyFrame` y `presentation_refs_cases`, que falla si `ResourceLoader.get_dependencies()` de una escena de cuerpo o de una ficha llega a un `AudioStream`, un `SoundSet`, un `.glb` o un `models/*.tscn`.
9. **`DedicatedStrip`** (NO VERIFICADO): que `_customize_resource` vea los streams importados y los `.res` de las bibliotecas en un export headless, y que el plugin esté habilitado al exportar desde la consola. Se prueba en s0 con la medida (§12). Si no ve los importados, va el plan B: la carpeta `data/audio` en «Strip visuals» no sirve para audio, así que el audio se mueve detrás del placeholder también en magos y dioses (pregunta 2).
10. **Archivos sin commitear en `main`** (54 `.import` y `data/look`, `data/fx`): el developer trabaja en un worktree y no los incluye. s3 toca los `.glb`/`.tscn` de modelos, no los `.png.import` sucios.
11. **Importación pesada:** 174 escenas nuevas, 74 modelos y las bibliotecas reescritas, y unos 330 `.res` de props. Una sola `--import` por sub-corte, sola en la cola FIFO (memoria «Godot puede colgar la Mac»).
12. **`unit_body.gd` (785), `wizard_body.gd` (570) y `doctor_body.gd` (414)** están en C1b: no pueden crecer. Todo lo nuevo va a `BodyMount`, `BodyCollider` y `BodyFacts`.
13. **El ciclo de recursos:** la escena del cuerpo no apunta a su ficha. El reviewer lo revisa.
14. **Captura:** los materiales horneados tienen que verse igual que los de runtime: `clip_shots` y `match_shots` con diff ≤ 0,5 %.

## 10. Criterios medibles y código 1 a 1 que se borra
**Lint** (`bash tools/lint/conventions.sh`; ningún conteo sube; `--update-baseline` al cerrar cada sub-corte):

| Regla | Hoy | Al cerrar | Sub-corte |
|---|---|---|---|
| C19 | 327 | **6** (−320 `body_sizes`, −1 `pose_overrides`) | s5 |
| C18 | 35 | **12** (−23 `BodyCatalog.*`) | s1 (16), s2 (2), s5 (5) |
| C16 | 39 | **30** (−9, §3.4) | s1, s2 |
| C13 | 9 | **6** | s3 (2), s5 (1) |
| C15 | 39 | **38** | s3 |
| C9 | 292 | **≤ 286** (bodies 6 → 0; `## Ref:` al final en lo tocado) | todos |
| C1a / C1b | 100 / 21 | **≤ 98** / 21 (`body_catalog` borrado, `body_model` ≤ 150; nuevos ≤ 150) | s2, s5 |
| C23 (nueva, pregunta 10) | el developer la fija al agregarla | **≤ 1** (`GodType.look`, con allowlist hasta la partición) | s2 |

**Build dedicado** (`agent/runs/run_055s_dedicated_cost.sh`):
- Exporta con `--export-release dedicated_server` y arranca el `.pck` con el binario de la Mac (`--headless --main-pack … -- --dedicated`), con las mismas banderas que la medida de `3626fb2e` (s0 las anota en este plan).
- Mide el tiempo hasta `dedicado listo puerto` y el RSS (`ps -o rss=`) 5 s después.
- **≤ 3,0 s y ≤ 380 MB.** Justificación:
  - antes de la v2 eran 2,5 s y 353 MB;
  - lo que sale del dedicado son unos 46 MB de pistas de hueso y unos 30 MB de audio de criaturas y magos, más la música y el consejero;
  - lo que entra son 87 escenas chicas y los marcadores.

  Se espera de 2,6 a 2,8 s y de 355 a 365 MB (NO VERIFICADO). El margen cubre el catálogo tipado de 055i. Si s0 mide que el plugin solo ya da ≤ 2,8 s, el objetivo se baja a eso.
- **Servidor de salas:** RSS hasta su línea de listo ≤ el valor de s0, y `presentation_refs_cases` en 0.

**Sondas** (headless, cola FIFO):
- `BODY FACTS bodies=87 equal=87 differ=0` (§4.2).
- `PRESENTATION REFS bodies=87 types=87 leaks=0` (riesgo 8).
- `CLIP STRIP roles=1352 equal=1352`.
- `PROP FACTS props=<n> mesh=<n> orphans=<m>` (informe).
- `WIRE CONFIG` con el mismo hash.
- `CATALOG PASS` con las reglas nuevas, `CLIP FACTS 87/87`, `rules_suite` PASS y `SOUND REFS` con los mismos conteos, leídos ahora de las apariencias (67 + 15).

**Determinismo y red:** `quick` con los 28 digests idénticos (§8) y diff vacío (§7).

**Capturas:** `clip_shots` (74 modelos en `idle` 0 s, `attack` en el `hit` y `cast` con manos) y `match_shots` (High Noon con edificios, flora y unidades): diff de AgentKit **≤ 0,5 %** por imagen entre s0 y el cierre.

**Greps en 0** en `scenes/`: `BodyCatalog`, `BodySize`, `BodyPoseOverride`, `pose_overrides`, `body_sizes`, `OriginalMaterial`, `HAND_HEIGHT`, `hands_of`, `surface_parts`, `scene_path(`, `RADIUS_PER_HEIGHT`, `_fit_shape`, `type.sounds` y `type.carried_fx`.

**Humano** (se borra al final):
- abrir `trogg.tscn`, estirar la cápsula y ver con F5 en High Noon que el trogg ocupa más;
- abrir `jnwr.tscn`, mover `HandR/Socket` y ver que las partículas del lanzamiento salen ahí;
- deshacer los dos cambios.

**Código 1 a 1 que se borra:**
- `body_catalog.gd` (189), `body_size.gd`, `body_pose_override(s).gd`, `original_material.gd` (92).
- `data/catalog/body_sizes/` (396 archivos, las medidas del SXSK/BLDG del original), `data/bodies/pose_overrides.tres`.
- `BodyModel.clips[*].hands` (los dos sockets por clip del original, con «root = sin mano», el NaN de sacengine) y `surface_parts` (las partes del exportador).
- `body_rig.gd` `_bind_hands`/`_apply_hands` y los nodos `HandL`/`HandR` del rig.
- Las tres copias de la regla de la cápsula (`body_collider.gd:20-22`, `wizard_body.gd:243-252`, `doctor_body.gd:340-343`) y `HAND_HEIGHT := 0.65` («there are no hand bones»).
- La carga por tag del modelo (`BodyModel.exists/scene_path`, `body_rig.gd:221-226`) y `BodyCatalog.mesh` por texto en 9 lugares.
- `CreatureType.model`/`sounds`/`carried_fx` y `WizardType.model`/`sounds` como datos que lee el servidor.
- La lectura de `textures/index.json` en cada arranque.
- `debug/bodies/capsule_preview`, `body_pose_bench` y `f134_hybrid_pose_*`.

## 11. Sub-cortes y paralelo
| Sub-corte | Qué | Tamaño | Depende | Paralelo con |
|---|---|---|---|---|
| **s0** prueba y referencias (rama descartable, la corre el orquestador) | Referencias sobre `main`: logs de `run_034m`/`run_049e`, `WIRE CONFIG`, `clip_shots`, `match_shots`, costo del dedicado y del servidor de salas. Spikes: placeholder (riesgo 7), roundtrip del float32 en `.tscn` con los 87 cuerpos (§8.4), `DedicatedStrip` solo, con su medida (riesgo 9), pista `visible` con `RESET` en el `Tree`, material horneado en `eorc` y un prop con diff ≤ 0,5 %. Los números se anotan en este plan | S | — | todo (no mergea) |
| **s1** cuerpo de la sim | `BodyFrame`, `BodyFacts`, `BodyMount`; `bake_bodies_055s` + `write_bodies_055s` (87 escenas de cuerpo, con `Look` vacío todavía); `CreatureType.body`, `WizardType.body`; `BodyCollider` como único escritor; los lectores de §3.3 a `BodyFacts`; `body_facts_cases` y `wire_config_cases`. `BodyCatalog` sigue vivo para el dibujo | M | s0 | s3, s4 |
| **s2** apariencia | 87 escenas de apariencia y el placeholder; `BodyRig.mount`; sonidos y llama a `BodyLook` (`unit_sounds`, `wizard_sounds`, `command_voice`, `creature_fx`); `bake_hands_055s` (manos y pista `visible`); `HandFx`, `damage_numbers`, `selection`, `lightning`, `teleport`; `wizard_preview`, `npc_spawn`; fuera `model`/`sounds`/`carried_fx` de los tipos; `presentation_refs_cases`; C23; `new_creature` reescrito | M–L | s1, s3 | s5a |
| **s3** materiales | `bake_materials_055s`: materiales compartidos y overrides en los 74 modelos; `BodyModel` sin `surface_parts`/`_dress`; mallas de los 11 híbridos con material; capturas | S–M | s0 | s1, s4 |
| **s4** build dedicado | `DedicatedStrip` + `plugin.gd`; `clip_strip_cases`; `run_055s_dedicated_cost.sh`; cliente contra el dedicado exportado; `deploy/README.md` | S | s0 | s1, s3 (solo `addons/`, `tools/deploy/`, `agent/runs/`) |
| **s5a** props | `bake_props_055s`: mallas de los props usados; 196 escenas de edificio (243 partes), 39 especies, `mesh_planter`/`vegetation_patch`, los 6 consumidores de mallas, `BuildingFit`, `import_props.py`, `front_m` de la roca; `prop_facts_cases`; capturas | M | s1, s3 | s2 (carpetas disjuntas: `structures/`, `look/vegetation/`, `spells/`, `data/vegetation/`; `body_visual.gd` lo toca solo s2) |
| **s5b** borrado | `BodyCatalog`, `BodySize`, `pose_overrides`, `body_sizes/`, `OriginalMaterial`, `GameCatalog.body_sizes`; herramientas y debug que los nombran (§5); greps en 0; `--update-baseline` | S | s2, s5a | — |
| **s6** nombres (pregunta 7) | `models/eorc.tscn` → `trogg_model.tscn` (+ `_clips.tres` y `_clips/`) con `rename_resources.py` | S | s5b | 055c2 si no toca `scenes/bodies/` |

- **Orden:** s0 → (s1 ∥ s3 ∥ s4) → (s2 ∥ s5a) → s5b → s6 → **055a-5**.
- **Fuera del corte:** 055c2–c5 tocan `unit_body.gd`, `melee_attack.gd` y `unit.tscn`, así que **no** van en paralelo con s1 ni con s2. 055x puede ir con s5a solo si no toca `spells/zones/` ni `rock_projectile.gd`.
- Cada sub-corte es un developer en su worktree. Hay review en s1 (simulación) y s2 (87 escenas). Godot va por la cola FIFO: como mucho 3 headless y 1 ventana, y la `--import` de cada sub-corte, sola.

## 12. Orden de implementación
1. **s0:**
   1. Referencias (§7.1, `WIRE CONFIG`, capturas, `run_055s_dedicated_cost.sh` sobre `main`).
   2. Spikes de los riesgos 7 y 9, de §8.4 y de la pista `visible`.
   3. Anotar los números en este plan.
2. **s1:**
   1. `BodyFacts` y `BodyFrame`.
   2. `bake_bodies_055s.gd` → JSON → `write_bodies_055s.py` → `--import`.
   3. `body_facts_cases` en paridad (`BodyCatalog` vivo).
   4. `BodyMount` en `unit.tscn`, `wizard_body.tscn` y `doctor.tscn`.
   5. `BodyCollider` único; los lectores de §3.3.
   6. `quick` idéntico, `rules_suite`, `late_join`, `run_034m`/`run_049e` con diff y `WIRE CONFIG`.
3. **s3:**
   1. `bake_materials_055s.gd`.
   2. Modelos con overrides; `BodyModel` sin `apply_to`.
   3. `clip_shots` ≤ 0,5 %.
4. **s4:**
   1. `DedicatedStrip`.
   2. `clip_strip_cases`.
   3. Export y medida; anotar.
   4. `deploy/README.md`.
5. **s2:**
   1. `BodyLook`; `write_bodies_055s.py --looks` (87 apariencias y el placeholder en las escenas de cuerpo).
   2. `BodyRig.mount`.
   3. Sonidos y llama.
   4. `bake_hands_055s.gd`; `HandFx`.
   5. UI y FX de §3.4.
   6. Fuera los campos de los tipos.
   7. `presentation_refs_cases`, `SOUND REFS`, C23.
   8. `new_creature` (rehacer `testmonster` en un directorio de prueba, no en el repo).
   9. Medida del dedicado ≤ 3,0 s / ≤ 380 MB; capturas; `quick`, red.
6. **s5a:**
   1. `bake_props_055s.gd` con informe.
   2. Edificios, especies y consumidores.
   3. `front_m`.
   4. `prop_facts_cases`, `match_shots`, `quick`.
7. **s5b:** borrar; greps en 0; `--update-baseline`; los READMEs de `bodies`, `units`, `wizards` y `structures` con las 5 líneas (`Check:`, no `Debug:`).
8. **s6** (si se aprueba): renombrar, `--import`, `catalog_cases`.

## 13. Cómo lo verifica un humano en el editor
- **`scenes/units/bodies/trogg.tscn`:** se ve el trogg. Al seleccionar `Bounds/Capsule`, las manijas de la cápsula; `Sockets/Reach` está delante. F6 lo muestra solo.
- **`scenes/units/bodies/trogg_look.tscn`:** en el inspector, `Sounds` = `trogg.tres`. Al vaciarlo y jugar con F5 en High Noon, el trogg no suena. Deshacer.
- **`scenes/wizards/bodies/jadugarr.tscn` → `Sockets/Muzzle`:** subirlo 1 m, F5, lanzar una bola: sale más arriba (y el banco cambia, como corresponde). Deshacer.
- **`scenes/bodies/models/jnwr.tscn`:** `Clips` → `cast`, la pista `Skeleton3D/HandL:visible` en `true`. Con `preview_role = cast` se ven `HandL/Socket` y `HandR/Socket` siguiendo las manos.
- **Una escena de edificio** (`scenes/structures/buildings/<x>.tscn`): sus partes son `MeshInstance3D` con `Mesh` = `scenes/props/meshes/<tag>.res`; abrir la malla muestra el material.
- **Headless:** `bash tools/lint/conventions.sh`, `rules_suite`, `bash agent/run_determinism.sh quick`, `bash agent/runs/run_034m.sh`, `bash agent/runs/run_049e.sh`, `bash agent/runs/run_055s_dedicated_cost.sh`.

## 14. Lo que 055s deja listo para 055a-5 (ragdoll del cautivo y los 54 que faltan)
- **Los 74 modelos** en `scenes/bodies/models/` (o con su nombre nuevo, si va s6) siguen siendo la única escena con esqueleto, `Ragdoll` y clips. `bake_ragdolls.gd` los recorre por la escena del cuerpo (no por tag), así que hornear los 54 restantes es correrlo sobre la lista de `type.body`.
- **El ancla:** `Sockets/Center` de cada escena de cuerpo es el punto de cuelgue (y = h/2, el mismo centro de hoy). El `AnimatableBody3D` Anchor de 055a-5 va como hijo del cuerpo, sin colisiones. `BodyFacts.height_m` da la vara de las métricas («extensión < 2× altura»).
- **La aguja del doctor:** `HandR/Socket` en `sacd.tscn` (`BoneAttachment3D`), visible en los roles del doctor que cargan.
- **Solo cliente:** el ragdoll vive en la apariencia, que el servidor nunca crea. `CaptiveLook` toma el esqueleto con `BodyRig.model_root()` (la API no cambia), y la sim sigue moviendo `body.global_position`.
- **La galería** `debug/units/death_ragdoll.tscn` puede instanciar las 72 apariencias directamente.

## 15. Preguntas abiertas (con recomendación)
1. **¿Escena del cuerpo compuesta (`BodyFrame` que el cuerpo instancia según su tipo) en vez de escena heredada de `unit.tscn` (RFC-055 §15)?** **Recomiendo la compuesta.** Es la única forma de que los magos tengan su escena sin cambiar los bytes del auto-spawn. Un humano abre una escena de 10 nodos, no de 110 en gris. Criaturas, magos y doctor quedan con un solo mecanismo. Si preferís la heredada, ver §5.4 (los magos quedan igual compuestos).
2. **¿La presentación sale del servidor con placeholder para cuerpos y `DedicatedStrip` para el audio y las pistas que quedan (`GodType.look`, consejero, FX, bibliotecas)?** **Recomiendo que sí.** El placeholder es la separación estructural donde ya hay escena, y el plugin extiende el mecanismo con que Godot ya quita mallas y texturas. Partir `match.tscn` en una rama de presentación (HUD, consejero, directores, `LookProfile` fuera de `GodType`) es un corte grande que pisa 055h/055o. Lo dejo para después, y **solo si** la medida de s2 no llega a ≤ 3,0 s / ≤ 380 MB.
3. **¿El objetivo es ≤ 3,0 s y ≤ 380 MB en el dedicado exportado, con el servidor de salas no peor que hoy?** **Recomiendo que sí** (justificado en §10). Si s0 mide que el plugin solo ya da ≤ 2,8 s, el objetivo baja a eso.
4. **¿`CreatureType.icon` (y los íconos de hechizos y habilidades) se quedan en el tipo?** **Recomiendo que sí.** El export dedicado ya los cambia por un placeholder de bytes, y el libro, el plantel y el panel los necesitan sin cargar la apariencia. Moverlos obligaría a la UI a cargar 72 apariencias para dibujar un libro.
5. **¿Materiales horneados como overrides guardados en cada modelo y dentro de la malla de cada prop** (y no como «materiales externos» en el `.glb.import`)? **Recomiendo que sí.** Los `.glb` no traen materiales (`_subresources={}`, sin superficies con nombre), así que el import no tiene a qué engancharlos sin reexportar los 74 `.glb`. El override se ve y se cambia en el inspector, y la malla del prop sirve tal cual al `MultiMesh` de la flora.
6. **¿Los props (311 medidas, 243 partes de edificio, 39 especies, 6 consumidores de mallas) entran en 055s (s5a)?** **Recomiendo que sí.** Sin ellos no se borran `BodyCatalog` ni C19, que son el objetivo del corte, y van en paralelo con s2.
7. **¿Se renombran los 74 modelos a nombre humano (`eorc.tscn` → `trogg_model.tscn`, con su biblioteca y su carpeta de clips) en s6?** **Recomiendo que sí**, como último paso mecánico con `rename_resources.py`, antes de 055a-5. Los `.glb` del original no se renombran: son assets con el nombre de su archivo fuente.
8. **¿El cable conserva `model` (en la unidad, en el mago y en el pick)?** **Recomiendo que sí** en 055s, byte idéntico y derivado de `BodyFrame.model_id`. Sacarlo es un cambio de protocolo que va en la fase 3.
9. **¿«Cuándo hay mano» va como pista `visible` dentro de la `Animation` de cada rol (con `RESET`)?** **Recomiendo que sí**: da paridad exacta con hoy, se ve en la línea de tiempo y es nativo. La alternativa (mano siempre encendida) cambia la presentación en los clips que hoy no tienen mano. Si s0 muestra que el `Tree` no vuelve a `RESET`, la clave `false` se escribe en cada rol sin mano.
10. **¿Regla nueva C23 «presentación en tipos que lee el servidor»** (`@export` de `SoundSet`, `AudioStream`, `LookProfile` o `PackedScene` de apariencia en `*_type.gd`, con allowlist `body` e `icon`)? **Recomiendo que sí**, con base propia, para que no vuelva. `GodType.look` queda en la allowlist con fecha hasta la pregunta 2.
11. **Si s0 muestra que el `.tscn` no conserva el float32 exacto de un marcador o de una forma, ¿qué hacemos?** **Recomiendo** guardar esos valores como `@export_storage` double en `BodyFrame` (los escribe la herramienta y los copia el `@tool` cuando un humano arrastra el gizmo), y mantener los digests idénticos. La otra opción es regrabar la base sin ceremonia (memoria «Godot estándar antes que fidelidad»), pero el pedido es «digests idénticos».
