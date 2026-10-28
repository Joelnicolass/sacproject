# RFC-025 — Selección sin tope, deselección con clic en vacío e iconos en lugar de textos indicadores

Estado: plan del tech lead, pendiente de OK. Arquitectura **estándar** (RULES.md). MP **online con dedicado** (MpKit). Autoridad: PRD > FEATURES > RULES > VISUAL > RFC > este plan.
Pedido del usuario (2026-10-14), textual:
1. «Mejoras en la selección de unidades: poder ver las unidades seleccionadas. En el juego original se ven a la izquierda y estaban limitadas; en nuestra versión prefiero que NO haya límite de unidades que se puedan seleccionar.»
2. «Tocar con el click izquierdo fuera de una unidad debería deseleccionarla.»
3. «Sacar los textos que están como indicadores (por ejemplo "elegí el suelo") y colocar los iconos que van realmente (usar Aseprite o sacar los iconos originales del juego).»

Features: **F78** = 025a, **F79** = 025b, **F80** = 025c. F70 queda reservada al pasto; F71–F77 son de RFC-024.

## 0. Contradicciones entre artefactos (gana el primero)

| Choque | Dónde | Gana |
|---|---|---|
| «hasta 12 (la más nueva va primero)» | FEATURES F27, `selection.gd` (`max_size := 12`), `orders.gd` (`max_units := 12`) | **El pedido del usuario: sin tope.** F27 se reescribe al cerrar 025a. |
| «El clic en el suelo no deselecciona» | FEATURES F27, que copia sacengine `dagonBackend.d:1171-1198` | **El pedido del usuario: el clic en vacío deselecciona.** Desviación consciente del original, anotada en F27. |
| «Se reconocen… el HUD… del juego original» | VISUAL.md, pilar 2 | Va **con** el pedido: el panel copia el marco 2×6 del original y los iconos salen del original. |
| «Nada del juego original se commitea» | RULES.md «Datos», VISUAL.md «Assets» | Gana. Los iconos van solo al caché (`cache/`, ignorado). El repo guarda tags y regiones, como hoy `spell_book.gd`. |
| «Textos de pantalla en español» | RULES.md «Idioma» | Rige para los textos que quedan (Vida/Maná/Almas, avisos de ritual, resultado). |

## 1. Objetivo (criterios de aceptación del pedido)

- La selección local no tiene tope: rectángulo, Shift, Ctrl o doble clic, los grupos (ver P2) y las órdenes llegan a **todas** las seleccionadas, también en red con dedicado.
- Un clic izquierdo en vacío (suelo o nada) deselecciona, sin Shift ni Ctrl, solo si no hay nada armado y no fue un arrastre. Un clic sobre la HUD nunca deselecciona.
- Las seleccionadas se ven en un panel a la izquierda con el marco del original, 2 columnas × 6 filas: hasta 12, una celda por unidad con icono y barras de vida y maná; más de 12, una celda por tipo con el número. Sin tope. Clic en una celda: deja solo esa unidad o ese tipo.
- Ningún texto indicador queda dibujado en la HUD. El hechizo, la orden o la habilidad armada aparece en el cursor; el cursor cambia según el blanco; un rechazo hace destellar `ncst`. Una prueba automática que busca textos en la HUD da 0.
- Rendimiento con 150 seleccionadas sin regresión medible (§7).

## 2. Hallazgos

Marcas: [P] port, [S] sacengine, [I] instalación, [O] captura del original, [REA] ejecutable.

### 2.1 Estado actual del port [P, VERIFICADO]
**Selección** (`scenes/world/selection.gd`, 291 líneas): solo criaturas propias vivas; tope `max_size := 12` aplicado en `_replace`, `_merge_front`, `_push_back`, `_same_type_near`, `select_rect`; clic elige, Shift+clic alterna, Ctrl+clic o doble clic eligen el tipo a 50 m; arrastre ≥ 3 px dibuja el rectángulo (un rectángulo vacío **sí** deselecciona); grupos 1–0, las convocadas entran al grupo 0. No hay anillos: la única marca es `HealthBar.set_selected` (`units/unit_health_bar.gd:34`), como en el original (`renderer.d:3890-3895`). `_prune()` corre en cada `_process`; `_replace` y `_merge_front` usan `Array.has` (O(n²)).

**Mando** (`scenes/world/match_command.gd`, 583 líneas): `%View` es un `Button` a pantalla completa que recibe los clics del mundo; los controles de la HUD encima se comen su clic. `_left_at` sin nada armado solo actúa si hay una criatura propia bajo el cursor: **un clic en el suelo hoy no hace nada**. Modos armados: `spell`, `structure`, `ability`, `attack`, `guard`, `menu`; el clic derecho cancela. El mago se mueve con E/S/D/F, no con el clic izquierdo. La acción `select` por teclado o AgentKit apunta a `_action_pointer()`.

**Textos indicadores que hoy se dibujan:**

