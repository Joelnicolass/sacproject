# RFC-031 — Menú de opciones (gráficos y jugabilidad) y fuego amigo configurable

Estado: plan del tech lead (Opus), aprobado por el orquestador el 2026-10-16 («ok» del usuario al orden propuesto).
- Arquitectura estándar.
- MP online con dedicado (MpKit), sin RPC nuevas: la regla viaja en el snapshot de `MatchState`.
- Orden de autoridad: PRD > FEATURES > RULES > VISUAL > RFC-022/027/030 > este RFC.

Pedido del usuario (2026-10-16), textual: «que exista fuego amigo pero que sea configurable desde las opciones (hay que agregar un menu de opciones para config graficas y todo lo de jugabilidad)».

Features: F139–F143 (cortes 031a, 031a2, 031b, 031c, 031d).

## 1. Objetivo

- **Fuego amigo como en sacengine.**
  - **Activo:** todo daño a un cuerpo del mismo bando vale ×0,5. Cubre melee, disparo, hechizo, salpicadura, nube y edificios. El veneno queda en ×1.
  - **Apagado:** el daño entre aliados vale 0, como hoy.
- **Es una regla de partida.**
  - La elige quien crea la partida (solo, «Contra la IA», o el dedicado con `--friendly-fire` / `--no-friendly-fire`).
  - La decide el servidor y llega a los clientes.
  - En producto viene encendida, que es el default de sacengine.
- **Menú de pausa con Esc:** Continuar, Opciones y Salir al menú.
  - En solo pausa la partida; en red no.
  - Cierra la deuda de F115: hoy no hay forma de volver al boot.
- **Opciones → Gráficos:** preset (Baja, Media o Alta; son los `LookQuality` existentes), pantalla completa, VSync, tope de FPS y tamaño del HUD.
  - Es una preferencia local en `user://settings.cfg` y se aplica en vivo.
- **Opciones → Jugabilidad:** fuego amigo, soltar almas con P y almas iniciales.
  - En el boot son preferencias para las partidas que crea el jugador.
  - Dentro de una partida se ven los valores de esa partida, solo lectura.
- Las preferencias locales y la regla de la partida son objetos distintos. `data/match_rules.tres` nunca se modifica.

## 2. Hechos verificados

### 2.1 sacengine
- **Opciones** (`options.d:89-115`): `friendlyFire=true` (`:98`), `enableDropSoul=true` (`:106`), `fasterStandupTimes`, `fasterCastingTimes`, `alwaysGib`, `randomCreatureScale`, `charmNeutralCreatures`, `targetDroppedSouls`, `collectAlliedSouls`, `greenAllySouls`, `fogOfWar` y `protectManafounts`. En `Settings`: `souls=12` y `level=9` (`:190-191`).
- **Cómo viajan:** van en `GameInit`; las fija el host (`state.d:31398-31412`) y se aplican en `31470-31481`. Los flags `--friendly-fire` / `--no-friendly-fire` salen del nombre del campo (`app.d:333-355`); `--souls=N` en `app.d:278`.
- **Daño entre aliados:**
  - `dealDamage` devuelve 0 si `!friendlyFire && stance==ally` (`state.d:8961`; edificios `9165`).
  - `dealRawDamage` multiplica todo el daño por `sideDamageMultiplier` (`9005`; edificios `9175`). Ese multiplicador vale 0,5 entre aliados salvo con `DamageMod.ignoreFriendly` (`28892-28899`).
  - Un bando cuenta como aliado de sí mismo (`30058`).
  - La caída no pasa por esta regla (`8959`).
