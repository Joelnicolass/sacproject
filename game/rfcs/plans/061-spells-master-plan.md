# Plan maestro de hechizos del mago (061b en adelante) — tech lead

Leí 061R completo, `CONVENTIONS.md` (con §2c), RFC-055 §12–§16, el plan 061a y el código real: `caster.gd`, `spell_action.gd`, `aimed_action.gd`, `pups/heal/lightning/thrown/rock_action.gd`, `speedup_effect.gd`, `health.gd`, `afflictions.gd`, `affliction(_type).gd`, `frozen.gd`, `vined.gd`, `life_shield.gd`, `fire_shield.gd`, `timed_state_ability.gd`, `pace_factors.gd`, `ghost_form.gd`, `spell_command.gd`, `ai_spell_eval.gd`, `wizard_brain.gd`, `unit_body.gd`/`idle_state.gd`, y los nodos de `unit.tscn` y `wizard_body.tscn`. Leí también los dos avisos del orquestador: cumplo §2c, los README usan `Check:` en lugar de `Debug:`, y uso escenas de verificación en `debug/<sistema>/` (el usuario volvió a permitirlas en el commit 05622346).

> **Decisiones del usuario (2026-10-24):** plan aprobado. Los hechizos van ya, tomando solo lo mínimo de 055e en cada corte (los 12 existentes no se tocan). Soul Mole se adelanta a 061d y Bombardment entra en 061h con daño y sin abolladuras. **Arte final desde el inicio**. **Cada hechizo ilumina con su color** (2026-10-24): estallidos con `FxLightSpec` en su `ParticleType` (pool `FxLightLayer`), efectos que duran con un `ActorLight` hijo (`ActorLightBudget`); color de la luz del exe si existe, si no el dominante de su textura; sin sombras ni bloom fuerte (no looks provisorios): cada corte trae el look del original (sus texturas/partículas de `assets/original/fx`, modelos con Blender cuando haga falta), verificado contra sacengine/REA y capturas.

## 0. Contradicción entre artefactos (decide el usuario)
RFC-055 §13.1 y §13.4 dicen que no entra contenido nuevo sobre un sistema calcado 1 a 1. Según eso, los 41 hechizos van después de 055e (mago y libro) y de 055f (IA), y hoy los dos son 1 a 1: `SpellType.flags*`, `AimedAction` con herencia de profundidad 2 y una IA que despacha por bits de `flags1`. La prioridad nueva del usuario («todos los poderes del mago») es la instrucción más reciente y manda sobre el orden del RFC.

**Mi propuesta:** cada corte se queda solo con lo mínimo de 055e que necesitan sus hechizos:
- acciones nuevas de profundidad 1 que no heredan de `AimedAction`;
- el blanco como sub-recurso embebido (`SpellTarget`);
- un campo con nombre `ai_use` en lugar de leer bits.

No se tocan los 12 hechizos que ya andan. El resto de 055e y 055f queda para después.

## 1. Piezas genéricas (8)

