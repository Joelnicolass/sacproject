# RFC-053: IA y sensación de combate

Estado: plan del tech lead, sin implementar. Cortes 053a–053h (F370–F377) y cierre 053z (F378).
Pedido: el usuario jugó contra la IA dos veces (Persephone Normal en peaks, James Normal en Peasantville). Dijo cinco cosas:
- La IA no se entiende ni es pareja.
- Cuesta ver la vida de los edificios.
- Al combate le falta respuesta.
- El reposo parece caminar en el lugar.
- Algunas de sus criaturas no atacan.

Autoridad: PRD > FEATURES > RULES > VISUAL > este RFC. Hay dos contradicciones con el PRD (§14); las decide el usuario.

## 1. Evidencia (partidas del usuario)

**Partida 1: peaks, IA Persephone Normal.**
- **Golpes a lápidas.** Las criaturas de la IA dieron unos 25 golpes cuerpo a cuerpo a edificios indestructibles del mapa: `grv1`, `grv2`, `grv3` y `crs1` (en el log: «vida 0 en su BLDG, es indestructible»). Daño total: 0.
- **Wrath sobre una lápida.** La IA tiró Wrath unas 6 veces centrado en la lápida `grv3`. La explosión de 10 m dañó a su propio Mutant y a su Ranger, que estaban a 1 m (unos 200 cada uno).
- **Heal en bucle.** Después tiró Heal unas 30 veces. Casi siempre sobre las unidades que había dañado ella misma, y también sobre Rangers recién convocados y sanos. El ciclo se repitió durante su Desecrate.
- **Remate lento.** 4 Rangers de la IA le disparaban al mago del jugador (120 por golpe) mientras la Charlotte del jugador lo curaba con telas (`slba`), y cada tanto caía un Wrath. Tardaron mucho en matarlo. «Todos en su lugar»: cada uno disparaba desde donde estaba.
- **Victoria de la IA.** Ganó con Convert para juntar almas y Desecrate mientras el mago del jugador estaba muerto.
- **Error de motor al terminar.** `structure_body.gd:52 _exit_tree` → `_release_manafount` → `manafount_body.gd release` → `_set_active` → `sprite_emitter.gd:46 set_active` → `get_global_transform` fuera del árbol, 3 veces.

**Partida 2: Peasantville, IA James Normal.**
- **Granjeros enemigos.** El log de la IA dice «escaneo inicial 2 propios, 0 aliados, 7 neutrales, 50 enemigos»: los Farmers (slot 3) cuentan como enemigos. Eso es fiel al original. La tabla SIDS de Peasantville tiene a los campesinos y a los magos como enemigos mutuos: `assets/original/maps/peasantville/sides.tres`, bando 0 con `enemies = 6`, bandos 1 y 2 con `0x7ffffffd`/`0x7ffffffb`. Es lo mismo que usa `getStance` en sacengine. **Los granjeros siguen siendo enemigos.**
- **Criaturas clavadas en un granjero.** Hay unas 30 líneas «aturdido Farmer durante 246», «aturdir: Farmer en enfriamiento (300)» y «directo Farmer 150.0». Criaturas con ataque que aturde o petrifica le pegan a un granjero pasivo que no muere: tiene 500 de vida, regenera 16,7/s y su resistencia cuerpo a cuerpo es 1,5 (`zepe.tres`). La criatura queda clavada ahí. Es la causa más probable de «mis criaturas no atacan».
- **El error del emisor también aparece al salir de la partida.** Lo dispara cualquier estructura con manantial que se libere en `_exit_tree`.

## 2. Causas encontradas en el código

