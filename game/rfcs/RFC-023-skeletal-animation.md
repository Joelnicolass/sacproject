# RFC-023 — Animación esquelética (esqueleto real desde el original)

Estado: plan del tech lead, pendiente de OK. Arquitectura **estándar**, MP **online con dedicado** (MpKit). Autoridad: PRD > FEATURES > RULES > VISUAL > RFC > este plan.
Pedido: que las animaciones vivan en nodos (`Skeleton3D` / `AnimationPlayer` / `AnimationTree`) y no como mallas por cuadro en caché. Opción elegida: **A, esqueleto real**. Nada del juego original va a git: el repo guarda estructura de nodos, scripts y alias; huesos, malla, pesos, clips y texturas salen de `cache/`.

## 1. Objetivo (criterios de aceptación)

- Un exportador propio genera desde la instalación (`saxs*.wad`) **un `.glb` por modelo** en `cache/skeletal/` con `Skeleton3D`, una malla con pesos y **todos** los clips SXSK del modelo como pistas de huesos.
- **Paridad de pose:** para cada clip, el cuadro N del `.glb` coincide con el OBJ horneado hoy (`cache/look/anim_f37/<m>/<tag>/N.obj`) dentro de 1 mm (máx.) por vértice, tras aplicar los mismos ejes/escala/`BodyPoseOverride`.
- Escena de cuerpo reutilizable (`body_rig.tscn`) con `AnimationPlayer` + `AnimationTree` (máquina de estados genérica por **rol**), `BoneAttachment3D` para manos y pistas de eventos; un modelo se mapea a sus clips con un `Resource` de alias.
- La simulación (ataque, disparo, casteo, `impact_frame`) **no depende** del esqueleto: el dedicado sigue sin mallas ni árbol de animación y da los mismos ticks que hoy.
- Unidades, mago, doctor, cautivo, fantasma y cadáver migrados; el horneado por cuadro (`anim_f37`, `ClipPosePlayer` de mallas) se retira al final.
- Rendimiento con 60 y 150 cuerpos animados **mejor o igual** que hoy en `look_bench` (hoy, tras el arreglo F66: 60 cuerpos en medio ≈ 8,3 ms/cuadro y ~330 MB de VRAM; `BodySeparation` ~7 ms por tick de física con 60).

## 2. Hechos verificados en el código

- Hoy los cuadros salen de **ejecutar el binario de sacengine** (`export_stats.py:_export_all_frames`, `export-all-frames:`): 32 modelos, **1,6 GB de OBJ** en `cache/look/anim_f37` + 166 MB en `cache/baked`. `ClipPosePlayer` cambia `MeshInstance3D.mesh` por cuadro (caché estática por clip).
- Los roles hoy son pocos: `unit_body._clip_roles()` → `idle`, `run` (walk o run), `attack` (melee[0]); `doctor_body` agrega `work_<slot>`; mago `idle`/`run`.
- **La simulación ya no lee `ClipPosePlayer`:** `melee_attack.gd`/`ranged_attack.gd` leen `attack_ticks`/`shoot_ticks`/`frames`/`framerate` de `CreatureType` (de `creatures.json`, `export_stats.py`); el casteo usa `casting_time_s`. `impact_frame()` del player solo alimenta `debug_clip_info()`.
- Lo replicado ya es **estado lógico**: `mode` de la unidad, `pose` del doctor (`MultiplayerSynchronizer`). No se replica pose de malla.
- Formato (sacengine GPL-3, **solo lectura para entender; no se copia código**): `saxs.d` — huesos con `parent < i`, posición relativa al padre y **sin rotación de reposo**; cada vértice tiene **≤ 3 influencias** (`int[3] indices`), cada una con **su propio `offset` en espacio del hueso**, peso `/16384`, normal; mallas por `bodyParts` con costuras; `zfactor` escala `displacement.z`. `sxsk.d` — `numFrames`, `referenceHeight`, `numBones ≤ 32`, por cuadro desplazamiento + quaternion por hueso (ejes `fromSXMD`), eventos SKEL (`sound/attack/load/shoot/cast_/death/grab/foot`) y `hands[2]` (hueso + offset por clip).

## 3. Decisiones técnicas

### 3.1 Formato de salida: `.glb` escrito en Python, importado por Godot
- **Recomendado: `.glb`** (glTF 2.0 binario) escrito por `tools/export_skeletal.py` (Python puro, `struct`, sin dependencias). Por qué: Godot lo importa nativo (esqueleto, skin, animaciones, tangentes), se abre y previsualiza en el editor, es inspeccionable con herramientas externas (Blender, validador glTF), y el exportador no necesita correr Godot ni sacengine. Un `.res` generado por script de Godot ata el exportador al editor y no se puede validar fuera.
- Import (`.glb.import` generado por el exportador en `cache/`, nunca en git): `animation/import=true`, `animation/fps=30` (o el `framerate` del clip), `meshes/ensure_tangents=true`, `skins/use_named_skins=true`, sin materiales embebidos (`materials/extract` no aplica: el `.glb` no trae materiales).
- Ejes y escala: aplicar en el exportador **la misma** conversión que hoy produce los OBJ (`fromSXMD` + `scaling` de sacengine + el cambio sac→Godot de `obj_mesh.gd`/`_from_sxmd`). La paridad numérica (3.2) es la prueba; no se ajusta a ojo.
- Reposo: hueso 0 = raíz identidad; rest de cada hueso = `Transform3D(Basis(), bone.position)`; matriz inversa de bind = traslación por `-pos_absoluta`.
- **Pesos:** ≤ 3 por vértice → cabe en 4 (relleno con 0, normalizado). Riesgo: cada influencia trae su offset; Godot exige **una** posición de bind. Se usa `v_bind = Σ w·(pos_abs(hueso)+offset)`; el exportador mide la discrepancia entre influencias por vértice y la reporta (si supera 1 mm, la paridad lo atrapa).
- **Malla única por modelo** (todas las `bodyParts` como superficies de un mismo `ArrayMesh`, compartida entre instancias). Tangentes generadas por Godot al importar → **simplifica 022g** (los mapas de normales necesitan tangentes estables; hoy cada cuadro OBJ es otra malla).
- **Materiales:** no van en el `.glb`. Se reusa `ObjMesh`/`body_material.gd` (textura + chroma key de SAXS, material compartido por textura) vía `set_surface_override_material`. El fantasma sigue duplicando por instancia (`transparency`/material propio).
- **Root motion:** el `displacement` del SXSK (con `zfactor`) va como pista de posición del hueso raíz `root`. Por defecto se **reproduce en el lugar** (igual que hoy: la sim mueve el cuerpo). `AnimationTree.root_motion_track` queda disponible para efectos de presentación (caída del cadáver, retroceso); nunca mueve la entidad simulada.
- **Eventos:** el `.glb` no los lleva. El exportador los escribe en `index.json` (`clips[tag].events`: [{frame, kind, parameter}]; ya no hay `.events.json`, 023b). Al construir la librería (una vez por modelo, estática) se agrega una **pista de método** que llama `ClipEvents.fire(kind)` en ruta relativa fija (`%ClipEvents`), compartida por todas las instancias. Solo presentación (pasos, sonidos, chispa de golpe).
- **Interpolación:** lineal por defecto (más suave que el original); knob global `BodyAnimSettings.stepped := false` que pone `INTERPOLATION_NEAREST` para comparar contra el original cuadro a cuadro.

### 3.2 Exportador y validación
- Entradas: `INSTALL/saxs*.wad` (SXMD + SXSK + SKEL), índice ya resuelto por `export_stats.index_saxs_*` y el lector `ex` de `export_persephone.py` (se importan, no se duplican).
- Salidas: `cache/skeletal/<m>.glb`, `<m>.glb.import`, `cache/skeletal/index.json` (modelo → clips, frames, framerate, huesos de mano por clip, discrepancia de bind, altura de referencia).
- Exporta **todos** los clips del modelo, no solo los de `_collect_mesh_clip_tags` → aparecen `thrash`/`rise` del cautivo y los de vuelo.
- Validación `tools/audit_skeletal.gd` (headless, sin ventana): por modelo y clip, instancia el `.glb`, hace `seek` a cuadros {0, mitad, último}, lee vértices skinneados en CPU (`Skeleton3D` global pose × skin) y compara con el OBJ del mismo cuadro; tabla `model / clip / frame / max_err_mm`. Falla si > 1 mm. Mientras exista `anim_f37`, es la red de seguridad.

