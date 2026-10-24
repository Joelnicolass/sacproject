# 061j — Meanstalks y Tornado — plan del corte

Fuentes: `061-spells-master-plan.md` (§1 pieza 7 `GroundZone`, fila 061j), `061R-abilities-structures.md` (filas `rter`, `nrot`), `061V-spell-visuals-j.md` (arte; el SPEL manda), `061f-zones-plan.md` (la zona que se reutiliza), sacengine `state.d` 11441-11488 y 22498-22706 (Meanstalks), 22708-22873 (Tornado), `CONVENTIONS.md` (C1-C21, §2c). Decisión del usuario: arte final desde el inicio. Regla nueva del usuario (812da7d4): **cada hechizo ilumina el entorno con su color**: los estallidos con `FxLightSpec` en el `ParticleType`, lo que dura con un `ActorLight` hijo.

## Objetivo
- **Meanstalks `rter`** (clic en el suelo, 1800 de maná, 4,4 s): cuatro tallos nacen en un anillo de 9 a 21,6 m alrededor del clic (un cuarto de vuelta cada uno con un desvío de ±22,5°), 60 m bajo el suelo, y suben mientras el mago lanza; al terminar el lanzamiento terminan de crecer (3 s). Cada tallo busca la criatura (o mago) enemiga o propia más cercana a menos de 60 m de su base que cumpla 10 ≤ distancia ≤ 45 m (con la altura contada a la mitad) y que ningún tallo del hechizo haya agarrado antes; se estira hacia ella (velocidad 30, aceleración 3), la agarra a menos de 0,1 m (500 de daño de hechizo directo, sonido de agarre), la sube hacia el tope (60 m sobre su base, velocidad 42, aceleración 4,2) con su centro en la punta y la lanza al llegar a menos de 7 m del tope con la velocidad de la punta. Sin blanco vaga hacia puntos al azar dentro de un cono de 30 m de radio y 60 de alto sobre su base (velocidad 6, aceleración 0,6). Dura 60 s y se encoge 3 s. Interrumpir el lanzamiento los hunde sin actuar.
- **Tornado `nrot`** (clic en el suelo, 1800 de maná, 3,7 s): un embudo que crece con el lanzamiento (escala hasta 0,8), pasa a 1 a 0,6 por s y vaga durante 25 s alrededor del punto del clic (objetivo al azar a `offset² · 50 m` por eje; velocidad máxima 6, aceleración 0,6; elige otro cuando llega a 1,4 m o cae fuera del suelo). Cada tick, toda criatura o mago **no volador** a menos de (radio del embudo a su altura + 30 m) del eje recibe un tirón de a lo sumo 3 m/s hacia una espiral de radio (radio + 15 m) y 2 m más arriba, sin gravedad ese tick, con tope de 30 m/s; no hace daño directo (el daño es el de la caída, `Tumbling`). Se disipa en 1,3 s.

## Escena de verificación
`res://debug/spells/cast_stalks_tornado.tscn` (F6), mismo patrón que `cast_zones.tscn`:
- Arma: High Noon, `debug/units/rock_hit.gd` como `Targets`: un Trogg enemigo a 15 m, un Druid enemigo a 25 m, un Ranger propio a 30 m, un Shrike (volador) a 35 m. Mago de nivel 9 con maná lleno (`debug/rules/cast_stalks_tornado.tres`).
- `wizard_god` en el inspector: persephone (Meanstalks) o stratos (Tornado).
- Estado inicial: ninguna zona, nadie lanzado.
- Acción: la tecla `spell_N` del hechizo (nivel 8: se confirma contra el HUD) y clic en el suelo.