| Síntoma | Causa | Dueño |
|---|---|---|
| Golpes a lápidas | `TargetRules.is_valid_foe_of(slot, node, me, by_stance)` acepta cualquier cuerpo de otro bando con `Health` que no esté muerto. Un `MapBuilding` de vida 0 tiene `Health.maximum = 0`, y `is_dead()` da `false` (`maximum > 0 and current <= 0`). Con orden (`ordered`), `UnitBody.is_foe`/`accepts_target` y `UnitOrders._in_sight` pasan `by_stance = false`. Las criaturas de la IA siempre tienen orden (escolta `guard` o avance `advance`), así que toman como blanco cualquier cuerpo ajeno. En sacengine, `isValidAttackTarget` exige `health != 0` (state.d:12426-12432) y `canDamage(Building)` también (9091). Falta confirmar si en peaks el bando 0 sale ENEMY por `SideRelations.stance` cuando `knows()` es falso; es el paso de diagnóstico de 053a. | `TargetRules` |
| Wrath sobre `grv3` | `wrath_strike.gd` explota contra el primer cuerpo de otro bando que toca (`pick_body` con `is_live_body`, que acepta `Health` de máximo 0). La lápida estaba entre el mago y su blanco. `AiWizardBrain.execute_best_cast` no comprueba la línea de tiro del original (su propio comentario lo dice). El original (shiny.d:3246-3270), sin tiro limpio ni línea de visión, no lanza: camina hasta la mitad de la distancia y vuelve a probar. Además, `AiSpellEval._area` resta los grupos propios cercanos al **blanco**, no al punto donde de verdad explota. | `AiWizardBrain`, `AiSpellEval` |
| Heal en bucle | `_heal` puntúa cualquier vida faltante mayor que 0 (`worth · healed/max`), sin umbral. La cola se arma cada 1,6 s y la entrada no se revalida al ejecutarla. `SupportPhase` no excluye cuerpos en `SUMMONING`. | `SupportPhase`, `AiSpellEval` |
| «Todos en su lugar», muerte lenta | Las criaturas de la IA solo escoltan al mago (`GuardTask` cmd 1: se quedan a `retreat_hold_m` = 10 m y pelean lo que llegue) o lo siguen (`IdleTask`). Nadie en el árbol ordena «atacar a X» a varias criaturas a la vez. `AttackPhase` elige de nuevo el blanco de los hechizos en cada replanificación, en vez de retenerlo, y no le da más peso a un curador enemigo. | `FocusTask` (nuevo), `AttackPhase` |
| Granjero inmortal | Ninguna regla suelta un blanco que no baja de vida. El ataque que aturde tiene 8 s de enfriamiento (`StunImpact.cooldown_ticks` 480), y el granjero se cura más rápido de lo que pierde. | `TargetPicker` (nuevo hijo `TargetFutility`) |
| La IA tira hechizos a granjeros | `AttackPhase` recorre `bodies(3)` con los NPC incluidos (lo dice su comentario). El PRD dice «La IA no los caza a propósito». | `AttackPhase` |
| Reposo que camina | Los clips `gesture` de `bake_body_scenes._creature_roles` son el `idle0` del CRE8. Medido en `data/catalog/creatures/*.tres`: son clips `*i1` de reposo (`HUi1`, `PEi1`, `CKi1`…), no pasos. El original incluso hace gestos **más** seguido: en cada vuelta de `stance1`, 4 de cada 5 veces elige al azar entre idle0, idle1 e idle3 (state.d:7977-7990, `!state.uniform(5)`). Lo más probable es otra cosa: `ChaseState` reproduce `run` con `pace = move_speed · max(0, facing·dir)` ≈ 0 en estos casos: <ul><li>la criatura está girando;</li><li>la evasión la tiene trabada;</li><li>está debajo de un volador que no alcanza (`maxTargetHeight` no está portado, state.d:12879);</li><li>está clavada en un blanco inútil.</li></ul> Se confirma con una sonda (053g). | `ChaseState`, `TargetPicker` |
| Error al salir | `SpriteEmitter.set_active` asigna `emitting` estando fuera del árbol. `SoundEmitter3D.set_active` ya se protege con `is_inside_tree()`. | `SpriteEmitter` |

## 3. Objetivo (criterios de aceptación)

- **Blancos válidos.** Ninguna criatura ni mago, del jugador o de la IA, elige ni golpea un cuerpo que no puede recibir daño (`Health.maximum <= 0`). Una criatura suelta el blanco que no logra bajar de vida. La IA no tira hechizos de ataque sobre NPC pasivos.
- **Hechizos sensatos.**
  - La IA no tira un hechizo de proyectil o de área sin tiro limpio: se acerca, como el original.
  - No lanza un hechizo de área si la explosión prevista daña a cuerpos propios más de lo que permite la dificultad.
  - Heal solo va a cuerpos propios por debajo del umbral de la dificultad. Nunca a uno lleno, en convocación o que ya se está curando.
- **Rematar.** Cuando la IA puede matar a un blanco con lo que sabe, sin trampa, se compromete:
  - varias criaturas reciben la orden de atacarlo;
  - el mago lo retiene como blanco de sus hechizos;
  - un curador enemigo cercano pesa más.

  En el escenario de remate, el tiempo hasta matar es como mucho la mitad del medido antes del corte.
- **Panel de información.** Al pasar el puntero sobre una criatura, mago, edificio o alma, aparece junto al cursor la caja del original después de 0,5 s. Muestra icono, «<nombre> de <bando>» y barra de vida (sin barra si es indestructible), o el texto del alma. Las barras de las criaturas no cambian.
- **Respuesta del combate.**
  - Destello al recibir daño.
  - Sacudida de cámara cuando golpean al mago local o hay explosiones grandes cerca; ajustable y apagable en Opciones.
  - El gesto de daño del original cuando la criatura está quieta y el modelo tiene el clip.

  Todo es presentación: sin RPC nuevas y sin tocar la simulación.