### 3.3 Árbol de nodos (repo)
```text
BodyRig (Node3D, body_rig.gd, @tool)      # thin: carga modelo, arma libreria, expone play(role)
├── %ModelSlot (Node3D)                   # el .glb instanciado aca en runtime, owner = null
├── %Anim (AnimationPlayer)               # root_node -> ModelSlot; libreria "role" armada en runtime
├── %Tree (AnimationTree)                 # StateMachine: idle, move(BlendSpace1D walk/run), attack, shoot, cast, hit, death, held, thrash, rise, fly
├── %HandL / %HandR (BoneAttachment3D)    # bone_name asignado desde index.json; sockets de arma/FX
└── %ClipEvents (Node)                    # señal clip_event(kind); objetivo de las pistas de metodo
```
- La máquina de estados usa **nombres de rol** (`role/idle`, `role/attack`…), no tags. `BodyClips.tres` (Resource por modelo o default derivado de `CreatureType`) da alias rol → tag; la librería `role` reusa los `Animation` del `.glb` (`add_animation(role, anim)` comparte el recurso, sin copia). Rol sin clip → el estado cae a `idle` (como hoy).
- Transiciones y mezclas (`xfade` 0,1–0,2 s, attack/shoot/cast como one-shot que vuelven a move/idle) son **datos del `.tscn`** en git, editables en el editor.
- `@tool`: en el editor, con caché presente, `BodyRig` instancia el modelo de `preview_model` y reproduce `preview_role` (se ve el cuerpo animando en `body_gallery`). **Sin caché**: no rompe; muestra la cápsula/placeholder y un `_get_configuration_warnings()` «falta cache/skeletal/<m>.glb».
- **Nada derivado se guarda:** todo lo instanciado en `%ModelSlot` y la librería `role` se crean con `owner = null` y `libraries` vacías en el `.tscn`. Esto cierra el bug de `unit.tscn` embebiendo texturas (y el `.tscn` se valida con un grep en review: sin `ExtResource` a `cache/`).

### 3.4 Simulación y red
- **Dedicado:** `BodyCatalog.loads_meshes() == false` → `BodyRig` no instancia modelo ni procesa el árbol (`active = false`, `process_mode = DISABLED`). Los ticks de ataque/disparo y `casting_time_s` siguen viniendo de `CreatureType` (ya es así).
- Lo que hoy da el reloj headless de `ClipPosePlayer` (rol, cuadro, `impact_frame` para `debug_clip_info`/flows) pasa a **`ClipClock`** (RefCounted, puro): rol + tiempo + datos de clip (`frames`, `framerate`, ticks) desde `CreatureType`/`index.json` sin mallas. Corre igual en dedicado y cliente; el visual **lee** el clock (rol y tiempo) y hace `travel`/`seek`, nunca al revés.
- Red: se replica el **estado lógico** existente (`mode`, `pose` del doctor, inicio de ataque si hace falta como tick). Cliente: al cambiar a ATTACK, `travel("attack")` + `seek(tiempo_desde_inicio)` para alinear golpe visual con el tick del servidor. No se replica pose ni tiempo de animación por cuadro.

### 3.5 Compatibilidad
- `BodyPoseOverride` (`rotation_degrees`, `position_offset`, `model_scale`, cápsula, `reach`): se aplica a `%ModelSlot`, igual que hoy al `Mesh`. Re-auditar `pose_overrides.tres` con `audit_body_pose.gd`: algunas correcciones (`sacd`, `pcfn`, `sbob`) pueden sobrar si el reposo del esqueleto ya es correcto; el **doctor desplazado de su cápsula** y la **altura de Brainiac** (`referenceHeight`/`scaling`) se revisan en ese pase.
- Fantasma: material por instancia sobre las superficies del skinneado (mismo mecanismo de hoy). Cautivo `HELD`/`REVIVING`: roles `held`/`thrash`/`rise`. Cadáver: `death` y quedarse en el último cuadro (sin `Tilt` manual si el clip ya cae). `BodySeparation` y selección usan cápsula/AABB: AABB de la malla skinneada es estático → fijar `custom_aabb` desde `index.json`.
- `BodyCatalog`: suma `skeletal_scene(model)` y `has_skeletal(model)`; el resto (props, mallas estáticas) sigue igual.
- Retiro (023h): `ClipPosePlayer` (lado malla), `anim_f37`, `anim_mesh_clips_f37.json`, `_export_all_frames`/`export_f37_mesh_clips`, horneado de cuerpos animados en `bake_bodies.gd`. Se mantiene horneado estático de props/edificios.

### 3.6 Rendimiento
- Skinning en GPU (Forward+ lo hace por compute): 150 cuerpos × ≤ 32 huesos × pocos miles de vértices es despreciable en el M4. Memoria: **una malla por modelo** + clips (KB) frente a una malla por cuadro (cientos de MB): se espera bajar de GB a decenas de MB.
- CPU: `AnimationTree` por cuerpo es lo caro. Mitigación (en 023g si la medición lo pide): `callback_mode_process = MANUAL` y un `BodyAnimLod` que avanza a 30 Hz cerca y 10–15 Hz lejos, pausa fuera de cámara (`VisibleOnScreenNotifier3D`); cuerpos lejanos solo `AnimationPlayer` sin árbol.
- Medición: `debug/look_bench.tscn --units=60` y `--units=150` (ms/cuadro, VRAM) y `agent/perf/perf_probe.tscn`, antes (horneado) y después, mismo preset. Registrar en este RFC.

## 4. Escena de prueba

`res://debug/skeletal_compare.tscn`: dos columnas lado a lado, mismo modelo y clip — izquierda `ClipPosePlayer` (horneado actual), derecha `BodyRig` — con luz neutra y cámara fija. Estado inicial: `eorc` en `idle`; **todavía no** cicla roles. Acciones del InputMap (debug): `ui_right`/`ui_left` cambia modelo, `ui_up`/`ui_down` cambia rol, `ui_accept` alterna `stepped` (interpolación original vs suave). Un `.tres` de debug (`skeletal_compare_jnwr.tres`, mismo script) arranca en `jnwr` + `cast` con espada/mano visible. Las familias se verifican en las escenas existentes (`body_gallery`, `look_bench`, `doctor`, `anim_wizard_trogg`).

## 5. Árbol de archivos (N nuevo, M modificado)
```text
game/
├── tools/
│   ├── export_skeletal.py            N  WAD -> .glb + .import + events + index (cache/)
│   ├── audit_skeletal.gd             N  paridad de vertices vs OBJ horneado (headless)
│   ├── export_stats.py               M  023h: retira export-all-frames
│   └── bake_bodies.gd                M  023h: sin cuerpos animados
├── scenes/world/body/                N
│   ├── body_rig.tscn / body_rig.gd   N  rig reutilizable (Player, Tree, manos, eventos)
│   ├── clip_events.gd                N  pista de metodo -> señal clip_event(kind)
│   └── clip_clock.gd                 N  reloj logico de clip (sin mallas)
├── scenes/data/body_clips.gd         N  Resource: alias rol -> tag, manos
├── data/bodies/clips/*.tres          N  solo modelos con alias especiales (resto: default desde CreatureType)
├── scenes/world/body_catalog.gd      M  skeletal_scene / has_skeletal
├── scenes/world/unit_body.gd, wizard/wizard_body.gd, sacrifice/doctor_body.gd,
│   units/captive.gd, units/corpse.gd, wizard/ghost_form.gd   M  play(role) sobre BodyRig
├── scenes/world/units/unit.tscn, wizard/wizard_body.tscn, sacrifice/doctor.tscn   M  ClipPosePlayer -> BodyRig
├── scenes/world/components/clip_pose_player.gd   M→retirado en 023h
└── debug/skeletal_compare.tscn/.gd + skeletal_compare_jnwr.tres   N
cache/skeletal/<m>.glb, .glb.import, index.json      (no git)
```

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `export_skeletal.py` | Traducir SAXS/SXSK/SKEL a glTF | Herramienta | Separado de `export_stats` (stats ≠ geometría); reusa su índice |
| `audit_skeletal.gd` | Probar paridad numérica | Herramienta | Corre en Godot (skin real); el exportador no |
| `body_rig.tscn/.gd` | Cargar modelo del caché y reproducir roles | Packed + nodo | Lo usan 6 cuerpos; no sabe de reglas |
| `AnimationTree` (en `body_rig.tscn`) | Estados, transiciones, mezclas | Nodo (datos en .tscn) | Editable en editor; no en código |
| `clip_events.gd` | Traducir pistas de evento a señal | Nodo | Objetivo estable de pistas compartidas |
| `clip_clock.gd` | Rol/tiempo/ticks sin mallas | RefCounted | Corre en dedicado; el rig no |
| `body_clips.gd` + `.tres` | Alias rol → tag por modelo | Resource de tipo | Otro modelo = otro `.tres` |
| `body_catalog.gd` | Saber qué hay en caché | Estático | Ya es el índice de cuerpos |
| `skeletal_compare.tscn` | Lado a lado horneado vs esqueleto | Debug | Solo hasta 023h |

