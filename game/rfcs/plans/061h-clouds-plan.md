# 061h — Nubes (Rain of Frogs, Rain of Fire, Plague, Cloudkill, Bombardment) — plan del corte

Fuentes: `061-spells-master-plan.md` (§1 pieza 7 `GroundZone` + `ZoneDropper` y `ZoneMover`; fila 061h), `rfcs/research/061R-abilities-structures.md` (REA manda: Cloudkill), `rfcs/research/061V-spell-visuals-h.md` (el arte: SPEL > exe > sacengine), `061f-zones-plan.md` (la zona que se reutiliza), sacengine (`state.d` 3462-3507, 3994-4084, 4228-4248, 11025-11063, 11331-11339, 19324-19504, 20897-21053, 21055-21421, 22036-22108; `renderer.d` 451-475, 1830-1858, 2080-2083, 2459-2516, 3318-3336) y `CONVENTIONS.md` (C1-C21 y §2c). Decisión del usuario: arte final desde el inicio.

Reglas de este corte que mandan sobre el plan maestro:
- **Bombardment va sin abolladuras** (061k). Hace daño, aturde y tiembla la pantalla; el suelo no se toca.
- **Las gotas son escenas, no clases por hechizo.** Un `ZoneDrop` genérico (vuelo + contacto) con hijos que dicen qué hace al llegar (`DropBlast`, `DropPoison`, `FrogHop` + `FrogCling`). Los números de daño viajan en los datos del spawn (como en `RiftSpirit`): la escena de la gota no apunta a ningún `SpellType` y puede ir en `SpellSpawner.projectiles` sin cerrar el círculo de carga que ya vimos en 061f. Las cinco zonas sí apuntan a su `SpellType` y van en `SpellSpawner.zones` (`match.tscn`).
- El SPEL manda sobre sacengine: Plague deja `freg = 0` (el envenenado no regenera).

## Objetivo
Todos los números de 061R/SPEL; las distancias de desvío (10/25 m, 2/3) y la gravedad (30, y 20 en Bombardment) son de sacengine (NO VERIFICADO contra el exe).
- **Rain of Frogs `grfr`** (clic en el suelo, 2,47 s de lanzamiento): una nube negra de 50 m de radio a 90 m sobre el clic crece mientras el mago lanza. Al terminar suelta 10 ranas por segundo durante 20 s. Cada rana nace sobre un punto al azar del disco de 50 m (o sobre una criatura cercana), cae (−45 m/s, gravedad 30), se sienta 0,5 s y salta hacia la criatura más cercana a ≤ 50 m, hasta 7 saltos. Si toca una criatura que se puede infectar se pega: frena ×0,6 por rana y a los 5 s explota (90 de hechizo al cuerpo, salpicadura de 5 m).
- **Rain of Fire `rifr`** (3,7 s): nube de 25 m. 3 gotas por segundo durante 20 s; cada una nace en el disco de 25 m de la nube y vuela sin gravedad en línea recta 1,4 s hasta un punto del disco de 50 m en el suelo (o una criatura). Al tocar suelo o criatura: 500 de hechizo, salpicadura de 5 m, fuego de 1 s en todos los alcanzados, sonido `Xfbx`, y la nube de explosión de fuego.
- **Plague `galp`** (3,7 s): nube de 50 m. 3 gotas por segundo durante 20 s, que caen como las ranas. Al tocar suelo o criatura infectable: veneno **contagioso** de 62,5/s durante 10 s al tocado y de `6,25 × (1 − d/5)`/s a los de ≤ 5 m, sin regeneración (SPEL `freg 0`).
- **Cloudkill `likc`** (3,95 s; clic en el suelo o en una criatura): una nube azul de 5 m de radio, a 22 m sobre el centro del blanco, crece en 4,3 s, **persigue** al blanco a 3 m/s y dura 30 s. Tira ≈ 2 rayos por segundo (verificado REA) a un punto del disco de 47,5 m bajo ella, o a un cuerpo cercano (siempre a ≤ 15 m, una de cada dos a ≤ 50 m). Cada rayo hace 900 de hechizo al cuerpo que toca y salpicadura de 5 m.
- **Bombardment `rtem`** (3,95 s; alcance 150 m): sin nube. 2 meteoritos por segundo durante 20 s; cada uno sale de la tierra (1 m bajo el suelo) a ≤ 12,5 m del mago y cruza el cielo en un arco de **12 s** hasta un punto del disco de 50 m alrededor del clic (o una criatura). Al llegar (solo bajando): 400 de hechizo al blanco, salpicadura de 5 m que **aturde** 8 s, 100 piedras y polvo, temblor de pantalla. **Sin abolladura.**
- Cortar el lanzamiento: la nube se achica a 1/s y no cae nada.