- **Reposo.** Ninguna criatura quieta reproduce `run` sin moverse.
- **Error de salida.** 0 errores de `get_global_transform` al caer un altar o al salir de una partida.
- **Datos.** Todos los umbrales y pesos de la IA viven en un `AiTactics` `.tres` por dificultad. Sin trampa: la IA usa lo que su bando sabe (`AiPerception.health_of`, `knows_live`), como hoy.

## 4. Escenas de prueba

- **Dónde y cómo corren.** Todas viven en `debug/` y corren sin ventana en segundos, salvo las marcadas «ventana».
- **Banco de la IA.** Es el que ya existe (`debug/ai/ai_match.tscn` + `BenchRules` `.tres`), con dos piezas de datos nuevas (§5):
  - `BenchBuilding`: edificios del mapa en la escena.
  - `BenchExpect`: criterios que se imprimen como `AI_EXPECT PASS|FAIL <nombre> <valor>`.
- **Variantes.** Una variante es otro `.tres`, nunca otro `.gd`.

Comando base: `bash agent/harness/godot_run.sh $G --headless --fixed-fps 600 --path . res://debug/<dominio>/<escena>.tscn -- --seed=1 --minutes=0.5 --watchdog-s=20`

| Corte | Escena | Estado inicial | Lo que todavía no ocurre | Acción |
|---|---|---|---|---|
| 053a | `debug/units/f370_targets.tscn` = `ai_match.tscn` con `debug/rules/f370_*.tres`. Tres casos. **`guard_reacts`**: 3 Troggs (`ycro`) del slot 1 quietos y 3 con `guard_area`; un Ranger del slot 2 pasa a 25 m con `move` (`order_point` nuevo en `BenchGroup`). **`indestructible`**: una `grv3` (slot 0) junto a 3 criaturas con `guard`, y un enemigo a 30 m. **`futile_stun`**: el atacante que aturde de `target_only` frente a un Farmer `zepe`, con un enemigo real a 60 m. | Todo quieto; la IA no corre. | Las criaturas no reaccionan; golpean la lápida; el atacante sigue clavado en el granjero. | Sin ventana: solo. Con ventana: Enter (`check_tick`). |
| 053b | `debug/ai/f371_ai_targets.tscn`. **`wrath_blocker`**: mago IA Persephone con maná y Wrath; una `grv3` a 6 m entre él y un enemigo a 25 m; un Ranger propio a 1 m de la lápida. **`npc`**: mago IA con Farmers a 20 m y un enemigo a 40 m. | El mago IA decide. | Wrath explota en la lápida; hechizos sobre granjeros. | Ídem. |
| 053c | `debug/ai/f372_ai_heal.tscn`: mago IA con Heal; 3 criaturas propias al 30 %, 95 % y 100 %, y una que se convoca en el tick 1. | | Heal sobre la del 95 % o sobre la recién convocada. | Ídem. |
| 053d | `debug/ai/f373_ai_finish.tscn`: mago IA y 4 Rangers del slot 2 contra el mago del slot 1 (quieto, al 40 %) y una Charlotte del slot 1 que lo cura. Variantes de dificultad: easy y normal. | | Cada Ranger con un blanco distinto; muerte lenta. | Ídem. |
| 053e (ventana) | `debug/ui/f374_target_info.tscn`: `Camera3D` fijo, `TargetProbe` con `debug_pointer`; una `grv3`, una casa destructible `jhut`, un Manalith, un `unit.tscn` (`ycro`) y un alma; `TargetInfoPanel` en un `CanvasLayer` con `HudScale`. | Nada bajo el puntero. | El panel no existe. | Flow `agent/flows/f374_target_info.json`. A mano: mover el mouse. |
| 053f (ventana) | `debug/fx/f375_hit_feel.tscn`: un `wizard_body.tscn` local y 2 `unit.tscn`, con `WorldCamera` y `CameraShake`. | Quietos. | Sin destello ni sacudida. | Acción `debug_hit`. Sin ventana: `--feel-script` imprime `FEEL PASS\|FAIL`. |
| 053g (ventana) | `debug/units/f376_idle_truth.tscn` = `ai_match.tscn` con dos casos. `f376_quiet.tres`: una criatura de cada modelo, 60 s, sin enemigos. `f376_flyer.tres`: una criatura cuerpo a cuerpo contra un volador `bobs` fuera de su alcance. Sonda `IdleTruthProbe`. | Quietos. | `run` sin moverse. | Sin ventana: solo. |
| 053h | `debug/fx/f377_fount_exit.tscn`: un manantial con un Manalith encima. Se libera primero el Manalith y después toda la escena. | Manalith en pie. | El error sale. | Solo; busca `get_global_transform` en el log. |

