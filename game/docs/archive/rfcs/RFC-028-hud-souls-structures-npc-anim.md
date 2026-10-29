# RFC-028 — Estadísticas del mago como en el original, vida de edificios al hacer clic y animaciones de NPC

Estado: plan del tech lead (Opus); preguntas resueltas por el orquestador por delegación del usuario (P1 = a, P2 = b, P3 = b). Arquitectura estándar; MP con dedicado. Features: **F92** = 028a, **F93** = 028b, **F94** = 028c (independientes).

Pedido: «el HUD del contador de almas (en lugar de mostrar texto); mostrar las barras de vida de edificios y árboles y estructuras cuando se hace clic (y dañarlos); agregar animaciones a NPCs».

## 0. Premisas corregidas
1. El pedido reemplaza «Vida/Maná/Almas» de RFC-025 P3; «Mago · Dios», «Fantasma», avisos y resultado siguen como texto.
2. **Los clips de Farmer y Taurock no están en el caché**: `anim_mesh_clips_f37.json` no tiene `epez` ni `eber` (`tools/export_stats.py:_collect_mesh_clip_tags` solo exporta convocables y `dcas`). En la instalación sí [verificado]: Farmer `PEi1` 34, `PEi2` 65, `PErn` 32, `PEa1` 26, `PEcw` 56 (encogerse), `PEtc` 56 (hablar encogido), `PEdi` 198 (cavar), `PEpu` 445, `PEp2` 93, `PEpd` 65, `PEd1` 66 (muerte); Taurock `BEi1` 29, `BErn` 23, `BEa1` 55, `BEa2` 72, `BEd1` 38. Ranuras CRE8 (`animations.d`): 32 encogerse, 33 tirar, 34 tirar 2, 35 cavar, 36 tirar abajo, 37 hablar encogido, 19 muerte.
3. **Los «árboles» con vida de High Noon son los 31 cactus `jcc1..4`** (BLDG, 1000 de vida), ya `MapBuilding` atacables (F73). Los widgets de `map_props.gd` son `FixedObject` en sacengine (`placeWidgets`, `state.d:31346-31357`): sin vida ni blanco. **Decisión fiel: los widgets no se dañan.**
4. Nada del original a git: texturas, fuente y franjas de barra a `cache/` (las franjas se generan desde `sacengine/source/sacobject.d:2111-2122` al exportar; no se copia código GPL al repo).

## 1. Objetivo
- Arriba a la derecha, el marco del original: almas (64×96 unidades HUD) con el alma azul animada y el número, más maná y vida como barras (32×96 cada una); sin texto «Vida/Maná/Almas»; escala con `HudScale` (F84).
- Clic izquierdo sobre casa, cactus, Manalith u otra estructura con vida: barra de vida sobre el modelo, sin cambiar la selección; el clic en vacío sigue deseleccionando (F78).
- Las estructuras se dañan con melé, hechizo directo y, como en el original, con daño de área (Wrath, Fireball, Swarm).
- Farmers y Taurocks con sus clips reales: quieto, correr/huir, encogerse (con variante hablando), cavar tranquilos, atacar (Taurock). Reloj del clip en física; simulación sin cambios.

