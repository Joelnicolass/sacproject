# RFC-030 — Bestiario completo por nivel de mago

Estado: plan del tech lead (Opus), pendiente de OK. Arquitectura **estándar**. MP **online con dedicado** (MpKit); la IA vive en quien simula. Autoridad: PRD > FEATURES > RULES > VISUAL > RFC-023/024/025/026/027 > este RFC.
Pedido del usuario: «también está pendiente tener a disponibilidad todas las criaturas. Hoy tenemos las básicas, pero en el juego original al avanzar en la campaña teníamos muchas más criaturas».
Features: **F112–F133** (cortes 030a–030v).

> **Conflicto con el PRD (gana el PRD hasta que se cambie):** `PRD.md:21` deja «libro de hechizos completo» fuera del primer corte. Las criaturas son entradas del libro (`spellbook.gd:3-5`). Antes de 030b el orquestador registra `changes/CHANGE-REQUEST-002.md` o edita esa línea: criaturas completas sí, hechizos de nivel ≥ 2 no. 030a no cambia el juego y puede ir antes.

## 1. Objetivo (criterios de aceptación)

- Cada dios tiene sus **10 criaturas + Manahoar**, con el reparto por nivel del original: nivel 1 trae 3 criaturas, del 2 al 7 una por nivel, el 8 ninguna y el 9 la última.
- El **nivel del mago** decide qué criaturas hay en el libro. Lo fija la partida (como `synchronizeLevel` del original), se ve en el libro y en el HUD con los iconos originales, y el servidor rechaza convocar una criatura de nivel superior.
- El nivel también cambia al mago como en sacengine: +50 de vida y +100 de maná por nivel, y lanzamiento más rápido con el bonus de `castingTime(level)`.
- Las 35 criaturas nuevas se convocan, caminan, atacan (cuerpo a cuerpo o con disparo), mueren y dejan alma, con sus clips reales.
- Después, por grupos: voladoras híbridas, pasivas, efectos de disparo y habilidades activas. Cada grupo es un corte con criterio propio.
- Con nivel 1 (las reglas de debug), el juego es **idéntico al de hoy**: libro, tiempos y digest de `ai_match`.

## 2. Hechos verificados

### 2.1 El original (sacengine, solo lectura)

- **Listas por dios** (`nttData.d:1245-1250`): Manahoar neutral y 10 criaturas por dios. `creatureSpells` las encadena (`:1251`). Fuera de los libros quedan los héroes de campaña (`:1264`), la Dragon Hatchling (`:1263`) y los familiares (`:1265`).
- **Nivel de cada entrada** (`state.d:2138-2172`, `computeDefaultSpells`): el Manahoar, Speedup, Heal y las estructuras son de nivel 0. Las criaturas 1-3 del dios son de nivel 1, las 4-9 de los niveles 2 a 7, y la 10 de nivel 9. El nivel 8 no trae criaturas, solo dos hechizos, y el Shrine es de nivel 3. Coincide con `spell_order/100` de cada CRE8 (`creature_type.gd:54-55`): Scythe 124 → 1, Necryl 245 → 2 … Hellmouth 989 → 9.
- **Qué se ve en el libro:** `getSpells` filtra `spell.level <= wizard.level` (`state.d:29512`) y el libro dibuja esa lista (`renderer.d:4875`). Lo de nivel superior **no se dibuja**. `spellStatus` lo da como inexistente (`state.d:29537`).
- **Quién elige el nivel en multijugador:** `Settings.level=9`, `minLevel=1`, `maxLevel=9`, `souls=12` (`options.d:174-194`), y `--level=`, `--min-level=`, `--max-level=`, `--xp-rate=` (`app.d:276-285`). Con `useMapSettings`, el nivel inicial y el tope salen del LEVL del mapa (`lobby.d:485-496`, `levl.d:9-20`). El host sincroniza el nivel a todos (`lobby.d:350`, `options.d:139`).
- **High Noon** (verificado leyendo el LEVL del `.scp` con `tools/export_high_noon_look.py:51`, sin escribir): `multiMinLevel` 3, `multiMaxLevel` 9, `multiSouls` 6. En un jugador: `singleStartLevel` 1 y `singleMaxLevel` 2.
- **Experiencia:** el mago gana XP (`state.d:8862`) y sube o baja de nivel entre min y max (`state.d:28149-28200`, `xpForLevel` en `nttData.d`).
- **Efectos del nivel en el mago:**
  - `makeWizard` suma `maxHealth += 50·level` y `maxMana += 100·level` (`state.d:2307-2311`); al subir, +50 y +100 (`state.d:28188-28194`).
  - `castingTime(level)`: `bonus = min(5, max(0, level − spellOrder/100))` y `frames = (f·10 − f·bonus)/10` (`sacspell.d:93-102`).
  - Hay casteos por ciclos según mago y nivel (`state.d:9543-9600`): fuera de alcance.
- **Voladoras:** `mustFly` = `creatureType "ylfo"` (`sacobject.d:81-83`); `canFly` = tiene la animación `fly` (`sacobject.d:113-115`). Las híbridas despegan cuando volando llegan antes (`state.d:12335-12339`, `startFlying` en `8692-8704`) y aterrizan con `land` (`8706-8716`; animación `land` en `8120-8124`).
- **Disparos:** cada criatura a distancia tiene su función de disparo y su proyectil (`state.d:12632-12730` → `11513-11870`). Efectos propios, vistos con grep (inferido, se confirma en cada corte):
  - salpicadura: Scarab 23609, Flummox 24059 (más aturdir), Mutant 24381, Abomination 24432 (gotas);
  - petrificar: Basilisk 23686;
  - vórtice y catapulta: Vortick 23840;
  - empuje: Squall 23974;
  - catapulta: Flurry 24602;
  - congelar: Silverback 24760;
  - veneno: Necryl 23493;
  - proyectil propio: Tickferno, Pyromaniac (cohete), Gnome, Deadeye (dardo), Bombard, Boulderdash, Warmonger (arma), Styx (rayo con explosión 24154), Phoenix, Hellmouth y Rhinok.
- **Habilidades activas:** `useAbility` reparte por tag (`state.d:13513-13557`); las tags están en `nttData.d:1151-1170`.
- **Pasivas:**
  - `passiveOnDamage = abilities[2]` (`sacobject.d:426`).
  - Taurock `korq`: el daño recibido se multiplica por `0.25 + 0.75·vida%` (`state.d:9012-9016`).
  - Firefist `ahtf`: el golpe hace `1 + 1.5·(1 − vida%)` (`state.d:8887-8890`).
  - Storm Giant `gcil`: carga de rayo (`state.d:9017-9022`).
  - Al morir (`state.d:8274-8278`): `goc@` nube de vapor, `cen@` nube venenosa, `tum@` lluvia curativa.
  - Al golpear: `freeze` (Yeti) y `graspingVines` (Dragon) (`state.d:14423-14436`).

### 2.2 El port

- **Libro:**
  - `export_stats.py:845` arma `books.json` con `neutralCreatures + {god}Creatures[:3]`, o sea **exactamente el nivel 1**. Los hechizos son los neutrales más el primero del dios (también nivel 1) y las estructuras sin el Shrine.
  - `GameData.book()` (`game_data.gd:83-97`) los entrega sin nivel.
  - `Spellbook._rebuild` (`spellbook.gd:179-208`) cachea por dios (`:181`) y ordena por `spell_order`.
- **Datos de las 51 criaturas de libro:** stats, costo, clips por tag e icono en `cache/data/creatures.json`. Hay 71 CRE8 en total.
  - Los 51 modelos tienen cuerpo horneado en `cache/baked/bodies/*.res`.
  - Hay **icono** para las 51 y para las 19 habilidades activas (`cache/look/icons`).
- **Faltan clips:** `anim_mesh_clips_f37.json` solo tiene los modelos de las 16 criaturas de nivel ≤ 1, porque `_collect_mesh_clip_tags` lee `books.json` (`export_stats.py:546-569`).
  - En `bodies.json`, las **35 nuevas tienen `pose_source: null`**: horneadas desde la pose de enlace, con la heurística de F53. Ent, Storm Giant y otras tienen `upright_fix` de 90°, y las alturas son dudosas (Phoenix 12,4 m, Rhinok 9,7 m).
- **Simulación independiente de los clips:** melee y disparo leen `attack_ticks`/`shoot_ticks` del `CreatureType` (RFC-023 §2). Una criatura nueva ya pelea con sus números aunque no tenga clips.
- **Voladoras:** `is_flying()` = `running_speed <= 0 and flying_speed > 0` (`creature_type.gd:50-51`). Las 9 híbridas (Blight, Gremlin, Ikarus, Pyrodactyl, Seraph, Dragon, Hellmouth, Rhinok, Silverback) **caminan siempre**.
- **Disparo genérico:**
  - `ranged_shot.gd:166` hace daño directo.
  - El aspecto sale de `data/shots/<tag>.tres` (`ShotLook`); hoy solo existe `ekba.tres`.
  - `BALLISTIC` ya lista `babt`, `tugt`, `cfba`, `caba`, `crba` (`ranged_attack.gd:31`).
- **Habilidades activas:**
  - `active_ability.gd:103-104` acepta una lista fija de 6 tags; las demás dicen «No implementado».
  - El reparto es un `match` (`:109`, `:140`). Crecerlo 13 tags más es el anti-patrón de `godot-composition-first`.
- **Pasivas en el export:**
  - El export guarda `abilities = [92, 96, 124]` y filtra los vacíos (`export_stats.py:298`, `:812`), así que **se pierde qué tag es `abilities[2]`**: Taurock `korq`, Firefist `ahtf`, Storm Giant `gcil` y Phoenix `rifl` quedan como «habilidades» sin rol.
  - Phoenix `rifl` termina como activa. Verificado en `creatures.json`: `grdr` tiene `abilities ['rdra','rifl']`.
  - `goc@`, `cen@` y `tum@` no están ni en `abilities.json` ni en `spells.json`. Tampoco está la pasiva del Cog (`goc@`), que ya es del roster de hoy.
- **Mago:** WIZD 1000 de maná y 1500 de vida para todos (`wizards.json`), o sea las estadísticas del **nivel 0**. `god` se replica con `replication_mode 2` (`wizard_body.tscn:45-47`); `WizardSpawner._place` reparte `rules` (`wizard_spawner.gd:26-31`).
- **Lanzamiento:** `casting_time_s` fijo (`caster.gd:352`, `spellbook.gd:119`, `desecrate_action.gd:50`, `convert_action.gd:49`). Hoy todo el libro es de nivel 1 (`spell_order` 100-136), así que a nivel de mago 1 el bonus es 0 y **no cambia nada**.
- **HUD:** `spell_book.gd:93-131` arma una casilla por entrada y el marco por cantidad. El InputMap ya tiene `creature_1..11` (`project.godot:93-143`). El panel F79 usa `HudIcons.icon(tag)` (`selection_roster.gd:180,206,236`). F84 tiene una guarda que achica el panel para no pisar el libro.
- **IA:**
  - `WizardBrain.rebuild_spells` lee el `Spellbook` del mago (`wizard_brain.gd:189-205`). Se rehace con `spell_dirty`, que se prende al crear el track (`ai_perception.gd:209`).
  - `SummonPhase` elige entre `wizard.summons` la criatura que puede pagar en almas con el mejor `rateWithBase·(1 − costo/pool)` (`summon_phase.gd:47-58`). La que «elige la mejor criatura» es `SummonPhase`, no `AiSpellEval`; `AiSpellEval` solo evalúa hechizos.
  - `tag_acc` / `fill_by_tag` toleran habilidades nulas (`ai_rater.gd:96-98`).
  - **La IA toma las criaturas nuevas sin cambios** apenas el libro las trae. Respeta el nivel porque el libro ya viene filtrado.
  - La IA no usa habilidades de criatura (`creature_brain.gd` no las nombra).
- **Digest:** `ai_match.tscn:5` usa `debug/rules/ai_duel_seeded.tres` (6 Trogg contra 6 Druid). Con `wizard_level` 1 por defecto en el script, el libro no cambia y el digest tampoco.

## 3. Bestiario completo y estado en el port

Datos de `creatures.json` (CRE8). Los niveles salen de `state.d:2138-2172`. «Clips» = falta exportar `idle/run/attack[/shoot]` y re-hornear la pose (resuelto en 030a para las 35). Todas tienen cuerpo horneado e icono.

| Dios | Nv | Criatura (tag) | Maná/Almas | Tipo | Activa | Pasiva | Estado en el port |
|---|---|---|---|---|---|---|---|
| — | 0 | Manahoar (oham) | 0/1 | tierra | — | aura de maná `hmba` (F41) | **completo** |
| Persephone | 1 | Druid (nmuh) | 300/1 | melee | Life Shield | — | **completo** |
| | 1 | Ranger (amuh) | 300/1 | dist `wobf` | Divine Sight | — | **completo** |
| | 1 | Shrike (tbsh) | 300/1 | vuela, `absh` | Life Shield | — | completo (pose de vuelo pendiente, F53) |
| | 2 | Scarab (cara) | 600/2 | dist `slba` | — | — | clips; salpicadura (030h) |
| | 3 | Troll (lort) | 700/2 | melee | — | — | clips (solo datos) |
| | 4 | Gnome (plfl) | 1000/2 | dist `plfa` | — | — | clips; disparo propio (030m) |
| | 5 | Gremlin (lrps) | 1000/3 | híbrida 7,5/17 | Web pull `psla` | — | clips; vuelo (030e); hab. (030q) |
| | 6 | Mutant (cbab) | 1100/3 | dist `babt` | — | `tum@` al morir | clips; salpicadura (030h); pasiva (030g) |
| | 7 | Ent (mtsl) | 1300/4 | melee | Protector `HSba` | — | clips (pose 90°); hab. (030o) |
| | 9 | Dragon (grdg) | 1900/5 | híbrida 10/20 | Breath of life `filb` | `eniv` al golpear, `tum@` | clips; vuelo; hab. (030p); pasivas (030g, 030u) |
| Pyro | 1 | Cog (zidf) | 300/1 | melee | — | `goc@` al morir | **falta pasiva** (030g) |
| | 1 | Flame Minion (fplk) | 300/1 | dist `fkba` | Run Away | — | **completo** |
| | 1 | Spitfire (sohf) | 300/1 | vuela, `fhba` | — | — | completo (F53) |
| | 2 | Tickferno (craf) | 600/2 | dist `sfba` | — | — | clips; disparo propio (030l) |
| | 3 | Firefist (lrtf) | 700/2 | melee | — | `ahtf` (daño ↑ con vida ↓) | clips; pasiva (030f) |
| | 4 | Pyromaniac (plff) | 1000/2 | dist `lffa` | — | — | clips; cohete (030l) |
| | 5 | Pyrodactyl (kacf) | 1000/3 | híbrida 7,5/17 | Viscous Oil `kcfa` | — | clips; vuelo; hab. (030r) |
| | 6 | Bombard (wlcf) | 1100/4 | dist `cfba` | — | — | clips; disparo propio (030l) |
| | 7 | Warmonger (nugf) | 1300/4 | dist `fhga` | Firewalk `wfhg` | — | clips; arma (030m); hab. (030o) |
| | 9 | Phoenix (grdr) | 1900/5 | híbrida 10/20, `rdra` | — | `rifl` (escudo), `goc@` | clips; vuelo; disparo (030n); export mal clasificado |
| James | 1 | Trogg (ycro) | 300/1 | melee | — | — | **completo** |
| | 1 | Earthfling (palk) | 300/1 | dist `ekba` | Rockform | — | **completo** |
| | 1 | Gargoyle (sohe) | 300/1 | vuela, `ehba` | — | — | completo (F53) |
| | 2 | Basilisk (guls) | 600/2 | dist `dpsf` | — | — | clips; petrificar (030i) |
| | 3 | Taurock (raeb) | 700/2 | melee | — | `korq` (daño recibido ↓) | ya es NPC hostil (F73); clips; pasiva (030f) |
| | 4 | Flummox (wlce) | 1000/3 | dist `crba` | — | — | clips; salpicadura + aturdir (030h/030i) |
| | 5 | Ikarus (kace) | 1000/3 | híbrida 5,6/12,75 | Sticky bomb `acia` | — | clips; vuelo; hab. (030r) |
| | 6 | Boulderdash (llab) | 1100/4 | dist `emba` | — | — | clips; disparo (030n) |
| | 7 | Jabberocky (mtse) | 1300/4 | melee | Quake `kauq` | — | clips; hab. (030u) |
| | 9 | Rhinok (gard) | 1900/5 | híbrida 7,5/15, `hrba` | Halo of Earth `HRba` | — | clips; vuelo; disparo (030n); hab. (030p) |
| Stratos | 1 | Frostwolf (lbog) | 300/1 | melee | Run Away | — | **completo** |
| | 1 | Sylph (ahcr) | 300/1 | dist `aaba` | Stealth | — | **completo** |
| | 1 | Brainiac (bobs) | 300/1 | vuela, `bsba` | — | — | completo (F53) |
| | 2 | Vortick (craa) | 600/2 | dist `cita` | — | — | clips; vórtice (030j) |
| | 3 | Squall (alab) | 700/2 | dist `amba` | — | — | clips; empuje (030j) |
| | 4 | Storm Giant (rgos) | 1000/2 | melee | Call lightning `gsba` | `gcil` (carga) | clips (pose 90°); hab.+pasiva (030s) |
| | 5 | Seraph (grps) | 1000/3 | híbrida 9,4/21,25 | Cage pull `psaa` | — | clips; vuelo; hab. (030q) |
| | 6 | Flurry (wlca) | 1100/4 | dist `caba` | — | — | clips; catapulta (030j) |
| | 7 | Yeti (ycrp) | 1300/4 | melee | — | `zerf` congela al golpear | clips; pasiva (030u) |
| | 9 | Silverback (grdb) | 1900/5 | híbrida 12,5/25, `rdba` | Run Away (ya existe) | — | clips; vuelo; congelar (030k) |
| Charnel | 1 | Scythe (dzid) | 300/1 | melee | — | — | **completo** |
| | 1 | Fallen (dplk) | 300/1 | dist `dkba` | Play Dead | — | **completo** |
| | 1 | Locust (pazb) | 300/1 | vuela, `zbba` | — | — | completo (F53) |
| | 2 | Necryl (glsd) | 600/2 | dist `cena` | — | `cen@` al morir | clips; veneno (030k); pasiva (030g) |
| | 3 | Blight (kacd) | 700/2 | híbrida 7,5/17 | Bilemites `liba` | — | clips; vuelo; hab. (030s) |
| | 4 | Netherfiend (crpd) | 1000/2 | melee | Devour `ifna` | — | clips; hab. (030t) |
| | 5 | Deadeye (plfd) | 1000/2 | dist `lfda` | — | — | clips; dardo venenoso (030k) |
| | 6 | Abomination (ctug) | 1100/3 | dist `tugt` | — | — | clips; gotas + salpicadura (030h) |
| | 7 | Styx (nugd) | 1300/4 | dist `dhga` | Rend Soul `dner` | — | clips; rayo (030m); hab. (030t) |
| | 9 | Hellmouth (nomd) | 1900/5 | híbrida 10/20, `mhba` | Devour `ifna` | — | clips; vuelo; veneno (030k); hab. (030t) |

Tras 030a + 030b + 030c, **las 51 se convocan, caminan, pelean, mueren y dejan alma**. Las demás columnas son fidelidad.

## 4. Cómo se elige qué criaturas tiene el jugador

- **Regla:** el libro muestra solo las entradas con `nivel ≤ nivel del mago`, como `getSpells` del original. Lo de nivel superior **no se dibuja**; no aparece en gris.
- **El nivel es una regla de partida**, igual para todos los magos, como `synchronizeLevel` del original:
  - `MatchRules.wizard_level` (1-9). Default del script **1**, para no cambiar nada en debug. `data/match_rules.tres` lo pone en **9** (producto, el default de sacengine `options.d:190`). El valor 9 entra en 030c, cuando el mago ya tiene el maná para pagarlas.
  - Lo replica el mago (`wizard_body.level`, igual que `god`). Queda listo para una futura XP que suba el nivel por mago.
  - Contra la IA lo elige el jugador en la selección (030d), con default 9. En el dedicado es `--level=N` (como `app.d:276`); los clientes no eligen.
- **HUD (F79/F80):** sin assets nuevos.
  - La pestaña Criaturas crece a 11 casillas con su icono original; teclas `creature_1..11`, que ya están en el InputMap.
  - El panel de seleccionadas usa `HudIcons.icon(tag)`. Una habilidad sin implementar destella el icono «no» de F80 con «No implementado».
  - Criterio de 030b: a 1280×720 con escala 0,8, el libro de 11 casillas no se superpone al panel (guarda de F84).

## 5. Cortes (por valor)

