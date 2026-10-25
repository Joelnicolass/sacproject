# 055h — HUD nativo de Godot (plan del tech lead, pendiente de aprobación)

Fuente: RFC-055 §13.2 (fila «Lecturas del original»), §13.2b C-8b y el orden (paso 2–7, «055h en paralelo»); auditoría `research/055R-legacy-audit.md` §3.4 y §3.8 (fila HUD/UI). Conteos de `main` al 2026-10-25 (`3e06e217`), medidos con `tools/lint/conventions.sh --verbose`, `grep` y `wc`.

**Qué se mantiene (identidad, no se toca el diseño):** el libro abajo a la izquierda con sus tres pestañas y la tira, el plantel a la izquierda, el bloque de almas + maná + vida arriba a la derecha, el minimapa redondo abajo a la derecha, el menú radial de dos anillos, la caja de info junto al puntero y el cursor del original. Cambia **cómo** se dibujan y se escalan, no **qué** se ve.

**Contradicción a resolver (pregunta 9):** el pedido nombra «055k (audio)», pero RFC-055 §13.2b C-8a y 055R §3.8 definen **055k = cámara** (`Curve` de distancia y altura); el audio por tag es 055i-b + 055x (C-8d). Gana el RFC (autoridad RFC > este plan). La sección 8 cubre los dos casos.

## 1. Objetivo (criterios del RFC, sin extras)
- El HUD lo escala Godot: `display/window/stretch/mode = canvas_items`, `aspect = expand`, base 1280×720. Fuera `HudScale` y las «unidades de 480 px».
- Cada widget se ubica con anclas y contenedores en la escena; ningún script calcula `scale`, `pivot_offset` o tamaños por la altura de la ventana.
- Un solo `Theme` (`data/ui/theme.tres`) gobierna fuentes, colores, cajas, marcos, barras y pestañas del HUD.
- Las texturas llegan por `@export` o por el Theme, nunca por directorio: fuera `HudIcons`, `BitmapDigits` y las rutas a `assets/original` en código.
- El tamaño de la interfaz es un único valor de Godot (`Window.content_scale_factor`), con un único escritor.
- El aspecto a 1280×720 es el de hoy (mismo tamaño relativo ±2 %), y a 1080p y 1440p es proporcional.

## 2. Escena de prueba
No hace falta una escena nueva en `debug/`: el criterio empieza en la partida real (`match.tscn`, la escena que abre el jugador) y se mide con `agent/harness/match_shots` en la vista nueva `hud`. Estado inicial: mago local de High Noon contra la IA, con maná al 50 % (la opción `--cast` ya llena el maná; se agrega `--mana=0.5`), tres criaturas seleccionadas y el radial abierto en el centro (`--radial`). Lo que **no** está todavía: el JSON de rectángulos del HUD, que es el resultado del criterio. No hay acción de InputMap del playtester: el harness no toca la entrada.

Cada escena de widget corre sola con F6 (`spell_book.tscn` muestra pestañas, tira y tapa; `wizard_stats.tscn` muestra las barras y deja arrastrar `value` en el inspector). `debug/ui/f374_target_info.tscn` sigue existiendo y solo pierde el `hud_scale`.

## 3. Inventario del HUD de hoy

Alcance: todo lo que cuelga de `match.tscn › Hud` (16 nodos) más el control de tamaño de Opciones. No entra: lobby, servidor local, selector de personaje, pickers y `match_result` (son de 055i-a).