- **Veneno:** `dealPoisonDamage` lleva `ignoreFriendly` (`9415-9419`). Con fuego amigo pega ×1; sin fuego amigo, 0.
- **Salpicadura:** `dealDamageAt` solo saltea al `directTarget` (`9077`). El atacante entra en su propio radio.
- **Disparos directos:** filtran con `entry.id==intendedTarget || side!=propio` (p. ej. `23145`, `24374-24376`; Wrath, Fireball y Swarm en `16490-16494`, `16624`, `16892`). Un aliado que está en el camino no los frena.
- **Melee:** `meleeAttackTarget` puede golpear a un aliado que esté dentro de la caja de golpe (`14350-14383`, `30033-30039`). En el port queda **fuera de alcance**.
- **Menú:** `optionsMenu` («UNEM») da `unsupported()` en sacengine (`dagonBackend.d:1052`). El original tiene un FORM en el WAD (investigación 031-R).

### 2.2 Port
- **`Health`:**
  - `damage_typed` rechaza el daño del propio slot (`health.gd:79-97`). El comentario de `:81` cita mal `state.d:8961`.
  - `damage()` (melee, ritual) no mira el bando.
- **Lectores del daño:**
  - `SplashDamage` (Wrath, Fireball, Swarm, vapor, `SplashImpact`) delega en `Health`.
  - `Poisoned`, `SplashDamage` y `SplashImpact` usan `damage_typed`; `RangedShot._burst` usa daño directo y `_can_hit` ya es fiel.
  - `Rock` puede tocar al propio bando.
  - `GuardPost` reparte el daño antes de aplicar el bando.
  - `GrudgeMemory` ignora al propio slot.
  - La cura filtra por bando sola.
- **`MatchRules`** ya tiene `enable_drop_soul`, `starting_souls` y `wizard_level`. El default del script es «hoy»; el `.tres` de producto usa el valor de sacengine.
- **Trampa:** `ai_match` solo cambia `world.rules`. `Match`, `UnitSpawner` y `StructureSpawner` conservan su `rules` = `data/match_rules.tres`. Todo lector de la regla tiene que leer `world.rules`.
- **El nivel (F115)** viaja así: `SacrificeFlow.level_override` / `_cli_level` → `WizardSpawner._level` → `wizard_body.level`, que se replica.
- **Snapshot:** `MatchState.to_snapshot` / `apply_snapshot` (`match_state.gd:178-219`) es el canal hacia los clientes.
- **Gráficos:** `LookQuality` + `data/look/quality_{low,medium,high}.tres`, `QualityApplier` y `LookRig.apply_quality`. `HudScale` guarda `[hud] scale` en `user://settings.cfg`.
- **Input:** Esc no está mapeado. `MatchCommand._input` se calla con el grupo `walk_order`. Nadie usa `get_tree().paused`.
- **No existen en el port:** derribo/levantarse, casteo por ciclos, XP, niebla, alianzas y gibs.

## 3. Decisiones
1. **Valores por defecto.** `MatchRules.friendly_fire` vale `false` en el script (bancos y digests sin cambio) y `true` en `data/match_rules.tres`. `ally_damage_factor := 0.5` es una perilla del `.tres`.
2. **Un solo dueño del factor: `Health._side_factor(from_slot, ignore_friendly)`.**

   | Caso | Factor |
   |---|---|
   | Sin slot o bandos distintos | 1 |
   | Mismo bando, fuego amigo apagado | 0 |
   | Mismo bando, fuego amigo encendido | `ignore_friendly ? 1 : ally_damage_factor` |

   - Lo usan `damage()` y `damage_typed()`.
   - El valor sale de `MatchState`, buscado en el grupo `match_state` con caché perezosa.
   - Si `MatchState` no existe, el comportamiento es el de hoy.
3. `MatchState` toma la regla de `world.rules` y la manda en el snapshot. Los clientes solo la muestran.
4. **Veneno:** `damage_typed(…, ignore_friendly := true)` desde `Poisoned`.
5. **`MatchSetup`** (RefCounted en `SacrificeFlow`) reemplaza `level_override` / `_cli_level`.
   - `HighNoon._enter_tree`, en la autoridad, aplica `rules = setup.apply_to(rules)` (`duplicate()`) antes de `MatchSeed.begin`.
   - Precedencia: boot > flag > reglas.