Todos siguen developer → reviewer → **playtester con ventana y capturas**. Cada corte cabe en 1–2 h de developer. Leyenda: N = nuevo, M = modificado.

### 030a — F112 Datos y cuerpos del bestiario (sin cambio de juego)

**Árbol**
```text
tools/export_stats.py                 M  books: "creatures" = Manahoar + las 10 del dios; "levels" {tag: nivel} como computeDefaultSpells (state.d:2138-2172); spells/structures sin cambio
                                         _collect_mesh_clip_tags ya toma books → exporta idle/run/attack/shoot de los 35 modelos nuevos
tools/audit_unit_parity.py            M  cubre las 51 criaturas de libro y reporta faltantes por nivel
tools/bake_bodies.gd                  —  se re-corre (pose_source = idle del clip)
scenes/data/game_data.gd              M  book(god, max_level := 1) filtra por "levels"; creature_level(god, tag)
debug/unit_parity_gallery.gd          M  @export var max_level := 1 (lo pasa a GameData.book)
debug/f110_bestiary_gallery.tscn      N  misma galería, max_level = 9, los 5 dioses
```

| Pieza | Responsabilidad | Tipo |
|---|---|---|
| `books.json` "levels" | nivel de cada entrada, del original | dato de caché |
| `GameData.book(god, max_level)` | catálogo filtrado; con el default 1 da lo de hoy | autoload existente |
| `f110_bestiary_gallery.tscn` | ver las 51 de pie con sus clips | debug, mismo script |

**Escena de prueba:** `res://debug/f110_bestiary_gallery.tscn`.
- Instancia la galería de F41 con `max_level` 9 y las 51 criaturas en filas por dios, en `idle`.
- Todavía **no** ciclan roles.
- El playtester pulsa `check_tick` (la acción que la galería ya usa) para pasar por `idle`, `run` y `attack`.

**Criterios**
1. `books.json` trae por dios 11 criaturas y `levels` = Manahoar 0 y las del dios 1,1,1,2,3,4,5,6,7,9.
2. `audit_unit_parity` reporta 0 faltantes de `idle/run/attack` (y `shoot0` en las de distancia) para las 51.
3. `bodies.json`: `pose_source` no nulo en las 51. Las 16 entradas de hoy, idénticas (diff).
4. `GameData.book("james")` sin segundo argumento devuelve Manahoar, Trogg, Earthfling y Gargoyle, igual que hoy.
5. Capturas: cada nueva de pie, con los pies en el suelo y dentro de su cápsula, en los 3 roles. Las híbridas se marcan aparte para 030e.

### 030b — F113 Nivel del mago y libro por nivel

**Árbol**
```text
scenes/data/match_rules.gd            M  @export_range(1, 9) var wizard_level := 1  (grupo «Libro»)
scenes/world/wizard/wizard_body.gd    M  @export var level := 1 (setter → pick_changed)
scenes/world/wizard/wizard_body.tscn  M  replica .:level (spawn + on change, como god)
scenes/world/wizard/wizard_spawner.gd M  _place: level = rules.wizard_level
scenes/world/spells/spellbook.gd      M  _rebuild con clave (god, level) → GameData.book(god, level)
debug/bench_rules.gd                  M  @export var human_god: StringName (el runner fija el dios del mago humano)
debug/ai_match.gd                     M  aplica human_god a SacrificeFlow.pick antes de poblar (como hace con los asientos, :364)
debug/f111_bestiary.tscn              N  runner ai_match + rules por defecto
debug/rules/f111_bestiary_<dios>.tres N×5 BenchRules: wizard_level 9, almas 60, maná lleno, human_god, grupo enemigo slot 2 = una de cada nueva del dios a 60 m
debug/rules/f111_level3_james.tres    N  igual, nivel 3
```
La IA no cambia: lee el `Spellbook`. El servidor rechaza sin cambios: `Caster._try_summon` busca en el libro filtrado (`caster.gd:279-284`) y responde «Blanco inválido».

**Escena de prueba:** `res://debug/f111_bestiary.tscn` con `f111_bestiary_james.tres` (otros dioses: `--rules=…`).
- Estado inicial: mago James de nivel 9, en pausa «Pendiente», 60 almas, maná lleno (1000) y las 7 criaturas nuevas de James del bando 2 a 60 m.
- Todavía **no** hay criaturas propias.
- El playtester pulsa `check_tick` y después `creature_5`…`creature_11`. Luego selecciona y ordena atacar con clic derecho.

**Criterios**
1. Nivel 9: la pestaña Criaturas muestra 11 casillas en orden de `spell_order`. Nivel 3: 6 casillas. Nivel 1: las 4 de hoy.
2. Cada criatura nueva de ≤ 1000 de maná aparece con «<Nombre> vida/vida», camina con una orden y pega o dispara (log `golpe`/`disparo`). Las de 1300/1900 dicen «Sin maná»; se habilitan en 030c.
3. Las enemigas del bando 2 mueren y dejan alma roja sobre el cadáver (log de `SoulSystem`).
4. Una RPC `submit_summon("nomd")` de un mago de nivel 3 → «Blanco inválido», sin criatura.
5. A 1280×720 el libro no se superpone al panel de seleccionadas.

### 030c — F114 Efectos del nivel en el mago

**Árbol**
```text
scenes/data/match_rules.gd            M  @export var wizard_level_stats := false (+50 vida/+100 maná por nivel, state.d:2307-2311)
data/match_rules.tres                 M  wizard_level = 9, wizard_level_stats = true (producto)
scenes/world/wizard/wizard_spawner.gd M  aplica el bono a Health.maximum / ManaPool.maximum (y current) al colocar
scenes/data/cast_time.gd              N  class_name CastTime: static func seconds(entry, wizard_level) (sacspell.d:93-102, frames enteros)
scenes/world/spells/caster.gd         M  :352 usa CastTime
scenes/world/spells/spellbook.gd      M  :119 usa CastTime
scenes/world/spells/actions/desecrate_action.gd, convert_action.gd  M  usan CastTime
debug/rules/f111_bestiary_*.tres      M  wizard_level_stats = true
```
`CastTime` es una clase de funciones estáticas (no un autoload) porque es un helper puro.

**Escena de prueba:** la de 030b. Ahora el mago arranca con 1900/1900 de maná y 1950 de vida, y con las 11 casillas. El playtester pulsa `creature_11` (Rhinok).

**Criterios**
1. Nivel 9: HUD «Maná 1900», vida 1950. Rhinok y Styx se convocan (maná 1900 → 0, luego 1300).
2. Trogg a nivel 9: 17 cuadros (≈ 0,21 s) contra 0,43 s a nivel 1. Manalith 5,56 s contra 11,11 s.
3. Nivel 1 (debug): todos los tiempos y el maná de F24/F25 iguales.
4. `rules_suite` PASS. Se listan las escenas de `debug/` que instancian `high_noon.tscn` sin `.tres` propio (p. ej. `ability_spit.tscn`): heredan nivel 9. `f29_spit` mide el maná del Earthfling, no el del mago, y debe pasar. Si una falla por maná o vida del mago, se le da `.tres` de nivel 1.

### 030d — F115 Elegir el nivel

**Árbol**
```text
scenes/flow/sacrifice_flow.gd         M  level_override (0 = el de las reglas); --level=N en dedicado y solo (como --ai-slots, :110)
scenes/ui/boot.tscn/.gd               M  fila «Nivel del mago» 1–9 junto a %AiGod (§13), default = data/match_rules.tres
scenes/world/wizard/wizard_spawner.gd M  usa level_override si > 0
```
**Escena de prueba:** la escena que abre el jugador (boot → selección → «Contra la IA»). No hace falta escena de debug. El playtester elige nivel 4 y pulsa Jugar.

**Criterios**
1. Con nivel 4, el libro de los dos magos (humano e IA) tiene 7 criaturas y el maná máximo es 1400.
2. En el dedicado `--level=2` con dos clientes, los dos ven 5 casillas.
3. Sin tocar nada, nivel 9.

### 030e — F116 Voladoras híbridas: despegue, vuelo y aterrizaje

**Árbol**
```text
tools/export_stats.py                 M  exporta takeoff/fly/land de las 9 híbridas (si el CRE8 no los nombra: por tag SXSK del modelo)
scenes/world/units/flight.gd          N  class_name Flight (hijo de unit.tscn): GROUND/TAKEOFF/FLYING/LANDING; despega si takeoff + d/vuelo < d/tierra (state.d:12335-12339); aterriza al quedar quieto (8706-8716)
scenes/world/units/unit.tscn          M  nodo Flight + replica Flight:state
scenes/world/unit_body.gd             M  is_flying() de tipo → pregunta a Flight; _clip_roles agrega fly/takeoff/land; altura por Flight
debug/rules/f114_flyers.tres          N  BenchRules: las 9 híbridas propias a 150 m de un manantial
```
**Escena de prueba:** `res://debug/f114_flyers.tscn` (runner `ai_match` con `f114_flyers.tres`). Estado inicial: las 9 en tierra. El playtester pulsa `check_tick`, las selecciona con rectángulo y da clic derecho lejos.

**Criterios**
1. Con un destino a 150 m despegan (clip `takeoff`), vuelan a `flying_speed` y aterrizan al llegar.
2. Con un destino a 5 m caminan.
3. Captura lateral: el cuerpo dentro de su cápsula en tierra y en vuelo (cierra lo pendiente de F53 para estas 9).
4. Red: el estado de vuelo se ve igual en A y B.

### 030e2 — Pose y cápsula de las híbridas (F134 = 030e2a, F135 = 030e2b; plan del tech lead, 2026-10-16)

**Diagnóstico.** No es la altura de los pies. La medición de F116 ignoraba `data/bodies/pose_overrides.tres`, que desde F112 sube a Hellmouth +1,68 m y a Rhinok +1,40 m. Además, el port repite el gesto `idle` (Edi1, DMi1, ADi1…) en lugar del reposo `stance1`, que es lo que hace sacengine en cada vuelta (`state.d:7957-7992`); el horneado de nivel 2 o más ya usa `stance1`. Eso explica que «Rhinok flote» y los 14,35 m de Silverback. En sacengine el origen está en el suelo, y lo que queda debajo (alas, cola) se dibuja dentro del terreno, que es lo fiel. Phoenix (DFst) toca −0,03 m en el fondo del aleteo y en la mediana flota +2,35 m: es intencional, se marca `rest_hovers`. Lo que de verdad queda es la cápsula **en vuelo** de Blight, Ikarus, Pyrodactyl y Silverback.

**030e2a — F134: reposo con `stance1` y pose medida en tierra**
```text
scenes/world/unit_body.gd             M  _clip_roles: "idle" = pose_source del modelo (stance1 desde nivel 2; idle0 en nivel 1), si no idle_animation
scenes/data/body_pose_override.gd     M  @export rest_hovers := false (lo lee la auditoría)
data/bodies/pose_overrides.tres       M  fdrg rest_hovers = true; notas en ddmn/edmn
tools/audit_body_pose.gd              M  sección HIBRIDA: mín, mediana del mín por cuadro, p95 máx, tope, cápsula; veredictos C1/C2
debug/unit_parity_gallery.gd          M  @export freeze_time, face_yaw_deg
debug/f134_hybrid_pose_small.tscn     N  5 chicas de perfil, cámara ortográfica lateral, cápsula visible
debug/f134_hybrid_pose_big.tscn       N  5 grandes, igual
```
Criterios:
1. **C1:** en las 9 que caminan, la mediana del mín por cuadro queda en [−0,30, +0,30] y el mín ≥ −0,35. En Phoenix, el mín queda en [−0,35, +0,35].
2. **C2:** p95 máx − 0,10 ≤ cápsula ≤ tope máx + 0,10.
3. El label de la galería muestra `tag=<pose_source>`, y en nivel 1 no cambia ningún tag.
4. Cuatro PNG de perfil, en idle y en fly, con los pies sobre la línea del suelo (±0,3 m).
5. Las líneas no híbridas de la auditoría quedan idénticas, el digest de seed 7 no cambia y `f25_flying_summon` da OK.

Riesgo: el cambio de reposo afecta a todas las criaturas de nivel 2 o más. Hay que comprobar la lista `bad` de `sacobject.d:675-677` y los flows que verifican tags de idle.

**Decisión (2026-10-16, por el developer de F134):** C2 falló en 7 de 10, porque las cápsulas se habían medido en el cuadro 0. Agrandarlas cambia la simulación: `info().height` alimenta la caja de golpe de `MeleeAttack`. Por eso C2 **pasa a F135**, que pone `capsule_height` en el rango [p95 − 0,10, tope + 0,10] para adrg, ddmn, drag, edmn, fdrg, sprg y sprl, y declara el digest nuevo. F134 cierra con C1, C3, C4 y C5 y sin cambio de simulación.

**030e2b — F135: cápsula en tierra (C2 de 030e2a) y en vuelo.** `BodyPoseOverride.capsule_height_flying` (dcak 4,95, ecak 5,82, fcak 5,10, adrg 12,08), `BodyCatalog.info().height_flying` y `Flight` cambia la altura de la `CollisionShape3D` al entrar y salir de FLYING. `unit_body.gd` no se toca. Criterios:
- **C3:** p50 máx(fly) ≤ cápsula de vuelo y p95 − 0,10 ≤ cápsula de vuelo.
- `f114_flyers` despega y aterriza igual que en F116.
- El digest no cambia.

**F135, cambio de simulación declarado (por REVIEW-F135 B2):** cambia la altura de tierra de 7 modelos:

| Modelo | Antes | Después |
|---|---|---|
| adrg | 6,90 | 12,18 |
| drag | 11,98 | 12,75 |
| sprg | 3,72 | 3,91 |
| sprl | 3,75 | 3,89 |
| ddmn | 10,47 | 11,02 |
| edmn | 9,52 | 10,07 |
| fdrg | 12,96 | 15,21 |

- **Qué cambia:** la caja vertical de `MeleeAttack`, `BodySeparation`, el origen del disparo y `captive`. Además, en vuelo la mira apunta al centro de la cápsula de vuelo.
- **Partidas afectadas:** las que incluyen esas híbridas, es decir, nivel 2 o más.
- **Digest:** el de seed 7 no cambia porque no las incluye, y ningún digest lo cubre. Esto reemplaza al criterio «el digest no cambia» de 030e2b.

**030e2-R — REA (sin código).** En `Sacrifice.exe`: ¿el desplazamiento SXSK se escala por `zfactor/referenceHeight`, y se suma algún término a la z de render (por ejemplo, el short de los bytes 10-11 de la cabecera)?
- **Si hay término:** se pasa a `position_offset` en los datos.
- **Si no hay:** los lifts de F112 quedan como desvío visual declarado y Phoenix queda con offset 0.

**Fuera de alcance:** los gestos idle al azar, `rotateOnGround`, el hitbox por cuadro y la mira y la selección en vuelo.

### 030f — F117 Pasivas de daño (Taurock, Firefist)

**Árbol**
```text
tools/export_stats.py                 M  passive_on_damage = slots[2] (sacobject.d:426); abilities conserva el slot 2 (ver Decisiones de 030f)
scenes/data/creature_type.gd, game_data.gd  M  passive_on_damage: String
scenes/world/units/damage_passive.gd  N  class_name DamagePassive: incoming_factor(vida%) / outgoing_melee_factor(vida%) desde su .tres
data/passives/korq.tres, ahtf.tres    N  DamagePassiveType (a + b·vida% o 1 + c·(1−vida%))
scenes/world/units/unit.tscn          M  hijo DamagePassive; Health y MeleeAttack lo consultan por socket @export
```
**Escena de prueba:** `res://debug/f115_passives.tscn` (runner `ai_match`): un Taurock al 50 % de vida contra un Trogg, y un Firefist al 20 % contra un Druid. El playtester pulsa `check_tick`.

**Criterios**
1. Log: el golpe al Taurock al 50 % vale ×0,625.
2. El golpe del Firefist al 20 % vale ×2,2.
3. Los NPC Taurock de F73 usan la pasiva (declarado: `village_taurock` cambia su registro).

**Decisiones (2026-10-16, por el developer de F117):**
- **Criterios 1 y 2:** se leen como fórmula con la h anterior al golpe. Taurock recibe ×(0,25 + 0,75·h) de todo daño menos la caída (`state.d:9010-9015`). Firefist hace ×(1 + 1,5·(1−h)) de daño, solo cuerpo a cuerpo (`state.d:8886-8890`). En el banco, el Druid golpea primero y el Firefist llega a h = 0,181, así que el log muestra ×2,228; eso cumple.
- **`abilities` sigue incluyendo el slot 2.** Sacarlo rompía tres cosas: la IA cuenta ese slot (`shiny.d:888-898`), el aura `hmba` del Manahoar vive ahí y el digest de nivel 1 cambiaría. Phoenix `rifl` ya no era activa: `active_ability` toma el slot 1 en las criaturas a distancia.
- **Quedan sin efecto:** `tdhg` y `tfhg` (Styx, Warmonger), que ahora aparecen en `passive_on_damage`.

### 030g — F118 Nubes al morir (Cog, Phoenix, Necryl, Mutant, Dragon)

**Árbol**
```text
tools/export_stats.py                 M  exporta los SPEL pasivos goc@/cen@/tum@ (carpeta a ubicar en spells.wad; hoy no salen en ningún json)
scenes/data/creature_type.gd, game_data.gd  M  passive_abilities (CRE8 440/452)
scenes/data/death_cloud_type.gd       N  class_name DeathCloudType: tag, scene, fx_name, fx_height_m
data/death_clouds/goc.tres, cen.tres, tum.tres  N  un DeathCloudType por pasiva
scenes/world/units/death_cloud.gd     N  class_name DeathCloud: actúa una vez sobre los cuerpos del radio, humo por FxBus, se libera
scenes/world/units/death_clouds/steam_cloud|poison_cloud|healing_shower.tscn/.gd  N  una escena por variante (sin if kind)
scenes/world/units/death_cloud_spawner.gd  N  hijo de unit.tscn; escucha Health.died en el servidor (state.d:8274-8278)
scenes/world/units/poisoned.gd        N  class_name Poisoned: una dosis de veneno, hija del cuerpo
scenes/world/spells/heal_effect.gd    M  on(target); add() suma cuadros con saturación (satAdd)
scenes/world/units/unit.tscn          M  hijo DeathCloudSpawner
tools/export_particles.py, data/fx/steam|poison|poison_dose|rainbow.tres  M/N  humo de las nubes
scenes/world/unit_body.gd             —  no se toca
```
**Escena de prueba:** `res://debug/f116_death_clouds.tscn`: un Cog, un Necryl y un Mutant con 1 de vida junto a Druids enemigos y aliados. El playtester pulsa `check_tick`.

**Criterios:** cada muerte deja su nube; vida de los vecinos medida antes y después (sube con `tum@`, baja con `goc@`/`cen@`).

**Decisiones (2026-10-16, por el developer de F118):**
- **`unit_body.gd` no se toca.** El dueño es `DeathCloudSpawner`, hijo de `unit.tscn`: escucha `Health.died` solo en el servidor y, por cada tag de `CreatureType.passive_abilities` (CRE8 440/452) con un `DeathCloudType` (`data/death_clouds/*.tres`), instancia su escena en diferido.
- **Las nubes no duran.** En sacengine actúan una vez, en su primer update, y se van (`state.d:25216-25254`, `25674-25697`). Lo que dura queda en los cuerpos: una dosis `Poisoned` (veneno) o un `HealEffect` (cura). La nube se ve en los clientes por `FxBus.broadcast`, igual que Wrath y Fireball.
- **Números del SPEL** (`@PRC.SCAT` de `spells.wad`; ahora salen en `abilities.json` con sus `args`):
  - `goc@` Steam Cloud (Cog y Phoenix): 300·(1 − d/10), daño de salpicadura de hechizo, a 10 m. Usa `SplashDamage`, así que también daña edificios.
  - `cen@` Poison Cloud (Necryl): a 5 m, 150 / 5 / 1,3 = 23,08 por segundo durante 300 cuadros (`state.d:11610-11614`).
  - `tum@` Healing Shower (Mutant, Dragon y Sirocco `risH`): a 30 m y solo al mismo bando. `amount` pasa a infinito (`sacspell.d:211`) y `heal()` lo convierte en la vida máxima del cuerpo (`state.d:10446-10449`): cura `maxHealth` en total a 240 por segundo, en ceil(maxHealth/240·60) cuadros, y corta si se llena (`16293-16310`). Si ya había una cura, suma cuadros con saturación (`satAdd`, `10455`).