## Escena de verificación
`res://debug/spells/cast_clouds.tscn` (F6), el patrón de `cast_zones.tscn`:
- Arma: High Noon, `debug/units/rock_hit.gd` como `Targets`: un Trogg enemigo a 25 m, un Ranger a 35 m, un Shrike (volador) a 30 m, más un Druida propio a 12 m. Mago de nivel 8 con maná lleno (`debug/rules/cast_clouds.tres`).
- `wizard_god` en el inspector: persephone (Frogs), pyro (Fire), charnel (Plague), stratos (Cloudkill), james (Bombardment).
- Estado inicial: ninguna nube, nadie afectado.
- Acción: la tecla `spell_N` del libro y clic en el suelo (Cloudkill: sobre una criatura).

## Árbol de archivos
```
scenes/spells/zones/                        (la carpeta de 061f)
  [~] README.md                             + nubes
  [~] ground_zone.gd                        + replicates_position (la zona se mueve: Cloudkill) y follow_path (el blanco que persigue). ≤150
  [+] zone_dropper.gd                       ZoneDropper (Node, hijo de la zona): servidor; en ACTIVE decide cuándo (tasa por segundo, resto por azar) y dónde
                                            (punto al azar de un disco, o una criatura cercana); emite chosen(point, body). ≤120
  [+] drop_launcher.gd                      DropLauncher (Node): escucha chosen y spawnea una gota por SpellSpawner: de dónde sale (sobre el punto / disco de la nube
                                            / disco del mago bajo tierra), en cuánto llega y con qué gravedad; le pasa los números del hechizo. ≤100
  [+] bolt_launcher.gd                      BoltLauncher (Node): escucha chosen y lanza un LightningStrike desde la nube; al pegar reparte la salpicadura. ≤80
  [+] zone_mover.gd                         ZoneMover (Node): servidor; la zona persigue el centro de su blanco a `spell.speed` (tope) y se queda cuando llega. ≤70
  [+] cloud_look.gd + cloud_sphere.gdshader CloudLook (Node3D): 20 capas (MultiMesh) de una esfera ruidosa translúcida que crece/achica con la fase de la zona;
                                            negra sin textura o con atlas (clou). ≤90
  [+] rain_of_frogs.tscn   GroundZone(grfr) ├ CloudAt(Marker3D 90 m) ├ Cloud(CloudLook) ├ Dropper └ Launcher(RainFrog) └ sonidos
  [+] rain_of_fire.tscn    GroundZone(rifr) ├ CloudAt ├ Cloud(r 0,5) ├ Dropper ├ Launcher(FireDrop, disco de la nube 0,5) └ sonidos (flp5 en lazo, cldl)
  [+] plague.tscn          GroundZone(galp) ├ CloudAt ├ Cloud ├ Dropper └ Launcher(PlagueDrop)
  [+] cloudkill.tscn       GroundZone(likc, replicates_position) ├ CloudAt(22 m) ├ Cloud(clou, 5 m) ├ Mover ├ Dropper(2/s, 0,95 R) └ Bolts(BoltLauncher) └ sonidos (cldl)
  [+] bombardment.tscn     GroundZone(rtem) ├ Dropper(2/s) └ Launcher(Meteor, desde el mago, 12 s, g 20) └ sonidos (Xquk en lazo)
scenes/spells/drops/                        (sistema nuevo: lo que cae, vuela o salta de una zona)
  [+] README.md                             What / Not / Talks to / Edit / Check
  [+] zone_drop.gd                          ZoneDrop extends SpellProjectile: vuelo con gravedad, suelo y contacto con un cuerpo vivo infectable; estados FLYING / RESTING /
                                            ATTACHED; señales landed, touched, ended; replica position y status. ≤150
  [+] drop_blast.gd                         DropBlast (Node): al terminar la gota: daño directo + salpicadura (+ fuego, + aturdir) y sus FX/sonidos. ≤110
  [+] drop_poison.gd                        DropPoison (Node): al terminar la gota: veneno contagioso al tocado y salpicadura de veneno a los cercanos. ≤90
  [+] frog_hop.gd                           FrogHop (Node): sentada 0,5 s, salto hacia la criatura más cercana, hasta 7 saltos; luego explota. ≤110
  [+] frog_cling.gd                         FrogCling (Node): al tocar un cuerpo se pega (Clinging ×0,6), explota a los 5 s o si el cuerpo ya no puede. ≤90
  [+] frog_look.gd                          FrogLook (Node, todos los peers): el cuadro del atlas según el estado (caída 11, salto 0..15, sentada 15) y el croar. ≤70
  [+] rain_frog.tscn                        ZoneDrop(g 30, contacto 0,5 m, descansa) ├ Sprite(AtlasSprite fhop) ├ Hop ├ Cling ├ Blast(90, 5 m, brst, Xfrx) └ Look
  [+] fire_drop.tscn                        ZoneDrop(g 0, contacto 1,5) ├ Sprite(AtlasSprite bbrd 6,9 m, aditivo) ├ Trail(FxTrail firy) └ Blast(500, 5 m, ignite 60, Xfbx, explosión)
  [+] plague_drop.tscn                      ZoneDrop(g 30, contacto 1,5) ├ Sprite(AtlasSprite pois) ├ Trail(blood) └ Poison(62,5/s, 10 s, 5 m, bldx, dish)
  [+] meteor.tscn                           ZoneDrop(g 20, contacto 3 m, solo bajando) ├ Spin ├ Rock(MeshInstance3D rock ×1,875) ├ Trail(dirt) └ Blast(400, 5 m, stun 480, Xmht, rocas, temblor)
scenes/fx/
  [+] atlas_sprite.gd + atlas_sprite_add/_mix.gdshader + atlas_sprite.gdshaderinc   AtlasSprite (MeshInstance3D): un quad de atlas con billboard y `frame`, aditivo o mezcla. ≤60
  [+] spinner.gd                            Spinner (Node3D): gira sola sobre un eje al azar. ≤40
scenes/units/abilities/
  [~] lightning_strike.gd                   + signal struck(body, at): al golpear (también el suelo), para que la salpicadura la reparta quien lo lanzó. +2 líneas
scenes/units/status/
  [~] clinging.gd                           + FROGS (×0,6; sin look); `shown` pasa de Vector2i a Vector3i. ≤ lo que tenía
scenes/spells/
  [~] spell_spawner.gd                      + RainFrog, FireDrop, PlagueDrop, Meteor en `projectiles` (las gotas no apuntan a ningún hechizo)
  actions/
    [+] rain_of_frogs_action.tscn, rain_of_fire_action.tscn, plague_action.tscn, cloudkill_action.tscn, bombardment_action.tscn   ZoneAction (sin script propio; knobs)
    [~] zone_action.gd                      + follows_target (el blanco clicado viaja en los datos como `follow`); knob `kind` ya existe. ≤ lo que tenía
scenes/match/[~] match.tscn                 SpellSpawner.zones + RainOfFrogs, RainOfFire, Plague, Cloudkill, Bombardment
data/catalog/spells/[~] grfr, rifr, galp, likc, rtem .tres   action = su escena; ai_use = NONE
data/gods/[~] persephone, pyro, charnel, stratos, james .tres   + el hechizo en `spells` (sumar con las listas de 061e y 061g al hacer merge)
data/fx/[+] frog_cast, frog_burst, fireball_blast, fireball_blast2, fireball_ash, fireball_smoke, fire_drop_trail, poison_cast, plague_trail,
            meteor_rocks, meteor_dirt, meteor_trail  (.tres de ParticleType; reutiliza explosion_*, dirt_cast, rock_emerge, rock_dust, poison)
data/fx/lights/[+] frog_burst, fireball_blast, meteor_hit .tres (FxLightSpec)
data/fx/shake_map.tres                      + meteor_hit, meteor_emerge
data/audio/fx_sounds.tres                   + cues: frog_burst (frx), plague_burst (bldx), plague_hit (dish), fireball_blast (fbx), meteor_hit (mht), meteor_emerge (spt3),
                                            cloud_loop (cldl), bombardment_loop (eqk), cloudkill_bolt ya existe (lightning)
assets/original/fx/                         fhop, frgl, brst, bbrd, clou   (tools/import/import_ui.py EXTRA_FX; los PNG y sus .import)
debug/spells/[+] cast_clouds.tscn ; debug/rules/[+] cast_clouds.tres
debug/suite/[+] cloud_cases.gd (+ cloud_case_base.gd si hace falta) ; [~] rules_suite.gd ; zone_case_base.gd registra las zonas nuevas
agent/harness/match_shots/[~] match_shots.gd   --cast: las nubes van al suelo cerca del enemigo; vista `zone` desde arriba con la nube; reporte (zonas, gotas, rayos)
tools/lint/[~] baseline.txt (solo si algun conteo baja)
```