| Texto | Origen | Cuándo |
|---|---|---|
| «Mago» | `match_command.gd` → `%Battle` | Nada seleccionado o armado |
| «<Nombre>» / «N unidades» | `_on_selection_changed` → `%Battle` | Cambia la selección |
| «Elegí el blanco» | `_arm_spell`, `_arm_order`, `_use_ability`, menú | Algo armado |
| «Elegí el suelo», «Elegí tu criatura», «Elegí un alma roja», «Elegí una criatura propia», «Elegí un edificio propio» | `SpellAction.prompt` (`wizard/wizard_body.tscn:113-139`) → `%Battle` | Estructura armada (Manalith `htlm`, Desecrate `ucas`, Convert `ccas`, Guardian `ndrg`, Teleport `elet`) |
| «Menú: Ataque/Escolta/Avance/Guardia/Retirada» | `_toggle_order_menu` | Menú de órdenes |
| «Orden/Ataque/Escolta/Guardia/Avance/Retirada» | `ORDER_TEXT` | Orden enviada |
| «Sin mago», «Nadie», «Sin suelo», «Sin blanco», «No implementado» | `match_command.gd` | Clic sin efecto |
| Nombre del hechizo o rechazo («Sin maná», «Enfriando», «Fuera de alcance», «Blanco inválido», «Sin lugar», «Lanzando», «Sin almas», «Sin fuente», «Lejos de un edificio propio») | `Caster.feedback` (RPC `_receive_feedback(text)`, `caster.gd:190-214`) | Respuesta del servidor |
| Nombre de la habilidad o «Sin habilidad», «Enfriando» | `units/active_ability.gd:18-23` | Ctrl+Q |
| «Trogg 960/960» / «4 unidades» | `scenes/ui/hud.gd` → `%Unit` | Selección |

**Textos que no son indicadores (quedan, ver P3):** «Mago · Dios» (`%Title`), «Vida/Maná/Almas» (`%Stats`), «Fantasma», avisos de ritual, resultado, respaldos sin caché, segundos de enfriamiento (solo dígitos), tooltips, error de desarrollo «Falta el terreno».

**Flows atados:** 94 flows leen el texto de `%Battle` (339 asserts; los más comunes «Elegí el blanco» ×29, «Orden», «Enfriando», «Rock»); 23 flows leen `%Unit` (62 asserts). AgentKit lee con `_node_text` (`addons/agent_kit/agent_flow.gd:430`, cae en `str(node.get("text"))`). AgentKit **no** tiene un assert de propiedad genérica.

**Iconos en el caché:** `tools/export_icons.py` escribe `cache/look/icons/<tag>.png` (174 archivos 32×32: criaturas, hechizos, habilidades; ya están `ycro`, `oham`, `palk` y las estructuras `htlm`, `ucas`, `ccas`, `ndrg`, `elet`) y `cache/look/hud/{tabs,page,fram,spi2}.png` (`fram` 128×128). `spell_book.gd` los carga con `Image.load_from_file` y regiones `AtlasTexture`.

**Órdenes** (`scenes/world/orders.gd`): RPC `submit_order(unit_paths, …)`, el servidor valida `owner_slot`; `max_units := 12` corta la lista en `_own_units`. La formación en línea crece sin tope (150 unidades a ~2,5 m = ~370 m); `_match` es O(n²) con sort.

### 2.2 Juego original en sacengine [S, VERIFICADO]
- **Panel:** `renderSelectionRoster`, `renderer.d:4400-4466`. Marco `huds.FLDR/fram.TXTR` con sub-región `selectionRoster` (138×256 unidades HUD, x = −34, centrado en vertical). Celdas 34×32: columna 0 para i < 6, columna 1 (x + 36) para i ≥ 6, fila `i % 6`. Icono = ICON de la criatura. Barra de vida 2×30 `healthColor` (192,0,0); maná `manaColor` (0,96,192) (`sacobject.d:1155-1156`). Icono de habilidad 34×34 en x = 105. Escala `hudScaling` = alto/480. Se dibuja siempre (aunque vacío). Clic en celda = `select` de esa criatura; Ctrl = `selectAll`; clic en habilidad = `selectAbility` (`dagonBackend.d:891, 1171-1198, 1969, 2046`).
- **Tope:** `numCreaturesInGroup = 12` (`state.d:30143-30145`), `getFormationOffsets` devuelve `Vector2f[12]` (`state.d:417`).
- **Clic izquierdo en vacío:** en `MouseStatus.standard` solo actúa sobre criatura seleccionable; en el suelo no hace nada (`dagonBackend.d:1171-1198`). `clearSelection` solo lo usan `setSelection` y el rectángulo.
- **Cursor** (`SacCursor`, `sacobject.d:1973-2021`): en `curs.FLDR`: normal `Cnor`, unidad propia `Cfun`, neutral `Cnun`, rescatable `Crun`, enemiga `Ceun`, diálogo `Ctlk`, edificio propio `Cfbg`/neutral `Cnbg`/enemigo `Cebg`, alma propia `Cspr`, rectángulo `Cdbx`, arrastre `Cdrg`, deslizar `Csld`; cursores de blanco armado `Tfrn` (propio), `Tntr` (neutral), `Tnme` (enemigo), `Tnon` (nada). Iconos de orden en `icon.FLDR`: `Matt` (atacar), `Mgua` (escoltar/guardia), `Mgot` (mover). Blanco inválido: `ncst`. Dibujo (`renderCursor`, `renderer.d:4113-4165`): cursor de 32·hudScaling, punto caliente arriba al centro; con algo armado el icono va 4/32 más abajo; `ncst` encima si `!targetValid`.
- **Menú de órdenes (xmenu):** `SacXmenu` (`sacobject.d:2024-2066`, `xmnu.d`), entradas en `xmenu.wad`: atacar `tta1`, escoltar `aug1`, mover `vom1`, retirada `zwp1`, habilidad `iba1`, más formaciones.
- **Rechazos de hechizo:** voz del consejero (`spellAdvisorHelpSpeech`, `dagonBackend.d:57-78`). **El original no dibuja texto**: el único texto de la HUD de partida es el número de almas (`renderText`, `renderer.d:5315-5344`).

### 2.3 Instalación [I, VERIFICADO]
`main.wad`: `curs.FLDR` (17 `*.ICON` más `Cebc`, `Cfbc`, `Cfol`, `Ckik`, `Cnbc`, `Cur1.PALT`, `Slct`); `icon.FLDR`: `Matt`, `Mgot`, `Mgua`, `ncst` (32×32 indexado), `Ifls.TXTR`; `huds.FLDR`: `fram`, `page`, `tabs`, `sarr`, `slst.PALT`. `data/xmenu.wad` existe; qué icono le toca a cada XMNU: **NO VERIFICADO** (el exportador lo resuelve leyendo `XMNU.icon`).

