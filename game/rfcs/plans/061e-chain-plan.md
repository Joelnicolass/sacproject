# 061e — Saltos y dirigidos (Chain Lightning, Rainbow, Dragonfire, Halo of Earth) — plan del developer

Escrito antes de codear, en el formato de 061b/061c del plan maestro (`061-spells-master-plan.md`, §1 piezas 5 y 6; §2 fila 061e). Números: `research/061R-abilities-structures.md` (REA manda: los topes son constantes del código, no `amount3`). Arte: `research/061V-spell-visuals-d-e.md` (versión SPEL; el SPEL manda). Decisión del usuario: **arte final desde el inicio**.

## Objetivo (lo que el jugador ve y mide)

- **Chain Lightning** (`ntlc`, Stratos, 800 de maná, 2,0 s): un rayo sale de las manos al blanco y salta cada 20 ticks al no aliado vivo más cercano que no haya sido golpeado. **7 golpes** de 600 (el inicial y 6 saltos). Antes del salto n (n = 0 a 5) busca a (6−n)/6 × 50 m: 50 m, 41,7 m, 33,3 m, 25 m, 16,7 m, 8,3 m. Cada golpe daña a los 12 ticks de su rayo. Sin blanco, el salto cae en un punto al azar y el rayo se ve igual. `damage_range` = 0 en el SPEL: sin salpicadura.
- **Rainbow** (`wobr`, Persephone, 300 de maná, 0,37 s): un arco en semicírculo vertical sale de las manos a un aliado (o al mago) y salta de aliado en aliado. **6 golpes** (el inicial y 5 saltos). Cada arco tarda 64 ticks en llegar; al llegar **cura toda la vida máxima** del blanco con `HealEffect` (la misma cura en el tiempo y la misma tasa que Heal) y suelta 128 destellos `prbw`. El siguiente blanco es el aliado vivo de menor fracción de vida a ≤ (6−n)/6 × 50 m que no haya sido curado.
- **Dragonfire** (`rifd`, Pyro, 800 de maná, 2,35 s): un dragón de fuego (`dfir`, 5 cuadros) nace junto al mago, sube en espiral durante el lanzamiento (una vuelta, hasta 4 m sobre la cabeza) y al terminar vuela a 18 m/s, girando hasta π rad/s, a ≥1 m del suelo. Quema a 175/s (700 × 0,25, ignora escudos) lo que su caja de 5 m atraviesa. Al llegar al blanco: 700 de daño con salpicadura de 5 m (con `IGNITE`) y todo lo alcanzado arde 1 s. Después busca el no aliado más cercano a ≤50 m (sin achicar) que no haya golpeado: **5 blancos** en total. Si no hay, vuela a un punto al azar a 25 m y, al segundo fallo, se achica a 0 en 1 s.
- **Halo of Earth** (`olah`, James, 1000 de maná, 2,47 s): sobre el mago. **6 rocas `roks`** salen escalonadas mientras se lanza: la roca n aparece cuando `floor((progreso + 0,1) × 6)` llega a n. Orbitan 3 m sobre su cabeza (disco de 2 m) y, ya lanzado el hechizo, cada una busca al enemigo más cercano a ≤50 m y se lanza (30 m/s, aceleración 3): 600 de daño directo al explotar, sobre el cuerpo, el suelo o a los 35 s. Un halo vivo rechaza otro (BAD_TARGET, como los escudos).

## Escena de verificación

`res://debug/spells/cast_chain.tscn` (F6), el mismo patrón que `cast_wards.tscn`: High Noon + `debug/units/rock_hit.gd` como `Targets`.
- Arma: 9 Trogg enemigos en una fila de 6 m, el primero a 20 m del mago (la cadena entra entera), 7 Trogg aliados con 100 de vida en un corro de 5 m a 12 m (Rainbow), y 2 Trogg enemigos a 60 m (fuera de alcance).
- Reglas: `debug/rules/cast_chain.tres` (mago de nivel 5, maná lleno, sin recarga extra).
- Estado inicial: el mago de `wizard_god` (en el inspector; Stratos por defecto) con su libro; ningún hechizo lanzado.
- Acción: la tecla del hechizo de nivel 4 del dios (`spell_N`) y clic en el Trogg; con Persephone el clic va a un aliado; con James la tecla del nivel 5 lanza el halo sobre sí.
- Resultado que se ve: ver los criterios.

## Piezas

