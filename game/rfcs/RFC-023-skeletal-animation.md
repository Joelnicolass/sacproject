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
- **Eventos:** el `.glb` no los lleva. El exportador escribe `cache/skeletal/<m>.events.json` (clip → [{frame, kind}]). Al construir la librería (una vez por modelo, estática) se agrega una **pista de método** que llama `ClipEvents.fire(kind)` en ruta relativa fija (`%ClipEvents`), compartida por todas las instancias. Solo presentación (pasos, sonidos, chispa de golpe).
- **Interpolación:** lineal por defecto (más suave que el original); knob global `BodyAnimSettings.stepped := false` que pone `INTERPOLATION_NEAREST` para comparar contra el original cuadro a cuadro.

### 3.2 Exportador y validación
- Entradas: `INSTALL/saxs*.wad` (SXMD + SXSK + SKEL), índice ya resuelto por `export_stats.index_saxs_*` y el lector `ex` de `export_persephone.py` (se importan, no se duplican).
- Salidas: `cache/skeletal/<m>.glb`, `<m>.glb.import`, `<m>.events.json`, `cache/skeletal/index.json` (modelo → clips, frames, framerate, huesos de mano por clip, discrepancia de bind, altura de referencia).
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
cache/skeletal/<m>.glb, .glb.import, .events.json, index.json      (no git)
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
