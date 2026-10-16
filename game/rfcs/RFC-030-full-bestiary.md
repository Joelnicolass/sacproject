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

### 030i — F120 Aturdir y petrificar (Flummox, Basilisk)

**Árbol**
- N: `impacts/stun_impact.tscn` y `impacts/petrify_impact.tscn`.
- N: `scenes/world/units/stun.gd` (estado en la unidad, hijo).
- M: `unit_body.gd` (modo detenido); `data/shots/crba.tres`, `dpsf.tres`.

**Escena de prueba:** `res://debug/f118_stun.tscn`. **Criterio:** el blanco queda quieto el tiempo del original (log) y después vuelve a pelear.

### 030j — F121 Empuje, vórtice y catapulta (Squall, Vortick, Flurry)

**Árbol**
- N: `impacts/push_impact.tscn` y `impacts/vortex_impact.tscn`.
- M: `data/shots/amba.tres`, `cita.tres`, `caba.tres`.

**Escena de prueba:** `res://debug/f119_push.tscn`. **Criterio:** la posición del blanco cambia lo medido contra sacengine (23840, 23974, 24602).

### 030k — F122 Veneno y congelación a distancia (Necryl, Deadeye, Hellmouth, Silverback)

**Árbol**
- N: `impacts/poison_impact.tscn` y `impacts/freeze_impact.tscn`.
- N: `scenes/world/units/poisoned.gd` y `frozen.gd` (efectos hijos).
- M: `data/shots/cena|lfda|mhba|rdba.tres`.

**Escena de prueba:** `res://debug/f120_poison.tscn`. **Criterio:** daño por segundo medido; el congelado no se mueve.

### 030l — F123 Disparos de fuego (Tickferno, Pyromaniac, Bombard)

**Árbol**
- N: `impacts/burn_impact.tscn` (si el efecto propio lo pide).
- M: `data/shots/sfba|lffa|cfba.tres`.

**Escena de prueba:** `res://debug/f121_fire_shots.tscn`. **Criterio:** forma de vuelo y daño de cada uno contra el original.

### 030m — F124 Rayos y armas (Gnome, Warmonger, Styx)

**Árbol**
- N: `impacts/bolt_impact.tscn` (patrón `StyxBolt`/`StyxExplosion`).
- M: `data/shots/plfa|fhga|dhga.tres`.

**Escena de prueba:** `res://debug/f122_bolts.tscn`. **Criterio:** daño y radio medidos.

### 030n — F125 Disparos grandes (Boulderdash, Phoenix, Rhinok)

**Árbol:** M `data/shots/emba|rdra|hrba.tres` (más un impacto si hace falta).

**Escena de prueba:** `res://debug/f123_big_shots.tscn`. **Criterio:** daño y forma medidos.

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

### 030p — F127 Halo of Earth y Breath of life
- **Árbol:** N `abilities/halo_of_earth.tscn/.gd`, `abilities/breath_of_life.tscn/.gd`; M `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f125_abilities.tscn`. **Criterio:** efecto medido.

### 030q — F128 Web pull y Cage pull
- **Árbol:** N `abilities/pull.tscn/.gd` (una escena; `.tres` o `@export` distinto por tag, `state.d:13538`); M `ability_catalog.tres`.
- **Escena de prueba:** `res://debug/f126_pull.tscn`. **Criterio:** el blanco se acerca X m.

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

030a → 030b → 030c → 030d (con esto, **todas disponibles**) → 030e (las 5 de nivel 9 son híbridas) → 030e2 (pose y cápsula de las híbridas) → 030f → 030g → 030h → 030h2 (Scarab: telaraña que cura; gotas de la Abomination) → 030i → 030j → 030k → 030l → 030m → 030n → 030o → 030p → 030q → 030r → 030s → 030t → 030u → (030v).

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