| Pieza | Qué es | Dueño de |
|---|---|---|
| `ChainHop` (`extends SpellLaunch`) | La cadena: lista de golpeados, el radio que se achica, el próximo blanco (más cercano, o de menor fracción de vida) y el reloj de los saltos (`hop_s`). Llama a su `ChainEffect` | «a quién le toca ahora» |
| `ChainEffect` (+ `ChainStrike`, `ChainHeal`) | Qué pasa en cada salto: un `LightningStrike` (daño a los 12 ticks) o el arco y la cura completa | el efecto de un salto |
| `SpellLaunch` (`extends Node3D`) | Contrato mínimo de «lo que un hechizo pone en el mundo mientras se lanza y suelta al terminar»: `begin_cast`, `release`, `abort` | nada de lógica |
| `LaunchAction` (`extends SpellAction`) | Una acción para Chain Lightning, Rainbow y Halo: valida el blanco con un `SpellTarget`, instancia su `launch` en el contenedor de disparos al empezar, lo suelta al terminar, lo aborta si se corta | el flujo de lanzar |
| `CarrierAction` (`extends SpellAction`) | Lo mismo para algo replicado que vuela (el dragón): lo crea por el `SpellSpawner` al empezar y lo suelta al terminar | el flujo de lanzar un portador |
| `SpellCarrier` (`extends SpellProjectile`) | Portador guiado: sigue al blanco con giro limitado, a `speed`, y al llegar dispara su hijo `OnArrive`. **Mínimo compatible con el plan maestro §1 pieza 6** (solo `Motion.GUIDED`; 061d agrega WALK y FALL) | el vuelo |
| `DragonArrive` (`extends CarrierArrive`) | El efecto de llegada del dragón: 700 + salpicadura + fuego y pasar al próximo blanco con su `ChainHop` | lo que pasa al llegar |
| `HaloOfEarth` (existente, del Rhinok) | Pasa a `extends SpellLaunch`; sirve también al mago: toma los números del `SpellType`, saca las rocas escalonadas durante el lanzamiento y empieza a buscar al soltarse | las 6 rocas |
| `SpellTarget` (Resource) | El blanco como dato (`who`, `ground_only`, `refuse_cc_protected`). **Mínimo compatible con el plan maestro §1 pieza 3** | quién es un blanco válido |
| `BeamType.path = ARC` | Camino curvo del `BeamFx` (semicírculo vertical) para el arco de Rainbow | el trazo |

## Árbol de archivos