6. **Preferencias locales.** `GraphicsPrefs` y `GameplayPrefs` son Resources compartidos (patrón `HudScale`) y viven en `[graphics]` / `[partida]` de `user://settings.cfg`. El archivo lo maneja el helper estático `UserSettings`.
7. **Gráficos por presets:** el menú elige un `LookQuality` y no copia sus campos. «Personalizada» queda fuera.
8. **Pausa.**
   - En solo usa `get_tree().paused`; en red muestra el overlay sin pausar.
   - Mientras está abierto, el grupo `menu_open` calla a `MatchCommand`, `WizardBody._read_forward` y `WorldCamera`.
   - Antes de salir se pone `paused = false`.
9. **Digest.**
   - `ai_duel_seeded.tres` hereda `false`, así que seed 7 `4915c884…`, seed 1 y `--npcs` no cambian.
   - Nuevo `debug/rules/ai_duel_seeded_ff.tres` con `friendly_fire = true` como segunda referencia.
   - Escribir `false` explícito en el `.tres` no sirve, porque Godot no guarda los valores por defecto.
10. **Jugabilidad:** entran fuego amigo, soltar almas y almas iniciales. Lo que no tiene sistema en el port queda fuera.
11. **Look del menú:** placeholder con el tema del boot hasta 031-R.

## 4. Cortes
Cada corte pasa por developer → reviewer → playtester con ventana y capturas.

### 031a — F139 Fuego amigo como regla de simulación
```text
scenes/data/match_rules.gd             M  grupo «Daño entre aliados»: friendly_fire := false, ally_damage_factor := 0.5 (state.d:28892-28899)
data/match_rules.tres                  M  friendly_fire = true (options.d:98)
scenes/world/match/match_state.gd      M  valores efectivos desde world.rules (no su @export); snapshot; log «fuego amigo: sí/no»
scenes/world/components/health.gd      M  _side_factor() único; damage() y damage_typed(…, ignore_friendly := false); caché de MatchState; comentario :81 corregido
scenes/world/units/poisoned.gd         M  damage_typed(…, true) (state.d:9418); doc actualizada
scenes/world/spells/splash_damage.gd   M  doc: la regla de bando vive en Health; el atacante entra en su radio (state.d:9077)
debug/bench_rules.gd                   M  doc: los bancos heredan friendly_fire = false
debug/rules/f139_ff_clouds.tres        N  f116 + friendly_fire = true (Druid propio a 3 m de Cog/Necryl/Mutant)
debug/rules/f139_ff_off_clouds.tres    N  igual con false
debug/rules/f139_ff_fireball.tres      N  pyro nivel 1, FF on; Druid enemigo con 2 Cogs propios a 2 m y 5 m
debug/rules/f139_ff_shot_line.tres     N  FF on; Earthfling propio, Druid propio en el camino, Druid enemigo a 25 m
debug/rules/ai_duel_seeded_ff.tres     N  segunda referencia de digest
debug/f139_friendly_fire.tscn          N  runner ai_match, default f139_ff_clouds.tres
debug/rules_suite.gd                   M  caso «fuego amigo»: on ×0,5; off 0; veneno on ×1, off 0
```
Criterios:
1. **Vapor, FF on:** el Druid propio toma entre 0,495 y 0,505 de la fórmula. El enemigo, igual que en F118.
2. **Veneno, FF on:** el Druid propio y el enemigo toman en relación 1,00 ± 0,01. La cura no cambia.
3. **FF off:** el Druid propio toma 0 y no tiene `poison_dose`.
4. **Fireball:** cada Cog propio toma 0,5 ± 0,005 de la fórmula, y su `GrudgeMemory` no anota el slot 1.
5. **Disparo en línea:** el Druid propio en el camino toma 0.
6. **Regresiones:**
   - Digests seed 7, seed 1 y `--npcs` sin cambio.
   - `ai_duel_seeded_ff` corrido dos veces da el mismo digest, que se anota.
   - `rules_suite` y `guardian_cases` PASS.
   - AGENT_OK en `f25`, `pt118`, `pt119` y `pt136`.
   - Pasan los flows de las escenas que heredan el producto.

