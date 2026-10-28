# 061g: muros (Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence)

Corte del plan maestro `061-spells-master-plan.md` (pieza 8, `SpellWall` + hijo `WallTouch`). Números de `docs/archive/rfcs/research/061R-abilities-structures.md` (REA manda: Firewall 625/s × una rampa de 3 s única para todo el muro, NO el 1200/s de sacengine); arte de `docs/archive/rfcs/research/061V-spell-visuals-f-g.md` (el SPEL manda). Arte final desde el inicio (decisión del usuario, 2026-10-24).

## Objetivo
- Los cinco se lanzan con la tecla y un clic en el **suelo**. El muro se centra en el clic, su recta es perpendicular a mago→clic y crece desde el centro hacia los dos lados a `effect_range / grow_ticks` por tick (55 m por lado). Cada extremo se detiene al llegar a `effect_range`, a un edificio o al borde del mapa. Empieza a crecer con el lanzamiento y sigue creciendo hasta `grow_ticks` (4 s; 3 s Wailing Wall; 176 ticks Fence, valores de sacengine marcados «TODO» ahí: **NO VERIFICADO** en el exe).
- Altura (rampa de subida): Firewall 7,5 m en 2 s; Wall of Spikes 5 m en 0,5 s; Wailing Wall 7,5 m (el SPEL; sacengine usa 6) en 2 s; Vinewall 7,5 m en 1 s. Espesor 5 m. Al final baja en 1 s. Los extremos bajan en rampa a lo largo de 5 m (`min(0,2·distancia al extremo, 1)`).
- Si el mago muere o lo interrumpen durante el lanzamiento el muro empieza a bajar de inmediato (sacengine: `status = shrinking`). El efecto empieza cuando termina el lanzamiento.
- **Firewall (`lwrf`, 30 s):** quien está dentro (caja contra caja, alto del muro) recibe `625 × rampa` por segundo; la rampa sube de 0 a 1 en 3 s desde que el muro termina de levantarse y es una sola para todo el muro (REA 0x42845f). Tipo de daño del SPEL (`[+0x48]`): **NO VERIFICADO**; por defecto hechizo directo con `pierce` e IGNITE (como `ignite` de sacengine); knobs `kind`, `pierce_shield`, `mods`. Sin filtro de bando en el muro (el de `Health` es el normal).
- **Wall of Spikes (`laws`, 40 s):** al que pisa el eje (≤0,4 × espesor) lo aturde, le hace 625 de hechizo directo y lo frena ×0,5 durante 6 s (no vuelve a tocarlo mientras dura). Sin filtro de bando (aturde a aliados; el daño lo filtra `Health`). Al cruzar sube un pincho `jspk` bajo el blanco (el `SpikeField` existente), con `spks` y 25 `dirt`. 180 pinchos fijos que crecen en 0,5 s durante el lanzamiento y se hunden en 1 s.
- **Wailing Wall (`laww`, 60 s):** a todo el que lo cruza le drena `maxMana` por segundo (queda en 0 en 1 s) y le pone un espíritu 8 s que lo frena ×0,75 (uno por cuerpo). Sin filtro de bando. 12 espíritus patrullan el muro.
- **Vinewall (`lawv`, 50 s):** al enemigo que cruza (≤0,35 × espesor; ≤0,5 arranca la animación, **no se dibuja**: ver desvíos) le pone Grasping Vines con lo que quede del muro (`min(cap, k·cap)`, `cap = duración − tiempo desde el fin del lanzamiento`) y 6 s de enfriamiento por blanco (se renueva mientras siga atado). Salta a quien es `ccProtected`. 180 lianas.
- **Fence (`cnef`, 35 s):** hasta 12 postes (dos cada 32 ticks desde el tick 16, uno en cada frente) flotando entre 2,5 y 5,5 m con un vaivén de 3,6 s. Cada poste tira un rayo de 625 (hechizo directo, marca de rayo) a cada criatura a ≤10 m con probabilidad 0,9/s; arcos entre postes vecinos con enfriamiento de 1 a 2 s y descargas al suelo a 5–15 m (modelo de carga de sacengine); 3–5 rayos al nacer cada poste.
- Grietas SCAR (`quk1`, `gscr`): **no hay lector de SCAR**; quedan fuera.