## Árbol de archivos
```
scenes/spells/zones/
  [~] ground_zone.gd             + synced: PackedStringArray (propiedades de los hijos que replica). ≤150
  [~] zone_rules.gd              + ring_points(rng, center, count, inner_m, outer_m, jitter): los puntos del anillo. ≤90
  [~] README.md                  menciona stalks/ y tornado/
scenes/spells/actions/
  [~] zone_action.gd             + anchor RING (count, inner_m, outer_m, jitter_rad; la zona queda en el clic y sus puntos son las raíces), + cast_scene (CastGlow del mago). ≤150
  [+] meanstalks_action.tscn, tornado_action.tscn   ZoneAction (sin script propio)
scenes/spells/stalks/
  [+] README.md                  What / Not / Talks to / Edit / Check
  [+] stalk.gd                   Stalk (Node3D): una raíz y su punta; modos GROWING, SEARCHING, APPROACHING, HOLDING, SHRINKING; solo la autoridad; replica `tip` y `growth`. ≤150
  [+] stalk_rules.gd             static, sin árbol: curva del tallo (dos cúbicas), aceleración de la punta, filtro de blanco, punto al azar del cono, caja a punto. ≤120
  [+] stalk_grip.gd              StalkGrip (Node): agarra, sostiene en la punta y lanza un cuerpo con Tumbling/BodyNudge; un solo dueño de «quién cuelga de este tallo». ≤100
  [+] stalk_look.gd              StalkLook (MeshInstance3D): lleva `tip`/`growth` a los uniformes del shader y a la luz; la tierra al nacer. ≤90
  [+] stalk.gdshader             el tubo: anillo `v` sobre las dos cúbicas, radio 2 → 1,8 → 0, mezcla dvin/vine; con luz
  [+] stalk_tube.res             malla horneada por tools/bake/make_stalk_tube.gd (31 segmentos × 24 lados)
  [+] stalk.tscn                 Stalk ├ Grip ├ Look(MeshInstance3D) ├ Dirt(SpriteEmitter) ├ Light(ActorLight) ├ Sounds
  [+] meanstalks.tscn            GroundZone(spell=rter, synced) └ Stalk ×4 (índice 0 a 3)
scenes/spells/tornado/
  [+] README.md
  [+] tornado_rules.gd           static: updateCurve (7 puntos, 7 radios), getCentre, wander, lift. ≤130
  [+] tornado_drift.gd           TornadoDrift (Node): vaga; dueño de la posición y de `size` (escala); replica ambas. ≤110
  [+] tornado_lift.gd            TornadoLift (Node): cada tick levanta y lanza lo que está dentro. ≤100
  [+] tornado_look.gd            TornadoLook (Node3D): pasa el eje, los radios, el giro y el alfa a los tres materiales; polvo; luz. ≤110
  [+] tornado_funnel.gdshader    embudo (modo cuerpo/borde, mitad de arriba/abajo)
  [+] funnel_rings.res, funnel_edge.res   mallas horneadas por tools/bake/make_tornado_funnel.gd
  [+] tornado.tscn               GroundZone(spell=nrot, synced) ├ Drift ├ Lift ├ Look(Upper, Lower, Edge, Dust, Light) └ sonidos
  [+] tornado_cast_glow.tscn     CastGlow con cst0
scenes/spells/[~] spell_spawner.gd (no: las zonas se registran en match.tscn, como 061f)
scenes/match/[~] match.tscn      zones += Meanstalks, Tornado
data/catalog/spells/[~] rter.tres, nrot.tres   action = su escena; (Meanstalks: no se guarda amount3)
data/gods/[~] persephone.tres, stratos.tres    + rter, + nrot en `spells`
data/fx/[+] stalk_dirt.tres, stalk_grab.tres (con FxLightSpec en data/fx/lights/), tornado_dust.tres, tornado_cast.tres
data/audio/[~] fx_sounds.tres    + stalk_rise (stka), stalk_grab (stkh), stalk_fall (stkf), tornado_loop (torn), tornado_cast (trns)
assets/original/fx/[+] dvin, trn1, trn2, edge, tdst (.png)   tools/import/import_ui.py EXTRA_FX
tools/bake/[+] make_stalk_tube.gd, make_tornado_funnel.gd
debug/spells/[+] cast_stalks_tornado.tscn ; debug/rules/[+] cast_stalks_tornado.tres
debug/suite/[+] stalk_cases.gd, tornado_cases.gd ; [~] zone_case_base.gd (+2 kinds), zone_run.gd/.tscn, rules_suite.gd
agent/harness/match_shots/[~] match_shots.gd   --cast=rter|nrot: vista `zone` y reporte de tallos / posición del tornado
tools/lint/[~] baseline.txt (solo si algún conteo baja)
```

**Fuera del corte:** la cicatriz `mean` del suelo (no hay lector de SCAR); el temblor de pantalla del crecimiento (el sistema de shake del port es por tipo de partícula: se pone en `stalk_dirt`); que un edificio o criatura bloquee la raíz (sacengine reintenta hasta 32 veces a 18 m: aquí una raíz fuera del suelo o dentro de un cuerpo se corre con las mismas 32 vueltas, pero sin consultar edificios, **divergencia declarada**); la IA no los lanza (`ai_use = NONE`, se confirma que vale 0).