| Archivo | Líneas | Qué hace | Quién lo usa | Calco 1:1 del original | Lint |
|---|---|---|---|---|---|
| `hud/hud_scale.gd` + `data/ui/hud_scale.tres` | 95 | `pixels = units · scale · alto / 480`; guarda `[hud] scale`; `--hud-scale=` | 11 scripts (`spell_book`, `selection_roster`, `wizard_stats`, `radial_menu`, `radial_layout` doc, `minimap`, `minimap_marker_style` doc, `target_info_panel`, `command_cue`, `cursor_skin`, `graphics_tab`), 4 `.tscn`, 4 de `agent/`, `debug/ui/f374`, 7 flows | `SACENGINE_HEIGHT := 480.0` (hudScaling, `dagonBackend.d:311`), base 600 «de las capturas» | C16 |
| `hud/hud_icons.gd` | 136 | Carga por directorio: íconos por tag, hojas (`tabs`, `page`, `fram`, `spi2`, `spir`, `fn10`, tiras), cursores, XMNU; cachés estáticas | 9 scripts de UI, `debug/units/custom_creature.gd`, `agent/harness/hud_cache_probe.gd` | `OriginalAssets.UI_*_DIR` ×4, `icon_file(tag)` (nombre del WAD) | C13 ×5, C18 ×1, C9 |
| `hud/bitmap_digits.gd` | 62 | Dibuja el número de almas con la hoja `fn10` | `soul_counter.gd` | anchos de `sacfont.d:24-80`, `LINE_HEIGHT 14`, `SPACE_WIDTH 6` | C16 |
| `hud/hud.gd` + `hud.tscn` (nodo `WizardHud`) | 84 + 44 | Nombre · dios, «Fantasma», bloque de stats | `match_world.gd:101` | `_fraction` (`renderer.d:4799`) | — |
| `hud/frame_piece.tscn`, `text_readout.gd` | 5, 6 | Pieza de marco; texto sin dibujar para flows | libro, plantel, minimapa | — | — |
| `spell_book/spell_book.gd` | 229 | Pestañas, páginas, tira de `max(10, 2n)` segmentos y tapa armadas en código | `match_world`, `spell_command` (`%SpellBook`) | 7 `const` de regiones de `SacHud` (`renderer.d:4204-4213`), `PAGE 32`, `TAB 48`, `SEGMENT 16×8`, `CAP 48×16` | C1a, C5 ×2, C9 |
| `spell_book/spell_slot.gd/.tscn` | 59 / 100 | Una página: ícono, costo, recarga | libro | `factor = min(1, mana/manaCost)` | C9 |
| `selection_roster/selection_roster.gd` | 288 | Marco de 4 mitades espejadas armado en código, celdas, ícono de habilidad, `avoid` (se achica si toca el libro) | `ability_command` (`%SelectionRoster`) | `FRAME_SIZE 138×256`, `FRAME_X -34`, `HALF_REGION` (`renderer.d:4400-4466`) | C1a, C5, C9, C12, C18 |
| `selection_roster/roster_cell.gd`, `roster_plate.tscn` | 125, 9 | Celda 34×32; placa de respaldo sin caché | plantel | `healthColor`/`manaColor` (`sacobject.d:1155`) | C5 ×4, C9 |
| `wizard_stats/wizard_stats.gd/.tscn` | 65 / 164 | Bloque 128×96 unidades, `custom_minimum_size` por código | `hud.tscn` | regiones de `fram` (`dagonBackend.d:3076`) | C5 ×2, C9 |
| `wizard_stats/stat_bar.gd` | 65 | Barra con 3 tiras (`top`, `mid`, `bottom`) por prefijo de texto | `wizard_stats.tscn` | área 14/68, tapas 4/6 (`renderer.d:4808-4826`) | C9 |
| `wizard_stats/soul_counter.gd` | 86 | Alma girando (15 cuadros/s) + número con `BitmapDigits` | `wizard_stats.tscn` | 0,85 del marco, 15 fps (`dagonBackend.d:1620`) | C9 |
| `radial/radial_menu.gd` + `layout`, `slot`, `entry` | 366 + 78 + 51 + 33 | Menú X de dos anillos; `_factor` del HUD | `order_radial`, `menu_sounds` (hijo en `radial_menu.tscn`) | radios en «unidades HUD» (`*_px`) | C1b, C14 ×3, C9 ×4 |
| `minimap/minimap.gd` + `markers` + 5 chicos | 209 + 170 + 207 | Círculo abajo-der; `zoom` en metros por unidad HUD | `pointer_ray`, `minimap_pointing`, `match_world` | escala HUD, flechas a «0,92 R − 6 unidades» | C1a ×2, C6 ×6, C12 ×2, C9 ×7 |
| `target_info/target_info_panel.gd` + `target_info.gd` + `health_strip.gd` | 207 + 92 + 56 | Caja junto al puntero; `box_units`, fuente en unidades | — | `renderer.d:5036-5230` | C1a, C5, C6, C7 ×4, C12, C9 ×3 |
| `command_cue/command_cue.gd`, `cursor_skin.gd`, `cue_set.gd`, `target_probe.gd` | 170, 98, 43, 167 | Ícono armado a 4/32 bajo el cursor, cursor de hardware de 32 unidades, tabla de tags | `match.tscn` | `renderCursor` (`renderer.d:4113`), `aim_icons: Dictionary` de tags (`Matt`, `Mgua`, `zwp1`) | C1a ×2, C13 ×2, C12 ×2, C14, C7, C9 ×4 |
| `options/graphics_tab.gd/.tscn`, `user_settings.gd` | 129, 90 | Slider «Tamaño del HUD», sección `[hud]` | Opciones | — | C9 ×2 |
| `data/ui/command_cues.tres`, `radial/*.tres` (15), `minimap/*.tres` (10) | — | Tags de íconos; tamaños en unidades HUD | — | tags del WAD | — |

Totales del alcance: **C13 7 de 16** · **C16 2 de 41** · C18 1 (+1 que va a 055i-b) · C12 7 archivos del HUD (+`match_result`, de 055i-a) · C1a 8 · C1b 1 · C5 10 · C6 7 · C7 5 · C14 4 · C9 28. Además, 13 scripts fuera de `scenes/ui` llegan al HUD por `%NombreÚnico` de `match.tscn` (`orders/` 10, `audio/advisor_voice.gd`, `souls/soul_system.gd`, `match_world.gd`), y 13 flows de `agent/flows` usan rutas `Hud/...` (sobre todo `HighNoon/Hud/View`).

**El arte del original:** las 478 imágenes de `assets/original/ui/` están versionadas en git (RFC-023); el producto no necesita el juego instalado. Lo que sí lo necesita es regenerarlas: `tools/import/import_ui.py` y `export_stats.py` (ya avisan al arrancar: `sac_formats/install.py` imprime «Requiere el juego original instalado (SAC_INSTALL)» y sale con estado 2).