```
scenes/spells/
  [~] README.md                          + Check: de 061e
  [+] spell_target.gd                    SpellTarget (Resource): who SELF/ALLY_OR_SELF/ENEMY, ground_only, refuse_cc_protected; pick(wizard, picked) -> Node3D. ≤60. (mínimo compatible con 061c)
  [+] spell_launch.gd                    SpellLaunch (Node3D): begin_cast(wizard, spell, target, point, cast_ticks), release(), abort(). ≤40
  [~] spell_spawner.gd                   spawn_projectile devuelve el nodo (null en un cliente); + "Dragonfire"
  chain/
    [+] README.md                        What / Not / Talks to / Edit / Check
    [+] chain_hop.gd                     ChainHop extends SpellLaunch. Knobs: hits, hop_s, shrink_steps (6; 0 = fijo), allies, pick (CLOSEST / LOWEST_HEALTH_FRACTION), effect: ChainEffect. static radius(n). ≤150
    [+] chain_effect.gd                  ChainEffect (Node): hop(chain, from, body, point) y land(chain, body, point), vacíos. ≤30
    [+] chain_strike.gd                  ChainStrike extends ChainEffect: hop → LightningStrike.launch(scene, sin retarget). ≤50
    [+] chain_heal.gd                    ChainHeal extends ChainEffect: hop → broadcast_beam(arco); land → HealEffect.heal_full + estallido prbw. ≤60
    [+] chain_lightning.tscn             ChainHop(hits 7, hop_s 20/60, shrink 6, enemigos, closest) └ Effect (ChainStrike, strike_scene = lightning_strike.tscn)
    [+] rainbow.tscn                     ChainHop(hits 6, hop_s 64/60, shrink 6, aliados, lowest) └ Effect (ChainHeal)
    [+] cast_bolts.gd/.tscn              CastBolts (Node3D, cada peer): mientras Caster.cast_fx_shown == `cast_type`, 1/2 por tick un rayito vertical de 1,5-3,25 m desde un punto de la caja ×1,5. ≤50
    [+] cast_glow.gd/.tscn               CastGlow (Node3D, cada peer): enciende su SpriteEmitter mientras se lanza su hechizo (Rainbow: 6 `heal` por tick que suben). ≤40
  actions/
    [+] launch_action.gd                 LaunchAction extends SpellAction. @export target: SpellTarget, launch: PackedScene; check (fondos, blanco, alcance, «ya hay uno»); started instancia; finish suelta; cancel aborta. ≤90
    [+] carrier_action.gd                CarrierAction extends SpellAction: igual con `SpellSpawner` (kind). ≤80
    [+] chain_lightning_action.tscn      LaunchAction(tag ntlc, target ENEMY, launch chain_lightning.tscn, cast_fx needle)
    [+] rainbow_action.tscn              LaunchAction(wobr, ALLY_OR_SELF, rainbow.tscn, cast_fx heal)
    [+] halo_action.tscn                 LaunchAction(olah, SELF, pick SELF, halo_of_earth.tscn de mago)
    [+] dragonfire_action.tscn           CarrierAction(rifd, ENEMY, kind "Dragonfire")
  carrier/
    [+] README.md
    [+] spell_carrier.gd                 SpellCarrier extends SpellProjectile (Motion.GUIDED): fases CASTING (espiral) / FLYING / SHRINKING; sigue al blanco; sync de position y scale. ≤150
    [+] carrier_arrive.gd                CarrierArrive (Node): arrive(carrier) vacío
    [+] dragon_arrive.gd                 DragonArrive extends CarrierArrive: 700 + salpicadura + Burning 1 s; ChainHop (hits 5, sin achicar) elige el próximo; retarget o shrink. ≤100
    [+] dragonfire.tscn                  SpellCarrier ├ Chain (ChainHop manual) ├ OnArrive (DragonArrive) ├ Look (dragon_look.tscn) ├ Trail (FxTrail) ├ Light ├ FlightSound (loop dfi4)
    [+] dragon_look.tscn                 Node3D ├ Dragon (MeshInstance3D de dfir.glb, 4 blend shapes) ├ Anim (AnimationPlayer: pesos 0→4→1 en 1,5 s). Materiales sin sombreado, alfa, energía 20
scenes/fx/
  [~] beam_type.gd                       + path (BOLT / ARC), arc_height_factor 0,5, tip_type/tip_per_s (destellos en la punta); fx_name()
  [~] beam_fx.gd                         dibuja el camino ARC y suelta los destellos de la punta
  [~] particle_type.gd                   + fx_name() (el archivo bajo data/fx/ sin extensión; C17)
scenes/units/abilities/
  [~] halo_of_earth.gd                   extends SpellLaunch; setup_spell(): números del SpellType; begin_cast/release/abort; salida escalonada REA ((p+0,1)×6); `armed`; temblor y sonido al emerger; _can_carry mira la vida del mago
  [~] halo_of_earth.tscn                 emerge_fx/shake; sockets de sonido
data/catalog/spells/[~] ntlc, wobr, rifd, olah .tres   action = su escena
data/shots/[~] halo_rock.tres            model = roks, model_scale = 1 (EXE confirmado)
data/fx/
  [+] spark.tres                         sprk, aditiva, 192, energía 15 (el golpe de cada salto)
  [+] fireball_dragon.tres, dragon_flame.tres   fbal / firy de la estela del dragón
  [+] rainbow_cast.tres                  glo2 subiendo (CastGlow)
  beams/ [+] lightning_small.tres (rayito del lanzamiento), rainbow.tres (rnbw, ARC, 31 segmentos, aleta 0,7 m, 160/60 s, viaje 64/60), [~] lightning.tres (nota ltn2/ltng)
        [+] lightning_ltng.tres          ltng, el mismo trazo: el knob del EXE (NO VERIFICADO)
data/audio/[~] fx_sounds.tres            + chain_lightning, rainbow, dragonfire_*, halo_*
scenes/wizards/[~] wizard_body.tscn      + CastFx └ ChainBolts, RainbowGlow
assets/original/fx/ [+] ltng, rnbw, fbal (import_ui EXTRA_FX) · props/ [+] roks.glb (SPELL_MODELS) · props/ [+] dfir.glb + dfir_M000/M001.png (tools/import/import_dragonfire.py + blender_dfir.py)
tools/import/ [~] import_ui.py, sac_formats/props.py · [+] import_dragonfire.py, blender_dfir.py
debug/spells/[+] cast_chain.tscn ; debug/rules/[+] cast_chain.tres
debug/suite/[+] chain_cases.gd ; [~] rules_suite.gd (lo registra)
agent/harness/match_shots/[~] match_shots.gd   --cast=ntlc|wobr|rifd|olah (ya existe --cast= de 061b; solo los puntos de mira y el aliado herido)
tools/lint/[~] baseline.txt (solo si algún conteo baja)
```

