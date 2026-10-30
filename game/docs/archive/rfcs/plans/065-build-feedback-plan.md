# Plan 065 (F389, propuesto): que se sienta construir una torre (partículas en el borde, luz que crece, canto, inicio, final y corte)

> **Estado:** aprobado por el usuario el 2026-10-26, con todas las recomendaciones de §14:
> - el corte es una explosión;
> - el canto se encadena en todos los lanzamientos;
> - el inicio suena con `cnj1-6` y el final con `SUMN`, más el zumbido;
> - sin pulso de post-proceso;
> - 180 anillos/s, que bajan a 90 si cuestan más de 1 ms;
> - el borde va en azul y la columna toma el color del lado;
> - el trauma final es 0,5;
> - ID 065 / F389.

No hay ID de RFC. Propongo **plan 065 / F389** como continuación de 064 (F388). Confirmalo o cambialo (pregunta 8).

Leí `CONVENTIONS.md` completo, RULES §Fidelidad, VISUAL, el plan 064 y el código real. Lint de hoy: todo OK, nada sube (C1a 83/84, C15 24/26).

## 0. Qué hacía el original (sacengine, con cita)

**Al empezar el lanzamiento**
- El edificio nace inactivo, transparente y sin daño, con la línea de corte 2 m bajo la base (`state.d:10076-10081`, `29467-29473`).
- La fuente se apaga en ese momento: se van el chorro y su loop (`putOnManafount` → `manafount.deactivate`, `state.d:8503`, `1716-1724`).
- No hay sonido ni burst propio de estructura.
- El inicio lo marca el **canto del mago**: `startCasting` toca un `incantation` al azar del SSET del mago (`Xinc`, `state.d:9532`), con ganancia 1.5 (`state.d:31033`).
- Las partículas de manos del dios salen todo el lanzamiento (`state.d:15248`, `16165-16226`).

**Mientras sube**
- **El canto se repite sin parar.** Cuando termina un clip, a los 0,1 s suena otro al azar (`timer2`, `state.d:14263-14270`). En la animación final solo entra un clip que quepa en lo que queda.
- No se corta al interrumpir: no hay `stopSoundsAt` del mago (solo para criaturas, `state.d:15207`, `15215`).
- Nuestros clips miden entre 0,67 y 0,88 s (`assets/original/audio/voice/_wspw/w1xx.ogg`). En un Manalith de 11,1 s son unos 12 clips.
- **Hoy `WizardSounds` toca uno solo** (`scenes/audio/wizard_sounds.gd:53-57`).
- **BlueRing** (`state.d:15237-15244`):
  - por cada parte del edificio y por tick (60 Hz) nacen de 1 a 5 anillos `uniform(1,6)`, en el eje de la parte, a una altura al azar dentro de la banda de 2 m del corte;
  - la escala va al azar de 0,875 a 1,125 y baja 1 por segundo, así que viven unos 1 s (`state.d:15280-15287`);
  - **dejan de nacer 0,5 s antes del final** (`state.d:15238`);
  - el sprite es `brng` 4x4, de 28x28 m a escala 1 (`sacobject.d:2145-2157`), en el plano XY de sacengine, es decir **horizontal**;
  - es aditivo, sin escribir profundidad, de dos caras, con energía `20*scale^4` (`renderer.d:181-190`, `1733-1748`).
- No hay luz dinámica.
- Las partículas de suelo eran un TODO que nunca se hizo (`state.d:15246`, `15249`).

**Al terminar**
- `activate` → `loopingSoundSetup`: arranca el zumbido del Manalith (`mlth`; el Shrine usa `afir`), en loop, ganancia 0.75 (`state.d:1750-1754`, `sacobject.d:266-272`, `audioBackend.d:252-254`).
- La columna de maná del lado (`animateManalith`) solo se dibuja con el edificio activo (`state.d:27983-27997`).
- **No hay flash, ni burst, ni shake.** `screenShake` tiene 6 llamadores y ninguno es de estructuras (`state.d:13417`, `16734`, `19151`, `21261`, `21375`, `21709`, `24088`).
- **El final del original es «aparece la columna y empieza el zumbido».**

**Al cortarse**
- `destroy` → `BuildingDestruction` (`state.d:15262-15263`, `8376-8380`, `15157-15181`).
- Por cada parte: `destructionAnimation` → `animateDebris` (35 escombros) + `explosionAnimation`, que toca `fbxp` con ganancia 10 y dos explosiones con sus partículas (`state.d:27625-27660`).
- La torre a medio subir **explota**. No es un dissolve.

