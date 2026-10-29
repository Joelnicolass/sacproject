# RFC-020 — Sacrificios fieles: doctores, Convert, Desecrate y cierre de partida (plan del tech lead)

Estado: plan, sin código. Reemplaza a RFC-017a y 017b. Base: `.studio/RESEARCH-doctors.md`.
Todo lo que sigue sale de lectura estática de `sacengine/source/state.d`, `cache/data/*.json` y el código del port. No corrí Godot ni escenas: los tiempos y el daño son cálculo, no medición.

## 0. Hallazgos que cambian el plan

1. **Hoy no se puede lanzar ni Convert ni Desecrate desde el libro.** `books.json` los trae en `structures` (`htlm, ndrg, ccas, ucas, elet`), no en `spells`. `caster.structure_status()` responde «No implementado» porque `_structure_model()` devuelve vacío para un hechizo sin edificio (`caster.gd:110-122`, `571-581`), y `_try_cast()` los busca con `spellbook.index_of()`, que solo mira la pestaña de hechizos (`caster.gd:206-208`, `spellbook.gd:49`). Además el altar no guarda `owner_slot` (ya anotado en F48). F38 y F39 dicen «Hecho» y no lo están.
2. **El blanco de Desecrate es la criatura propia, no el altar.** Flags del hechizo en `spells.json`: 1835012 = `targetCreatures | onlyCreatures | onlyOwned | disallowHero` (`spells.d:168-183`). `castDesecrate` recibe `target.id` = la criatura y toma el altar de `wizard.closestEnemyAltar` (`state.d:9908-9912`), que es el altar enemigo más cercano a 75 m o menos en planta (`state.d:28083`). El jugador hace clic en su criatura.
3. **El doctor nace cuando termina el casteo.** El vórtice aparece al empezar (`castConvert` / `castDesecrate`, `state.d:10181-10213`) y el doctor sale al terminar el drenaje de maná (`updateSacDocCasting`, `state.d:15535`). Si el casteo se interrumpe, no hay doctor y el alma queda libre.
4. **El drenaje no es un golpe por ronda.** Se reparte en 250 cuadros (4,17 s) dentro de la ventana de disparo (`state.d:15975`, `15997-16011`): `48·(1+almas)` de vida por segundo y `9,6·(1+almas)` de maná por segundo. El total por ronda es el de la investigación.
5. **La derrota llega 11 s después de la muerte del mago.** El altar empieza a destruirse cuando el cuerpo del mago queda muerto (`state.d:15901-15903`); `defeat(side)` se llama al terminar la destrucción: 4 s + 4 s + 3 s (`state.d:5289-5291`, `26062`). El mago se desvanece en 4 s (`state.d:14010`) y al terminar, `lose(side)` mata a todas sus criaturas (`state.d:13404-13407`, `25998`).
6. **Un hechizo directo mata a un doctor de un golpe.** Rock 650, Fireball 625, Wrath 550, Swarm 550, Lightning 750 contra 400 de vida y resistencia 1,0. Ese es el contrajuego real. Con criaturas hace falta daño sostenido mayor a 83,3/s (ver sección 9).
7. **sacengine no excluye al doctor de la IA.** Es blanco válido en `idle`, `moving`, `pumping` y `torturing` (`state.d:138-141`): una criatura ociosa lo ataca sola. El original: sin verificar.
8. **Al completar Desecrate, el lanzador recupera las almas de la criatura** (`obj.gib(state,caster)`, `state.d:16039`; `gib` con `giveSoulsTo`, `8341-8350`). Sin verificar en el original.
9. **`sacd` está horneado, sin clips.** `cache/baked/bodies/sacd.res` existe (`radius 0,398`, `height 2,549`, `reach 1,536`, `upright_checked: false`); `anim_mesh_clips_f37.json` no trae `sacd`. El doctor se ve en pose fija.

## 1. Sub-cortes

| Sub-corte | Qué cierra | Depende de | Feature |
|---|---|---|---|
| **020a** Altar con estado y partida que cierra | `Altar`, `RitualSite`, `MatchState`, `DefeatRule`, cartel de resultado, regla del fantasma | nada | F57 |
| **020b** El Sac Doctor como actor | `fsm_kit`, `doctor.tscn`, `Attackable`, `class_name Health` | nada (paralelo con 020a) | F58 |
| **020c** Desecrate: casteo, vórtice, portador | `SacrificeSystem`, `carrier_doctor.tscn`, `Captive`, input sobre la criatura | 020a, 020b | F59 |
| **020d** Ritual: rondas, drenaje, cancelación, victoria | `ritual.tscn`, empuje, ocupación del altar, avisos | 020c | F60 |
| **020e** Convert fiel | pump, revivir, ritual de Convert, acreditación, borrado del Convert viejo | 020d | F61 |

F49–F56 están reservados (018c–e, 019a–e). Entre 020c y 020d, Desecrate lleva a la criatura hasta el altar y el portador espera: es un estado intermedio declarado, no un bug.

### Criterios de aceptación

**020a (F57)**
- `props/altar.tscn` tiene script; cada altar de `high_noon.tscn` queda con el `owner_slot` de su `PlayerStart`.
- Un mago que muere sin altar en pie pasa a `GONE` y su bando queda derrotado; el otro cliente ve «Victoria» y él «Derrota». El dedicado no muestra nada.
- Cuando `MatchState` pone un altar en `COLLAPSING`, a los 11 s queda `DESTROYED` en los tres procesos: sin malla, sin colisión, sin maná, fuera del grupo `altar`.
- Un cliente que entra después ve el altar en su estado y, si la partida terminó, su resultado.
- Al quedar derrotado un bando, sus criaturas mueren.
- En solo funciona igual, sin servidor.

**020b (F58)**
- `doctor.tscn` tiene 400 de vida, camina a 10 m/s con `move_and_slide`, regenera 83,33/s también recién golpeado, y su vida se ve en los dos clientes.
- Un Rock sobre el doctor lo mata; 4 Druids con orden de ataque lo matan; no deja cadáver ni alma.
- No se selecciona ni recibe órdenes. No ataca.
- Soltado desde 12,75 m cae, rebota y no recibe daño hasta terminar el rebote.

**020c (F59)**
- Desecrate se arma desde la pestaña Estructuras solo con un altar enemigo a 75 m o menos; si no, «Lejos del altar enemigo».
- El clic va sobre una criatura propia y viva a 20 m o menos. Otra cosa: «Blanco inválido».
- Al terminar el casteo cae un doctor a 10 m de la criatura, la levanta y la lleva flotando hasta 20 m del altar enemigo.
- Matar al portador suelta a la criatura: viva, del mismo dueño, seleccionable otra vez.
- No hay RPC nuevo: viaja por `submit_cast`.

**020d (F60)**
- Al llegar, el portador muere y aparecen 4 doctores a 20 m del altar, en 45° + 90°·k. 5 s de preparación; rondas de 13,5 s.
- En cada ronda el mago enemigo pierde `200·(1+almas)` de vida y `40·(1+almas)` de maná.
- Si el mago muere bajo ritual no pasa a fantasma: desaparece, su altar se destruye y a los 11 s su bando queda derrotado.
- Si muere cualquiera de los 4 doctores, el ritual se cancela: el altar sigue en pie y la criatura cae viva y libre.
- Un mago en fantasma al empezar el ritual vuelve al cuerpo con al menos 1 de vida.
- Lo que esté a menos de 20 m del altar es empujado hacia afuera. Con el altar ocupado, un segundo portador espera.
- Un cliente que entra a mitad del ritual ve los 4 doctores, la criatura en el aire y el aviso.

**020e (F61)**
- Convert se arma con un altar propio en pie y se apunta a un alma roja a 20 m o menos.
- El doctor camina al cadáver, bombea `(almas+1)·5` s con la criatura revivida a `max(400, 50 %)`, la levanta y la lleva al altar propio más cercano al mago al castear.
- Ritual de Convert: `int(vidaMáx/550) + 1` rondas. Al final la criatura se desintegra y sus almas se suman al contador del mago.
- Los cuatro casos de muerte del doctor dan lo que dice la investigación (tabla en sección 6).
- No quedan `sac_doctor.*`, `desecration_*` ni la lógica vieja de Convert.

