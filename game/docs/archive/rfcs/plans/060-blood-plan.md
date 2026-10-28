Estado: **aprobado 2026-10-26** con estos cambios del usuario (mandan sobre el resto del plan):

1. Manchas permanentes en el pool de «Cantidad de marcas»: OK.
2. **Todo sangra.** Toda criatura que sufre daño sangra, sin excepciones (sin `none.tres` en ningún look; `none.tres` se puede quedar como dato disponible pero ningún look lo usa). «A nivel de diseño debería pensarse así»: el daño produce sangre, punto. Si algún camino de daño no provoca sangre hoy, analizar por qué y arreglarlo (todo daño que baje `Health.current`, sea melee, proyectil, hechizo, zona o veneno).
3. **Toda la sangre es roja.** Sin verde ni negro. Si hace falta una textura nueva, crearla con Material Maker o Aseprite (arte propio en `assets/blood/`).
4. Flash sutil 0,12 s, se apaga con «Sangre»: OK.
5. **El mago sangra en este corte**, reaprovechando los mismos nodos (`BloodFx` y `HitFlash` en `wizard_body.tscn`), sin código nuevo.
6. Sin hit-stop: OK.
7. Opción «Sangre» en Jugabilidad: OK.
8. Feature F390.

# Plan RFC-060: sangre y feedback de golpe (fase 2, solo presentación)

Base: rama `refactor/new-systems`, HEAD 23b1b83f. Leí `CONVENTIONS.md` entero, `RULES.md`, `VISUAL.md`, `PRD.md`, RFC-055 §12–§16 (§14.2 es el boceto de este RFC), las memorias que pediste y el código real. El lint de hoy está en verde y ningún conteo puede subir (C1a 83, C15 24, C16 17, C17 0, C23 0…).

---

## 0. Qué hacía el original y qué ya tenemos

**El original** (sacengine para el QUÉ, REA vía `rfcs/research/061S-scar-ground-marks.md`):
- **Gib.** Hace 40 `hoverBlood` y 20 chorros de 10 `blood` (`state.d:8310-8330`, `gibAnimation`). Usa una sola textura roja `blud` para todas las criaturas (`sacobject.d:1726-1730`). `locustBlood` usa la misma textura (`sacobject.d:1732-1735`). En el original no hay sangre de otro color.
- **Manchas en el suelo.** Existen en el ejecutable, no en sacengine. Cuando una partícula de sangre toca el suelo, pinta la SCAR `blud` de 8×8 px (1,25 m) en el mismo pool de baldosas que las demás cicatrices (`PARTICLESYSTEM::RunParticles`, G3D 0x1602018e-0x160201ed, 061S §2.4). Las manchas no se desvanecen; el tope es «Number of scars» (256 baldosas). El menú tiene un bit aparte para apagar la sangre (bit 0 de «Types of scars allowed», EXE 0x40d51e, 061S §2.3). Ya está importada: `assets/original/scars/blud.png` (8×8, rojo medio 107,4,1).
- **Al recibir daño.** El original reproduce un clip de dolor direccional (`damageAnimation`, `state.d:8780-8806`: `damageFront+dir`, `flyDamage`) y el sonido `damaged`. No hay flash ni hit-stop: no encontré nada en `state.d`. NO VERIFICADO con REA que el ejecutable tampoco los tenga. El `ScreenShake` del original solo lo disparan hechizos y rocas (`state.d:13417`, 16734, 21261…), nunca un golpe cuerpo a cuerpo.
- **Salpicadura al golpear.** sacengine no la tiene. RFC-055 §14.2 la toma de los videos (NO VERIFICADO con REA).

**El port hoy:**
- `Gib` (`scenes/units/gib.gd`) hace `FxBus.broadcast` de `data/fx/hover_blood.tres` y `data/fx/blood.tres`, sin manchas.
- `GibEffect` y `KillEffect` (`scenes/spells/effects/`) llaman a `Gib.burst`.
- `GroundScars` + `ScarMark` es el único dueño de las marcas del suelo. Es presentación, se apaga sin ventana y tiene la opción «Cantidad de marcas».
- `FxBus.play` / `ParticleType` traen pool, luz, sonido y `camera_trauma`.
- `CameraShake` ya tiembla con los golpes al mago local y lee `Health.changed`.
- `DamageNumbers` también lee `Health.changed`.
- `UnitSounds` ya hace sonar `damaged` cuando baja `Health.current`. Ese es el patrón exacto que sigue `BloodFx`.
- El debug `f375_hit_feel` usa la acción `debug_hit` (K).
- Ninguno de los 85 `*_clips.tres` tiene el rol `hit`: el clip de dolor no está importado.