| # | Pieza | Qué hace | Knobs | Hechizos | Reutiliza o reemplaza |
|---|---|---|---|---|---|
| 1 | `Wards` (único dueño) + `Ward` (hijo) | Escudos y formas temporales de un cuerpo. `Wards` es el único que responde `shielded()`, `factor(kind)` e `immune()`. Lo consultan `Health` y `Afflictions`. | `spell: SpellType`, `factor`, `ranged_factor`, `immune`, `counts_as_shield`, `look: Node3D` (crece y se achica), `health` (termina al morir). `shown` se replica | Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm. Después Halo y Healing Aura | `LifeShield` pasa a ser `extends Ward` (profundidad 1). Se borran `Health.life_shield` y `Afflictions.life_shield`. Así se cierra la deuda de RFC-030: hasta hoy solo Life Shield cuenta como escudo |
| 2 | `BodyAura` | Lo que un cuerpo le hace a los que tiene cerca mientras su `Ward` está prendido: daño continuo, robo de vida, empuje o cura | `ward`, `body`, `reach` (Area3D con monitoring apagado y forma con gizmo, como `ManaSource` en 061a), `damage_per_s`, `damage_kind`, `pierce_shield`, `mods` (IGNITE), `affects` (ENEMIES / NOT_OWN / ALLIES), `heal_owner_fraction`, `push_force` | Fireform, Protective Swarm, Air Shield (empuje). Healing Aura (061f) | El recorte por cajas de `fire_shield.gd`, más `BodyNudge.push`. Más adelante el Phoenix puede migrar a esta pieza (no entra en estos cortes) |
| 3 | `SpellTarget` (Resource embebido) + acciones `WardAction` y `AfflictAction` | El blanco de un hechizo como dato, no como subclase. Una acción genérica por familia | `who` (SELF / ALLY_OR_SELF / ENEMY), `ground_only`, `refuse_cc_protected`. `AfflictAction.affliction: AfflictionType` | Los 9 de 061b y 061c; después todos los de un solo blanco | Reemplaza el patrón `resolve_target` de `AimedAction` en lo nuevo. Se agrega `SpellAction.Pick.SELF` |
| 4 | `SpellAffliction` (`extends Affliction`) | Estado temporal con knobs, con el bit y la replicación que ya tiene `Afflictions` | modo de duración (fija o `cc_ticks` por vida), `max_stacks`, `pace_per_stack`, daño por segundo (tipo, pierce), `resistance_bonus_per_stack`, `attack_time_per_stack`, `accuracy_per_stack`, `look` | Rings of Fire, Slime. Después Blind Rage y la hinchazón de Intestinal Vaporization | `Afflictions`, `PaceFactors`, `Affliction.cc_ticks`, `StoneLook` (tinte) |
| 5 | `ChainHop` | Golpe que salta al siguiente blanco con un radio que se achica, (6−n)/6 × alcance | `hits`, `effect` (daño o cura completa), `allies`, `beam` | Chain Lightning (7), Rainbow (6), los saltos de Dragonfire | `LightningAction`, `HealEffect` |
| 6 | `SpellCarrier` (escena) | Algo que viaja (guiado, caminando o cayendo) y al llegar dispara su hijo `OnArrive` | `motion`, `speed`, `on_arrive` (hijo intercambiable: afectar, gibear, cambiar de bando, traer el alma) | Soul Mole, Soul Wind, Dragonfire, Halo, Charm, Blind Rage, Intestinal Vaporization, Bovine Intervention, Death | `spell_projectile.gd`, `SpellSpawner`, `rend_soul.gd` |
| 7 | `GroundZone` (escena) + hijos `ZonePulse`, `ZoneDropper`, `ZoneMover` | Área en el suelo con duración. Sus hijos pulsan un efecto, sueltan escenas a una tasa o mueven la zona | `duration`, `Reach` (forma), tasa, altura de la nube como `Marker3D`, escena que suelta | Explosion, Frozen Ground, Demonic Rift, Healing Aura, Rain of Frogs/Fire, Plague, Cloudkill, Bombardment, Meanstalks, Tornado | `splash_damage.gd`, `death_clouds/*`, `poisoning.gd`, `clinging.gd` |
| 8 | `SpellWall` + hijo `WallTouch` | Muro perpendicular a la línea mago→clic, que crece hasta 55 m por lado. `WallTouch` aplica su efecto al que cruza | largo, alto y espesor como forma, `grow_s`, `duration`, enfriamiento por blanco, efecto | Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence | `burning`, `stunned`, `vined`, `mana_pool`, `fx/spike_field.gd` |

Para la IA no hay script nuevo: `SpellType` gana `enum AiUse { NONE, SELF_GUARD, DISABLE_FOE, … }` y `ai_spell_eval.rating_fn` lo lee antes de los bits.

## 2. Plan de cortes

Cada corte se puede jugar al cerrar. Cada uno lleva suite, un caso de IA (como mínimo, que no rompa) y una captura con `match_shots --cast=<tag>`.