Resource de tipo: `BodyClips`, `BodyPoseOverride`, `CreatureType`. Nodo: `BodyRig` y sus hijos. `@export` de instancia: `BodyRig.clips: BodyClips`, `preview_model`, `preview_role`, `lod_far_hz`.

Corre en — editor: rig con preview (si hay caché); cliente: rig + árbol + `ClipClock`; dedicado: solo `ClipClock`/`CreatureType`.

## 6. Sub-cortes

| Corte | Qué | Criterio verificable |
|---|---|---|
| **023a** Exportador + paridad | `export_skeletal.py`, `audit_skeletal.gd` para **`eorc`** (simple, ya referencia F36) y **`jnwr`** (mago, manos/casteo) | Tabla de paridad ≤ 1 mm en todos los clips; `.glb` abre en el editor y anima |
| **023b** Rig + comparador | `body_rig.tscn`, `ClipEvents`, `BodyClips`, `skeletal_compare.tscn` | Capturas lado a lado idénticas en cuadros 0/mitad/fin; con `stepped` coincide cuadro a cuadro; sin caché: aviso, sin error |
| **023c** Unidades | `unit.tscn` usa `BodyRig`; `ClipClock` reemplaza el reloj headless | Flows de ataque/disparo con mismos ticks (log dedicado); captura vs horneado y vs sacengine; `unit.tscn` sin `ExtResource` a `cache/` |
| **023d** Mago + manos | `wizard_body`, `BoneAttachment3D` (FX de casteo en la mano) | Captura del casteo: FX sigue la mano; contra el original (REA/captura) |
| **023e** Doctor + cautivo | `doctor_body`, `captive` con `held/thrash/rise`; revisar desplazamiento de cápsula | El cautivo forcejea en el aro; doctor centrado en cápsula (`audit_body_pose`) |
| **023f** Fantasma + cadáver + voladoras | translucidez por instancia, `death`, vuelo | Fantasma translúcido sin afectar a otros; cadáver cae con su clip |
| **023g** Rendimiento | medir y, si hace falta, `BodyAnimLod` | `look_bench` 60/150: ms y VRAM ≤ hoy (objetivo: 60 cuerpos ≥ 60 fps) |
| **023h** Retiro | quitar `anim_f37`, horneado por cuadro, `ClipPosePlayer` de mallas | `rg anim_f37` vacío; regresión de flows f19/f23/f32 y RFC-022 |

Cada corte: developer → reviewer → **playtester con ventana y capturas** (no se saltea). Exportar sigue `INSTALL` fijo como hoy.

## 7. Coordinación con RFC-022

- El hallazgo de 022a (190 ms, 7,7 GB con 60 cuerpos) ya se resolvió en F66 (materiales y mallas compartidos). 023 no es requisito para medir 022; sí conviene que 022g (normales y AO de modelos) se haga sobre la malla esquelética.
- 022g (normales/AO de modelos originales) se hace **sobre la malla esquelética** (una por modelo, tangentes del import), no sobre OBJ por cuadro: 022g espera a 023c o, como mínimo, 023b.

## 8. Riesgos

- **Offsets por influencia** (bind no único): medido por el exportador; si un modelo falla, se aísla (queda horneado) y se reporta.
- **Ejes/escala/`zfactor`/`referenceHeight`**: solo la paridad contra OBJ los cierra; no ajustar a ojo.
- **Eventos SKEL** mal alineados o con parámetro desconocido (`SkelEvent.parameter`): solo presentación; la sim no los usa.
- **Manos por clip** (`hands` varía por clip; `yogo` tiene un arreglo especial en sacengine): `BoneAttachment3D` cambia `bone_name`/offset al cambiar de clip, desde `index.json`.
- **Costuras** (`seamFace*`) y normales: el original regenera normales por cuadro; el skinning las transforma: puede verse distinto en pliegues → comparar en capturas.
- **Licencias:** sacengine es GPL-3: exportador escrito desde el formato, sin copiar código; nada del original en git (`cache/` ignorado; review lo chequea).
- `AnimationTree` × 150 en CPU (ver 3.6).

## 9. Fuera de alcance

IK, ragdoll, retarget entre modelos, animaciones nuevas hechas a mano, root motion que mueva la simulación, props/edificios (siguen horneados), mapas de 022g.

## 10. Cómo verifica un humano

1. Correr `export_skeletal.py`; abrir `cache/skeletal/eorc.glb` en el editor: esqueleto, malla y clips en el panel de animación.
2. F6 en `debug/skeletal_compare.tscn`: ciclar modelos/roles; alternar `stepped` y ver que coincide con el horneado.
3. Abrir `body_rig.tscn`: `AnimationTree` → editar la máquina de estados; inspector de `BodyRig` con `preview_model`.
4. F5 partida 1P y online con dedicado: unidades atacan/disparan al mismo ritmo; mago castea con FX en la mano.
5. Guardar `unit.tscn` desde el editor y `git diff`: sin texturas ni rutas a `cache/`.

## 11. Preguntas abiertas (con recomendación)

1. **Paridad exigida** — (a) ≤ 1 mm vértice a vértice **[recomendado]**; (b) solo visual por capturas; (c) ≤ 1 cm.
2. **Interpolación por defecto** — (a) lineal suave, `stepped` como knob **[recomendado]**; (b) escalonada como el original; (c) por modelo en `BodyClips`. (Confirmar con REA si el original interpola entre cuadros.)
3. **Root motion** — (a) en el lugar, pista disponible para presentación **[recomendado]**; (b) extraído y aplicado a la visual del cuerpo (desliza respecto a la sim); (c) aplicado a la sim (rompe el dedicado: no).
4. **Modelos de prueba** — (a) `eorc` + `jnwr` **[recomendado]**; (b) `gobl` + `sacd` (doctor, resuelve su desplazamiento antes); (c) `huma` + `jnwr`.
5. **Dónde viven los eventos** — (a) sidecar JSON + pistas de método agregadas en runtime **[recomendado]**; (b) extras glTF → metadata; (c) solo `index.json` leído por `ClipClock`.
6. **Retiro del horneado** — (a) en 023h tras todas las familias **[recomendado]**; (b) por familia al migrarla; (c) mantenerlo como fallback permanente.

## Decisiones del usuario (2026-10-14)

1. **Interpolación:** suave (lineal entre cuadros) por defecto, con una perilla para volver al escalonado del original; confirmar con REA cómo lo hacía el juego.
2. **Desplazamiento:** en el lugar; la animación nunca mueve la simulación.
3. **Modelos de prueba:** `eorc` (criatura simple) y `jnwr` (mago con manos).
4. **Cuándo:** después de cerrar el pasto (022e1) y el pase de paleta de la pradera.

## Nota del orquestador (2026-10-16, REVIEW-F112)
En sacengine la pose de reposo es `stance1` (slot 0, offset 176), y los `idle0..3` son gestos que salen al azar con probabilidad 1/5 (`state.d:7957-7992`). Hoy el port usa `idle0` como idle en loop. La actualización de este RFC tiene que pasar todas las criaturas a `stance1` como reposo y dejar `idle0..3` como gestos. En F112 solo se horneó la pose de las 35 nuevas desde `stance1`.