**Fuera del corte:** las abolladuras de Bombardment (061k), la cicatriz `scar`/`gscr`/`ecrk` de rayos y meteoritos (no hay lector de SCAR), las luces dinámicas del exe, las partículas `frck` en el aire de Rain of Fire (cantidad NO VERIFICADO), la malla `rokm` (NO VERIFICADO si es la del exe), `iacc`/`fspd` de Plague (el port no los modela) y la IA (`ai_use = NONE`: se confirma que vale 0 o que el evaluador no se rompe).

## Tipo / nodo / instancia
- **Resource de tipo:** el `SpellType` `.tres` de cada hechizo (daño, rangos, duración, velocidad) y el `ParticleType` de cada partícula. `ZoneDropper`/`DropLauncher` leen la zona (`@export var zone`) y esta su `SpellType` (C18); el daño viaja en los datos del spawn.
- **Nodos:** la nube, el dropper y el launcher son hijos de la zona; la gota es una escena con sus efectos hijos. Alturas por `Marker3D` (`CloudAt`, C16); la forma de la nube es un `squash` del nodo.
- **`@export` de instancia:** tasa, radio de salida, gravedad, tiempo de caída, contacto, tamaño de sprite, chance y distancias del desvío, fuego, aturdir, veneno, partículas, sonidos.
- **Dónde se edita un hechizo:** su `.tres` (números) y su escena de zona y de gota (cómo se ve y cuándo actúa).