## 4. Árbol de archivos
```
project.godot                                [~] display/window/stretch/mode="canvas_items", aspect="expand" (la base 1280×720 ya está)
data/ui/
  [-] hud_scale.tres
  [+] ui_scale.tres                           UiScalePrefs: min 0.75, max 1.4 (el valor por defecto es Project Settings › Stretch › Scale)
  [~] theme.tres                              + variaciones Hud* (StyleBoxTexture sobre las hojas versionadas, fuentes y colores; ver §5)
  [~] command_cues.tres                       íconos de órdenes, de rechazo y cursores como Texture2D (no tags)
  [~] radial/orders_layout.tres (+ las que tengan tamaños)   radios e ícono en px de lienzo (×1,2)
  [~] minimap/*.tres                          tamaños de marca en px de lienzo (×1,2); view.tres: zoom → view_radius_m (metros al borde)
assets/original/ui/hud/
  [+] stats_frame.png, soul_frame.png, roster_frame.png, minimap_frame.png, book_cap.png   marcos enteros (espejados/rotados), derivados
  [+] stat_mana_bar.png, stat_health_bar.png, health_strip.png                             tira entera (tapa + relleno + tapa), derivadas
  [~] fn10.png.import                         fuente de imagen (FontFile) para el número de almas (pregunta 5)
  [-] stat_{mana,health}_{top,mid,bottom}.png reemplazadas por la tira entera
tools/bake/
  [+] hud_sheets.gd                           arma las 8 hojas derivadas desde las PNG versionadas (no necesita el original; avisa si falta assets/original/ui/hud)
  [+] fill_type_icons.gd                      una vez: `icon` de los .tres de criaturas, hechizos y habilidades desde assets/original/ui/icons (OriginalAssets.icon_file queda solo acá)
  [~] creature_icon.gd                        escribe CreatureType.icon (no busca assets/custom/icons/<tag>.png por convención)
scenes/core/[~] boot.tscn                     + UiScaleApplier
scenes/match/
  [~] match.tscn                              Hud: anclas en el inspector; conexiones MatchWorld.local_wizard_changed → bind(); sockets del HUD hacia órdenes (055h-4)
  [~] match_world.gd                          [-] %WizardHud.bind / %SpellBook.bind (la conexión vive en la escena)
scenes/ui/
  [~] README.md
  action_button/
    [+] action_button.gd, action_button.tscn  ActionButton (≤40): @export action: StringName del InputMap; al apretar inyecta esa acción
  hud/
    [+] README.md                             What / Not / Talks to / Edit / Check del HUD entero
    [-] hud_scale.gd, hud_icons.gd, bitmap_digits.gd, frame_piece.tscn
    [~] hud.gd, hud.tscn → [~] wizard_hud.gd, wizard_hud.tscn   mismo nodo `WizardHud`; textos con variación de tema
    [~] ritual_notice.gd                      slot local por bind (055h-4)
  spell_book/
    [~] spell_book.tscn                       pestañas, tira y tapa como nodos (§5)
    [~] spell_book.gd                         sin regiones, sin _build_frame, sin _fit_screen, sin HudIcons; bind(wizard: WizardBody) (≤150)
    [~] spell_slot.gd, spell_slot.tscn        página e ícono desde el tipo y el tema
  selection_roster/
    [~] selection_roster.tscn, .gd            marco = Panel; sin avoid, fitted_factor, _fit_screen ni _build_frame
    [~] roster_cell.gd, roster_cell.tscn      tamaños ×1,2; ícono = unit.type.icon
    [-] roster_plate.tscn                     (sin textura, el Panel ya es la placa)
  wizard_stats/
    [~] wizard_stats.tscn, wizard_stats.gd    HBox de 3 paneles con ProgressBar (≤40 líneas)
    [-] stat_bar.gd, soul_counter.gd
  target_info/
    [~] target_info_panel.gd, .tscn           tamaño y fuente desde la escena y el tema; sin _factor/_resize
    [-] health_strip.gd                       → ProgressBar horizontal, variación HudHealthStrip
    [~] target_info.gd                        ícono = type.icon
  radial/
    [~] radial_menu.gd, radial_menu.tscn      sin hud_scale/_factor/_fit; (055h-5) [+] radial_decor.gd, AnimationPlayer open/close
    [~] radial_layout.gd                      doc: px de lienzo
  minimap/
    [~] minimap.gd, minimap.tscn              sin factor/_fit_screen; marco = Panel HudMinimapFrame
    [~] minimap_view.gd, minimap_marker_style.gd   view_radius_m; px de lienzo
    [~] minimap_markers.gd                    slot local por bind (055h-4)
  command_cue/
    [~] command_cue.gd, command_cue.tscn      textura del armado desde CommandLog; tamaño en la escena
    [~] cursor_skin.gd                        px físicos = px de lienzo × (alto de ventana / alto del lienzo); texturas de CueSet
    [~] cue_set.gd                            Dictionary[StringName, Texture2D]
    [~] target_probe.gd                       slot local por bind (055h-4)
  options/
    [+] ui_scale_prefs.gd                     UiScalePrefs (Resource ≤60): get/set/guardar [ui] scale, --ui-scale=
    [+] ui_scale_applier.gd                   UiScaleApplier (Node ≤40): único escritor de Window.content_scale_factor; inerte en headless, dedicado y AgentKit salvo --ui-scale=
    [~] graphics_tab.gd, graphics_tab.tscn    slider «Tamaño de la interfaz» sobre UiScalePrefs
    [~] user_settings.gd                      sección [ui]; [hud] se ignora (pregunta 2)
scenes/spells/[~] spell_type.gd               + @export icon: Texture2D
scenes/units/abilities/[~] ability_type.gd    + @export icon: Texture2D
scenes/units/[~] creature_type.gd             doc de `icon` (ya existe; sin la ruta assets/custom)
scenes/wizards/[~] wizard_body.gd             + @onready var spellbook: Spellbook (una línea)
data/catalog/{creatures,spells,abilities}/[~] 188 .tres   `icon` lleno por fill_type_icons.gd
scenes/orders/
  [~] command_log.gd                          arm(kind, icon: Texture2D, …); armed_changed(kind, icon)
  command/[~] spell_command.gd, ability_command.gd, armed_command.gd   pasan la textura del tipo o de CueSet
  command/[~] pointer_ray.gd, minimap_pointing.gd, spell_command.gd, ability_command.gd   (055h-4) @export del widget en vez de %Minimap/%SpellBook/%SelectionRoster
agent/harness/match_shots/
  [~] match_shots.gd                          vista `hud` (cámara del juego, HUD visible), --mana=, --radial
  [+] hud_layout.gd                           escribe <png>.json: rect de cada widget en fracción del alto, px del cursor, ida y vuelta puntero↔mundo
agent/harness/[-] hud_scale_probe.gd, hud_cache_probe.gd · [~] pt142_probe.gd
agent/fixtures/[~] f037b/minimap_probe.gd, f038d/radial_probe.gd
agent/flows/[-] f84_hud_scale.json, pt92_scale.json · [~] f92_stats, pt84_group, pt142_b, pt142_b2, pt142dev_b (--ui-scale=)
debug/ui/[~] f374_target_info.gd, .tscn       sin hud_scale
debug/units/[~] custom_creature.gd            lee type.icon
```