- **Phoenix, Dragon y Sirocco entran** con la misma mecánica: Phoenix tiene `goc@`; Dragon y Sirocco, `tum@`. Phoenix no renace; su `rifl` es el escudo de 030n.
- **Fuego amigo: divergencia heredada del hueco Fuego amigo (AUDIT-2026-10-12:152).** sacengine tiene `friendlyFire=true` por defecto (`options.d:98`), con ×0,5 en salpicadura y `ignoreFriendly` en el veneno (`state.d:28892-28899`, `9415-9419`). Acá `Health.damage_typed` no daña al mismo slot, así que el vapor y el veneno no tocan a los aliados. Se resuelve en un RFC aparte.
- **Queda para 030k:** los debuffs de la dosis (`ires` 1000, `freg` 0), el bloqueo de maná a los 2 s y el contagio.

**Decisión del usuario (2026-10-16): fuego amigo.** Tiene que existir, como en sacengine (`friendlyFire=true` por defecto, `options.d:98`), y tiene que ser configurable desde un menú de opciones nuevo con gráficos y jugabilidad. Va en **RFC-031**: el menú de opciones, el fuego amigo como regla de partida que decide el host o el servidor, y `sideDamageMultiplier` e `ignoreFriendly` en `Health`. Hasta entonces, la divergencia de 030g y 030h sigue declarada.

### 030h — F119 Impacto con salpicadura (Scarab, Mutant, Abomination, Flummox)

**Árbol**
```text
scenes/world/units/shot_impact.gd     N  class_name ShotImpact (Node): apply(shot, target, point, ability)
scenes/world/units/impacts/splash_impact.tscn/.gd  N  daño de salpicadura en damage_range (dealSplashRangedDamageAt)
scenes/world/units/shot_look.gd       M  @export var impact: PackedScene
scenes/world/units/ranged_shot.gd     M  al pegar, solo en el servidor, instancia impact si existe
data/shots/slba.tres, babt.tres, tugt.tres, crba.tres  N  ShotLook + impact
```
**Escena de prueba:** `res://debug/f117_splash.tscn`: las 4 criaturas a distancia del bando 1 frente a 3 Druids juntos. El playtester pulsa `check_tick`.

**Criterio:** un disparo baja la vida de los 3 Druids; el log trae el daño por distancia.

**Decisiones (2026-10-16, por el developer de F119):**
- **Árbol real:** además, `impacts/lob_splash_impact.tscn` (escena heredada de `splash_impact.tscn` con `direct_hit` apagado y radio `effect_range`) y `SplashDamage.bodies_within` (un solo recorrido; `DeathCloud.bodies_within` delega). `SplashDamage.deal/hurt` toman el tipo de daño. No hay `slba.tres`.
- **Mutant `babt` y Abomination `tugt`** (`state.d:24381-24387`, `24432-24439`): el cuerpo tocado recibe el `amount` entero como ranged|splash (resistencia de salpicadura a distancia, `8952-8954`) y queda fuera del área; el resto, `amount·(1 − d/damageRange)`. Si cae al suelo, solo el área. Caja de choque 1,25 m.
- **Flummox `crba`** (`24059-24067`): `dealSplashRangedDamageAt(0, …, effectRange)`, sin golpe entero: el tocado también cae con la distancia. Caja 2 m. El aturdido (`stunWithCooldown`) queda para 030i, como hijo `ShotImpact` de la escena del impacto.
- **Scarab `slba` queda fuera:** es «Healing web». `scarabProjectileHit` (`23609-23627`) llama a `dealSplashSpellDamageAt` con un callback que cura a los del bando y devuelve `false`, así que no daña a nadie; además apunta al aliado más herido (`12949-12958`) y no dispara a enemigos (`12850-12853`). Hoy el port le pega daño directo a distancia a enemigos: hace falta un corte propio (impacto de cura + elección de blanco).
- **Fuera:** las gotas de la Abomination (`AbominationDroplet`, 50 de daño directo a distancia, `24488-24505`), los modelos de los proyectiles (bolas de reserva) y las partículas `splat`/`gib` (se usa `blood`).
- **Fuego amigo:** divergencia heredada (ver 030g).

### 030h2 — F136 Telaraña que cura (Scarab `slba`; plan del tech lead, 2026-10-16)

**Sacengine:**
- **Impacto** (`scarabProjectileHit`, `state.d:23609-23627`): cura a los cuerpos móviles del bando del tirador que estén a ≤ 5 m (`effect_range`). Usa la misma regla que `tum@`: hasta `maxHealth`, a 240/s, con satAdd (`10443-10458`). No daña a nadie ni a ningún edificio, y el tirador también entra.
- **Proyectil** (`23631-23672`): va recto. Choca con su blanco o con cualquier cuerpo de su bando. La caja de choque mide 0,15 m. Al agotar el alcance, estalla igual.
- **Blanco por IA** (`12949-12958`, `28828-28842`): el aliado con la vida relativa más baja y no lleno; primero dentro de 110 m y después dentro de la vista. Nunca elige a un enemigo.
- **Orden de atacar a un enemigo** (`12849-12855`): le dispara y lo cura a él no, sino a los aliados que estén a 5 m del impacto. En contacto le pega cuerpo a cuerpo. Nunca le pega cuerpo a cuerpo a un aliado.

**Árbol**
```text
scenes/data/target_policy.gd               N  TargetPolicy (Resource): tag, accepts(body,node,ordered), pick(body,center,within)
scenes/data/wounded_ally_policy.gd         N  WoundedAllyPolicy: aliado más herido; con orden acepta foes como hoy
data/targeting/slba.tres                   N  WoundedAllyPolicy tag "slba"
scenes/world/units/target_picker.gd        M  @export policies; active() por ranged_attack_tag; pick()/accepts() delegan; sin política = código de hoy
scenes/world/unit_body.gd                  M  solo _is_valid_foe pregunta a TargetPicker.accepts (neto 0 líneas)
scenes/world/units/ranged_attack.gd        M  prefers(): nunca melee al propio slot
scenes/world/units/shot_look.gd            M  @export hits_allies, burst_at_range_end
scenes/world/units/ranged_shot.gd          M  respeta hits_allies; _burst(null) al agotar alcance si burst_at_range_end
scenes/world/units/impacts/heal_impact.gd/.tscn N  HealImpact: bodies_within + HealEffect.heal_full al slot del tirador
scenes/world/spells/heal_effect.gd         M  static heal_full(body) (compartida con tum@)
scenes/world/units/death_clouds/healing_shower.gd M  usa heal_full
data/shots/slba.tres                       N  ShotLook (0,15 m, hits_allies, burst_at_range_end, heal_impact)
scenes/world/units/unit.tscn               M  TargetPicker.policies = [slba.tres]
debug/ai_match.gd, bench_group.gd          M  order "attack_unit"
debug/f136_healing_web.tscn + rules        N  carril A (IA: aliado al 50 % lejos, enemigo al 50 % cerca), carril B (orden de atacar al enemigo, aliado al 50 % a 2 m); carriles a 160 m
```

**Criterios**
1. **Carril A, primer disparo:** el primer disparo va al aliado aunque el enemigo esté más cerca. El aliado pasa de 400 a 800 en ≤ 2 s con «cura total ≤ 400». El Scarab no hace ningún daño.
2. **Carril A, enemigo:** el enemigo nunca recibe cura. Cuando el aliado está lleno, el Scarab deja de disparar.
3. **Carril B:** el Scarab dispara al enemigo, que queda en 800/800, y el aliado a 2 m recibe cura. En contacto le pega cuerpo a cuerpo al enemigo.
4. **Regresiones:** `f117_splash` (382,50), `f116_death_clouds`, `f29_spit` y `f25_summon` dan lo mismo. El digest de seed 7 no cambia: el Scarab es de nivel 2. Queda declarado que, con nivel ≥ 2, la IA que convoca Scarabs ahora cura.

**Riesgos**
- `body.target` puede ser un aliado: revisar los lectores de `target` en `ai` y en el HUD.
- `closest_foe` queda con un nombre engañoso, y `fired` sigue informando 150.
- `burst_at_range_end` solo vale para `slba`.

**Desvíos (developer de F136, 2026-10-16):**
- **Desvío 1, `is_foe` sigue significando «enemigo».** La política decide solo `_is_valid_foe`, es decir, el blanco que el cuerpo conserva. Si `is_foe` delegaba en ella, `Orders._closest_enemy_creature` (el reasignado de una orden de atacar) tomaba como «enemigo» al aliado herido: el Scarab del carril B quedó atacando a su Manahoar aliado. `UnitOrders._in_sight` también usa `is_foe`, así que con un aliado de blanco vuelve a pedir blanco a la política. `unit_body.gd` sigue con 1046 líneas.
- **Desvío 2, `ShotLook.sweep` (solo `slba`).** Si la caja no toca a nadie en el cuadro, se revisa el segmento recorrido (`lineOfSight` de `updateScarabProjectile`, `state.d:23655-23664`; Earthfling no lo tiene). A 48 m/s el disparo avanza 0,8 m por cuadro y una caja de 0,15 m puede atravesar un cuerpo.
- **Carril C agregado** (z +200: Scarab con orden de atacar a un Trogg pegado) para el cuerpo a cuerpo en contacto. Con un Druid, el hueco entre cajas queda en 0,62–0,64 m, por encima de `melee_distance` 0,5, y el Scarab dispara. Es la regla de hoy para toda criatura a distancia y no se tocó.
- **Escena real** (`debug/f136_healing_web.tscn`, semilla 4): carriles a z −80, +80 y +200 (a z ±160 hay huecos en el terreno). Carril A: Druid aliado al 50 % a 85 m y Manahoar enemigo al 50 % a 6 m (un Druid enemigo mataba al Scarab en 4 s). Carril B: Manahoar enemigo y Manahoar aliado al 50 %, los dos pacíficos, para que nadie más toque la vida del enemigo.
- **Vidas reales de los criterios:**
  - C1: el Druid aliado pasa de 400 (459 al llegar la telaraña, por la regeneración) a 800, con `cura Druid total 304`.
  - C3: el enemigo es un Manahoar y queda en 550/550, no 800/800; el aliado, otro Manahoar, se cura de 289 a 550.
  - Contacto: 6 golpes del Scarab al Trogg en el carril C.
- **Declarado:** con nivel ≥ 2, la IA que convoca Scarabs ahora cura. Con una orden de atacar de la IA, el Scarab le dispara al enemigo y cura a los aliados a 5 m del impacto.

### 030h3 — Gotas de la Abomination (`AbominationDroplet`, `state.d:4838-4845`, `24441-24452`, `24488-24505`)
- **Mecánica:** en cada cuadro de vuelo, con probabilidad 3/4, suelta una gota. La gota cae a 10 m/s², choca con cualquier obstáculo y hace 50 de daño directo a distancia.
- **Diseño propuesto:** un hijo `ShotDropper` (`ShotLook.dropper`) que corre solo en el servidor.
- **Va aparte** porque es una mecánica durante el vuelo, necesita decidir de dónde sale el número aleatorio (determinismo) y el costo de unas 40 gotas por disparo hay que medirlo.

### 030i — Aturdir y petrificar (Flummox `crba`, Basilisk `dpsf`; plan del tech lead, 2026-10-16)

**Sacengine — aturdir:**
- `stunWithCooldown(obj, 480)` (`state.d:8561-8568`) pasa el modo a `stunned` con un enfriamiento de 8 s. `canStun` (`8546-8553`) rechaza si hay enfriamiento o si el cuerpo está stunned, dying, dead, rockForm, playingDead, etc.
- La duración es la del clip: `(knocked2Floor + getUp)·2` cuadros (`8138-8146`, `14170-14212`; slots 9 y 10). En vuelo usa `flyDamage` (slot 35).
- El Flummox aturde, antes del daño, a **todo** cuerpo a ≤ 8 m: sin filtro de bando, incluido el tirador y los magos (`24059-24067`, `9075-9089`).

**Sacengine — petrificar:**
- `dpsf` sale de las manos, recto a 48 m/s, con caja de 0,35 m y línea de visión (`23686-23725`). **No hace daño**: solo llama a `petrify`.
- Duración: un mago queda 2,5 s y una criatura `min(10, 10000/vida máx)` s (`11641-11645`).
- La rechaza `ccProtected`; se petrifica igual a un aturdido o a un Rockform (`11631-11640`, `189-197`).
- Mientras dura:
  - no actúa, no gira, no se mueve y no regenera;
  - congela la pose;
  - un volador cae;
  - **recibe daño ×0,2** (`8965`);
  - se ve gris (`bone.d:189-192`).
- Al terminar llama a `damageStun`: cae, se levanta y queda con 4 s de enfriamiento (`23732-23764`).
- Aturdido o petrificado, el cuerpo sigue siendo blanco válido y obstáculo. Las órdenes se guardan y se ejecutan al levantarse (`93-145`, `1140-1142`).

**Duraciones (frames de los .wad):**

| Criatura | Aturdido | Petrificado |
|---|---|---|
| Druid / Trogg | 226 cuadros (3,77 s) | 600 (10 s) |
| Earthfling | 112 | |
| Frostwolf | 152 | |
| Scythe | 390 | |
| Flummox | 116 | 263 |
| Basilisk | 154 | 357 |
| Shrike en vuelo | 96 | |

**Diseño: un dueño de «¿puede actuar?».** El nodo `Afflictions`, hijo de `unit.tscn`, responde `holds()`, `immobilized()`, `damage_factor()`, `cc_protected()` y `clip_role()`.
- Cada estado es un hijo `Affliction` (`Stunned`, `Petrified`, y más adelante `Frozen`). Sus banderas están en `AfflictionType` (`.tres`).
- Quién gana lo dice el dato (`cancels`), no el orden.
- `StunImpact` es un hijo `ShotImpact` más.
- A los clientes se replica `Afflictions:shown` (máscara de bits).
- `unit_body.gd` no crece: la rama `_playing_dead` se funde con la puerta.

#### 030i-a — F120 Estado común y aturdir (Flummox)
```text
tools/export_stats.py                          M  stun_animations {knock 9, get_up 10, fly_damage 35} + clips
scenes/data/creature_type.gd, game_data.gd     M  stun_animations
scenes/data/affliction_type.gd                 N  AfflictionType (Resource)
data/afflictions/stunned.tres                  N
scenes/world/units/afflictions/afflictions.gd  N  Afflictions (dueño; shown replicado; held_changed/look_changed)
scenes/world/units/afflictions/affliction.gd   N  Affliction (Node)
scenes/world/units/afflictions/stunned.gd      N  Stunned (cuadros del clip; enfriamiento; knock→get_up)
scenes/world/units/impacts/stun_impact.gd      N  StunImpact: bodies_within 8 m, sin filtro de bando, cooldown 480
scenes/world/units/impacts/flummox_impact.tscn N  lob_splash_impact + StunImpact
data/shots/crba.tres                           M  impact = flummox_impact.tscn
scenes/world/units/unit.tscn                   M  Afflictions/Stunned + sync shown
scenes/world/unit_body.gd                      M  neto ≤ 0 (fusión con _playing_dead; clip_role; ability_status)
debug/f118_stun.tscn + rules                   N  carril A (Flummox vs 3 Druids), carril B (Flummox + aliado + Earthfling)
```
Criterios:
1. **Duración:** «durante 226», y «se levanta» llega a los 226 ±2 cuadros. En ese lapso el cuerpo se mueve menos de 0,05 m y no ataca.
2. **Vuelve a pelear:** al levantarse retoma el combate.
3. **Enfriamiento:** un segundo disparo antes de 8 s no aturde, pero sí hace daño.
4. **Sin bando:** quedan aturdidos el Earthfling (112), el Druid aliado (226) y el propio Flummox (116).
5. **Cliente:** en `net_local` el cliente ve caer y levantarse.
6. **Regresiones:** `f117_splash` hace el mismo daño (382,50), y `f136`, `f29`, `f25` y Play Dead se comportan igual. Los digests de seed 7 y `--npcs` no cambian.

Riesgo: el export puede ocupar mucho disco. Si pasa de +1 GB, se usa un Tween de reserva.

#### 030i-b — F137 Petrificar y la mirada del Basilisk
```text
data/afflictions/petrified.tres                N  holds, immobilizes, damage_factor 0.2, cc_protects, cancels [stunned]
scenes/world/units/afflictions/petrified.gd    N  congela clip; StoneLook; volador cae; al terminar knock (enfriamiento 240) + rocas
scenes/world/look/stone_look.gd, stone.gdshader N
scenes/world/components/clip_pose_player.gd    M  frozen
scenes/world/components/health.gd              M  × afflictions.damage_factor()
scenes/world/units/flight.gd                   M  drop()
scenes/world/units/impacts/petrify_impact.gd/.tscn N  solo el tocado; cap 10 s, k 10000, mago 2,5 s; sin daño
data/shots/dpsf.tres                           N  0,35 m, sweep, impact petrify
scenes/world/units/unit.tscn                   M  Afflictions/Petrified + Health.afflictions
scenes/world/unit_body.gd                      M  0 líneas
debug/f137_petrify.tscn + rules                N  A (Basilisk vs Druid + Trogg propio atacando), B (vs Flummox), C (vs Gargoyle)
```
Criterios:
1. **Duración:** 600 cuadros, después «aturdido 226». En el Flummox, 263.
2. **El impacto no hace daño.**
3. **Daño recibido:** cada golpe sobre el cuerpo petrificado se multiplica por 0,20.
4. **Quieto:** se mueve menos de 0,05 m y la pose queda congelada.
5. **Protegido:** un segundo disparo no lo petrifica.
6. **Vuelve a pelear.**
7. **Gargoyle:** cae al suelo y vuelve a 4,5 m.
8. **Cliente:** ve la piedra.
9. **Regresiones:** las mismas que en 030i-a, más `f115_passives`. El digest no cambia.

Declarado: el Basilisk deja de hacer los 150 de daño directo que hace hoy.

#### 030i-c — F138 Magos aturdidos y petrificados
`wizard_body.tscn` recibe `Afflictions` con `Stunned` y `Petrified`. El aturdido corta el lanzamiento y el arreglo de `hitFloor` (`sacobject.d:844-857`) aplica igual. La piedra dura 2,5 s. Hasta este corte, los impactos ignoran al mago y lo dejan en el log (divergencia declarada).

**Digest de seed 7:** no cambia. El Flummox es de nivel 4, el Basilisk de nivel 2, no hay RNG nuevo y los factores neutros dan exactamente 1,0.

**Riesgos:**
- Al fundir la rama, Play Dead suma `_cap_air_pace`.
- `StoneLook` usa overrides por superficie.
- Sin huesos de mano, el Basilisk mira desde un solo punto (divergencia).
- El aturdido sí alcanza a los aliados; el daño todavía no, hasta RFC-031.
- Hay otros lectores de `mode` que no saben si el cuerpo está retenido.

**Fuera de alcance:**
- El aturdido por golpe cuerpo a cuerpo (`9246-9262`): cambiaría el digest de nivel 1 y va en un corte propio.
- Catapulta (030j) y congelar (030k).
- Skin of Stone.
- Migrar Rockform y Play Dead a `Afflictions` (030v).

### 030j — F121 Empuje, vórtice y catapulta (Squall, Vortick, Flurry)

**Árbol**
- N: `impacts/push_impact.tscn` y `impacts/vortex_impact.tscn`.
- M: `data/shots/amba.tres`, `cita.tres`, `caba.tres`.

**Escena de prueba:** `res://debug/f121_push.tscn`. **Criterio:** la posición del blanco cambia lo medido contra sacengine (23840, 23974, 24602).

**Plan (developer de F121, 2026-10-17)**