## 5. Árbol de archivos

```
game/
├── scenes/ai/
│   ├── data/ai_tactics.gd                 NUEVO  AiTactics (Resource): umbrales y pesos de 053b-053d por dificultad
│   ├── data/ai_difficulty.gd              CAMBIA @export var tactics: AiTactics (null = tactics_normal)
│   ├── brains/ai_spell_eval.gd            CAMBIA _heal con umbral; own_splash(point, spell)
│   ├── brains/ai_line_of_fire.gd          NUEVO  AiLineOfFire (static): tiro limpio mago→blanco
│   ├── brains/wizard_brain.gd             CAMBIA execute_best_cast: tiro limpio (si no, acercarse a la mitad), veto de daño propio, revalidar Heal
│   ├── brains/phases/attack_phase.gd      CAMBIA peso 0 a NPC pasivos, peso extra al curador, retiene el blanco
│   ├── brains/phases/support_phase.gd     CAMBIA sin cuerpos en SUMMONING; umbral de AiTactics
│   ├── tasks/focus_task.gd                NUEVO  FocusTask: «matar a X»; reclama criaturas cercanas y les ordena attack
│   ├── tasks/kill_estimate.gd             NUEVO  KillEstimate (static): segundos para matar
│   └── ai_side.tscn                       CAMBIA Tasks: CaptureTask, FocusTask, GuardTask, IdleTask
├── data/ai/tactics_{easy,normal,hard}.tres NUEVO; difficulty_*.tres CAMBIA tactics
├── scenes/units/
│   ├── targeting/target_rules.gd          CAMBIA is_valid_foe_of: false si Health.maximum <= 0
│   ├── targeting/target_picker.gd         CAMBIA passive_weight; max_target_height en cuerpo a cuerpo; consulta TargetFutility
│   ├── targeting/target_futility.gd       NUEVO  TargetFutility: un blanco que no baja de vida se marca inútil por ban_s
│   ├── unit.tscn                          CAMBIA hijos TargetFutility, HitFlash
│   ├── states/chase_state.gd              CAMBIA (053g, según la sonda) sin `run` con paso ≈ 0
│   └── states/idle_state.gd               CAMBIA (053f) clip `hit` al recibir daño quieto; (053g) gesto
├── scenes/wizards/wizard_body.tscn/.gd    CAMBIA HitFlash; (053g) igual que idle_state
├── scenes/fx/
│   ├── sprite_emitter.gd                  CAMBIA set_active fuera del árbol: guarda y aplica al entrar
│   ├── hit_flash.gd/.tscn/.gdshader       NUEVO  HitFlash (overlay aditivo, Tween 0,12 s)
│   └── shake_map.gd                       NUEVO  ShakeMap: FX de FxBus → trauma (data/fx/shake_map.tres)
├── scenes/camera/
│   ├── camera_shake.gd                    NUEVO  CameraShake (hijo de WorldCamera)
│   └── world_camera.gd                    CAMBIA _place() suma shake.offset() y roll
├── scenes/ui/
│   ├── command_cue/target_probe.gd        CAMBIA hovered + hovered_changed(node)
│   ├── target_info/target_info.gd         NUEVO  TargetInfo (static)
│   ├── target_info/target_info_panel.*    NUEVO  TargetInfoPanel
│   ├── options/feel_prefs.gd              NUEVO  FeelPrefs (data/ui/feel_prefs.tres, [sensacion])
│   └── options/gameplay_tab.*             CAMBIA sacudida, destello, info al pasar el puntero
├── scenes/match/match.tscn                CAMBIA Hud/TargetInfoPanel; Camera/CameraShake
├── scenes/structures/building_type.gd     CAMBIA @export var display_name := ""
├── tools/import/export_stats.py           CAMBIA (053f2, requiere el original) damage_animations
├── tools/bake/bake_body_scenes.gd         CAMBIA (053f2) rol `hit`; (053g) sin `gesture` en los modelos medidos
├── project.godot                          CAMBIA acción debug_hit
├── debug/suite/ bench_building.gd, bench_expect.gd NUEVO; bench_rules.gd, bench_group.gd, target_cases.gd, ai_cases.gd CAMBIA
├── debug/ai/ ai_match.gd CAMBIA; expect_judge.gd NUEVO; f371/f372/f373 escenas
├── debug/units/f370_targets.tscn, f376_idle_truth.tscn, idle_truth_probe.gd
├── debug/rules/f370_*.tres … f376_*.tres
├── debug/ui/f374_target_info.tscn; debug/fx/f375_hit_feel.tscn, f377_fount_exit.tscn
├── agent/flows/f374_target_info.json, f375_hit_feel.json, f376_idle.json
└── agent/runs/run_rfc053.sh               NUEVO  casos sin ventana por corte
```

