# Plan 064 (F388): construir sobre un manantial con aviso antes del clic y sin rechazos por unidades

> **Estado:** aprobado por el usuario el 2026-10-26.
>
> **Decisiones del usuario (§15):**
> - **Q1.** El empuje también mueve al mago que lanza, con un knob `push_caster` para apagarlo.
> - **Q2.** El anillo marca los 15 m del empuje.
> - **Q3.** El tech lead elige; queda la malla.
> - **Q4.** `RefusalReason` muestra el motivo de todos los rechazos.
> - **Q5.** No hace falta vista previa para los hechizos comunes, ni en este corte ni en otro.
> - **Q6. Entra AHORA.** La torre nace al empezar el lanzamiento, como en el original: inactiva e indestructible mientras sube, y se destruye si se corta. Lleva un efecto de revelado tipo «dissolve» que va mostrando la torre mientras sube, como el original o parecido (verificar en sacengine cómo se ve). Hay que verificar en sacengine si el mago puede moverse durante el lanzamiento (el usuario cree que no) y copiar eso.
> - **Q7.** Textos tal cual.

## 0. Por qué falla hoy (medido en el código y los datos)

- **La regla es demasiado ancha.** `TowerRules.has_room` (`scenes/structures/towers/tower_rules.gd:31`) rechaza con `occupied` si hay cualquier mago, unidad o estructura a menos de `footprint_m + MARGIN_M` del centro del manantial.
  - La caja del Manalith mide 15,93 × 17,96 m (`buildings/_mana.tscn:9`). Eso da 8,98 + 2 = **10,98 m**.
  - La del Shrine mide 22,63 m (`_pcsh.tscn:9`). Eso da 11,31 + 2 = **13,31 m**.
  - El alcance es de 20 m (`data/catalog/spells/htlm.tres`). El mago tiene que quedarse en un anillo de 11 a 20 m, y **el propio mago y sus criaturas, que lo siguen, bloquean el hechizo**.
- **No hay aviso antes del clic.**
  - `CommandCue._check_hover` solo compara la clase del objetivo. Para el probe el manantial es «ground», así que siempre lo da por válido.
  - Las claves `occupied` y `no_fount` no tienen línea del consejero (`scenes/audio/advisor/advisor.tscn:182-190`).
  - No se muestra texto en ningún lado.
- **Cada chequeo cuesta caro.** `StructureAction._can_place` instancia la escena entera de la torre en cada chequeo (`structure_action.gd:78-82`). Así no sirve para revisar al pasar el puntero.

## 1. Qué hacía el original (sacengine, solo lectura)

- **Blanco.** El Manalith y el Shrine apuntan al manantial mismo, no al suelo: tienen el flag `onlyManafounts` (`sacspell.d:56`). El flag `manafount` solo se marca si el manantial está libre, con `!top` (`state.d:30786-30790`).
- **`spellStatus` revisa, en este orden:** nivel, almas, maná, blanco válido (`invalidTarget`) y alcance mago→manantial (`state.d:29534-29573`). **No mira ni unidades ni estructuras cerca.** VERIFICADO en sacengine.
- **Al empezar el lanzamiento** la torre se crea enseguida sobre el manantial, inactiva e indestructible, y va «subiendo» (`state.d:10072-10083`, `putOnManafount` 1716-1724, `setupStructureCasting` 29464-29472).
- **Unidades en el lugar: las empuja, no rechaza.** En cada cuadro del lanzamiento corre `pushAll(posición, 5, 15, 5)` (`state.d:15259`).
  - La fórmula está en `state.d:8614-8628`: fuerza = (1 − (d − 5)/10) × 5 m/s, o sea 0 a los 15 m y 7,5 m/s en el centro.
  - El empuje respeta el suelo (8604-8612) y no mueve a las criaturas inmovilizadas (`fixed`).
  - No filtra bandos. Que también empuje al mago es NO VERIFICADO: es un `MovingObject` y no hay filtro, pero no lo probé.