## Dueños y red
- **`GroundZone` es el único dueño del reloj y de la fase** (como en 061f); `ZoneDropper` solo lee la fase y sortea; `ZoneMover` es el único que escribe la posición de la zona (en el servidor; `position` replicado).
- **`ZoneDrop` es el único dueño de la posición, la velocidad y el estado de una gota**; `FrogHop` le pide un salto (`launch`), `FrogCling` le pide pegarse (`attach`) y ninguno la mueve. `Clinging` es el único que cuenta las ranas pegadas y da el factor de velocidad a `PaceFactors`. `Poisoning` es el único que envenena. `LightningStrike` es el único que golpea con rayo. `SplashDamage` reparte toda la salpicadura.
- **Un sorteo por nodo con `MatchSeed`:** cada `ZoneDropper` y cada gota con azar usan `MatchSeed.rng([nombre, …])`, así que dos corridas de la misma semilla dan lo mismo.
- **Red:** `Caster.request_cast` → `submit_cast` → en el host `ZoneAction.started` crea la zona por `SpellSpawner.spawn_projectile` (`phase`, `cancelled` y, en Cloudkill, `position` replicados) → solo el servidor corre el dropper, el mover y las gotas; cada gota nace por `MultiplayerSpawner` con `position` y `status` replicados (las gotas no se simulan en el cliente). La nube, el sprite de la rana y el temblor se dibujan en cada peer desde esos datos; las explosiones, el rayo y los sonidos de impacto salen por `FxBus.broadcast*` (un RPC por evento). En un servidor dedicado o headless no se dibuja nada.