| Corte | Hechizos | Piezas nuevas | Criterio de aceptación (resumen) |
|---|---|---|---|
| 061a | Shrine (en curso, no se replanea) | — | — |
| **061b** escudos de nivel 2 | Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm | 1, 2, 3 (`WardAction`), `Pick.SELF`, `ai_use` | Los factores verificados con REA se cumplen. Los cinco cuentan como `shielded`. La IA los lanza bajo amenaza |
| **061c** control sobre un blanco + Troll | Freeze, Grasping Vines, Rings of Fire, Slime | 3 (`AfflictAction`), 4 | Duraciones con `cc_ticks` y números de 061R. Un cuerpo `ccProtected` los rechaza. El Troll regenera 29,2/s en cualquier estado |
| 061d almas | Soul Mole (nv 3), Animate Dead (4), Soul Wind (5) | 6 | El alma llega al mago en 9 s ± 1 tick. Aturde a ≤10 m (Soul Mole) y a ≤30 m con 400 una sola vez (Soul Wind). Revive en `reviveTime` |
| 061e saltos y dirigidos | Chain Lightning, Rainbow, Dragonfire, Halo of Earth | 5 (y 6 para Dragonfire y Halo) | 7 golpes de 600 con radios de 50 m, 41,7 m, … ; 6 curas completas ; Dragonfire encadena 5 blancos ; Halo 6 rocas de 600 a ≤50 m |
| 061f zonas | Explosion, Frozen Ground, Demonic Rift, Healing Aura | 7 (`ZonePulse`) + 2 | 5 estallidos de 600 a los 3,8 s ; congela a ≤15 m y rompe con 800 a los 30 s ; 24 espíritus de 500 ; 60/s a ≤30 m durante 20 s |
| 061g muros | Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence | 8 | 55 m por lado, cortado por edificios ; Firewall 625/s × rampa de 3 s ; pinchos 625 + aturdir + ×0,5 ; drenaje total de maná ; Vines por cruce ; postes 625 a ≤10 m |
| 061h nubes | Rain of Frogs, Rain of Fire, Plague, Cloudkill, Bombardment (sin abolladuras) | 7 (`ZoneDropper`, `ZoneMover`) | Tasas por segundo, radio 50 m y 20 s. Cloudkill a 22 m, ≈2 rayos/s de 900, persigue al blanco |
| 061i nivel 8 sobre un blanco | Charm, Blind Rage, Intestinal Vaporization, Bovine Intervention, Death | 6 + 4. Se agrega `SpellType.count` (`amount3`) | Cambio de bando permanente ; 30 s de furia en 30 m ; gibeo con el alma en el suelo ; Death mata 8 o dura 40 s, nunca a magos |
| 061j | Meanstalks, Tornado | 7 | 4 tallos de 500 con catapulta ; tornado de 25 s que lanza a ≤30 m |
| 061k terreno (RFC-057) | Erupt, Volcano, Bore, las abolladuras de Bombardment | `TerrainShape` | Deformación sincronizada (suelo, colisión, navmesh) |

Me aparté de 061R §5 en dos puntos:
- **Soul Mole va en 061d** porque es nivel 3 y en High Noon está disponible desde el arranque.
- **Halo va en 061e** porque comparte el portador de las rocas.

## 3. Árboles detallados

### 061b — Escudos de nivel 2 (Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm)

**Objetivo**
- El mago se lanza su hechizo de nivel 2 sobre sí mismo al pulsar la tecla, sin clic.
- Factores de daño: Skin of Stone ×0,25 ; Air Shield ×0,5, y ×0,25 contra daño a distancia ; Ethereal ×0 (también contra pierce) ; Fireform ×1 ; Protective Swarm ×0,75.
- Duraciones: 80, 60, 15, 40 y 40 s. Terminan al morir.
- Fireform quema 250/s con pierce a los no aliados a ≤5 m de la caja. Protective Swarm pica 75/s a ≤4 m y cura al mago el 50 % de lo que inflige. Air Shield aparta a los que no son propios a ≤5 m con fuerza 20.
- Los cinco cuentan como `shielded`: protegen de Freeze, Petrify y Web/Cage pull. Life Shield sigue igual.