- **Corte y fin.** Si se corta el lanzamiento, la torre se destruye (15261). Si termina, se activa (15264-15274).
- **Dos magos sobre el mismo manantial.** Queda la última torre: `putOnManafount` libera a la anterior (1720), y hay un «TODO: stun both wizards» (10074).
- **Aviso al jugador.**
  - Con un icono armado, el cursor dibuja el icono del hechizo y, encima, el icono de «blanco inválido» siempre que `spellStatus != ready`. Se calcula en vivo en el cliente (`dagonBackend.d:1930-1942`, `renderer.d:4120-4147`).
  - El cursor mismo se elige por la clase de lo que hay bajo el puntero. Un manantial libre cuenta como neutral (`state.d:30845`).
  - Si el clic es rechazado, habla el consejero (`dagonBackend.d:57-78`, `1245-1249`): `invalidTarget`, `lowOnMana`, `outOfRange` o `notReady`.
  - **No había texto ni anillo en el suelo**: no encontré nada en sacengine. En el ejecutable es NO VERIFICADO (no lo miré con REA).
  - El clic derecho sobre un manantial libre lanza el Manalith directamente (`dagonBackend.d:1271-1272`).
- **Manual, página 50 del PDF:** «You must be standing very close to mana fountain to cast a manalith». Contradice nuestra regla, que bloquea al mago cuando está cerca.
- Ni la investigación 055R ni la de Scapex dicen nada sobre el espacio libre.

## 2. Contradicciones

1. **Nuestra regla contra el original y el manual.** Nosotros rechazamos por unidades y por el propio mago; el original empuja y el manual pide estar cerca. Gana el original, por CONVENTIONS («verificar con sacengine») y por RULES («del original se copia lo que se nota al jugar»).
2. **Un método que no existe.** El doc de `scenes/spells/refusal.gd:5` cita `Refusal.text(key)`, pero no está. Lo creamos en este corte.
3. **«No es tu manantial» no es una regla** ni en el original ni en el port: los manantiales son neutrales. Recomiendo una sola clave nueva, `fount_taken`, que cubra la torre propia y la ajena.
4. **Clic en el suelo o en el manantial.** Nosotros apuntamos al suelo y elegimos el manantial libre más cercano (20 m); el original apunta al manantial mismo. Lo dejamos como está: perdona más, y la vista previa muestra en qué manantial se va a construir.
5. **Momento en que aparece la torre.** En el original nace al empezar el lanzamiento; en el port, al terminar. Queda fuera de este corte (pregunta Q6).

## 3. Recomendación para simplificar: opción **d** (a + c)

- **a) Empujar, como el original.** Mientras dura el lanzamiento, el servidor empuja a todos los cuerpos vivos del área (con la fórmula de `pushAll`). Al terminar, cualquier cuerpo vivo que siga dentro de la caja de la torre se pone en el borde (`CastTower.clear_footprint`, que hoy solo mueve cadáveres y almas). Las unidades **dejan de bloquear**.
  - El empuje copia al original.
  - El barrido final es la garantía de Godot: nadie queda atrapado dentro de la caja sólida.
- **c) Los rechazos que quedan se ven antes del clic:** falta maná, enfriando, fuera de alcance, no hay manantial, manantial con torre y edificio encima.
  - El edificio encima es raro: en los 9 mapas el edificio más cercano a un manantial está a 26,8 m o más (medido sobre los `map.tscn`).
- **b) Área que bloquea, descartada:**
  - El navmesh se hornea offline, así que habría que volver a hornear los 9 mapas.
  - Un círculo de 30 m cortaría caminos, y `check_map` comprueba el camino altar→manantial.
  - Las almas y los cadáveres que caen ahí quedarían fuera del alcance de los doctores (justo por eso existe `clear_footprint`).
  - Afectaría a Convert y a los sacrificios cerca del manantial, y el mago ya no podría pararse «very close».
  - El original no lo hace.
