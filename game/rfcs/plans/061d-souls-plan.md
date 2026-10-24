# 061d: almas (Soul Mole, Animate Dead, Soul Wind)

Corte del plan maestro `061-spells-master-plan.md` (pieza 6, `SpellCarrier`). Números de `rfcs/research/061R-abilities-structures.md`; arte de `rfcs/research/061V-spell-visuals-d-e.md` (el SPEL manda sobre las etiquetas del exe). Arte final desde el inicio (decisión del usuario, 2026-10-24).

## Objetivo
- **Soul Mole (`pmcd`, nivel 3, 50 de maná):** un topo (la roca `rock`) nace en los pies del mago al empezar el hechizo, camina 4,5 s por una curva hasta el alma, la suelta de su cuerpo (el cadáver se disuelve) y en otros 4,5 s la arrastra al mago. Todo el que pasa a ≤10 m del topo queda aturdido (8 s de enfriamiento propio), salvo el mago. No hace daño. El aturdimiento empieza cuando termina el lanzamiento.
- **Soul Wind (`dnws`, nivel 5, 500 de maná):** igual, pero un remolino. Cada no aliado a ≤30 m del remolino recibe, una sola vez por viaje, aturdimiento y 400 de daño de hechizo directo, con un rayo del remolino al blanco.
- **Animate Dead (`deda`, nivel 4, 300 de maná):** sobre el alma de un cadáver (alma azul para el mago, no soltada con P) la criatura revive al empezar el lanzamiento y tarda su `reviveTime` (5 s): sube 2 m en la primera mitad, gira dos vueltas y queda en pie. Mientras tanto, unas 15 estelas por segundo van del mago a la criatura y las 128 chispas violetas estallan sobre ella.
- Los tres se arman con la tecla y se lanzan con un clic sobre un **alma** (no sobre un cuerpo).
- Si el mago muere o lo interrumpen durante el lanzamiento, el topo o el remolino desaparece (Animate Dead ya no se corta: en el original el revivir empieza al comenzar el lanzamiento).
- Si el alma desaparece (otro mago la recoge, la revive un hechizo, la revienta Rend Soul) el viaje termina donde esté.

## Dónde se edita y quién es dueño de qué
- **Tipo:** los `.tres` de `data/catalog/spells/` (maná, enfriamiento, `effect_range`, `damage`) más la escena de acción de cada hechizo (`action = ...`).
- **Nodos/escenas:** `soul_mole.tscn` y `soul_wind.tscn` son el mismo `SpellCarrier` con otros hijos (look, `SoulFetch`, `CarrierPulse`). El radio del aturdimiento es la forma `Reach` de cada `CarrierPulse` (se arrastra con el gizmo, C20), no un número.
- **Un dueño por estado:** el viaje (posición, fase, cuándo corta el alma) es de `SpellCarrier`; el alma es de `Soul` (que sigue a su portador: `Soul.carrier`, sin que nadie más escriba su posición); el aturdimiento es de `Stunned`; la revivida es de `FastRevive` (ya existe; Animate Dead usa otros knobs).
- **Nada nuevo en `Caster`:** `SpellType.action` instancia la escena de acción.

## Árbol de archivos