**Escena de verificación:** `res://debug/spells/cast_wards.tscn`
- Arma: el mundo de High Noon, `debug/units/rock_hit.gd` como `Targets` (el mismo patrón que `cast_pyro.tscn`), un Trogg enemigo a 3 m y un Ranger enemigo a 25 m.
- Reglas: `debug/rules/cast_wards.tres`, otra instancia de las mismas reglas del debug, con mago de nivel 3 y maná lleno.
- `wizard_god` se elige en el inspector.
- Estado inicial: ningún escudo prendido.
- Acción: `spell_N` del InputMap, la tecla del hechizo de nivel 2 en el libro. El developer confirma N contra el HUD.

```
scenes/spells/
  [~] README.md                          Check: rules_suite ward_cases · match_shots --cast=niks|dlhs|mrfe|mrff|rwsp
  wards/
    [+] README.md                        What / Not / Talks to / Edit / Check
    [+] wards.gd                         Wards (Node): shielded(), factor(kind), immune(), ward_for(spell); static of(body). ≤90
    [+] ward.gd                          Ward (Node3D): start_for(spell)/stop/is_on; `shown` replicado; signal shown_changed(on); look crece y se achica (sale de LifeShield). ≤130
    [+] body_aura.gd                     BodyAura (Node3D): solo autoridad, consulta por cajas a ≤ radio de Reach. ≤140
    [+] skin_of_stone.tscn               Ward(spell=niks, factor .25) └ Look (caparazón de piedra provisorio)
    [+] air_shield.tscn                  Ward(dlhs, .5, ranged .5) ├ Look (shield_bubble) └ Aura(push 20, Reach r 5, affects NOT_OWN, daño 0)
    [+] ethereal_form.tscn               Ward(mrfe, immune) (el look es la conexión con GhostForm, ver wizard_body)
    [+] fireform.tscn                    Ward(mrff, factor 1) ├ Look (GPUParticles3D aditivas) └ Aura(250/s, pierce, IGNITE, Reach 5, ENEMIES)
    [+] protective_swarm.tscn            Ward(rwsp, .75) ├ Look (partículas) └ Aura(75/s, Reach 4, heal_owner .5)
  actions/
    [+] ward_action.gd                   WardAction extends SpellAction: pick SELF; check = funds + ward_for(spell) que no esté prendido; finish → ward.start_for. ≤50
    [+] ward_action.tscn                 una sola escena para los 5 (se instancia desde SpellType.action, RFC-041)
    [~] spell_action.gd                  + Pick.SELF
  [~] spell_type.gd                      + enum AiUse, @export ai_use
scenes/orders/command/[~] spell_command.gd   arm_spell: si pick == SELF, request_cast(tag, posición del mago, mago) en el momento
scenes/components/[~] health.gd          life_shield → @export wards: Wards; shield_factor(kind); _can_be_damaged() pregunta wards.immune()
scenes/units/afflictions/[~] afflictions.gd  life_shield → wards; cc_protected() usa wards.shielded()
scenes/units/passives/[~] life_shield.gd     extends Ward (conserva start_for(ability)); of() → "Wards/LifeShield"
scenes/units/abilities/[~] pull.gd            el blanco «shielded» se consulta con Wards.of(target).shielded()
scenes/units/[~] unit.tscn               Wards └ LifeShield; Health.wards, Afflictions.wards; sync "Wards/LifeShield:shown"
scenes/units/[~] README.md               Debug: → Check:
scenes/wizards/[~] wizard_body.tscn      + Wards └ SkinOfStone, AirShield, EtherealForm, Fireform, ProtectiveSwarm (instancias)
                                         Health.wards, Afflictions.wards; sync de los 5 :shown
                                         conexión en la escena EtherealForm.shown_changed → GhostForm.set_ethereal
scenes/wizards/[~] ghost_form.gd         + set_ethereal(on): GhostForm sigue siendo el único que escribe la transparencia del mago (ALIVE = ethereal ? 0,64 : 0, en 30 cuadros)
data/catalog/spells/[~] niks, dlhs, mrfe, mrff, rwsp .tres   action = ward_action.tscn, ai_use = SELF_GUARD
scenes/ai/brains/[~] ai_spell_eval.gd    rating_fn: ai_use primero; FN_GUARD solo con blanco == lanzador, sin escudo prendido y con amenaza
data/ai/[~] tactics_easy/normal/hard.tres  guard_threat_m, guard_min_foes (knobs de AiTactics)
scenes/ai/[~] ai_tactics.gd              los dos knobs
debug/spells/[+] cast_wards.tscn ; debug/rules/[+] cast_wards.tres
debug/suite/[+] ward_cases.gd ; [~] rules_suite.gd (lo registra)
agent/harness/match_shots/[~] match_shots.gd   --cast=<tag>[,…] (el mago local lanza después de --after; blanco: él mismo o el enemigo más cercano) + vista wizard_close
tools/lint/[~] baseline.txt
```

