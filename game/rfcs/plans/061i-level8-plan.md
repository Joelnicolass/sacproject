# 061i — Nivel 8 sobre un blanco (Charm, Blind Rage, Intestinal Vaporization, Bovine Intervention, Death) — plan del corte

Fuentes: `061-spells-master-plan.md` (§1 pieza 6 `SpellCarrier`, pieza 4 `SpellAffliction`, pieza 3 `SpellTarget`; fila 061i; regla de luces), `rfcs/research/061R-abilities-structures.md`, `rfcs/research/061V-spell-visuals-i.md` (arte, SPEL y luces), sacengine (`state.d` 4086-4305, 11217-11362, 21423-22300; `sacobject.d` 3114-3337; `renderer.d` 1968-1982, 2517-2998) y `CONVENTIONS.md` (C1-C21 y §2c). Decisiones del usuario: arte final desde el inicio; cada hechizo ilumina con su color. Los cortes 061g (muros) y 061h (nubes) corren en otros worktrees: no usan el portador.

Una sola pieza común para los cinco: el `SpellCarrier` de 061d/061e gana **dos movimientos nuevos** (caer, cazar), **una fase de espera sobre el blanco** y **tres señales** (`arrived`, `settled`, `landed`). Lo que cada hechizo hace al blanco es un **hijo reutilizable** (`TargetEffect` con un `BodyEffect` embebido: afligir, gibear, matar, cambiar de bando). Un hechizo nuevo de este tipo es una escena y un `.tres`, no un script.

## Objetivo
- **Charm `mrhc`** (clic en una criatura enemiga que no sea mago y cuyo bando tenga mago): tres espíritus rodean al mago mientras lanza, vuelan a 30 m/s al blanco, lo rodean 5 s y la criatura **cambia de bando para siempre**: pierde órdenes, entra en `retreat` hacia el mago, lanza 128 corazones y muestra un corazón grande 10 s. Los espíritus siguen 4 s más. Si el blanco muere o deja de poder encantarse antes, no pasa nada.
- **Blind Rage `egar`** (clic en una criatura enemiga que no sea mago): un puño vuela a 30 m/s a 4 m sobre el suelo bajo el blanco, forma el puño 82 ticks, explota con un anillo que crece a 30 m en 128 ticks, y **toda criatura que no sea mago a ≤30 m** (de cualquier bando, sin mirar escudos) queda **30 s enfurecida**: no obedece órdenes, no dispara, ataca a la criatura más cercana de cualquier bando y alrededor suyo giran partículas rojas.
- **Intestinal Vaporization `pavi`** (clic en una criatura enemiga que no sea mago): un proyectil de tripas vuela a 30 m/s; al llegar, siete tripas giran alrededor del blanco 5 s, el blanco queda **aturdido** (se renueva cada 3 s) y se **hincha** 1,5 de escala más; al final **se gibea** (sangre, sin cadáver) y **su alma queda** en el suelo.
- **Bovine Intervention `ivob`** (clic en una criatura enemiga que no sea mago): al terminar el lanzamiento nace una vaca bajo tierra, 15 m delante del mago; viaja 12 s en parábola (pico de 200 m) y a los 12 s está sobre el blanco: **lo gibea** (el alma queda); sigue cayendo y al atravesar el suelo revienta: escombros, polvo y una onda que **aturde** hasta 25 m. Durante el lanzamiento el suelo del punto levanta tierra y tiembla.
- **Death `taed`** (clic en el suelo o en una criatura): aparece una Muerte de 12 m (2 s de disolución vertical). Al terminar el lanzamiento camina a 18 m/s hacia la criatura más cercana **de cualquier bando que no sea mago**, la **mata** (muerte normal: cadáver y alma; ignora escudos) con tres rayos, y sigue. Se va al matar `count` = **8** (`amount3`) o a los 40 s.

## Escena de verificación
`res://debug/spells/cast_level8.tscn` (F6), el mismo patrón que `cast_wards`/`cast_zones`:
- Arma: High Noon, `debug/units/rock_hit.gd` como `Targets`: un Trogg enemigo a 25 m (blanco), otros cuatro Troggs enemigos agrupados a 8-20 m del primero (para la furia y la Muerte), un Troll propio a 12 m del Trogg (se pelea con los enfurecidos) y un mago enemigo a 40 m (nunca blanco). Mago de nivel 9 con maná lleno (`debug/rules/cast_level8.tres`).
- `wizard_god` se elige en el inspector: Persephone (Charm), Pyro (Blind Rage), James (Bovine Intervention), Charnel (Intestinal Vaporization y Death).
- Estado inicial: nadie afligido, todos de su bando.
- Acción: la tecla `spell_N` del hechizo (el número se confirma contra el HUD) y clic sobre el Trogg (Death: sobre el suelo).