- **Determinismo y red.**
  - Empujar y barrer es simulación: lo hace solo el servidor o la partida en solitario, con `BodyNudge`, recorriendo los grupos en orden fijo. Las posiciones se replican.
  - La vista previa es local: el cliente llama a la misma `StructureAction.check` sobre su estado replicado y no agrega ningún RPC. Si el cliente predice mal, decide el servidor: hoy ya hace parpadear el icono y ahora también da el motivo.

## 4. Objetivo y criterios medibles

1. Con el mago a 10 m, una unidad propia a 5 m y una enemiga a 8 m del manantial, `check` responde `""`. Hoy responde `occupied`.
2. Tras un lanzamiento completo (11,1 s simulados) con unidades quietas entre 3 y 10 m: se crea una torre y **0** cuerpos vivos quedan dentro del AABB de su caja. Todos quedan a una distancia plana de al menos `footprint_m + MARGIN_M`, o sea 10,98 m para el Manalith y 13,31 m para el Shrine.
3. `BodyNudge.push_speed(d, 5, 15, 5)` da 5,0 a los 5 m, 2,5 a los 10 m, 0 a los 15 m y 7,5 en el centro.
4. Una estructura a 10 m del manantial da `occupied`; a 16 m da `""`.
5. Manantial ocupado y ninguno libre a 20 m: `fount_taken` con `aim.site` igual a ese manantial. Sin manantiales cerca: `no_fount` con `site == null`.
6. Un solo dueño: para todos los casos de 1 a 5, `Caster.action_status(...)` es igual a `Caster.aim_for(...).status`.
7. Flujo en la escena de prueba:
   - Mago a 30 m y puntero sobre el manantial: `%Battle.aim_status == "out_of_range"`, `%CommandCue/Invalid` visible, `CursorSkin.current == "Tnon"`, `%RefusalReason.text` igual al texto de `REFUSAL_OUT_OF_RANGE` en strings.csv, y el anillo visible con el color de bloqueado.
   - Con el mago a 12 m: `aim_status` vacío, `Invalid` oculto, cursor `Tntr` y anillo con el color de válido.
8. El estado de la vista previa cambia en ≤ 0,1 s después de mover el puntero (15 Hz).
9. Captura con cámara fija sobre el manantial: al menos 2000 px del tono del anillo dentro de la máscara del anillo, y menos del 1 % con el anillo oculto.
10. Costo: cada consulta de la vista previa cuesta ≤ 0,2 ms de promedio en 100 muestras. No instancia nada.
11. En una partida solo contra la IA (banco quick), la IA recibe **0** respuestas `occupied` al pedir `htlm` (AiAudit).
12. El lint no sube ningún conteo. `caster.gd` no crece en líneas netas.

## 5. Escena de prueba

`res://debug/spells/manalith_build_area.tscn` hereda de `debug/map/structure_siege.tscn` (High Noon, un manantial libre junto a Start1, sin Manalith).

- **Qué instancia:** el `manafount.tscn` real del mapa (con `BuildArea` y `Ring`), una unidad propia (`Loiterer`, `ranger.tres`, slot 1) a 5 m del manantial 1 y otra enemiga (`Sieger`) a 8 m. Todas se colocan con el gizmo.
- **Estado inicial:** el mago en su `WizardSpot`, a más de 20 m, sin nada armado.
- **Qué todavía no está:** ni anillo, ni torre, ni texto.
- **Qué hace quien prueba:** pestaña Estructuras, después `%SpellBook/Slots/Structure1` (o la tecla del primer hechizo del InputMap). Pasa el puntero por el manantial y ve el anillo rojo, el cursor «no se puede» y el texto «Muy lejos». Camina hasta 12 m, ve el anillo verde, hace clic y ve cómo las unidades se corren y la torre se levanta.
- Para un atajo de prueba, otra instancia de esta misma escena, sin `.gd` nuevo.

## 6. Árbol de archivos