**Tipo / nodo / instancia**
- **Resource de tipo:** el `SpellType` `.tres` (números) y el `SpellTarget` embebido.
- **Nodos:** `Wards`, cada `Ward` y su `BodyAura`, que viven en `wizard_body.tscn`.
- **`@export` de instancia:** factor, radio de `Reach`, fuerza, look.
- **Dónde se edita un hechizo:** su `.tres` y su escena de escudo.

**Dueños y red**
- `Wards` es el único dueño de «protegido y por cuánto».
- `GhostForm` es el único que escribe la transparencia del mago.
- `PaceFactors` no cambia.
- Red: `Caster.request_cast` → `submit_cast` → en el host `WardAction.finish` → `Ward.start` → `shown` viaja por el `MultiplayerSynchronizer` del mago → cada peer dibuja el look. El aura y el daño corren solo en el host.

**Criterios (suite `ward_cases`)**
- Un golpe de 1000 de hechizo directo al mago deja 250, 500, 0, 1000 y 750 según el escudo. Un golpe de 1000 a distancia con Air Shield deja 250. Un golpe con pierce bajo Ethereal deja 0.
- Duración en ticks = `duration` × 60 ± 1. Al morir, `shown` pasa a falso.
- Fireform: un Trogg con 0,5 m de distancia entre cajas pierde 2500 ± 1 % en 10 s, incluso con Life Shield. Un aliado no pierde nada.
- Protective Swarm: el enemigo pierde 75/s y el mago se cura 37,5/s.
- Air Shield: un enemigo a 3 m queda a más de 5 m en ≤ 1 s. Una unidad propia no se mueve.
- Con cualquier escudo prendido, Freeze, Petrify y Pull rechazan al mago.
- Los casos existentes de Life Shield, Protector y Pull siguen verdes.
- IA: un mago de la IA con 2 enemigos a ≤ `guard_threat_m` lanza su hechizo de nivel 2 en ≤ 5 s. Sin amenaza no lo lanza.
- El lint no sube.

Con ventana: captura en la partida real de High Noon con `--cast` para cada dios, antes y después.

**Orden:** `Ward`/`Wards` y migrar `LifeShield` (suite verde) → `Health`/`Afflictions` → `Pick.SELF` y `WardAction` → las 5 escenas y `wizard_body` → `GhostForm` → IA → suite, debug y captura.

### 061c — Control sobre un blanco (Freeze, Grasping Vines, Rings of Fire, Slime) + regeneración del Troll

**Objetivo**
- Freeze: dura 20·1000/vida s (5 s sobre un mago). Al deshelar hace 150.
- Grasping Vines: 40·1000/vida s (10 s sobre un mago). No se puede lanzar sobre un volador.
- Rings of Fire: 10 s fijos (`ceil(60·10)`, SAC 10741) a 95/s con pierce. Sin regeneración y con `ccProtected` mientras dura.
- Slime: 30·1000/vida s (7,5 s sobre un mago). Por capa: velocidad en tierra 0,2ⁿ, ataques 5ⁿ veces más lentos, precisión 0,2ⁿ y +0,2 de resistencia. Sin regeneración.
- Los cuatro rechazan un blanco `ccProtected`.
- Troll: regenera 29,2/s en cualquier estado, también recibiendo golpes.

**Escena de verificación:** `res://debug/spells/cast_control.tscn`
- Arma: High Noon y `rock_hit.gd`, con un Trogg enemigo a 40 m, un Shrike enemigo (volador), un Druid enemigo con Life Shield y un Troll propio.
- Reglas: `debug/rules/cast_control.tres` (nivel 3).
- Estado inicial: nadie afectado.
- Acción: `spell_N` y después clic sobre el blanco.