## Árbol de archivos
```
scenes/spells/
  [~] spell_type.gd                    + count (SPEL amount3: golpes/muertes)
  [~] spell_target.gd                  + refuse_wizards, neutral_allowed
  [~] README.md
  carrier/
    [~] README.md
    [~] spell_carrier.gd               Motion + FALL, HUNT; Phase + HOLDING, LINGERING; señales arrived/settled/landed; el viaje de almas pasa a SoulTrip. ≤150
    [+] soul_trip.gd                   SoulTrip (RefCounted): el viaje de ida y vuelta de Soul Mole/Soul Wind, sacado de SpellCarrier sin cambiar un número. ≤80
    [+] carrier_hold.gd                CarrierHold (RefCounted): espera sobre el blanco (sigue su centro, baja el puño al final) y luego se queda un rato. ≤90
    [+] carrier_fall.gd                CarrierFall (RefCounted): la parábola de 12 s de la vaca y la caída hasta el suelo. ≤90
    [+] carrier_hunt.gd                CarrierHunt (RefCounted): la Muerte: elige la criatura más cercana que no sea mago, gira, camina, golpea, cuenta. ≤150
    [~] guided_flight.gd               sin on_arrive la llegada llama a carrier.arrive_at(blanco)
    [+] target_effect.gd               TargetEffect (Node): al `arrived` o `settled` del portador aplica su BodyEffect al blanco o a los cuerpos de su Reach. ≤90
    [+] hold_body.gd                   HoldBody (Node): mientras el portador espera aturde al blanco y lo hincha (DevourGrowth.inflation). ≤70
    [+] carrier_landing.gd             CarrierLanding (Node): al `landed` suelta la onda (QuakeWave), el polvo y las rocas. ≤60
    [+] swarm_orbit.gd                 SwarmOrbit (Node3D): hijos que giran en puntos al azar de un disco alrededor de lo que el portador rodea (mago al lanzar, blanco al esperar). ≤120
    [+] growing_ring.gd                GrowingRing (MeshInstance3D): anillo que crece de 0 a `radius_m` durante la fase LINGERING del portador. ≤70
    [+] ring.gdshader                  anillo aditivo con el atlas 4x4 (per2)
    [+] morph_model.gd                 MorphModel (Node3D): reproduce los cuadros de un .glb con blend shapes (secuencia + cuadro continuo). ≤120
    [+] sprite_swarm.gdshader          quad con atlas 4x4 y mezcla alfa o aditiva (gut1/gut2/hart)
    [+] charm.tscn                     SpellCarrier(GUIDED, hold del hechizo, linger 10) ├ Spirits(SwarmOrbit ×3 con RiftRibbon) ├ Hearts(SpriteEmitter) ├ OnSettled(TargetEffect, SideChangeEffect) ├ Heart(sprite hart) ├ ActorLight └ sonidos
    [+] blind_rage.tscn                SpellCarrier(GUIDED, hold 82 ticks a 4 m, linger 128 ticks) ├ Fist(MorphModel rage) ├ Swirl(SpriteEmitter swrl) ├ Ring(GrowingRing per2) ├ OnSettled(TargetEffect, AfflictEffect, Reach 30 m) ├ ActorLight └ sonidos
    [+] vaporization.tscn              SpellCarrier(GUIDED, hold del hechizo) ├ Sprite(gut1) ├ Swarm(SwarmOrbit ×7 gut2) ├ Hold(HoldBody) ├ OnSettled(TargetEffect, GibEffect) ├ ActorLight └ sonidos
    [+] bovine_intervention.tscn       SpellCarrier(FALL) ├ Cow(MorphModel bovi ×4) ├ OnArrived(TargetEffect, GibEffect) ├ Landing(CarrierLanding) ├ ActorLight └ sonidos
    [+] death.tscn                     SpellCarrier(HUNT) ├ Reaper(MorphModel deth + reveal.gdshader) ├ Aura(3 esferas, noisy_sphere) ├ OnArrived(TargetEffect, KillEffect) ├ ActorLight └ sonidos
    [+] death_reveal.gdshader          disolución vertical (el sombreador de «construcción» del original)
    [+] death_aura.gdshader            esfera con ruido y atlas dth2, aditiva con energía negativa
  effects/
    [+] README.md
    [+] body_effect.gd                 BodyEffect (Resource): apply(carrier, body) -> bool; la base no hace nada. ≤30
    [+] afflict_effect.gd              AfflictEffect: pone un AfflictionType en el cuerpo (Afflictions.child_for(...).lay). ≤40
    [+] gib_effect.gd                  GibEffect: Gib.burst(cuerpo). ≤30
    [+] kill_effect.gd                 KillEffect: Health.kill + tres rayos. ≤50
    [+] side_change_effect.gd          SideChangeEffect: cambia owner_slot al del mago, borra órdenes, retreat, corazones. ≤70
  actions/
    [~] carrier_action.gd              + spawn_on (START | FINISH), cast_scene (efecto en el suelo mientras lanza). ≤110
    [+] charm_action.tscn, blind_rage_action.tscn, vaporization_action.tscn, bovine_intervention_action.tscn, death_action.tscn   (sin script propio; knobs)
  [~] spell_spawner.gd                 + 5 clases en `projectiles`: Charm, BlindRage, Vaporization, BovineIntervention, Death
scenes/units/
  [+] gib.gd                           Gib (static, RefCounted): FX de sangre, marca `gibbed`, mata sin cadáver, libera el cuerpo. ≤60
  [~] unit_body.gd                     + gibbed (var); closest_foe no corta a un enfurecido (1 línea)
  afflictions/
    [~] afflictions.gd                 + raging() (_any(&"rages"))
    [~] affliction_type.gd             + rages
    [+] looks/rage_swirl.tscn          partículas swrl alrededor de la caja del cuerpo (AfflictionEmitter)
  [~] unit.tscn                        + Afflictions/BlindRaged (SpellAffliction, rage_swirl) ; sync "DevourGrowth:inflation"
  [~] unit_orders.gd                   un enfurecido no recibe ni conserva órdenes
  targeting/
    [+] rage_policy.gd                 RagePolicy (TargetPolicy): la criatura más cercana de cualquier bando, no ella. ≤50
    [~] target_picker.gd               + rage_policy ; active() lo prefiere mientras Afflictions.raging()
  attacks/[~] ranged_attack.gd         prefers() = false mientras Afflictions.raging()
  status/[~] devour_growth.gd          + inflation (replicada): bulk = 2 − 0,75ⁿ + 1,5 × inflation
scenes/components/[~] health.gd        + kill(from_slot): la vida a 0 sin factores
scenes/souls/[~] soul_system.gd        un cuerpo gibbed deja su alma al instante, sin cadáver (attached = false)
scenes/units/abilities/[+] bovine_quake_wave.tscn   QuakeWave con stun_max = 25 (instancia de quake_wave.tscn)
data/afflictions/[+] blind_raged.tres  (bit 11: holds false, rages true, coexists true)
data/catalog/spells/[~] taed.tres (count = 8) ; mrhc, egar, pavi, ivob, taed .tres   action = su escena, ai_use = NONE
data/gods/[~] persephone, pyro, james, charnel .tres    + los hechizos en `spells`
data/targeting/[+] rage.tres           (RagePolicy)
data/fx/[+] charm_hearts.tres (hrot, FxLightSpec), charm_bounce.tres, rage_swirl.tres (swrl), rage_blast.tres (luz), vaporize_burst.tres (luz), cow_burst.tres (luz), death_strike.tres (luz), cow_ground.tres (dirt), cow_rocks.tres, cow_dust.tres
data/audio/[~] fx_sounds.tres          + charm_cast, charm_start, charm_done, rage_fist, rage_boom, vaporize_hit, vaporize_burst, cow_emerge, cow_hit, death_cast, death_strike
assets/original/fx/                    hrot, hart, swrl, per2, gut1, gut2, dth2   (tools/import/import_ui.py, EXTRA_FX)
assets/original/props/                 rage.glb, bovi.glb, deth.glb (+ *_M000.png)   (tools/import/import_morph_models.py, Blender CLI)
tools/import/[+] import_morph_models.py ; [~] blender_dfir.py (nombre del objeto) ; [~] import_ui.py
tools/bake/[~] catalog_builder.gd      + count
scenes/match/[~] match.tscn            SpellSpawner.projectiles ya trae las 5 (no hay círculo: ninguna apunta a su SpellType)
debug/spells/[+] cast_level8.tscn ; debug/rules/[+] cast_level8.tres
debug/suite/[+] level8_cases.gd, level8_cases.tscn, level8_cases_run.gd ; [~] rules_suite.gd
agent/harness/match_shots/[~] match_shots.gd   --cast: los cinco, vista `carrier` sigue al portador, `foe_close` informa los estados
tools/lint/[~] baseline.txt (solo si algún conteo baja)
```