## 6. Responsabilidades (un dueño por cosa)

| Estado o decisión | Dueño único | Lo leen |
|---|---|---|
| ¿Se puede pelear contra este cuerpo? | `TargetRules.is_valid_foe_of` | `TargetPicker`, `UnitOrders`, `UnitBody`, `SideVision` |
| Blancos inútiles de una criatura | `TargetFutility` (servidor) | `TargetPicker` |
| Umbrales y pesos de la IA | `AiTactics` `.tres` | fases, `FocusTask`, `AiSpellEval` |
| ¿Hay tiro limpio? | `AiLineOfFire` | `AiWizardBrain` |
| Blanco al que la IA se comprometió | `FocusTask` | `AttackPhase`, `CreatureBrain` |
| Qué hay bajo el puntero | `TargetProbe.hovered` | `TargetInfoPanel`, `CursorSkin`, `CommandCue` |
| Texto y vida de un cuerpo para la UI | `TargetInfo` | `TargetInfoPanel` |
| Sacudida de cámara | `CameraShake` | `WorldCamera._place` |
| Preferencias de sensación | `FeelPrefs` | `CameraShake`, `HitFlash`, `TargetInfoPanel` |
| Estado del emisor fuera del árbol | `SpriteEmitter` | `ManafountBody` |

## 7. Resources, nodos y `@export`

- **`AiTactics` (Normal).** Easy y Hard van en §9.
  - Curación: `heal_below_ratio = 0.6`, `heal_min_missing = 100`.
  - Tiro limpio: `los_check = true`, `los_retry_factor = 0.5`.
  - Daño propio: `own_splash_max_ratio = 0.1`, `own_splash_counts_wizard = true`.
  - Pesos de blanco: `npc_passive_weight = 0.0`, `healer_weight = 2.0`, `commit_weight = 1.5`, `commit_hold_s = 6.0`.
  - Foco: `focus_kill_window_s = 20.0`, `focus_power_ratio = 1.2`, `focus_radius_m = 60.0`, `focus_max_members = 6`.
- **Otros Resources.**
  - `ShakeMap`: FX → trauma, más `max_distance_m`.
  - `FeelPrefs`: `shake_scale = 0.5`, `damage_flash = true`, `hover_info = true`.
  - `BenchBuilding`, `BenchExpect` y `BuildingType.display_name`.
- **Nodos.** `TargetFutility`, `HitFlash`, `CameraShake`, `TargetInfoPanel`, `FocusTask`, `ExpectJudge`, `IdleTruthProbe`. Sacar un nodo apaga su comportamiento.
- **`@export` de instancia.**
  - `TargetFutility`: `window_s = 6`, `min_loss_ratio = 0.05`, `ban_s = 15`.
  - `TargetPicker`: `passive_weight = 0.5`, `melee_height_filter = true`.
  - `HitFlash`: `duration_s = 0.12`, `min_fraction = 0.01`.
  - `CameraShake`: `max_offset_m = 0.35`, `max_roll_deg = 1.5`, `decay_per_s = 2.5`, `noise_hz = 18`, `wizard_hit_trauma_per_max = 2.0`.
  - `TargetInfoPanel`: `delay_s = 0.5` (renderer.d:66), `box_units = Vector2(220, 70)`, `cursor_gap_units = 16`.

## 8. Red y determinismo

- **Simulación (053a–053d).** Corre solo en el servidor o en la partida sola, sin RPC nuevas. `TargetFutility` cuenta en ticks de `MatchClock`.
- **Presentación (053e, 053f, 053g).** Corre en todos los pares, sin RPC. Lee `Health.changed` y `FxBus.played`, y el ruido sale de un `FastNoiseLite` con semilla fija. En el dedicado y en headless no se crea nada.
- **Banco** (prueba de humo, regla del proyecto):
  - 053a–053d cambian los digests a propósito. En cada uno se corre `quick` una vez. Si falla solo por ese cambio, se regraba con `agent/run_determinism.sh bless` y se anota una línea con la causa en el F.
  - 053e, 053f y 053h no pueden cambiar ningún digest; si cambia, es un error.
  - 053g: si la sonda obliga a tocar `ChaseState`, se regraba con su línea.

## 9. Cortes (ordenados por lo que más va a notar el usuario)

### 053a: blancos válidos y criaturas que reaccionan (F370)