*Sacengine:*
- **Squall `amba`** (`updateSquallProjectile`, `state.d:23974-24008`): disparo recto a 60 m/s, caja 0,45 m. Si toca una criatura (o un mago), primero `pushback` y después 520 de daño directo a distancia; un edificio solo recibe el daño; el suelo y el fin del alcance no hacen nada. `Pushback` (`4768-4776`, `24017-24031`) dura 2/3 s: en cada uno de 40 ticks llama a `push(22,5·dirección)`, 15 m en total. `push` (`8604-8612`) desliza sobre la tierra: si el paso sale de la tierra no se mueve, y la altura es la del suelo. **No aturde ni arroja.** Si el cuerpo ya está en tumbo, le suma la velocidad una vez y termina.
- **Vortick `cita`** (`updateVortickProjectile`, `23840-23879`): recto a 48 m/s, caja 0,45 m. En una criatura, 150 de daño directo a distancia; en la criatura, en el suelo o al agotar el alcance (110 m), `spawnVortex` en la posición del cuadro anterior. `VortexEffect` (`4736-4751`, `23922-23960`): dura 2 s, radio = `effectRange` (2 m), alto 4 m. Caja: ±√2·radio en el plano, de −1 m a +4 m. Mientras `frame < 90` toca a todo cuerpo móvil, sin filtro de bando: si `frame < 45` y no está en tumbo, `catapult(dirección tangente·1,5 m/s, +2,5 m/s)`; si está en tumbo, le suma el campo `(5,5·(−y−x), 5,5·(x−y), 5,5)` m/s² relativo al centro (solo debajo de 4 m), con `vz ≥ 1` y sin gravedad ese tick (`antiGravityTime`). Se actualiza antes que las criaturas.
- **Flurry `caba`** (`flurryProjectileImplosion`, `24577-24598`; `updateFlurryImplosion`, `24619-24672`): bola con gravedad (30 m/s²) a 42 m/s, caja 1,75 m. Al tocar: 400 a distancia con resistencia de salpicadura al tocado, salpicadura en 10 m al resto, y una implosión que encoge de 20 m a 0 en 1,5 s. Cada tick, a cada cuerpo móvil dentro del cubo ±escala y a ≤ 20 m del centro: `speed = √(max(10,d)·max(10,escala))/20·15/60` m por tick hacia el centro. Si el paso queda a ≤ 0,125 m del suelo, se desliza (como `push`). Si no, `catapult(2·speed·dir)`. En tumbo, `position += 2·speed·dir`.
- **Catapulta y tumbo** (`catapult`, `8579-8599`; `14781-14797`; `14175-14212`): no se arroja a un volador en el aire ni a un cuerpo muerto, en `landing` o convocándose. El modo pasa a `stunned` y el movimiento a `tumbling`, con `fallingVelocity = v` (o `+= v` si ya está en tumbo). En el tumbo, cada tick: si está en el suelo y baja, `vz = 0`; si no, `vz −= 9,81/60` (salvo `antiGravityTime`). Después, `vxy ·= 0,99`, `vz ·= 0,998` y `pos += v/60`. Aterriza cuando `vz ≤ 0` y `pos.z + vz/60 ≤ suelo`. Ahí sufre `dealFallDamage = max(0, −vz − 3)·20` (sin resistencia ni bando, `9429-9438`) y queda aturdido `hitFloor + getUp` cuadros ×2 (sin tocar el enfriamiento del aturdido). Un híbrido que puede volar deja el tumbo en el ápice y vuelve a volar.
- **Magos:** sí. El vórtice y la implosión tocan a todo `movingObject` y `pushback` acepta cualquier blanco de tipo criatura, magos incluidos.

*Árbol (N/M):*
```text
tools/export_stats.py                          M  STUN_ANIM_SLOTS y WIZARD_STUN_ANIM_SLOTS + hit_floor (slot 8), solo el largo
scenes/data/affliction_type.gd                 —  sin cambios
data/afflictions/tumbling.tres                 N  id tumbling, bit 2, holds, cancels [stunned]
scenes/world/units/afflictions/affliction.gd   M  steer(velocity, delta) por defecto = la misma
scenes/world/units/afflictions/afflictions.gd  M  steer() (el estado que mueve al cuerpo), previous (máscara antes del último cambio)
scenes/world/units/afflictions/tumbling.gd     N  Tumbling: catapult(v, side), add_velocity, shift, steer (balística), aterrizaje → daño de caída + Stunned.fall_down
scenes/world/units/afflictions/stunned.gd      M  fall_down(): hit_floor + get_up, sin enfriamiento; el cliente lo deduce de `previous`
scenes/world/units/body_nudge.gd               N  BodyNudge (static): slide (push de sacengine), center, box, ground
scenes/world/units/impacts/direct_impact.gd    N  DirectImpact: el monto entero, directo a distancia, al tocado
scenes/world/units/impacts/pushback.gd         N  Pushback (Node, hijo del cuerpo empujado, prioridad −1): 22,5 m/s × 40 ticks
scenes/world/units/impacts/push_impact.gd/.tscn N  Squall: PushImpact (Pushback) + DirectImpact
scenes/world/units/impacts/vortex.gd/.tscn     N  Vortex (Node3D en el contenedor de disparos, prioridad −1): updateVortexEffect
scenes/world/units/impacts/vortex_impact.gd/.tscn N  Vortick: DirectImpact + VortexImpact (Vortex en la posición del tick anterior)
scenes/world/units/impacts/implosion.gd/.tscn  N  Implosion (Node3D, prioridad −1): updateFlurryImplosion
scenes/world/units/impacts/implosion_impact.gd/.tscn N  Flurry: SplashImpact (directo + 10 m) + ImplosionImpact
data/shots/amba.tres, cita.tres, caba.tres     N  ShotLook (0,45 / 0,45 / 1,75 m; cita burst_at_range_end)
scenes/world/units/unit.tscn                   M  Afflictions/Tumbling; Stunned.fall_type
scenes/world/wizard/wizard_body.tscn, .gd      M  Afflictions/Tumbling; una línea: velocity = _afflictions.steer(...)
scenes/world/unit_body.gd                      M  +1 steer, −1 (else/if aplanado): neto 0
debug/f121_push.tscn + rules/f121_push.tres    N  carriles A (Squall → Druid), B (Vortick → Druid trabado con un Trogg), C (Flurry → 3 Druids)
agent/run_determinism.sh                       M  caso f121 (0,5 min)
```

*Criterios (log con números):*
1. **Squall:** el Druid se desliza `15·|dir_xz|` m (±0,3 m) en 40 ticks y no cambia de altura más que el relieve. Log `empuje <cuerpo> … m en 40 ticks`.
2. **Vortick:** el blanco sale arrojado. El ápice (sobre el suelo de partida) y el desplazamiento al aterrizar coinciden ±10 % con la réplica de sacengine (`agent/tools/f121_expect.py`) desde el mismo punto relativo al centro del vórtice. Log `tumbo <cuerpo> desde …`, `ápice … m`, `aterriza … a … m, vz …, caída …`.
3. **Aterriza y vuelve a pelear:** después de `aturdido tras caer … (hit_floor+get_up)·2` llega «se levanta» a esos ticks (±2) y el Druid y el Trogg vuelven a pegarse.
4. **Flurry:** los Druids van hacia el centro de la implosión hasta tocar las cápsulas de los otros. El Druid lejano (12,42 m) recorre ±10 % del tirón de la réplica y queda a ≤ 1,3 m del centro (réplica sin choques: 0,04 m).
6. **Aterrizar sobre algo (REVIEW-F121 B1):** un cuerpo arrojado que cae sobre un edificio u otra cápsula aterriza por contacto de suelo (`is_on_floor` después de `move_and_slide`), con el mismo daño de caída y el mismo `fall_down`. Carril D: el Druid sobre la choza `Bld068_jhut` aterriza «sobre Bld068_jhut» y se levanta 286 ticks después.
5. **Determinismo:** `quick` PASS y `f121` igual en los 3 modos. Los digests de la línea base no cambian (las tres son de nivel ≥ 2).

*Divergencias declaradas:*
- Un híbrido arrojado deja el tumbo en el ápice, pero no vuelve a volar: cae con la gravedad del cuerpo.
- Sobre el borde de un agujero, `GroundGuard.hold_on_ground` puede frenar el tumbo.
- La caja del vórtice usa la cápsula del cuerpo como caja.
- **Cápsulas (B2):** en el port, las cápsulas de `CharacterBody3D` no se atraviesan. En sacengine, la implosión mueve `position` sin `positionAfterCollision` y los cuerpos se solapan en el centro. Por eso el tirón de la implosión termina donde se tocan las cápsulas (≈ 1,1-1,3 m con 4 Druids).
- **`BodySeparation` en el tumbo (m4):** `BodySeparation.resolve` también corrige la velocidad del cuerpo en tumbo. Es el equivalente de `positionAfterCollision`, pero con otro reparto. Dos cuerpos arrojados juntos se separan en el aire (el Trogg del carril B cae a 15,98 m contra 12,88 de la réplica de un cuerpo solo). Un cuerpo que cae sobre otra cápsula se desliza al costado.
- **Petrificado (m3):** no se lo puede arrojar, porque `tumbling` no cancela `petrified`. En sacengine, `catapult` lo acepta (modo `stunned`).
- **Rockform (m3):** un Earthfling en Rockform arrojado aterriza con `fall_down` (hitFloor + getUp) y sigue en Rockform. En sacengine sigue en `rockForm` y no reproduce hitFloor.
- **`fasterStandupTimes` (m3):** `WIZARD_STUN_ANIM_SLOTS` exporta `hit_floor` (slot 8) sin el arreglo de `sacobject.d:844-874`. Para 7 magos (yogo, seerix, acheron, buta, charlotte, shakti, marduk), sacengine usa knocked2Floor en lugar de hitFloor, así que acá yacen otro largo.
- **Altura sobre edificios:** `BodyNudge.floor_y` toma la altura propia del cuerpo cuando está apoyado sobre algo por encima de la tierra (sacengine `getHeight` cuenta los techos). Así, un empuje o un tirón sobre un techo no lo baja a la tierra.

*Deuda (no se arregla en F121):*
- **m1:** hay dos escritores de `Tilt.rotation:z` (`Stunned` y `Tumbling`). Hace falta un único dueño de la pose derivado de `clip_role`, y va con el sistema de animaciones.
- **m5:** quedan rutas por string (`"Afflictions/Tumbling"`, `"Collision"`, `"Flight"`) en `BodyNudge` y `Tumbling` en lugar de sockets `@export`.
- **`previous`:** un cliente que entra tarde ve knock en vez de hitFloor (solo cosmético). Se arregla con un tipo o bit propio para «caído».

**Resultado (developer de F121, 2026-10-17)** — `debug/f121_push.tscn`, semilla 7, comparado con `agent/tools/f121_expect.py`:
- **Escena real:** carril A (z −80) Squall → Druid pacifista a 20 m. Carril B (z +80) Vortick → Druid a 25 m trabado con un Trogg propio a 26,5 m. Carril C (z +80, x negativo) Flurry en x −10 → 3 Druids pacifistas en x −40 y uno en x −52 (z +200 tiene una ladera de 12 m y x −90 en z −80 es un agujero).
- **C1 Squall:** 15,00 m en 40 ticks, plano 14,94 m = 15·|dir_xz| 14,94.
- **C2 Vortick (Druid):** ápice 6,91 m (réplica 6,91), aterriza a 6,34 m (6,31), vz −11,12 (−10,98), caída 162 (160); 170 ticks. **Trogg:** ápice 6,84 (6,85) pero 15,98 m contra 12,88 (124 %): los dos cuerpos chocan en el aire (la réplica es de un cuerpo solo). Con el Trogg solo, en la misma escena: ápice 7,01 / 7,01 y 5,72 / 5,70 m.
- **C3:** «aturdido tras caer … 286» (Druid: hitFloor 67 + getUp 76) y «se levanta» a los 286 ticks. Después, `struck Trogg1 -> Druid2` desde el tick 622.
- **C4 Flurry:** el Druid a 12,42 m termina a 1,30 m del centro (réplica 0,04 m). Los cercanos quedan a 1,1-1,3 m: las cápsulas de los cuerpos no se atraviesan en el port, y en sacengine sí (la implosión mueve `position` sin `positionAfterCollision`). **Divergencia nueva**, heredada de la física de los cuerpos.
- **C5:** `quick` PASS (s7, f139, s1_quick y f148 iguales a la línea base). `f121` da 9fc5b190 en fixed, stress y window, y entra en `quick` y en `det_baseline.txt`. `rules_suite` PASS (con `sim_rng_lint`).
- **Corrección (REVIEW-F121):**
  - **C6 (B1):** el Druid del carril D aterriza «sobre Bld068_jhut» (vz −11,13, caída 163). Queda aturdido 286 ticks y se levanta en el 1053.
  - **m2:** `sweep` en `amba` y `cita`.
  - **Digest nuevo de `f121`:** fcefa9a3, igual en fixed, stress y window, y actualizado en `det_baseline.txt`.
  - **`quick`:** s7, s1_quick, f148 y f121 dan OK. `f139` falla (a267c95b contra af04fefb) por la fase 1 de 030k-a (veneno sin cablear) que está en el árbol, no por 030j.

### 030k — F122 Veneno y congelación a distancia (Necryl, Deadeye, Hellmouth, Silverback)

**Árbol**
- N: `impacts/poison_impact.tscn` y `impacts/freeze_impact.tscn`.
- N: `scenes/world/units/poisoned.gd` y `frozen.gd` (efectos hijos).
- M: `data/shots/cena|lfda|mhba|rdba.tres`.

**Escena de prueba:** `res://debug/f120_poison.tscn`. **Criterio:** daño por segundo medido; el congelado no se mueve.

#### 030k-a — F122 Veneno a distancia (Necryl `cena`, Deadeye `lfda`, Hellmouth `mhba`) y debuffs de `cen@`

**Plan (developer de F122, 2026-10-17):** el del tech lead en `rfcs/plans/030k-030l-plan.md` §030k-a (sacengine, diseño, árbol y criterios), sin cambios de árbol.
- `Poisoning` (`scenes/world/units/poisoning.gd`, hijo `Poisoning` de `unit.tscn` y `wizard_body.tscn`) es el único dueño.
  - Sus hijos son las dosis `Poisoned` (`extends DamageOverTime`) y las corre en orden en `_physics_process`, solo en servidor o solo.
  - Los agregados se derivan de las dosis vivas en cada consulta: `resistance_bonus()` = 1e-3·Σ ires, `regeneration_factor()` = Π freg, `mana_blocked()` y `damage_sum()` = Σ int(por s).
  - El contagio usa `BodyNudge.box(...).grow(2 m)` + `bodies_in`, y el enfriamiento es `vida + 180` ticks de `MatchClock`.
- `DamageOverTime.step()` da `lifetime + 1` actualizaciones: daña, termina si `frame >= lifetime` y recién después suma `frame`.
- Health, ManaPool y MeleeAttack le preguntan a `Poisoning`:
  - `Health.resistance` = `max(0, base + bonus)`;
  - `Health.regenerate(amount)`, que `unit_body` y `wizard_body` llaman en lugar de `heal` (neto 0);
  - `ManaPool.add` no da nada con el maná bloqueado;
  - `MeleeAttack.roll_damage` suma el bono dentro del max.
- `PoisonImpact`: con criatura o mago, `drenaje = amount·drain` del tirador y dosis DIRECT_RANGED; con un edificio, daño directo. `disease_impact.tscn` es la misma con `infectious = true`.
- `AbilityType.args` viene de `abilities.json`. La nube `cen@` envenena con sus `ires 1000` / `freg 0`.

**Resultado (developer de F122, 2026-10-17):** `debug/f122_poison.tscn` (caso `f122` del banco), semilla 7, comparado con `agent/tools/f122_expect.py`:
- **C1 Deadeye:** `veneno Druid4 total 499.3 en 601 actualizaciones`. El drenaje lleva al Deadeye de 585 a 945.
- **C2 Hellmouth:** 61,538/s × 0,9 = 0,923 por tick: 110,8 en 120 ticks (total de la dosis: 554,8 en 601). El Hellmouth pasa de 2700 a 3100.
- **C3 Necryl:** drenaje de 630 a 730 y `Druid1 regeneración ×0.00` mientras dura (vuelve a ×1.00 al terminar).
  - El primer tick no se loguea aparte. Sale de 15,385/60 × (0,9 + 1) = 0,4872, y el total de Druid1 coincide exacto con la réplica, que usa ese tick.
- **C4 Contagio:**
  - `Druid2 infectado por Druid1: 15/s, 600 cuadros` y, una sola vez, `Druid1 reinfectado por Druid2: 15/s, 600 cuadros`. Druid3 (control, a 6 m) no aparece nunca.
  - Druid1 muere en la actualización 546 de su dosis, igual que la réplica en orden port; sacengine da 545, dentro de ±2.
  - Druid2 termina con 515 de vida, contra 514,5 de la réplica.
- **C5 Maná:** `maná bloqueado por Dose (cuadro 120, tick N)` sale 120 ticks después de cada impacto (Druid5 en el 183; Druid1, Druid2 y Druid4 en el 197).
  - La dosis de reinfección de Druid1 se bloquea en el 198, un tick después, porque se le dio cuando su Poisoning ya había corrido ese tick.
  - `maná libre` sale cuando termina la última dosis.
- **C6 Determinismo:**
  - `f122` da aab853fc en fixed, stress y window, y entra en `quick` y en `det_baseline.txt` (con el carril A movido, ver abajo).
  - `quick`: s7, s1_quick, f148 y f121 iguales a la línea base.
  - `f139` cambia (declarado: tiene un Necryl). Da 5ade9305 en fixed, stress y window y se regrabó la línea base. El `f139_fixed2` que queda en `agent/out/det` es de una corrida vieja.
  - `rules_suite` PASS.
  - No se corrieron `f116` ni `f117`.

*Desvíos del plan:*
- **Carril A movido (playtest):** en z −80 los Druids quedaban dentro de la roca `bld3` del mapa, en (1300, 1190), y solo se veían sus barras de vida. Ahora el Necryl está en x +35 / z −50 = (1305, 1220) y los Druids en x +65 (1335, 1220; 1335, 1221,5; 1335, 1214), con las mismas distancias relativas. El lugar se eligió con `high_noon_terrain.bin` + `high_noon_widgets.json` / `high_noon_ntts.json`: 0,3 m de desnivel en el Necryl, 0,66 m en el grupo de Druids, línea de tiro libre y el accesorio más cercano (JAW1) a 14 m. Los números no cambian.
- El kill del Necryl pasa de 10 s a 8 s: a 10 s alcanzaba a disparar una segunda vez (tick ≈ 545) y la medición ya no era de una sola dosis.
- Los logs de `Poisoning` nombran el nodo (`Druid4`), no el tipo, para distinguir A1, A2 y A3.
- Un cuerpo sin hijo `Poisoning` no se envenena y lo dice en el log (`veneno: X no tiene Poisoning`).

*Divergencias declaradas:*
- Las del plan: contagio en cada tick, sin la cola de IA; sin el ×1,5 del guardián, sin `iacc` y sin el drain general de `dealDamage`.
- Nueva: una dosis que se le da a un cuerpo cuyo `Poisoning` ya corrió en ese tick arranca en el siguiente. En sacengine la lista es global y corre en el mismo cuadro, así que acá llega 1 tick tarde.
- Visto en `f139`: el Necryl en melee se infecta de su propio blanco. El contagio no mira el bando, igual que en sacengine.

#### 030k-b — F149 Congelar a distancia (Silverback `rdba`)

**Plan (developer de F149, 2026-10-17):** el del tech lead en `rfcs/plans/030k-030l-plan.md` §030k-b, sin cambios de árbol. Se hizo en dos fases: primero archivos nuevos sin referencias, en paralelo con 030k-a; después el cableado.
- `Frozen` (`afflictions/frozen.gd` + `data/afflictions/frozen.tres`, bit 3) es un `Affliction`:
  - `try_freeze_with_cooldown` rechaza `cc_protected` y muertos. Con enfriamiento > 0 tira `uniform(600)` con `MatchSeed ["freeze", nombre]`, y si la tirada deja intentar, el enfriamiento vuelve a 600.
  - `freeze` dura `ceil(60·1000/vidaMáx·20)` en float32, como sacengine (`_f32` en cada paso, REVIEW N6): Trogg 1250, y 801 (no 800) para Sara Bella y Gangrel (1500 de vida). Un mago dura 300. No cuenta el cuadro en que arranca.
  - Termina por tiempo (deshielo en el mismo tick) o con `Health.hit` > 0 (deshielo en el tick siguiente).
  - El deshielo hace 150 de hechizo directo del bando que congeló, más las esquirlas `freeze_shards`.
- Pose: el único dueño es `Afflictions._show` (`clip_pose.frozen = immobilized()`); `Petrified` ya no la escribe. `Petrified.can_be_immobilized` es estática y la usan los dos.
- `ShotInFlight` (`shot_in_flight.gd`) es lo que el disparo hace en cada tick de vuelo:
  - `ShotLook.dropper` pasa a `in_flight` y `ShotDropper` pasa a ser un `ShotInFlight` (`f148` no cambia).
  - `FrostWave` (`frost_wave.gd/.tscn`): radio `7,5·frame/(60·40/36)` y recorrido `SplashDamage.bodies_within` con memoria de tocados. Al blanco: 500 directo a distancia y después congela. Al mismo bando: nada. Al resto: `500·(1−d/r)` como salpicadura y congela al final del update.
  - `ShotLook.collides = false` (`rdba.tres`): no choca con cuerpos ni con el suelo y vuela 40 m.
- El look del mesh también tiene un solo dueño, `Afflictions.look`: un único `StoneLook` por cuerpo (nodo `Afflictions/Look`).
  - Lo resolvió REVIEW-030k-b B1: antes Petrified y Frozen escribían cada uno los overrides de material del mesh.
  - `_show` elige el `look_tint` del estado encendido con `has_look` y mayor `look_priority` (petrificado 2, gris; congelado 1, hielo (0,6, 0,85, 1)) y lo apaga cuando no queda ninguno. Es idempotente.
  - `StoneLook.tint` llega al `stone_tint` del shader. La caché de materiales usa `[fuente, tint]` como clave.
- FX: `frost_breath` (`cst0_a`, alfa con mezcla normal; aditivo sobre la nieve da blanco) como `trail_fx` del aliento, y `freeze_shards` (`shrd`). Se regeneraron con `tools/export_particles.py`.