**Fuera del corte**
- La IA no lanza estos cinco (`ai_use = NONE`); un caso confirma que valen 0 y no rompen una partida.
- Añadir al cambio de bando las caras del jugador local (selección y marcas de bando de la criatura: `CreatureFx` tiñe una sola vez; se vuelve a teñir al próximo spawn). **NO VERIFICADO** en ventana.
- La cicatriz `deth`/`scar` de la Muerte y del impacto de la vaca (no hay lector de SCAR).
- La excepción de Manahoar en la furia (no hay una marca en el port; ningún Manahoar es blanco de las pruebas).
- Las luces del exe: ninguna de las cinco tiene una conocida; los colores salen de las texturas (`061V-i`).

## Tipo / nodo / instancia
- **Resource de tipo:** el `SpellType` `.tres` (todos los números: velocidad, duración, alcance, `count`), el `AfflictionType` de la furia y los `BodyEffect` embebidos en cada escena.
- **Nodos:** cada hechizo es un `SpellCarrier` con sus hijos (modelo, enjambre, anillo, efectos, luz, sonidos); los puntos (`Marker3D`: la mano del puño, la altura del lanzamiento) y los radios (`CollisionShape3D` de `Reach`) se mueven con el gizmo.
- **`@export` de instancia:** `hold_s`, `linger_s`, `hold_height_m`, `bulge`, `radius_m`, el número de espíritus/tripas (cuántos hijos tiene el enjambre), la altura del pico de la vaca (`peak_m`), la velocidad de caza.
- **Dónde se edita un hechizo:** su `.tres` (números) y su escena del portador (cómo se ve y cuándo actúa).

