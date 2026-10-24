# 061f — Zonas (Explosion, Frozen Ground, Demonic Rift, Healing Aura) — plan del corte

Fuentes: `061-spells-master-plan.md` (§1 piezas 1, 2 y 7; fila 061f), `rfcs/research/061R-abilities-structures.md`, `061V-spell-visuals-f-g.md` (el SPEL manda sobre las etiquetas del exe), sacengine (`state.d` 9986-10013, 10960-11116, 19037-19065, 19507-19737, 19739-19899) y `CONVENTIONS.md` (C1-C21 y §2c). Decisión del usuario: arte final desde el inicio. Los hechizos de 061d (`SpellCarrier`) y 061e (`ChainHop`) corren en otros worktrees; este corte no los usa.

Dos correcciones que mandan sobre el plan maestro:
- **Healing Aura la lleva una criatura aliada** (sacengine `HealingAura.target`): es un `Ward` + `BodyAura` de 061b, no una `GroundZone`.
- **Frozen Ground dura 30 s** (dato `zorf.duration`); sacengine fuerza 15 s por decisión propia (sacspell.d:214). Se usa el dato.

## Objetivo
- **Explosion `pxef`** (clic en el suelo): durante el lanzamiento nacen 5 bolas de fuego (el clic y 4 al azar a ≤20 m) que crecen. A los 3,8 s del inicio del lanzamiento estallan: 600 de daño de hechizo con caída lineal en 10 m (`amount·(1−d/10)`), prenden fuego, y lanzan por el aire a todo lo que está a ≤30 m del primer punto (5 a 20 m/s según la distancia al punto más cercano). Interrumpir el lanzamiento achica las bolas y no estalla nada.
- **Frozen Ground `zorf`** (clic en el suelo): una bola de nieve crece junto al mago, vuela 2 s en parábola y cae. En el suelo un anillo de hielo crece en 0,5 s hasta 15 m y **congela** (con los números de Freeze, `zerf`) a todo no aliado que está en tierra dentro del anillo, una vez cada uno. A los 30 s el hielo se rompe en 6 pasos de 5 ticks, del centro hacia afuera, y hace 800 de hechizo (una vez cada uno) a quien siga encima.
- **Demonic Rift `tfir`** (clic en el suelo): una grieta aparece en los pies del mago mientras lanza. Cuando termina suelta un espíritu cada 1/3 s (hasta 24). Cada uno busca al enemigo más cercano a ≤75 m de un punto al azar del disco de 75 m alrededor del clic que aún no tenga espíritu, le pega 500 de hechizo directo, sube en espiral 4 s, se va a un punto al azar a 20 m de altura, vuelve a la grieta y se hunde. Si el espíritu no encuentra criatura, vuela a un punto del suelo (sin daño) y el siguiente espera 1 s. La grieta se cierra cuando se fueron todos.
- **Healing Aura `ruah`** (clic en una criatura aliada o en el propio mago): la criatura la lleva 20 s. Ella y toda criatura **de su bando** a ≤30 m (distancia entre cajas) se curan a 60/s; la cura se renueva cada tick con un temporizador de 256 ticks, así que sigue 4,3 s después de salir del radio.

## Escena de verificación
`res://debug/spells/cast_zones.tscn` (F6), el mismo patrón que `cast_wards.tscn`/`cast_control.tscn`:
- Arma: High Noon, `debug/units/rock_hit.gd` como `Targets`: un Trogg enemigo a 25 m, un Ranger enemigo a 35 m, un Shrike enemigo (volador) a 30 m y un Troll propio a 15 m (para curar). Mago de nivel 6 con maná lleno (`debug/rules/cast_zones.tres`).
- `wizard_god` se elige en el inspector: Pyro (Explosion), Stratos (Frozen Ground), Charnel (Demonic Rift), Persephone (Healing Aura).
- Estado inicial: ninguna zona, nadie curado, el Troll propio con la vida a la mitad.
- Acción: la tecla `spell_N` del hechizo (el número se confirma contra el HUD) y clic: en el suelo (las tres zonas) o sobre el Troll (la aura).