## 2. Escenas de prueba

Todas instancian `scenes/world/high_noon.tscn` y cambian `rules` por un `.tres`, como `debug/wizard_ghost.tscn`. Los extras son instancias de `units/unit.tscn` con overrides en el `.tscn`. Online: `--world=res://debug/<x>.tscn` en el dedicado y en los dos clientes, con `--mp-port` distinto de 7777. El cliente A entra primero (slot 1).

| Escena | Instancia y estado inicial | Todavía NO cumplido | Acción InputMap |
|---|---|---|---|
| `debug/match_defeat.tscn` (020a) | `rules/match_defeat.tres` (`start_health = 50`). `[editable path]` sobre `Start2` con `Altar.state = DESTROYED`. `Executioner` (Druid slot 1, `target_groups = ["wizard"]`) a más de 100 m del mago 2, sobre su línea de frente | Mago 2 vivo, `Match.winner_slot == 0`, `%MatchResult` oculto | B: `move_forward` hasta entrar en la vista del Druid. A: mira |
| `debug/doctor_bench.tscn` (020b) | `rules/doctor_bench.tres`. Tres `doctor.tscn` de slot 2 frente al mago 1: `DoctorRock` a 30 m; `DoctorMelee` a 30 m con `Guard1..4` (Druid slot 1, `idle_aggro = false`); `DoctorDrop` a 12,75 m de altura con `drop_on_ready` | Los tres vivos con 400; `DoctorDrop` en el aire | A: `spell_3` (Rock) + clic sobre `DoctorRock`. A: arrastre de selección sobre los Druids y clic derecho sobre `DoctorMelee` |
| `debug/desecrate_carry.tscn` (020c) | `rules/desecrate.tres` (`start_health = 150`). `Start2` movido a 70 m o menos del punto de aparición del mago 1, en llano. `Offering` (Druid slot 1, `idle_aggro = false`, `target_groups = []`) 12 m delante del mago 1 | Sin doctor, `Offering` en el suelo y en el grupo `unit` | A: clic `%StructureTab`, `spell_4`, clic en `%View` sobre `Offering` |
| `debug/desecrate_ritual.tscn` (020d) | Igual que la anterior | Sin ritual, altar 2 en pie, mago 2 con 150, sin resultado | A: igual. B: mira hasta «Derrota» |
| `debug/ritual_cancel.tscn` (020d) | Igual, con `rules/ritual_cancel.tres` (vida llena). `Guard1..4` (Druid slot 2, `target_groups = ["doctor"]`) a 100 m del altar 2, del lado opuesto al mago 1 | Sin ritual, 0 doctores, altar 2 en pie | A: igual. B: mira |
| `debug/convert_ritual.tscn` (020e) | `rules/convert.tres` (`starting_souls = 0`). `Victim` (Druid slot 2, grupo `victim`, sin agresión) 15 m delante del mago 1. `Killer1..2` (Druid slot 1, `target_groups = ["victim"]`) | Sin alma, sin doctor, «Almas 0» | A: espera el alma roja; clic `%StructureTab`, `spell_3`, clic sobre el alma |
| `debug/convert_pump_kill.tscn` (020e) | Igual + `Guard1..4` (Druid slot 2, `target_groups = ["doctor"]`) a 40 m del `Victim` | Igual | A: igual |
| `debug/convert_carry_kill.tscn` (020e) | `WizardSpawner.toward_fount = 120`. `Victim` a 140 m del altar 1. `Guard1..6` en línea sobre el camino, a 30 m del altar 1 | Igual | A: igual |

Por qué esas distancias: el Druid ve a 100 m (`creatures.json`, `nmuh`). En `ritual_cancel` los guardias ven a los doctores del anillo (a unos 87 m) y no al portador (se detiene a 120 m de ellos). En `convert_pump_kill` el doctor no es blanco mientras cae; los guardias tardan unos 3,6 s en llegar y el pump dura 10 s. En `convert_carry_kill` los guardias están a 110 m del cadáver durante el pump y ven al doctor apenas arranca.

Tiempos estimados desde el clic: `desecrate_ritual` unos 40–45 s hasta el cartel (casteo 5,6 + caída y rebote 2,5 + acarreo 6 + preparación 5 + 6,4 hasta la muerte + animación de muerte 1,7–5,1 + destrucción 11). `convert_ritual` unos 46 s (Druid de 800: 2 rondas).

### Flows para el playtester (`agent/flows/`, patrón `f20_client_a/b.json`)

- 020a: `rfc020a_defeat_a`, `rfc020a_defeat_b`, `rfc020a_late_b` (B entra con la partida terminada y ve «Derrota» y el altar destruido), `rfc020a_solo`.
- 020b: `rfc020b_rock_a`, `rfc020b_melee_a`, `rfc020b_watch_b` (B ve bajar `Health.current` y desaparecer los doctores).
- 020c: `rfc020c_carry_a`, `rfc020c_carry_b`.
- 020d: `rfc020d_win_a`, `rfc020d_lose_b` (profanación completa hasta «Victoria» / «Derrota»); `rfc020d_cancel_a`, `rfc020d_cancel_b` (ritual cancelado: altar en pie, `Offering` viva en `%Units`); `rfc020d_late_b` (B entra durante la preparación y ve 4 doctores, `%RitualNotice` visible y a `Offering` en el aire).
- 020e: `rfc020e_convert_a` («Almas 0» → «Almas 1»), `rfc020e_convert_b`; `rfc020e_pump_kill_a` (alma roja de nuevo, «Almas 0»); `rfc020e_carry_kill_a` (`Victim` vivo, `owner_slot` 2, en el grupo `unit`, «Almas 0»).
- Regresión: `f20_client_a/b`, `f24_online_client`, `f30_pt_online_client`, `f31_online_client`, `late_join_ghost_a/b`.

### Casos nuevos de `debug/rules_suite` (sin red)

| Caso | Sub-corte | Qué comprueba |
|---|---|---|
| `altar_collapse` | a | `begin_altar_collapse(2, 1)` → a los `altar_collapse_s` el altar está `DESTROYED`, fuera de `altar`, y el slot 2 derrotado |
| `match_snapshot` | a | `to_snapshot()` aplicado a otra instancia de `MatchState` con sus altares deja los mismos estados y el mismo ganador |
| `doctor_stats` | b | 400 de vida, velocidad 10, fuera del grupo `unit`, `Attackable.is_body` verdadero |
| `doctor_regen` | b | Tras 100 de daño vuelve a 400 en menos de 1,5 s simulados |
| `doctor_one_shot` | b | `damage_typed(650, DIRECT_SPELL)` lo mata; a los `doctor_death_s` no queda nodo, cadáver ni alma |
| `doctor_melee` | b | 4 Druids con `engage()` lo matan en un tiempo acotado; imprime los segundos (mide el cálculo de la sección 9) |
| `drop_positions` | c | `SacrificeMath.drop_positions()`: vórtice a 20 m, aterrizaje en el punto medio; con el aterrizaje fuera del suelo prueba ±45°, ±90°, ±135°, 180° |
| `captive` | c | Una unidad tomada sale de `unit` y no es blanco; soltada vuelve, viva y con su dueño |
| `desecrate_check` | c | Altar a más de 75 m, criatura ajena, criatura muerta y doctor como ofrenda: rechazados con su texto |
| `ritual_ring` | d | 4 puntos a 20 m en 45° + 90°·k; a progreso 1, a 17 m y un cuarto de vuelta después |
| `ritual_numbers` | d | Drenaje por ronda con 1 y 4 almas; rondas de Convert para 540, 800 y 4500 de vida (1, 2, 9); pump `(n+1)·5` |
| `ghost_under_ritual` | d | Mago con `desecrations = 1` y vida 0 termina en `GONE`, no en `RISING`; fantasma con `desecrations = 1` pasa a `UNGHOSTING` con vida ≥ 1 |
| `convert_revive` | e | Cadáver revivido queda con `max(400, 50 %)` y no es blanco; muerto otra vez deja alma de su dueño |