```
scenes/spells/
  [~] README.md                          Check: rules_suite soul_cases · debug/spells/cast_souls.tscn · match_shots --cast=pmcd|deda|dnws
  [~] spell_spawner.gd                   + kinds "SoulMole", "SoulWind", "AnimateDead"
  [~] spell_type.gd                      (sin cambios de campos: 061d no agrega AiUse, ver IA)
  carrier/
    [+] README.md                        What / Not / Talks to / Edit / Check
    [+] spell_carrier.gd                 SpellCarrier extends SpellProjectile: viaje de ida y vuelta al alma; reached/returned/ended; solo el servidor lo mueve. ≤150
    [+] carrier_path.gd                  CarrierPath (RefCounted, static): Hermite de dos tramos, tangentes perpendiculares; se prueba sola. ≤70
    [+] soul_fetch.gd                    SoulFetch (Node hijo): al llegar al alma la suelta del cadáver y la hace seguir al portador. ≤80
    [+] carrier_pulse.gd                 CarrierPulse (Node3D hijo): cada tick, los cuerpos dentro de `Reach`: aturdir, y si quiere daño/rayo una vez por blanco. ≤130
    [+] soul_mole.tscn                   SpellCarrier ├ Look (rock.glb + SpriteEmitter dust + SpriteEmitter rock) ├ Fetch ├ Pulse(Reach r 10, solo aturde) └ Sound(Xquk, lazo)
    [+] soul_wind.tscn                   SpellCarrier ├ Look (embudo + SpriteEmitter dust) ├ Fetch └ Pulse(Reach r 30, 400 una vez, no aliados, rayo) └ Sound
    [+] funnel.gdshader                  swnd x2, desplazamiento de v, alfa 0,75
    [+] soul_wind_funnel.res             ArrayMesh 32 lados x 32 anillos (la hornea tools/bake/make_soul_wind_funnel.gd: es una formula, no hace falta Blender)
    [+] prop_look.gd                     PropLook (MeshInstance3D): dibuja un modelo estatico del original por nombre (la roca del topo)
  actions/
    [+] soul_action.gd                   SoulAction extends SpellAction: pick SOUL; check (alma azul, no soltada, viva, en alcance); started → spawn del portador; finish → pulse armado; cancel → portador fuera. ≤90
    [+] soul_mole_action.tscn            SoulAction(tag pmcd, carrier_kind SoulMole, cast_fx dirt_cast)
    [+] soul_wind_action.tscn            SoulAction(tag dnws, carrier_kind SoulWind, cast_fx cast de Stratos)
    [+] animate_dead_action.gd           AnimateDeadAction extends SpellAction: pick SOUL; check (alma con cadáver); started → FastRevive normal + efecto replicado. ≤80
    [+] animate_dead_action.tscn
  animate_dead/
    [+] README.md
    [+] animate_dead_fx.gd               AnimateDeadFx extends SpellProjectile: estallido sobre la criatura y estelas del mago a ella, en cada peer. ≤110
    [+] streamer_fx.gd                   StreamerFx (MeshInstance3D): una estela de 31 segmentos por una curva Hermite con ventana de cometa. ≤120
    [+] streamer_fx.tscn
    [+] animate_dead_fx.tscn
scenes/souls/
  [~] soul.gd                            + carrier (el portador al que sigue), release_to(slot) (suelta el cadáver y prefiere al mago)
scenes/units/abilities/
  [~] fast_revive.gd                     (sin cambios: la revivida normal es revive_ticks 300 / rise_ticks 150 / turns 2)
  [+] fast_revive_slow.tscn              FastRevive con los knobs de Animate Dead (otra instancia de la misma escena)
scenes/orders/command/
  [~] spell_command.gd                   cast_at: si la acción elige alma, el clic busca el alma (layer 4)
scenes/fx/
  [~] fx_bus.gd                          + name_of(type: Resource) para pasar un tipo tipado sin texto (C17)
data/catalog/spells/[~] pmcd, deda, dnws .tres   action = su escena
data/fx/
  [+] soul_mole_dust.tres, soul_mole_rocks.tres, soul_wind_dust.tres, animate_dead_burst.tres
  beams/[+] soul_wind_bolt.tres, animate_dead_streamer.tres
assets/original/fx/[+] and2.png, cfx1.png, swnd.png, wdst.png (+ .import)   tools/import/import_ui.py: EXTRA_FX
tools/bake/[+] make_soul_wind_funnel.gd
data/gods/[~] james, stratos, charnel .tres   pmcd, dnws, deda entran en el libro (las tres ya estaban en los desbloqueos por nivel)
scenes/spells/actions/[~] spell_action.gd, aimed_action.gd   projectile_spawner() sube a SpellAction (lo usan tambien SoulAction y AnimateDeadAction)
debug/spells/[+] cast_souls.tscn, soul_field.gd         debug/rules/[+] cast_souls.tres
debug/suite/[+] soul_cases.gd, animate_dead_cases.gd, soul_world.gd ; [~] rules_suite.gd, determinism_cases.gd (dos lineas permitidas para los RNG de presentacion)
agent/harness/match_shots/[~] match_shots.gd   --cast con un hechizo de alma: apunta al alma libre más cercana (si no hay, suelta una a 30 m)
tools/lint/[~] baseline.txt
```

**Tipo / nodo / instancia**
- Tipo (Resource): `SpellType` por hechizo; `ParticleType` y `BeamType` del look.
- Nodos: cada portador y su look en su `.tscn`. Instancia: el radio de `Reach` (gizmo), `stun_ticks`, `once_per_target`.
- Para hacer otro hechizo de viaje (Charm, Dragonfire…) alcanza con otra escena de `SpellCarrier` con otros hijos.

## Red
- `Caster.request_cast` → `submit_cast` → en el servidor `SoulAction.started` pide al `SpellSpawner` un portador (`SoulMole`/`SoulWind`). El spawner lo replica en cada peer, que dibuja su look. El servidor lo mueve y replica `position` (`MpReplicate`, como el Fireball); los clientes no ejecutan el viaje ni el pulso.
- El alma ya replica su posición: en el servidor sigue a su portador (`Soul.carrier`), así que el cliente la ve viajar.
- Animate Dead: el servidor arranca `FastRevive` en el cuerpo (ya replicado por el cuerpo) y pide un `AnimateDead` al spawner; cada peer dibuja el estallido y las estelas desde la criatura y el mago.
- No hay `MpKit.` nuevo fuera de la allowlist (`multiplayer.is_server()` directo).