## Tipo / nodo / instancia

- **Resource de tipo:** el `SpellType` `.tres` (números), el `SpellTarget` embebido en la escena de la acción, los `BeamType`/`ParticleType` de `data/fx/`.
- **Nodos:** `ChainHop` + su `Effect` (las escenas `chain_lightning.tscn` y `rainbow.tscn`), el portador con su `OnArrive` y su `Look`, el halo.
- **`@export` de instancia:** `hits`, `hop_s`, `shrink_steps`, `allies`, `pick`; `speed`/`turn_rate` del portador; `orbit_*` del halo.
- **Dónde se edita un hechizo:** su `.tres` (maná, alcance, daño) y su escena de acción/lanzamiento (cantidad de golpes, ritmo, look). Las posiciones del lanzamiento (salida del rayo, centro de la órbita) usan los sockets `Marker3D` ya existentes del cuerpo del mago.

## Dueños y red

- `ChainHop` es el único dueño de «quién fue golpeado y a quién le toca»; los efectos no guardan estado de la cadena.
- `Health` sigue siendo el único que descuenta daño; `HealEffect` el único que cura en el tiempo.
- Todo lo que simula (cadena, dragón, rocas) corre **solo en el host/solo**. Los nodos de cadena y halo no existen en un cliente (igual que `LightningStrike`). El dragón sí se replica (`SpellSpawner` + `MpReplicate` de `position` y `scale`); su orientación se deriva en cada peer del movimiento. Rayos, arcos, estallidos y temblor viajan por `FxBus.broadcast*`.
- La presentación del lanzamiento (rayitos, destellos) la hace cada peer desde el `cast_fx_shown` replicado del `Caster`; no lee la simulación.
- No se toca `MpKit.`: el `SpellSpawner` ya es el dueño de `MultiplayerSpawner`.

## Criterios medibles (suite `chain_cases`, a `--fixed-fps 600`)

- **Radio:** `ChainHop.radius(reach, n)` = (6−n)/6 × reach para n = 0..5: 50, 41,667, 33,333, 25, 16,667, 8,333 ± 1e-3. Con `shrink_steps = 0` es fijo.
- **Selección:** un blanco a 45 m del golpeado 0 entra y a 45 m del golpeado 1 no entra (41,7 m); uno ya golpeado no vuelve; un aliado no entra en Chain Lightning; un muerto tampoco.
- **Chain Lightning:** 9 Trogg enemigos en fila a 6 m: reciben 600 × su resistencia exactamente **7** (el 8.º y el 9.º, 0). Cada daño llega 12 ticks después de que sale su rayo, y los rayos salen cada 20 ticks ± 1. Un aliado en la fila no recibe nada. Con un enemigo menos y sin otro a la vista, el 7.º rayo cae en un punto (sin daño, sin error).
- **Rainbow:** 7 aliados con 100 de vida en un corro de 5 m: **6** terminan con la vida máxima completa y el 7.º no se toca; el orden es el de menor fracción de vida; cada arco llega en 64 ticks ± 1; la cura total de cada uno = su máximo ± 1.
- **Dragonfire:** 6 Trogg enemigos a 8 m entre sí: el dragón golpea **5** (700 con salpicadura de 5 m; el 6.º, 0 salvo la salpicadura), vuela a 18 m/s ± 1 %, y la quemadura de paso es 175/s ± 2 % a un cuerpo en su caja. Con un solo blanco: 2 intentos fallidos y se achica a 0 en 1 s ± 2 ticks.
- **Halo:** 6 rocas exactas (la 7.ª no existe); en un lanzamiento de 148 ticks salen en los ticks que da `floor((p + 0,1) × 6)`; ninguna roca explota mientras se lanza; 6 Trogg a ≤50 m reciben 600 × su resistencia cada uno; uno a 60 m, nada; rocas que explotan sin blanco a los 35 s; abortar el lanzamiento hace explotar las libres.
- **Cast por el libro de cada dios:** `Caster.request_cast` con maná: gasta 800/300/800/1000, pone la recarga y a los `casting_time_s` empieza el efecto; «ya hay un halo» es BAD_TARGET.
- **IA:** los cuatro dan `rating_fn` distinto de FN_NONE sin romper; con un blanco al alcance la acción dice "" (podría empezar); sin él, un motivo.
- **Lint** sin subir conteos.