### 2.4 Captura del original [O, VERIFICADO]
`visual/refs/original/orig_4_manantial.webp`: a la izquierda, centrado en vertical, marco ornamentado de 2 columnas × 6 huecos redondos con gemas azules; a su derecha un hueco circular (habilidad); cursor = mano dorada; las estadísticas son barras con el número de almas (fuera de este RFC).

### 2.5 Ejecutable [REA, NO ENCONTRADO]
`strings` sobre `Sacrifice.exe` no muestra los tags (se guardan como enteros). El snapshot `.rea-snapshots/sacrifice-exe` (32 KB) no trae el análisis de la GUI. No se lanzó Ghidra (memoria). La verificación se apoya en sacengine, el WAD y la captura. Confirmación en el exe = paso aparte con Ghidra y un solo proceso.

### 2.6 Herramientas [VERIFICADO]
Aseprite: `/Users/joelsartori/.local/bin/aseprite` (wrapper). LFS cubre `game/assets/cc0/**` y `game/assets/mm/**`; no hay patrón para `assets/ui/`.

## 3. Diseño

### 3.1 Selección sin tope (025a)
- `Selection.max_size`: `0` = sin tope (por defecto en `high_noon.tscn`); con `12` vuelve el modo clásico, editable en el inspector. El mismo knob gobierna los grupos y el grupo de convocadas (P2).
- Membresía: `Dictionary` instance_id → nodo junto al `Array` de orden; `has()` O(1); `_replace` y `_merge_front` O(n).
- API nueva: `clear()`, `select_only(units)`, `remove(units)`, `has(unit)`. La señal `changed(units)` no cambia.
- `Orders`: `max_units = 0` = sin tope (en el servidor, misma escena). La formación en línea se parte en **filas de `row_size` (12)**; las filas siguientes van detrás separadas por `spacing` (extensión propia, sacengine no la tiene). La guardia flanqueada solo en la primera fila.
- RFC-024: la IA planea en grupos ≤ 12 (`apply_for`) y no depende del tope; coordinar el merge de `orders.gd` (§8).

### 3.2 Regla exacta del clic izquierdo (025a)
Precondiciones: el evento llega a `%View` (ningún Control `STOP` de la HUD lo tomó) o por la acción `select`; no fue arrastre de rectángulo (≥ 3 px) ni de cámara.

| Estado | Bajo el cursor | Shift | Ctrl | Resultado |
|---|---|---|---|---|
| Algo armado (spell, structure, ability, attack, guard, menu) | cualquier cosa | — | — | Lo de hoy: el armado consume el clic. **Nunca deselecciona**, aunque se rechace. |
| Nada armado | criatura propia seleccionable | — | — | Lo de hoy: `Selection.click` (Shift alterna; Ctrl o doble clic eligen el tipo). |
| Nada armado | suelo (rayo de máscara 1) o nada (cielo/vacío) | no | no | **`Selection.clear()`** y se olvida el doble clic (`_last_unit = null`). |
| Nada armado | suelo o nada | sí | — | Nada: Shift suma, no borra. |
| Nada armado | suelo o nada | — | sí | Nada: Ctrl es selección por tipo o vista libre. |
| Nada armado | otro cuerpo (enemigo, mago propio, edificio, cadáver, alma) | — | — | Nada: es «una unidad» u objeto. |
| — | control de la HUD (libro, panel, pestañas) | — | — | No llega a `%View`; sin cambio. |

`WizardHud` (textos arriba a la derecha) sigue con `MOUSE_FILTER_IGNORE`; el panel y el libro son `STOP`. El rectángulo vacío sin Shift ya deselecciona. El clic derecho cancela el armado y no toca la selección.

### 3.3 Panel de seleccionadas: `SelectionRoster` (025b)
- Escala por `_fit_screen` como el libro (alto/480); a la izquierda, centrado en vertical. Marco: región `fram` del original en repetición (`renderer.d:4206`); ajuste fino contra la captura lado a lado.
- **Por unidad** (selección ≤ `capacity` = `columns × rows` = 2 × 6): una celda por unidad, más nueva primero; columna `i >= rows`, fila `i % rows`; barra de vida 2×30 (192,0,0) y maná (0,96,192) si `maximum > 0`.
- **Agrupado** (selección > `capacity`): una celda por `creature_tag`, por cantidad descendente y luego tag; `%Count` muestra **solo dígitos**; vida = Σvida / Σmáximo del grupo (igual maná). Si los tipos superan `capacity`, crecen columnas hasta `max_columns` (4) y luego `ScrollContainer`.
- **Clics:** por unidad — clic `select_only([u])`, Shift `remove([u])`, Ctrl todas del tipo dentro de la selección; agrupado — clic `select_only(tipo)`, Shift `remove(tipo)`.
- **Habilidad:** `%Ability` muestra el icono de la habilidad activa; su clic emite `ability_pressed`, conectado a `_use_ability()` (igual que Ctrl+Q).
- **Tooltip:** «Trogg 960/960» o «Trogg ×50», apagable desde el inspector.
- **Rendimiento:** pool de `capacity` celdas; se reconstruye solo en `Selection.changed`; barras con `Timer` a `refresh_hz` (10); no se conectan 150 señales de `Health`.
- **Visibilidad:** siempre visible (también vacío) cuando `MpKit.local_slot() > 0`; oculto en el dedicado.
- **Desvíos implementados en 025b:** (1) sin `max_columns`: si los tipos superan `capacity` el panel **no** crece en columnas (el marco `fram` es de 2×6 fijo) y las filas extra hacen scroll vertical en el `ScrollContainer`; (2) en modo agrupado Ctrl+clic equivale al clic simple (no hay «tipo dentro de la selección» distinto); (3) knob extra `base_height` (480) para la escala; (4) la habilidad del icono sale de `Selection.ability_tag()`, la misma fuente que Ctrl+Q en `match_command`; (5) el panel no tiene socket `command`: `match_command` conecta `ability_pressed`.