## 3. Árbol de archivos

```text
game/
├── addons/fsm_kit/                        NUEVO 020b  copia de godot-studio-skills/rc-v0.9.0-spanish/addons/fsm_kit
├── project.godot                          MOD   020b  plugin FsmKit
├── data/match_rules.tres                  MOD   a–e   grupo «Sacrificios»
├── scenes/data/match_rules.gd             MOD   a–e
├── scenes/world/
│   ├── match/
│   │   ├── match.tscn                     NUEVO a     Match (MatchState) + DefeatRule
│   │   ├── match_state.gd                 NUEVO a     class_name MatchState
│   │   └── defeat_rule.gd                 NUEVO a     class_name DefeatRule
│   ├── props/
│   │   ├── altar.gd                       NUEVO a     class_name Altar
│   │   ├── altar_collapse.gd              NUEVO a     class_name AltarCollapse
│   │   ├── ritual_site.gd                 NUEVO a     class_name RitualSite
│   │   ├── altar.tscn                     MOD   a     script, Visuals, Collapse, Site
│   │   └── player_start.gd                MOD   a     owner_slot tipado
│   ├── attackable.gd                      NUEVO b     class_name Attackable (static)
│   ├── components/health.gd               MOD   b     + class_name Health
│   ├── sacrifice/
│   │   ├── doctor.tscn                    NUEVO b
│   │   ├── doctor_body.gd                 NUEVO b     class_name DoctorBody
│   │   ├── doctor_states/dropping.gd      NUEVO b
│   │   ├── doctor_states/grounded.gd      NUEVO b
│   │   ├── doctor_states/working.gd       NUEVO b
│   │   ├── doctor_states/dying.gd         NUEVO b
│   │   ├── stuck_guard.gd                 NUEVO b     class_name StuckGuard
│   │   ├── sacrifice_math.gd              NUEVO c     class_name SacrificeMath (static); crece en d
│   │   ├── sacrifice_system.tscn / .gd    NUEVO c     class_name SacrificeSystem
│   │   ├── carrier_doctor.tscn            NUEVO c     doctor.tscn + Errand
│   │   ├── carry_errand.gd                NUEVO c     class_name CarryErrand
│   │   ├── errand_step.gd                 NUEVO c     class_name ErrandStep extends FsmState
│   │   ├── errand_states/approach.gd      NUEVO c     (rama Convert en e)
│   │   ├── errand_states/haul.gd          NUEVO c
│   │   ├── errand_states/pump.gd          NUEVO e
│   │   ├── ritual.tscn / ritual.gd        NUEVO d     class_name Ritual
│   │   ├── ritual_states/setup.gd         NUEVO d
│   │   ├── ritual_states/walk.gd          NUEVO d
│   │   ├── ritual_states/shoot.gd         NUEVO d     (fin de Convert en e)
│   │   ├── ritual_states/wait.gd          NUEVO d
│   │   ├── ritual_push.gd                 NUEVO d     class_name RitualPush
│   │   └── ritual_fx.gd                   NUEVO d     class_name RitualFx
│   ├── units/captive.gd                   NUEVO c     class_name Captive (revive en e)
│   ├── units/unit.tscn                    MOD   c     + Captive
│   ├── units/corpse.gd                    MOD   e     stand_up()
│   ├── unit_body.gd                       MOD   b (target_groups) · c (Mode.HELD) · e (Mode.REVIVING)
│   ├── body_separation.gd                 MOD   b     + &"doctor" en GROUPS
│   ├── match_command.gd                   MOD   b (Attackable) · c (clic de Desecrate, − _altar_under)
│   ├── units/ranged_shot.gd               MOD   b     Attackable.is_body
│   ├── spells/rock_projectile.gd          MOD   b     Attackable.is_body
│   ├── spells/caster.gd                   MOD   c (ucas) · e (ccas)
│   ├── wizard/ghost_form.gd               MOD   a     desecrations, under_ritual, _has_altar por Altar
│   ├── wizard/wizard_body.tscn            MOD   a     GhostForm:under_ritual en el sincronizador
│   ├── souls/soul.gd                      MOD   e     State.REVIVING, reserva por slot
│   ├── souls/soul_system.gd / .tscn       MOD   e     − Convert viejo, − Doctors, − DoctorSpawner
│   ├── souls/sac_doctor.gd / .tscn        BORRAR e
│   ├── desecration/ (4 archivos)          BORRAR c
│   ├── high_noon.tscn                     MOD   a (+ %Match, + %MatchResult) · c (− %DesecrationSystem, + %SacrificeSystem) · d (+ %RitualNotice)
│   └── high_noon.gd                       MOD   a     − match_over; conecta result_changed
├── scenes/ui/
│   ├── match_result.tscn / .gd            NUEVO a     class_name MatchResultBanner
│   └── ritual_notice.tscn / .gd           NUEVO d     class_name RitualNotice
└── debug/
    ├── match_defeat.tscn                  NUEVO a
    ├── doctor_bench.tscn                  NUEVO b
    ├── desecrate_carry.tscn               NUEVO c
    ├── desecrate_ritual.tscn              NUEVO d
    ├── ritual_cancel.tscn                 NUEVO d
    ├── convert_ritual.tscn                NUEVO e
    ├── convert_pump_kill.tscn             NUEVO e
    ├── convert_carry_kill.tscn            NUEVO e
    ├── rules/{match_defeat, doctor_bench, desecrate, ritual_cancel, convert}.tres   NUEVO
    └── rules_suite.gd                     MOD   a–e   casos de la sección 2
```

Árbol de las escenas nuevas:

```text
doctor.tscn
Doctor (CharacterBody3D, DoctorBody; capa 2, máscara 1)
├── Pivot (Node3D) └── Mesh (BodyVisual, model = sacd)
├── Collision (cápsula ajustada con BodyLibrary.info en _ready)
├── Health
├── HealthBar (unit_health_bar.tscn)
├── StuckGuard
├── States (FsmMachine, actor = Doctor)
│   ├── Off · Dropping · Grounded · Working · Dying
├── Net (MpReplicate)
└── MultiplayerSynchronizer

carrier_doctor.tscn = doctor.tscn +
└── Errand (CarryErrand)
    └── Steps (FsmMachine, actor = Errand)
        ├── Wait · Approach · Pump · Haul · Over

ritual.tscn
Ritual (Node3D, en el centro del sitio)
├── Phases (FsmMachine, actor = Ritual)
│   ├── Off · Setup · Walk · Shoot · Wait · Ended
├── Push (RitualPush)
├── Fx (RitualFx)
└── MultiplayerSynchronizer

sacrifice_system.tscn
SacrificeSystem
├── Doctors (%) + DoctorSpawner (MpSpawner: doctor.tscn, carrier_doctor.tscn)
└── Rituals (%) + RitualSpawner (MpSpawner: ritual.tscn)

altar.tscn
Altar (StaticBody3D, Altar)
├── Visuals (Node3D): Base, Pillar1..4, Top
├── BaseCollision, Pillar1..4Collision
├── ManaSource
├── Site (RitualSite)
└── Collapse (AltarCollapse)
```

`Off`, `Wait`, `Over` y `Ended` son `FsmState` sin script.