## Tipo / nodo / instancia
- **Resource de tipo:** `rter.tres` y `nrot.tres` (todos los números: daño, alcances, velocidades, duración) y cada `ParticleType` (con su `FxLightSpec`).
- **Nodos:** cada tallo es una escena `Stalk` hija de `meanstalks.tscn` (se arrastra con gizmo; el tope de 4 es la cantidad de hijos); el embudo y su luz son nodos de `tornado.tscn`. Posiciones: `Marker3D` para el punto de luz de cada uno; las raíces de los tallos se calculan al lanzar (son azar de la partida, `MatchSeed`).
- **`@export` de instancia:** tiempos de la zona (`hold_is_spell_duration`, `end_s`), alcances del tallo (`pick_min_m`, `pick_max_m`, `catch_m`, `release_m`), tasas (`search_rate`, `grab_rate`), `lift_margin_m`, `spin_s`, `energy`, `opacity` del embudo.

## Dueños y red
- **`GroundZone` es el dueño del reloj y de la fase** (como 061f). **`Stalk` es el único dueño de su punta, su crecimiento y de a quién agarra**; **`StalkGrip` el único que mueve al cuerpo colgado** (entre el agarre y el lanzamiento nada más lo mueve). **`Tumbling` es el único que lanza** (el tallo y el tornado le piden `catapult`/`drive`/`lift`). **`TornadoDrift` es el único dueño de la posición y del tamaño del tornado**; `TornadoLift` y `TornadoLook` los leen.
- Red: `Caster.request_cast` → `submit_cast` → en el host `ZoneAction.started/finish` → `SpellSpawner.spawn_projectile` (la zona es un `SpellProjectile`) → solo el host corre tallos, deriva y tirón; la zona replica `phase`, `cancelled` y los `synced` (`StalkN:tip`, `StalkN:growth`; `.:position` y `Drift:size` del tornado); cada par dibuja el tubo y el embudo desde esos datos. Las fases del viento (balanceo y giro) salen de los ticks propios de cada par y una semilla del spawn. El sonido de agarre y la tierra al nacer viajan por `FxBus.broadcast`. Un par que entra tarde ve los tallos y el tornado donde están (`late_join`).
- Orden en el tick: la zona avanza primero (`process_physics_priority` -1); los tallos y el tornado actúan en prioridad -1 también y los cuerpos corren después; `Tumbling` ya corre después del cuerpo.
- Autoridad de los hijos: el `MultiplayerSynchronizer` de la zona agrega los paths de sus hijos; no hay uno por tallo.

## Criterios (suite `stalk_cases` y `tornado_cases`)
Mediciones con `--fixed-fps 600`; las duraciones largas del dato se prueban con el dato aparte.
- **Reglas (`stalk_rules`, `tornado_rules`):** la curva termina en la base y en la punta; la panza de un tallo de 60 m de largo es 0 y la de uno de 30 m es `0,5·(√675 + ⁴√675)`; el filtro de blanco acepta 10 y 45 m y rechaza 9,9 y 45,1; el radio del embudo en el pie es 1,5 y en la cima 300; `getCentre` en la cima devuelve el punto 0; el tirón nunca pasa de 3 m/s por tick ni de 30 m/s.
- **Meanstalks, escenas:** el hechizo `rter` tiene acción, cabe en el libro de Persephone, la zona está registrada y no hay warnings; la zona tiene 4 hijos `Stalk`; `ai_use = NONE` y el evaluador de la IA da 0.
- **Meanstalks, anillo:** las 4 raíces caen a 9 ≤ d ≤ 21,6 m del clic (± la tolerancia del reintento) y a ≥ 45° ± 22,5° unas de otras.
- **Meanstalks, crecimiento:** durante el lanzamiento la punta de cada tallo sube con el progreso; 180 ± 1 ticks después de soltar el lanzamiento `growth == 1`; interrumpir el lanzamiento: ningún daño y la zona termina en `end_s`.
- **Meanstalks, agarre:** un Druid enemigo a 20 m de una raíz queda agarrado: recibe 500 × resistencia ± 1 %, entra en `Tumbling`, su centro sigue a la punta (≤ 0,5 m de error por tick) y a menos de 7 m del tope es lanzado con la velocidad de la punta (|v| ≥ 5 m/s y componente vertical positiva). Nunca agarra dos veces al mismo cuerpo. Uno a 5 m o a 46 m de la raíz no se agarra. Con un blanco sostenido el tallo no busca otro. Un cuerpo `fixed` (congelado) no se agarra.
- **Meanstalks, duración:** 3600 ticks ± 1 desde el fin del lanzamiento hasta que empieza a encogerse; después `end_s` y la zona se libera.
- **Tornado, escenas:** igual (acción, libro de Stratos, registro, sin warnings, IA 0).
- **Tornado, deriva:** durante 25 s la posición queda a ≤ 50 m ± 1 del punto, la velocidad nunca pasa de 6 m/s, y con `MatchSeed` fijo la trayectoria es la misma en dos corridas (los 4 primeros puntos de paso).
- **Tornado, tirón:** un Druid a 20 m del eje (radio 1,5 en el suelo) sube (Tumbling activo, y > inicio) en ≤ 120 ticks; uno a 40 m no se mueve; un volador a 5 m no se mueve; un cuerpo `fixed` no se mueve; ningún cuerpo supera 30 m/s; el tornado no hace daño directo (la vida cambia solo por caída).
- **Tornado, duración:** `ceil(60 · 25)` = 1500 ticks ± 1 en ACTIVE y después se disipa (el tamaño llega a 0) y la zona se libera. Interrumpir el lanzamiento: nadie es levantado.
- **Luz:** cada tallo y el tornado tienen un `ActorLight` sin sombras de color distinto de blanco; `stalk_grab` tiene `FxLightSpec`; el lint no cuenta `Light.new(`.
- **Lint:** ningún conteo sube; los scripts nuevos ≤150 líneas.
- **Antes/después visual:** no se verifica sin ventana. El comando de captura queda en los README.