## Decisión del usuario (2026-10-17)
El pasto se apaga de forma provisoria (`grass_enabled = false` en `data/look/quality_{low,medium,high}.tres`) y queda para el final. RFC-023 ya no espera a 022e1: arranca con 023a.

## Decisión del usuario (2026-10-17): sin caché en el port final
- El port final no depende de `cache/`. Cada modelo es un asset propio: `game/assets/original/models/<m>.glb`, con esqueleto, malla y todas sus animaciones, uno por modelo. No hay mallas por cuadro.
- Esos assets **se commitean** (git LFS para `.glb` y `.png`), y sus `.import` también. RULES.md se actualizó; los WAD siguen fuera de git.
- `export_skeletal.py` es el importador que los genera desde la instalación; se corre al agregar o regenerar modelos, no en cada arranque.
- Cambia §3.1: «`.glb.import` en `cache/`, nunca en git» pasa a «`.glb.import` versionado junto al `.glb`». §3.3: `BodyRig` lee de `assets/original/models/`; el aviso sin caché pasa a «falta el asset».
- Las texturas de los cuerpos (hoy en `cache/`) migran a `assets/original/textures/` en un corte posterior. El resto de la caché (terreno, props) se planifica en un RFC aparte.

## 023a: Resultado (developer, 2026-10-17; ronda de corrección tras REVIEW-RFC-023a)

Entregado: `tools/export_skeletal.py` (salida por defecto `assets/original/models/`, `--out`), `tools/export_skeletal_reference.py` (OBJ de referencia desde sacengine, fuera de git, `agent/out/skeletal_ref/`), `tools/audit_skeletal.gd` (`MODELS_DIR` es la única ruta; `--ref=DIR` usa la referencia de sacengine; sin `--ref` usa `cache/look/anim_f37`), `.gitignore` (`!assets/original/**/*.import`). Generados: `eorc` (19 huesos, 51 clips) y `jnwr` (32 huesos, 39 clips), 3,1 MB.

Regenerar y auditar (desde `game/`, Godot siempre por `agent/harness/godot_run.sh`):
1. `python3 tools/export_skeletal.py` y `godot --headless --path . --import`.
2. `python3 tools/export_skeletal_reference.py` (ejecuta el binario de sacengine, ~8 min para los 90 clips).
3. `godot --headless --path . --script res://tools/audit_skeletal.gd -- --ref=<abs>/agent/out/skeletal_ref`.

Paridad contra la exportación OBJ de sacengine (con la corrección de desplazamiento por `referenceHeight`, sin umbral), TODOS los clips, cuadros {0, mitad, último}: **90 de 90 clips, 270 filas, PASS**.

| modelo | clips auditados | max_err_mm | vértices sin normalizar |
|---|---|---|---|
| eorc | 51 de 51 | 0,31 | 0 |
| jnwr | 39 de 39 | 0,22 | 1 (error previsto 3,95 mm, medido 4,08 mm) |

Vértice sin normalizar de `jnwr` (superficie 1, vértice 208 escrito; pesos 1,0 + 0,0061 = 1,006): sacengine usa el peso crudo y suma el desplazamiento de raíz fuera de la suma ponderada; el `.glb` normaliza (glTF lo exige). Diferencia = |suma−1|·|p−D| (D = desplazamiento de raíz). Está en `index.json` → `unnormalized_vertices` (vértices con |suma−1| > 0,002) y el audit los compara con `p = D + suma·(p_normalizado − D)` (error restante ≤ 0,22 mm), reportando el previsto y el medido. No se reproduce en glTF.

Huesos auxiliares (offset por influencia; glTF tiene una sola posición de bind por vértice): la influencia principal usa el hueso real; solo los vértices cuyas influencias discrepan más de 0,5 mm (`BIND_THRESHOLD`) reciben huesos auxiliares (hijos del hueso, sin animar, bind desplazado cuantizado a 0,5 mm, `SHIFT_STEP`). El resto usa el bind promediado con huesos reales (error < 0,5 mm).

| modelo | huesos reales | auxiliares antes (0,05 mm, sin umbral) | auxiliares ahora (0,5 mm) | total ahora |
|---|---|---|---|---|
| eorc | 19 | 286 | 263 | 282 |
| jnwr | 32 | 208 | 198 | 230 |

Barrido de umbral = paso (mm) → auxiliares eorc / jnwr: 0,5 → 263/198; 1 → 219/129; 2 → 143/14; 3 → 106/0; 5 → 97/0. Con 1 mm de presupuesto no se baja de ~64: `eorc` necesitaría un umbral por encima de 5 mm (error de varios mm). Si pesa en 023g, la salida es skinning propio en shader con los offsets por influencia en `CUSTOM`, o aceptar un umbral mayor en modelos puntuales (`--bind-threshold-mm`, `--shift-step-mm`).

Otros hallazgos:
- El import del editor regenera tangentes (mikktspace) y reordena vértices: el audit lee el `.glb` con `GLTFDocument` (mismo orden que el exportador) y comprueba aparte que `load()` del importado funciona. El import corre sin errores ni avisos.
- Un vértice sin caras (último de la superficie 10 de `jnwr`) no se escribe: `index.json` → `dropped_vertices`.
- Las pistas constantes iguales al reposo (p. ej. hueso 17 de `jnwr`, identidad) las descarta el importador de glTF: el audit parte de `reset_bone_poses()` antes de cada seek; **023b tiene que resetear el esqueleto al cambiar de clip** (o dejar que `AnimationPlayer` lo haga con una pista RESET), si no la pose del clip anterior queda en esos huesos.
- La caché global de poses de `Skeleton3D` queda vieja tras `seek` en headless: el audit calcula las poses globales desde las locales.
- Orientación de caras comprobada: tras el import las caras exteriores son frontales en ambos modelos. No se verificaron materiales ni tangentes.
- `index.json` guarda por clip frames, framerate, `reference_height`, manos (hueso + offset crudo) y eventos, con rutas relativas a la carpeta. AABB solo en reposo (`bind_aabb`): 023b fija un `custom_aabb` con margen.

## Enmienda del criterio de paridad (orquestador, 2026-10-17, REVIEW-023a)
«≤ 1 mm por vértice» valía salvo para los vértices cuyos pesos no suman 1 en el original (sacengine no normaliza). Esos se listan en `index.json` → `unnormalized_vertices` con su error previsto |suma−1|·|p−D|, y el audit los compara contra esa posición escalada. La referencia de paridad es la exportación OBJ de sacengine (`tools/export_skeletal_reference.py`, todos los clips en {0, mitad, último}), no los OBJ horneados. La cantidad de huesos auxiliares (eorc 282, jnwr 230 en total) se mide en 023g; si pesa, la salida es skinning en shader o un umbral por modelo.

## 023b: Resultado (developer, 2026-10-17)

Entregado: `scenes/world/body/body_rig.tscn/.gd` (`@tool`; `%ModelSlot`, `%Anim`, `%Tree` con máquina de 11 estados por rol y 110 transiciones en el `.tscn`, `%HandL/%HandR` con hijo `Socket`, `%ClipEvents`), `clip_events.gd`, `scenes/data/body_clips.gd` (rol → tag), `data/bodies/clips/{eorc,jnwr}.tres`, `OriginalAssets.models_index()`, `debug/skeletal_compare.tscn/.gd`, `debug/skeletal_compare_setup.gd` + `skeletal_compare_jnwr.tres`. El `.tscn` y los `.tres` no tienen `ExtResource` a `cache/` (grep vacío).

Cómo probarlo: F6 en `debug/skeletal_compare.tscn` (izquierda horneado, derecha esqueleto; `ui_left/right` modelo, `ui_up/down` rol, `ui_accept` `stepped`). Jadugarr casteando: `-- --setup=res://debug/skeletal_compare_jnwr.tres`. Medición: `godot --path game --max-fps 60 --resolution 1280x720 res://debug/skeletal_compare.tscn -- --capture=<dir abs>` (usa ventana; escribe PNG y `report.txt`). PNG de esta corrida en `game/agent/out/023b/` (fuera de git).