## 5. Árbol de nodos

`match.tscn › Hud` (las rutas que usan los flows no cambian: nada se mete en contenedores nuevos):
```
Hud (CanvasLayer)
├── View (Button, rect completo)          el mundo; no se borra
├── SelectionRoster   ancla centro-izq    bind ← MatchWorld.local_wizard_changed
├── SelectionBox (ReferenceRect)
├── SpellBook         ancla abajo-izq     bind ←
├── Battle (CommandLog)                   infraestructura; no se borra
├── Minimap           ancla abajo-der     bind ←
├── RadialMenu        oculto
├── WizardHud         ancla arriba-der    bind ←
├── MatchResult · LobbyReturn · RitualNotice (bind ←)
├── TargetProbe (bind ←) · CursorSkin (bind ←) · CommandCue · HoverFrame
└── TargetInfoPanel (bind ←)
```
Cada nodo de infraestructura lleva `editor_description` «no borrar».

`wizard_hud.tscn`:
```
WizardHud (VBoxContainer, WizardHud)      bind(wizard)
├── WizardStats (instancia, shrink_end)
├── Stats (Node, TextReadout)             texto sin dibujar para los flows
├── Title (Label, HudTitle)
└── GhostState (Label, HudState)
```

`wizard_stats.tscn`:
```
WizardStats (HBoxContainer, WizardStats)  show_values(health, mana, souls)
├── Souls (Panel, HudSoulFrame, mín 77×115)
│   ├── Spin (TextureRect, anclas al 85 % centrado, AtlasTexture local de spir.png)
│   │   └── SpinPlayer (AnimationPlayer «spin»: 8 cuadros a 15/s, autoplay, loop)
│   └── Count (Label, HudSoulCount, centrado)
├── Mana (Panel, HudStatsFrame, mín 38×115)
│   └── Bar (ProgressBar, HudManaBar, fill_mode BOTTOM_TO_TOP, anclas del área 14..82 de 96, max 1)
└── Health (Panel, HudStatsFrame, mín 38×115)
    └── Bar (ProgressBar, HudHealthBar, ídem)
```

`spell_book.tscn`:
```
SpellBook (VBoxContainer, ancla abajo-izq, crece hacia arriba, SpellBook)   bind · show_tab · *_pressed
├── Tabs (HBoxContainer, ButtonGroup)
│   ├── CreatureTab (Button toggle, HudTabCreature 58×58)   «pressed» del tema = el selector
│   ├── SpellTab (Button toggle, HudTabSpell)
│   └── StructureTab (Button toggle, HudTabStructure)
└── Shelf (HBoxContainer)
    ├── Pages (VBoxContainer)
    │   ├── Strip (Panel, HudBookStrip, StyleBoxTexture en mosaico, mín 192×10)
    │   └── Slots (HBoxContainer)   ← spell_slot.tscn por entrada (en juego; es una lista de datos)
    └── Cap (Panel, HudBookCap, 19×58)
```
La página de cada pestaña y la marca de almas son íconos del tema del tipo `SpellBook` (`page_creature`, `page_spell`, `page_structure`, `spirit`), leídos con `get_theme_icon`, como cualquier control propio de Godot.

`selection_roster.tscn`:
```
SelectionRoster (Control, ancla centro-izq, SelectionRoster)   selection; ability_pressed
├── Frame (Panel, HudRosterFrame, 166×307, x = −41)
├── Cells (GridContainer, 2 columnas)   ← roster_cell.tscn (en juego)
├── Ability (Button 41×41, x = 85)
└── Refresh (Timer)
```

Tamaños: los números de hoy en «unidades HUD» × 1,2, redondeados a px enteros (hoy, con escala 0,8 sobre 480, una unidad son `alto/600` px; con base 720 son `1,2 · alto/720`: el mismo tamaño en cualquier 16:9).

## 6. Cómo lo hace un humano