---

## 1. Contradicciones y cuál gana

| # | Choque | Gana | Por qué |
|---|---|---|---|
| 1 | Tu pedido dice «escucha `Weapons.struck`», pero `struck` solo se emite en la simulación (`melee_weapon.gd:141-143`, dentro de `_land`). Los clientes nunca lo reciben. | **`Health.changed`** | `Health:current` se replica ON_CHANGE (`unit.tscn` properties/8). Así lo hacen `UnitSounds`, `DamageNumbers` y `CameraShake`. Escuchar `struck` dejaría a los clientes sin sangre y haría trabajar al dedicado. |
| 2 | §14.2 pide `CreatureType.blood_color`. | **`BodyLook.blood`** | La regla C23 del lint (conteo 0) prohíbe presentación en los tipos que lee el servidor. La apariencia y los sonidos viven en `BodyLook` (055s, posterior a §14.2). |
| 3 | §14.2 pide `BloodDecals`: `Decal` en el `LookRig`, con pool y `fade_s`. | **`GroundScars`** | El original pinta `blud` en el mismo pool de cicatrices (REA, 061S §2.4). Además rigen «un dueño por estado», «el look del original manda» y «no inventar». Consecuencia: **las manchas no se desvanecen** y las recorta «Cantidad de marcas». Va como pregunta 1. |
| 4 | §14.2 pide «rojo por defecto; verde, negro o nada». El original es rojo siempre. | **El boceto del usuario, pero el color es la elección de un `.tres`, no un campo `Color`** | `blud.png` es rojo puro (media 53,0,0) y el shader multiplica el tinte, así que verde × rojo da negro. Para verde o negro hace falta arte nuevo (pregunta 3). |
| 5 | Tu pedido sugiere «un hit-stop chico si va». | **Sin hit-stop** | `Engine.time_scale` frena la simulación en solo, que corre en el mismo proceso. Congelar un cuerpo sería un segundo escritor de la reproducción del rig (`BodyRig.set_paused`, `Afflictions`), lo que viola «un dueño». El original no lo tiene. |
| 6 | El feedback del original es el clip de dolor. | **Fuera de 060** | No está importado en ningún modelo. Requiere importar `damageFront…` y un dueño de reproducción: un RFC propio. |
| 7 | RFC-055 §14.2 cita `unit_body.gd:608`. | Cita vieja | El archivo tiene 197 líneas; el gib vive en `gib.gd`. Corregir la cita en RFC-055 al cerrar. |

Autoridad: PRD > FEATURES > RULES > VISUAL > RFC > este plan. VISUAL dice que el original manda, y eso decide el #3.

---

## 2. Objetivo y criterios de aceptación (medibles)

Todo con la cámara fija de `blood_lab`, con ventana salvo donde se dice. Cada chequeo imprime `BLOOD <check>: PASS|FAIL`.

1. **Salpicadura.**
   - Un golpe del 20 % a un Trogg (K): en ≤ 1 cuadro, `FxBus.played` emite `blood_hit.tres` a ≤ 0,15 m de `body.soul_anchor()` y `BloodFx.sprays` sube en 1.
   - Un golpe ≥ `heavy_from` (40 %) emite `blood_hit_heavy.tres`.
2. **Manchas.**
   - El golpe del 20 % pinta `marks_per_spray` (1) manchas `blud`, a ≤ `mark_radius_m` (1,5 m) de los pies: `GroundScars.log_lines` suma 1 línea «painted blud.png» y `painted_tiles()` es mayor que 0.
   - El golpe fuerte pinta 3.
   - Un cuerpo a más de `mark_max_height_m` (1 m) sobre el suelo, como un volador, no pinta: la línea dice «refused (too far…)».