### 3.4 Del texto al icono (025c)
**`CommandLog`** (Node, sin dibujo, conserva el nombre `Battle` / `%Battle`): `armed` (`""`, `spell`, `structure`, `ability`, `attack`, `guard`, `menu:<orden>`), `armed_icon` (tag del caché), `text` (último mensaje, **no se dibuja**; lo leen flows y log). API `arm(kind, icon_tag)`, `disarm()`, `say(text)`; señales `armed_changed`, `said(text, cue)`. `match_command` llama a esa API donde hoy escribe `%Battle.text`. La RPC `_receive_feedback(text)` **no cambia**: el texto se traduce a un cue en el cliente con `CueSet`.

**Vistas:** `CommandCue` (Control a pantalla completa, `MOUSE_FILTER_IGNORE`): `%Aim` = icono armado que sigue al puntero con el desfase del original (4/32 hacia abajo), 32·hudScaling; `%Invalid` = destello `ncst` de `flash_s` (0,6 s). `CursorSkin` (Node): `Input.set_custom_mouse_cursor` con `C*` sin nada armado y `T*` con algo armado, según el blanco bajo el puntero (rayo a `hover_hz` 30), escala hudScaling, punto caliente arriba al centro; no hace nada en headless ni dedicado. `%Invalid` también se enciende sin clic si el blanco no corresponde (órdenes: nada bajo el cursor; estructuras: blanco que no coincide con `SpellAction.pick`). El chequeo por `flags` de hechizo queda fuera.

**Desvíos implementados en 025c:** (1) nodo extra `TargetProbe` (un rayo para cursor y cue); (2) `CommandCue`, `TargetProbe` y `CursorSkin` van al final de `Hud` para que el icono dibuje sobre todo; (3) `CommandLog.arm(kind, icon_tag, prompt, accepts)` y `armed_accepts` para el `%Invalid` por blanco inválido; (4) `%Mirror` y `last_flash_s` en `CommandCue` para capturas y medición; (5) `CueSet` guarda los datos en el `.tres` (el script no trae valores); (6) iconos `armed_icon` de retirada = `zwp1` (XMNU), resueltos por `HudIcons.armed`.

**Del texto a su reemplazo:**

| Texto actual | Reemplazo |
|---|---|
| «Mago», «<Nombre>», «N unidades» | Nada; lo muestra el panel. |
| «Elegí el blanco» (hechizo) | Icono del hechizo (`icons/<tag>`) sobre el cursor `T*`. |
| «Elegí el suelo»/«…criatura»/«…alma roja»/«…criatura propia»/«…edificio propio» | Icono de la estructura (`htlm`, `ucas`, `ccas`, `ndrg`, `elet`) sobre `T*`. `SpellAction.prompt` deja de dibujarse; el campo queda para no tocar `wizard_body.tscn` (lo toca RFC-023). |
| «Elegí el blanco» (Ctrl+R / Ctrl+A) | `Matt` / `Mgua` sobre `T*`. |
| «Elegí el blanco» (habilidad) | Icono de la habilidad sobre `T*`. |
| «Menú: X» | Icono de X en el cursor: atacar/avance `Matt`, escolta/guardia `Mgua`, retirada con el XMNU `zwp1`. El menú radial completo queda fuera. |
| «Orden/Ataque/…/Retirada», nombre del hechizo o habilidad al empezar | Nada: ya están el ping y el barrido de enfriamiento del libro. El sonido va en otro RFC. |
| Rechazos («Sin maná», «Enfriando», «Fuera de alcance», «Blanco inválido», «Sin lugar», «Lanzando», «Sin almas», «Sin fuente», «Lejos…», «Sin blanco», «Sin suelo», «No implementado», «Sin habilidad») | Destello `ncst` (P1). |
| «Sin mago», «Nadie» | Nada; el original no hace nada. |
| Texto desconocido por `feedback` | Solo `CommandLog.text` y log. |

**Iconos — vía principal = originales desde el caché.** `tools/export_icons.py` suma: `curs.FLDR/*.ICON` → `cache/look/cursors/<Nombre>.png`; `Matt`, `Mgua`, `Mgot`, `ncst` → `cache/look/icons/`; los XMNU de `xmenu.wad` → `cache/look/xmenu/<tag>.png` resolviendo `XMNU.icon`. Paleta del ICON = la del mismo folder (`Cur1.PALT`). Por qué: VISUAL.md pide reconocer el HUD del original, los iconos existen todos y el pipeline ya existe. **Aseprite solo si aparece algo que el original no tenga** (hoy ningún candidato): iría a `game/assets/ui/` con patrón LFS nuevo en `.gitattributes` y con OK del usuario.

**Sin caché (clon sin instalación):** `CommandCue` dibuja un círculo de respaldo con `_draw`; `CursorSkin` deja el cursor del sistema; ambos muestran `_get_configuration_warnings()` «falta cache/look/cursors». El juego no se rompe.

**Auditoría de textos:** `agent/harness/hud_text_audit.gd` recorre el `CanvasLayer` `Hud` y cuenta `Label`, `RichTextLabel` y `Button` visibles con letras, salvo los del grupo **`hud_text_allowed`** (asignado en el `.tscn`: `%Title`, `%Stats`, `%GhostState`, `RitualNotice`, `MatchResult`). Respaldos sin caché y dígitos no cuentan.