| Verbo | Ejemplo | Qué abre y qué toca | Lugares | Código nuevo |
|---|---|---|---|---|
| Entender | «¿qué hay en el HUD y dónde?» | `match.tscn › Hud`: cada hijo con nombre, ancla visible en el viewport 2D y `editor_description`; `scenes/ui/hud/README.md` dice quién habla con quién. F6 sobre cada widget lo muestra solo | 1 | no |
| Modificar | «cambiar el ícono de un hechizo» | `data/catalog/spells/<hechizo>.tres` › `icon`: arrastrar un PNG | 1 | no |
| Modificar | «cambiar la textura o el color de la barra de maná» | `data/ui/theme.tres` › variación `HudManaBar` › `fill` (StyleBoxTexture) | 1 | no |
| Modificar | «mover el minimapa arriba a la izquierda» | `match.tscn › Hud › Minimap` › preset de anclas | 1 | no |
| Agregar | «agregar un botón al HUD» | instanciar `action_button.tscn` bajo `Hud`, preset de anclas, `action` = una acción del InputMap (p. ej. `pause`), ícono. Si la acción no existe: Project Settings › Input Map | 1–2 | no |
| Agregar | «una entrada más en el radial» | `data/ui/radial/orders_layout.tres` › `inner`/`outer` › un `RadialEntry` | 1 | no |
| Quitar | «sacar el minimapa» | borrar `Hud › Minimap`; los sockets `minimap` de `PointerRay` y `MinimapPointing` quedan vacíos y no hacen nada (055h-4) | 1 | no |
| Crear | «otra estética del HUD» | duplicar las variaciones `Hud*` de `theme.tres` y cambiar sus StyleBoxTexture y fuentes; el alma que gira está en `wizard_stats.tscn › Souls › Spin` | 2 | no |
| Crear | «un widget nuevo» | escena en `scenes/ui/<nombre>/`, instanciarla bajo `Hud`; si necesita al mago, conectar `MatchWorld.local_wizard_changed` → `bind` en el panel Señales | 2 | solo el del widget |
| Escalar | «cambiar el tamaño de todo el HUD» | el jugador: Opciones › Gráficos › «Tamaño de la interfaz». El diseñador: Project Settings › Display › Window › Stretch › Scale | 1 | no |
| Escalar | «otra resolución o pantalla 1440p» | nada: `canvas_items` + `expand` | 0 | no |

Revisado contra la regla de §2c: con arte en cada escena, «otra estética» pedía 5 escenas (libro, plantel, stats, minimapa, caja de info); por eso el arte de cajas y marcos va al Theme. Con `%Minimap` en las órdenes, «quitar el minimapa» rompía `pointer_ray`; por eso 055h-4 pasa esos tres a sockets.

## 7. Dueños (uno por estado)
| Estado | Dueño | Quién lo lee |
|---|---|---|
| Tamaño en pantalla de toda la UI (`Window.content_scale_factor`) | `UiScaleApplier` (único escritor; en `boot.tscn`) | Godot; `CursorSkin` deriva sus px físicos |
| Elección guardada del jugador | `UiScalePrefs` (`data/ui/ui_scale.tres`, `[ui] scale`) | `UiScaleApplier`, slider de Opciones |
| Valor por defecto | Project Settings › Stretch › Scale | `UiScalePrefs` cuando el jugador no eligió |
| Dónde está cada widget | anclas del nodo en `match.tscn` | Godot |
| Fuentes, colores, cajas, marcos, barras, pestañas, páginas | `data/ui/theme.tres` (variaciones `Hud*`) | cada control por `theme_type_variation` |
| Ícono de criatura, hechizo y habilidad | el `.tres` del tipo (`icon`) | libro, plantel, caja de info, `CommandLog` |
| Íconos de órdenes, de rechazo y cursores | `data/ui/command_cues.tres` | `CommandCue`, `CursorSkin`, `ArmedCommand` |
| Ícono armado en curso | `CommandLog.armed_icon` (lo escribe quien arma) | `CommandCue` |
| Mago y slot del jugador local en el HUD | `MatchWorld` (emite `local_wizard_changed`); cada widget guarda su copia en `bind` | nadie del HUD lee `MpKit` (055h-4) |
| Vida, maná, almas | `Health`, `ManaPool`, `SoulPurse` del mago | el HUD por señales |
| Pestaña activa del libro | `SpellBook.tab` (el `ButtonGroup` la refleja) | `SpellCommand` |
| Selección | `Selection` (orders) | el plantel solo muestra |

## 8. Riesgos y fuera de alcance

**Multijugador.** El HUD es presentación local: nada se replica y `content_scale_factor` es de cada proceso. En el dedicado no hay ventana: `UiScaleApplier` y `CursorSkin` quedan inertes, y como nadie llama `bind` el HUD sigue oculto (hoy cada widget pregunta `MpKit.local_slot()`; 055h-4 lo reemplaza por el `bind`). El nuevo `CommandLog.arm` pasa una textura local, no viaja por red.

**Cliente que entra tarde.** El HUD se arma cuando llega el mago local (`MatchWorld._check_local` → `local_wizard_changed`), igual que hoy; `bind` debe pintar en el acto los valores ya sincronizados (vida, maná, almas, libro). Los íconos salen de `unit.type` (resuelto por el spawner en la frontera), así que el cliente tardío los tiene sin buscar por tag. Se verifica con `debug/net/late_join.tscn`.

**UI a otras resoluciones.**
- `canvas_items` cambia también los menús (lobby, opciones, selector): a 720p se ven igual; a 1080p y 1440p crecen con la ventana (hoy quedan chicos). Las capturas de 055i-a cambian: 055h-1 entra antes.
- En 4:3 `expand` limita por el ancho: el HUD queda un 20 % más chico que hoy (que solo miraba la altura). En 16:9 y ultrapanorámico es idéntico.
- **NO VERIFICADO** que `Camera3D.project_ray_origin` / `unproject_position` y `get_mouse_position` queden en el mismo sistema con `canvas_items` (afecta `pointer_ray`, `selection.gd`, `target_probe`, `hover_frame_rules`, `order_radial`). Criterio numérico en §9 antes de seguir.
- **NO VERIFICADO** si Godot 4.7 escala `Input.set_custom_mouse_cursor` con el stretch; `CursorSkin` calcula los px físicos a mano (alto de ventana / alto del lienzo) y se mide.
- **NO VERIFICADO** si el importador de fuentes de imagen de Godot 4.7 respeta anchos por glifo (los de `fn10` son variables). Pregunta 5.
- `world_camera.gd edge_px := 100` pasa a ser px de lienzo: a 1440p el borde de scroll mide el doble en px físicos. Es de 055k (cámara), no se toca acá; se anota.
- El plantel y el libro no se tocan si la escala ≤ 1,4 (alto del lienzo ≥ 514: el plantel termina en 257 + 154 = 411, el libro empieza en 514 − 96 = 418). Por eso el tope es 1,4 y se borra `avoid`.