## 4. Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `Altar` | Estado `STANDING / COLLAPSING / DESTROYED` y su efecto local: mallas, colisión, `ManaSource`, grupo `altar` | Nodo en `altar.tscn` | `PlayerStart` coloca; no decide el estado |
| `AltarCollapse` | La secuencia visible de 11 s (hundir 4, flotar 4, estallar 3), en cada peer | Hijo de `Altar` | Sin él el altar igual pasa a destruido; el reloj lo lleva el servidor |
| `RitualSite` | «Acá se hace un ritual»: dueño, centro, libre u ocupado | Hijo de `Altar` | Es el punto de extensión de Shrine: otro edificio lo suma como hijo |
| `MatchState` | Fuente única del estado de partida: altares por slot, bandos derrotados, ganador; snapshot y reenvío | Nodo `%Match` | Si viviera en el ritual, la victoria quedaría atada a un hechizo |
| `DefeatRule` | Servidor: fin del derrumbe → derrota; mago en `GONE` → pierde altares y criaturas; un solo bando en pie → ganador | Hijo de `Match` | Otra condición de victoria = otro hijo; se apaga sacándolo |
| `MatchResultBanner` | «Victoria» / «Derrota» / «Fin de partida» según `MpKit.local_slot()`; oculto con slot 0 | Packed UI bajo `Hud` | `%Battle` lo pisa el próximo mensaje |
| `GhostForm` (mod) | Suma: contador `desecrations` (servidor) y `under_ritual` (replicado); bajo ritual o sin altar en pie, no hay fantasma | Nodo existente | Ya es dueño de las etapas del mago |
| `Attackable` | `GROUPS` e `is_body(node)`: qué es blanco de golpes, disparos y hechizos directos | `static` | Reemplaza tres copias del mismo `is_in_group(...) or ...`; «doctor» sería la cuarta |
| `DoctorBody` | Cuerpo del doctor: vida, regeneración, verbos (`drop_to`, `walk_to`, `stop`, `begin_work`, `kill`), `pose` replicada | Packed `doctor.tscn` | Lo usan el portador y el ritual. No es `unit.tscn`: sin órdenes, sin ataque, sin cadáver |
| Estados de `States` | Un modo físico cada uno: caer, andar, trabajar quieto, morir | `FsmState` | Un modo nuevo = un nodo |
| `StuckGuard` | Mide el avance hacia la meta; pide esquivar y, pasado el plazo, mata al doctor | Hijo de `doctor.tscn` | Es la parte no fiel: se saca el hijo y queda el comportamiento original |
| `SacrificeSystem` | Puerta de entrada en el servidor: valida, reserva, abre el vórtice, spawnea portador y ritual | Nodo en `high_noon.tscn` | Reemplaza a `DesecrationSystem` y al Convert de `SoulSystem`; un solo spawner de doctores |
| `SacrificeMath` | Cuentas puras: posiciones del vórtice, anillo, rondas, drenaje, pump | `static` | Se prueban en `rules_suite` sin mundo |
| `CarryErrand` | El recado de un portador: qué hechizo, de quién, qué alma o criatura, a qué sitio; avisa cómo terminó | Hijo de `carrier_doctor.tscn` | Recado ≠ cuerpo: el doctor del ritual no tiene recado |
| Estados de `Steps` | Un paso del recado; cada uno sabe qué pasa si el doctor muere en él | `ErrandStep` | Los cuatro casos de «matan al doctor» son cuatro `doctor_died()` |
| `Captive` | La criatura tomada: revivir, quedar suspendida, seguir al portador, caer libre | Hijo de `unit.tscn` | `unit_body.gd` tiene 771 líneas; ahí solo entran dos modos y tres guardas |
| `Ritual` | Un ritual en curso: sitio, lanzador, criatura, 4 doctores, mago blanco; `phase` y `round` replicados; `abort()` y `complete()` | Packed `ritual.tscn`, spawneado | Convert y Desecrate son el mismo nodo con `kind` |
| Estados de `Phases` | Preparación, caminar, disparar (drena), esperar | `FsmState` | Tiempos y efectos distintos por fase |
| `RitualPush` | Empuja hacia afuera lo que esté a menos de 20 m del sitio | Hijo de `Ritual` | Se apaga sacándolo |
| `RitualFx` | Lo que se ve del ritual según `phase`, en cada peer | Hijo de `Ritual` | Presentación; el dedicado no la corre |
| `RitualNotice` | Avisos del jugador local: «Están profanando tu altar», «Ritual interrumpido», «Altar profanado» | Packed UI bajo `Hud` | Sale de datos replicados; no necesita RPC |
| `Caster` (mod) | Sigue llevando casteo, maná y enfriamiento; delega validar, abrir y cerrar en `SacrificeSystem` | Nodo existente | 666 líneas: no suma reglas de ritual |

## 5. Máquinas de estados

**Cuerpo del doctor (`States`).** El servidor transiciona; el cliente queda en `Off` y pinta `pose`.

| Estado | Qué hace | Sale a | Quién dispara |
|---|---|---|---|
| `Off` | Nada | `Dropping` o `Grounded` | `SacrificeSystem` al spawnear (`drop_to(landing)` o `stand()`) |
| `Dropping` | Invulnerable. Balística con la gravedad del motor hacia `landing`; al tocar el suelo cuenta `doctor_bounce_s` | `Grounded` | Su propio reloj; emite `landed` |
| `Grounded` | Camina a `goal` si lo hay: `BodySeparation` + `GroundGuard` + `move_and_slide`. Regenera | `Working`, `Dying` | `begin_work(kind)` del recado o del ritual |
| `Working` | Quieto, regenera. `pose` = pump, levantar o torturar | `Grounded`, `Dying` | `end_work()` |
| `Dying` | Sin colisión, fuera del grupo `doctor`, emite `died`; a los `doctor_death_s` se libera | — | `Health.died` desde cualquier estado, o `kill()` |

**Recado del portador (`Steps`).**

| Paso | Qué hace | Sale a | Si el doctor muere acá |
|---|---|---|---|
| `Wait` | Espera `body.landed` | `Approach` | Libera la reserva del alma |
| `Approach` | Meta = alma o criatura. Si el blanco deja de valer o el sitio cae: mata al doctor. Convert: a menos de 2 m → `Pump`. Desecrate: a menos de 10 m → toma a la criatura → `Haul` | `Pump` / `Haul` | Convert: el alma sigue roja y convertible. Desecrate: nada |
| `Pump` (Convert) | Revive a la criatura; cuenta `(almas+1)·5` s. Sitio caído: mata al doctor. Al terminar quita el alma, levanta a la criatura | `Haul` | La criatura muere otra vez y deja su alma, de su bando |
| `Haul` | Meta = centro del sitio; la criatura lo sigue flotando. A 20 m o menos y en el suelo pide el ritual. Sitio ocupado: se detiene y espera. Sitio caído: mata al doctor | `Over` (el ritual arrancó; el portador muere) | La criatura cae viva, de su dueño original |
| `Over` | Nada | — | — |

**Ritual (`Phases`).** `round` empieza en 0.

| Fase | Duración | Qué hace | Sale a |
|---|---|---|---|
| `Off` | — | Cliente | — |
| `Setup` | 5 s | La criatura sube hasta 15 m sobre el sitio. Los 4 doctores aparecen en el anillo | `Walk` |
| `Walk` | 4,5 s | Cada doctor camina un cuarto de vuelta; el radio baja de 20 a 17 en el último quinto | `Shoot` |
| `Shoot` | 4,5 s | Los doctores miran al sitio y torturan. Entre 0,33 s y 4,5 s drena al mago (Desecrate). Al salir: ¿terminó? Convert: `round == int(vidaMáx/550)`. Desecrate: el mago blanco está muerto o no existe | `Wait` o `Ended` (`complete()`) |
| `Wait` | 4,5 s | Los doctores sueltan | `Walk` con `round + 1` |
| `Ended` | — | Nada | — |

En cualquier fase, `Ritual` revisa cada cuadro en el servidor: muere un doctor → `abort()`; el sitio deja de estar en pie → `abort()` (salvo Desecrate con el mago ya muerto); el cuerpo del mago blanco queda muerto → `match_state.begin_altar_collapse(slot, caster_slot)` una vez.