## 2. Hallazgos (sacengine verificado)
- `renderStats` (`renderer.d:4770-4830`): marco de almas en x = W − 2·32 − 64, 64×96; maná en x = W − 64 y vida en x = W − 32, 32×96; y = 0; escala `hudScaling`. Marco: región u 0,5–0,75, v 0–0,25 de `fram` (mitad superior estirada, inferior espejada). Alma: `bits.FLDR/spir.TXTR` grilla 4×4, cuadros azules 0–7, 64×96·0,85, 15 fps. Barra (`renderStatBar`): área 32×68 desde y = 14 que se llena desde abajo, tapón de 4 arriba y 6 abajo (franjas 32×4, 32×1, 32×6). Número: `renderText` (`renderer.d:5306-5344`), fuente `font.FLDR/fn10.TXTR`, sombra negra + blanco; es el único texto de la HUD del original.
- Vida de edificios en el original: no hay barra en el mundo; `renderMouseoverBox` (`renderer.d:5036-5230`) muestra una caja tras 0,5 s de cursor quieto. El clic sobre un edificio no hace nada (`dagonBackend.d:1171-1198`). La barra al hacer clic es una extensión del port pedida por el usuario.
- Daño de área: `dealDamageAt` (`state.d:9075-9089`) alcanza edificios por distancia a la caja, sin filtrar bando: `amount·(1 − d/r)`; no daña con `cannotDamage` o vida 0 (`canDamage`, 9091).
- Campesinos: COWER usa el clip de encogerse; al terminar, 1 de cada 5 veces hablar encogido (`state.d:8164-8171, 14228-14231`). «Working the fields» existe en el FSM pero sin regla decompilada.
- Port: `%Stats` es Label leído por **147 flows** → se conserva como nodo de texto que no se dibuja (como `%Battle` en F80). `wrath_strike`/`fireball_projectile`/`swarm_projectile` solo dañan `wizard`/`unit`; `box_distance` solo entiende cápsulas. `UnitBody._clip_roles()`: idle, run, attack; COWER aplasta `Tilt`.

## 3. Diseño
### 028a — Estadísticas del mago (F92)
`WizardStats` (escena): tres marcos con `HudIcons.region("fram", Rect2(64,0,31,31))`, dos `StatBar` (Mana, Health) y `SoulCounter` (alma de `spir.png`, 15 fps, en `_process` por ser presentación; número con `BitmapDigits` sobre `fn10.png`). Pegado arriba a la derecha, `mouse_filter = IGNORE`, se rehace con `hud_scale.changed` y el cambio de viewport. Sin caché: barras de color plano (192,0,0)/(0,96,192) y número en Label del grupo `hud_text_allowed`. `hud.gd` llama `show_values(vida, maná, almas)`; `%Stats` pasa a `Node` con `text_readout.gd` (misma cadena, sin dibujar). «Mago · Dios» y «Fantasma» quedan como texto debajo de los marcos (P1 = a).

### 028b — Inspeccionar y dañar estructuras (F93)
Clic izquierdo sin nada armado sobre algo de `_building_under()` con `Health` máximo > 0 → `%Inspector.inspect(body)`; la selección queda intacta. Clic en vacío → `Selection.clear()` + `Inspector.clear()`. Uno inspeccionado a la vez; altar o indestructible sin barra. Barra: `unit_health_bar.tscn` instanciada en `map_building.tscn` y `structure.tscn` (≈3 m), knob `only_when_selected`, oculta si `maximum ≤ 0` o muerta, `place_above(tope de la caja)`; local, sin RPC. Ataque: sin cambios (clic derecho = orden de ataque; melé y hechizos directos ya funcionan). Daño de área fiel: `SplashDamage` (static) recorre `wizard`, `unit`, `structure` con distancia a la caja (`box_distance` también para `BoxShape3D` rotado), `is_live_body`, `amount·(1 − d/r)`, sin filtrar bando; lo usan Wrath, Fireball y Swarm. Fuera: caja del cursor quieto (P2 = b, va con la decisión de tooltips), widgets, modelo de edificio destruido.

### 028c — Animaciones de Farmer y Taurock (F94)
Sistema actual (`ClipPosePlayer`); RFC-023 migrará estos roles después. Exportador: `decode_cre8` lee ranuras 32, 33, 35, 37 (descarta «00»); `creatures.json` gana `extra_animations {cower, talk_cower, work, pull}`; `NPC_ANIM_CREATURES = ("zepe","raeb")` exporta `PEi1`, `PErn`, `PEa1`, `PEcw`, `PEtc`, `PEdi`, `BEi1`, `BErn`, `BEa1`, `BEa2` (no `PEpu`). `UnitBody._clip_roles()` suma `cower`, `talk_cower`, `work`; COWER usa el clip y deja el aplastado como respaldo. `ClipPosePlayer` emite `clip_looped(role)` en física; variante `talk_cower` si `(hash(name) + vueltas) % 5 == 0` (sin `randi()`). Trabajar el campo (decisión del port): `PeasantBehavior.set_idle_role("work")` en estado tranquilo, knobs `work_when_calm` (on) y `work_role`. Muerte: sigue el tween de `Corpse` (P3 = b, con RFC-023). Solo presentación: digest igual; headless sin mallas.