### 3.5 Red
Selección local del cliente, no se replica. Las órdenes siguen por `Orders.request` (valida dueño en el servidor); con 150 unidades el paquete fiable de `submit_order` pesa ~6–12 KB (ENet fragmenta). Los rechazos siguen por `_receive_feedback(text)`. **Sin RPC nueva ni tocar `addons/mp_kit`.** El dedicado no instancia cursores y oculta el panel con `local_slot() == 0`.

### 3.6 AgentKit
Assert genérico nuevo `{"assert": {"node": "...", "prop": "count", "equals": 150}}` con variantes `gte`, `lte`, `contains`, en `addons/agent_kit/agent_flow.gd`; sube después a `godot-studio-skills`. Sin esto los criterios numéricos dependerían de textos de overlays.

## 4. Escenas de prueba (bancos reproducibles)

Un banco nuevo es otra escena o los mismos `@export`/`.tres` con otros números, no otro script.

| Banco | Instancia | Estado inicial | Acción |
|---|---|---|---|
| `res://debug/selection_many.tscn` **(N)** | Hereda `debug/orders_group.tscn` (`high_noon.tscn` + `debug/rules/orders_group.tres` + `units/unit.tscn`, `debug/orders_group.gd`) | James, 150 criaturas propias quietas en grilla delante del mago, `own_tags = ["ycro","oham","palk"]` (50 de cada una), Druid enemigo a 40 m, `idle_aggro` apagado; nada seleccionado, panel vacío | `check_tick` (rectángulo sobre las 150) |
| `debug/orders_group.tscn` (existe) | ídem, 4 Trogg | 4 Trogg y Druid | `check_tick`, `order_units`, `order_attack`, `order_guard`, `order_menu` |
| `debug/rock_hit.tscn` (existe) | James, Druid a 40 m, Trogg a 60 m | Nada armado | `spell_N` de Rock, luego `select` |
| `debug/guardian_manalith.tscn` (existe) | Pestaña Estructuras | Nada armado | `spell_N` Manalith |
| `debug/ability_spit.tscn` (existe) | Earthfling seleccionado | Habilidad sin usar | Clic en `%Ability` |

`debug/orders_group.gd` (M): `@export var own_tags: PackedStringArray` (vacío = `own_tag`, los bancos de hoy no cambian); el overlay `%OrdersLog` suma `sel N · ordenadas N · rect_us · order_us · frame_ms`. Harness `agent/harness/selection_probe.gd` (N): `aim_empty()` proyecta un punto de suelo a 8 m del cúmulo sin cuerpos a 3 m y lo pone en `%Camera.debug_pointer`; `aim_body(name)`. El clic por puntero real se prueba aparte con `drag` de 0 px en una coordenada fija de suelo.

## 5. Árbol de archivos y responsabilidades

```text
game/
├── FEATURES.md                                   M  F27 reescrito (sin tope, clic en vacío); F78, F79, F80
├── addons/agent_kit/agent_flow.gd                M  assert {node, prop, equals|gte|lte|contains}
├── data/ui/command_cues.tres                     N  CueSet: claves de cue → tag de icono; rechazos → cue. Solo tags.
├── tools/export_icons.py                         M  + cursores curs.FLDR, + Matt/Mgua/Mgot/ncst, + iconos XMNU de xmenu.wad
├── scenes/
│   ├── ui/
│   │   ├── hud_icons.gd                          N  class_name HudIcons (static): icon(tag), sheet(name), region(name, rect), cursor(name), xmenu(tag)
│   │   ├── spell_book.gd                         M  usa HudIcons; sin cambio de conducta
│   │   ├── hud.gd · hud.tscn                     M  025b: sale %Unit y show_selection/show_unit; 025c: grupo hud_text_allowed
│   │   ├── ritual_notice.tscn · match_result.tscn M  025c: grupo hud_text_allowed (si P3 = mantener)
│   │   ├── selection_roster/
│   │   │   ├── selection_roster.tscn             N  Control: %Frame, %Cells (GridContainer), %Ability (Button); MOUSE_FILTER_STOP
│   │   │   ├── selection_roster.gd               N  vista de Selection: modo unidad/agrupado; pool de celdas; Timer de barras; clics; ability_pressed; count, mode, last_build_us
│   │   │   ├── roster_cell.tscn                  N  Button 34×32: %Icon, %Health, %Mana, %Count (dígitos)
│   │   │   └── roster_cell.gd                    N  show_unit / show_group / set_bars; pressed_with(shift, ctrl)
│   │   └── command_cue/
│   │       ├── cue_set.gd                        N  class_name CueSet extends Resource
│   │       ├── command_cue.tscn / .gd            N  Control full rect IGNORE: %Aim, %Invalid; respaldo _draw sin caché
│   │       └── cursor_skin.gd                    N  set_custom_mouse_cursor C*/T*; no-op headless
│   └── world/
│       ├── command_log.gd                        N  class_name CommandLog (Node): armed, armed_icon, text; arm/disarm/say; señales
│       ├── selection.gd                          M  max_size 0 = sin tope; Dictionary; clear/select_only/remove/has; last_rect_us
│       ├── match_command.gd                      M  regla 3.2; %Battle.arm/disarm/say; conecta ability_pressed
│       ├── orders.gd                             M  max_units 0 = sin tope; filas de row_size (12); last_apply_us
│       └── high_noon.tscn                        M  Battle: Label → Node(CommandLog); + SelectionRoster (tras View), CommandCue, CursorSkin; Selection.max_size = 0; Orders.max_units = 0
├── debug/
│   ├── orders_group.gd                           M  own_tags; overlay con sel/ordenadas/tiempos
│   └── selection_many.tscn                       N  hereda orders_group.tscn: 150 propias, 3 tipos
├── agent/
│   ├── harness/selection_probe.gd                N  aim_empty(), aim_body(name)
│   ├── harness/hud_text_audit.gd                 N  audit() → found y lista
│   ├── tools/migrate_unit_asserts.py             N  reescribe los 23 flows de %Unit
│   └── flows/ f78_deselect, f78_many, f78_online_a (+ run_f78_net.sh), f79_roster, f79_roster_many, f80_cues, f80_hud_text   N
│              (23 flows con %Unit)               M  025b, migración mecánica
└── rfcs/RFC-025-selection-and-hud-icons.md       N  este documento
```