- `abort()`: la criatura cae libre donde estaba al empezar el ritual, mueren los doctores que queden, el sitio se libera, `desecrations -= 1`.
- `complete()` de Convert: la criatura se desintegra, `SoulPurse.add(almas)` al lanzador, mueren los doctores, sitio libre.
- `complete()` de Desecrate: la criatura se desintegra, sus almas vuelven al lanzador, mueren los doctores. El altar ya estaba en `COLLAPSING`.

## 6. Qué pasa en cada caso

| Caso | Resultado | Fuente |
|---|---|---|
| Casteo interrumpido | No hay doctor; el alma queda libre | `state.d:15526-15530` |
| Doctor de Convert muerto antes de llegar | Alma roja y convertible otra vez | `state.d:15626-15627` |
| Muerto durante el pump | La criatura muere de nuevo y deja su alma, de su bando | `state.d:15731-15735`, `10147-10150` |
| Muerto mientras la lleva | La criatura cae viva, de su dueño original, sin alma suelta | `state.d:15776-15779`, `15652-15656` |
| Ritual abortado | La criatura cae viva y libre | `state.d:15817-15821` |
| El alma deja de valer (alguien la junta) o el sitio cae | El doctor muere | `state.d:15681-15685`, `15730`, `15773-15775` |
| La ofrenda de Desecrate muere o cambia de dueño antes de levantarla | El doctor muere | `state.d:15709-15713` |
| Mago blanco en fantasma al empezar | Vuelve al cuerpo con vida ≥ 1 | `state.d:13959-13962` |
| Mago blanco muere bajo ritual, por lo que sea | No hay fantasma: se desvanece en 4 s; su altar se destruye | `state.d:14009-14010`, `15901-15903` |
| Sin mago en ese bando | El altar cae al final de la primera ronda | `state.d:15900`, `16037-16042` |
| Altar ocupado por otro ritual | El portador espera a 20 m | `state.d:15780`, `15866` |

## 7. Resource, nodo, `@export`

- **Resource de tipo:** `MatchRules` gana el grupo «Sacrificios» (sección 8). Los `.tres` de `debug/rules/` solo cambian números. La vida, velocidad, regeneración, evasión y resistencias del doctor salen de `GameData.creature("dcas")`: no se commitea un `.tres` con datos originales.
- **Nodo:** todo lo de la tabla de la sección 4 salvo `Attackable` y `SacrificeMath`.
- **`@export` de instancia (sockets):** `Altar.owner_slot`, `.state`, `.visuals`, `.mana_source`, `.site`, `.collapse`; `RitualSite.kind`; `MatchState.rules`; `DefeatRule.match_state`; `MatchResultBanner.match_state`; `DoctorBody.owner_slot`, `.health: Health`, `.visual`, `.health_bar`, `.states: FsmMachine`, `.rules`, `.drop_on_ready` (solo para el banco de prueba); `StuckGuard.body`; `CarryErrand.body: DoctorBody`, `.steps: FsmMachine`; `Ritual.phases`, `.push`, `.fx`; `SacrificeSystem.world`, `.match_state`, `.doctors_root`, `.doctor_spawner`, `.rituals_root`, `.ritual_spawner`; `Captive.body: UnitBody`, `.corpse`.
- Sockets obligatorios vacíos avisan con `_get_configuration_warnings()`.
- `Caster` vive en el mago, que se spawnea: busca `SacrificeSystem` por el grupo `sacrifice_system` una vez y lo guarda tipado. Sin `.call("…")`.
- Señales en pasado: `Altar.state_changed`, `MatchState.altar_state_changed / side_defeated / result_changed`, `DoctorBody.landed / died`, `CarryErrand.finished(outcome)`, `Ritual.round_tortured(round) / ended(completed)`.

## 8. Números

En `MatchRules`, grupo «Sacrificios», con la cita en el comentario.

| Dato | Valor | Fuente |
|---|---|---|
| Vida, velocidad, regeneración del doctor | 400 · 10 m/s · 83,33/s | `creatures.json` `dcas` |
| Regeneración continua (sin pausa tras un golpe) | sí | `nttData.d:693`, `state.d:1433` |
| Evasión cuerpo a cuerpo · resistencias | 1000 · 1,0 | `creatures.json` `dcas` |
| No se selecciona, no recibe órdenes, no se aturde | — | `state.d:1135`, `1141`, `8547` |
| Convert: maná, casteo, alcance | 800 · 2,22 s · 20 m | `spells.json` `ccas` |
| Desecrate: maná, casteo, alcance | 1000 · 5,56 s · 20 m | `spells.json` `ucas` |
| `desecrate_altar_range` | 75 m en planta | `state.d:28083` |
| `doctor_drop_distance` | 20 m del blanco | `state.d:2640`, `10190`, `10205`. Original: 25 m con reintento a 17,5 (`0x44a8e0`, `0x44ac90`) |
| Punto de aterrizaje | punto medio: 10 m del blanco | `state.d:10168` |
| Lado del vórtice | Convert: más allá del alma, visto desde el mago. Desecrate: del lado del mago | `state.d:10190`, `10205` |
| Búsqueda si el aterrizaje no es suelo | ±45°, ±90°, ±135°, 180° | `state.d:10162-10179` |
| `doctor_drop_height` | 15 m; el doctor sale 2,25 m más abajo | `state.d:2639`, `2641`, `15489` |
| `doctor_bounce_s` | 1,0 s | **invento del port**: la animación `bounce` no está exportada |
| `doctor_death_s` | 2,0 s (70 + 50 cuadros) | `state.d:13999` |
| `convert_reach` | 2 m en planta | `state.d:15693` |
| `convert_pump_s_per_soul` | 5 → `(almas+1)·5` s | `state.d:15697` |
| `convert_revive_min_health` · `_fraction` | 400 · 0,5 | `state.d:8679` |
| `desecrate_pickup_distance` | 10 m en planta | `state.d:15714-15715` |
| `carry_height` · `carry_distance` · `carry_speed_factor` | 3,5 m · 2,7 m detrás · 1,1 | `state.d:15759-15766` |
| `ritual_start_distance` | 20 m (3D) | `state.d:15780` |
| `ritual_radius` | 20 m; 17 m al final de la caminata | `state.d:15857` |
| Ángulos | 45° + 90°·k | `state.d:15858-15859` |
| `ritual_setup_s` | 5 s | `state.d:2713` |
| `ritual_walk_s` · `_shoot_s` · `_wait_s` | 4,5 · 4,5 · 4,5 | `state.d:15948-15951` |
| Ventana de drenaje | empieza a 0,33 s del disparo, dura 4,17 s | `state.d:15975`, `15997` |
| `desecrate_health_per_round` · `_mana_per_round` | `200·(1+almas)` · `40·(1+almas)` | `state.d:16010-16011` |
| Chequeo de fin de ronda | a 9,0 s de la ronda | `state.d:16020` |
| `convert_health_per_round` | 550 → `int(vidaMáx/550) + 1` rondas | `state.d:16027` |
| Altura de la criatura en el ritual | 15 m sobre el sitio | `state.d:15928` |
| `ritual_push_radius` · `_inner` · `_speed` | 20 m · 5 m · 20 m/s, lineal hasta 0 en el borde | `state.d:16051`, `8614-8628` |
| `wizard_vanish_ritual_s` · `wizard_vanish_s` | 4 s · 1 s | `state.d:14010` |
| `altar_collapse_s` | 4 + 4 + 3 = 11 s | `state.d:5289-5291`, `26062` |
| `doctor_stuck_abort_s` | 45 s (0 = nunca) | **invento del port** |

**20 m contra 25 m.** Elijo 20 m con la búsqueda de sacengine. El PRD lo nombra árbitro de la simulación; la diferencia es medio segundo de caminata; y la búsqueda usa `terrain.is_on_ground`, que ya existe.

## 9. ¿Se puede matar a un doctor?

Daño cuerpo a cuerpo sostenido según `melee_attack.gd:114-130`: `orientación × esperanza × fuerza × 0,4`, con orientación entre 1 (de frente) y 2 (por la espalda). Contra evasión 1000:

| Atacante | De frente | De costado | Por la espalda |
|---|---|---|---|
| Druid (fuerza 150, precisión 1000) | 45/s | 72/s | 100/s |
| Trogg (fuerza 200) | 60/s | 96/s | 133/s |

Hay que superar 83,3/s. Un Druid solo no alcanza salvo por la espalda. Dos Druids: entre 7 y 117 de daño neto por segundo. Tres: entre 52 y 217 (de 1,8 a 7,7 s). **Cuatro: entre 97 y 317 (de 1,3 a 4,1 s).** Por eso las escenas llevan 4 guardias; `convert_carry_kill` lleva 6 porque el blanco se mueve. Un Ranger tira 120 cada 2,6 s (46/s): hacen falta 4. Un hechizo directo lo mata de un golpe.

Es cálculo. El caso `doctor_melee` de la suite lo mide.

## 10. Réplica

| Dato | Mecanismo | Por qué |
|---|---|---|
| Estado de cada altar, bandos derrotados, ganador | **Snapshot**: `MpKit.push_snapshot({"match": …})` al cambiar; `push_snapshot_to(peer)` en `client_world_ready` | Confiable y ordenado; el altar es un nodo fijo, no pasa por spawner. `MpFlow` ignora un snapshot sin `world_id` (`mp_flow.gd:275-279`) |
| Doctor: existe o no | **Spawner** (`DoctorSpawner`, un solo `MpSpawner`) | Cubre la entrada tardía |
| Doctor: `position`, `rotation` | Synchronizer, siempre | Como `unit.tscn` |
| Doctor: `owner_slot` | Synchronizer, solo spawn | Identidad |
| Doctor: `Health:maximum`, `Health:current`, `pose` | Synchronizer, spawn + al cambiar | Barra de vida y presentación |
| Recado del portador | No se replica | Solo el servidor decide |
| Ritual: existe o no | **Spawner** (`RitualSpawner`) | El que entra tarde lo recibe |
| Ritual: `kind`, `caster_slot`, `target_slot`, `site_path` | Synchronizer, solo spawn | No cambian |
| Ritual: `phase`, `round` | Synchronizer, spawn + al cambiar | Efectos y aviso |
| Criatura tomada | Su sincronizador de siempre: `position` y `mode` (`REVIVING`, `HELD`) | No hay dato nuevo |
| Mago: `GhostForm:under_ritual` | Synchronizer del mago, spawn + al cambiar | Duración del desvanecido y aviso |
| Vida y maná del mago drenado | Lo que ya se replica | — |
| Vórtice y rayos | `FxBus.broadcast` (RPC authority, no confiable) | Evento cosmético |
| Convert / Desecrate | `submit_cast(tag, point, path)` existente; `path` = alma o criatura | **Ningún RPC nuevo de cliente** |
| Texto de rechazo | `_receive_feedback` existente | — |
| Avisos del ritual | Ninguno: `RitualNotice` los deduce de `Ritual` y `MatchState` | — |

**Solo el servidor:** validación, reserva del alma, posición del vórtice, estados del doctor, recado, ritual, drenaje, empuje, ocupación del sitio, reloj del derrumbe, derrota.

**Cliente que entra a mitad de un ritual:** recibe los 4 doctores con su vida, el nodo `Ritual` con su fase, la criatura en el aire con `mode = HELD`, `under_ritual` en el mago y el snapshot de `MatchState`. No ve el vórtice ni los rayos hasta la próxima emisión.

## 11. Presentación mínima

| Fase | Qué se ve hoy | Falta exportar |
|---|---|---|
| Casteo | `FxBus` `summon` a 15 m, al empezar y al salir el doctor | Vórtice rojo (malla y textura) |
| Caída y rebote | `sacd` en pose fija, cayendo | Clips `expelled`, `bounce` |
| Caminar | `sacd` deslizándose, barra de vida (`unit_health_bar.tscn`) | Clips `SDrn` (correr) y caminar cargando |
| Pump | Doctor quieto sobre el cadáver; `FxBus` `heal` al revivir | Clip `SDpm`; sonido `convertRevive` |
| Acarreo | Criatura flotando 3,5 m arriba y detrás | Clip `SDpu`; la cuerda (aguja y spline de 5 puntos); `thrash` de la criatura |
| Preparación | 4 doctores quietos en el anillo; criatura subiendo | Clip `SDda` (danza); aparición gradual |
| Disparo | `FxBus` `wrath_cast` sobre la criatura y `wrath_explosion1` sobre el mago cada 0,5 s | Rayos del altar (2) y de profanación (3); clips de tortura y `SDsb`; resaltado del mago |
| Fin de ritual | `FxBus` `blood` donde estaba la criatura | Animación de desmembrado |
| Altar | `Visuals` se hunde 4 s, la base sube y se achica 4 s, `wrath_explosion2` | Disolución por altura de los pilares; temblor de cámara |
| Muerte del doctor | Se desvanece en 2 s | Clip de muerte |

Avisos en `%RitualNotice` (cartel propio; `%Battle` lo pisan las órdenes): «Están profanando tu altar» al dueño mientras exista un `Ritual` de Desecrate sobre su slot; «Ritual interrumpido» al lanzador y al dueño; «Altar profanado» a todos. Rechazos por `%Battle`, como hoy: «Sin altar», «Lejos del altar enemigo», «Blanco inválido», «Fuera de alcance».

No se inventa arte. Los clips del `sacd` salen del mismo exportador de F37; es otro corte.

## 12. Qué se borra y qué cambia

- **020a:** de `high_noon.gd`, `_on_match_over` y la conexión a `match_over`. De `desecration_system.gd`, `match_over`, `_destroyed_altars`, `_watch_wizard`, `_on_ghost_stage_changed`.
- **020c:** la carpeta `scenes/world/desecration/` entera y `%DesecrationSystem`. De `caster.gd`, `_desecrate_altar`. De `match_command.gd`, `_altar_under` y las ramas `CONVERT` / `DESECRATE` de `_cast_at`, que no se alcanzan.
- **020e:** `souls/sac_doctor.gd` y `.tscn`. De `soul_system.gd`: `request_convert`, `_spawn_doctor`, `_make_doctor`, `_altar_point`, `_doctor_for`, `_on_doctor_finished`, `DOCTOR_SCENE`, `CONVERTED`, `doctors_root`, `doctor_spawner`. De `soul_system.tscn`: `Doctors`, `DoctorSpawner`. De `caster.gd`: `_convert_soul`.
- **Lo que se reusa de RFC-017:** `Altar` con estado, `MatchState` con snapshot y reenvío, `MatchResultBanner`, `DoctorBody`, `Attackable`, `class_name Health`, la tabla de réplica del doctor.
- **Cambio de `ghost_form.gd` con «sin altar».** Hoy `_has_altar()` mira los `ManaSource` de tipo altar y, si no hay, pasa a `GONE` en 1 s y no pasa nada más. Queda: `_has_altar()` pregunta por un `Altar` en `STANDING` de su slot; `GONE` también si `desecrations > 0`, con 4 s de desvanecido; `DefeatRule` escucha `GONE`.

## 13. Limitaciones, resueltas a la vista