## 4. Escenas de prueba
- 028a: `debug/soul_pickup.tscn` (0 almas, alma libre; W hasta el alma; `spell_2` Heal baja maná) y `debug/wizard_ghost.tscn`.
- 028b: `debug/village.tscn` (mago a 30 m de la `jhut` (1255,3, 1213,8); cactus `jcc2` (1245,9, 1177,4) a ~11 m; Hunter seleccionado; `wizard_travel.set_pointer_world` + `select`/`order_units`) y `debug/wrath_splash_building.tscn` (nueva, heredada de `rock_hit.tscn` con exports `building_tags ["jcc2"]`, `building_spots [(3,40)]`; `spell_3` Wrath sobre el Human).
- 028c: `debug/npc_anim_gallery.tscn` (nueva, script `unit_parity_gallery.gd` con `unit_tags ["zepe","raeb"]`, `cycle_roles [idle, run, attack, cower, talk_cower, work]`; `check_tick` cicla), más `village_cower`, `village`, `village_taurock`.

## 5. Árbol de archivos
```
game/
├── tools/
│   ├── export_icons.py                         M 028a  fn10 → cache/look/hud/fn10.png; franjas stat_{health,mana}_{top,mid,bottom}.png
│   └── export_stats.py                         M 028c  ranuras 32/33/35/37 → extra_animations; NPC_ANIM_CREATURES
├── scenes/
│   ├── ui/
│   │   ├── hud.tscn / hud.gd                   M 028a  WizardStats + Title + GhostState; Stats = Node(text_readout)
│   │   ├── text_readout.gd                     N 028a
│   │   ├── bitmap_digits.gd                    N 028a  BitmapDigits (static)
│   │   └── wizard_stats/{wizard_stats.tscn,wizard_stats.gd,stat_bar.gd,soul_counter.gd}  N 028a
│   ├── data/{creature_type.gd,game_data.gd}    M 028c  extra_animations
│   └── world/
│       ├── high_noon.tscn                      M 028b  %Inspector
│       ├── match_command.gd                    M 028b  _left_at: edificio → inspect; vacío → clear
│       ├── structure_inspector.gd              N 028b
│       ├── unit_body.gd                        M 028c  roles cower/talk_cower/work, set_idle_role
│       ├── components/clip_pose_player.gd      M 028c  signal clip_looped(role)
│       ├── map/map_building.{tscn,gd}          M 028b  HealthBar
│       ├── structures/{structure.tscn,structure_body.gd}  M 028b  HealthBar
│       ├── units/unit_health_bar.gd            M 028b  only_when_selected
│       ├── units/peasant_behavior.gd           M 028c  work_when_calm, work_role
│       └── spells/
│           ├── splash_damage.gd                N 028b  SplashDamage (static)
│           └── {wrath_strike,fireball_projectile,swarm_projectile}.gd  M 028b
├── debug/
│   ├── rock_hit.gd                             M 028b  building_scene/tags/spots
│   ├── wrath_splash_building.tscn              N 028b
│   ├── unit_parity_gallery.gd                  M 028c  unit_tags, cycle_roles
│   └── npc_anim_gallery.tscn                   N 028c
├── agent/flows/{f92_stats,f92_ghost,f93_inspect,f93_splash,f94_gallery,f94_village}.json  N
└── FEATURES.md                                 M  F92, F93, F94
```