**Mapa de responsabilidades:** `Selection` = estado local de selección y grupos (no dibuja); `MatchCommand` = input → selección, armado y órdenes (no dibuja texto); `CommandLog` = estado observable del mando local; `CommandCue`/`CursorSkin` = presentación del armado y del cursor (no deciden); `SelectionRoster` = presentación de la selección, el clic delega en `Selection`; `Orders` = autoridad de órdenes; `HudIcons` = carga de imágenes del caché; `CueSet` = datos de qué icono va con qué. Sin `SelectionRoster` no hay panel; sin `CommandCue` no hay icono en el cursor; el juego sigue andando.

## 6. Resource, nodo o `@export`

- **Resource:** `CueSet` (`data/ui/command_cues.tres`): `aim_icons` (`attack→Matt`, `guard→Mgua`, `move→Mgot`, `retreat→<xmenu zwp1>`), `refused_icon = "ncst"`, `refusals` (cada constante de rechazo → `&"refused"`), `target_cursors`/`free_cursors` (tipo de blanco → nombre de cursor). Otra variante = otro `.tres`. Tipos de criatura, hechizo y habilidad siguen en `CreatureType`, `SpellType`, `AbilityType`.
- **Nodos:** `SelectionRoster`, `RosterCell`, `CommandCue`, `CursorSkin`, `CommandLog`, `Selection`, `Orders`.
- **`@export` de instancia (inspector de `high_noon.tscn`):** `Selection.max_size` (0); `Orders.max_units` (0) y `row_size` (12); `SelectionRoster`: `columns` (2), `rows` (6), `max_columns` (4), `cell_size` (34×32), `refresh_hz` (10), `tooltips` (true), sockets `selection` y `command`; `CommandCue`: `log`, `cues`, `flash_s` (0,6); `CursorSkin`: `cues`, `hover_hz` (30), `enabled`. Sockets vacíos → `_get_configuration_warnings()`. Colores de barras (192,0,0) y (0,96,192) como `@export_color_no_alpha` en `RosterCell`, con la cita.

## 7. Cortes

Cada corte: **studio-developer → studio-reviewer (una pasada) → studio-playtester con ventana y capturas**; se cierra solo con el playtest en verde, actualizando FEATURES. Godot: un solo proceso, `--max-fps 60`, RSS < 2,5 GB, nada de `look_bench`; el editor del usuario está abierto. Antes de editar `match_command.gd`, `orders.gd` o `high_noon.tscn`, **releer el archivo** (otros agentes y RFC-024 también los tocan).

### 025a — Selección sin tope y clic en vacío (F78)
Developer: `selection.gd`, `orders.gd` (filas), `match_command.gd` (regla 3.2), `orders_group.gd` (`own_tags`, overlay), `selection_many.tscn`, `selection_probe.gd`, assert `prop` de AgentKit, flows f78.

Criterios:
1. `selection_many.tscn`, `check_tick` → `%Selection` `size()` == **150**; overlay `sel 150`. Con `max_size = 12` en el inspector, el mismo paso da 12.
2. Con 150, `order_units` sobre el suelo → `ordenadas 150`; ancho lateral ≤ `12·spacing + 1 m`; `ceil(150/12)` = 13 filas (`filas 13 ancho X`).
3. Clic en vacío deselecciona por dos caminos: (a) `selection_probe.aim_empty` + `press select`; (b) `drag` de 0 px en el píxel de suelo fijo. En ambos `size` == 0 y `barras 0`.
4. Shift + clic en vacío y Ctrl + clic en vacío → `size` sigue en 150.
5. Clic sobre el Druid, sobre el mago propio (`aim_body`) y sobre `%CreatureTab` → `size` sin cambio.
6. Con algo armado no se deselecciona: Rock armado + clic en vacío → `size` sin cambio y `%Battle` `text` == «Blanco inválido» (sigue armado); Ctrl+R + clic en vacío → avance, `size` sin cambio.
7. Grupos (si P2 = sí): `group_set_1` con 150, vaciar con clic en vacío, `group_1` → `size` == 150.
8. Regresión: `f27_orders`, `f27_pt_group`, `f27_pt_formation`, `f27_pt_summon`, `f25_summon`, `f29_spit`.
9. Rendimiento (overlay): `rect_us` ≤ 4000; `order_us` ≤ 12000; `frame_ms` promedio de 120 cuadros con 150 seleccionadas − con 0 seleccionadas ≤ **1,0 ms** (calidad media, 1280×720).
10. Red: `run_f78_net.sh` levanta el dedicado y un cliente con `--world=res://debug/selection_many.tscn`; el cliente selecciona 150 y ordena mover; el servidor imprime `orden move 150` y las 150 cambian de `mode`.

Playtester: `f78_deselect`, `f78_many`, `f78_online_a`; capturas `f78_0_start`, `f78_1_sel150`, `f78_2_order_rows`, `f78_3_cleared`.

### 025b — Panel de seleccionadas (F79)
Developer: `hud_icons.gd` (y `spell_book` lo usa), `selection_roster/*`, `hud.gd/tscn` (sale `%Unit`), `high_noon.tscn` y `ability_pressed`, `migrate_unit_asserts.py` + los 23 flows, `f79_*`.