Con ventana (el usuario captura): `match_shots --cast=ntlc|wobr|rifd|olah` en High Noon con cámara fija.

## Verificado y NO VERIFICADO

- Verificado (REA/SPEL en `061R`/`061V`): 7 y 6 golpes, radios (6−n)/6, curas completas, 5 blancos del dragón (`enum totTargets=5`, sacengine), 6 rocas, escalonado `(p+0,1)×6`, `roks` fijo, `rnbw`, `prbw`, `dfir` de 5 cuadros.
- NO VERIFICADO (se deja el knob): `ltn2` (SPEL) contra `ltng` (EXE) del rayo: por defecto `ltn2`, `lightning_ltng.tres` listo; la quemadura `scar` y la grieta `gscr` (falta el lector SCAR); el sonido `Xcnj` en lazo de Chain Lightning; qué evento es cada bandera de los cuatro sonidos de Dragonfire.
- Desvío declarado: el SPEL de Chain Lightning dice que el primer blanco puede ser un edificio; los saltos eligen solo cuerpos vivos con vida (como el original: `EnemyType.creature`).

## Orden

1. Plan (este archivo). 2. Assets: `ltng`, `rnbw`, `fbal`, `roks` por el importador; `dfir.glb` con Blender CLI. 3. Piezas compartidas (`SpellTarget`, `SpellLaunch`, `ChainHop`, efectos, `BeamType.ARC`). 4. Chain Lightning y Rainbow (datos, escenas, sonido, presentación del lanzamiento). 5. Halo (refactor mínimo de `HaloOfEarth`, `roks`, escalonado). 6. Dragonfire (portador, modelo, llegada, trazo). 7. Escena de verificación, suite, `match_shots`. 8. Lint y corrida.

## Ajustes al implementar (lo que cambió respecto del árbol de arriba)

- `SpellTarget` ya existía (061c, en `main`): se usa tal cual; no se creó ninguno.
- La presentación del lanzamiento no está en `wizard_body.tscn`: `LaunchAction.cast_scene` la juega en cada peer con `FxBus.broadcast_scene` (`CastBolts`, `CastGlow`), como el globo de Slime. `wizard_body.tscn` no se toca.
- La elección del próximo blanco y el punto de caída salieron de `ChainHop` a `ChainPick` (RefCounted, sin estado), y la geometría del vuelo del dragón a `CarrierPath`, para quedar bajo las 150 líneas (C1).
- `ChainHop.pick` pasó a `order` (`ChainPick.Order`).
- `Health.of(body)`, `ShotSpawner.of(tree)` / `container()` y `SpellSpawner.of(tree)` son estáticos nuevos (el lint prohíbe `get_node("Health")` y los grupos por texto).
- `LightningStrike.launch` recibe `look`, `travel` y `seat` opcionales (el rayo de la cadena trae su haz, su chispa y su tiempo, y daña en nombre del mago aunque ya no exista).
- `data/gods/<dios>.tres`: cada libro suma su hechizo en `spells` (ntlc, wobr, rifd, olah); sin eso el mago no lo tiene.
- Sonidos: `rainbow_arc`, `dragon_roar`, `dragonfire_loop`, `halo_throw` en `fx_sounds.tres`; `lightning_ltng` alias del cue del rayo. `halo_throw` y `dragon_roar` son `ParticleType` sin sprites (solo disparan el sonido por `FxBus`).
- `data/fx/spells/` guarda los tipos continuos (`rainbow_cast`, `dragon_flame`, `dragon_fireball`): FxBus pre-calienta todo lo que está en `data/fx/` y esos son para `SpriteEmitter`.
- No se creó `roks.tres` en `data/catalog/body_sizes/` (suma 1 al conteo C19 y la roca no lo necesita); el `sizes.json` sí tiene la entrada.
- El halo del Rhinok también pasa a `roks` ×1 (el exe empuja `roks` fijo para las dos versiones).
- Dragonfire usa `CarrierArrive` con cuatro ganchos (`begin`, `released`, `along`, `arrive`); `along` es la quema al pasar. `SpellSpawner.spawn_projectile` devuelve el nodo.