```
scenes/units/afflictions/
  [+] spell_affliction.gd                SpellAffliction extends Affliction: lay(spell, slot), relojes por capa (como Vined), dar el pace por capa, daño continuo, look por el bit. ≤150
  [~] affliction.gd                      + lay(spell, slot) -> bool (por defecto inflict). La usa un hechizo
  [~] frozen.gd                          lay → freeze() (el hechizo no pasa por el enfriamiento del Yeti)
  [~] afflictions.gd                     + child_for(type) (comparación tipada) y stat_factor(stat) (ATTACK_TIME / ACCURACY / RESISTANCE_BONUS, derivado)
  [~] README (del sistema)               Check:
  [+] rings_of_fire_look.tscn            3 TorusMesh con material aditivo + AnimationPlayer (provisorio)
data/afflictions/[+] rings_of_fire.tres (bit 9, cc_protects, blocks_regeneration, coexists, holds false)
                 [+] slimed.tres (bit 10, ídem + has_look con tinte verde brillante)
scenes/units/[~] unit.tscn ; scenes/wizards/[~] wizard_body.tscn   + Afflictions/RingsOfFire y Afflictions/Slimed (SpellAffliction con knobs)
scenes/spells/
  [+] spell_target.gd                    SpellTarget (Resource): who, ground_only, refuse_cc_protected; pick(wizard, picked) -> Node3D. ≤60
  actions/[+] afflict_action.gd          AfflictAction extends SpellAction: @export affliction, target (embebido); check (funds, blanco, alcance); finish → Afflictions.child_for(type).lay(spell, slot). ≤60
  actions/[+] freeze_action.tscn, grasping_vines_action.tscn, rings_of_fire_action.tscn, slime_action.tscn   (sin script propio; knobs)
data/catalog/spells/[~] zerf, eniv, rapf, htel .tres   action = su escena, ai_use = DISABLE_FOE
scenes/components/[~] health.gd          resistencia + afflictions.stat_factor(RESISTANCE_BONUS)
scenes/units/attacks/[~] melee_attack.gd, ranged_attack.gd   enfriamiento × ATTACK_TIME, precisión × ACCURACY
scenes/units/[~] creature_type.gd        + @export regenerates_always := false
data/catalog/creatures/[~] lort.tres     regenerates_always = true
scenes/units/[~] unit_body.gd            un solo llamador de regenerate(): _physics_process, si current_state().regenerates() o type.regenerates_always (este último sin la pausa por daño)
scenes/units/states/[~] idle_state.gd, cower_state.gd, rock_form_state.gd   regenerates() → true (sacan su llamada directa)
scenes/ai/brains/[~] ai_spell_eval.gd    FN_DISABLE: blanco enemigo vivo, sin ccProtected ni el estado ya puesto; vale sort_key × min(1, s_cc / tactics.disable_ref_s)
data/ai/[~] tactics_*.tres ; scenes/ai/[~] ai_tactics.gd   disable_ref_s
debug/spells/[+] cast_control.tscn ; debug/rules/[+] cast_control.tres
debug/suite/[+] control_cases.gd ; [~] rules_suite.gd
```

**Dueños y red**
- `Afflictions` sigue siendo el único dueño de los bits y de las preguntas al cuerpo.
- `PaceFactors` es el único dueño de la velocidad: Slime le da su factor con la fuente `&"slimed"`.
- `UnitBody` es el único que llama a la regeneración.
- Red: el host aplica. El bit `shown`, que ya se replica, prende el look en cada peer.