Medición (cámara ortográfica fija, ambos lados desde el mismo punto, cuadros 0 / mitad / último, eorc `idle`/`run`/`attack`, jnwr `idle`/`run`; el horneado solo existe para esos clips): 30 de 30 capturas dentro del umbral (píxeles que solo dibuja un lado ≤ 0,5 % del cuerpo, diferencia media de canal ≤ 6/255). Corrida final (con las claves completas): peor silueta 0,016 % en estas capturas, `stepped` y suave coinciden con el horneado cuadro a cuadro (`stepped` a +0,4 de cuadro igual al cuadro); diferencia media 0,7–2,8. Esa diferencia residual es de normales (el horneado trae las normales por cuadro de sacengine, el skinneado las del reposo transformadas), no de pose. Con `stepped` el resultado coincide con el horneado cuadro a cuadro. A 0,4 de cuadro pasado el medio: `stepped` queda igual al cuadro (silueta 0–0,25 %), suave se aleja (2,4–14,7 %): la perilla funciona. `eorc` (282 huesos) se ve bien renderizado: textura y volumen coinciden con el horneado en todas las capturas. Cambio de rol: `play(a)` + avance + `play(b)` contra `play(b)` solo, todos los pares de roles de ambos modelos: diferencia máxima de pose 0,000000 (`deterministic = true` en `%Anim` y `%Tree` repone los huesos que el clip nuevo no anima; `pose_at` además llama `reset_bone_poses()`).

Hallazgos y decisiones:
- **El importador de escenas recorta claves** (eorc `idle`: 2242 → 1441 claves de rotación, error hasta 0,004 rad) e ignora sus propias opciones. Probado con un solo Godot y un solo clip (eorc `HUi1`, contando claves): `_subresources` por clip con `optimizer/enabled=false` → 1441; con `optimizer/enabled=true` y los tres errores en 0,0 → 1441 (las claves se guardan tal como las escribe el editor y se conservan al reimportar; la prueba de que el plomo llega: `settings/loop_mode` por clip sí se aplica). Sale con un script de postimportación: `tools/skeletal_post_import.gd` (`import_script/path` en el `.glb.import`, que escribe `export_skeletal.py`) vuelve a poner cada clip tal como lo guarda el `.glb` (leído con `GLTFDocument`, sin quitar pistas constantes) → **2242 de 2242**. Con eso `stepped` usa las claves reales (solo `INTERPOLATION_NEAREST`); se quitó `_resampled` y `STEP_BIAS_S`. Con las claves completas el suave también queda dentro de la paridad del `.glb`.
- Variantes de animación (bucle, `stepped`, eventos) son copias en caché estática por modelo; los clips importados no se tocan. Los clips en bucle duran `frames/fps` (el original muestra `frames` cuadros por ciclo y vuelve); los de un disparo mantienen el último cuadro.
- Eventos: se leen de `index.json` (`clips[tag].events`, única fuente; se quitó `.events.json` del exportador y de `assets/original/models/`) y se agregan como pista de método `../../ClipEvents` → `fire(kind)`.
- Ejes: el `.glb` está en los ejes del OBJ; `BodyRig` pone `scale.z = -1` al modelo instanciado (como `MIRROR_Z` del horneado). `%HandL/%HandR` llevan un `Socket` con `scale.z = -1` que cancela el espejo; su posición es el `offset_raw` de la mano del clip (misma conversión que `to_obj`). Sin validar contra el original (es de 023d).
- `custom_aabb` desde `bind_aabb` más `aabb_margin` (0,5 m).
- Sin asset: `_get_configuration_warnings()` + `push_warning`, sin error. En headless el rig queda inerte (`process_mode = DISABLED`).
- Desvíos: el `.tres` de debug no comparte script con la escena (usa el Resource `SkeletalCompareSetup`). Los roles `idle` usan `HUi1`/`jwi1` (lo que hornea hoy el port); el paso a `stance1` queda para 023c. La máquina no tiene BlendSpace1D walk/run (un solo estado `run`). Los `BoneAttachment3D` sin esqueleto en el editor muestran su aviso propio.
- `agent/run_determinism.sh quick`: hash idéntico en los tres modos (44d78b49…) y las líneas de baseline en OK; el veredicto salió FAIL solo por `contaminated=1` (otro agente corría Godot en paralelo). La simulación no se tocó.

What: BodyRig (rig esquelético por roles), BodyClips, ClipEvents, comparador horneado vs esqueleto. Why: 023c necesita un cuerpo reusable que reemplace a `ClipPosePlayer`. Where: `scenes/world/body/`, `scenes/data/body_clips.gd`, `debug/skeletal_compare*`. Learned: el importador de escenas de Godot recorta claves aunque se desactive `optimizer/enabled` (se arregla con un `EditorScenePostImport`); `deterministic = true` resuelve el reseteo de huesos entre clips.

## 023c: Resultado (developer, 2026-10-17)

Entregado: `unit.tscn` usa `BodyRig` (`Tilt/Mesh/Rig`, hijo del `BodyVisual`: hereda la pose, la escala de la cápsula y `DevourGrowth`) y un `BodyAnimator` en el nodo `ClipPose`. `ClipClock` (RefCounted, `scenes/world/body/clip_clock.gd`) lleva rol, tag, cuadro, framerate e `impact_frame` (el primer evento `attack` de `index.json`); corre igual en dedicado y cliente y reemplaza al reloj headless de `ClipPosePlayer`. El visual lee el clock: `BodyAnimator` hace `play`/`travel` al rol del clock y `seek` (`BodyRig.play(role, restart, at)`) si el modelo llega con el clock ya andando. El dedicado no carga modelo ni árbol (`BodyRig` inerte; el animator solo corre el clock). Nuevos: `ClipPlayback` (contrato común de `ClipPosePlayer` y `BodyAnimator`; `Afflictions`/`Stunned` hablan con él), `UnitClipRoles` (rol → tag desde `CreatureType`; salió de `unit_body.gd`), `BodyClips.from_roles`, `BodyCatalog.has_skeletal`, nueve roles nuevos en la máquina de estados (`cower talk_cower work takeoff land knock get_up fly_damage gesture`, 381 transiciones generadas), `BodyVisual.set_fade`/`use_skeleton`, `StoneLook` sobre las mallas del rig, `CreatureType.stance_animation`. `unit.tscn` sin `ExtResource` a `cache/` (grep vacío). `unit_body.gd`: 1017 líneas (≤ 1040).

Modelos: exportados los 69 de las criaturas (`assets/original/models/`, 79 MB, LFS). **58** dibujan con esqueleto; **11** quedan horneados porque el SXSK propio no trae los clips que usa su criatura (híbridos `…H`: faez, thes, the2, sara, hoom, bane, ban2, sirc, surt, gamm, baby; solo 1 clip, ya eran cuerpos estáticos antes). Paridad contra la exportación de sacengine (`export_skeletal_reference.py --unit-clips`, `audit_skeletal.gd --clips= --ref=`), los 446 clips que juegan las unidades en los cuadros {0, mitad, último} (1338 filas): **PASS, máximo 0,46 mm**, ningún modelo con filas fuera de 1 mm. Máximo por modelo (mm): AArc 0,36 · FAmr 0,02 · aclw 0,22 · adrg 0,31 · apez 0,16 · aprc 0,23 · babc 0,34 · bala 0,30 · bale 0,35 · buga 0,32 · bugf 0,24 · bugl 0,37 · bugz 0,27 · dcak 0,20 · ddiz 0,32 · ddmn 0,28 · dflp 0,24 · dklp 0,42 · dpez 0,23 · drag 0,25 · dslg 0,14 · eber 0,17 · ecak 0,24 · eclw 0,44 · edmn 0,31 · ehbt 0,20 · eklp 0,34 · eorc 0,30 · epez 0,44 · eslg 0,16 · estm 0,42 · fcak 0,19 · fclw 0,44 · fdrg 0,41 · fdzy 0,18 · fflp 0,27 · fhbt 0,09 · fklp 0,36 · fpez 0,14 · ftrl 0,46 · gobl 0,26 · gund 0,24 · gunf 0,20 · gutc 0,24 · huma 0,37 · humn 0,43 · lflp 0,28 · lhbt 0,33 · ltrl 0,46 · maho 0,19 · peas 0,42 · prcy 0,22 · sacd 0,31 · sbob 0,22 · sogr 0,18 · sprg 0,44 · sprl 0,42 · stmp 0,23. `BodyCatalog.SKELETAL_FALLBACK` queda vacía: ningún modelo falló la paridad; los 11 de arriba caen solos porque `has_clip(idle)` es falso.