Criterios:
1. Sin selección, `%SelectionRoster` visible con `count` == 0 y 12 huecos. Captura lado a lado con `orig_4_manantial.webp`: el reviewer compara lugar, proporción y marco a 1280×720 y 1920×1080.
2. `orders_group`, `check_tick` → `count` == 4, `mode` == `"unit"`, 4 celdas con icono `ycro`, vida llena.
3. `selection_many`, `check_tick` → `count` == 150, `mode` == `"group"`, 3 celdas, suma de `%Count` == 150 (50/50/50).
4. Agrupado: clic en la celda Trogg → `size` == 50, todas `ycro`; Shift+clic en la celda Manahoar (con 150) → `size` == 100.
5. Por unidad: clic en la celda 2 → `size` == 1 (esa unidad); Ctrl+clic → `size` == 4.
6. Un golpe del Druid a un Trogg seleccionado: la barra de su celda baja en ≤ 0,2 s (captura y `print` de `fraction`).
7. `ability_spit.tscn`: `%Ability` visible con el icono de Rockform; clic → maná 200 → 187 (igual que F29).
8. Clic en el fondo del panel → `size` sin cambio.
9. No existe `%Unit`; los 23 flows migrados pasan.
10. Rendimiento con 150: `last_build_us` ≤ 1500; refresco de barras ≤ 300 µs por tick; el Δ `frame_ms` de 025a.9 se mantiene.

Playtester: `f79_roster`, `f79_roster_many`; capturas `f79_0_empty`, `f79_1_four`, `f79_2_grouped150`, `f79_3_side_by_side`.

### 025c — Iconos en lugar de textos (F80)
Developer: `export_icons.py`, `command_log.gd`, `command_cue/*`, `cue_set.gd` y `command_cues.tres`, `match_command.gd` (`arm/say`), `high_noon.tscn` (Battle → Node), `hud_text_audit.gd`, grupos `hud_text_allowed`, `f80_*`.

Criterios:
1. `python3 tools/export_icons.py` imprime cursores ≥ 17, órdenes 4 (`Matt`/`Mgua`/`Mgot`/`ncst`) y xmenu ≥ 5; archivos en `cache/look/{cursors,icons,xmenu}/`; `git status` sin nada nuevo fuera de `cache/`.
2. `rock_hit`, `spell_N` (Rock): `%Battle` `armed` == `"spell"`, `armed_icon` == `"kcor"`, `%CommandCue/%Aim` visible; `aim_body("Druid")` → `CursorSkin.current` == `"Tnme"`; suelo → `"Tntr"`; cielo → `"Tnon"`.
3. `orders_group`: Ctrl+R → `armed_icon` == `"Matt"`; Ctrl+A → `"Mgua"`; `order_menu` ×2 cambia el icono según la orden; clic derecho → `armed` == `""` y `%Aim` oculto.
4. `guardian_manalith`: Manalith armado → `armed_icon` == `"htlm"`; con `aim_body` sobre una criatura, `%Invalid` visible.
5. Rechazo: Rock al suelo → `%Invalid` visible y oculto a los `flash_s` (± 0,1 s); `%Battle` `text` == «Blanco inválido».
6. Auditoría de textos: `f80_hud_text` → `found` == **0** en cuatro casos: `high_noon` en reposo; `rock_hit` con Rock armado; `orders_group` con el menú abierto; `selection_many` con 150 seleccionadas.
7. Regresión del texto de `%Battle`: `f24_cast`, `f27_orders`, `f28_rock`, `f29_spit`, `f63_guardian_manalith`, `f64_teleport`, `pt24_ui`, `polish_spellbar`.
8. Sin caché (`HudIcons` apuntando a una carpeta vacía): el juego corre, `%Aim` usa el respaldo y no hay errores en el log.
9. Dedicado (`run_f78_net.sh` reusado): ninguna llamada a `set_custom_mouse_cursor` ni errores en su log.
10. Capturas lado a lado: cursor, hechizo armado, orden armada y `ncst` contra los PNG del caché ampliados; el usuario juzga a ojo (no hay captura del original con algo armado).

Playtester: `f80_cues`, `f80_hud_text`; capturas `f80_0_idle_cursor`, `f80_1_rock_armed_enemy`, `f80_2_attack_armed`, `f80_3_manalith`, `f80_4_refused`, `f80_5_menu`.

## 8. Riesgos

- **Choques de archivos con otros agentes:** `high_noon.tscn` (RFC-022e, RFC-024), `orders.gd` (RFC-024 `apply_for`), `match_command.gd` (grande, pisadas previas). Mitigación: ventanas de edición cortas, releer antes, no tocar `scenes/world/look/grass/`, `rfcs/research/` ni los archivos de RFC-024.
- **Filas de 12:** extensión, no el original; con muchas unidades puede trabarse en pasos angostos (se mide en 025a.2; `row_size` ajustable).
- **`_match` O(n²) con sort:** a 300 unidades ~90 000 pares (~40 ms estimado en GDScript). El criterio mide 150; si hace falta, agrupar por fila antes de emparejar (local a `orders.gd`).
- **150 barras de vida 3D visibles:** costo de dibujo, se mide en 025a.9; si supera el umbral, RFC aparte con `MultiMesh`.
- **Mapeo de rechazos por texto:** la RPC manda texto en español; si cambia una constante el `CueSet` deja de reconocerla. Mitigación: el `.tres` referencia las mismas constantes y un warning lista los textos sin cue; a futuro, códigos en la RPC.
- **`%Battle` ya no es Label:** un flow que pida `visible` sobre `%Battle` se ignora; revisar los 94 en 025c.7. Nombre conservado a propósito.
- **Tamaño del cursor de hardware:** máximo 256 px; con hudScaling × 32 en 4K ≈ 144 px: cabe; en Retina verificar `screen_get_scale`.
- **AgentKit modificado:** subir el cambio a `godot-studio-skills` o la próxima copia del addon lo pisa.