**Lo que esto revela de 064 (es el hallazgo principal).** Desde que 064 hace nacer la torre al empezar el lanzamiento, `CastTower._ready` → `fount.occupy()` prende la columna (`ManalithFx`), `ManalithLight` y `ManalithSound` **al empezar** (`scenes/map/props/manafount_body.gd:115-129`). El original los prende **al terminar**. Por eso hoy no se nota el final. Arreglarlo es la marca de final fiel, y sale gratis.

**Lo que agregamos porque el usuario lo pidió (no está en el original):** la luz que sube, el burst y el flash del inicio y del final, el shake y el pulso opcional. Esto está por encima de la memoria «el look del original manda», con el tope «sin bloom fuerte». Ojo: VISUAL.md dice «bloom en lo que emite luz» y la memoria del usuario (2026-10-24) dice «sin bloom fuerte». Gana la indicación del usuario: un bloom sutil y medido (criterio 5). Conviene ajustar VISUAL.md.

## 1. Objetivo
- Mientras sube: anillos azules horizontales en el borde del corte y una luz azul que sube con el borde y crece con `build_progress`.
- El canto del mago se encadena todo el lanzamiento (como el original) y no se encadena más al terminar o cortarse.
- Inicio claro: burst chico, flash de luz y un sonido de conjuro en la base, solo en una torre que empieza.
- Final claro:
  - aparecen la columna, la luz y el zumbido del Manalith (fiel);
  - más un burst, un flash, un sonido y un shake corto que solo siente quien está cerca;
  - el pulso de post-proceso es opcional.
- Corte: la torre explota en la línea del corte (fiel) en vez de desaparecer.
- Todo sale del estado replicado (spawn, `build_progress`, despawn). Cero RPC nuevos, y uno menos (`rise_fx`). El dedicado no dibuja ni suena nada.

## 2. Criterios medibles
Cámara fija de la escena de prueba, `--fixed-fps 60`. Manalith de 11,1 s = 666 ticks, el tick 0 es el clic.

1. **Anillos.** `Tower/BuildEdge/EdgeRings`:
   - prendido (`is_active()`) para `build_progress` en [0,01; 0,955);
   - apagado para ≥ 0,955 (los 0,5 s finales) y con la torre en pie;
   - su `global_position.y` = `BuildReveal.line_y() + edge_width_m/2` ± 0,05 m;
   - las capturas `f389_02`/`03` muestran anillos planos (vistos desde arriba en elipse) a la altura del borde.
2. **Luz que sube.** `EdgeLight.light_energy` = 2,0 × curva(p), con la curva lineal de 0,15 a 1, ±5 %: 0,725 en p=0,25, 1,15 en p=0,5 y 1,575 en p=0,75. Su Y sigue la línea.
   - Al quedar en pie baja a 0 en 1,0 ± 0,1 s, mientras `ManalithLight` sube de 0 a 1,6 en 1,0 s desde el mismo tick.
   - Nunca quedan las dos por debajo de 0,2 más de 0,1 s.
3. **Línea de tiempo del sonido** (SoundLog):
   - `INCANTATION` del mago en el tick 0 y después cada (clip más largo + 0,1 s): ≥ 10 entradas en [0, 666) y ninguna nueva después del fin. Hoy hay 1.
   - `build_start` en el tick 0 a 2.
   - El `LOOP` de `fountain_loop` se suelta en los ticks 0 a 30 (`check_s` 0,5).
   - El `LOOP` de `manalith_loop` se toma recién en el tick ≥ 666. Hoy se toma en ~0.
   - `build_done` en 666 ± 2.
   - Con corte: `explosion_burst` en el tick del corte ± 2, nunca `manalith_loop`, y `fountain_loop` vuelve dentro de 0,5 s.
4. **Shake.** Justo después del final, `CameraShake.trauma` = 0,5 dentro de 8 m, 0,5·(40−d)/32 entre 8 y 40 m y 0 a partir de 40 m.
   - Vuelve a 0 en ≤ 0,2 s.
   - Con «Sacudida» en 0 %: offset 0.