- **Sin pathfinding.** El doctor camina en línea recta con colisión. Contra un cilindro (pilar, base del altar) `move_and_slide` lo hace resbalar. Contra un borde de cañón o una pared se traba. **Fiel:** el original no tiene plazo; el doctor empuja hasta que lo matan o el blanco deja de valer. **Pragmático (lo que planifico):** `StuckGuard` hace un paso al costado si no avanza 2 m en 2 s y mata al doctor a los `doctor_stuck_abort_s`. Al morir corre el caso fiel de «matan al doctor». Con el valor en 0 o sin el hijo queda el original.
- **Sin Shrine.** El destino de Convert es el `RitualSite` propio en pie más cercano al mago al castear. Un Shrine futuro suma un hijo `RitualSite` y entra solo.
- **Sin componente conexa.** sacengine exige que el sitio esté en la misma zona caminable que el mago (`state.d:28089`). Sin pathfinder no se puede preguntar: se omite.
- **Sin XP.** `Ritual` emite `round_tortured(round)`; un sistema de XP futuro escucha ahí (`giveXPToSide`, `state.d:16000`; `drainXPFromSide`, `16012`). Fuera de alcance.
- **Regeneración de 83/s.** Es fiel. Sección 9.
- **La criatura flotando no usa `move_and_slide`.** Va sin colisión y sigue un punto, como en sacengine (`state.d:15762-15769`). No es locomoción; la regla de RULES sobre el movimiento aplica al doctor, que sí usa el motor.

## 14. Riesgos

- **Pose del `sacd`.** `upright_checked: false`: puede verse acostado o flotando. Se corrige con una entrada en `data/bodies/pose_overrides.tres`, que nace en 019b.
- **`FsmMachine` entra al estado inicial también en el cliente.** Por eso el primer hijo es `Off`, sin script, y solo el servidor transiciona. No hay guardas en cada estado.
- **`Mode.HELD` y `Mode.REVIVING` van al final del `enum`.** `mode` se replica como entero; insertar en el medio rompe los flows que leen `mode`.
- **Revivir un cadáver** deshace `Corpse.lay_down` en todos los peers (grupo, capa, pivote). Es la pieza más delicada de 020e.
- **Empuje.** `RitualPush` mueve cuerpos ajenos con `move_and_collide` después de `GroundGuard.keep_on_ground`. Si un altar está pegado a un borde, un cuerpo puede quedar apretado contra él.
- **`convert_carry_kill`.** Guardias cuerpo a cuerpo contra un blanco que camina a 10 m/s pueden no sostener 83/s. Si el flow no cierra: más guardias sobre el camino, o se prueba a mano con Rock.
- **Reingreso con la partida terminada.** `WizardSpawner` puede crear un mago nuevo; solo se garantiza el cartel.
- **Daño por salpicadura.** Fireball, Swarm y Wrath siguen sin alcanzar a doctores ni estructuras por salpicadura (`["wizard","unit"]`). El golpe directo sí.
- **`match_rules.gd`** lo tocan los cinco sub-cortes, 019d y 019e. Cada uno agrega al final de su grupo.

**Fuera de alcance:** pathfinding; Shrine, Guardian, Teleport; XP; el manantial que deja un altar destruido (`makeManafount`, `state.d:26009`); clips, vórtice, rayos, cuerda y sonidos; alarma en el minimapa; equipos y más de 2 jugadores; el aviso al dueño cuando atacan a su doctor (`state.d:999`); refactor de `unit_body.gd`.

## 15. Conflictos y orden con lo que está en cola

| Corte en cola | Archivos en común | Veredicto |
|---|---|---|
| 019b (en curso) | Ninguno. 020b usa `BodyVisual` y `BodyLibrary.info("sacd")`, no los edita | Paralelo. La revisión visual del doctor, después de 019b |
| 019a | Ninguno | Paralelo |
| 019c | Ninguno (`props/manafount.*`, `scenes/fx/`). 020 solo consume `FxBus` | Paralelo |
| 019d | `match_rules.gd`, y depende de `Altar` | Después de 020a |
| 019e | `match_rules.gd/.tres` | No en simultáneo sobre ese archivo |
| 018c | `high_noon.tscn` | No en simultáneo con 020a ni 020c, que editan esa escena. 020b, 020d y 020e sí |
| 018d | `high_noon.tscn` | Igual que 018c |
| 018e | Mueve `MapProps/Starts` a la escena del mapa | **Después de todo 020.** Tiene que actualizar las rutas de las escenas debug. `MatchState` busca altares por grupo, no por ruta |

Entre los míos: **020a ∥ 020b** (solo comparten `rules_suite.gd` y `match_rules.gd`, con agregados al final). 020c, 020d y 020e van en serie.

## 16. Orden de implementación

**020a**
1. `altar.gd`, `ritual_site.gd`, `altar_collapse.gd`; `altar.tscn` con `Visuals`, `Site`, `Collapse`; `player_start.gd` tipado.
2. `match_state.gd`, `defeat_rule.gd`, `match.tscn`; `%Match` en `high_noon.tscn`.
3. Snapshot: push, reenvío en `client_world_ready`, aplicación en el cliente.
4. `ghost_form.gd`: `desecrations`, `under_ritual`, `_has_altar()` por `Altar`; `under_ritual` al sincronizador del mago.
5. `match_result.tscn` bajo `Hud`; limpiar `high_noon.gd` y la parte de victoria de `desecration_system.gd`.
6. `match_rules` (`altar_collapse_s`, `wizard_vanish_*`); `debug/match_defeat.tscn`; casos `altar_collapse` y `match_snapshot`.

**020b**
1. Copiar `addons/fsm_kit`, activar el plugin, parse headless sin errores.
2. `class_name Health`; `attackable.gd`; reemplazar los tres chequeos; `"doctor"` en `target_groups` y en `BodySeparation.GROUPS`.
3. `doctor.tscn`, `doctor_body.gd`, los cuatro estados, `stuck_guard.gd`.
4. `match_rules` (`doctor_*`); `debug/doctor_bench.tscn`; casos `doctor_*`.

**020c**
1. `captive.gd` en `unit.tscn`; `Mode.HELD` y sus tres guardas en `unit_body.gd`.
2. `sacrifice_math.gd` (posiciones del vórtice); `sacrifice_system.tscn/.gd`: `arm_status`, `check`, `begin_cast`, `finish_cast`, `cancel_cast`.
3. `carry_errand.gd`, `errand_step.gd`, `approach.gd`, `haul.gd`, `carrier_doctor.tscn`.
4. `caster.gd`: `structure_status` y `_try_cast` aceptan `ucas` desde la pestaña de estructuras; `_start`, `_finish` e `_interrupt` llaman al sistema.
5. `match_command.gd`: el clic de Desecrate usa `_unit_under`.
6. Borrar `desecration/`; `%SacrificeSystem` en `high_noon.tscn`; `debug/desecrate_carry.tscn`; casos `drop_positions`, `captive`, `desecrate_check`.

**020d**
1. `SacrificeMath`: anillo, rondas, drenaje.
2. `ritual.tscn`, `ritual.gd`, las cuatro fases; `RitualSpawner`; `SacrificeSystem.start_ritual()` con la ocupación del sitio.
3. Drenaje en `shoot.gd`; `desecrations` en el mago blanco; aviso a `MatchState` cuando el mago muere.
4. `ritual_push.gd`; `ritual_fx.gd`; `ritual_notice.tscn`.
5. `debug/desecrate_ritual.tscn`, `debug/ritual_cancel.tscn`; casos `ritual_*` y `ghost_under_ritual`.

**020e**
1. `soul.gd`: `State.REVIVING` y reserva por slot.
2. `Captive.revive()`, `Corpse.stand_up()`, `Mode.REVIVING`.
3. `pump.gd`; rama Convert de `approach.gd`; fin de Convert en `shoot.gd`; `SacrificeSystem` valida `ccas` y elige el sitio.
4. `caster.gd` acepta `ccas`; borrar el Convert viejo de `soul_system` y `sac_doctor.*`.
5. Las tres escenas `convert_*`; caso `convert_revive`.
6. Reescribir F38 y F39 en `FEATURES.md`.

## 17. Cómo verifica un humano