Capturas en partida, cámara fija (`debug/rig023c/rig023c_shots.tscn`, `--max-fps 60 --resolution 1280x720`; la misma escena con y sin `--baked-bodies`, `agent/tools/rig023c_diff.py`), seis criaturas (Trogg, Ranger, Taurock, Dragon, Ent, Peasant) × idle/run/attack, en `game/agent/out/023c/`: mismas poses de partida, diferencia media de canal 2,4–6,4 sobre 255 en run/attack/idle de las cinco que ya tenían clip (≤ 7,7 % de píxeles del cuerpo con diferencia > 24); el residuo es de normales y sombreado (el horneado trae las normales de cada cuadro). Ranger y Trogg en `idle0` contra el reposo viejo: silueta 0,00 %, media 2,7. El `idle` de los de nivel 1 difiere a propósito (ahora `stance1`, antes `idle0`). El peón no tenía clips horneados (estático); ahora anima. Piedra, translucidez y vuelta a las texturas se ven bien con el esqueleto (`effects_on/off.png`).

Rendimiento (`look_bench --units=60 --quick`, 9 vistas, mismo preset): horneado (`--baked-bodies`) / esqueleto. Medio: 45,05 / 45,51 ms por cuadro (+1 %), VRAM 1700 / 1683 MB; bajo 31,14 / 29,85; alto 84,51 / 83,89; nativo 64,85 / 63,89. Llamadas de dibujo 1072 / 7137 (una superficie por parte del cuerpo × 60 × 9 vistas): no pesa hoy; 023g lo mira. No empeora más de 20 %.

Digests: `agent/run_determinism.sh quick` = `44d78b49…` (igual a la base). `all fixed fixed2 stress window`: los cuatro modos dan el mismo digest por caso (s7 `c5a5755a…` y f139 `4750f4d1…` igual a `det_baseline.txt`; s7_npcs `4386b384…`, s1_trivial `60fbf6d5…` iguales entre modos). El veredicto salió FAIL solo por `contaminated=1` en 8 filas (otros agentes corrían Godot en paralelo); ningún digest difiere.

Reposo: **hecho**. Todo el que tiene esqueleto descansa en `stance1` (rol `idle`) y tras cada vuelta de reposo juega el gesto `idle0` (rol `gesture`) 1 de cada 5 con `posmod(hash(nombre) + vueltas, 5)`, igual en todos los peers y sin tocar la sim. Solo está `idle0`: `idle1..3` no se exportan a `creatures.json` (pendiente en `export_stats.py`). El horneado (modelos sin esqueleto, `--baked-bodies`) conserva la regla vieja (`pose_source`).

Desvíos y notas:
- **Medidas**: `sizes.json` (altura, radio, `foot_offset`, `upright_fix`) **no** pasa a salir del esqueleto. Las usa `BodyCollider` (cápsulas) y cambiarlas mueve la física: los digests cambiarían (los 16 de nivel 1 pasarían de la pose `idle0` a `stance1`). Va en un corte propio.
- Cuerpos horneados desde la pose de enlace (sin `pose_source`: peones, Zyzyx): sus clips ya paran al cuerpo, así que con esqueleto `BodyCatalog.pose` no aplica `upright_fix` ni `foot_offset` (si no quedaban acostados y 0,65 m en el aire).
- Knob de depuración `--baked-bodies` (argumento de usuario): dibuja todo con el horneado para comparar y medir en el mismo build; se va con 023h.
- `export_skeletal.py`: no reescribe un `.glb.import` que ya existe (lleva el UID) y guarda `reference_height` 0,0 cuando el SXSK trae infinito (`Infinity` rompía el JSON).
- `ClipPosePlayer` sigue vivo para magos, doctor y estructuras (023d–f) y como dibujo de fallback; ya no es el reloj de las unidades.
- Los roles de unidad repiten todos (el clock da vuelta con cualquier clip); no hay one-shot en `unit`.

What: unidades con esqueleto (BodyRig + ClipClock + BodyAnimator), 58 modelos con paridad ≤ 0,46 mm. Why: sacar el horneado por cuadro del cuerpo de las unidades sin tocar la sim ni el dedicado. Where: `scenes/world/body/`, `unit.tscn`, `assets/original/models/`. Learned: los cuerpos horneados desde la pose de enlace llevan correcciones (`upright_fix`, `foot_offset`) que el esqueleto no debe repetir; los autoloads no compilan en `--script`, los chequeos de escenas van como escena.

## 023f: Resultado (developer, 2026-10-17)

Entregado, sin ventana (regla del usuario: el developer no abre ventanas; las capturas quedan para el playtester):
- **Cadáver** (`corpse.gd`, `unit_body.gd`): con esqueleto, el cuerpo cae con su clip `death` (o `fly_death` si está en el aire) y se queda en el último cuadro (`BodyClips.HOLD_ROLES`; `BodyAnimator.play_ended` para quien llega tarde). El pivote no se toca (`Corpse.clip_driven`); el reloj de caída es el mismo encadenado de cuatro pasos que el Tween, así que `settled` y el alma salen en el mismo tick (el dedicado y los cuerpos horneados siguen con el Tween). `soul_anchor` usa `Corpse.laid_pose` en los dos casos: misma posición del alma.
- **Desvanecido**: `Corpse.fade_s` (`@export`, 1,0 s) al final de `dissolve_s`; `dissolving` pasó a `@export` replicado (`unit.tscn`, `Corpse:dissolving`) para que lo vean los clientes. **No es fiel**: en sacengine el cadáver desaparece de golpe a los 2,5 s (`state.d:14073-14078`, solo suena un sonido; el renderer no atenúa). Es el pedido del usuario encima del original; `fade_s = 0` lo apaga.
- **Fantasma**: `SeeThroughLook` (RefCounted, `scenes/world/body/`) lleva transparencia, sombra y material sin sombreado de UN cuerpo, sobre las mallas del rig (`rig.skinned_meshes()`) o la propia; copia por instancia como `surface override` (guarda y devuelve los overrides; el `OriginalMaterial` compartido no se toca). `GhostForm` lo usa.
- **Voladoras**: roles nuevos `hover` y `fly_death` en `BodyClips.ROLES` y en el `AnimationTree` (`body_rig.tscn`, +2 estados, transiciones regeneradas con la misma regla). Un híbrido en el aire en IDLE juega `hover` (slot 38); en movimiento `fly`.
- **Datos**: `tools/export_stats.py` exporta `death_animations` (death0 slot 19, flyDeath slot 36) y `hover` en `flight_animations`; `assets/original/data/creatures.json` regenerado (solo cambian esas dos claves; el resto de los JSON, idénticos). `CreatureType.death_animations`, `UnitClipRoles.DEATH_ROLES`. `unit_body.gd`: 1038 líneas (≤ 1040).
- Escena de capturas: `debug/rig023f/rig023f_shots.tscn` (se cierra sola; tope interno de 90 s). Una corrida parcial con ventana, hecha antes de la regla, dejó `ghost_beside_opaque.png` (fantasma translúcido junto a un Trogg opaco: se ve bien) y la caída del cadáver; `corpse_fade_mid.png` salió vacío (el cuerpo ya no estaba: hay que repetir con la escena actual, que espera a transparencia 0,4).

Capturas pendientes (playtester, `--max-fps 60 --resolution 1280x720`, a `agent/out/023f/`): fantasma junto a opaco, cadáver cayendo (a y b), cadáver echado, cadáver a mitad del desvanecido, hover y vuelo de dragón y murciélago; `report.txt` debe decir `clip_driven=true` y `removed=true`.

Desvíos y notas: (1) el clip de muerte puede durar más que los 0,91 s de la caída del Tween (dragón: 148 cuadros = 4,9 s); el alma aparece a los 0,91 s como hoy. Para ser fiel, la duración tendría que salir del clip: es un cambio de sim y va aparte. (2) Los magos con esqueleto (023d) no existen en esta rama: `GhostForm` ya trabaja con rig por `SeeThroughLook`, sin verificar en un mago real. (3) `creatures.json`, `body_rig.tscn` y `body_clips.gd` pueden chocar con 023d/e al mergear: se regenera con `export_stats.py --out assets/original/data` y las transiciones se rehacen sumando los roles.