```
game/
├─ scenes/spells/
│  ├─ refusal.gd                         [~] FOUNT_TAKEN; static text(key)
│  ├─ caster.gd                          [~] aim_for(); action_status = aim_for().status (neto 0 líneas)
│  └─ actions/
│     ├─ spell_action.gd                 [~] Aim.site: Node3D
│     └─ structure_action.gd             [~] check: fount_taken, site, sin unidades, sin instanciar; empuja mientras lanza
├─ scenes/structures/towers/
│  ├─ tower_rules.gd                     [~] closest_fount(free_only), has_room(area) solo estructuras
│  ├─ cast_tower.gd                      [~] clear_footprint también mueve cuerpos vivos
│  └─ README.md                          [~]
├─ scenes/map/props/
│  ├─ build_area.gd                      [+] BuildArea (CollisionShape3D apagada, cilindro)
│  ├─ build_ring.gd                      [+] BuildRing (MeshInstance3D, presentación)
│  ├─ build_ring.gdshader                [+] anillo unshaded, color por instancia
│  ├─ build_area_look.gd                 [+] BuildAreaLook (Resource)
│  ├─ manafount.tscn                     [~] + BuildArea/Ring
│  └─ manafount_body.gd                  [~] @export build_area + aviso
├─ scenes/map/README.md                  [~] Edit/Check de BuildArea
├─ scenes/units/movement/body_nudge.gd   [~] push_speed (pasa acá desde SacrificeMath)
├─ scenes/sacrifice/sacrifice_math.gd    [~] - push_speed
├─ scenes/sacrifice/ritual_push.gd       [~] usa BodyNudge.push_speed
├─ scenes/orders/
│  ├─ command_log.gd                     [~] aim_status, aim_site, aim_changed, show_aim()
│  ├─ command/armed_preview.gd           [+] ArmedPreview
│  └─ README.md                          [~]
├─ scenes/match/match.tscn               [~] MatchCommand/ArmedPreview
├─ scenes/ui/command_cue/
│  ├─ cue_set.gd                         [~] blocked_cursor
│  ├─ cursor_skin.gd                     [~] cursor bloqueado
│  ├─ command_cue.gd                     [~] _check_hover también por aim_status (+3 líneas)
│  ├─ refusal_reason.gd                  [+] RefusalReason (Label)
│  └─ command_cue.tscn                   [~] + Reason
├─ scenes/audio/advisor/advisor.tscn     [~] no_fount, fount_taken, occupied → Line_invalid_target
├─ data/ui/build_area_look.tres          [+]
├─ data/ui/command_cues.tres             [~] blocked_cursor = Tnon; fount_taken → refused
├─ data/i18n/strings.csv                 [~] REFUSAL_* (una fila por clave de Refusal)
├─ debug/spells/manalith_build_area.tscn [+]
├─ debug/suite/build_area_cases.gd       [+]
├─ debug/suite/rules_suite.gd            [~] registra build_area_cases
├─ debug/suite/action_cases.gd           [~] no_room pasa a ser una estructura, no una unidad
├─ debug/suite/tower_cases.gd            [~] los cuerpos vivos salen de la caja
├─ debug/suite/ritual_cases.gd           [~] BodyNudge.push_speed
└─ agent/flows/f388_build_area.json      [+]
```

## 7. `manafount.tscn` después del cambio

```
Manafount (StaticBody3D, ManafountBody)    build_area -> BuildArea
├─ Visual (MeshInstance3D)
├─ Collision (CollisionShape3D, cilindro r 3,6)
├─ GroundFootprint (GroundFootprint, caja 8×8, apagada)
├─ BuildArea (BuildArea: CollisionShape3D, CylinderShape3D r 15 / h 1, disabled)  [+]
│  └─ Ring (BuildRing: MeshInstance3D, PlaneMesh 2×2 escalado a r; y = 0,2; look = build_area_look.tres)  [+]
├─ ManaSource
├─ FreeFx · ManalithFx · FountSound · ManalithSound
├─ SummonSpot (Marker3D)
├─ GroundSnap
└─ ManalithLight
```

El radio de 15 m es el de `pushAll`. Cubre la caja del Shrine (11,3 m de semiancho) y se ajusta con el gizmo. En el editor el anillo se ve; en el juego queda oculto hasta que la vista previa lo muestra.