1. **Diagnóstico.** Imprimir `SideRelations.stance(1|2, 0)` y `(1|2, 3)` en peaks y en Peasantville. En el primer `pick` sobre un `MapBuilding` de vida 0, anotar qué camino lo eligió.
2. **`TargetRules.is_valid_foe_of`.** Devuelve `false` si `Health.maximum <= 0`, se use la postura de bandos o no. Los proyectiles siguen chocando contra la lápida: es física y le pasa igual al jugador.
3. **`TargetPicker`.**
   - Un pasivo (`aggressiveness 0`) pesa `passive_weight` (0,5).
   - Una criatura solo cuerpo a cuerpo no elige blancos por encima de su altura de golpe (`maxTargetHeight`).
4. **`TargetFutility`.**
   - Si el blanco no bajó al menos `min_loss_ratio · maximum` en `window_s`, queda marcado como inútil durante `ban_s`.
   - Una orden ATTACK explícita del jugador ignora la marca.

**Criterios:**
- **`guard_reacts`.** Los 6 eligen al Ranger y le dan al menos un golpe antes de 3 s.
- **`indestructible`.** 0 golpes a cuerpos de máximo 0. El enemigo recibe un golpe antes de 5 s.
- **`futile_stun`.** El atacante suelta al Farmer antes de `window_s + 1` s y le pega al enemigo antes de 10 s.
- **Banco.** Se regraba.

### 053b: la IA elige bien dónde tirar (F371)

1. **`AttackPhase`.** Un NPC pasivo pesa `npc_passive_weight` (0 en Normal). Los Taurocks hostiles siguen contando.
2. **`AiLineOfFire.clear`.**
   - Se lanza un rayo con la forma del proyectil desde la mano hasta el blanco. Si el primer cuerpo que toca no es el blanco, lo bloquea.
   - Los hechizos sin proyectil solo miran el terreno.
3. **Sin tiro limpio.** El mago se acerca hasta la mitad de la distancia (shiny.d:3262).
4. **`own_splash(point, spell)`.** Calcula el daño previsto a los cuerpos propios en el punto real de la explosión. Si alguno pierde más de `own_splash_max_ratio`, el hechizo no se tira.

**Criterios:**
- **`wrath_blocker`.** 0 daño propio y 0 explosiones a menos de 2 m de la lápida. El enemigo recibe un Wrath antes de 20 s.
- **`npc`.** 0 hechizos de ataque sobre Farmers, y al menos 1 sobre el enemigo antes de 15 s.
- **Banco.** Se regraba.

### 053c: disciplina de curación (F372)

1. **`_heal` devuelve 0 si** se cumple cualquiera de estas condiciones:
   - `current/max >= heal_below_ratio`;
   - le falta menos de `heal_min_missing`;
   - el cuerpo está en `SUMMONING`;
   - ya tiene `HealEffect`.
2. **Revalidación.** Antes de lanzar Heal, se vuelve a puntuar la entrada.
3. **Umbral por dificultad.** Easy 0,45, Normal 0,6, Hard 0,7.

**Criterios:**
- El primer Heal va a la criatura al 30 %.
- 0 Heals en 30 s sobre las de 95 % y 100 % o sobre la recién convocada.
- Como mucho 2 Heals en 30 s.
- **Banco.** Se regraba.

### 053d: rematar (F373)

1. **`KillEstimate`.** Tiempo para matar = vida conocida / (DPS de los miembros − curación vista de los curadores enemigos conocidos a menos de 30 m). Sin trampa.
2. **`FocusTask`.**
   - **Candidatos:** enemigos conocidos a menos de `focus_radius_m` de un grupo propio.
   - **Puntaje:** `worth · healer_weight (si cura) · 1/kill_seconds`.
   - **Cuándo se compromete:** si `kill_seconds <= focus_kill_window_s` y la fuerza local supera `focus_power_ratio`.
   - **Qué hace:** reclama hasta `focus_max_members` criaturas y les ordena `attack`.
   - **Cuánto dura:** `commit_hold_s`, o hasta que el blanco muera.
   - **El mago:** `AttackPhase` multiplica el peso de ese blanco por `commit_weight`, así le tira hechizos al mismo.
3. **Valores por dificultad.**
   - Easy: `commit_hold_s` 3, `focus_max_members` 3, `healer_weight` 1.
   - Hard: 8, 8 y 3.

**Criterios:**
- Se mide antes del corte el tiempo hasta matar de hoy. Después, Normal tarda como mucho el 50 % de eso.
- Antes de 10 s, al menos 3 de los 4 Rangers apuntan al mago o a la Charlotte. Si la Charlotte está a menos de 30 m, cae primero.
- Easy tarda más que Normal con la misma semilla.
- **Banco.** Se regraba.