What: cadáver con clip `death` y desvanecido, fantasma por instancia sobre el rig, `hover`/`fly_death`. Why: sacar los últimos Tween de caída y el fantasma ligado a una malla horneada, y pagar la deuda del desvanecido. Where: `corpse.gd`, `see_through_look.gd`, `ghost_form.gd`, `body_rig.tscn`, `export_stats.py`. Learned: una escena de capturas sin tope propio se queda abierta si falla una corrutina; `frame_post_draw` no sale en headless.
## 023e: Resultado (developer, 2026-10-17)

Entregado: el doctor (`doctor.tscn`: `Pivot/Mesh/Rig` = `BodyRig`, `ClipPose` = `BodyAnimator`; `DoctorBody.clip_player` pasa a `ClipPlayback`, el desvanecido de la muerte usa `BodyVisual.set_fade`) y el cautivo. Roles del doctor: `idle` ahora es `stance1` (SDst) y no `idle0` (SDda), que se pasea 1,6 m de la cápsula; `work_roles` (export) lleva pump -> `work`, lift -> `cast`, torture -> `attack`, porque la máquina del rig tiene un estado por rol de `BodyClips.ROLES` y no se tocó `body_rig.tscn`. Cautivo: `Captive` (todos los pares, desde el modo replicado) pone `UnitBody.captive_role`: HELD = `rise` (una vez) -> `held` (= float2Thrash del original, una vez) -> `thrash` en bucle; REVIVING = `rise` y vuelve a idle (sacengine state.d:8200-8223, 14329-14342). Los tags salen de `CreatureType.captive_animations`, nuevo en `tools/export_stats.py` (slots 46, 49, 25; `assets/original/data/creatures.json` regenerado: solo ese campo cambia). Clips nuevos que exportar: ninguno; los `.glb` ya traían todos. Los 11 híbridos horneados no tienen esos clips y se quedan en idle. `unit_body.gd`: 1027 líneas.
- Centrado: nuevo `tools/audit_skeletal_center.gd` (headless, skinning en CPU con los ejes del juego): centroide del doctor a la cápsula, reposo <= 0,30 m, run <= 0,40, melee <= 0,60 (el doctor se inclina 0,5 m hacia lo que trabaja, es el original): PASS. `audit_body_pose.gd` sin cambios: PASS (sacd ok).
- Banco: `quick` = `44d78b49…` igual a la base en fixed, stress y window (veredicto FAIL solo por `contaminated=1`, otros agentes corriendo). `rules_suite` PASS (incluye `captive` y los casos de doctor/ritual/convert). Pasada completa `all ... window`, flows con ventana y capturas: pendientes (cierre del RFC / playtester).
- Falta para el playtester: `res://debug/rig023e/rig023e_shots.tscn` (ventana, `--max-fps 60 --resolution 1280x720 -- --out=<dir>`, sin correr aún): doctor caminando (`doctor_walk_*`) y Trogg cautivo rise/held/thrash en el aro (`captive_*`); y los flows `pt59_carry`, `pt75w_convert`.
- Desvío: el enlace `sacengine` en la raíz del worktree es solo para correr `export_stats.py`; no se commitea.

What: doctor y cautivo sobre BodyRig/ClipClock. Why: 023e del plan. Where: `doctor*`, `captive.gd`, `unit_clip_roles.gd`, `export_stats.py`. Learned: el rig tiene estados fijos por rol, así que los trabajos del doctor toman roles prestados; el idle0 del doctor se aleja de la cápsula, el reposo es stance1.
## 023d: Resultado (developer, 2026-10-17)

**Arreglo previo del exportador.** `parse_clip` (`tools/export_skeletal.py`) normalizaba con `sqrt(...) or 1.0`: un hueso sin rotación en el SXSK (los cuatro `short` en cero) quedaba como cuaternión (0, 0, 0, 0). sacengine lo normaliza con el `normalize()` de dlib, que deja un vector de largo cero en (0, 0, 0, 1) (identidad). Ahora se escribe la identidad. Regenerados `dcak`, `ecak`, `fcak`, `stmp`, `eber`; el import ya no da ningún «quaternion must be normalized» (borrado `.godot/imported` de los cinco y reimportado: 0 errores). Paridad contra sacengine (`export_skeletal_reference.py --unit-clips`, `audit_skeletal.gd --clips= --ref=`), 47 clips, 141 filas: PASS, máximo por modelo dcak 0,20 · ecak 0,25 · fcak 0,19 · stmp 0,23 · eber 0,17 mm (igual que en 023c: los huesos sin rotación no movían ningún vértice).

**Magos.** Exportados los 14 modelos de mago que faltaban (`serx mrdk xwiz quil gret ABRX sage hero buta rigl spdr shkt YOGO brod`; `jnwr` ya estaba), 15 de 15 con esqueleto. Paridad (referencia de sacengine, los 5 clips que juegan: stance, idle0, run, spellcast, runSpellcast; 70 clips, 210 filas): PASS, máximo 0,37 mm (ABRX y buta). `export_stats.py` suma a `wizards.json` `stance_animation` y `cast_animations` ({cast: WIZD slot 27, run_cast: slot 30}; solo agrega claves); `WizardType` los lee.
- `wizard_body.tscn`: `Tilt/Mesh` (`BodyVisual`) con hijo `Rig` (`body_rig.tscn`), `ClipPose` pasa de `ClipPosePlayer` a `BodyAnimator` (el reloj `ClipClock` corre igual en el dedicado), nodo nuevo `CastHands` (`HandFx`).
- Roles: `UnitClipRoles.for_wizard` (reposo `stance1` como las unidades, `idle0` de gesto 1 de cada 5 con `hash(nombre)`, `run`, `cast`, y el rol nuevo `cast_run`, con sus 40 transiciones en `body_rig.tscn`). `WizardBody._update_clip_state` elige `cast`/`cast_run` mientras el Caster lanza.
- Manos: `BodyRig.hand_points()` da la posición mundial de los `BoneAttachment3D` (hueso y offset del clip, `index.json` → `hands`; una mano sobre el hueso raíz es «sin mano», como el NaN de sacengine). `HandFx` juega la partícula de casteo en cada mano (sacengine `animateCasting` pone una en las dos manos de la pose, state.d:16165) cada 0,5 s, igual que el intervalo anterior, y espera la pose si el cuerpo todavía mezcla desde el reposo (0,3 s máximo; sin manos cae en pies + 1 m).
- `Caster` ya no hace `FxBus.broadcast` (en el dedicado no hay hueso para calcular la mano): publica `cast_fx_shown` (replicado, `Caster:cast_fx_shown` en el sincronizador) y la señal `cast_fx_changed`; `HandFx` y la pose lo leen en todos los pares. Es presentación: no toca ticks, mana ni RNG de la simulación.
- `GhostForm` hace el fade por `BodyVisual.set_fade` (si no, el fantasma con esqueleto quedaba opaco; la sombra y el material sin sombreado del fantasma son 023f).
- Desvíos: el casteo juega solo el bucle (`spellcast`/`runSpellcast`); los clips de inicio y fin no. Los estados aturdido/caído del mago siguen con el Tween de `Stunned` (no se agregaron roles `knock` al mago). `unit_body.gd` queda en 1017 líneas.

**Verificación (solo headless; sin ventana por pedido del orquestador).** `run_determinism.sh quick`: digest `44d78b49…` en fixed/stress/window, igual a la base, y todas las líneas `baseline … OK`; el veredicto sale FAIL solo por `CONTAMINATED` (otros agentes con Godot). La pasada `all fixed fixed2 stress window` se canceló (queda para el cierre del RFC); `s7` dio `c5a5755a…` en fixed, fixed2 y stress, igual a la base. Sin `SCRIPT ERROR` en los logs del banco. Antes del aviso del orquestador corrí una captura con ventana (`debug/rig023d/rig023d_cast.tscn`, `agent/out/023d/jnwr/`): reposo `jwst`, casteo `jws2` con las dos manos en posiciones distintas por cuadro (px 564,301 / 669,224 → 630,204 / 734,327 → 540,332 / 641,201) y el FX sobre ellas; `cast_run` `jwr2` en marcha. No hay captura del original para comparar (no se corrió REA).