3. **Sin spam.** Diez golpes del 1 % en 1 s, como el veneno, dan ≤ 3 salpicaduras: se acumula hasta `min_lost` = 3 % y entre una y otra pasan ≥ `every_s` (0,25 s).
4. **Sin sangre.** Una criatura con `none.tres`: 0 salpicaduras y 0 manchas tras 5 golpes.
5. **Gib con charco.**
   - `Gib.burst` sobre un Trogg deja ≥ 8 manchas `blud` en un radio de 4 m (`SprayMarks`).
   - Sin ventana, `-- --blood-headless` comprueba que `BloodFx.is_active()` y `SprayMarks.is_active()` son false y que `GroundScars.painted_tiles()` es 0. Esto vale también como prueba de que el dedicado no hace nada.
6. **Flash (si se aprueba, pregunta 4).**
   - El parámetro de instancia `hit_flash` llega a un pico ≤ `peak` (0,45) y vuelve a 0 en `flash_s` (0,12) + 0,05 s.
   - `material_overlay` queda en null al terminar.
   - Un cuerpo en sigilo (`SpecialForms.stealth`) no destella.
7. **Opción apagada.** Con «Sangre» apagada en FeelPrefs: 0 salpicaduras, 0 manchas y 0 flashes.
8. **Medible visual.** Captura fija `f390_01` antes y `f390_03` 5 s después de 3 golpes fuertes. En el rectángulo del suelo bajo el Trogg, los píxeles con R > 80, R > 2·G y R > 2·B pasan de < 20 a ≥ 150 (`tools/look/` o el harness).
9. **Lint.** `bash tools/lint/conventions.sh`: ningún conteo sube.

---

## 3. Escena de prueba

`res://debug/fx/blood_lab.tscn` [+] con `debug/fx/blood_lab.gd` [+] (~120 líneas, solo debug). Es la ruta de §14.2, carpeta `debug/fx/`.

- **Qué instancia del producto:**
  - `scenes/map/maps/test_flat/map.tscn`, con su `Terrain` y `GroundScars` reales, como `scars_lab`;
  - una `Camera3D` fija con `CameraShake`;
  - `scenes/units/unit.tscn` tres veces: TroggA y TroggB con `trogg.tres`, y Stone con `earthfling.tres` y, con «Hijos editables», `BloodFx.fallback = data/fx/blood/none.tres`;
  - `SprayMarks` (`scenes/fx/blood/spray_marks.tscn`).
  - Un atajo es otro valor del mismo nodo, no otro script.
- **Estado inicial:** suelo limpio (0 baldosas pintadas), tres cuerpos quietos a vida llena, «Sangre» prendida.
- **Qué todavía no está:** salpicadura, manchas y flash.
- **Acciones del InputMap que pulsa el playtester:**
  - `debug_hit` (K, ya existe): 20 % al siguiente cuerpo, en rueda;
  - `debug_hit_heavy` [+] (Shift+K): 45 %;
  - `debug_gib` [+] (G): `Gib.burst` al siguiente.
  - El golpe del lab baja `Health.current` igual que se ve en cualquier peer: es el mismo camino que `f375_hit_feel.hit()`.
- **Sin ventana:** `-- --blood-script` corre los chequeos 1–7 con `run_headless` en los nodos (como CameraShake). `-- --blood-headless` es el 5b.
- Esto queda en el `F390` de FEATURES. F389 es de 065; confirmá el número.

---

## 4. Árbol de archivos