## 8. Responsabilidades

| Pieza | Hace | No hace |
|---|---|---|
| `StructureAction.check` (vía `Caster.aim_for`/`action_status`) | Única regla de «¿puedo construir acá?»: elige el manantial y da el motivo | Dibujar o empujar por su cuenta |
| `StructureAction._physics_process` | Mientras `_fount` no es nulo (entre `begin` y `finish`/`cancel`, solo en servidor), llama a `_fount.build_area.push_bodies()` | Decidir la fuerza |
| `BuildArea` | La zona: radio (forma), centro, empuje de un tick (`core_m`, `push_mps`), reenvía la vista previa al anillo | Saber de hechizos o del jugador |
| `BuildRing` | Dibuja oculto, válido o bloqueado con los colores del `look` | Leer la simulación |
| `ArmedPreview` | Cliente con jugador local: a 15 Hz, si hay una estructura armada con `Pick.GROUND`, rayo al suelo, `aim_for` y escritura del estado | Lanzar, mandar RPC o pintar el cursor |
| `CommandLog` | Guarda `aim_status`/`aim_site` y avisa con `aim_changed` | Dibujar |
| `CursorSkin` / `CommandCue` / `RefusalReason` | Cursor bloqueado / icono `ncst` sobre el icono armado / texto del motivo | Decidir el motivo |
| `CastTower.clear_footprint` | Al nacer la torre, saca cadáveres, almas y cuerpos vivos de la caja | Empujar durante el lanzamiento |

`ArmedPreview` es el único que escribe `aim_*` y el que muestra el anillo. `StructureAction` es el único que decide.

## 9. Resources, nodos y `@export`

- **Resources (tipo o look):** `BuildAreaLook` (`ok_color`, `blocked_color`, `width_m`) en `data/ui/build_area_look.tres`; `CueSet.blocked_cursor` en `command_cues.tres`; los textos en `strings.csv`.
- **Nodos (con gizmo):** `BuildArea` (radio = forma, regla C20) y `Ring` en `manafount.tscn`; `ArmedPreview` en `match.tscn`; `Reason` en `command_cue.tscn`.
- **`@export` de instancia:**
  - `BuildArea`: `core_m = 5`, `push_mps = 5`, `ring`.
  - `BuildRing`: `look`.
  - `ArmedPreview`: `armed`, `ray`, `probe`, `hz = 15`.
  - `RefusalReason`: `command_log`, `probe`, `flash_s = 0,6`, `offset_px`.
  - `ManafountBody`: `build_area`.
- **El color por manantial** va con `set_instance_shader_parameter`, para no duplicar el material.

## 10. Cómo lo hace un humano

| Verbo | Qué abre o toca | Lugares |
|---|---|---|
| Entender | `manafount.tscn`: se ve el cilindro y el anillo; `editor_description` de `BuildArea`; README de map | 1 |
| Modificar | Radio con el gizmo; `core_m`/`push_mps` en el inspector; colores en `build_area_look.tres`; cursor en `command_cues.tres`; textos en `strings.csv` | 1 c/u |
| Agregar | Otra estructura sobre el suelo: un `.tres` de hechizo con `StructureAction` y la vista previa sale sola. Otro motivo: una constante en `Refusal` y una fila en el csv | 2 |
| Quitar | Borrar `BuildArea`: aviso en `ManafountBody`, sin empuje, sin anillo y sin chequeo de estructuras. Borrar `ArmedPreview`: queda solo el parpadeo al hacer clic. Borrar `Reason`: sin texto | 1 |
| Crear | Otro look: duplicar el `.tres` | 1 |
| Escalar | Vista previa para hechizos comunes: `ArmedPreview` lee `mode == "spell"` con la misma `aim_for` (otro corte) | 1 script |
| Encontrar un bug | F6 en `manalith_build_area.tscn` y, en el inspector remoto, mirar `%Battle.aim_status`/`aim_site`; caso `build_area_cases` de la suite | 2 |