**Arte del original.** El HUD sigue funcionando sin el juego instalado: las PNG están versionadas y las escenas y el tema las referencian como cualquier textura. Sin `assets/original/ui/` (un fork sin el arte), Godot avisa dependencias faltantes al cargar y el HUD dibuja cajas vacías y barras planas; el arreglo es poner otras PNG en el tema. Herramientas:
- `tools/import/import_ui.py`, `export_stats.py`: **necesitan el original** y ya lo dicen al arrancar (salen con estado 2).
- `tools/bake/hud_sheets.gd`, `fill_type_icons.gd`: **no lo necesitan** (leen las PNG versionadas); si falta la carpeta lo dicen y no escriben nada.
- `creature_icon.gd`: no lo necesita (dibuja desde el modelo).

**Conflictos con otros cortes.** `spell_type.gd`, `ability_type.gd` y 188 `.tres` de `data/catalog/` (055h-3) chocan con 055e y con 055i-b/055c1 (renombran los `.tres`): ver §11. `wizard_body.gd` (+1 línea) es de 055e. `bake_catalog` reescribe `data/catalog/`: si se corre antes de congelarlo (055i), borra los `icon`; `fill_type_icons.gd` se vuelve a correr.

**Fuera de alcance.** `match_result` y todo el lobby (055i-a). El tag en `selection_roster.gd:235` (`GameData.ability`, 055i-b). Extraer el HUD a su propia `hud.tscn` (pregunta 8). Las fórmulas del minimapa más allá del radio en metros. Los 13 `%Nombre` del HUD desde `orders/`, `audio/` y `souls/` que no son libro, plantel ni minimapa (fase 3 / 055z). Teclas crudas de `spell_book.key_label` (055z). La niebla de guerra.

## 9. Criterios de aceptación medibles
**Greps en 0** (`scenes/ data/ agent/harness/ debug/`): `HudScale`, `hud_scale`, `HudIcons`, `BitmapDigits`, `SACENGINE_HEIGHT`, `_units\b`; en `scenes/ui/**.gd`: `_fit_screen`, `_fit()`, `assets/original`, `OriginalAssets`, `get_visible_rect().size.y`. `MpKit.` en 0 archivos del alcance del HUD (055h-4).

**Lint** (cada sub-corte reescribe la base con lo que bajó; nada sube):
| Regla | Hoy | Al cerrar 055h | Sub-corte |
|---|---|---|---|
| C13 | 16 | 9 (−7) | 055h-3 |
| C16 | 41 | 39 (−2) | 055h-1, 055h-2 |
| C18 | 131 | 130 (−1) | 055h-3 |
| C12 | 85 | 78 (−7) | 055h-4 |
| C5 | 217 | 213 (−4) | 055h-2 |
| C1a | 103 | ≤ 101 (`spell_book`, `command_cue` ≤150) | 055h-1..3 |
| C1b | 24 | 23 (`radial_menu`) | 055h-5 |
| C14 | 224 | 220 (−4) | 055h-1, 055h-5 |
| C9 | 355 | ≈ 330 (cada archivo tocado arregla su encabezado) | todos |

**Capturas** con `agent/harness/godot60_res.sh` (`PT_RES`) y `match_shots --views=hud --mana=0.5 --radial`, High Noon, a **1280×720, 1920×1080 y 2560×1440**, antes (`main` de hoy, `hud_scale` 0,8) y después. `hud_layout.gd` escribe por captura el rectángulo de `SpellBook`, `SelectionRoster.Frame`, `WizardStats`, las dos barras, `Minimap` y `RadialMenu`, en fracción del alto de la ventana.
1. **Igual a hoy:** cada rectángulo (alto, ancho y distancia a su esquina) después vs antes, ±2 % en las tres resoluciones.
2. **Independiente de la resolución:** después, la fracción de cada rectángulo es la misma en las tres, ±1 %.
3. **Barras:** con maná al 50 %, alto del relleno / alto del marco = 0,354 ±2 % (34 de 96, como `StatBar`).
4. **Escala del jugador:** con `--ui-scale=1.4`, el borde de abajo del plantel queda ≥ 4 px de lienzo sobre el libro en las tres; con 0,75 y 1,4 el libro sigue pegado a su esquina (±1 px).
5. **Cursor:** lado físico aplicado = round(38,4 × alto/720 × escala) ±1 px (lo informa `CursorSkin.apply_count` + el px aplicado).
6. **Puntero ↔ mundo con `canvas_items`:** en 5 puntos (centro y 4 esquinas a 60 px), el punto de suelo de `PointerRay` proyectado de vuelta cae a < 1,5 px de lienzo del puntero; el centro del marco de `HoverFrame` sobre el mago a ±2 px de su proyección. En las tres resoluciones.
7. **Número de almas:** ancho del texto «12» a 720p igual al de `BitmapDigits` de hoy ±1 px (si se usa la fuente de imagen).

**Red:** `debug/net/late_join.tscn`: el cliente tardío muestra maná y vida a ±1 % del host y el libro con la misma cantidad de entradas. Dedicado: `CursorSkin.apply_count == 0` y el HUD oculto.

**Suite:** `rules_suite` sin cambios (el HUD no es sim). Banco de determinismo omitido (memoria «Sin banco de determinismo»).