```
scenes/
├─ fx/blood/                                  [+] sistema nuevo
│  ├─ README.md                               [+] What/Not/Talks to/Edit/Check
│  ├─ blood_type.gd                           [+] BloodType (Resource, ~45)
│  ├─ blood_rules.gd                          [+] BloodRules (static, ~50): cuántas salpicaduras, puntos de las manchas
│  ├─ blood_fx.gd                             [+] BloodFx (Node, ~110)
│  ├─ spray_marks.gd                          [+] SprayMarks (Node, ~60): charco del gib
│  └─ spray_marks.tscn                        [+]
├─ look/
│  ├─ hit_flash.gd                            [+] HitFlash (Node, ~90)          (060c, opcional)
│  └─ hit_flash.gdshader                      [+] unshaded, blend_add, instance uniform float hit_flash
├─ bodies/body_look.gd                        [~] + @export var blood: BloodType (+3 líneas)
├─ units/unit.tscn                            [~] + hijos BloodFx y HitFlash
├─ match/match.tscn                           [~] + SprayMarks junto a DamageNumbers   COMPARTIDO con 065 (S5 opcional)
└─ ui/options/
   ├─ feel_prefs.gd                           [~] + blood() / set_blood() (+ hit_flash si se aprueba)   (060d)
   └─ gameplay_tab.tscn / gameplay_tab.gd     [~] + CheckButton «Sangre»
data/
├─ fx/blood_hit.tres                          [+] ParticleType: blud 4x4, count 14, speed 1,5–6, gravity 15, vida 0,9, lit, mix, SIN sonido, pool_max 64, fade
├─ fx/blood_hit_heavy.tres                    [+] igual, count 40, speed 2–10
├─ fx/blood/red.tres                          [+] BloodType: sprays de arriba, mark = assets/original/scars/blud.png
├─ fx/blood/none.tres                         [+] BloodType vacío (no sangra)
├─ look/hit_flash.tres                        [+] ShaderMaterial (060c)
└─ ui/feel_prefs.tres                         [~] default_blood = true
scenes/units/bodies/<criatura>_look.tscn      [~] blood = none.tres solo en la lista que apruebe el usuario (060e)
debug/fx/
├─ blood_lab.tscn                             [+]
└─ blood_lab.gd                               [+]
project.godot                                 [~] + debug_hit_heavy, debug_gib
agent/flows/f390_blood.json                   [+] capturas f390_01..03 con cámara fija
FEATURES.md                                   [~] F390        COMPARTIDO con 065 (F389)
rfcs/RFC-060-blood-hit-feedback.md            [+] spec corta a partir de §14.2 con estas decisiones
```

- **No se tocan**: `particle_type.gd`, `fx_atlas.gd` y `sprite_emitter.gd` (los cambia 065), `GroundScars`, `ScarMark`, `Gib`, `Health`, `addons/terrain_tools`, `tower.tscn`, `wizard_sounds.gd` ni `wizard_body.tscn`.
- **Compartidos**: `match.tscn` (065 S5 opcional) y `FEATURES.md` (065). `scenes/fx/README.md` no se toca: la carpeta nueva trae su propio README.

---

## 5. Árboles de nodos

**unit.tscn** (solo se agregan dos hijos):
```
Unit (UnitBody)
├─ Tilt/Mesh/Rig (BodyRig)              ya existe
├─ Health                               ya existe
├─ UnitSounds                           ya existe (mismo patrón)
├─ BloodFx (Node)            [+] body=..  health=../Health  fallback=red.tres  prefs=feel_prefs.tres
└─ HitFlash (Node)           [+] health=../Health  rig=../Tilt/Mesh/Rig  forms=../SpecialForms
                                 material=hit_flash.tres  prefs=feel_prefs.tres
```

**match.tscn:**
```
HighNoon
├─ DamageNumbers            ya existe
└─ SprayMarks (Node)        [+] sprays=[blood.tres]  blood=red.tres  marks=12  radius_m=4
```

**`<criatura>_look.tscn`:** se agrega el campo `blood` en la raíz `BodyLook`. Vacío = el `fallback` de BloodFx (rojo).

**blood_lab.tscn:**
```
BloodLab (Node3D, blood_lab.gd)  camera, targets[], status
├─ WorldEnvironment, Sun
├─ Map (test_flat/map.tscn)       Terrain/GroundScars reales
├─ Camera (Camera3D fija) / CameraShake
├─ World/TroggA, TroggB, Stone (unit.tscn; Stone con BloodFx.fallback = none.tres)
├─ SprayMarks (spray_marks.tscn, run_headless solo bajo --blood-script)
└─ Overlay/Status (Label)
```

---

## 6. Responsabilidades (una frase; qué NO hace)