## Orden
1. Importar texturas (hecho: `import_ui.py`); hornear las tres mallas.
2. `GroundZone.synced`, `ZoneRules.ring_points`, `ZoneAction` (anillo y casting) y el registro en `match.tscn` con cajas sin arte.
3. Tornado (reglas → deriva → tirón → suite) y su arte (shader, polvo, luz, sonidos).
4. Meanstalks (reglas → tallo → agarre → suite) y su arte.
5. Libros, `cast_stalks_tornado.tscn`, `match_shots`, READMEs, lint, suite completa.

## Riesgos
- Sin ventana no se ve nada: los shaders se validan con la carga headless y los números; la captura con ventana es del orquestador.
- `GroundZone` y `ZoneAction` los tocan también 061g/061h: conflicto probable en `zone_action.gd`, `zone_rules.gd` y `match.tscn` (una línea por zona).
- Tamaño (C1): `stalk.gd` es el script más cercano a 150 líneas; el agarre y la curva viven en `StalkGrip` y `StalkRules`.
- Un cuerpo colgado a 60 m: `Tumbling` lo aterrizaría si `velocity.y ≤ 0` y bajo el suelo; mientras se le da la velocidad de la punta (hacia arriba) no ocurre. Si el tallo muere (zona cancelada o fin de tiempo) mientras sostiene, `StalkGrip` lo suelta en el acto con la velocidad que tiene.
- Dos escritores de la posición del agarrado (el tallo y el cuerpo): la regla es que solo `StalkGrip` escribe `global_position` del colgado y lo hace después del paso del cuerpo (prioridad de física +1).

## Desvíos al implementar
- **Cast de Meanstalks:** el SPEL no trae `tcst`, y sacengine usa la partícula `heal` en las manos del mago: es el `cast_fx = "heal"` de la acción (el mecanismo `HandFx` que ya existe), no una escena `CastGlow` nueva. Tornado sí lleva `cast_scene` (la espiral `cst0`).
- **Piezas que el plan no nombraba:** `StalkHunt` (la elección de presa y las velocidades de la punta; saca esas líneas de `Stalk`, que ya llegaba a 150), `StalkRoster` (quién fue agarrado en este hechizo, uno por zona), `TornadoWinds` (los cuatro ángulos del viento, una sola fuente para `Lift` y `Look`). No hizo falta `hold_extra_s` ni `age_ticks` en `GroundZone` (que ya estaba en 150 líneas): con un lanzamiento real los tallos están crecidos al soltarlo, así que los 60 s de caza se cuentan desde ahí; los giros del viento los cuenta `TornadoWinds`.
- **Duración de los tallos:** manda el dato (60 s). sacengine resta dos veces el temporizador (state.d:22667 y 22689-22690): NO VERIFICADO si el exe también lo hace.
- **Sin cicatriz `mean`, sin temblor de pantalla al crecer** (como declaraba el plan).
- **Arte de la ranura 0/1 del tallo:** NO VERIFICADO, ver `061V-spell-visuals-j.md`.