5. **Flash sin bloom fuerte** (captura fija `f389_05` en el final + 0,1 s, contra `f389_04` en p≈0,95):
   - píxeles con algún canal ≥ 250: ≤ base + 1,5 % del cuadro;
   - luminancia media en un cuadro de 200x200 px en la base: ≤ +25 % en el pico, y de vuelta a la base ±3 % a +1,0 s (`f389_06`).
6. **Inicio solo en torre nueva.** Un cliente que entra con p≈0,5 no registra `build_start`, ve anillos y luz, y registra `build_done` una sola vez.
7. **Red y dedicado.**
   - `fx_net_probe`: una construcción manda 0 RPC de FxBus (hoy manda 1).
   - Headless: `EdgeLight` liberada; `EdgeRings`, `BuildCues` y `BuildReveal` sin proceso; la suite `tower_cases` y `build_area_cases` sigue PASS.
8. **(Solo si aceptás el pulso)** ΔL media de todo el cuadro ≤ 0,04 en el pico, duración ≤ 0,3 s, 0 a ≥ 40 m.

## 3. Escena de prueba
- **Inicio, subida y final:** se reusa `res://debug/spells/manalith_build_area.tscn` sin cambios.
  - Estado: el mago está a 30 m de FountEast, libre, con nada armado.
  - El resultado (anillos, luz, canto, columna) todavía no está.
  - Acción: la pestaña Estructuras / `spell_1` sobre el manantial y luego clic (`select`).
- **Corte:** `res://debug/spells/manalith_build_cut.tscn` [+].
  - Hereda la anterior y agrega `StunKey` (`debug/spells/stun_key.gd` [+], solo debug, ≤ 30 líneas, `@export var target: WizardBody`, `@export var stun_s := 1.0`).
  - Con `debug_hit` (K) aturde al mago, y eso corta el lanzamiento (`Caster._interrupt`).
  - No existe un atajo que corte un lanzamiento, por eso hace falta este script (`f375_hit_feel` deja 1 de vida).
- **Flujo:** `agent/flows/f389_build_feedback.json` [+], con capturas fijas `f389_01` a `f389_07`: p = 0 / 0,25 / 0,5 / 0,95, final +0,1 s, final +1,0 s y corte +0,1 s. Hace `print` de `EdgeLight:light_energy`, `EdgeRings:emitting`, `CameraShake:trauma` y el SoundLog. Todo esto va en el `F389` de FEATURES.

## 4. Árbol de archivos
```
game/
├─ scenes/structures/
│  ├─ towers/
│  │  ├─ tower.tscn                       [~] + BaseSpot, BuildCues, BuildEdge/{EdgeRings, EdgeLight}
│  │  ├─ shrine_tower.tscn                [=] hereda (el borde sigue a la línea, sin overrides)
│  │  └─ README.md                        [~] Talks to / Edit
│  └─ reveal/
│     ├─ build_reveal.gd                  [~] + line_y() (≈ +8 líneas → ~126)
│     ├─ build_edge.gd                    [+] BuildEdge (~80)
│     ├─ build_cues.gd                    [+] BuildCues (~90)
│     └─ README.md                        [~] What/Talks to/Edit/Check con las piezas nuevas
├─ scenes/map/props/
│  ├─ manafount_body.gd                   [~] columna/luz/zumbido solo con el ocupante en pie; − summon_point
│  └─ manafount.tscn                      [~] − SummonSpot
├─ scenes/spells/actions/
│  ├─ structure_action.gd                 [~] − rise_fx y su FxBus.broadcast
│  └─ structure_action.tscn               [~] − rise_fx
├─ scenes/fx/
│  ├─ particle_type.gd                    [~] + flat, emission_height_m (~125)
│  ├─ fx_atlas.gd                         [~] quad_for por (size, flat): QuadMesh FACE_Y
│  ├─ sprite_emitter.gd                   [~] emission_ring_height = type.emission_height_m (~149, al límite de C1a)
│  └─ README.md                           [~] − SummonSpot; + BaseSpot
├─ scenes/look/lights/actor_light.gd      [~] + set_level(fraction)
├─ scenes/audio/
│  ├─ sound_cue.gd                        [~] + longest_s()
│  └─ wizard_sounds.gd                    [~] el canto se encadena mientras dura el lanzamiento (~100)
├─ data/fx/
│  ├─ build_edge_ring.tres                [+] ParticleType: brng 4x4, 28x28 m, flat, 180/s, vida 1,125 s, escala 0,875–1,125, scale_fade 1, fade 1
│  ├─ build_start.tres                    [+] burst chico (cstj) + luz + sonido build_start
│  ├─ build_done.tres                     [+] burst (anillo brng plano que se abre + chispas) + luz + sonido + camera_trauma 0,5
│  ├─ build_cut.tres                      [+] explosión chica (xplo) + luz + explosion_burst + camera_trauma 0,35
│  └─ lights/
│     ├─ build_start_glow.tres            [+] FxLightSpec azul 2,5 / 10 m / 0,4 s
│     └─ build_done_flash.tres            [+] FxLightSpec azul 5 / 18 m / attack 0,05 / decay 0,6 / pow 1,5 / h 4 m
├─ data/audio/cues/
│  ├─ build_start.tres                    [+] cnj1–6 (los streams de frozen_ground_cast), −8 dB
│  └─ build_done.tres                     [+] _s_u_m_n (SUMN), −6 dB
├─ debug/spells/
│  ├─ manalith_build_cut.tscn             [+] hereda manalith_build_area + StunKey
│  └─ stun_key.gd                         [+] solo debug
├─ debug/fx/fount_fx_probe.gd             [~] un ocupante que no es CastTower cuenta como en pie
├─ agent/flows/f389_build_feedback.json   [+]
├─ agent/flows/f54c_net_a.json, pt19c_net_c.json  [~] lo que esperan de ManalithFx (prendido recién en pie)
├─ debug/audio/ (caso de canto)           [~] el caso de «1 incantation por lanzamiento» pasa a ≥ N
├─ FEATURES.md                            [~] F389
└─ (opcional S5) scenes/look/post/screen_pulse.{tscn,gd,gdshader} [+], match.tscn [~], particle_type.gd [~] screen_pulse
```