**Resultado (developer de F149, 2026-10-17):** `debug/f149_freeze.tscn` (caso `f149` del banco), semilla 7, comparado con `agent/tools/f149_expect.py`:
- **C1 Congelación:**
  - Trogg1 (D1) recibe 450 directos y queda `congelado durante 1250`.
  - Druid1 (D2) recibe la caída: 14, contra 14,0 de la réplica (tick 22, d 2,29 m, r 2,36 m), y queda `congelado durante 1500`.
  - Los dos alientos hacen 67 actualizaciones.
- **C2 Quietud** (ventana, `pt149_watch`): desplazamiento 0,0000 m en los tres congelados, 0 golpes mientras duran y el tinte de hielo en todos los cuadros (1249/1249 y 1499/1499).
- **C3 Fin:** Trogg1 se descongela en el cuadro 1325 con `deshielo 0 (inmune)`; Druid1, en el 1580 con 150. Sin derribo, vuelven a idle.
- **C4 Rotura:** E1 (Druid2) se congela en el 75. El veneno del Deadeye llega en el 103; el primer tick rompe el hielo en el 104 (0,83 de daño) y el deshielo de 150 llega en el 105.
- **C5 Determinismo:**
  - `f149` da bf28b3fd en fixed, stress y window, y entra en `quick` y en `det_baseline.txt`.
  - `quick` PASS: s7, f139, s1_quick, f148, f121, f122 y f123 iguales a la línea base.
  - `f137` (pt137_main): clip_changes 0, drift 0 y ×0,2 con piedra.
  - `rules_suite` PASS.
- Capturas en `agent/out/pt149/`: onda en vuelo, Trogg y Druid congelados, deshielo con esquirlas, E1 congelado y hielo roto por el dardo.

**Corrección de la review (REVIEW-RFC-030k-b, 2026-10-17):**
- **B1:** el look del mesh pasa a tener un solo dueño, `Afflictions.look` (ver el plan).
- **N1:** se corrigió el comentario: en sacengine una caída de más de 0 también rompe el hielo (`state.d:9037`).
- **N2:** se quitó `cooldown_ticks()`.
- **N3:** `RangedShot` ahora tiene `class_name` y `ShotInFlight` / `FrostWave` lo usan tipado.
- **N4:** se usa `get_node_or_null("Health")`.
- **N5:** `FrostWave.log_touches` es estático y viene apagado; lo enciende `debug/ai_match.gd`, como `DropletRain.log_hits`.
- **N6:** la duración usa float32 exacto en lugar del épsilon.

Después de la corrección:
- `f149` sigue dando bf28b3fd en fixed, stress y window.
- `quick` PASS.
- `f137` (pt137_main): grey en todos los cuadros, clip_changes 0 y drift 0. La piedra se ve gris en la captura.

*Desvíos del plan:*
- **Carriles en z +140 (D) y z +200 (E).** Son los que están libres de rocas, estructuras y accesorios en `high_noon_ntts.json` / `high_noon_widgets.json`; en z −80 está `bld3`.
- **D2 en x +22, z +143.** A 18 m quedaba más cerca que D1 y `attack_unit` (el más cercano) lo elegía como blanco.
- **El Deadeye en x +20, z +260,** a 60 m de E1 de costado: en x −40, z +200 cae a un hueco. Muere a los 9 s (una sola dosis).
- **0,6 min,** porque D2 deshiela en el cuadro 1580.
- **Esquirlas teñidas:** `freeze_shards` lleva un `color_ramp` azul hielo. El atlas `shrd` es casi blanco y se pierde sobre la nieve; el original lo dibuja tal cual.

*Divergencias declaradas:*
- Las del plan: un golpe de 0 no rompe el hielo; el deshielo por golpe hace el daño un tick después; un cuerpo en tumbo no se congela; el hielo es un tinte, no el cubo `frez`.
- Nueva: en el primer update el radio es 0 y no toca a nadie.
- Fuera de este corte: `healBlocked` (curas bloqueadas mientras dura, igual que en Petrified) y el sonido `3zrf`.

### 030l — F123 Disparos de fuego (Tickferno, Pyromaniac, Bombard)

**Árbol**
- N: `impacts/burn_impact.tscn` (si el efecto propio lo pide).
- M: `data/shots/sfba|lffa|cfba.tres`.

**Escena de prueba:** `res://debug/f121_fire_shots.tscn`. **Criterio:** forma de vuelo y daño de cada uno contra el original.

**Plan (developer de F123, 2026-10-17):** el del tech lead en `rfcs/plans/030k-030l-plan.md` §030l, con estas precisiones:
- `Burning` (`scenes/world/units/burning.gd`, `extends DamageOverTime`) es un `Fire` de sacengine.
  - `Burning.ignite(...)` hace de `setAblaze` / `setAblazeWithManaDrain`: `damage/lifetime` por actualización, `lifetime + 1` actualizaciones (lo cuenta la base) y `mana_drain/lifetime` con `ManaPool.drain`.
  - Las partículas `fire` (FxBus) salen solo sobre criaturas y magos, aunque el fuego no haga daño.
  - Un fuego no suma nada con otros (no hay agregados como en `Poisoning`), así que cada `Burning` es su propio dueño: cuelga del cuerpo que quema, avanza solo en `_physics_process` y se libera al terminar.
- `BurnImpact` (`impacts/burn_impact.gd`) tiene knobs de monto (del disparo o ninguno), duración (la del SPEL o fija), `kind`, `pierce_shield`, fracción de maná y radio de salpicadura. Las variantes son escenas:
  - `heat_ray_impact.tscn`: sfba, drena 0,5 del maná máximo.
  - `rocket_impact.tscn`: lffa, con `pierce_shield`.
  - `bombard_impact.tscn`: cfba, `SplashImpact` más un `BurnImpact` visual de 60 cuadros sobre el tocado y el radio.
- `Health.damage_typed(..., pierce_shield)`: con `peirceShield` no se aplican `damage_factor` (Rockform, Life Shield) ni `_state_factor()` (petrificado). `DamageOverTime.pierce_shield` lo pasa.
- `ManaPool` (ahora con `class_name`) tiene `drain(amount)`: baja sin pasar de 0 y el veneno no la bloquea.
- `data/shots/sfba|lffa|cfba.tres`.
- `data/fx/fire.tres`: atlas `firy` 4×4, energía 8, delay 2, agregado a `tools/export_particles.py`.

**Resultado (developer de F123, 2026-10-17):** `debug/f123_fire_shots.tscn` (caso `f123` del banco), semilla 7, comparado con `agent/tools/f123_expect.py`:
- **C1 Tickferno:** `fuego Druid1 total 216.9 en 61 actualizaciones … maná -50.83 (queda 49.17)`.
- **C2 Pyromaniac:** `fuego Trogg1 total 866.9 en 301 actualizaciones`, sin daño directo.
- **C3 Bombard:** el tocado queda con 282,5 de vida (517,5 de daño). Los otros dos Druids, a 2,54 m y 3,16 m de la caja, reciben 386 y 354, que es `575·(1−d/10)·0,9`. Los tres tienen `fuego … total 0.0 en 61 actualizaciones`.
- **C4 Vuelo:**
  - `vuelo sfba 39.20 m, 49.0 cuadros a 48 m/s`, contra 50 ±2 esperados;
  - `vuelo lffa 51.00 m, 51.0 cuadros a 60 m/s`, contra 50 ±2 esperados;
  - `cfba` ya era balística, con g 30 (`RangedAttack.BALLISTIC`).
- **C5 Determinismo:**
  - `f123` da d7db648e en fixed, stress y window, y entra en `quick` y en `det_baseline.txt`;
  - `quick` PASS, con s7, f139, s1_quick, f148, f121 y f122 iguales a la línea base (ninguno trae estas criaturas);
  - `rules_suite` PASS.
- **Ventana** (`agent/flows/pt123_play.json`, capturas en `agent/out/pt123/`): se ven la estela del rayo de calor, el fuego sobre el Trogg y las llamas de la Bombard sobre los Druids.

*Desvíos del plan:*
- **Carril C a 25 m:** a 60 m, hacia +x y hacia −x desde (1270, 1470), los tres Druids caían al vacío. Las demás distancias relativas (3 m entre Druids) se mantienen.
- **Carriles en z +80, +140 y +200:** se evita la roca `bld3`.
- `Burning` es su propio dueño, sin un nodo agregador en `unit.tscn`.

*Divergencias declaradas:*
- Las del plan: no hay incendio de edificios (`igniteBuilding`) ni `DamageMod.ignite` (030r).
- El rayo y el humo del cohete usan visuales de reserva: la estela del rayo es una ristra de `fire` y la del cohete es `steam`.
- Las partículas de fuego salen como una ráfaga de 30 cada 10 ticks, no 3 por cuadro.
- No hay lista global de fuegos: cada `Burning` avanza en el orden del árbol. sacengine los saca con swap-remove.
- `pierce_shield` no se ejercita en la escena (el Trogg no tiene escudo); se verifica en la review.

**Corrección (developer de F123, 2026-10-17; review APPROVE con menores, playtest visual FAIL):**
- **V1, fuego blanco:**
  - El original suma `firy` con energía 8. Sobre la nieve, sumar luz solo puede llegar al blanco.
  - Por eso `tools/export_particles.py` escribe además `firy_a.png`, el mismo brillo como overlay de alfa recta (`glow_to_alpha`: el tono a pleno, y alfa = brillo·3), con un promedio de color de (254, 171, 100).
  - `fire.tres` pasa a `blend_mix` con energía 1 y `alpha_max` 0,85. También es más chica y lenta: escala de 0,6 a 0,9, velocidad de 0,3 a 1,2 m/s y vida de 0,8 s.
  - `Burning` la emite a `fire_height_m` (0,8 m, knob de `BurnImpact`), por debajo de la barra de vida.
  - Medición en la caja del cuerpo, proyectada por `pt123_watch`:
    - `k1_druid1_burning.png`: R 0,674 / G 0,598 / B 0,506, con luminancia 0,607;
    - `k5_trogg_burning.png`: R 0,595 / G 0,531 / B 0,495, con luminancia 0,542;
    - antes del fuego (`k0`), la caja daba 0,789 y gris.
  - La barra se lee en las dos capturas.
- **V2, explosión de la Bombard:** sacengine lanza 80 partículas `fire`, de escala 2 a 10, sobre el disco `effectRange` y subiendo (`bombardProjectileExplosion`, state.d:24529-24541). Se agregó `data/fx/bombard_fire.tres` (60 partículas, escala 2 a 5, radio 6 m, el mismo atlas) y es el `impact_fx` de `cfba.tres`. Se ve en `k2_bombard_explosion.png`.
- **M1:** se sacó `RangedShot.traveled()`. El vuelo lo mide `pt123_watch`, desde el tick en que aparece el disparo hasta el tick en que se va: lffa 51, sfba 49 y cfba 32 ticks.
- **M2:** `AfflictionType.damage_factor` queda documentado como de escudos solamente, porque `pierce_shield` lo saltea.
- **M4:** `ManaPool` tipado en `BurnImpact`.
- **Nit:** se reescribió el comentario de `DamageOverTime` (el dueño de las dosis, o la dosis misma si no hay nada que sumar).
- **M3, declarado:** `Burning.ignite` no pone el fuego visual sobre un cuerpo que acaba de morir; sacengine sí, porque `updateFire` solo mira el tipo.
- `f123` sigue en d7db648e en fixed: el look no es simulación.

### 030m — F124 Rayos y armas (Gnome, Warmonger, Styx)

**Árbol**
- N: `impacts/bolt_impact.tscn` (patrón `StyxBolt`/`StyxExplosion`).
- M: `data/shots/plfa|fhga|dhga.tres`.

**Escena de prueba:** `res://debug/f124_bolts.tscn` (los carriles C y E del Warmonger, en 030m-b). **Criterio:** daño y radio medidos.

**Plan (developer de 030m-a, 2026-10-17):** el del tech lead en `rfcs/plans/030m-030n-plan.md` §030m. Gnome, Styx y Warmonger no tienen proyectil, así que `bolt_impact` pasa a ser «strikes»:
- `ShotLook.strike` (PackedScene) y `ShotLook.for_tag` (la única búsqueda de `data/shots/`, que antes era `RangedShot._look_for`).
- `RangedAttack._fire`: precisión con `ShotAim.scatter` (sacada tal cual, mismo orden de sorteos) y diccionario con `aim_x/y/z` y `accuracy`. Si el look tiene `strike`, lo instancia como hijo propio, solo en el servidor, y llama a `launch(data, look, self)`. `shot_origin()` pasa a ser público.
- `ShotImpact.land(holder, look, target, point, ability)` (estático) es el único dueño de lo que pasa donde pega un disparo o un strike: impacto o daño directo, y después `impact_fx`. `RangedShot._burst` lo usa. Devuelve el daño directo recibido.
- `scenes/world/units/strikes/`:
  - `ShotStrike` (Node3D, prioridad −1, mismos nombres que `RangedShot`). El tick 0 corre en `launch`; después corre los ticks que avanzó `MatchClock`.
  - `RayStrike` (ráfagas, `first_tick`, período, rayos, `reroll`, `follow`, `foes_only`, beam).
  - `TargetStrike` (golpe en `land_tick`, en el centro del blanco vivo o en el punto apuntado).
  - `gnome_ray.tscn` y `styx_strike.tscn`.
- `data/shots/plfa.tres` (strike `gnome_ray`, fx `gnome_hit`) y `dhga.tres` (strike `styx_strike`, impacto `splash_impact.tscn`, fx `styx_spark`).
- Beams `data/fx/beams/gnome_flame.tres` (gmfl 2×2, 1,7 m, 16 ticks: el `GnomeEffect`, que es un fogonazo en la boca y no un rayo, sacobject.d:4268-4283) y `styx.tres` (ltn2, 1 bolt de ancho 1,5, 64 ticks, cambia cada 6, sigue al blanco).
- Partículas `gnome_hit` (gsqb) y `styx_spark` (styx), dibujadas como overlay de alfa (`gsqb_a`, `styx_a`, `glow_to_alpha`) con `blend_mix`, como el fuego. `warmonger_hit` (wsqb) ya queda exportada para 030m-b.
- Logs (`rayo …`, `golpe …`) apagados en el producto: los enciende `ShotStrike.log_strikes` desde `debug/ai_match.gd`.

**Resultado (developer de 030m-a, 2026-10-17):** `debug/f124_bolts.tscn` (caso `f124` del banco), semilla 7:
- **C1 Gnome (A):** `rayo plfa Gnome1 → Druid1 a 61.1 m: 540.0` en el mismo tick que `fired` (rel 11 en la ventana). Druid1 queda en 260 y el maná del Gnome pasa de 200 a 187.
- **C2 Aliado (B):** `rayo plfa Gnome2 → Trogg1 (aliado) a 1.8 m: 0.0`. Trogg1 queda en 960 y Druid2 en 800.
- **C3 Styx (D):**
  - `fired` en rel 102 y `golpe dhga Styx1 → Druid3` en el tick siguiente;
  - aparece `salpicadura dhga … radio 10.0 m de 500`;
  - Druid3 (D1) pierde 450, Druid4 (D2, a 3,77 m) pierde 280,35 = 450·(1−0,377) y Druid5 (D3) pierde 0;
  - el maná del Styx pasa de 500 a 467, un solo disparo antes de morir en rel 270;
  - el beam se ve en `d1_styx_bolt.png` y `d2_styx_splash_sparks.png`.
- **C6 Determinismo:**
  - `f124` da c5abf4c8 en fixed, stress y window, y entra en `quick` y en `det_baseline.txt`;
  - `quick` PASS, con s7, f139, s1_quick, f148, f121, f122, f123 y f149 iguales a la línea base (`ShotAim` y `land` son neutros);
  - `rules_suite` PASS.
- **Ventana** (`agent/flows/pt124_play.json`, `agent/harness/pt124_watch.gd`, capturas en `agent/out/pt124/`): se ven las chispas verdes del golpe del Gnome sobre Druid1 (`a2`) y sobre el Trogg aliado que frena el rayo (`b1`), y el bolt del Styx hasta los Druids (`d1`, `d2`).

*Desvíos del plan:*
- **B2 en +173/+60 (a 3 m del Gnome), no en +227:** el carril B baja ~1 m cada 8 m. A 8 m o a 57 m el rayo le pasaba al Trogg por arriba o al costado (con semilla 7 la precisión 150 sorteó un azimut de 2,9°, casi el máximo). Es fiel: sacengine también falla.
- **Beam `gnome_flame` (fogonazo de 1,7 m), no `gnome_ray`:** el `GnomeEffect` original es eso, no un trazo hasta el blanco.
- Las chispas del Styx van en `dhga.impact_fx` (las lanza `land`); el strike solo tiene el beam.

*Divergencias declaradas:*
- Las del plan: el rayo se corta en rocas y estructuras, y no hay `StyxExplosion` ni `igniteBuilding`.
- **El fogonazo del Gnome no se ve sobre la nieve** (`a1_gnome_flame.png`): el beam se dibuja solo con `blend_add`, energía 10, y el verde sumado sobre el blanco se satura. Queda para un pase visual (el shader de beam no tiene modo mix).
- Las chispas `styx_spark` no se distinguen en la captura con la cámara alta: los Druids quedan chicos en cuadro.
- El origen del `StyxBolt` no sigue al tirador; el final sí sigue al blanco.
- La salpicadura del Styx alcanza la choza `Bld069_jhut` a 8,01 m del carril D. No aparece en los eventos `hurt` del banco.

**030m-b: Plan (developer, 2026-10-17):** el del tech lead en `rfcs/plans/030m-030n-plan.md` §030m (carriles C y E), sobre 030m-a.
- `strikes/warmonger_gun.tscn`: `RayStrike` con `bursts 16`, `first_tick 2`, `period 4`, `rays 2`, `reroll`, `follow`, `foes_only`, prioridad −1, `label "ametralladora"`. Sin beam: sacengine no dibuja fogonazo del arma (el `SacWarmongerEffect` es la llama del modelo); solo `warmongerHit` donde termina cada rayo.
- `data/shots/fhga.tres` (strike `warmonger_gun`, `impact_fx` `warmonger_hit`) y `data/fx/warmonger_hit.tres`: 20 partículas, vida 31 ticks (0,517 s), velocidad 0,8–3,2, gravedad, `pool_max` 20 (15 ráfagas/s × 2 rayos × 0,517 s × 1,25 ≈ 19).
- `tools/export_particles.py`: `warmonger_hit` pasa a `wsqb_a` (overlay de alfa, `glow_to_alpha`, `blend_mix`, energía 1) con `lifetime_frames` 31 (antes 63). Sobre la nieve, nada aditivo.
- M1 y M2 de la review de 030m-a: `RangedAttack` tiene `class_name`, `ShotStrike.source` y `launch(from)` son `RangedAttack`, `RayStrike` llama `source.shot_origin()` directo (sin `call` ni `has_method`) y `BreathOfLife._origin` también.
- `debug/rules/f124_bolts.tres`: carriles C y E **al final** (los cuerpos A, B y D no se renumeran). Harness `pt124_watch` ve a Warmonger1/2, Druid6/7 y Trogg2.

**030m-b: Resultado (developer, 2026-10-17):** semilla 7, `f124` fixed/stress/window = `3a9bb548` (baseline regrabada). Carriles A, B y D dan las mismas líneas que antes.
- **C (Warmonger1, `nugf`):** `fired` en el tick 107 (ticks de `MatchClock` en el log: 109 + 4k).
  - Exactamente 16 `ráfaga k/16` (109, 113, …, 169) y 32 `rayo fhga`.
  - Druid6 (C1) recibe 5 rayos de 72 (`hurt direct_ranged`), el resto termina en `suelo` o `nada`.
  - `rayo fhga Warmonger1 → Trogg2 (aliado) a 34.5 m: sin daño (aliado)`; Trogg2 queda en 960.
  - Maná de Warmonger1 500 → 467, una sola vez (muere en el tick 270, antes de la segunda tanda).
- **E (Warmonger2):** muere a los 2,2 s; `ametralladora fhga cortada: tirador muerto tras la ráfaga 7/16` y ningún rayo después.
- **Pruebas:** `quick` PASS (todas las líneas base iguales, f124 incluida), `rules_suite` `--fixed-fps 60` PASS.
- **Ventana** (`pt124_play`, capturas `c0_lane_before`, `c1_gun_hits_druid_a/b`, `c2_ally_stops_ray(_b)` en `agent/out/pt124/`): las chispas naranjas de `warmonger_hit` se distinguen de la nieve (R−B ≈ +130 en los píxeles de chispa contra −2 del pasto) sobre Druid6 y sobre el Trogg que frena los rayos.