### 053e: panel de información (F374, ventana)

1. **`TargetProbe.hovered`.** Guarda el nodo que está debajo del puntero y emite `hovered_changed`.
2. **`TargetInfo.of`** (como el original, renderer.d:5036-5230). Arma el contenido según qué haya debajo del puntero:
   - Criatura o mago: icono y «<nombre> de <bando>»; un NPC es de «aldea».
   - Edificio: su `display_name`, o «Edificio» si no tiene.
   - Vida: actual/máximo. Si el máximo es 0, no hay barra.
   - Cadáver: «Cadáver de <nombre>».
   - Alma: «Alma». Si es pagana: «Alma pagana / Convertila.»
3. **`TargetInfoPanel`.**
   - **Aparición:** a los `delay_s` de dejar el puntero quieto, junto al cursor. Se recorta para no salirse de la pantalla.
   - **Aspecto:** 220×70 unidades × `HudScale`, fondo negro al 68 %, barra hecha con `stat_health_*`.
   - **Edificio inspeccionado:** con un edificio inspeccionado por clic y nada bajo el puntero, el panel lo muestra fijo abajo a la izquierda. Así se sigue un edificio grande.
4. **Sin cambios:** las barras de las criaturas.

**Criterios:**
- Aparece entre 0,45 y 0,6 s después de quedarse quieto y se va en menos de 0,1 s.
- Los textos son exactos y la barra muestra la vida con un error de ± 0,01.
- `grv3` se ve sin barra.
- El panel queda siempre dentro de la pantalla en 1280×720 y 1920×1080, con el HUD al 100 % y al 150 %.
- **Playtest con ventana.**

### 053f: respuesta del combate (F375, ventana)

1. **`HitFlash`.** Cuando una criatura, un mago o una estructura destructible pierde al menos `min_fraction` de su vida, aparece un destello que se apaga en `duration_s`. El shader sale del catálogo de Godot Shaders, con el link en el encabezado.
2. **`CameraShake`.**
   - **Qué la provoca:** los golpes al mago local, con trauma = daño/máximo · `wizard_hit_trauma_per_max`. También los FX de `ShakeMap` cercanos, que se atenúan con la distancia.
   - **Cuánto mueve:** desplazamiento = trauma² · `max_offset_m` · ruido; el roll es proporcional. Todo se escala con `shake_scale`.
3. **053f2 (opcional, requiere el original).** Agrega el rol `hit` (damageFront). `IdleState` lo reproduce si la criatura recibe daño estando quieta, como mucho 1 vez cada 0,5 s.
4. **Opciones → Jugabilidad.**
   - «Sacudida de cámara»: de 0 a 100 %, 50 % por defecto; 0 la apaga.
   - «Destello de daño».
   - «Info al pasar el puntero».

**Criterios:**
- El destello llega al máximo en el cuadro del golpe y vuelve a 0 en 0,12 s.
- Un golpe del 20 % al mago, con sacudida al 100 %, mueve la cámara 0,35 m como máximo. A los 0,5 s queda por debajo de 0,01 m.
- Con la sacudida al 0 %, la cámara no se mueve.
- En headless no se crea nada.
- `quick` da los mismos digests.
- **Playtest con ventana.**

### 053g: reposo sin caminar en el lugar (F376)

1. **Sonda `IdleTruthProbe`.** Mide tres cosas:
   - (a) segundos con el rol `run` y velocidad menor a 0,2 m/s;
   - (b) ciclos Idle→Chase→Idle sin enemigos a la vista;
   - (c) desplazamiento de la raíz en el clip `gesture` de cada modelo.
2. **Arreglo según lo que mida la sonda.**
   - Si (a) sale en `ChaseState`: mientras gira con paso ≈ 0 por más de 0,2 s, el rol es `idle`.
   - Si (b) es mayor que 0: corregir el estado que suelta el blanco y lo vuelve a tomar.
   - Si (c) supera 0,1 m en algún modelo: el bake deja de poner `gesture` en ese modelo. La lista es editable en el bake.

**Criterios:**
- (a) = 0 y (b) = 0 en `f376_quiet`.
- (a) ≤ 0,2 s en `f376_flyer`.
- (c) ≤ 0,1 m en todos los gestos que queden.
- Con ventana, el usuario mira el campo 60 s y no ve pasos en el lugar.

### 053h: error de los emisores al salir (F377)

`SpriteEmitter.set_active` fuera del árbol guarda `_active` sin tocar `emitting`, y lo aplica en `NOTIFICATION_ENTER_TREE`.