## 5. `tower.tscn` después del cambio
```
Tower (CastTower ← map_building.tscn)
├─ Visuals                (partes desde buildings/_<tag>.tscn)
├─ Collision
├─ Health
├─ Sync                   (Health, build_progress)
├─ HealthBar
├─ HealthRegen
├─ ManaSource
│  └─ Reach/Shape
├─ AttachPoint            (Marker3D 15 m)
├─ GuardPost
├─ BuildReveal            (Node)        tower=.., visuals=../Visuals
├─ BaseSpot               (Marker3D, y 0,3)  [+] donde nacen el inicio y el final (gizmo)
├─ BuildCues              (Node)        [+] tower=.., reveal=../BuildReveal, spot=../BaseSpot,
│                                            start_fx=build_start, done_fx=build_done, cut_fx=build_cut
└─ BuildEdge              (Node3D)      [+] tower=.., reveal=../BuildReveal, rings=EdgeRings, light=EdgeLight,
   │                                         energy_curve (Curve 0,15→1), rings_until_progress 0,955, fade_out_s 1,0
   ├─ EdgeRings           (sprite_emitter.tscn, type=build_edge_ring.tres) [+]
   └─ EdgeLight           (actor_light.tscn: color azul del borde, energy 2,0, range 12, priority 3) [+]
```

## 6. Responsabilidades (un dueño por estado)
| Pieza | Hace | No hace |
|---|---|---|
| `CastTower` | dueño de `build_progress` (replicado) | dibujar o sonar |
| `BuildReveal` | dueño de la línea del corte: materiales, `line_y()` | anillos, luz, momentos |
| `BuildEdge` | pone `EdgeRings` y `EdgeLight` sobre la línea; prende los anillos en [0,01; 0,955); nivel de luz = curva(p); fade de 1 s al quedar en pie | inicio, final o corte; colores de lado |
| `BuildCues` | detecta inicio (primer frame con p ≤ 0,05), final (pasa de <1 a 1 visto subiendo) y corte (`tree_exiting` todavía subiendo y con la partida viva); `FxBus.play` **local** | broadcast; decidir el corte |
| `ManafountBody` | dueño del look de la fuente: libre (chorro y loop), ocupada subiendo (nada) u ocupada en pie (columna, luz, zumbido), derivado e idempotente de (ocupante, `is_rising()`) | sonar los momentos |
| `WizardSounds` | dueño del canto: encadena `incantation` mientras `caster.is_casting()` | cortar el clip que suena |
| `StructureAction` | simulación del lanzamiento (sin FX) | — |
| `ActorLight` | único que escribe `light_energy` (`set_level`, fades) | — |