## Árbol de archivos
```
scenes/spells/zones/
  [+] README.md                       What / Not / Talks to / Edit / Check
  [+] ground_zone.gd                  GroundZone extends SpellProjectile (Node3D): reloj, fases CASTING→ARMING→ACTIVE→ENDING, puntos, release()/cancel(); `phase` replicado. ≤150
  [+] zone_pulse.gd                   ZonePulse (Node, hijo de la zona): en qué fase, cuándo y cuántas veces actúa (at_s / steps); busca los cuerpos del alcance. ≤90
  [+] zone_blast.gd                   ZoneBlast extends ZonePulse: salpicadura + fuego + lanzamiento + estallido visual. ≤120
  [+] zone_freeze.gd                  ZoneFreeze extends ZonePulse: congela una vez a cada no aliado en tierra dentro del radio que crece. ≤90
  [+] zone_shatter.gd                 ZoneShatter extends ZonePulse: 6 pasos de anillo, daño una vez a cada cuerpo. ≤90
  [+] zone_rules.gd                   static, RefCounted: fuerza del lanzamiento, radio que crece, anillo del paso, puntos al azar en un disco. ≤90
  [+] zone_balls.gd                   ZoneBalls (Node3D): pone cada bola hija sobre un punto de la zona y la escala con el lanzamiento. ≤80
  [+] fire_ball.tscn                  una bola: 3 capas de la misma esfera con ruido (fire_sphere.gdshader, exeg 4x4, aditivas)
  [+] fire_sphere.gdshader            esfera con ruido y atlas, aditiva; noisy_sphere.gdshaderinc (hash/ruido compartidos)
  [+] explosion_zone.tscn             GroundZone(spell=pxef) ├ Balls(5 FireBall) ├ Blast(ZoneBlast) └ sonidos
  [+] explosion_burst.gd/.tscn        la presentación del estallido que corre FxBus.broadcast_scene: esferas que crecen (exeg), escombros (bold ×0,2), estela firy
  [+] debris_piece.gd/.tscn           un escombro (bold.glb) balístico con rebote; lo instancia explosion_burst
  [+] frozen_ground.tscn              GroundZone(spell=zorf) ├ Snowball(snowball_flight) ├ IcePatch(ice_patch) ├ Freeze(ZoneFreeze) ├ Shatter(ZoneShatter) └ sonidos
  [+] snowball_flight.gd              SnowballFlight (Node3D): la bola sbll crece en la mano y vuela 2 s en parábola con la estela cst0. ≤100
  [+] ice_patch.gd + ice_ground.gdshader   IcePatch: malla de anillo pegada al terreno (TerrainShape), radio e radio interior por shader. ≤110
  [+] demonic_rift.tscn               GroundZone(spell=tfir) ├ Edge(cilindro abierto, rift_edge.gdshader) ├ Swirls(SpriteEmitter rif3) ├ Spirits(RiftSpawner) └ sonidos
  [+] rift_edge.gdshader              el borde de la grieta: atlas 1x8 de rif2, mezcla que oscurece
  [+] rift_spawner.gd                 RiftSpawner (Node): un espíritu cada 1/3 s (hasta 24); elige el blanco; la grieta se cierra al irse el último. ≤110
  [+] rift_spirit.gd + rift_spirit.tscn   RiftSpirit extends SpellProjectile: TARGETING→RISING→MOVING_AWAY→MOVING_BACK→VANISHING; estela de cinta rift. ≤150
scenes/spells/actions/
  [+] zone_action.gd                  ZoneAction extends SpellAction: check (fondos, alcance), started/finish/cancel; spawna la zona por SpellSpawner. ≤110
  [+] explosion_action.tscn, frozen_ground_action.tscn, demonic_rift_action.tscn   (sin script propio; knobs)
  [~] ward_action.gd                  + @export target: SpellTarget (vacío = sobre el mago, como hoy); finish pone el Ward en el cuerpo elegido
  [+] healing_aura_action.tscn        WardAction con target ALLY_OR_SELF
scenes/spells/
  [~] spell_spawner.gd                + 4 clases en `projectiles`: Explosion, FrozenGround, DemonicRift, RiftSpirit
  [~] heal_effect.gd                  + renew(per_frame, frames): el temporizador de la aura (max de los dos, sin sumar)
  [~] README.md
scenes/spells/wards/
  [~] body_aura.gd                    + heal_per_s e include_owner (cura con HealEffect.renew); Affects.OWN_SIDE
  [+] healing_aura.tscn               Ward(ruah) ├ Look(3 capas aura_sphere.gdshader, por dentro) ├ Aura(BodyAura heal 60/s, Reach 30 m) ├ WardEmitter glo2 └ WardSound aura
  [+] aura_sphere.gdshader            esfera con ruido y atlas 4x4 de haur, aditiva, vista desde adentro
scenes/units/[~] unit.tscn            Wards └ HealingAura; sync "Wards/HealingAura:shown"
scenes/wizards/[~] wizard_body.tscn   Wards └ HealingAura + CastColumn (WardEmitter WHILE_CASTING); sync ídem
data/catalog/spells/[~] pxef, zorf, tfir, ruah .tres   action = su escena
data/fx/[+] explosion_blast.tres (xplo 5x5), explosion_blast2.tres (exp2), explosion_ash.tres (frck), explosion_smoke.tres (smok),
            snowball_shards.tres, rift_cast.tres (cfx1), rift_swirl.tres (rif3), healing_aura_cast.tres, healing_aura_rise.tres, healing_aura_glow.tres (glo2)
data/fx/shake_map.tres               + explosion_blast
data/audio/fx_sounds.tres            + explosion_*, frozen_ground_*, rift_*, healing_aura
assets/original/fx/                  exeg, xplo, exp2, frck, smok, fbal, rif2, rif3, rift, haur  (tools/import/import_ui.py, EXTRA_FX)
assets/original/props/               bold, sbll  (tools/import/sac_formats/props.py SPELL_MODELS)
debug/spells/[+] cast_zones.tscn ; debug/rules/[+] cast_zones.tres
debug/suite/[+] zone_cases.gd ; [~] rules_suite.gd
agent/harness/match_shots/[~] match_shots.gd   --cast: los hechizos de zona van al suelo cerca del enemigo + vista `zone` (la zona desde arriba) y reporte de zonas
tools/lint/[~] baseline.txt (solo si algún conteo baja)
```