### 031a2 — F140 MatchSetup, flag del dedicado y la regla en los clientes
```text
scenes/flow/match_setup.gd             N  MatchSetup (RefCounted): level, friendly_fire (−1 = reglas); apply_to(rules) duplicate; from_cli()
scenes/flow/sacrifice_flow.gd          M  setup reemplaza level_override/_cli_level; --friendly-fire/--no-friendly-fire; reset en play_solo/host_lan/return_to_boot
scenes/world/high_noon.gd              M  _enter_tree (autoridad): rules = setup.apply_to(rules) antes de MatchSeed.begin
scenes/world/wizard/wizard_spawner.gd  M  _level() → rules.wizard_level
```
Criterios:
1. Dedicado con `--no-friendly-fire`: el servidor y los dos clientes imprimen «fuego amigo: no». Sin el flag imprimen «sí».
2. En solo con el flag pasa lo mismo.
3. F115 sin regresión: nivel 4 da 7 casillas, y el dedicado con `--level=2` da 5.
4. `data/match_rules.tres` no cambia en memoria.
5. Los digests no cambian.

### 031b — F141 Menú de pausa y Salir al menú
```text
project.godot                          M  acción pause_menu = Escape
scenes/ui/pause_menu/pause_menu.tscn   N  CanvasLayer > Dim > Panel: Continuar, Opciones (oculto hasta 031c), Salir al menú + ConfirmationDialog; process_mode ALWAYS
scenes/ui/pause_menu/pause_menu.gd     N  PauseMenu: open/close; solo → paused; red → no; grupo menu_open; Salir: paused=false → return_to_boot
scenes/world/high_noon.tscn            M  instancia PauseMenu
scenes/world/match_command.gd          M  callado con menu_open
scenes/world/wizard/wizard_body.gd     M  _read_forward 0 con menu_open
scenes/world/world_camera.gd           M  teclado ignorado con menu_open
```
Criterios:
1. **Solo:** Esc deja `paused == true`. Una criatura se mueve ≤ 0,01 m en 3 s y la IA queda quieta.
2. Con el menú abierto no responden ni las teclas ni el clic.
3. Al continuar, la partida sigue.
4. Salir → boot en ≤ 2 s con `paused == false`. Después, «Contra la IA» en nivel 4 da 7 casillas (cierra la deuda de F115).
5. **Red:** el menú de A no frena a B ni al servidor. Si A sale, el servidor registra `peer_left` y B sigue.
6. Captura a 1280×720 donde el menú se lea bien.

### 031c — F142 Opciones → Gráficos
```text
scenes/ui/options/user_settings.gd     N  UserSettings (static): read/write en user://settings.cfg; no pisa un archivo ilegible
scenes/ui/hud_scale.gd                 M  usa UserSettings
scenes/ui/options/graphics_prefs.gd    N  GraphicsPrefs (Resource): presets, quality, vsync, fullscreen, max_fps; [graphics]; --quality= por corrida
data/ui/graphics_prefs.tres            N  presets = quality_{low,medium,high}.tres
scenes/ui/options/graphics_applier.gd  N  GraphicsApplier: ventana/VSync/max_fps; rig.apply_quality solo en partida; inerte en headless
scenes/ui/options/options_menu.tscn/.gd N  OptionsMenu: TabContainer + Cerrar
scenes/ui/options/graphics_tab.tscn/.gd N  Calidad, Pantalla completa, VSync, Límite de FPS, Tamaño del HUD
scenes/ui/boot.tscn/.gd                M  botón Opciones + OptionsMenu + GraphicsApplier
scenes/ui/pause_menu/pause_menu.tscn   M  Opciones visible
scenes/world/high_noon.tscn            M  GraphicsApplier con rig = %Look
```
Criterios:
1. Al pasar a Baja en partida, `read_back` coincide con `quality_low` y la partida no se corta.
2. `settings.cfg` guarda `[graphics]` sin tocar `[hud]`, y el cambio sobrevive al reinicio.
3. VSync y el tope de FPS se aplican. En el primer arranque: Media, VSync on, sin tope.
4. El slider del HUD funciona en vivo.
5. Con un archivo corrupto se usan los defaults sin pisarlo. En headless o dedicado no se aplica nada.
6. Las escenas de debug conservan su preset.