## Dueños y red
- **`SpellCarrier` es el único dueño del reloj y de la fase** del hechizo; sus hijos lo escuchan (`arrived`, `settled`, `landed`, `ended`) y nunca lo escriben. `Afflictions` sigue siendo el único dueño de «qué estados tiene el cuerpo» (la furia es un estado más); `DevourGrowth` el único que escribe la escala por hinchazón; `Gib` la única salida de un cuerpo sin cadáver; `Health.kill` la única muerte directa; `owner_slot` lo cambia solo `SideChangeEffect`.
- Red: `Caster.request_cast` → `submit_cast` → en el host `CarrierAction.started/finish` → `SpellSpawner.spawn_projectile` (el portador es un `SpellProjectile` que se replica con `position`, `rotation`, `scale` y `phase`) → solo el host mueve, espera, aplica y cuenta; cada par dibuja el modelo, el enjambre, el anillo y las luces desde la fase y la posición del blanco (que viaja como camino en los datos del spawn). Los estallidos van por `FxBus.broadcast`. La furia replica el bit `shown` de `Afflictions`; la hinchazón, `DevourGrowth.inflation`; el bando, `owner_slot` (ya replicado).
- Orden en el tick: el portador avanza en `_physics_process` (prioridad 0); `TargetEffect` actúa en la señal, el mismo tick.

## Criterios (suite `level8_cases`)
Cada número se lee en ticks de `MatchClock` (la suite corre a cualquier fps fijo). Sin red: los caminos del host corren en solitario.
- **Datos.**
  - `SpellType.count`: `taed.count == 8`; el resto 0.
  - Los cinco tienen `action`, la escena no tiene warnings, están en `book.spells` de su dios y `ai_use = NONE`.
  - Los cinco `SpellTarget` refusan a un mago y a un aliado; Charm también refusa a un neutral (slot 0).
- **Charm.**
  - Llega a un blanco a D m en `ceil(D / 0,5)` ticks ± 2 (30 m/s) tras `finish`.
  - A los 300 ticks ± 1 de llegar, `owner_slot` del blanco es el del mago; antes, no.
  - Pierde sus órdenes y tiene un `RETREAT` hacia el mago; la ventana de espíritus vive 600 ticks más.
  - Un mago, un neutral, uno muerto o uno que muere en los 5 s: ningún cambio de bando.