**Criterios (suite `control_cases`)**
- Freeze sobre un Trogg: `ceil(60·1000/vida·20)` ± 1 tick. Sobre un mago: 300 ticks. Al deshelar: 150 de hechizo directo.
- Vines: `ceil(60·1000/vida·40)`, 600 ticks sobre un mago y velocidad xz 0. Sobre un Shrike: `BAD_TARGET`.
- Rings: 600 ticks, 950 ± 1 % de daño contra un cuerpo con Life Shield, regeneración 0 y un Freeze posterior rechazado.
- Slime: con 1 capa la velocidad es ×0,2 ; con 2 capas ×0,04 ; resistencia +0,2 por capa ; enfriamiento cuerpo a cuerpo ×5 ; precisión a distancia ×0,2.
- Druid con Life Shield o mago con Skin of Stone: los 4 rechazan.
- Troll en Chase durante 10 s: +292 ± 1 %. Una criatura sin la marca, en Chase: +0.
- IA: un mago de Stratos de nivel 3 lanza Freeze sobre la criatura enemiga más valiosa en ≤ 5 s y nunca sobre una `ccProtected`.
- `late_join`: el cliente ve los anillos.
- El lint no sube.

Con ventana: captura con `--cast=rapf` y `--cast=htel`.

**Orden:** `SpellTarget` y `AfflictAction` con Freeze y Vines (estados que ya existen) → `SpellAffliction`, Rings y Slime → los ganchos de ataque y resistencia → el Troll → IA → suite, debug y captura.

## 4. IA
- **Mínimo, ya cumplido hoy:** con `flags1` 0x410 y 0x820, los hechizos nuevos dan `FN_NONE` y valen 0. La IA no los elige y no se rompe. Cada corte agrega un caso de suite que lo confirma para los hechizos todavía sin `ai_use`.
- **Ideal:** la IA los lanza desde el corte en que entran:
  - 061b `SELF_GUARD`: entra por la fase de apoyo, porque `SUPPORT_MASK` ya acepta 0x0400.
  - 061c `DISABLE_FOE`: entra por la fase de ataque, porque `ATTACK_MASK` ya acepta 0x0800.
  - 061d en adelante: un valor de `AiUse` por familia (traer almas, zona, muro, nivel 8).
- 055f absorbe todo esto después.

## 5. Riesgos
- La migración de `LifeShield` a `Wards` toca `Health`, `Afflictions`, `pull`, `protector` y `life_shield_ability`, es decir, a todas las unidades. Mitigación: es el primer paso de 061b y no se sigue hasta que la suite esté verde.
- Tamaño de scripts (C1): `afflictions.gd` tiene 266 líneas y `health.gd` 274. La cuenta por tipo de daño se pone en `Wards` y los números de estado en un único `stat_factor`, para no pasar de 300.
- El tipo de daño de Fireform y Protective Swarm sale del SPEL `+0x48`, que no está exportado (`spell_type: 4` es otra cosa). Queda **NO VERIFICADO**: se lee con REA o del WAD al implementar; no se inventa.
- La distancia entre cajas del aura se aproxima con la forma de `Reach` (divergencia declarada, igual que `ManaSource` en 061a).
- 5 propiedades replicadas más por mago.
- La suite vive en `debug/suite/`. Si se borra `debug/`, hay que moverla antes.

## 6. Preguntas al usuario
1. ¿Hacemos los hechizos ya, absorbiendo solo lo mínimo de 055e en cada corte, en lugar de esperar a 055e y 055f como dice RFC-055 §13? **Recomiendo que sí.**
2. ¿Adelantamos Soul Mole (nivel 3) a 061d, y Bombardment con daño pero sin abolladuras a 061h? **Recomiendo que sí.** Erupt queda para el final, porque lo que lo define es el suelo que se deforma.
3. ¿Looks provisorios (burbuja, partículas aditivas, mallas simples) hasta cerrar el libro, y los modelos con Blender (vaca, Muerte, dragón de fuego) en una pasada aparte con referencias? **Recomiendo que sí.**

Archivos clave:
- game/rfcs/research/061R-abilities-structures.md
- game/rfcs/plans/061a-shrine-plan.md
- game/CONVENTIONS.md
- game/scenes/spells/caster.gd
- game/scenes/spells/actions/spell_action.gd
- game/scenes/components/health.gd
- game/scenes/units/afflictions/afflictions.gd
- game/scenes/units/passives/life_shield.gd
- game/scenes/wizards/wizard_body.tscn
- game/scenes/wizards/ghost_form.gd
- game/scenes/orders/command/spell_command.gd
- game/scenes/ai/brains/ai_spell_eval.gd
- game/scenes/units/unit_body.gd