## Dónde se edita y quién es dueño de qué
- **Tipo:** los `.tres` de `data/catalog/spells/` (maná, `damage`, `effect_range`, `duration`) y la escena de acción. `SpellType.action` instancia `wall_action.tscn`; la escena del muro se elige por la clave `wall_kind` del `SpellSpawner`.
- **Nodos/escenas:** cada muro es una escena `SpellWall` con otros hijos (`WallTouch`, el look, emisores, sonido). Largo, alto y espesor son la forma `Body` (un `BoxShape3D`: `x` = alcance total, `y` = alto, `z` = espesor) que se arrastra con el gizmo (C20). Subida, bajada, `grow_ticks` y los knobs de efecto (`damage_per_s`, `hit_damage`, `stun_ticks`, `slow_factor`, `mana_drain`, `affliction`, `cooldown_s`, `core_fraction`) son `@export` de la escena.
- **Un dueño por estado:** el ciclo del muro (edad, bordes, `top`) es de `SpellWall`; qué hace al que está dentro es de `WallTouch`; el aturdimiento es de `Stunned`; la velocidad de `PaceFactors` (fuente `wall_*`); el maná de `ManaPool`; las lianas de `Vined`. El alto vigente (`top`) y la rampa se **derivan** de `age`/`vanish_at` (idempotente: no hay banderas de «ya subí»).
- **Nada nuevo en `Caster`:** `WallAction` extiende `SpellAction` (como `SoulAction`).
- **IA:** sin código nuevo. Los `.tres` de los muros ya dan `FN_AREA` por `flags1` (0x4040): la IA los lanza sobre la criatura enemiga más valiosa (como lo haría el original). La suite de IA confirma que no se rompe.

## Árbol de archivos

```
scenes/spells/
  [~] README.md                          Check: ... · wall_cases · match_shots --cast=lwrf|laws|laww|lawv|cnef --views=wall
  [~] spell_spawner.gd                   + kinds "Firewall", "WallOfSpikes", "WailingWall", "Vinewall", "Fence"
  walls/
    [+] README.md                        What / Not / Talks to / Edit / Check
    [+] spell_wall.gd                    SpellWall extends SpellProjectile: setup, edades, bordes que crecen y se detienen, top() derivado, arm()/stop(), ended. Solo el servidor crece; age/left/right/vanish_at se replican. ≤150
    [+] wall_rules.gd                    WallRules (RefCounted, static): in_wall(caja, ...), edge_scale(t,...), rise(age,...), lateral(...). Se prueba sola. ≤90
    [+] wall_touch.gd                    WallTouch (Node hijo): cada tick, quién está dentro y qué se le hace (knobs). Solo el servidor. ≤150
    [+] wall_look.gd                     WallLook (MeshInstance3D): le da al shader left/right/top/tiempo y la altura del suelo bajo el muro (textura 129×1). ≤100
    [+] wall_emitter.gd                  WallEmitter (Node3D): mueve un SpriteEmitter hijo sobre el muro (relleno) o sus frentes (bordes). ≤90
    [+] wall_spikes.gd                   WallSpikes (MultiMeshInstance3D): 180 pinchos (malla de SpikeField): nacen, crecen y se hunden. ≤130
    [+] wall_vines.gd                    WallVines (MultiMeshInstance3D): 180 lianas (tubo sin huesos; el shader las dobla). ≤110
    [+] wall_spirits.gd                  WallSpirit (Node3D): un espíritu que patrulla el muro; 12 en wailing_wall.tscn. ≤90
    [+] wall_orbit.tscn + wall_orbit.gd  WallOrbit: el espíritu que gira 8 s alrededor del cuerpo cruzado (FxBus.broadcast_scene). ≤70
    [+] wall_light_follow.gd             WallLightFollow (Node): deja el ActorLight del muro en el punto (o poste) más cercano al oyente y lo prende mientras el muro está en pie. ≤60
    [+] wall_sound.gd                    WallSound (SoundEmitter3D): un disparo al levantarse o al hundirse, o un lazo mientras está en pie, en el punto del muro más cercano al oyente. ≤60
    [+] wall_ground.gd                   WallGround (RefCounted, static): el suelo bajo un punto, si un extremo puede pararse ahí, los cuerpos dentro. ≤70
    [+] fence_posts.gd                   FencePosts (Node3D): nacen los postes, flotan y se apagan; dibuja burbuja `bubl` y chispas `cst0`. ≤140
    [+] fence_zap.gd                     FenceZap (Node, servidor): rayos a criaturas, arcos entre postes, descargas al suelo, modelo de carga. ≤140
    [+] wall.gdshaderinc                 el doblado del muro: altura, rampa de extremos, ondulación, suelo
    [+] wall_add.gdshader, wall_mix.gdshader   muro aditivo (Firewall) y con alfa (Wailing Wall): atlas 4×4, un cuadro cada 4 ticks, mosaico espejado
    [+] wall_vine.gdshader               doblado de la liana: crece, se retuerce, se recoge
    [+] wall_sprite_add.gdshader, wall_sprite_mix.gdshader   sprite billboard con atlas (postes)
    [+] wall_strip.obj                   la malla del muro (techo a dos aguas, 129 secciones; la hornea tools/bake/make_wall_meshes.py con Blender CLI)
    [+] vine_tube.obj                    la liana sin huesos (la hornea el mismo script)
    [+] firewall.tscn, wall_of_spikes.tscn, wailing_wall.tscn, vinewall.tscn, fence.tscn
  actions/
    [+] wall_action.gd                   WallAction extends SpellAction: pick GROUND; check (funds, alcance, suelo); started → spawn del muro; finish → arm(); cancel → stop(). ≤80
    [+] firewall_action.tscn, wall_of_spikes_action.tscn, wailing_wall_action.tscn, vinewall_action.tscn, fence_action.tscn
scenes/spells/ (compartido)
  [~] fx/spike_field.gd                  _mesh() pasa a una función estática pública (la comparten el pincho del golpe y los 180 del muro)
scenes/units/afflictions/
  [~] affliction.gd                      + lay_within(spell, slot, max_s): por defecto lay()
  [~] vined.gd                           lay_within: min(max_s, k·duración) (el tope del Vinewall); grasp() lo usa
data/catalog/spells/[~] lwrf, laws, laww, lawv, cnef .tres   action = su escena
data/gods/[~] pyro, james, charnel, persephone, stratos .tres   el hechizo entra al final de book.spells
data/fx/[+] wall_flames.tres (fwpt), wall_firy.tres, wall_dirt.tres, wall_pvin.tres, wall_cst1.tres, wail_spirit.tres (wlsp)
data/audio/fx_sounds.tres [~]            + claves wall_* (lazos y disparos)
assets/original/fx/[+] fwal, fwpt, wwal, wlsp, pvin, bubl (.png + .import)   tools/import/import_ui.py: EXTRA_FX
tools/bake/[+] make_wall_meshes.py       Blender CLI: wall_strip.obj y vine_tube.obj (sin archivos del original)
debug/spells/[+] cast_walls.tscn         debug/rules/[+] cast_walls.tres
debug/suite/[+] wall_cases.gd, wall_world.gd? (reusa soul_world.gd) ; [~] rules_suite.gd
agent/harness/match_shots/[~] match_shots.gd   --cast con un muro: apunta al suelo entre el mago y el enemigo más cercano; vista `wall` (el primer SpellWall en pie)
tools/lint/[~] baseline.txt
```