| Pieza | Hace | No hace |
|---|---|---|
| `BloodType` | Dice cómo sangra un tipo de cuerpo: salpicadura liviana y fuerte, umbrales, cada cuánto, imagen y cantidad de manchas. | Decidir cuándo sangra ni pintar nada. |
| `BloodRules` | Hace las cuentas: dado lo perdido, nada, liviana o fuerte; puntos de manchas en un disco con un `RandomNumberGenerator` propio. | Tocar el árbol, FxBus ni GroundScars. |
| `BloodFx` | Hijo del cuerpo. Cuando baja `Health.current`, acumula lo perdido. Al pasar `min_lost` (y si pasó `every_s`), hace `FxBus.play(spray, soul_anchor)` en este peer y pide manchas a `GroundScars.of(self).stamp(mark, p, mark_max_height_m)`. Elige el tipo con `body.mount.look.blood` o, si no hay, `fallback`. Se calla si el cuerpo no está visible, si no carga mallas (dedicado o headless), en los primeros `quiet_s` (0,5 s, para el primer valor que llega a un cliente que entra tarde) o con la opción apagada. Señal `bled(at, heavy)` y contadores `sprays`/`marks` para el inspector y los chequeos. | Escribir la simulación, usar el RNG global, crear nodos, hacer un RPC ni sangrar edificios. |
| `SprayMarks` | Escucha `FxBus.played`. Cuando el efecto está en `sprays` (el gib), pinta `marks` manchas del `blood.mark` en `radius_m`. | Decidir quién explota (eso es `Gib`) ni sonar. |
| `HitFlash` | Cuando baja la vida, pone `material_overlay` en `rig.skinned_meshes()` y anima con un tween `hit_flash` de `peak` a 0 en `flash_s`; después lo saca. Se calla en sigilo, sin mallas o con la opción apagada. | Tocar las sobreescrituras de superficie (eso es de `StoneLook`) ni la velocidad del rig. |
| `BodyLook.blood` | Guarda la sangre de esta apariencia, junto a `sounds`. | Nada en el servidor: solo un cliente construye el look. |
| `FeelPrefs.blood` | Es la preferencia local «Sangre» (como el bit `bscr` del original). | Ser regla de partida ni viajar por la red. |

---

## 7. Resource, nodo o `@export`

- **Resource de tipo:**
  - `BloodType` (`red.tres`, `none.tres` y, si se aprueban, `green`/`black`);
  - `ParticleType`: `blood_hit`, `blood_hit_heavy`;
  - `ShaderMaterial` `hit_flash.tres`.
  - No se mutan en runtime.
- **Nodo:** `BloodFx` y `HitFlash` (hijos de cada unidad), `SprayMarks` (uno por partida).
- **`@export` de instancia:**
  - sockets: `body`, `health`, `rig`, `forms` y `prefs`, cada uno con `_get_configuration_warnings`;
  - `BloodFx.fallback` y `quiet_s`;
  - `HitFlash`: `peak`, `flash_s`, `color` y `min_lost`;
  - `SprayMarks`: `sprays`, `blood`, `marks` y `radius_m`;
  - `run_headless`, solo para chequeos.
- **Estado de runtime en el nodo:** lo perdido acumulado, el último `current`, el tiempo de la última salpicadura y los contadores.

---

## 8. Cómo lo hace un humano (seis verbos + encontrar un bug)

| Verbo | Qué abre o toca | Lugares |
|---|---|---|
| Entender | `scenes/fx/blood/README.md`, o el `##` de `BloodFx` en el inspector | 1 |
| Modificar | Más o menos sangre: `data/fx/blood/red.tres` (umbrales, manchas) o `data/fx/blood_hit.tres` (partículas). El flash: el nodo `HitFlash` de `unit.tscn` | 1 |
| Agregar | Sangre verde: duplicar `red.tres` → `green.tres` con su spray y su mancha, y asignarla en `<criatura>_look.tscn` → `blood` | 2 |
| Quitar | Una criatura que no sangra: `blood = none.tres` en su look. Sacar todo: borrar los nodos `BloodFx`/`HitFlash` de `unit.tscn`, o la opción «Sangre» | 1 |
| Crear | Una criatura propia de Blender: su `_look.tscn` ya sangra rojo sin tocar nada; otra sangre = elegir el `.tres` | 0–1 |
| Escalar | Sangre en el mago: el mismo nodo `BloodFx` en `wizard_body.tscn` (sin código nuevo; pregunta 5). Muchos combates: `pool_max` del spray y «Cantidad de marcas» | 1 |
| Encontrar un bug | `blood_lab.tscn` (F6, K, Shift+K, G). Remote → `BloodFx.sprays`/`marks`. `GroundScars.log_lines` dice por qué se rechazó una mancha («not over land», «too far»). Canal `DebugLog` `blood` | 1 |