## 7. Resource de tipo, nodo o `@export` de instancia
- **Resources (tipo):**
  - `ParticleType` `build_edge_ring`, `build_start`, `build_done` y `build_cut` llevan el look, la luz (`FxLightSpec`), el sonido (`SoundCue`) y el `camera_trauma`;
  - las dos `FxLightSpec` y los dos `SoundCue`;
  - la `Curve` de energía va embebida en `tower.tscn`.
- **Nodos:** `BaseSpot` (Marker3D), `BuildCues`, `BuildEdge`, `EdgeRings` (SpriteEmitter existente) y `EdgeLight` (ActorLight existente).
- **`@export` de instancia:** sockets (`tower`, `reveal`, `spot`, `rings`, `light`), `rings_until_progress`, `fade_out_s`, `start_max_progress`, `chant_gap_s` (0,1) y la energía y el rango de `EdgeLight`.
- Ningún número vive en `MatchRules`.

## 8. Cómo lo hace un humano
| Verbo | Dónde, sin código |
|---|---|
| Entender | `reveal/README.md` (5 líneas) y el árbol de `tower.tscn`: cada pieza es un nodo con `editor_description` |
| Modificar | brillo y tamaño de los anillos en `data/fx/build_edge_ring.tres`; luz en `Tower/BuildEdge/EdgeLight` + `energy_curve`; flash y sonido en `build_done.tres`; dónde nace en el gizmo de `BaseSpot` |
| Agregar | otro efecto de final = arrastrar otro `.tres` a `BuildCues.done_fx` (o duplicar `build_done.tres`) |
| Quitar | vaciar el campo (`cut_fx` vacío = nada) o borrar el nodo `BuildEdge`: la torre sigue subiendo |
| Crear | la torre de un dios nuevo hereda `tower.tscn` y trae todo; otro edificio que «sube» copia los tres nodos y asigna sus sockets |
| Escalar | 2 lugares como máximo: el `.tres` del efecto y el nodo en `tower.tscn` |

## 9. Contratos
```gdscript
# BuildReveal
## Global Y of the cut line for the current progress: base - edge_width_m at 0, top at 1 (base Y before the first dress).
func line_y() -> float

# ActorLight
## Sets light_energy to the scene energy times `fraction` (kills a running fade). The only writer besides set_lit.
func set_level(fraction: float) -> void

# ParticleType
@export var flat := false                      ## lies flat facing up (rings around a tower); FxAtlas gives a FACE_Y quad
@export_range(0.0, 20.0, 0.1, "suffix:m") var emission_height_m := 0.0  ## height of the emission band (SpriteEmitter)

# SoundCue
func longest_s() -> float                       ## longest stream length; 0 when silent

# BuildCues (signals for checks and the agent, past tense)
signal start_shown(at: Vector3)
signal done_shown(at: Vector3)
signal cut_shown(at: Vector3)

# ManafountBody
func shows_tower() -> bool                      ## occupied by a standing tower: column, light and hum on
```
- **Red:** todo sale de `build_progress` (ON_CHANGE, confiable), del spawn y del despawn del `MultiplayerSpawner`. `BuildCues` usa `FxBus.play` (local), nunca `broadcast`. Se borra el `FxBus.broadcast(rise_fx, …)` de `structure_action.gd:89-90`.
- **Dedicado:** las piezas se cargan pero quedan inertes, igual que `BuildReveal` y `StateLight`: `ActorLight` se libera, `SpriteEmitter` no dibuja en headless y el export `dedicated_server=true` quita lo visual.

## 10. Sub-cortes (los developers no corren Godot; una sola pasada de pruebas al final)
- **S1 El final se ve** (fiel). `manafount_body.gd` (look derivado del ocupante en pie), menos `SummonSpot` y `summon_point`, menos `rise_fx`, más el probe y los flujos. Independiente.
- **S4 Canto.** `wizard_sounds.gd` + `SoundCue.longest_s()` + el caso de audio. Independiente.
- **S2 Borde que sube.** `ParticleType`, `FxAtlas`, `SpriteEmitter`, `build_edge_ring.tres`, `BuildReveal.line_y`, `ActorLight.set_level`, `BuildEdge` + `EdgeRings` + `EdgeLight` en `tower.tscn`.
- **S3 Momentos** (después de S2: también toca `tower.tscn`). `BaseSpot`, `BuildCues`, los `.tres` de fx, luces y cues, `stun_key.gd`, `manalith_build_cut.tscn` y el flujo `f389`.
- **S5 (opcional) Pulso.** Un pase de `scenes/look/post/` (CanvasLayer −1 + ColorRect + shader de un archivo) que escucha `FxBus.played` y usa la caída de `ShakeMap`, con un campo `ParticleType.screen_pulse` (0–0,2).
- **Cierre:** import, `rules_suite` (tower, build_area, fx_wire, spell_light), casos de audio, el flujo `f389` en local, el `f54c` con red y `bash tools/lint/conventions.sh`. Ningún conteo sube, y los `README` usan `Check:`.
- S1 y S4 van en paralelo con S2→S3.