### 031d — F143 Opciones → Jugabilidad
```text
scenes/ui/options/gameplay_prefs.gd    N  GameplayPrefs: friendly_fire, drop_soul, starting_souls; [partida]; to_setup(level)
data/ui/gameplay_prefs.tres            N
scenes/ui/options/gameplay_tab.tscn/.gd N  edición (boot) / solo lectura (partida, lee MatchState)
scenes/ui/options/options_menu.tscn    M  pestaña Jugabilidad
scenes/flow/match_setup.gd             M  drop_soul, starting_souls; --souls=N, --drop-soul/--no-drop-soul
scenes/flow/sacrifice_flow.gd          M  play_solo(setup) / play_vs_ai(god, setup)
scenes/ui/boot.gd                      M  arma MatchSetup = GameplayPrefs + %AiLevel
scenes/world/match/match_state.gd      M  snapshot + drop_soul, starting_souls
```
Criterios:
1. Con fuego amigo off en «Contra la IA», el log dice «no» y un Fireball a una criatura propia hace 0.
2. Con 6 almas, los dos magos arrancan con 6. Con «soltar almas» off, P no hace nada.
3. Los valores persisten.
4. En partida la pestaña es de solo lectura y en el cliente muestra los valores del servidor.
5. El dedicado y los bancos ignoran las preferencias.

### 031-R — Menú del original (investigación, sin código)
Con REA y el WAD, listar los FORM del menú (`UNEM` y sus hijos) y compararlos con 031c y 031d.

## 5. Digests

| Digest | 031a | Resto |
|---|---|---|
| seed 7 `4915c884…`, seed 1, `--npcs` | igual | igual |
| `ai_duel_seeded_ff` | nuevo | igual |
| partidas de producto | cambian: las salpicaduras pegan ×0,5 a aliados y el veneno ×1 | — |

## 6. Riesgos
- **Escenas de debug que heredan el producto.** Si un flow falla, se le da un `.tres` con `friendly_fire = false`.
- **Daño a uno mismo con fuego amigo.** El tirador recibe ×0,5 dentro de su propio radio, lo que cambia lo declarado en F119.
- **`Health.damage()` aplica la regla de bando.** Hay que verificar `village_cases` y `bench_events`.
- **`paused` sobrevive a `change_scene`.** AgentKit, FxBus y los tweens tienen que seguir funcionando.
- **Esc con un hechizo armado.** Abre el menú y no desarma el hechizo.
- **Cambio de preset en vivo.** Hay que medir el costo de rehacer el pasto y el suelo.
- **Caché de `MatchState` perezosa.** Se resuelve en el primer golpe.

## 7. Fuera de alcance
- Melee contra un aliado que se interpone (`state.d:14350-14383`).
- Opciones sin sistema en el port.
- Preset «Personalizada».
- Gamma, audio y remapeo de teclas.
- Botón de host LAN en el boot.
- Look final del menú, que depende de 031-R y del OK del usuario.

## 8. Orden
031a → 031a2 → 031b → 031c → 031d. 031-R puede ir en cualquier momento. Las corridas de Godot van de a una.