---

## 9. Contratos (firmas)

```gdscript
class_name BloodType extends Resource
@export var spray: ParticleType                 ## empty = no spray
@export var heavy_spray: ParticleType           ## empty = spray
@export_range(0.0, 1.0) var heavy_from := 0.4   ## share of max health in one drop
@export_range(0.0, 1.0) var min_lost := 0.03    ## accumulated share before bleeding
@export_range(0.0, 5.0, 0.05, "suffix:s") var every_s := 0.25
@export var mark: Texture2D                     ## a SCAR picture (blud.png = 1.25 m); empty = no marks
@export_range(0, 8) var marks_per_spray := 1
@export_range(0, 16) var heavy_marks := 3
@export_range(0.0, 10.0, 0.1, "suffix:m") var mark_radius_m := 1.5
@export_range(0.0, 10.0, 0.1, "suffix:m") var mark_max_height_m := 1.0
```

- `BloodRules.kind_for(lost_share: float, type: BloodType) -> int`: 0, 1 o 2.
- `BloodRules.mark_points(center: Vector3, count: int, radius_m: float, rng: RandomNumberGenerator) -> PackedVector3Array`.
- `BloodFx`: `signal bled(at: Vector3, heavy: bool)`, `func is_active() -> bool`, `var sprays: int`, `var marks: int`.
- `SprayMarks.is_active() -> bool`.
- `HitFlash.is_active() -> bool`.
- `FeelPrefs.blood() -> bool`, `set_blood(on: bool, save := true)`.

Consumidos sin cambios: `Health.changed`, `FxBus.play`, `GroundScars.of`, `GroundScars.stamp`, `BodyMount.look`, `BodyRig.skinned_meshes`, `UnitBody.soul_anchor`.

---

## 10. Subcortes y paralelismo

Los developers no corren Godot; hay una sola pasada de pruebas al final.

1. **060a (núcleo):** `BloodType`, `BloodRules`, `BloodFx`, `blood_hit*.tres`, `red`/`none.tres`, `BodyLook.blood`, el hijo en `unit.tscn`, el README, `blood_lab` y las acciones del InputMap.
2. **060b (charco del gib):** `SprayMarks` en `match.tscn` y la tecla G del lab. Depende de 060a (usa `red.tres` y `BloodRules`).
3. **060c (flash, opcional según la pregunta 4):** `HitFlash`, el shader, el material y el hijo en `unit.tscn`. Va en paralelo a 060a en carpetas, pero los dos editan `unit.tscn`: **un solo developer agrega los dos nodos**, o 060c se hace después de 060a.
4. **060d (opción «Sangre»):** `FeelPrefs` y `GameplayTab`. Después de 060a y 060c, porque las dos leen `prefs`.
5. **060e (datos):** `none.tres` en los looks de la lista que confirme el usuario. Es trabajo de inspector y se puede hacer en paralelo a todo.
6. **060z:** F390 en FEATURES, la spec RFC-060 y la pasada única de pruebas: `--blood-script`, `--blood-headless`, el flujo `f390_blood` con las capturas y el lint.

En paralelo: 060a junto con 060e; después 060b junto con 060c. Godot solo en 060z, respetando la cola FIFO.

---

## 11. Tests

- `blood_lab.tscn -- --blood-script`: criterios 1–4, 5a, 6 y 7. Imprime `BLOOD … PASS|FAIL` y sale con 0 o 1; tiene un guardián de tiempo.
- `blood_lab.tscn -- --blood-headless`: criterio 5b.
- `agent/flows/f390_blood.json`: capturas fijas y el criterio de píxeles rojos (8).
- Banco de casos existente: `debug/fx/f379_fx_fade` recorre todo `data/fx/`. Los dos sprays nuevos tienen que pasar su chequeo de desvanecido (con `fade_s` o la cola), y `fx_gallery` los muestra solos.
- `f375_hit_feel --feel-script` tiene que seguir en PASS, porque el spray no trae `camera_trauma` ni sonido.
- Sin banco de determinismo (pospuesto según la memoria): la sangre no escribe la simulación.