## 9. Fuera de alcance (otros RFC)
Voz del consejero ante rechazos (`spellAdvisorHelpSpeech`, `sounds.wad`) y sonidos de clic de orden; menú radial completo del xmenu (formaciones, chispas `iglo`) y formaciones distintas de la línea; validez del blanco por `flags` de `SpellType` en el cliente (`isApplicable`); estadísticas del mago como barras del original (`renderStats`); vista previa de la selección mientras se arrastra el rectángulo; minimapa; códigos de estado en lugar de texto en la RPC de `Caster`; `MultiMesh` para las barras si 025a.9 no alcanza.

## 10. Preguntas para el usuario (RESUELTAS 2026-10-14: el usuario aprobó las tres recomendaciones: 1 = (a), 2 = (a), 3 = (a))

1. **Rechazos sin texto** («Sin maná», «Enfriando», «Fuera de alcance»…; el original los dice con la voz del consejero). **(a) Recomendada: destello del icono `ncst` en el cursor** (el libro ya muestra maná y enfriamiento; la voz va en un RFC aparte). (b) Dejar un texto corto solo para los rechazos. (c) Sumar ya la voz del original desde `sounds.wad` (alarga este RFC).
2. **¿Los grupos Ctrl+1…0 y el grupo de convocadas también sin tope?** **(a) Recomendada: sí, el mismo `max_size`.** (b) Mantener 12 en los grupos.
3. **¿Qué textos quedan?** **(a) Recomendada: «Mago · Dios», «Vida/Maná/Almas», «Fantasma», avisos del ritual y resultado** (no son indicadores de blanco; las barras del original van en otro RFC). (b) Sacar también «Fantasma» y los avisos del ritual (habría que decidir con qué se reemplazan).

## 11. Orden de implementación

1. **025a:** assert `prop` de AgentKit → `Selection` (membresía, `clear`, `select_only`, `remove`, `has`, `max_size` 0) → `Orders` (`max_units` 0, filas) → regla 3.2 en `match_command` → `own_tags` y overlay en `orders_group.gd` + `selection_many.tscn` → `selection_probe.gd` → flows f78 y `run_f78_net.sh` → review → playtest → FEATURES (F27 y F78).
2. **025b:** `HudIcons` (y `spell_book` lo usa; `polish_spellbar` pasa) → `RosterCell` → `SelectionRoster` → instancia en `high_noon.tscn` tras `View` → `ability_pressed` → sacar `%Unit` y migrar los 23 flows → f79 → review → playtest → F79.
3. **025c:** `export_icons.py` (correrlo) → `CommandLog` (Battle → Node) → `match_command` con `arm/say` → `CueSet` y `.tres` → `CommandCue` → `CursorSkin` → grupos `hud_text_allowed` → `hud_text_audit` → f80 → review → playtest → F80.

## 12. Verificación humana en el editor (sin tests)

- Abrir `high_noon.tscn`: `Selection.max_size` = 0, `Orders.max_units` = 0, `row_size` = 12; bajo `Hud` el orden es `View`, `SelectionRoster`, `CommandCue`; `Battle` es un `Node` con `command_log.gd`; sin advertencias de sockets. Con `max_size = 12` vuelve el comportamiento clásico.
- `F6` sobre `scenes/ui/selection_roster/selection_roster.tscn`: marco con 12 huecos (con caché) o respaldo.
- `F6` sobre `debug/selection_many.tscn`: rectángulo sobre todas → panel agrupado con 3 celdas (50/50/50) y `sel 150`; clic derecho en el suelo → filas detrás de la primera; clic izquierdo en el suelo → selección vacía y barras apagadas; clic en la pestaña de criaturas → sin cambio.
- `F6` sobre `debug/rock_hit.tscn`: con la tecla de Rock, el icono de Rock pegado al cursor; sobre el Druid, cursor de blanco enemigo; en el suelo, clic → destello `ncst`; ningún texto arriba a la izquierda.
- Abrir `data/ui/command_cues.tres`: cambiar `aim_icons[attack]` a otro tag, `F6` en `orders_group` y Ctrl+R muestra el icono nuevo (el mapeo vive en datos).

## Archivos citados
- Port: `game/scenes/world/{selection,match_command,orders,high_noon}`, `scenes/world/units/unit_health_bar.gd`, `scenes/world/spells/{caster,summoner}.gd`, `scenes/world/spells/actions/{spell_action,manalith_action,guardian_action}.gd`, `scenes/world/units/active_ability.gd`, `scenes/world/wizard/wizard_body.tscn:100-140`, `scenes/ui/{hud,spell_book,spell_slot,ritual_notice}.gd`, `tools/export_icons.py`, `addons/agent_kit/{agent_flow,agent_ops}.gd`, `debug/orders_group.{gd,tscn}`, `agent/flows/f27_orders.json`.
- sacengine: `source/renderer.d:4072-4165, 4194-4213, 4400-4466, 4985-4993, 5306-5344`; `source/sacobject.d:1155-1156, 1945-2110`; `source/xmnu.d`; `source/dagonBackend.d:57-78, 891, 1130-1260, 1930-1945, 2086-2113`; `source/state.d:417-457, 29795, 30143-30150, 30830-30853`; `source/controller.d:176-183`.
- Instalación: `/Users/joelsartori/Downloads/sacgame/Sacrifice/data/{main.wad,xmenu.wad}`. Captura: `game/visual/refs/original/orig_4_manantial.webp`.