## 10. Código 1:1 que este corte borra
- `hud_scale.gd` entero: `SACENGINE_HEIGHT 480`, la base 600 de las capturas, `factor()`, `px()`, `MIN_PX/MAX_PX`, `socket_warning`, `--hud-scale=` y `[hud] scale`; y `data/ui/hud_scale.tres`.
- `hud_icons.gd` entero: los 4 `*_DIR`, `icon_file(tag)` en runtime, `CUSTOM_ICON_DIR`, las 5 cachés estáticas, `cursor_sized` con `Image.resize`.
- `bitmap_digits.gd` entero (anchos de `sacfont.d`, `LINE_HEIGHT 14`, `SPACE_WIDTH 6`).
- `spell_book.gd`: `TAB_REGIONS`, `SELECTOR_REGION`, `PAGE_REGIONS`, `FRAME_SEGMENT_REGION`, `FRAME_CAP_REGION`, `PAGE/TAB/SEGMENT/CAP`, `_build_frame`, `_fit_screen`, `icon_for`.
- `selection_roster.gd`: `FRAME_SIZE`, `FRAME_X`, `HALF_REGION`, `HALF_WIDTH`, `_build_frame`, `_fit_screen`, `avoid`, `avoid_margin`, `fitted_factor`; `roster_plate.tscn`.
- `wizard_stats.gd`: `block_units`, `frame_region`, `frame_mirror_region`, `frames`, `_fit`; `stat_bar.gd` y `soul_counter.gd` enteros; `health_strip.gd` entero.
- `radial_menu.gd`: `hud_scale`, `_factor`, `_fit`; `minimap.gd`: `factor`, `_fit_screen`, `zoom` en metros por unidad; `target_info_panel.gd`: `box_units`, `cursor_gap_units`, `pinned_margin_units`, `title_font_units`, `_factor`, `_resize`; `command_cue.gd`/`cursor_skin.gd`: `icon_units`, `cursor_units`, el `4/32` en código y los avisos «Faltan assets/original/ui/cursors».
- `cue_set.gd`: `aim_icons` de tags y `refused_icon` de texto.
- `frame_piece.tscn` y los marcos armados en código (libro, plantel, stats, minimapa).
- `agent/harness/hud_scale_probe.gd`, `hud_cache_probe.gd` y los flows `f84_hud_scale`, `pt92_scale`.

## 11. Sub-cortes y paralelo
| Sub-corte | Qué | Tamaño | Depende de |
|---|---|---|---|
| **055h-1** Godot escala | stretch `canvas_items`/`expand`; `UiScalePrefs` + `UiScaleApplier`; fuera `HudScale` y todo `_fit*`; tamaños ×1,2 en `.tscn`/`.tres`; slider; `CursorSkin` físico; vista `hud` + `hud_layout.gd`; criterios 1, 2, 4, 5, 6 | M | — |
| **055h-2** Un Theme para el HUD | `hud_sheets.gd`; variaciones `Hud*`; marcos como `Panel`; barras `ProgressBar`; alma con `AnimationPlayer`; número de almas; fuera `BitmapDigits`, `StatBar`, `SoulCounter`, `HealthStrip`, `frame_piece`; criterios 3 y 7 | M | 055h-1 |
| **055h-3** Íconos tipados | `icon` en `SpellType`/`AbilityType`; `fill_type_icons.gd`; `CueSet` con texturas; `CommandLog.arm(texture)`; fuera `HudIcons` | S–M | 055h-2 (comparte libro y plantel) |
| **055h-4** Jugador local por `bind` | conexiones `local_wizard_changed` → `bind`; slot local guardado; sockets `@export` de libro, plantel y minimapa en 4 scripts de `orders/` | S | 055h-1 |
| **055h-5** Radial en piezas | `RadialDecor` (dibujo del sector, puntero, centro y puntos), apertura y cierre con `AnimationPlayer`, `print` → `DebugLog` | S | 055h-1 |

Orden interno: 1 → 2 → 3, con 4 y 5 después de 1 (5 puede ir en paralelo con 2 o 3 porque solo toca `scenes/ui/radial/`; 4 va después de 3 porque toca los mismos widgets).

**Con 055i-a (UI, lobby, `sacrifice_flow`):** archivos disjuntos salvo `project.godot` (055h-1) y `data/ui/theme.tres` (055h-2). Regla: 055h-1 se integra antes de que 055i-a saque capturas de menús; mientras corre 055h-2, 055i-a no edita `theme.tres` (o lo hace en variaciones sin prefijo `Hud` y se integra después). 055h no toca `match_result`, `lobby/`, `local_server/`, `character_select/` ni los pickers.

**Con 055k:** si es la **cámara** (RFC), disjuntos (`scenes/camera/`); solo se le avisa que `edge_px` pasa a px de lienzo. Si es **audio**: disjuntos salvo `radial_menu.tscn` (aloja `MenuSounds`, 055h-5) y `match.tscn` (055h-1 y 055h-4, donde viven `ListenerFocus` y `CommandVoice`): esas ediciones van en serie.

**No en paralelo:** 055h-3 con 055e, 055c1 o 055i-b (`spell_type.gd`, `ability_type.gd`, `data/catalog/`).