*Desvíos del plan:*
- **Carril C movido a (1375, 1155)** (offset +105/−115; C1 +143/−115): el del plan, (1290, 1250), tiene una choza `jhut` (1313, 1239) con huella grande que corta la línea de tiro y el Warmonger no disparaba hasta el tick 254. Un segundo intento en (1320, 1155) tenía una loma de 5 m en medio. El elegido tiene suelo sin huecos, ningún `ntts` a menos de 26 m del tramo y el terreno por debajo de la línea de tiro (script de búsqueda con `terrain.bin`).
- **C2 en +141,5/−114,3 (1 m delante de C1 y 0,7 m al costado), no a +1,5 m al costado:** a 8 m del tirador los rayos le pasan por arriba (el Warmonger dispara desde alto y el rayo baja hacia el centro del Druid); pegado al blanco sí lo frena, como en B de 030m-a.
- Warmonger1 muere a los 4,5 s, después de las 16 ráfagas (la tanda dura hasta el tick 169).

*Divergencias declaradas:*
- Sin `igniteBuilding` ni `iacc`; el rayo se corta en rocas y estructuras (las del plan).
- Sin fogonazo en la boca (sacengine tampoco lo dibuja).

### 030n — F125 Disparos grandes (Boulderdash, Phoenix, Rhinok)

**Árbol:** M `data/shots/emba|rdra|hrba.tres` (más un impacto si hace falta).

**Escena de prueba:** `res://debug/f123_big_shots.tscn`. **Criterio:** daño y forma medidos.

**Plan (developer de 030n-a, 2026-10-17):** el del tech lead en `rfcs/plans/030m-030n-plan.md` §030n, sobre 030m-a.
- `ShotLook.volley` (1 por defecto) y `ShotLook.range_factor` (1 por defecto).
- `RangedAttack._fire`: en la rama sin `strike`, un bucle de `volley` disparos con la misma dirección (una sola tirada de precisión). Cada paquete es una copia del diccionario, con `volley_index` (−k..k) y `aim_distance` (|apuntado − origen|). `max_distance` pasa a ser `cast_range · range_factor`.
- `RangedShot.spawn_data`: el paquete con el que nació. Lo lee su `ShotInFlight`.
- `ShotSplit` (`split_flight.gd/.tscn`, un `ShotInFlight`):
  - cuenta `max(0, aim_distance − 60)` hacia abajo, a `speed/60` por tick;
  - el tick en que baja de 0, las laterales giran `índice · 3,5°` alrededor de `Vector3.UP`, después del movimiento de ese tick (el orden de `updateBoulderdashProjectile`, state.d:24729-24755);
  - el log `abanico …` se enciende con `ShotSplit.log_split` desde `debug/ai_match.gd`.
- `data/shots/emba.tres`: modelo `rock` (0,45, provisional), caja 0,7, `volley 3`, `range_factor 2`, `in_flight` `split_flight`, `burst_at_range_end` sin impacto (al agotar el alcance no daña), estela `rock_trail` y fx `rock` + `dirt`.
- `data/shots/rdra.tres`: caja 0,35, `sweep`, `burst_at_range_end` e impacto `heat_ray_impact.tscn` (el del Tickferno).
- `debug/f125_big_shots.tscn` con los carriles A y B (caso `f125` del banco, 0,3 min) y la réplica `agent/tools/f125_expect.py`.

**Resultado (developer de 030n-a, 2026-10-17):** semilla 7.
- **C1 Abanico (A):**
  - salen Shot1, Shot2 y Shot3 con índices −1, 0 y +1, apuntado 68,138 m;
  - aparece `abanico ±3,5° a los 8.138 m` en el tick 9 de vuelo, con ángulos visto desde arriba de +3,5000°, 0 y −3,5000°;
  - los tres terminan en el tick 68 sobre Druid2, Druid1 y Druid3, a ≤0,003 m de la réplica (`3 piedras, 0 con diferencias`);
  - cada Druid recibe `hurt 450.00 direct_ranged` en el mismo tick y no hay piedras que caigan al suelo.
- **C2 Phoenix (B):**
  - `fired` en rel 45 y primer cuadro de fuego en rel 91: 45 ticks para unos 45 m (d/60);
  - `fuego rdra a Druid: 800.0 en 60 cuadros, maná 50.00` y `fuego Druid4 total 732.0 en 61 actualizaciones`, con 12 por tick (`direct_ranged`, sin daño directo);
  - el drenaje es 50,83 (100 → 49,17). El log muestra `queda 82.50` porque B1 está a 47 m de `FountSouth` (radio 50): el manantial le da 33,33/s mientras arde, igual que en sacengine (`updateCreatureStats`, state.d:14409-14410; el `Fire` no bloquea la regeneración). Criterio C2 enmendado (review m1): se mide el drenaje (−50,83), no el maná final;
  - el Phoenix no muere (como pide el plan) y vuelve a disparar a los 4 s: el segundo fuego mata a Druid4.
- **C5 Determinismo:**
  - `f125` da c06a1501 en fixed, stress y window, y entra en `quick` y en `det_baseline.txt`;
  - `quick` PASS, con las 9 líneas base sin cambios (`volley 1` y `range_factor 1` son neutros);
  - `rules_suite` PASS.
- **Ventana** (`agent/flows/pt125_play.json`, `agent/harness/pt125_watch.gd`, capturas en `agent/out/pt125/`):
  - `a1`/`a2`: las tres piedras abiertas en abanico hacia los tres Druids (en rel 92 están a z 1222,50 / 1219,82 / 1217,13);
  - `a3`: el polvo de los tres impactos, con los Druids en 350;
  - `b1`/`b2`: Druid4 en llamas.

*Desvíos del plan:* ninguno de diseño. El giro sale espejado por los ejes: el índice −1 va hacia +z (A2). Es simétrico, y la réplica usa la misma convención.

*Divergencias declaradas:*
- Las del plan: el giro usa `Vector3.UP`, el Phoenix tira desde su altura de vuelo sin el tubo de 30 cuadros, y el giro y el polvo usan RNG propio.
- **El pasto tapa a los Druids** en la captura cercana (`a3`). En `a2` las piedras se ven chicas con la cámara alta.

**Plan (developer de 030n-b, 2026-10-17):** el del tech lead en `rfcs/plans/030m-030n-plan.md` §030n (Rhinok), sobre 030n-a. Números verificados en `state.d` 11880-11885, 4996-5025, 24933 y 24942-25037.
- `GroundHug` (`ground_hug_flight.gd/.tscn`, un `ShotInFlight`): en cada tick vuelve el disparo a `suelo + 0,05` antes de que `RangedShot` busque el choque. Las púas del camino son visuales (`rock_emerge` cada 4 ticks en un disco de 2,5 m, con `MatchSeed.rng(["spikes", disparo])`).
- `SpikeImpact` (`impacts/spike_impact.gd/.tscn`): el tocado recibe el monto entero como `splash_ranged` y los anillos salen bajo su centro. Si se agota el alcance, el pedido vivo recibe lo mismo y los anillos salen del punto final.
- `SpikeWave` (`impacts/spike_wave.gd/.tscn`, Node3D en el contenedor de disparos, prioridad −1):
  - el cuadro es `MatchClock.now()` menos el tick del golpe;
  - el anillo i daña en `damage_frames[i]` (14, 29, 44, 59, 89), de `1 + 5,75·i` a +6 m, con la distancia xy medida desde los pies;
  - cuenta criaturas, magos y edificios sobre tierra y a no más de 10 m del suelo;
  - saltea al tocado y a los aliados (mismo slot y no es el pedido) antes de Health;
  - el daño es una vez **por anillo**, como en sacengine: un cuerpo que cae donde dos franjas se pisan recibe los dos golpes;
  - termina en el cuadro 90.
- `data/shots/hrba.tres`: caja de 5 m, `in_flight` `ground_hug_flight`, impacto `spike_impact`, `burst_at_range_end` y fx `rock_emerge`.
- Los logs se encienden con `GroundHug.log_flight` y `SpikeWave.log_spikes` desde `debug/ai_match.gd`. La réplica es `agent/tools/f151_expect.py` (distancia → anillo → cuadro).
- Carril C en `debug/f125_big_shots` (después de B):
  - Rhinok (−60/+45) contra C0 (−32);
  - C1 a C5 en −28, −22, −17, −11 y −5;
  - C6, aliado del slot 1, en −32/+53;
  - el Rhinok muere a los 4 s.

**Resultado (developer de 030n-b, 2026-10-17):** semilla 7, caso `f125`.
- **C3 Vuelo:** Shot5 vuela 21 ticks con |y − (suelo + 0,05)| = 0,000 y choca con Druid5 (C0) en el cuadro 118: `dano Druid5 450`.
- **C4 Anillos:**
  - Druid6 (4 m) recibe 450 en 132 (+14), Druid7 (10 m) en 147 (+29), Druid8 (15 m) en 162 (+44), Druid9 (21 m) en 177 (+59) y Druid10 (27 m) en 207 (+89), una vez cada uno;
  - Druid11 (C6, 8 m) y Rhinok1 (28 m) aparecen como `aliado, sin daño`;
  - también reciben 500 `Bld069_jhut` (14,59 m, +44) y los dos `Bld041/043_jcc2` (26,18 m, +89);
  - `fin +90` en el cuadro 208;
  - `f151_expect.py` da `RESULTADO PASS (0 diferencias)` en fixed, stress y window.
- **030n-a sin cambios:** `f125_expect.py` da `3 piedras, 0 con diferencias`, y el fuego del Phoenix sigue en 732,0 / 61.
- **C5 Determinismo:**
  - `f125` da f8709101 en los 3 modos y se regrabó en `det_baseline.txt`;
  - `quick` PASS, con las otras 9 líneas base sin cambios;
  - `rules_suite` PASS. El `sim_rng_lint` obligó a sembrar las púas visuales con `MatchSeed.rng`.
- **Ventana** (`agent/flows/pt151_play.json`, `agent/harness/pt151_watch.gd`, `run_pt151.sh`, capturas en `agent/out/pt151/play/`):
  - `c1`: las púas del camino detrás del Rhinok, con el disparo en rel 106 en (1228,63, 10,14, 1315,45);
  - `c2`: el golpe en C0 (Druid5 en 350);
  - `c3`/`c4`: las púas de los anillos y C1 y C3 en 350, con los anillos 1 y 3;
  - `c6`: el report da Druid11 en 800 en rel 212;
  - nadie queda dentro de rocas ni de chozas (`c4` los muestra en el pasto abierto);
  - en la ventana el Rhinok dispara en rel 92; headless, en el cuadro 97. Los daños caen en los mismos desfases que da la réplica.

*Desvíos del plan:* C6 va en +53 en vez de +55, para quedar a 8,6 m de JAW2 y no a 6,8. El Rhinok muere a los 4 s en vez de 5 s: el ciclo de disparo es de unos 285 ticks y así nunca dispara dos veces. Los dos desvíos los aceptó el orquestador.

*Divergencias declaradas:*
- Las del plan: vuela a +0,05 m, al agotar el alcance revienta en el mismo tick (±1), el aliado se decide por slot y las púas son el visual `rock_emerge`.
- La altura del vuelo es la de la tierra, sin los techos de los edificios que sí cuenta `getHeight`.
- Si `RangedShot` revienta sin cuerpo por el chequeo del suelo, `SpikeImpact` lo toma como alcance agotado.
- **El pasto tapa a C6** en la captura cercana: su vida sale del report del watcher.

**Corrección (developer de 030n-b, ronda única, `reviews/REVIEW-RFC-030n-b.md`):**
- **B1, la altura tiene un solo dueño:**
  - `ShotInFlight.holds_height()` vale false por defecto, y `GroundHug` lo pone en true. Con eso `RangedShot` saltea su chequeo de suelo y el disparo solo termina por choque o por alcance.
  - `GroundHug` toma la altura de `RangedShot.ground_height()`, que pasó a ser pública. Es el rayo con máscara 1 que cuenta techos de estructuras, altares y manantiales, igual que `getHeight`.
  - `SpikeImpact` solo le hace daño al blanco pedido si `RangedShot.range_spent()`.
- **m1, carril D:**
  - Rhinok2 en +225/+180 contra Druid12 (D1) en +262, con el manantial jfnt (1520, 1450) en el medio, y Druid13 (D2) a 4 m.
  - Shot6 sube a 19,10 m sobre el manantial en los ticks 13 a 19, baja al suelo (16,0 m) y choca con D1 en el cuadro 168 (450). D2 recibe 450 en +14.
  - Antes de la corrección habría reventado en el tick 13 y Druid12 habría recibido 500 desde 16 m.
  - La rama de alcance agotado con el blanco vivo no se da en la IA del banco (siempre se tira dentro del alcance). Queda cubierta por `range_spent()`.
- **Visual:**
  - Las púas son las de `Spike`/`SacSpike` (state.d:3875-3885, sacobject.d:2984-2994, renderer.d:2627-2638):
    - malla de `makeSpikeMesh` (radio 0,3 m en el suelo y 0,25 m a 0,75; punta en 1);
    - textura `jspk`, sacada de `shwn.WAD` con `tools/export_particles.py`, en MIX;
    - eje s·d con d = (0, 2,5, 0) + disco de 2 m × U(0,85, 1,15) y s = 1 − (2t/L − 1)².
  - Lo dibuja `scenes/fx/spike_field.tscn` (MultiMesh). Cada evento es un solo `FxBus.broadcast_scene`, que es nuevo: un RPC con parámetros.
  - Cada anillo es un evento con 1 púa/m² en su franja (hasta 1000; sacengine mantiene unas 1200 en pie). En vuelo, un evento cada 6 ticks con 18 púas.
  - Pasa de unos 70 RPC a 10 por disparo (m5). La semilla sale de `MatchSeed.derive([…, tick])` (m6).
- **Medición** (`agent/tools/f151_bands.py`, muestras de `pt151_watch.samples`, cámara cenital a 62 m, oscuro con luminancia < 0,4, después − antes):

| Captura | Franja | Interior | Exterior |
|---|---|---|---|
| Anillo 2 (`p3_ring2_overhead.png`) | +0,0363 | −0,0182 | −0,0039 |
| Anillo 3 (`p3_ring3_overhead.png`) | +0,0233 | −0,0109 | −0,0011 |

  Los dos dan PASS. Con el umbral 0,5 la línea base en pausa sale más oscura y el resultado no sirve. En `p3_ring5_side.png` se ve de costado el muro de púas del anillo 5.
- **m3 declarado:** el blanco pedido recibe el daño por Health. Un pedido aliado queda en 0 o en `ally_damage_factor` según el fuego amigo.
- **Divergencia nueva:** las púas de cada anillo duran 0,4 s, no 2/3 s, para que haya un solo anillo en pie por vez. En sacengine nacen sin parar sobre el círculo que crece.
- **Pruebas:**
  - `f125` da 04bb9085 en los 3 modos y se regrabó;
  - `f151_expect` y `f125_expect` dan PASS en los 3;
  - `quick` y `rules_suite` dan PASS.

### 030o — F126 Catálogo de habilidades + Protector y Firewalk

**Árbol**
```text
scenes/world/units/ability_effect.gd       N  class_name AbilityEffect (Node): status(ctx) -> String, use(ctx)
scenes/data/ability_catalog.gd             N  class_name AbilityCatalog (Resource): effects {tag: PackedScene}
data/abilities/ability_catalog.tres        N
scenes/world/units/abilities/protector.tscn/.gd, firewalk.tscn/.gd  N
scenes/world/units/active_ability.gd       M  si el catálogo tiene la tag: instancia el efecto hijo y delega; si no, el match actual (sin crecerlo)
```
**Escena de prueba:** `res://debug/f124_abilities.tscn`: un Ent y un Warmonger seleccionados. El playtester pulsa Ctrl+Q / Shift+B (la acción de habilidad de F29).

**Criterios:** maná de la criatura y efecto medidos (log); ya no dice «No implementado».

#### 030o-a: Plan (developer) / Resultado

**Plan (developer de 030o-a, 2026-10-17):** el del tech lead en `rfcs/plans/030o-030p-plan.md` §030o-a. Números de `state.d` 13092-13100, 13196-13202, 25698-25713, 25122, 218-224 y 8962-8963.
- `AbilityCatalog` (`data/abilities/ability_catalog.tres`, `{"HSba": protector.tscn}`) dice qué tag tiene efecto propio. `ActiveAbility` lo instancia como hijo «Effect» y le delega `status()` (después del maná) y `fire()`; la regla y el efecto viven en `AbilityEffect`, y el enfriamiento y el gasto siguen en `ActiveAbility`.
- `LifeShield` (hijo de `unit.tscn`, `shown` replicado) es el único dueño del escudo: `start(ticks)`, `is_on()` derivado de `MatchClock`, `factor()` (×0,5), fin por tiempo o por muerte. Life Shield (`hsba`) y Protector (`HSba`) lo usan.
- `Health.shield_factor() = max(0, damage_factor) · life_shield.factor()`: lo usan `damage_typed` (salvo `pierce_shield`) y el golpe cuerpo a cuerpo (`melee_attack.gd`).
- Se borraron de `ActiveAbility` `SHIELD_FACTOR`, `shield_alpha`, `_life_shield_left`, `_apply_life_shield` y `_reset_shield` (neto −5 líneas).
- Logs apagados por defecto: `AbilityEffect.log_effects` y `LifeShield.log_shields`, encendidos en `debug/ai_match.gd`.

**Resultado (developer de 030o-a, 2026-10-17):** semilla 7, caso `f126` (carril A, 0,36 min).
- `agent/tools/f126_expect.py` da `RESULTADO PASS` en fixed, stress y window:
  - T = tick 5: `habilidad Protector mana 500->200` y `escudo Ent1 1200 ticks`;
  - T+1: `protector Ent1: Druid1 10,0 m sí; Druid2 27,5 m ya tenía; Druid3 35,0 m fuera`, y Druid4 (enemigo) no aparece;
  - Life Shield migrado: `habilidad Life Shield mana 100->50` y `escudo Druid2 1200 ticks`;
  - **A1 800,0 → 530,0** en el tick 16 (sin escudo habría quedado en 260);
  - los escudos terminan en 1205 (Ent1, Druid2) y 1206 (Druid1).
- **Determinismo:** `f126` da 446809b6 en los 3 modos y se grabó en `det_baseline.txt` y en `quick`. `quick` PASS (las 10 líneas anteriores sin cambios; `shield_factor` es neutro sin escudo). `rules_suite` PASS.
- **Ventana** (`agent/flows/pt126_play.json`, `agent/harness/pt126_watch.gd`, `run_pt126.sh`, capturas en `agent/out/pt126/play/`): `p2_ent_bubble` (burbuja del Ent), `p2_a1_bubble` y `p1_ray_b` (A1 escudado con el rayo del Gnome saliendo; el report da A1 en 530,0), `p3_a2_bubble_a3_none` (A2 con burbuja y A3 sin ella) y `p3_a4_enemy_none` (A4 sin burbuja). RSS máximo 619 MB.

*Desvíos del plan:* ninguno. `wizard_body` no necesitó `life_shield` (`Health` lo trata como opcional).

*Divergencias declaradas:*
- El escudo termina por tiempo o por muerte; los modos sin `canShield` quedan fuera, y no existe `shieldBlocked`.
- La burbuja es un placeholder (MIX, alfa 0,22): en el pasto, la de un Druid (0,6 m) se ve tenue desde la cámara del banco; la del Ent se ve bien.
- El look del Life Shield del Druid cambia: antes era transparencia del cuerpo con varios escritores.

#### 030o-b: Plan (developer) / Resultado

**Plan (developer de 030o-b, 2026-10-17):** el del tech lead en `rfcs/plans/030o-030p-plan.md` §030o-b. Números de `state.d` 13470-13493, 12631-12758 (el maná se cobra aunque `firewalk` falle: 12746-12748), 13213-13217, 25802-25846 y modo firewalk (124, 135, 141, 193, 8922).
- `ActiveAbility`: con `windup() > 0` (Firewalk, 150 ticks de `shoot_animations[1]`), `use()` enciende `UsingAbility` (hijo de `Afflictions`, bit 4, `holds`) y no gasta. En `now + windup` dispara el efecto, cobra el maná siempre y pone el enfriamiento si estaba en 0; si `UsingAbility` ya no estaba (aturdimiento, petrificado, congelado, tumbling lo cancelan por `cancels`) loguea `preparación cortada` y no gasta.
- Tiempo en ticks (`MatchClock`): el enfriamiento, Stealth y Play Dead pasan de restar `delta` a «hasta el tick N».
- `Firewalking` (Affliction, bit 5, `holds`, `hides`, `cancels using_ability`): `walk(end)`, `steer()` escribe la posición de cada cuadro, `WarpSnap.announce()` en el salto, oculta `Tilt`, estela `fire` (MIX).
- `AfflictionType.hides` → `Afflictions.hides()`; `is_obstacle` e `is_targetable` suman `and not _afflictions.hides()` (neto 0 líneas, `unit_body.gd` queda en 1040).
- `BenchEvent.action "ability"` (`user`, `target`, `point`) y `"stun"` (solo para el caso de la preparación cortada); `ai_match` enciende `Firewalking.log_walk`. Catálogo: `"wfhg": firewalk.tscn`.