## 11. Contratos

```gdscript
# SpellAction.Aim
var site: Node3D        ## where the cast builds or lands when it is not `target` (a fount); previews draw there; null = none
# Caster
func aim_for(tag: String, point: Vector3, picked: Node3D) -> SpellAction.Aim   # read only, never begins
func action_status(tag: String, point: Vector3, picked: Node3D) -> String      # = aim_for(...).status
# Refusal
const FOUNT_TAKEN := &"fount_taken"
static func text(key: StringName) -> String   # tr("REFUSAL_" + upper); "" when the csv has no row
# TowerRules
static func closest_fount(tree, point: Vector3, max_distance: float, free_only := true) -> ManafountBody
static func has_room(tree, area: BuildArea) -> bool   # only `structure` bodies inside area radius; null area = true
# BuildArea extends CollisionShape3D
func radius_m() -> float
func center() -> Vector3
func push_bodies() -> int          # one tick, server/solo: wizard, unit, doctor alive; BodyNudge.push; returns moved
func show_preview(state: BuildRing.State) -> void
# BuildRing extends MeshInstance3D
enum State { HIDDEN, OK, BLOCKED }
func show_state(state: State) -> void
func set_radius(r: float) -> void  # called by BuildArea (calls go down)
# BodyNudge
static func push_speed(distance: float, inner: float, radius: float, speed: float, edge := 0.0) -> float
# CommandLog
signal aim_changed(status: StringName, site: Node3D)
var aim_status: StringName
var aim_site: Node3D
func show_aim(status: StringName, site: Node3D) -> void   # no-op when equal; disarm() clears
# CueSet
@export var blocked_cursor: Texture2D
```

`StructureAction.check` queda en este orden:

1. Manantial libre a ≤ 20 m del punto; si no hay, cerca del mago (alcance + 1).
2. Si no hay ninguno libre: el manantial ocupado más cercano al punto da `fount_taken` con `site` igual a ese manantial; si tampoco hay, `no_fount`.
3. `site = fount` y `point = anchor`.
4. `standing_status`: enfriando, sin maná, fuera de alcance.
5. `has_room(fount.build_area)`; si falla, `occupied`.

`begin` toma el manantial de `aim.site` (se va `data["fount"]`).

## 12. Subcortes (los developers no corren Godot)

- **S1, regla y simulación (servidor):**
  - `Aim.site`, `Caster.aim_for`, `Refusal.FOUNT_TAKEN`.
  - `TowerRules`, `StructureAction` (sin `_can_place`, con empuje).
  - `BuildArea` más el nodo en `manafount.tscn` y el socket en `ManafountBody`.
  - Pasar `push_speed` a `BodyNudge`; `clear_footprint` con cuerpos vivos.
  - Suite: `build_area_cases` (criterios 1 a 6), `action_cases`, `tower_cases`, `ritual_cases`.
- **S2, aviso en el cliente** (en paralelo, sobre los contratos de §11):
  - `BuildRing`, el shader, `BuildAreaLook` y su `.tres`, el `Ring` en `manafount.tscn`.
  - `CommandLog` aim; `ArmedPreview` en `match.tscn`.
  - `CueSet`/`CursorSkin`/`CommandCue`; `RefusalReason` con `Refusal.text` y `strings.csv`; líneas del consejero.
  - Escena de prueba y flujo `f388`.
- **S3, pasada única con Godot (orquestador):**
  - Import, suite quick y `build_area_cases`, flujo `f388` más la captura fija (criterios 7 a 10).
  - Banco quick con IA (criterio 11).
  - Lint.
  - Volver a grabar el digest de determinismo si cambió por el empuje (decisión ya tomada: se vuelve a grabar al final).

S1 se integra primero. S2 depende solo de las firmas.

## 13. Cómo verifica un humano en el editor