**Fuera del corte**
- La cicatriz `scar` (quemadura en el suelo) de Explosion: no hay lector de SCAR. Queda sin dibujar.
- Las luces dinámicas del exe (regla del proyecto: el brillo sale de sprites aditivos).
- `ZoneDropper` y `ZoneMover` (061h) y `SpellWall` (061g): no entran.
- El sprite «XS» del exe (`sub_439f10`, NO VERIFICADO): se usa la esfera que sacengine dibuja (crece a 30 m).
- La IA no lanza estas cuatro (`ai_use = NONE`); se confirma que vale 0 y no se rompe.

## Tipo / nodo / instancia
- **Resource de tipo:** el `SpellType` `.tres` de cada hechizo (todos los números: daño, rangos, duración) y el `ParticleType` de cada partícula. `ZonePulse` y compañía leen el `SpellType` por `@export`, no por texto (C18).
- **Nodos:** la zona es una escena por hechizo (`explosion_zone.tscn`, `frozen_ground.tscn`, `demonic_rift.tscn`); sus pulsos, bolas, malla de hielo y emisores son nodos hijos que se mueven con gizmo. `healing_aura.tscn` es un `Ward` más.
- **`@export` de instancia:** tiempos de fase (`arm_s`, `hold_s`, `end_s`, `grow_s`), cantidad de bolas, pasos del anillo, tasa y máximo de espíritus, alturas por `Marker3D`.
- **Dónde se edita un hechizo:** su `.tres` (números) y su escena de zona (cómo se ve y cuándo actúa).

## Dueños y red
- **`GroundZone` es el único dueño del reloj y de la fase** de una zona; los pulsos, las bolas y el hielo la leen y no la escriben. `Wards`/`Ward` siguen siendo el único dueño de «quién lleva la aura».
- **`Frozen` es el único que congela** (la zona llama `Frozen.lay(zerf, slot)`); **`Tumbling.catapult` es el único que lanza**; **`HealEffect` es el único que cura en el tiempo** (la aura le renueva el temporizador); `SplashDamage` es el único que reparte salpicadura.
- Red: `Caster.request_cast` → `submit_cast` → en el host `ZoneAction.started/finish` → `SpellSpawner.spawn_projectile` (la zona es un `SpellProjectile`) → solo el host corre pulsos y espíritus; `phase` (y la posición de cada espíritu) viajan por el `MultiplayerSynchronizer` de la zona; cada par dibuja las bolas, el hielo, el borde y las cintas desde esos datos. Los estallidos van por `FxBus.broadcast`/`broadcast_scene` (un RPC por evento). La aura: `Ward.shown` replicado (`Wards/HealingAura:shown`), como los de 061b.
- Orden de dueños en el tick: la zona avanza antes que sus pulsos (los pulsos son hijos: `process_priority` -1 en la zona y 0 en los pulsos); `Tumbling` y `Frozen` ya corren después del cuerpo.