**Tipo / nodo / instancia**
- Tipo (Resource): `SpellType` por hechizo; `ParticleType` y `BeamType` del look.
- Nodos: cada muro y su look en su `.tscn`. Instancia: forma `Body` (gizmo), subida/bajada, `grow_ticks`, knobs de `WallTouch`.
- Otro muro = otra escena de `SpellWall` con otros hijos y otra fila en el libro.

## Red
- `Caster.request_cast` → `submit_cast` → en el servidor `WallAction.started` pide al `SpellSpawner` un muro; el spawner lo replica en cada peer, que dibuja su look. El servidor hace crecer los bordes y replica `left`, `right`, `age` y `vanish_at` (más `FencePosts.posts` en Fence); cada peer cuenta además su propio `age` por tick y deriva `top` y la rampa de ahí. Los clientes no ejecutan `WallTouch` ni `FenceZap`.
- Sin `MpKit.` nuevo fuera de la allowlist (`multiplayer.is_server()` / `MpKit.is_networked()` como el portador).

## Criterios (suite `wall_cases`)
- **Geometría:** la dirección es perpendicular a mago→clic; tras `grow_ticks` los bordes están a `±effect_range` (55 ± 0,3 m); con un edificio a 20 m del centro el borde izquierdo queda a ≤20 m y no pasa. `WallRules.in_wall` acepta una caja dentro del espesor y del alto, rechaza una a 4 m del eje (espesor 5) y una volando sobre el muro.
- **Ciclo:** el alto sube a 7,5 m en `rise_s` ± 1 tick, el muro desaparece a `grow_ticks + duración·60 + 60` ticks ± 2; si el mago muere durante el lanzamiento baja en ≤ 60 ticks; la forma `Body` del muro es el alto y el espesor que se usan.
- **Firewall:** el daño por segundo con la rampa llena es 625 ± 2 % y la rampa de 3 s es una sola (dos cuerpos que entran con 2 s de diferencia reciben lo mismo en el mismo tick); durante la rampa el daño es ≤ la mitad en su primer segundo.
- **Wall of Spikes:** el cuerpo sobre el eje queda aturdido, recibe 625 ± resistencia y su velocidad pasa a ×0,5 (`PaceFactors`) durante 360 ± 2 ticks; un segundo cruce en esos 6 s no hace nada; un cuerpo a 2,3 m del eje (> 0,4 · 5) no recibe nada; un aliado queda aturdido y frenado.
- **Wailing Wall:** el maná llega a 0 en ≤ 62 ticks (aliado o enemigo); pace ×0,75 durante 480 ± 2 ticks.
- **Vinewall:** el enemigo queda `vined` con `lay_within` (duración = el menor entre el tope del muro y la normal); un aliado no; el segundo cruce antes de los 6 s no vuelve a atar; un `ccProtected` se salta.
- **Fence:** 12 postes nacen en los ticks 16, 48, …, 176 (dos por vez); un enemigo a ≤10 m de un poste recibe un múltiplo de 625 en 30 s de simulación con la semilla de la suite; uno a >10 m de todos los postes, nada.
- **Luz:** cada escena de muro trae un `ActorLight` llamado `Light`, sin sombras, con el color de arriba (caso `*_has_its_light` y `*_light_colour`); `WallLightFollow` lo pone donde se ve.
- **Escenas:** cada acción pide `Pick.GROUND` y no avisa configuración; cada clave está en el spawner; cada escena de muro no avisa; la forma `Body` coincide con el SpellType (`x` = 2·effect_range).
- **IA:** un mago de la IA con muros en el libro sigue lanzando y la suite de IA sigue verde.
- El lint no sube; el resto de la suite sigue verde.