## 11. Verificación de un humano en el editor
- **F6** en `manalith_build_area.tscn`, lanzar el Manalith:
  - se apaga el chorro;
  - suena el conjuro y salta una chispa en la base;
  - el mago canta sin pausa;
  - el borde azul sube tirando anillos planos que se achican, con una luz azul que lo acompaña y crece;
  - en el último medio segundo no salen anillos;
  - al terminar: flash, burst, sacudida corta, aparece la columna del color del lado, la luz de la columna reemplaza a la del borde y arranca el zumbido.
- **Inspector remoto:** `Tower/BuildEdge/EdgeLight.light_energy`, `EdgeRings.emitting` y `FountEast.shows_tower()`.
- **F6** en `manalith_build_cut.tscn`: en mitad de la subida apretar K → explosión chica en la línea, vuelve el chorro y no hay zumbido.

## 12. Riesgos
- **Overdraw y bloom.** 180 anillos/s de 28 m aditivos (el ritmo del original para una parte). Lo cuidan `energy` bajo en el `.tres` (empezar en 4, no 20), el criterio 5 y una prueba de costo: ≤ 1 ms de frame en medium, si no 90/s.
- **Inicio falso en late join** si el estado de spawn del `Sync` llega después del primer frame. Lo mitigan el umbral `start_max_progress` y el criterio 6.
- **Corte falso al salir de la partida** (`tree_exiting` en cascada). `BuildCues` no toca nada si la escena actual se está borrando. Lo verifica el SoundLog al salir a mitad de una subida.
- **El canto cambia todos los lanzamientos** (hechizos e invocaciones), como el original. Habrá más densidad en el bus Voice; hay que ajustar el caso de audio que espera una sola entrada.
- **Flujos que leen `ManalithFx`** a mitad de la subida ahora ven `false`.
- `sprite_emitter.gd` queda a 149 líneas (C1a).
- En `low` (4 luces) `EdgeLight` puede perder el presupuesto: aceptable.

## 13. Fuera de alcance
- La destrucción de una torre en pie (hoy `queue_free` sin FX).
- Las partículas de suelo (TODO también en el original).
- Altares y otros edificios.
- El pulso, salvo que digas que sí.
- El port web.

## 14. Preguntas, con mi recomendación
1. **Corte:** explosión como el original (explosión chica en la línea + `explosion_burst` + trauma 0,35), una nube suave, o un dissolve hacia afuera. **Recomiendo la explosión.** El dissolve necesita que la malla sobreviva al despawn (nodos copiados): más piezas para algo que el original no hacía.
2. **Canto** en todos los lanzamientos (como el original) o solo en estructuras. **Recomiendo en todos:** un solo dueño en `WizardSounds`, sin `if` por tipo.
3. **Sonido del final:** el zumbido (fiel) más `SUMN` a −6 dB. **Del inicio:** `cnj1-6` (el conjuro que el original usa al empezar Frozen Ground, `state.d:11106`) a −8 dB. **Recomiendo los dos.** Son elección nuestra, no del original para estructuras.
4. **Pulso de post-proceso:** **recomiendo no por ahora.** El flash, la columna, el zumbido y la sacudida ya marcan el final, y el pulso es la pieza con más riesgo de bloom. Si lo querés, va en S5 con ΔL ≤ 0,04.
5. **Ritmo de anillos:** 180/s (el original) o 90/s. **Recomiendo 180** con el corte por costo.
6. **Color de la luz que sube:** el azul del borde (fijo) o el color de maná del lado. **Recomiendo el azul del borde:** acompaña lo que se ve, y la columna toma el color del lado al final.
7. **Trauma del final 0,5.** Se siente hasta unos 25 m y casi nada más lejos. **Recomiendo 0,5.**
8. **ID:** ¿plan 065 / F389?