## 6. Criterios
**028a:** `fn10.png` y 6 franjas en `cache/`, nada en git; a 1280×720 escala 0,8 bloque de 153,6 × 115,2 px (±1) pegado arriba a la derecha (1920×1080: 230,4 × 172,8); barra llena 81,6 px; `mana_fraction` = maná/máximo (±0,01) a ≤ 1 cuadro; `spell_2` baja exactamente el costo; `souls_shown` 0 → 1 al juntar el alma y el alma anima 8 cuadros en ~0,53 s; fantasma: `health_fraction` 0 y «Fantasma» visible sin tapar; `f80_hud_text` auditoría 0; `%Stats.text` conserva el formato (`f30_pt_pickup`, `pt31_ghost`, `f24_cast`, `f22_mana_pt` OK); sin caché, respaldo sin errores; cambio de escala en caliente 0,6–1,2 sin pisar `SelectionRoster` ni `SpellBook`. Regresión: `f79_roster`, `f84_hud_scale`.
**028b:** en `village`: `select` sobre la `jhut` → `inspected` = casa, barra visible 1,0, selección intacta; sobre el cactus → pasa al cactus, exactamente 1 barra visible; suelo → `inspected` null, 0 barras, selección 0; altar sin barra; barra 0,3–0,6 m sobre la caja; Hunter con `order_units` sobre el cactus baja su vida en ≤ 30 s y si cae `inspected` = null sin errores; en `wrath_splash_building` el Human recibe 550 y el cactus 550·(1 − d/5) (±1); indestructible sin daño; `wrath_splash` igual que antes; `rules_suite` sin fallas nuevas; digest de `ai_match` seed 7 informado antes/después (cambio aceptado solo si lo explica el daño de área a estructuras). Regresión: `f78_deselect`, `f78_corpse`, `f80_cues`, `pt73w_house`.
**028c:** caché con los clips de `epez`/`eber` (MB informados); `zepe.extra_animations` correcto, `raeb` vacío; galería: tag esperado por rol y cuadro que avanza; `village_cower`: COWER con `PEcw`/`PEtc` sin aplastado, secuencia igual en dos corridas; `village`: Farmer tranquilo con `PEdi`, huyendo con `PErn`; `village_taurock`: `BErn` y `BEa1`; digest de `ai_match` seed 7 idéntico; headless sin mallas de NPC; caché viejo sin errores; con 26 Farmers y 6 Taurocks el cuadro no empeora > 1 ms (`FrameBudget` de 027a si existe). Regresión: `pt73w_*`, `f79_roster`.

## 7. Riesgos
028a: paleta de `fn10` (respaldo Label), franjas premultiplicadas (verificar contra la captura). 028b: `box_distance` con caja rotada; el área a estructuras puede cambiar partidas de la IA (fiel, digest documentado); `_unit_under` va antes que el edificio. 028c: tiempo y disco del export (`PEdi` 198 cuadros; no `PEpu`); «trabajar el campo» no verificado (marcado port, se apaga); primera reproducción de clips (apoyarse en 027b).

## 8. Fuera de alcance
Caja del cursor quieto y tooltips (P2); clip de muerte (P3, RFC-023); estados Talking/Disgusted/etc. sin regla; modelo destruido y caída de la casa; minimapa; daño a widgets; estadísticas del objetivo de cámara; IA que ataque edificios a propósito.

## 9. Orden
028a y 028b en paralelo (archivos disjuntos). 028c después de 027b (ambos tocan `clip_pose_player.gd`). Cada corte: developer → review → playtest → FEATURES.

Fuentes: sacengine `renderer.d:4170-4230, 4770-4830, 4976-4993, 5036-5230, 5306-5344`; `sacobject.d:1158-1177, 2070-2128`; `dagonBackend.d:1165-1200, 3076+`; `state.d:8164-8171, 9063-9095, 14228-14231, 31346-31357`; `animations.d:5-81`; `sacfont.d:5-60`. Instalación: `main.wad` (`fram`, `spir`, `fn10`), `spells.wad` (CRE8 `zepe`/`raeb`), `saxs_odd.wad` (`epez`), `saxs_r5.wad` (`eber`).