**Criterios:**
- 0 líneas con `get_global_transform` en el log.
- Al liberar solo el Manalith, el manantial vuelve a estar activo.
- `quick` da los mismos digests.

### 053z: cierre (F378)

- **Pruebas automáticas:** `all` y `rules_suite` completos.
- **Partida de 10 min con ventana** contra Normal en peaks, con estos criterios:
  - 0 golpes a cuerpos de máximo 0;
  - 0 daño propio de la IA por hechizos de área;
  - como mucho 1 Heal por minuto con su ejército sano;
  - el remate tarda como mucho el 50 % del tiempo que tardó en la partida del usuario;
  - el panel funciona sobre un edificio grande;
  - la sacudida se puede apagar.

## 10. Riesgos

- **El remate puede sentirse injusto en Normal.** Se ajusta en `tactics_normal.tres`, sin tocar código.
- **El rayo de tiro limpio tiene costo.** Si `AiAudit` sube más de 0,2 ms por tick, el resultado se cachea por blanco durante 6 ticks.
- **La futilidad podría soltar un blanco que se está curando.** Por eso `min_loss_ratio` es bajo (5 %) y la orden explícita del jugador la ignora. `f373` vigila que no pase.
- **053f2 y 053g (c)** dependen del original y de la sonda. Si falta algo, el corte entrega el resto y lo anota.
- **El banco cambia en cuatro cortes.** Un digest que cambia sin causa es un error y no se regraba.
- **Refactor en curso.** 053a–053d tocan `scenes/ai/` y `scenes/units/targeting/`, así que arrancan cuando termine el refactor de llamadas tipadas.

## 11. Fuera de alcance

- Estadísticas en el panel (foesKilled, nivel).
- Hit-stop: la simulación es compartida y determinista.
- Reescribir la IA.
- Diplomacia de los NPC.
- Look.
- Números de daño flotantes (§14).

## 12. Orden de implementación

053h → 053a (incluida la base del banco: `BenchBuilding`, `BenchExpect`, `ExpectJudge`, `--watchdog-s`) → 053b → 053c → 053d → 053e → 053f (y 053f2) → 053g → 053z.

## 13. Cómo lo verifica un humano en el editor

- **053a–053d.** Abrir `debug/units/f370_targets.tscn` o `debug/ai/f37x_*.tscn` con F6 y pulsar Enter para arrancar. Para cambiar de caso, editar `default_rules`. Los umbrales viven en `data/ai/tactics_normal.tres`.
- **053e.** Abrir `debug/ui/f374_target_info.tscn` con F6 y pasar el mouse por encima. En una partida, pasar el puntero sobre el altar enemigo.
- **053f.** Abrir `debug/fx/f375_hit_feel.tscn` con F6 y usar `debug_hit`. Con la sacudida al 0 %, la cámara no se mueve.
- **053g.** Abrir `debug/units/f376_idle_truth.tscn` con F6 y mirar 60 s.
- **053h.** Salir de una partida con el menú de pausa: no aparece `get_global_transform`.

## 14. Contradicciones y preguntas (con recomendación)

1. **Granjeros.** El PRD dice que las criaturas atacan a los NPC al verlos y que la IA no los caza a propósito.
   - **Recomendación:** quedan como blanco con la mitad de prioridad, más la regla de futilidad, y la IA deja de tirarles hechizos.
   - Si el usuario quiere que sus criaturas no les peguen nunca por su cuenta, hace falta un CHANGE-REQUEST: `passive_weight = 0`.
2. **Normal = números del original.** Este RFC cambia el comportamiento de Normal.
   - **Recomendación:** un CHANGE-REQUEST-005 que diga «Normal = números del original + las reglas de sensatez de RFC-053».
3. **Panel: al pasar el puntero o al seleccionar.** **Recomendación:** al pasar el puntero, como el original, y además el edificio inspeccionado, fijo.
4. **Sacudida.** **Recomendación:** 50 % por defecto, ajustable de 0 a 100 %, y solo por golpes a tu mago y explosiones cercanas.
5. **Números de daño flotantes.** **Recomendación:** por ahora no.
6. **Remate en Normal.** **Recomendación:** `commit_hold_s` 6 y `focus_kill_window_s` 20; jugar una partida y ajustar el `.tres`.
7. **Frecuencia del gesto.** **Recomendación:** dejarla en 1 de cada 5 vueltas (el original hace 4 de 5).
8. **Nombres de edificios.** **Recomendación:** «Edificio» como genérico, más un `display_name` editable.

Referencias de sacengine (solo descripción, sin copiar código):
- `state.d`: 7957-7992, 8780-8806, 9091, 12426-12446, 12879.
- `bots/shiny.d`: 3246-3270.
- `renderer.d`: 66 y 5036-5230.