## Criterios (suite `soul_cases`)
- **Camino:** `CarrierPath` está en el mago en el tick 0, en el alma en el tick 270 ± 1 y vuelve al mago en el tick 540 ± 1; la tangente de salida es perpendicular a la recta mago→alma; la altura sigue el suelo.
- **Soul Mole:** el topo está sobre el alma en el tick 270 ± 1; ese tick suelta el alma (cadáver disuelto, `owner_slot` = mago, `carrier` = topo); entre 270 y 540 la distancia alma–topo es 0; el mago la recoge (regla de 5 m) antes del tick 540 y el viaje termina. Aturde a un Trogg a ≤10 m, no a uno a 12 m, y nunca al mago. Sin armar (durante el lanzamiento) no aturde. No hace daño.
- **Soul Wind:** igual recorrido. Un enemigo a ≤30 m recibe 400 de hechizo directo (± resistencia) y queda aturdido **una sola vez** aunque el remolino pase dos veces cerca; un aliado y el mago no reciben nada; uno a 40 m tampoco.
- **Cancelar:** si el mago muere durante el lanzamiento, el portador desaparece y el alma queda intacta (con su cadáver).
- **Alma perdida:** si otra cosa se lleva el alma (la recoge un mago, la revienta Rend Soul) antes del tick 270, el viaje termina.
- **Animate Dead:** sobre el alma de un cadáver propio, la criatura pasa a `REVIVING` en el mismo tick, y a los `300 ± 1` ticks está viva, en reposo, con la vida completa y 2 vueltas dadas; el alma se va; sube 2 m ± 0,05 en la primera mitad. Rechazos: alma suelta o soltada con P → `BAD_TARGET`; alma ya `REVIVING` → `BAD_TARGET`; sin maná → `NO_MANA`.
- **Pick:** los tres piden `Pick.SOUL`; el clic sobre un cuerpo no los lanza.
- **IA:** un mago de la IA con alma a mano no lanza estos hechizos ni rompe: su `rating_fn` da `FN_NONE` y el vuelo de la suite de IA sigue verde.
- El lint no sube; el resto de la suite sigue verde.

## Escena de verificación: `res://debug/spells/cast_souls.tscn` (F6)
- High Noon con `debug/rules/cast_souls.tres` (nivel 5, maná lleno), un Trogg muerto con su alma a 25 m (`rock_hit.gd` no sirve: los cadáveres los pone la escena) y enemigos a 6 y 20 m para ver el aturdimiento y el daño. `spell_N` arma el hechizo; un clic sobre el alma lo lanza.

## IA
- Hoy el original no tiene evaluador para estos tres (`flags1` da `FN_NONE`): la IA no los lanza y no se rompe. 061d lo confirma con un caso. Lo ideal (traer almas, revivir a su criatura más cara) cae en 055f: la IA no ve almas como blancos (`AiTrack`), así que un `AiUse` por familia hoy sería código sin dónde pararse. **Declarado, no hecho.**

## Divergencias y NO VERIFICADO
- Animate Dead sobre un alma sin cadáver: el original lanza igual y gasta el maná sin hacer nada; acá se rechaza con `BAD_TARGET` antes de gastar.
- Los sonidos `sstl`, `sac0`, `sac9`, `anme` no están en `world.tres` como claves del SPEL; solo suenan `Xquk` (topo), `Xfbl` (remolino) y `Xanm` (Animate Dead).
- El lazo `shld` del remolino y los modelos `skul` de Soul Wind son NO VERIFICADOS en 061V (no se usan).
- Las dos capas de `swnd` (`ttx1`/`ttx2`): se dibujan como una sola capa con dos repeticiones (NO VERIFICADO cómo las combina el original); el knob `layers` del shader permite probar la segunda.
- `reviveTime` y `reviveHeight` son constantes de sacengine (5 s y 2 m; `stats.d:165-170`), no datos del SPEL.

## Orden
`Soul.carrier`/`release_to` → `CarrierPath` y `SpellCarrier` → `SoulFetch` y `CarrierPulse` → `SoulAction` y los `.tres` → `spell_command` (clic sobre alma) → casos de suite del viaje (headless, sin look) → `AnimateDeadAction` → casos → arte (assets, partículas, embudo, estelas) → debug, `match_shots` y lint.

## Nota del merge con 061e
`SpellCarrier` ahora tiene `motion` (SOUL_TRIP es el de este plan, sin cambios de comportamiento; GUIDED es el dragon de Dragonfire) y `arm(target := null)`. `CarrierPath` suma `spiral` y `turned`. Ver `061e-chain-plan.md`.