---

## 12. Red y determinismo

- **Simulación:** no se toca nada. No hay RPC nuevo ni `submit_*`, y el dedicado no hace trabajo nuevo: `BloodFx`, `HitFlash` y `SprayMarks` se apagan cuando `BodyLook.loads_meshes()` es false, y `GroundScars` ya está inactivo sin ventana. El gib sigue con su `broadcast` de siempre.
- **Cliente:** deriva todo de `Health:current`, que se replica ON_CHANGE. Si el sincronizador junta dos golpes en un solo cambio, el cliente ve una salpicadura más fuerte en vez de dos. Es aceptable.
- **Quien entra tarde:** no ve manchas viejas (igual que `ScarMark` hoy). `quiet_s` evita sangrar por el primer valor que llega.
- **Solo y host:** el mismo proceso dibuja una vez y nunca escribe hacia la simulación. RNG propio por nodo, sembrado con el id de instancia; las semillas de FxBus vienen de su propio generador. Nada llama `randf()` global.

---

## 13. Riesgos

- **Manchas eternas y pool compartido.** Mucha pelea en una zona reclama baldosas y desaloja cicatrices viejas de hechizos. Es fiel al original, pero se nota. Lo mitigan `every_s`, `marks_per_spray = 1` y la opción.
- **Costo de `GroundScars.stamp`.** Cada llamada pinta y sube una capa de 64×64 RGBA. El tope por cuerpo (`every_s`) lo acota; en el lab medir que una pelea de 40 unidades se quede en ≤ 30 manchas por segundo.
- **Pool de partículas.** `pool_max 64` es el tope global del spray; si se llena, se recicla el emisor más viejo.
- **Flash y sigilo o fantasma.** Un overlay aditivo delataría al cuerpo: por eso el socket `forms` y la regla de no destellar en sigilo. Que nadie más use `material_overlay` en los cuerpos está verificado con grep (0 usos); hay que vigilarlo.
- **Gib.** El cliente también ve la caída a 0 y salpica una vez más, junto al gib: es aceptable. El gib sigue rojo para todas las criaturas, también una elemental (igual que el original); colorearlo por criatura queda fuera.
- **`Health:current` sin `spawn = true`.** El primer valor que recibe un cliente puede ser una baja; `quiet_s` lo cubre. Hay que verificarlo en la pasada en red (NO VERIFICADO).
- **`unit.tscn` es grande y central.** Agregar dos hijos tiene conflicto bajo, pero hay que revisar `node_paths` al fusionar.

**Fuera de alcance:**
- el clip de dolor direccional (RFC propio: importar `damageFront…` más un dueño de reproducción);
- sangre de otro color en el gib;
- desvanecer las manchas;
- sangre en el mago (salvo que se apruebe la pregunta 5);
- hit-stop.

---

## 14. Preguntas, cada una con recomendación

1. **¿Las manchas se quedan, como en el original (pool «Cantidad de marcas»), o se desvanecen?** Recomiendo que **se queden**: es fiel al REA, tiene un solo dueño y no suma un segundo sistema. Si las querés con desvanecido, sería un cambio en `GroundScars` (un sistema compartido) en otro corte.
2. **¿Quiénes no sangran?** Recomiendo rojo por defecto para todas y `none.tres` solo para las que no son de carne. Lista propuesta, a confirmar porque el original no distingue: Earthfling, Boulderdash, Jabberocky, Ghost, Flame Minion, Squall y Snowman. El resto, rojo.
3. **¿Verde y negro?** Hace falta arte, porque `blud` es rojo puro y el tinte no sirve. Recomiendo dejar verde y negro fuera de 060. Si los querés, recolorear `blud` (el atlas de 128 px y la SCAR de 8 px) con el MCP de Aseprite en `assets/blood/` (arte propio, no en `assets/original/`) y crear `green.tres` y `black.tres`.
4. **¿Flash de golpe?** El original no lo tiene. Recomiendo **sí, sutil** (pico 0,45, 0,12 s, blanco cálido) y que se apague con la misma opción «Sangre». Alternativa: dejar 060c para después de ver las capturas.
5. **¿Sangra el mago?** Recomiendo **no en 060**: su golpe ya tiene el temblor de cámara y `wizard_body.tscn` queda quieto mientras corre 065. Agregarlo después es un nodo más, sin código.
6. **¿La opción va en Jugabilidad («Sangre», `FeelPrefs`) o en Gráficos?** Recomiendo **Jugabilidad**: ahí ya están el temblor y los números de daño.
7. **Número de feature:** recomiendo **F390** (F389 es de 065).