1. Abrir `manafount.tscn`: se ven el cilindro de `BuildArea` y el anillo verde. Cambiar el radio con el gizmo y el anillo lo sigue. Borrar `BuildArea` y aparece el aviso en `Manafount`.
2. Abrir `data/ui/build_area_look.tres`, cambiar `blocked_color` y comprobar que el `Ring` se actualiza en el editor.
3. F6 en `debug/spells/manalith_build_area.tscn`: recorrer los pasos de §5. Con el inspector remoto mirar `Hud/Battle.aim_status`. Hacer clic con las unidades a 5 y 8 m: se corren durante unos 11 s y aparece la torre.
4. Repetir con el Shrine (subir el mago a nivel 3 en la misma escena).

## 14. Riesgos y fuera de alcance

- **El cliente predice mal por la latencia:** el anillo da verde y el servidor rechaza. El servidor decide, y parpadean el icono y el motivo.
- **Unidades más rápidas que el empuje** (Druid a 11 m/s, contra 5 m/s en el núcleo): pueden volver a entrar. El barrido final de `clear_footprint` lo cubre. Puede haber temblores contra la evasión de NavigationAgent; es aceptable.
- **El barrido final** se ve como un salto (teletransporte replicado). Aceptable.
- **El navmesh:** confirmar en S3 que el horneado ignora la forma apagada, como ya pasa con `GroundFootprint` (mismo hash de `nav.res` si se vuelve a hornear uno).
- **El anillo sin depth test** puede verse por encima de lomas en 15 m de radio. Es portable; un `Decal` proyecta mejor, pero en el renderer Compatibility (web) es NO VERIFICADO.
- **Instance uniforms** en Compatibility: NO VERIFICADO.
- **Mapas que pisen hijos** de `manafount.tscn`: revisar que ningún `map.tscn` tenga editable children.
- **`caster.gd`** (466 líneas, por encima de 300) y **`command_cue.gd`** (162): no deben crecer de forma neta. Si `command_cue.gd` crece, el texto va en `RefusalReason` aparte.
- **Fuera de alcance:**
  - Que la torre nazca al empezar el lanzamiento y se destruya si se corta (fidelidad, Q6).
  - Vista previa para hechizos comunes.
  - Lanzar con clic derecho sobre el manantial.
  - Que `check_map` exija que no haya estructuras a 15 m de un manantial (opcional).

## 15. Preguntas, con mi recomendación

- **Q1. ¿El empuje mueve también al mago que lanza?** Recomiendo que sí, como `pushAll` sin filtro (NO VERIFICADO para el mago), con un knob `push_caster := true` en `BuildArea`.
- **Q2. ¿El anillo marca los 15 m del empuje o la base de la torre (unos 11 m)?** Recomiendo 15 m: es un solo número y muestra lo que se va a despejar.
- **Q3. ¿Anillo de malla o `Decal`?** Recomiendo malla: anda en cualquier renderer, incluido el port web.
- **Q4. ¿`RefusalReason` muestra el motivo de todos los rechazos (hechizos, órdenes) o solo el de la estructura apuntada?** Recomiendo todos: es un solo nodo y lo lee de `CommandLog`.
- **Q5. ¿Vista previa en vivo para los hechizos comunes, como hacía el original con `mouseTargetValid` para todos?** Recomiendo dejarlo para el próximo corte, reusando `ArmedPreview`.
- **Q6. ¿Torre que nace al empezar el lanzamiento (original) o al terminar (hoy)?** Recomiendo dejarlo para un RFC aparte: toca `StructureSpawner`, el corte del lanzamiento y la animación de subida.
- **Q7. ¿Textos?** Propongo:
  - `REFUSAL_NO_FOUNT`: «No hay un manantial libre cerca».
  - `REFUSAL_FOUNT_TAKEN`: «Ese manantial ya tiene torre».
  - `REFUSAL_OCCUPIED`: «Hay un edificio en el lugar».
  - `REFUSAL_OUT_OF_RANGE`: «Muy lejos».
  - `REFUSAL_NO_MANA`: «Falta maná».
  - `REFUSAL_COOLING`: «Todavía no está listo».