**Falta (playtester, con ventana):** (1) `godot --path game --max-fps 60 --resolution 1280x720 res://debug/rig023d/rig023d_cast.tscn -- --out=<dir> [--wizard=cwf0 --fx=cast_pyro]` por mago (capturas a 1280x720, FX en la mano); (2) comparar contra una captura del original (REA); (3) flow `agent/run_f165.sh f165`; (4) `look_bench` 60 unidades `--quick` contra la base; (5) pasada completa del banco.

What: magos con `BodyRig` (15 modelos), manos con `BoneAttachment3D`, partícula de casteo en la mano, reposo `stance1`; exportador sin cuaterniones nulos. Why: 023d de la tabla §6. Where: `scenes/world/wizard/`, `scenes/world/body/hand_fx.gd`, `spells/caster.gd`, `tools/export_*.py`, `assets/original/models/`. Learned: sacengine (dlib) normaliza el cuaternión nulo a la identidad; el dedicado no tiene huesos, así que el FX de la mano tiene que salir de un estado replicado y dibujarse en cada cliente.

### Enmienda 023g: paridad ≤ 30 mm con single-bind

Criterio de paridad: **≤ 30 mm por vértice con single-bind; ≤ 1 mm ya no es requisito (decisión del usuario 2026-10-17).** `tools/export_skeletal.py` usa por defecto un solo bind promediado por vértice y mide el error (`bind_discrepancy.max_mm`, por vértice, es la distancia entre influencias). Un modelo que lo pasa recibe huesos auxiliares solo para los vértices por encima de 30 mm (`BIND_THRESHOLD` = `MAX_ERROR_MM`); `residual_max_mm` es el error que queda. `audit_skeletal.gd` falla por encima de 30 mm (`TOLERANCE_MM`).

Resultado de la medición (84 modelos): con single-bind puro el máximo por modelo pasa 30 mm en los 84 (de 46 mm a 3,7 m; unos pocos vértices con influencias lejanas), así que todos reciben auxiliares: mediana 64 por modelo con 30 mm (total 9068; antes con 0,5 mm eran cientos por modelo), 34 con 100 mm, 1,5 con 300 mm. Error residual máximo 30,0 mm, mediana 27,2 mm. Superficies: las partes que comparten textura se fusionan en una primitiva (`index.json` → `surface_parts`); en los 84 modelos solo 4 (YOGO, dflp, sprg, sprl) tienen partes con la misma textura: 572 → 568 superficies, así que fusionar no baja las llamadas de dibujo. Las llamadas de dibujo ×8 vienen de que el renderizador agrupa en una sola llamada las mallas horneadas idénticas (instancing) y no puede hacerlo con mallas con piel (un esqueleto por cuerpo).


## 023h: Resultado (developer, 2026-10-17)

Retirado el camino horneado de los cuerpos animados. **Borrado:** `scenes/world/components/clip_pose_player.gd` (lado malla); `ClipClock._from_baked_list` (el reloj lee solo `models/index.json`); `UnitClipRoles._baked_rest_tag`; el `ClipPosePlayer` que creaba `BodyAnimator` (y los parámetros `mesh_base_pos/rot` de `setup`, en `ClipPlayback`, `BodyAnimator` y los tres cuerpos que lo llamaban); el flag `--baked-bodies` (`BodyCatalog.baked_bodies_forced`); `BodyCatalog.BAKED_DIR`, `CLIPS_SUBDIR`, `LOOK_DIR`, `clip_frame_path`, `SKELETAL_FALLBACK` (vacía) y el argumento de `refresh()`; `OriginalMaterial.model_of` ya no entiende `anim_f37`. `structure_body.gd`/`structure.tscn`: fuera el nodo `ClipPose` y la lectura de `anim_mesh_clips_f37.json` (ese JSON solo tenía cuerpos, ningún edificio: era código sin efecto). En `tools/`: `bake_clips.gd`, `bake_bodies.gd` completo (los props y edificios ya salen de los `.glb` de 033c; su única otra salida era `sizes.json`, ver abajo), `export_f37_mesh_clips` y la cadena de `export_stats.py` (`_export_all_frames`, `_fix_frame_displacement`, `_collect_mesh_clip_tags`, `ANIM_OUT`, `ENGINE`/`MAP`), y los oráculos que leían los cuadros horneados: `audit_skeletal.gd`, `audit_body_pose.gd`, `audit_unit_parity.py`, `export_skeletal_reference.py`. En `debug/`: `skeletal_compare*` y `rig023c/rig023c_shots*` con `agent/tools/rig023c_diff.py` (comparaban horneado contra esqueleto).

**Los 11 híbridos** (faez, thes, the2, sara, hoom, bane, ban2, sirc, surt, gamm, baby): asset propio, un `.glb` estático por modelo en `assets/original/props/<m>.glb` (como los props de 033c; mismas etiquetas `bodypartNNN`, los materiales los pone `OriginalMaterial`). Se descartó el `.glb` esquelético: su pose de enlace no es la del OBJ horneado (entre 1,8 y 63 cm de distancia máxima entre vértices según el modelo, y la caja cambia: Sirocco 6,933 m contra 6,699 m), así que cambiaría el look y ya no coincidiría con las cápsulas de `sizes.json`. La fuente es el OBJ de `saveObj` (`tools/import_props.py --bodies-from=DIR`, con z espejada como `ObjMesh.MIRROR_Z`): medido en Python contra ese OBJ, 0,0 mm de diferencia por vértice en los 11, y la caja coincide con la de `sizes.json`. `BodyCatalog.mesh()` devuelve solo mallas estáticas (props e híbridos); un cuerpo con esqueleto no tiene malla ahí y `BodyVisual` no dibuja cápsula de relleno si el modelo tiene esqueleto. `wizard_preview.gd` (selector de magos) usaba la malla horneada: ahora instancia un `BodyRig` con `UnitClipRoles.for_wizard` (se ve el reposo, no la pose de enlace). `tools/check_original_assets.sh` salta esos 11 (dato versionado).

**`sizes.json`:** queda como **dato versionado, sin generador**. Calcularlo desde los `.glb` no da los mismos números (la pose de enlace del `.glb` difiere de la del OBJ con que se midió; los cuerpos con pose se midieron sobre los cuadros de sacengine y el esqueleto los reproduce a ≤ 0,5 mm pero los valores se redondean a 1 mm), y cambiarlo mueve cápsulas y digests. Documentado en `assets/original/README.md`; se quitó `--sizes-from` de `import_props.py`.

**`rg`:** `cache/` en `scenes data debug addons agent/harness` queda vacío salvo el comentario de `scenes/world/obj_mesh.gd`. En `tools/` sobreviven, de 033/033i: `audit_original_props.gd`, `export_persephone.py`, `export_bodies.py` (produce los OBJ que lee `--bodies-from`) y la rama de caché de `export_buildings` en `export_stats.py`. `rg "anim_f37|baked-bodies|ClipPosePlayer"` vacío fuera de `rfcs/`, `reviews/` y `FEATURES.md`.

Desvíos / notas: `debug/body_gallery` y las escenas que usan `gallery_body.tscn` solo dibujan los híbridos y los props (los cuerpos con esqueleto no tienen malla estática); no se tocaron. No se corrió Godot (pedido del orquestador): los 11 `.glb.import` nuevos no tienen `uid` hasta el primer import. No se regrabó ningún digest.

What: retiro del horneado de cuerpos animados, híbridos como `.glb` estático, `sizes.json` como dato. Why: 023h de la tabla §6, antes de borrar `cache/` (033i). Where: `scenes/world/{body_catalog,body_visual,body/*,structures/*}`, `scenes/ui/wizard_preview.gd`, `tools/import_props.py`, `tools/export_stats.py`, `assets/original/props/`. Learned: la pose de enlace del esqueleto exportado no es la del OBJ de sacengine (hasta varios cm), así que los cuerpos estáticos salen del OBJ y no del `.glb`; el `.glb` solo sirve para animar.