---

## 15. Cómo lo verifica un humano en el editor

1. Abrir `debug/fx/blood_lab.tscn` y pulsar F6.
2. K: el Trogg salpica y deja una mancha de unos 1,25 m a sus pies.
3. Shift+K: salpica más y deja tres manchas.
4. G: el gib deja un charco.
5. Stone no sangra.
6. En el panel Remote, `World/TroggA/BloodFx` muestra `sprays` y `marks`.
7. Abrir `data/fx/blood/red.tres`, subir `heavy_marks` y volver a probar.
8. Opciones → Jugabilidad → apagar «Sangre»: ya no aparece nada.
9. En `unit.tscn`, seleccionar `BloodFx` sin `health`: el inspector avisa con un warning.

Al terminar: `bash tools/lint/conventions.sh`, y ningún conteo puede subir. Los README nuevos llevan `Check:`, no `Debug:`.

---

## Archivos relevantes (absolutos)

- /Users/joelsartori/Development/sacproject/game/rfcs/RFC-055-human-first-refactor.md (§14.2, cita vieja `unit_body.gd:608`)
- /Users/joelsartori/Development/sacproject/game/rfcs/research/061S-scar-ground-marks.md (§2.3, §2.4: la sangre del original pinta `blud`)
- /Users/joelsartori/Development/sacproject/game/scenes/units/gib.gd
- /Users/joelsartori/Development/sacproject/game/scenes/units/weapons/melee_weapon.gd (líneas 141-143: `struck` solo en la simulación)
- /Users/joelsartori/Development/sacproject/game/scenes/audio/unit_sounds.gd (el patrón a seguir)
- /Users/joelsartori/Development/sacproject/game/scenes/components/health.gd
- /Users/joelsartori/Development/sacproject/game/scenes/map/terrain/ground_scars.gd
- /Users/joelsartori/Development/sacproject/game/scenes/spells/scar_mark.gd
- /Users/joelsartori/Development/sacproject/game/scenes/bodies/body_look.gd
- /Users/joelsartori/Development/sacproject/game/scenes/bodies/body_rig.gd (`skinned_meshes`)
- /Users/joelsartori/Development/sacproject/game/scenes/look/stone_look.gd (dueño de las sobreescrituras de superficie)
- /Users/joelsartori/Development/sacproject/game/scenes/camera/camera_shake.gd
- /Users/joelsartori/Development/sacproject/game/scenes/fx/fx_bus.gd
- /Users/joelsartori/Development/sacproject/game/scenes/fx/damage_numbers.gd
- /Users/joelsartori/Development/sacproject/game/scenes/ui/options/feel_prefs.gd
- /Users/joelsartori/Development/sacproject/game/scenes/units/unit.tscn
- /Users/joelsartori/Development/sacproject/game/scenes/match/match.tscn (compartido con 065)
- /Users/joelsartori/Development/sacproject/game/data/fx/blood.tres
- /Users/joelsartori/Development/sacproject/game/data/fx/hover_blood.tres
- /Users/joelsartori/Development/sacproject/game/assets/original/scars/blud.png
- /Users/joelsartori/Development/sacproject/game/debug/fx/f375_hit_feel.gd
- /Users/joelsartori/Development/sacproject/game/debug/look/scars_lab.tscn
- /Users/joelsartori/Development/sacproject/game/tools/lint/conventions.sh (C23)
- /Users/joelsartori/Development/sacproject/game/rfcs/plans/065-build-feedback-plan.md (para ver qué archivos se comparten)
- /Users/joelsartori/Development/sacproject/sacengine/source/state.d (8310-8330, 8780-8806, 13417)
- /Users/joelsartori/Development/sacproject/sacengine/source/sacobject.d (1726-1735)