## Criterios (suite `cloud_cases`; las zonas de prueba duran poco y el dato largo se comprueba aparte)
- **Hechizos:** los cinco tienen `action` (una `ZoneAction` sin warnings, `kind` registrado en el spawner), están en el libro de su dios, `ai_use = NONE` y el evaluador de la IA no se rompe.
- **Tasa** (semilla fija): en 10 s de ACTIVE nacen `rate × 10` ± 25 % gotas (Frogs 100, Fire 30, Plague 30, Bombardment 20) y Cloudkill 20 rayos ± 25 %. Ninguna gota nace antes de ACTIVE (ni durante el lanzamiento) ni después de `duration`.
- **Zona:** nube a `CloudAt` = 90 m (22 m en Cloudkill) sobre el suelo del clic; la zona dura `ceil(60 × duration)` ticks ± 1 y se libera 0,5 s después de achicarse (la nube baja a 1/s). Cancelar en CASTING: ninguna gota, la zona se libera.
- **Frogs:** una rana sin criatura cerca aterriza a `82 ± 2` ticks de nacer (90 m con v0 −45 y g 30); salta a los 30 ticks de sentarse; tras 7 saltos explota. Una rana que toca a una criatura la pega: su `speed_factor` baja a 0,6 (dos ranas: 0,36); explota a `300 ± 2` ticks y el cuerpo pierde `90 × resistencia ± 1 %`; sin criatura no hace daño. Un cuerpo no infectable no la recibe.
- **Fire:** el vuelo dura `84 ± 2` ticks (1,4 s); nace a ≤ 25 m del eje y cae a ≤ 50 m; sin gravedad (la altura es lineal). Un cuerpo en el centro pierde `500 × resistencia ± 1 %`; uno a 2,5 m de caja, `250 × resistencia`; todos los alcanzados tienen `Burning`.
- **Plague:** la gota llega a `82 ± 2` ticks; el tocado tiene `Poisoning.damage_sum() = 62`, dura 600 ticks y contagia; uno a 2,5 m de caja recibe 3/s (`int(6,25 × 0,5)`); la regeneración del envenenado es 0.
- **Cloudkill:** la nube queda a `centro + 22 m` ± 0,05 m cuando llega; se mueve ≤ 3 m/s y ≤ `3/60` m por tick; sigue a un blanco que camina. Un cuerpo bajo el rayo pierde `900 × resistencia ± 1 %` a los 12 ticks del rayo; uno a 3 m del punto, `900 × (1 − 3/5) × resistencia`; el rayo a un punto del suelo (sin cuerpo) solo reparte salpicadura.
- **Bombardment:** el meteorito sale a ≤ 12,5 m del mago y 1 m bajo el suelo; aterriza a `720 ± 2` ticks; solo choca bajando; 400 × resistencia ± 1 % al tocado; los de ≤ 5 m quedan `Stunned`; la altura del terreno en el punto de impacto **no cambia**.
- **Luz (regla del usuario: cada hechizo ilumina con su color):** los estallidos (`frog_burst` verde, `fireball_blast` naranja, `meteor_hit` polvo cálido) llevan un `FxLightSpec` en su `ParticleType` (data/fx/lights/*.tres, sin sombras); las nubes y las gotas de fuego llevan un `ActorLight` hijo (Fire naranja, Cloudkill azul, Frogs verde, Plague oliva) y el rayo de Cloudkill ya usa `lightning_flash`. Color: el dominante de la textura (el exe empuja luces de 0x44ca20 solo en otros hechizos); energía y alcance moderados. Caso `cloud_lights`: cada escena tiene su luz o su `light` y ninguna proyecta sombra.
- **Lint:** ningún conteo sube; los scripts nuevos ≤ 150 líneas; READMEs con What/Not/Talks to/Edit/Check.
- **Antes/después visual:** no se verifica sin ventana (se captura con `match_shots`; el comando queda en el README).

## Orden
1. Importar `fhop`, `frgl`, `brst`, `bbrd`, `clou` (EXTRA_FX) y escribir sus `.tres` de partículas.
2. `GroundZone` (follow/position), `ZoneDropper`, `DropLauncher`, `ZoneDrop` con su estado y sus señales, y `ZoneAction.follows_target`. Zona sin arte + gota con un cubo.
3. Frogs (`FrogHop`, `FrogCling`, `Clinging.FROGS`) → suite → arte (`AtlasSprite`, `FrogLook`, nube).
4. Fire (`DropBlast`) → suite → arte. Plague (`DropPoison`) → suite → arte.
5. Bombardment (meteorito, aturdir, temblor) → suite → arte.
6. Cloudkill (`ZoneMover`, `BoltLauncher`, `LightningStrike.struck`) → suite → arte (nube azul).
7. Libros, `match.tscn`, `cast_clouds.tscn`, `match_shots`, READMEs, lint, suite completa.

## Riesgos
- **Muchos nodos replicados:** las ranas llegan a ~100 vivas. Cada gota lleva su `MpReplicate` con solo `position` y `status`. Si pesa, las gotas que caen o vuelan en línea (Fire, Plague, Bombardment) podrían simularse en el cliente: queda como mejora.
- **Contacto por consulta física:** una consulta de forma por gota y por tick. Se hace solo bajo `contact_height_m` (30 m) del suelo; las gotas altas no consultan.
- **Cargas circulares:** las zonas van en `match.tscn` (`zones`) y las gotas en `projectiles` (sin `SpellType`). El caso `cloud_scenes` carga los cinco hechizos para vigilarlo.
- **Tamaño de `lightning_strike.gd` (176 líneas, ya fuera de C1a):** solo gana dos líneas; no es un infractor nuevo.
- **Contratos sin probar contra el exe:** distancias de desvío (10/25 m, 2/3; Cloudkill 15/50, 1/2), gravedad de las gotas (30; 20 en Bombardment), cómo entra `acceleration` 0,3 de Cloudkill (se aplica como aceleración por tick con tope `speed`), significado de `Xquk!`/`cldl!`/`cldf`/`clod`, sonido `Xfrx` de la explosión de rana, y la malla `rokm`. Cada uno es un campo de una escena.

## Desvíos al implementar
- **Contacto sin consulta física:** `ZoneDrop` usa `BodyNudge.bodies_in` (cajas) y `Poisoning.can_be_poisoned()` como filtro de «infectable», no `intersect_shape`; sigue la compuerta de 30 m de altura.
- **El splash de Cloudkill lo reparte `BoltLauncher`** al recibir `LightningStrike.struck` (señal nueva, también para rayos al suelo); `LightningStrike` solo ganó la señal.
- **La velocidad de salida vive en `ZoneRules.launch_velocity`** (arco que cae a tiempo con `lobbed`, línea recta si no) y `ZoneDrop.setup` la calcula con su propia gravedad: el lanzador pasa `goal` y `fall_s`, no una velocidad.
- **Piezas genéricas nuevas en `scenes/fx/`:** `AtlasSprite` (cuadro de atlas que mira a la cámara, con `fps` propio), sus dos shaders y `Spinner`; `ZoneGround` (altura del terreno o un valor de reserva) en `zones/`.
- **Tolerancia de la tasa:** la cuenta de gotas por segundo es un sorteo; el criterio es el mayor de ±25 % o 3 sigmas (`3 × √(tasa × s)`), no ±25 % a secas.
- **`Clinging.shown` pasa de `Vector2i` a `Vector3i`** (z = ranas); el path de replicación no cambia.
- **Los lazos `cldl` (nubes de Fire y Cloudkill) y `Xquk` (Bombardment) y el `Xfrx` de la rana son lectura del SPEL** (NO VERIFICADO qué evento los toca); cada uno es una `ZoneSound` o un cue de una escena.
- **El mago del test de casos es de nivel 8** (`wizard_level`); la prueba de Cloudkill lanza rayos con `BoltLauncher._launch` directo y deja la zona sin liberar para que su propio dropper no tire rayos al azar sobre los cuerpos medidos.
- **Pruebas:** `debug/suite/cloud_cases.gd` (`cloud_scenes`, `cloud_rules`, `cloud_rates`, `cloud_frog`, `cloud_fire`, `cloud_plague`, `cloud_meteor`, `cloud_cloudkill`, `cloud_cast`, `cloud_ai`, `cloud_lights`), con `--case=<nombre>` para correr uno.