**Resultado (developer de 030o-b, 2026-10-17):** semilla 7, caso `f126` (carriles A y B, 0,36 min).
- `agent/tools/f152_expect.py` da `RESULTADO PASS` y `f126_expect.py` (carril A) sigue en PASS:
  - `usando habilidad Firewalk Warmonger1 150 ticks`; el camino empieza 150 ticks después; `habilidad Firewalk mana 500->250 enfriamiento 600 ticks`;
  - W1: cuadro 30 a 10,00 m del origen, cuadro 31 a 9,67 m del destino (salto 40,36 m), cuadro 60 en (1280, 1290); a mitad de la caminata `is_targetable` e `is_obstacle` en false; la malla vuelve a verse al terminar;
  - W2: 0,250 m por tick, termina en (1250, 1278);
  - W3 (160 m): «Fuera de alcance», sin preparación ni gasto.
- **Preparación cortada:** `debug/rules/f152_cut.tres` (Warmonger usa Firewalk a 0,5 s y lo aturden a 1,5 s): `preparación cortada Firewalk Warmonger1`, sin camino y sin gasto de maná.
- **Determinismo:** `f126` pasa a 45d8baca en fixed, stress y window y se regrabó en `det_baseline.txt` (cambia por el carril B). `quick`: las otras 10 líneas base iguales, así que la migración a ticks no movió ningún digest. `rules_suite` PASS.
- **Ventana** (`agent/flows/pt152_play.json`, `agent/harness/pt152_watch.gd`, `run_pt152.sh`, capturas en `agent/out/pt152/play/`): `p1_preparing` (W1 quieto preparándose), `p2_walking_a` (sin malla, solo la estela de fuego) y `p5_appeared` (W1 en el destino con la malla de vuelta).

*Desvíos del plan:* la orden de banco la ejecuta `BenchEvents` (que ya despacha los eventos), no `ai_match.gd`; `ai_match` solo enciende el log. `bench_event.action "stun"` es un agregado para probar el corte.

*Divergencias declaradas:* las del plan (fuera de alcance rechaza en vez de acercarse, no gira hacia el blanco, usa siempre shoot1, la barra de vida queda visible, la cápsula sigue en la capa de unidades, sin `catapult` final). La estela de fuego es chica a la distancia de la cámara del banco.

### 030p — F127 Halo of Earth y Breath of life
- **Árbol:** N `abilities/halo_of_earth.tscn/.gd`, `abilities/breath_of_life.tscn/.gd`; M `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f125_abilities.tscn`. **Criterio:** efecto medido.

#### 030p-a: Plan (developer) / Resultado

**Plan (developer de 030p-a, 2026-10-17):** el del tech lead en `rfcs/plans/030o-030p-plan.md` §030p-a. Números de `state.d` 13232-13236, 19284-19321, 19212-19270, 19076-19100, 19272-19282, 202-209, 28825 y util.d 554-560.
- `HaloOfEarthAbility` (`AbilityEffect` sin preparación) pone un coordinador `HaloOfEarth` en el contenedor de disparos; el coordinador (prioridad −1, solo en el servidor) simula las 6 rocas y las mueve; cada roca es un `RangedShot` con `ShotLook halo_rock` (no colisiona, solo se dibuja y se replica). Catálogo: `"HRba": halo_of_earth_ability.tscn` (la clave es el tag; ningún archivo se llama como el tag).
- `ShotSpawner` pasa a tener `class_name` y `spawn_shot` devuelve el `RangedShot` (null en un cliente); `ranged_shot.gd` expone `touching()`. Los dos `WORKAROUND:` del coordinador se tiparon y se borraron.
- `ai_match` enciende `HaloOfEarth.log_halo`. `rock_dust.tres` pasa a `pool_max 128` (6 rocas × 30 estelas/s × 0,517 s × 1,25).

**Resultado (developer de 030p-a, 2026-10-17):** semilla 7, caso `f127` (carril C, 0,15 min).
- `f127_expect.py` da `RESULTADO PASS` en fixed, stress y window: maná 750→100, enfriamiento 2400, 6 rocas en T+1 dentro de la caja ×1,25, roca 0 → Druid1 y roca 1 → Trogg2, persecución ±1 tick, Druid1 recibe 600 y 211 (muere; el 211 es la vida que le quedó tras regenerar 11 en 52 ticks), Trogg2 4 golpes de 0, nunca Trogg1 ni Druid2, fin en el tick 248 (< T+600). La réplica no modela la regeneración, así que el golpe que mata admite hasta 60 más.
- **Determinismo:** `f127` da `d165115b` en fixed, stress y window y se grabó en `det_baseline.txt`. `quick`: las otras 11 líneas base iguales. `rules_suite` PASS.
- **Ventana** (`agent/flows/pt127_play.json`, `agent/harness/pt127_watch.gd`, `run_pt127.sh`, capturas en `agent/out/pt127/play/`): `p1_rise` (las 6 rocas, luminancia 20 a 36 contra 120 a 170 de fondo), `p2_orbit` (4 rocas orbitando sobre el Rhinok), `p5_impact` (la explosión de tierra sobre Druid1).
- **Pendiente visual:** las dos rocas que persiguen vuelan a ras del suelo y la hierba de nieve las tapa en `p3_chase` y `p4_close` (luminancia 158 a 185 contra 174 a 190): en esas capturas no se distinguen del fondo.

*Divergencias declaradas:* las del coordinador (línea de visión por rayo al centro, aliado = mismo slot, RNG de MatchSeed, estela de polvo siempre, sin sacudida ni sonido, edificios sin `Health` no frenan una roca).

#### 030p-b: Plan (developer) / Resultado

**Plan (developer de 030p-b, 2026-10-17):** el del tech lead en `rfcs/plans/030o-030p-plan.md` §030p-b. Números de `state.d` 13238-13248, 13470-13493, 25943-25975, 8651-8664, 14101-14131 y 29582-29604.
- `BreathOfLifeAbility` (`AbilityEffect` con preparación de 52 ticks, de `shoot_animations[1]`) juzga el blanco (alma → cadáver, muerto, mismo slot, alma NORMAL o EMERGING, ≤ 40 m en 3D) y pone un `BreathOfLife` en el contenedor de disparos. El coordinador (prioridad −1, solo en el servidor) mueve un `RangedShot` (`ShotLook breath_of_life`) con `v = 60·(blanco − pos)`, tope 60; al llegar agrega `FastRevive` al cuerpo.
- `FastRevive` usa `Captive.revive(0, 1)` y deja el alma en REVIVING; durante 150 ticks sube 2 m/75 por tick (1,97 m) y gira 2π; al final borra el alma y llama a `Captive.finish_revive()` (nuevo: REVIVING → IDLE, velocidad cero; `taken_changed(false)` devuelve la capa y el grupo `unit`).
- `AbilityEffect.windup()` pasa a ser el único dueño de la búsqueda del clip (`windup_from_clip`, apagado por defecto: Protector y Halo no preparan). Firewalk y Breath lo encienden en su escena y ya no lo duplican.
- `match_command._ability_at`: cuerpo vivo, y si la habilidad tiene `targetSouls | targetCorpses`, alma (`_soul_under`) y después cadáver (`_corpse_under`, máscara 8), y por último el suelo. Catálogo: `"filb": breath_of_life_ability.tscn`.
- Los dos `WORKAROUND:` (`spawn_shot` y `finish_revive` llamados por nombre) se tiparon y se borraron. `ai_match` enciende `BreathOfLife.log_breath` y `FastRevive.log_revive`.

**Resultado (developer de 030p-b, 2026-10-17):** semilla 7, caso `f153` (carril D, 0,15 min).
- `f153_expect.py` da `RESULTADO PASS` en fixed, stress y window: «Blanco inválido» (D3) en el tick 84 y «Fuera de alcance» (D2) en el 90 sin gasto; preparación de 52 ticks, maná 750→700 y enfriamiento 240; el aliento sale en el 152 y llega en el 172 (d 19,0004 m; la réplica da 173, dentro de ±1); D1 vuelve a 800/800 en el tick de la llegada, sube 1,9733 m a los 74 ticks y queda IDLE en el 322 con 800 de vida.
- **Determinismo:** `f153` da `130a619b` en fixed, stress y window y se grabó en `det_baseline.txt`. `quick`: las otras 12 líneas base iguales (`f126` con Firewalk incluido, tras mover `windup()` a la base). `rules_suite` PASS.
- **Ventana** (`debug/f153_breath.tscn`, `agent/flows/pt153_play.json`, `agent/harness/pt153_watch.gd`, `run_pt153.sh`, capturas en `agent/out/pt153/play/`): cubre hasta rel 392 (220 después de la llegada). `p1`/`p2` el aliento dorado en vuelo, `p4_rising` y `p5_turning_top` D1 levantándose (y 10,29 y 11,17) y girando, `p6_standing`/`p7_end` D1 de pie, grupo `unit`, capa de unidades, sin alma. El `report()` imprime modo, grupo, capa y almas.
- **Sin probar en ventana:** el clic real sobre un alma o un cadáver (`_ability_at`); el banco ordena la habilidad por `BenchEvents`.

*Divergencias declaradas:* las del plan (no se acerca ni gira hacia el blanco, aliado por slot, aliento y partículas placeholder, sin `botRevive`), y el cuerpo vuelve al suelo por gravedad, no se vuelve a agregar a la selección y no usa el clip de revivir.

### 030q — F128 Web pull y Cage pull
- **Árbol:** N `abilities/pull.tscn/.gd` (una escena; `.tres` o `@export` distinto por tag, `state.d:13538`); M `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f126_pull.tscn`. **Criterio:** el blanco se acerca X m.

#### 030q-a: Plan (developer) / Resultado

**Plan (developer de 030q-a, 2026-10-17):** el del tech lead en `rfcs/plans/030q-030s-plan.md` §030q-a. Números de `state.d` 10108-10113, 13166-13175, 12592-12605, 12738-12739 y 25434-25519.
- `Pull` (`AbilityEffect`, `abilities/pull.gd`, escenas `web_pull.tscn` y `cage_pull.tscn`) juzga el blanco (no aliado, sin Life Shield, ≤ 50 m), prepara 54 ticks (carga en el cuadro 27) y en `fire` arranca el `Pulling` del usuario. `AbilityEffect.starts_cooldown` es un knob nuevo de la base y `ActiveAbility._spend` lo respeta (la Web y la Cage lo apagan).
- `Pulling` (`Affliction`, `pulling.tres`, bit 6, `holds`, `cancels [using_ability]`; nodo `Afflictions/Pulling` en `unit.tscn`) es el único dueño de la simulación: hilo, tirones, ventana de 25 ticks, tirón extra y fin (`_finish()` único). Usa `Stunned.stun_with_cooldown(480)`, `Tumbling.catapult` y el nuevo `Tumbling.drive(v)` (sin `WORKAROUND:`), o `BodyNudge.push` en el suelo. Prioridad −1. `stunned`, `petrified`, `frozen` y `tumbling` agregan `&"pulling"` a `cancels`.
- Hilo (`pull_thread.gd/.tscn`): `FxBus.broadcast_scene` una vez, en MIX (alfa, nunca aditivo). Catálogo: `"psla"` → `web_pull.tscn`, `"psaa"` → `cage_pull.tscn`. `ai_match` enciende `Pulling.log_pull`. Caso `f128` (0,3 min) en `run_determinism.sh`.

**Resultado (developer de 030q-a, 2026-10-17):** semilla 7, caso `f128` (carril Q, 0,3 min).
- `f128_expect.py` da `RESULTADO PASS` en fixed, stress y window: rechazos «Blanco inválido» (ticks 18 y 21) y «Fuera de alcance» (24) sin gasto; preparación de 54 ticks, maná 300→240, sin enfriamiento; tirones en T+162/326/490, solo el primero aturde; velocidad horizontal 16,50 y 0,275 m por tick en las ventanas; termina por «cerca» en la 3.ª ventana (tick 541).
- **Determinismo:** `f128` da `8b230572` en fixed, stress y window y se grabó en `det_baseline.txt`. `quick`: las otras 13 líneas base iguales. `rules_suite` PASS con `--fixed-fps 60`.
- **Desvío del carril:** el Druid1 pasó de 20 m a 31 m del Gremlin (x −9). Con 20 m el Tumbling del blanco vuela unos 11,7 m por ciclo (la ventana de 6,6 m más el vuelo libre con el amortiguamiento 0,99) y la distancia cierra en la 2.ª ventana; la estimación del plan («6,4 m por ventana») no contaba el vuelo libre. La regla de cierre es la de sacengine y el log la verifica tick a tick. El chequeo de suelo del carril Q pasó de «plano» a «pendiente ≤ 0,1 m por m».
- **Ventana** (`agent/flows/pt128_play.json`, `agent/harness/pt128_watch.gd`, `run_pt128.sh`, capturas en `agent/out/pt128/play/`): `p1_web_thread` (cuerda marrón oscura entre Gremlin y Druid, luminancia 33 a 84 contra 184 de fondo), `p3_web_druid_air`, `p5_web_end`. El primer hilo era crema (0,93, 0,9, 0,78) y no se distinguía de la nieve (luminancia ~185 en todo el cuadro): pasó a (0,32, 0,2, 0,08) con ancho 0,1.
- **Pendiente visual:** el Druid en el aire se ve muy chico y el pasto lo tapa; los residuos `rock_dust` del fin casi no se ven.

*Divergencias declaradas:* las de `pulling.gd` (un edificio o un alma en el camino no cambia el blanco, el usuario no se acerca ni gira, sin telaraña ni jaula alrededor del blanco, sin clip de disparo mientras tira); hilo de color liso (`WORKAROUND:` en `pull_thread.gd`: faltan las texturas `cord` y `ltng` del exportador).

#### 030q-b: Plan (developer) / Resultado

**Plan (developer de 030q-b, 2026-10-17):** el del tech lead en `rfcs/plans/030q-030s-plan.md` §030q-b. Es el mismo `Pull` y el mismo `Pulling`: cambian la escena (`cage_pull.tscn`, SPs1 de 102 cuadros: vuelta de 204 ticks, tirones en T+202+204k), el hilo (`cage_thread.tscn`: rayo de 10 tramos, dispersión 2,5 m, cambia de forma cada 6 ticks, crece en 0,5 s) y las chispas del final (`styx_spark`).

**Resultado (developer de 030q-b, 2026-10-17):** semilla 7, caso `f128` (carril C, el mismo caso y los mismos baselines).
- `f154_expect.py` da `RESULTADO PASS` en fixed, stress y window: 4 tirones en los ticks 236, 440, 644 y 848 (T+202+204k), solo el primero aturde, fin por «4 tirones» en el tick 849 (T+815) con la caja a 10,77 m; Druid5 sigue en el aire y aterriza en el 866 en (1093,48, 1509,99), igual que la réplica. La réplica ahora cuenta que el `Pulling` pisa la velocidad con el empuje (sin elevación) un tick después del 4.º tirón, antes de terminar.
- **Desvío del carril:** el carril C se mudó a suelo plano en (1100, 1510) (Seraph1 en x −170 / z +240, Druid5 en x −212, 42 m). En el carril de z −50 el suelo sube 4 cm por m y el blanco planeaba 26 m en el primer ciclo, así que la distancia cerraba antes del 4.º tirón con cualquier distancia inicial probada (30, 36, 42 m).
- **Ventana** (misma corrida): `p2_cage_thread` (rayo azul (0,1, 0,3, 0,95) con quiebres, luminancia 36 a 129 contra 174 de fondo), `p4_cage_druid_air`, `p6_cage_end` (chispas azules en el blanco). El primer hilo era celeste claro y no se distinguía de la nieve.

#### 030r-a: Plan (developer) / Resultado

**Plan (developer de 030r-a, 2026-10-17):** el del tech lead en `rfcs/plans/030q-030s-plan.md` §030r-a. Números de `state.d` 13179-13187, 13463-13493, 11491-11510, 25524-25578 y `stats.d` 122.
- `PaceFactors` (componente, `unit.tscn` y `wizard_body.tscn`) es el único dueño de `speed_factor = Π factores` (por nombre de fuente, solo escribe si cambia). `SpeedupEffect` le da su factor (`&"speedup"`); el doctor no lo tiene y sigue escribiendo directo.
- `Clinging` (componente, mismos dos cuerpos; sockets `body`, `poisoning`, `pace`; `Clinging:shown` replicado) lleva los vencimientos por tipo y le da a `PaceFactors` `0,75ⁿ`. Se suelta todo si el cuerpo ya no puede ser pegado.
- `LobAbility` (`AbilityEffect`, `sticky_bomb.tscn`, catálogo `"acia"`) prepara desde el clip y lanza 10 `RangedShot` con la puntería de `ShotAim.scatter` y `0,2·uniformDirection` (`MatchSeed.rng(["lob", usuario, tick])`); `StickImpact` (`ShotImpact`, `sticky_bomb_impact.tscn`, look `data/shots/acia.tres`) pega a una criatura enemiga que `can_be_poisoned` o desaparece en el suelo.
- `AbilityEffect.windup()` con `windup_from_clip` toma el último cuadro (`frames − 1`, 2 ticks por cuadro) si el clip no tiene `lrba` (Ikarus: 94). Firewalk sigue en 150, Breath en 52 y Web/Cage pull en 54. `FRAME_TICKS` pasó a la base (`Pull` lo hereda). `ShotAim.origin(cuerpo, fracción)` es el origen compartido de `RangedAttack.shot_origin()` y de `LobAbility`.
- Banco: acción `attack` en `bench_event.gd`/`bench_events.gd` (`Orders.apply_for`, con el knob `order`). `ai_match` enciende `Clinging.log_cling` y `PaceFactors.log_pace`. Caso `f129` (0,3 min, semilla 7) en `run_determinism.sh` (usage, `case_args`, `quick` fixed).

**Resultado (developer de 030r-a, 2026-10-17):** semilla 7, caso `f129` (carril S, 0,3 min).
- `f129_expect.py` da `RESULTADO PASS` en fixed, stress y window: preparación de 94 ticks, maná 300→240, enfriamiento de 360, las 10 bombas con su suelo o cuerpo a ±1 tick de la réplica, Druid2 (aliado) sin ninguna, `speed_factor` 0,75ⁿ, paso de crucero de Druid1 `11·0,75ⁿ/60` (±2 %) y la bomba se suelta a +601 con el factor otra vez en 1,0.
- **Determinismo:** `f129` da `7c69f9b0` en fixed, stress y window y se grabó en `det_baseline.txt`. `quick`: las otras 14 líneas base iguales (Speedup incluido). `rules_suite` PASS con `--fixed-fps 60`.
- **Desvíos del carril:** (1) la habilidad pasó de 0,5 s a 0,7 s: con la semilla 7 a los 0,5 s ninguna bomba le pegaba a Druid1 (1 de cada 10 pega: la dispersión de 0,2 sobre un vector unitario son ±5 m a 25 m) y no se podía medir el paso. (2) Druid1 es pacifista (`aggressiveness 0`) y `Orders` le rechaza «attack»: el evento usa `order = "move"` hacia el Ikarus (knob nuevo de `BenchEvent`). (3) La réplica mide el paso con el percentil 90 (la llegada al Ikarus y las pendientes solo lo frenan; la mediana mezclaba tramos).
- **Ventana** (`agent/flows/pt129_play.json`, `pt129_watch.gd`, `run_pt129.sh "pt129_play:--autostart,--seed=2"`; capturas en `agent/out/pt129/play/`): con Enter el tick de arranque de la ventana cambia 1 tick y con él el `rng` del volley (la bomba sobre Druid1 se perdía), así que la corrida usa `--autostart` y `--seed=2` (en ese tick el volley pega a Trogg1 y a Druid1). `p1_in_air` y `p2_in_air_late` (las bombas en vuelo, puntos ámbar chicos), `p3_stuck_close` (bomba ámbar sobre Druid1: 290 píxeles ámbar en 60×60), `p4_walking_slow` (a 4 m, 38 píxeles ámbar: el pasto la tapa) y `p6_released`. Druid1 a 13,1 m del Ikarus a los 300 ticks contra 9,5 m sin bomba. La esfera pasó de 0,12 a 0,18 m y de emisión 0,6 a 2,0, y las bombas suben (`min_height` 0,45) para que el pasto no las tape.
- **Pendiente visual:** las bombas en vuelo se ven muy chicas desde la cámara del carril y el pasto tapa la bomba pegada con la cámara a nivel; el look final de la bomba es un placeholder (esfera ámbar).