- **F6 en `altar.tscn`:** en el inspector remoto, `state = COLLAPSING` → se hunde y desaparece; `DESTROYED` → sin malla ni colisión.
- **F6 en `doctor.tscn`:** se ve `sacd`, la cápsula y la barra; sin avisos de sockets. Con `drop_on_ready` cae y rebota.
- **Inspector:** `data/match_rules.tres` muestra el grupo «Sacrificios». `ritual_walk_s = 1` en un `.tres` de debug acorta la ronda sin tocar código.
- **Online:** `Godot --headless --path game -- --dedicated --mp-port=7801 --world=res://debug/desecrate_ritual.tscn` y dos editores con el mismo `--world`. A hace la acción de la tabla. En el árbol remoto del dedicado: `%SacrificeSystem/Rituals/Ritual1` con `phase` cambiando, `%Match.winner_slot = 1` al final. Los clientes: «Victoria» y «Derrota».
- **Cancelación a mano:** en `desecrate_ritual`, B pulsa `spell_3` (Rock) y hace clic sobre un doctor del anillo: los cuatro desaparecen, el altar sigue, `Offering` cae y se puede seleccionar.
- **Entrada tardía:** abrir B durante la preparación: 4 doctores, criatura en el aire, «Están profanando tu altar».
- **Convert:** en `convert_ritual`, «Almas 0» pasa a «Almas 1» y `Victim` ya no está en `%Units`.
- **Solo:** F5 → Jugar solo en `desecrate_ritual`: el ritual corre sin servidor (no hay mago 2: el altar cae al final de la primera ronda).
- **Suite:** `Godot --headless --path game res://debug/rules_suite.tscn` termina en `RULES SUITE PASS`.

## 18. Texto corregido para `FEATURES.md`

### F38 — Convert con Sac Doctor
Convert (`ccas`, pestaña Estructuras) roba las almas de una criatura enemiga muerta. El mago apunta a un alma roja a 20 m o menos y necesita un altar propio en pie. Al terminar el casteo (2,2 s, 800 de maná) un Sac Doctor cae de un vórtice junto al cadáver, camina hasta él, lo revive y lo bombea `(almas+1)·5` s, lo levanta y lo lleva flotando al altar propio más cercano al mago. Ahí cuatro doctores hacen el ritual: 5 s de preparación y `vidaMáx/550 + 1` rondas de 13,5 s. Al final la criatura se desintegra y sus almas se suman al contador del mago.

Criterio: en `res://debug/convert_ritual.tscn`, con dedicado y dos clientes, A pulsa la pestaña Estructuras, `spell_3` y hace clic sobre el alma roja; «Almas 0» pasa a «Almas 1» y la criatura ya no está. Matar al doctor: antes de llegar, el alma sigue roja; durante el bombeo (`convert_pump_kill.tscn`), la criatura muere otra vez y deja su alma; mientras la lleva (`convert_carry_kill.tscn`), la criatura cae viva y de su dueño.

Pendiente: RFC-020e. Lo anterior (un doctor que salía del altar, consumía el alma y volvía) no era el original y se reemplaza.

### F39 — Desecrate y fin de partida
Desecrate (`ucas`, pestaña Estructuras) es la condición de victoria. Con un altar enemigo a 75 m o menos, el mago apunta a una criatura propia y viva a 20 m o menos. Al terminar el casteo (5,6 s, 1000 de maná) un Sac Doctor cae junto a ella, la levanta y la lleva al altar enemigo. Ahí cuatro doctores hacen el ritual a 20 m del altar: 5 s de preparación y rondas de 13,5 s. Cada ronda le quita al mago enemigo `200·(1+almas)` de vida y `40·(1+almas)` de maná. Si el mago muere bajo ritual no vuelve como fantasma: desaparece, su altar se destruye y su bando queda derrotado. Si muere cualquiera de los cuatro doctores, el ritual se cancela y la criatura queda viva y libre.

Criterio: en `res://debug/desecrate_ritual.tscn`, con dedicado y dos clientes, A pulsa la pestaña Estructuras, `spell_4` y hace clic sobre su criatura; el cliente A termina en «Victoria» y el B en «Derrota», con el altar 2 destruido en los tres procesos. En `res://debug/ritual_cancel.tscn`, los guardias matan a un doctor: el altar 2 sigue en pie y la criatura vuelve a `%Units`.

Pendiente: RFC-020a, c y d. Lo anterior (borrar una criatura, un doctor que cantaba 7,5 s y destruía el altar) no era el original y se reemplaza.

## 19. Preguntas abiertas

Ninguna bloquea. El plan asume la recomendación.

1. **Doctor trabado.** ¿Plazo de 45 s (pragmático) o sin plazo (fiel)? **Recomiendo 45 s**: sin pathfinding, un doctor contra un borde retiene a una criatura para siempre. Es un número en `MatchRules`.
2. **Criaturas del derrotado.** sacengine las mata a todas cuando el mago termina de desvanecerse. **Recomiendo incluirlo en 020a**; son pocas líneas en `DefeatRule`.
3. **Almas de la ofrenda.** En sacengine vuelven al lanzador al completar Desecrate. Sin verificar en el original. **Recomiendo seguir a sacengine.**
4. **Manantial donde había un altar.** sacengine deja uno al destruirlo. **Recomiendo dejarlo fuera**: nadie queda en la partida para usarlo con 2 jugadores.
5. **Numeración.** F57 a F61 para 020a–e, y reescribir F38 y F39 en lugar de abrir entradas nuevas para Convert y Desecrate. **Recomiendo eso.**

## 20. Decisiones del usuario (2026-10-13)

- Árbol aprobado como está: cinco sub-cortes en el orden propuesto, 020a y 020b en paralelo.
- Pregunta 1: plazo de 45 s para el doctor trabado (invento del port, en `MatchRules`).
- Preguntas 2 a 5: se siguen las recomendaciones (mueren las criaturas del derrotado; las almas de la ofrenda vuelven al lanzador; sin manantial donde había un altar; F57 a F61 y reescribir F38 y F39).

## 21. Ajustes tras `.studio/RESEARCH-victory.md` (2026-10-13)

Investigación pedida por el usuario sobre la condición de victoria, con cuatro fuentes: sacengine, el ejecutable, los textos del juego (`ReadMe.txt` de la instalación, cadenas de `lang_english.wad`) y web.

- **Confirmado con el texto del propio juego** (`ReadMe.txt` 7.7): la victoria se consigue profanando el altar rival; el ritual ataca al mago repetidamente y, si muere por esos ataques, su altar se destruye y su partida termina. Un mago que muere sin ritual vuelve como fantasma y no pierde.
- **020d — sin tope de rondas.** El ritual no termina por tiempo ni por cantidad de rondas: sigue hasta que el mago muere o se cancela. Que el mago se cure o huya no lo corta. Criterio a agregar en 020d.
- **020d — cancelación.** Basta matar a uno de los 4 doctores. Según el ReadMe, los atacantes cuerpo a cuerpo no pueden hacerlo por una barrera mágica: coincide con el empuje de 20 m de `RitualPush`. El contrajuego son hechizos y ataques a distancia. Las escenas de prueba de 020d que cancelan el ritual tienen que usar tiradores o un hechizo directo, no Druids cuerpo a cuerpo.
- **020a — reglas respaldadas solo por sacengine**, sin verificar en el original: «el mago que muere sin ningún altar en pie desaparece y su bando pierde» y «al quedar derrotado un bando mueren sus criaturas». Quedan implementadas y anotadas así.
- **Más de dos bandos:** la victoria es «no quedan enemigos con altar sin derrotar», no un único vencedor. Hoy hay 2 jugadores; `DefeatRule` ya declara ganador al último bando en pie.
- **Sin resolver, no se elige:** las cifras del drenaje difieren entre el ejecutable (vida:maná 100:13,3) y sacengine (200:40) y no se pudieron reconciliar las unidades; se usa sacengine, anotado. Qué pasa con las almas del desterrado: el ReadMe dice que quedan libres para convertir y un consejo del juego dice que se pierden para siempre.
- **Fuera de alcance, anotado:** rendirse; modos Slaughter, Soul Harvest y Domination.
- **A revisar aparte (no es de este RFC):** el ReadMe dice que el fantasma revive al reponer el 25 % del maná en altar, Manalith o manantial; el port (F31, sacengine) lo hace por vida llena con 4,2 de vida por punto de maná.