## Criterios (suite `zone_cases`)
Números medibles; los tests de zona usan una duración corta cuando el dato es larga (30 s) y comprueban el dato aparte.
- **Explosion.**
  - Cinco puntos: el primero es el clic y los otros 4 caen a ≤ `effect_range` (20 m) del clic.
  - Estalla a 228 ticks ± 1 desde el inicio del lanzamiento.
  - Un cuerpo con la caja a 0 m del centro pierde 600 × resistencia ± 1 %; a 5 m de caja, 300 × resistencia.
  - Un cuerpo a 5 m queda en `Tumbling` con |v| = 5 + 17,5·(1 − 5/10) = 13,75 m/s ± 1 % (tope 20) y con componente vertical positiva; uno a 11 m no se lanza.
  - Todo cuerpo dentro del radio de 10 m tiene `Burning`.
  - Interrumpir el lanzamiento: 0 de daño, ningún `Tumbling`, la zona se libera.
- **Frozen Ground.**
  - Aterriza a 120 ticks ± 1 de `finish`.
  - En los 30 ticks siguientes quedan congelados un Trogg a 10 m y uno a 14,9 m; no el de 16 m, no un volador a 5 m, no un aliado, no el mago, no un cuerpo con escudo prendido.
  - La zona dura `ceil(60·zorf.duration)` = 1800 ticks ± 1 desde el aterrizaje y después rompe en 6 pasos, uno cada 5 ticks.
  - Un cuerpo a 3 m recibe 800 × resistencia en el paso 2; uno a 14 m en el paso 6; ninguno recibe dos veces; uno a 20 m no recibe nada.
- **Demonic Rift.**
  - Sin objetivo en 75 m el primer espíritu sale al terminar el lanzamiento y los siguientes a 60 ticks; con objetivos, uno cada 20 ticks ± 1.
  - Con 3 enemigos en 75 m cada uno recibe 500 × resistencia **una vez** (no más) y los espíritus que sobran vuelan al suelo sin dañar.
  - Nunca hay más de 24 espíritus. La zona se libera sola cuando se fue el último, y interrumpir el lanzamiento la cierra.
- **Healing Aura.**
  - Dura 1200 ticks ± 1.
  - Un aliado herido a 20 m de caja gana 60 ± 5 % en 1 s; el portador también; un enemigo a 10 m no gana nada; un aliado a 40 m no gana nada.
  - La cura sigue ≈ 256 ticks después de que el aliado sale del radio.
  - La aura la lleva el cuerpo clicado, no el mago.
  - No cuenta como escudo (Freeze sigue afectando al portador).
- **Hechizos:** los cuatro tienen `action`, la escena no tiene warnings, `ai_use = NONE` y el evaluador de la IA da 0 (no se rompe una partida de IA).
- **Lint:** ningún conteo sube; los scripts nuevos ≤150 líneas.
- **Antes/después visual:** no se verifica sin ventana. El comando de captura queda en el README de la carpeta.

## Orden
1. Importar texturas y mallas (`import_ui`, `import_props`).
2. `GroundZone`, `ZonePulse`, `zone_rules`, `ZoneAction` y el registro en `SpellSpawner` con la caja de la zona sin arte.
3. Explosion (sim) → su suite → su arte (`fire_ball`, ráfaga, partículas, sonidos).
4. Frozen Ground (sim + hielo + bola) → suite → arte.
5. Demonic Rift (zona + espíritus) → suite → arte.
6. Healing Aura (`BodyAura` + `Ward` + `WardAction`) → suite → arte.
7. `cast_zones.tscn`, `match_shots`, READMEs, lint, suite completa.

## Riesgos
- **Sin ventana no se ve nada:** los shaders y las mallas se validan con la carga headless y con los números; la captura con ventana la hace el usuario con el comando del README.
- `SpellSpawner` y `wizard_body.tscn` los tocan también 061d y 061e: el conflicto de merge es una línea en `projectiles`.
- Tamaño (C1): `body_aura.gd` está en 140 líneas; el cura va en un método corto y se quita el resto a `zone_rules`/`heal_effect`.
- **NO VERIFICADO:** el tipo de daño de Healing Aura (cura, no daño); el significado de los números de `FrozenGroundRun` (10; 0,5; 2,5; 5; 1; 0,05); `iXsm` (humo) de la explosión genérica; qué malla dibuja el sprite XS. Por defecto: la forma de sacengine. Knob para cambiarlo: `fire_ball.tscn` (capas), `explosion_burst.tscn` (esferas).
- Healing Aura: sacengine apaga la aura 30 ticks antes del final (`frame+scaleFrames ≥ duration`); acá cura hasta el final del `Ward` y la mirada se achica al apagarse (divergencia de medio segundo declarada).