*Divergencias declaradas:* las bombas se dibujan en posiciones fijas del cuerpo; una criatura que no se puede pegar frena la bomba (en sacengine la atraviesa); sin sonido; la bomba sale del frente del cuerpo a `shot_height` y no de la mano de la animación.

#### 030r-b: Plan (developer) / Resultado

**Plan (developer de 030r-b, 2026-10-17):** el del tech lead en `rfcs/plans/030q-030s-plan.md` §030r-b. Números de `state.d` 8961, 9028-9031, 13189-13194, 13647-13649, 25580-25676 y los portadores de ignite 23041, 23051, 23247, 24521, 24528, 16670-16677 y 25218.
- `AfflictionType.coexists` y `Afflictions.admit` (se saltea en las dos direcciones, no cancela ni es cancelado). `Oiled` (bit 7, hijo de `Afflictions` en `unit.tscn` con el socket `orders` y en `wizard_body.tscn` sin él; `oiled.tres` retiene, `oiled_wizard.tres` no; ambos `coexists` y con look oscuro: `StoneLook` de `Afflictions` con tinte (0,3, 0,22, 0,12) y prioridad 0, debajo de piedra y hielo). `Health.oil` (socket): con `IGNITE` sobre un cuerpo untado el golpe pasa ×2 y `Oiled.ignite()` lo enciende; la explosión sale en el tick siguiente.
- Cadena de ignite: `ShotLook.ignites` y `hits_every_side` → `RangedShot.mods` → `ShotImpact.mods_of`/`land`, `DirectImpact`, `SplashImpact` → `SplashDamage.deal`/`hurt(…, mods)`. `fireball_projectile` y `steam_cloud` pasan `IGNITE`; Tickferno y Phoenix no. `fkba.tres` y `fhba.tres` (solo `ignites`), `ignites = true` en `cfba.tres` (Bombard).
- **`fhba` (Spitfire) no es un proyectil:** es el aliento-cono del Spitfire (state.d:23035-23055); se borró `fhba.tres` y queda para su propio corte (con Rain of Fire, Lava ball y Dragonfire, que tendrán que llevar `IGNITE`). `fkba` (Flame Minion) sí volaba como una bola sin look: ahora tiene su `.tres`.
- **Ronda de REVIEW-030r-b:** (B1) `Afflictions.held_changed` sale también cuando cambia `breaks_special_modes()` (un dueño, `unit_body.gd` intacto): una criatura en Rockform ya untada que se petrifica cierra Rockform; carril R de `f155`. (Look) el untado es un `StoneLook` con los knobs del shader por tipo (`look_base/gain/roughness/metallic`): negro y brillante. (Explosión) `Oiled.blast_fx` = `data/fx/oil_blast.tres` (`fire`, MIX, 150 partículas de 2,5 a 6 m, radio 2,5).
- **Declarado (m6):** `holds` del aceite es más fuerte que sacengine: bloquea también las habilidades y deja colgado en el aire al que está en vuelo (sacengine solo borra órdenes y no corre la IA).
- `OilImpact` (`kcfa.tres`, `hit_size 1,0`, `hits_every_side`), `ViscousOil` (`LobAbility`, un tiro, prepara 94 ticks), `data/fx/oil_splash.tres` en MIX (nunca aditivo, `pool_max 4`), catálogo `"kcfa"`. `ShotImpact.land` imprime la línea `dano` del golpe directo sin impacto (la que lee el banco). `rock_projectile.report` usa el nombre del nodo (`Druid1`) cuando `Oiled.log_oil` está encendido (solo el banco), para distinguir cuerpos del mismo tipo.
- Banco: `ai_match` enciende `Oiled.log_oil`; caso `f155` (0,4 min, semilla 7) en `run_determinism.sh` (usage, `case_args`, `quick` fixed) y en `det_baseline.txt`.

**Resultado (developer de 030r-b, 2026-10-17):** semilla 7, caso `f155` (carril O, reglas aparte).
- `f155_expect.py` da `RESULTADO PASS` en fixed, stress y window: maná 300→240 y enfriamiento 360; el aceite cae en el tick 172 y unta a O1, O2, O3 y O5 (no a O4, FM ni al Pyrodactyl); O5 quieto (0,0000 m); primer `fkba` sobre O1: `dano 288` (160·0,9·2); O1 arde en el 248 y explota en el 249 (450), O2 arde en el 249 y explota en el mismo tick, O3 (aliado) recibe 0 y no arde; fuego visual de 61 actualizaciones en todo el radio de 5 m; O3 se limpia a +901.
- **Determinismo:** `f155` da `91b01488` en los 3 modos y se grabó en `det_baseline.txt`. `quick`: las otras 16 líneas base iguales, `f123` incluido (`cfba` enciende, pero ahí no hay aceite). `rules_suite` PASS con `--fixed-fps 60`, `sim_rng_lint` incluido.
- **Desvío de la réplica:** el Flame Minion no es pacifista y, cuando mueren Druid1 y Druid2, escupe fuego a O5 (que sigue untado): a los 404 arde y explota en el 405, y su aceite se quita con la explosión (como `igniteOil`). `f155_expect.py` acepta ese fin para Trogg1 en los criterios 3 y 6 (quieto hasta que arde; limpio por «explotó» ≤ 1 tick después de arder). El criterio 6 de Druid3 sigue exacto (+901).
- **Ventana** (`agent/flows/pt155_play.json`, `agent/harness/pt155_watch.gd`, `run_pt155.sh "pt155_play"`; capturas en `agent/out/pt155/play/`, con Enter y cámara en picado cercana re-encuadrada; `rel` = ticks desde Enter): `p1_oil_falling` (la bola negra en el aire), `c1`/`c3` (O1 limpio contra untado: el tinte pasa de verde y amarillo a gris oscuro; croma 94 → 79; contra la nieve la luminancia casi no cambia, Michelson 0,335 → 0,350, porque el pasto tapa el cuerpo y el piso del shader de piedra es 0,3), `p2_oiled_group`, `p4_blast_chain` (fuego naranja sobre el aliado O3).
- **Pendiente visual:** el fuego visual de la explosión (`fire`, 60 ticks) es chico y el pasto lo tapa desde la cámara del carril; la explosión de 500 no tiene destello propio (solo el `oil_splash` del impacto del aceite); el look untado es el `StoneLook` con tinte, no un shader de aceite (brillo/negro mojado).

*Divergencias declaradas:* sin manchas en el suelo ni `igniteBuilding`; aceite y untado con looks de reserva; el aceite no retiene al mago (otro `.tres`); el orden de explosiones encadenadas es el del árbol de la escena y no el de creación de los `Oil` (un encadenado puede explotar en el mismo tick o en el siguiente; el primero, exacto al tick siguiente).

#### 030s-a: Plan (developer) / Resultado

**Plan (developer de 030s-a, 2026-10-17):** el del tech lead en `rfcs/plans/030q-030s-plan.md` §030s-a. Números de `state.d` 13121-13136, 10474-10491, 16366-16386, 9017-9022, 9237, 25342-25386 y `stats.d` 122.
- `LightningStrike` (`abilities/lightning_strike.gd/.tscn`; coordinador en el contenedor de disparos, solo servidor; `launch` e `is_valid_target` estáticos) es el único dueño de «un rayo vuela y daña»: rebota en el primer cuerpo del camino (`retarget`), a los 12 ticks hace el daño directo con `Health.LIGHTNING` y el look es `FxBus.broadcast_beam("lightning")`. **Nombre:** la fase 0 lo llamó `LightningBolt`, pero `scenes/fx/lightning_bolt.gd` ya es el `class_name LightningBolt` (la forma del rayo del `BeamFx`); chocaba y rompía `fx_bus`/`pull_thread`.
- `CallLightning` (`AbilityEffect`, catálogo `"gsba"`): sin preparación ni enfriamiento, `MatchSeed.rng(["call_lightning", usuario, tick])`.
- `LightningCharge` (hijo de `unit.tscn`; sockets `body` y `pace`; `LightningCharge:shown` replicado, índice 17 tras `Clinging:shown`): dueño de los cuadros, la rampa y las descargas; `PaceFactors` `&"lightning_charge"` ×1,5; chispas con un RNG de presentación sembrado por `MatchSeed.seed_rng`. `DamagePassive.charge` solo lo consulta (`incoming_factor`, `outgoing_melee_factor`, `melee_accuracy_factor`); `Health.damage_typed(..., mods)` y `Health.LIGHTNING/IGNITE`; `Caster._strike_lightning` pasa `LIGHTNING`.
- `MeleeAttack.roll_damage` multiplica la precisión por el factor de la carga; `MeleeAttack.log_melee` escribe la línea `golpe …` (apagada en el producto). Banco: `ai_match` enciende `LightningStrike.log_bolt`, `LightningCharge.log_charge` y `log_melee`; caso `f130` (0,4 min, semilla 7) en `run_determinism.sh` (usage, `case_args`, `quick` fixed).

**Resultado (developer de 030s-a, 2026-10-17):** semilla 7, caso `f130` (carriles L y K, `friendly_fire` y `ally_damage_factor 0,5`).
- `f130_expect.py` da `RESULTADO PASS` en fixed, stress y window: maná 200→150 sin enfriamiento; en T+12 93,75 de daño y +1500; paso cargado 0,225 contra 0,150; precisión 2250 (×1,5) contra 1500; 4 descargas a ≤ 30 m o al suelo, a +12, cada una descuenta 125; fin en T+12+1500−125·k.
- **Determinismo:** `f130` da `84715e1b` en los 3 modos y se grabó en `det_baseline.txt`. `quick`: las otras 15 líneas base iguales. `rules_suite` PASS con `--fixed-fps 60`.
- **Ajuste del log:** la línea `golpe` imprime facing, pendiente, p y tirada con 6 decimales; con 4 la réplica no cerraba a ±0,01 porque `(1−tirada)/(1−p)` amplifica el redondeo.
- **Ventana** (`agent/flows/pt130_play.json`, `agent/harness/pt130_watch.gd`, `run_pt130.sh "pt130_play"`; capturas en `agent/out/pt130/play/`, con Enter y cámara cercana re-encuadrada): `p1`/`p2` el rayo cae sobre el Storm Giant (pico de luminancia +93 sobre el fondo a lo largo del haz, mínimo +48), `p3` el gigante cargado con chispas azules (1796 píxeles con azul−rojo > 60 en la zona, fondo 1), `p4`/`p5` descarga hacia el suelo (253 contra 184 de fondo). El rayo es blanco-azulado fino sobre la nieve: se distingue, pero con poco color.
- **Pendiente visual:** el beam `lightning` es aditivo y sobre nieve queda blanco sobre blanco (se lee por el halo y el brillo); `styx_spark` tiene `count 192` y `pool_max 8`: con la carga (2 por segundo) no se ve saturado, pero el golpe de varios rayos juntos no se probó.

*Divergencias declaradas:* los edificios no frenan el rayo; el nodo del rayo se libera al pegar (no guarda sus 64 cuadros: el look tiene los suyos); sin cicatriz ni sonido; los candidatos de una descarga van en orden de grupos y no de cercanía; un cuerpo que muere pierde la carga al instante.

### 030r — F129 Sticky bomb y Viscous oil
- **Árbol:** N `abilities/lob_ability.tscn/.gd` (proyectil de habilidad); M `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f127_lobs.tscn`. **Criterio:** daño o efecto en el blanco.

### 030s — F130 Bilemites, Call lightning y carga de rayo (`gcil`)
- **Árbol:** N `abilities/bilemites.tscn/.gd`, `abilities/call_lightning.tscn/.gd`, `data/passives/gcil.tres`; M `DamagePassive` (carga), `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f128_lightning.tscn`. **Criterio:** daño de rayo ×0,25 y golpe ×1,5 con la carga activa.

### 030t — F131 Devour y Rend Soul
- **Árbol:** N `abilities/devour.tscn/.gd`, `abilities/rend_soul.tscn/.gd`; M `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f129_devour.tscn`. **Criterio:** el blanco desaparece o cura al usuario según el original; almas medidas.

### 030u — F132 Quake y golpes que congelan o enredan (Yeti `zerf`, Dragon `eniv`)
- **Árbol:** N `abilities/quake.tscn/.gd`, `scenes/world/units/melee_on_hit.gd` (pasiva al golpear, `state.d:14423-14436`); M `melee_attack.gd` (llama al hijo), `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f130_quake.tscn`. **Criterio:** efecto medido.

### 030v — F133 (opcional) Migrar las 6 habilidades viejas al catálogo
- **Árbol:** N 6 escenas en `abilities/`; M `active_ability.gd` (quita el `match` y la lista de `:103`).
- **Escena de prueba:** `ability_spit.tscn` (la de F29).
- **Criterio:** `f29_spit`, `final_spit_melee` y los flows de Run Away, Play Dead, Stealth, Life Shield y Divine Sight pasan iguales.

## 6. Qué es Resource, qué es nodo, qué es `@export`

- **Resource de tipo:**
  - `CreatureType` / `AbilityType` (de la caché, sin cambios).
  - `ShotLook` (`data/shots/<tag>.tres`) con el `impact` como `PackedScene`.
  - `DamagePassiveType` (`data/passives/<tag>.tres`) y `AbilityCatalog`.
  - `MatchRules.wizard_level` / `wizard_level_stats` como reglas de ronda.
- **Nodo:**
  - El nivel vivo del mago (`wizard_body.level`, replicado) y el `Spellbook` que filtra.
  - `Flight`, `DamagePassive`, `Stun`/`Poisoned`/`Frozen`, cada `AbilityEffect` y cada `ShotImpact`: un comportamiento por nodo.
- **`@export` de instancia:** los sockets entre `Health` / `MeleeAttack` y `DamagePassive`; los knobs de `Flight` (altura, velocidad vertical); `max_level` de la galería.
- **Nunca** se muta un `.tres`. El estado vivo (cargas, congelado, vuelo) está en el nodo.

## 7. Determinismo y regresión mínima

- **Digest:** `ai_match` con `ai_duel_seeded.tres` (seed 7, 2 min) da el **mismo digest** después de cada corte, porque `wizard_level` vale 1 por defecto en el script. Se corre al cerrar 030a, 030b, 030c, 030e y 030f.
- **IA en producto:** la IA de producto usa las nuevas desde 030c, con nivel 9 y maná 1900. **Declarado:** cambia qué convoca la IA en una partida real. Las escenas `ai_*` tienen `.tres` propio de nivel 1 y no cambian.
- **Pasivas en NPC:** 030f cambia el registro de las escenas con NPC Taurock (`village_taurock`, `ai_npc_load`), y 030g el de las que tienen Cogs. Se declara en cada cierre.
- **Flows de regresión por corte:**
  - `f25_summon` (Shift+Q → «Trogg 960/960», nivel 1);
  - `f29_spit` (Earthfling 200 → 187);
  - `ai_summon` (la IA convoca con nivel 1, mismo orden que hoy);
  - `rules_suite`;
  - en 030e, además `f25_flying_summon`.

## 8. Riesgos

1. **Disco y tiempo del export (030a):** hoy son 1,6 GB de OBJ para 32 modelos (RFC-023 §2). Las 35 nuevas suman ≈ +1,7 GB (inferido). Si RFC-023 (esqueleto) se aprueba, esos clips se reemplazan por `.glb`. 030a sigue valiendo para los datos y los niveles.
2. **Pose y tamaño:** las 35 están horneadas desde la pose de enlace. Las alturas actuales pueden ser falsas (Phoenix 12,4 m). Se corrige al re-hornear con `idle`; si no, se usa `BodyPoseOverride`.
3. **Cuerpos grandes:** `BodySeparation` y la navegación (RFC-026) con cajas de 6 a 10 m pueden trabar el paso. Se mide en el banco de 030b.
4. **El export pierde roles de pasiva** (`abilities[2]`): **cerrado en 030f.** `passive_on_damage` se exporta aparte y `abilities` conserva el slot 2 porque la IA y `hmba` lo usan. Phoenix `rifl` no era activa.
5. **La IA valora habilidades que el port no tiene** (`fill_by_tag` usa el dato), así que puede preferir una criatura cuya habilidad todavía no existe. Es aceptable: la IA no usa habilidades de criatura.
6. **Escenas de debug sin `.tres` propio** heredan nivel 9 desde 030c (ver criterio 4 de 030c).
7. **Efectos de disparo y habilidades:** lo de §2.1 sale de grep (inferido). Cada corte lee la función de sacengine antes de codificar.

## 9. Fuera de alcance

- Hechizos de nivel ≥ 2 y el Shrine (otro RFC).
- Experiencia y subida de nivel en partida (`state.d:8862`, `28149-28200`).
- Casteo por ciclos según mago (`state.d:9543-9600`).
- Héroes de campaña, Dragon Hatchling, familiares, campaña.
- Almas iniciales del mapa (6 en High Noon; el port usa 12 como sacengine).
- Que la IA use habilidades de criatura.
- Sonido.

## 10. Orden de implementación

030a → 030b → 030c → 030d (con esto, **todas disponibles**) → 030e (las 5 de nivel 9 son híbridas) → 030e2 (pose y cápsula de las híbridas) → 030f → 030g → 030h → 030h2 (Scarab: telaraña que cura) → 030i-a → 030i-b → 030i-c → 030h3 (gotas de la Abomination; espera el RNG de simulación) → 030j → 030k → 030l → 030m → 030n → 030o → 030p → 030q → 030r → 030s → 030t → 030u → (030v).

## 11. Cómo verifica un humano

- **030a:** abrir `debug/f110_bestiary_gallery.tscn`, F6, Enter para ciclar roles. Las 51 de pie.
- **030b–030c:** F6 en `debug/f111_bestiary.tscn`, Enter, y `creature_1..11`. En el inspector, `MatchRules.wizard_level` del `.tres` cambia las casillas; `HighNoon/…/Wizard.level` muestra el nivel replicado.
- **030d:** F5 → selección → «Contra la IA» → elegir nivel → contar casillas y leer «Maná».
- **030e en adelante:** F6 en la escena del corte, Enter, y la acción de habilidad (Ctrl+Q) o una orden. El log imprime los números del criterio.

## 12. Preguntas abiertas (decide el orquestador)

1. **Nivel por defecto.**
   - (a) **Fijo, elegido en la partida, 9 por defecto** **[recomendado]**: todas disponibles, como sacengine `options.d:190`.
   - (b) Fiel al mapa: arranca en 3 y sube con experiencia hasta 9. Necesita XP, en un RFC aparte.
   - (c) Fijo en 3 (el mapa) sin XP: solo 5 criaturas por dios.
2. **Criaturas con habilidad o efecto pendiente.**
   - (a) **Se muestran igual: pelean con stats, disparo genérico y «No implementado» en la habilidad** **[recomendado]**: es fiel al libro y cada corte las completa.
   - (b) Se ocultan hasta su corte, con una lista en `MatchRules`.

## 13. Decisiones del orquestador (2026-10-16, delegadas por el usuario)

- **Numeración:** las features se corrieron +2 (F112–F133), porque F110 y F111 ya son de RFC-029.
- **P1 = (a):** nivel fijo elegido en la partida, 9 por defecto. La XP queda para otro RFC.
- **P2 = (a):** las criaturas se muestran aunque tengan habilidades pendientes, con «No implementado».
- **Conflicto con el PRD:** se resolvió en `changes/CHANGE-REQUEST-002.md` y en `PRD.md` («Fuera del primer corte»).
- **Orden:** 030a puede ir ya. 030b espera a que cierren F79/F80/F84 en el HUD (ya cerradas) y a 028a, porque los dos tocan el libro y el HUD.
- **030d (por REVIEW-F77):** «Contra la IA» se elige en el boot después de la selección de personaje. La fila «Nivel del mago» va junto a `%AiGod` en el boot, no en `character_select`.
- **030e (por el playtest de F112):** Rhinok flota en el idle (`Eds1`, que también es tag de vuelo) y Phoenix flota +3,26 m. Las dos entran al criterio de pose de 030e.
- **030e, revisado por REVIEW-F116 (2026-10-16):** fiel a sacengine (`sacobject.d:675-689`), Rhinok no vuela y camina siempre: sus slots de vuelo repiten `stance1`. Según los datos no flota, está hundido entre −0,77 y −1,47 m. Phoenix vuela siempre y no tiene takeoff ni land (`DF00`), así que también despega con destinos a 5 m. Se acepta como excepción al criterio 2. El criterio 3 (pose y cápsula: Rhinok, Hellmouth y Silverback hundidos, alas y cuellos fuera de la cápsula, y decidir con REA si Phoenix flota como en el original) pasa al corte nuevo **030e2**.
- **Deuda de 030e:** no hay combate en el aire (CHASE y ataque hacen bajar a tierra), falta el clip `hover`, `badLanding` y morir en el aire, el vuelo largo no sigue el relieve, y el export no aplica `nonFlyingTags` ni `fixFamiliar`.