## 12. Orden de implementación
1. (h-1) `project.godot` stretch. `UiScalePrefs`, `UiScaleApplier` en `boot.tscn`, slider. Medir el criterio 6 (puntero ↔ mundo) **antes** de seguir; si falla, parar y reportar.
2. (h-1) Por widget: borrar `hud_scale`/`_fit*`, pasar tamaños ×1,2 a la escena y a `radial/` y `minimap/` `.tres`; `CursorSkin` en px físicos; `target_info_panel` con fuente de tema.
3. (h-1) `hud_layout.gd` + vista `hud` en `match_shots`; capturas antes/después en las 3 resoluciones; borrar `hud_scale.gd`, `.tres`, probes y flows viejos; lint y base.
4. (h-2) `hud_sheets.gd` y las 8 hojas; variaciones `Hud*` en `theme.tres`; libro, plantel, stats, minimapa y caja de info con `Panel`/`ProgressBar`/`Button` de tema; alma con `AnimationPlayer`; número de almas; borrar los scripts de dibujo; criterios 3 y 7.
5. (h-3) `icon` en los tipos; `fill_type_icons.gd`; `CueSet` y `command_cues.tres` con texturas; `CommandLog.arm` y sus 4 llamadores; borrar `HudIcons`; `creature_icon.gd` y `custom_creature.gd`.
6. (h-4) Conexiones `local_wizard_changed` en `match.tscn`; `bind` guarda el slot; fuera `MpKit.` del HUD; sockets de órdenes; late join.
7. (h-5) `RadialDecor` y `AnimationPlayer`; `DebugLog`.
8. Cada paso: `bash tools/lint/conventions.sh` sin subas, `--update-baseline` con lo que bajó; README del HUD con `Check:`.

## 13. Cómo lo verifica un humano en el editor
- Project Settings › Display › Window › Stretch: `canvas_items`, `expand`, `Scale` = 1.
- `match.tscn` › Hud: cada widget seleccionado muestra su preset de anclas; arrastrarlo en el viewport 2D lo mueve; cambiar el tamaño de la ventana del editor (vista 2D) los deja en su esquina.
- F6 sobre `wizard_stats.tscn`: arrastrar `value` de `Mana/Bar` entre 0 y 1 llena la barra con sus tapas.
- `theme.tres` en el editor de temas: la vista previa muestra las variaciones `Hud*`; cambiar `HudManaBar › fill` se ve en `wizard_stats.tscn` sin correr nada.
- F5 en una partida: Opciones › Gráficos › «Tamaño de la interfaz» agranda y achica todo en vivo; maximizar la ventana mantiene las proporciones.
- `data/catalog/spells/<x>.tres` › `icon`: el libro muestra el nuevo ícono en la próxima partida.

## 14. Preguntas abiertas (con recomendación)
1. **¿La escala del jugador es de toda la interfaz (`content_scale_factor`: HUD y menús) o solo del HUD?** Recomiendo toda la interfaz, con el nombre «Tamaño de la interfaz»: es el mecanismo estándar de Godot, es un solo valor y los menús también lo necesitan a 1440p. Solo el HUD obligaría a mantener un factor propio, que es justo lo que se borra.
2. **¿Rango 0,75–1,4 y sin migrar el `[hud] scale` guardado?** Recomiendo que sí: 0,75–1,4 equivale al 0,6–1,12 de hoy, garantiza que el plantel nunca toca el libro (se borra `avoid`) y una preferencia local no justifica código de migración: el jugador vuelve al valor por defecto una vez.
3. **¿El arte de cajas y marcos va en el `Theme` (con 8 hojas derivadas por `hud_sheets.gd`) o como texturas dentro de cada escena (como el marco del minimapa hoy)?** Recomiendo el Theme: «otra estética» queda en 2 lugares en vez de 5, y es lo que pide la auditoría («un `Theme`»). El costo son 8 PNG derivadas de las versionadas.
4. **Barras como `ProgressBar` con StyleBoxTexture.** Al 0 % Godot no dibuja el relleno, así que tampoco las tapas (el original las muestra vacías). ¿Se acepta? Recomiendo aceptarlo: con 0 de maná el marco queda vacío y se lee igual; a cambio, el valor se previsualiza en el inspector. La alternativa es un `StatBar` de 40 líneas con 3 texturas `@export`.
5. **Número de almas:** ¿fuente de imagen desde `fn10.png` (NO VERIFICADO que respete los anchos por glifo) o un `Label` con la fuente del tema y contorno? Recomiendo probar la fuente de imagen con el criterio 7 y, si no da ±1 px, quedarse con el `Label` del tema sin más vueltas.
6. **¿Cuándo corre 055h-3 (toca 188 `.tres` del catálogo, `spell_type.gd` y `ability_type.gd`)?** Recomiendo antes de que arranquen 055e y 055i-b. Si alguno ya arrancó, 055h-3 espera a que termine y vuelve a correr `fill_type_icons.gd` sobre los archivos renombrados.
7. **¿055h-4 (el HUD no lee `MpKit`; sockets de órdenes) entra en 055h o se difiere a la fase 3?** Recomiendo que entre: baja C12 en 7, hace posible «quitar el minimapa» y es un solo dueño del jugador local en el HUD.
8. **¿Se extrae el HUD a su propia `scenes/ui/hud/hud.tscn` (F6 del HUD entero)?** Recomiendo que todavía no: hay 13 scripts de `orders/`, `audio/` y `souls/` que llegan al HUD con `%Nombre` de `match.tscn`, y 13 flows con rutas `Hud/...`. Pasarlos a sockets es un corte propio (fase 3 o 055z), y además toca archivos de audio.
9. **¿055k es la cámara (como dicen RFC-055 y 055R) o el audio?** Recomiendo seguir la numeración del RFC (055k = cámara) y llamar al corte de audio por su nombre (055i-b / 055x). Si es audio, aplica la regla de §11 sobre `match.tscn` y `radial_menu.tscn`.
10. **¿055h-5 (radial en piezas) va en este corte?** Recomiendo que sí, pero al final: es el único script de más de 300 líneas del HUD (C1b), solo toca `scenes/ui/radial/` y puede ir en paralelo con 055h-2 y 055h-3.