## Escena de verificación: `res://debug/spells/cast_walls.tscn` (F6)
- High Noon con `debug/rules/cast_walls.tres` (nivel 9, maná lleno, dios por inspector), un Trogg enemigo a 25 m, otro aliado a 30 m, un Ranger a 40 m y una Taurock a 35 m para ver el fuego, el aturdimiento, las lianas y los rayos. `spell_N` arma el muro y un clic en el suelo lo lanza.
- Captura: `bash agent/harness/godot_run.sh "$GODOT_BIN" --path . res://agent/harness/match_shots/match_shots.tscn -- --god=pyro --cast=lwrf --views=wall,overview` (ventana; lo captura el orquestador). `--cast` de un muro lanza sobre el suelo bajo el enemigo más cercano.

## Divergencias y NO VERIFICADO
- El tipo de daño del Firewall (SPEL `[+0x48]`) y qué significa «terminar de levantarse» para la rampa (por defecto: alto lleno; knob `ramp_start_s`).
- `grow_ticks` (240, 180 y 176) son constantes de sacengine con `TODO` ahí; el exe no se leyó.
- Vinewall: la animación de lianas que cae sobre el blanco al acercarse (≤0,5 · espesor) no se dibuja; el atado sí. La grilla de `pvin` (5 × 6) es una lectura del perfil.
- Wailing Wall: alto 7,5 m (SPEL) y no los 6 de sacengine; el rayo `ltng` de `sub_4363d0` queda sin dibujar (NO VERIFICADO si es el drenaje).
- Wall of Spikes: el pincho del golpe se dibuja con `SpikeField` (el lanzamiento original solo dice «sube y baja en 2/3 s»); el brillo especular del pincho lo da el material.
- Luces (regla del usuario del 2026-10-24: cada hechizo ilumina con su color): un `ActorLight` por muro (`Light`, sin sombras, rango 12-18 m) que `WallLightFollow` deja en el punto del muro más cercano al oyente (en el Fence, en el poste más cercano). Colores: Firewall el naranja (1, 0,5, 0) de la luz del exe (100 m en el exe; acá 18 m, moderado); el resto el dominante de su textura: pinchos `jspk` (0,75; 0,55; 0,35), Wailing Wall `wwal` (0,8; 0,4; 0,28), Vinewall `vine`/`pvin` (0,5; 0,72; 0,25), Fence `bubl` violeta (0,7; 0,55; 1). Los rayos del Fence ya traen su destello (`lightning_flash` del BeamType).
- Las lianas y los pinchos del muro se generan con una semilla de presentación por muro; cada peer los coloca algo distinto (solo se ven).
- Grietas SCAR: sin lector, fuera.
- `WallTouch` es un solo script con knobs para los cuatro efectos (en vez de uno por muro).

## Piezas compartidas que toqué (por si se pisan con 061e / 061f)
- `SpikeField._mesh()` pasa a estática; `Affliction.lay_within` y `Vined.lay_within` (nuevos, de 061g). Nada de `ChainHop` ni `GroundZone`.

## Orden
`WallRules` + `SpellWall` (headless, sin look) → `WallTouch` → `WallAction` y los `.tres` → casos de suite del ciclo y los cuatro efectos → `FencePosts`/`FenceZap` → malla (Blender) y shaders → looks por muro → `debug`, `match_shots` y lint.