- **Blind Rage.**
  - El puño llega, espera 82 ticks ± 1 y aplica; el anillo llega a 30 m en 128 ticks ± 1.
  - Cuatro criaturas a ≤30 m (dos de cada bando, una con escudo) quedan `BlindRaged` 1800 ticks ± 1; una a 31 m y un mago no.
  - Enfurecida: ignora una orden de movimiento, su blanco es la criatura más cercana aunque sea de su bando, y no dispara (`prefers` falso).
  - Al terminar, vuelve a obedecer.
- **Intestinal Vaporization.**
  - El blanco queda aturdido de forma continua 300 ticks ± 1 y su escala crece de 1 a 1 + 1,5 (`inflation` de 0 a 1).
  - A los 300 ticks el cuerpo ya no existe, **no queda cadáver** y hay un alma (`Soul`) en su lugar con `number` = sus almas.
  - Un blanco que muere antes: sin gibeo.
- **Bovine Intervention.**
  - La vaca nace al terminar el lanzamiento a 15 m ± 0,1 delante del mago y 4 m bajo el suelo.
  - A los 720 ticks ± 1 el blanco está gibeado (con alma, sin cadáver).
  - Altura en el tick 360: `(inicio + blanco)/2 + 200` ± 1 m.
  - Al atravesar el suelo, un cuerpo a 12 m queda aturdido y uno a 26 m no; nadie pierde vida.
- **Death.**
  - Aparece en el clic (sobre el suelo) o 10 m delante del mago (clic sobre una criatura); 120 ticks de disolución.
  - Camina a 18 m/s ± 1 hacia la criatura más cercana que no es mago, **propias incluidas**; la mata a ≤6 m + escala (con cadáver y alma); nunca a un mago.
  - Con 10 blancos mata exactamente 8 y desaparece; con 1 blanco desaparece a los 40 s ± 1 de terminar el lanzamiento.
  - Interrumpir el lanzamiento la quita.
- **Luces.**
  - Los cinco portadores tienen un `ActorLight` hijo sin sombra del color de la tabla de `061V-i` ± 0,02.
  - `charm_hearts`, `rage_blast`, `vaporize_burst`, `cow_burst` y `death_strike` tienen `FxLightSpec` del color de la tabla.
- **Base:** gib sin alma (`UnitBody._gib_fallen`) y los casos de almas/ControlCases siguen verdes; `soul_cases` pasa con `SpellCarrier` refactorizado.
- **Lint:** ningún conteo sube; los scripts nuevos ≤150 líneas.
- **Antes/después visual:** no se verifica sin ventana. El comando de captura queda en `carrier/README.md`.

## Orden
1. Importar texturas y mallas (`import_ui`, `import_morph_models`), luces medidas, sonidos.
2. Datos: `count`, `SpellTarget`, `Health.kill`, `Gib`, `SoulSystem`, `BodyEffect`/`TargetEffect`.
3. `SpellCarrier` refactor (suite de almas/dragón verde) y los movimientos FALL/HUNT, la espera y las señales.
4. Intestinal Vaporization (espera + hinchazón + gibeo) → su suite → su arte.
5. Charm (cambio de bando) → suite → arte.
6. Blind Rage (estado + targeting + anillo) → suite → arte.
7. Bovine Intervention (caída + onda) → suite → arte.
8. Death (caza + matar) → suite → arte.
9. `cast_level8.tscn`, `match_shots`, READMEs, lint, suite completa, merge con main.

## Riesgos
- **Sin ventana no se ve nada:** las mallas, el sombreador de disolución y los anillos se validan con la carga headless y con los números; la captura con ventana la hace el usuario.
- `spell_carrier.gd` está en 150 líneas: se saca el viaje de almas a `SoulTrip` antes de agregar nada (la suite de 061d lo cuida).
- `SpellSpawner`, `wizard_body.tscn`/`unit.tscn` y `data/gods/*.tres` los tocan también 061g y 061h: el conflicto de merge es una línea de `projectiles` y una de `spells`.
- **NO VERIFICADO:** los sonidos de Charm (sacengine los comenta); `peri`/`iva2`; las banderas de dibujo del exe de `gut1/gut2`; ~~la duración de Intestinal Vaporization (dato 5 s, sacengine 8,5 s)~~ **VERIFICADO (2026-10-25):** sacengine usa `spell.duration` (`progress = frame / (spell.duration * updateFPS)`, state.d:21475) y `pavi.tres` trae `duration_s = 5.0`: los 5 s son el hinchado; el 8,5 s era la suma con el vuelo; cómo se ve una criatura encantada con la marca de bando.
- 5 mallas con 12, 27 y 65 cuadros: el `.glb` con 64 blend shapes de la vaca pesa ≈350 KB.
