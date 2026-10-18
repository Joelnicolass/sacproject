# RFC-038 — Menú radial de órdenes y formaciones

Estado: plan del tech lead (Opus), pendiente de OK. Arquitectura **estándar**. MP **online con dedicado**: el servidor decide, todo pasa por `Orders.submit_order` (el mismo RPC, con un argumento más; ver P4). Para el plan no se corrió Godot: todo sale de leer el código.
- **Pedido del usuario (2026-10-18, después de una partida contra la IA):** falta un menú radial para dar órdenes y formaciones.
- **Deuda que cierra:** F80 dice que el menú «avance/guardia/retirada» no ejecuta su acción. Causa, leída en `scenes/world/match_command.gd`: `Tab` (`order_menu`) cicla `ORDER_MENU_ORDER` y el clic izquierdo pone `_mode = kind`. Pero `_left_at` solo atiende `"attack"` y `"guard"`. Con `advance`, `guard_area` o `retreat`, el clic cae en la rama de selección y no ordena nada.
- **Autoridad:** pedido del usuario > PRD > FEATURES > RULES (§Fidelidad: Godot estándar primero; §IA: la IA usa el mismo puerto) > VISUAL > este plan.
- **Features:** las asigna el orquestador (una F por corte, desde la siguiente libre después de las de RFC-037).

## 0. Qué hace el original

Fuente: sacengine `source/dagonBackend.d:640-880` (X menu), `975-995` (apertura), `1090-1116` (atajos de formación); `source/xmnu.d`; `source/state.d:397-500` (`getFormationOffsets`) y `29140-29270` (`applyOrder`). Se describe, no se copia (GPL).

- **Apertura:** se **mantiene apretado el botón derecho**. Pasados `xmenuTime` = 15 cuadros a 60 Hz (0,25 s), aparece el «X menu» donde está el puntero. Un toque corto sigue siendo la orden de siempre.
- **Centro (según lo que había bajo el puntero al apretar):** suelo → mover; enemigo → atacar; propio o cadáver → escoltar/guardar; manantial → Manalith; alma roja/verde → Convert.
- **Navegación:** no es un anillo. Es una **cruz** de iconos enlazados por un grafo (`XMNL`: cada entrada tiene vecina arriba/abajo/izquierda/derecha). Se navega moviendo el mouse en esa dirección y se ejecuta **al soltar** el botón. Si se suelta sin entrada, suena «abortar».
- **Entradas (`XmnuTag`):** atacar, escoltar, mover (las tres **arman** el icono para el próximo clic), retirada (inmediata), habilidad, 8 formaciones, «cambiar cámara» (sacengine no la implementa).
- **Formaciones (`Formation`):** línea, flanco izquierdo, flanco derecho, falange (3 filas de 4), semicírculo, círculo, cuña y escaramuza (línea con uno sí y otro no medio paso atrás). La separación es la misma que ya usa `Orders` (`1,25 · tamaño + 0,85`, tope 10). Cada forma tiene su ajuste cuando se escolta a un cuerpo o se ataca.
- **Semántica de la formación:** elegirla **no mueve** a nadie. Guarda la formación en cada criatura seleccionada (`creatureAI.formation`). Cada orden siguiente usa la formación **que más criaturas del grupo tengan**. Por defecto todas tienen línea.
- **Atajos de teclado** para las 8 formaciones (`hotkeys`). **Dudoso:** qué teclas usa el original por defecto; no se busca, el port elige las suyas (P6).
- **Dudoso:** la disposición exacta de la cruz (está en `XMNL` dentro de `xmenu.wad`, que no está exportado). Los iconos de todas las entradas **sí** están en `assets/original/ui/xmenu/` (`tta1`, `aug1`, `vom1`, `zwp1`, `iba1`, `nil1`, `llf1`, `rlf1`, `ahp1`, `mes1`, `ric1`, `jdw1`, `rks1`, y los centros `kcta`, `drug`, `otog`, `htil`, `ccas`, `enon`).

## 1. Diseño en Godot estándar

### 1.1 Formaciones como Resources

`FormationType` (Resource base, `class_name`) con `id: StringName`, `display_name` (español), `icon: Texture2D` (el PNG de `xmenu/`), `match_rows: bool`, y un método `slots(count, spacing, target_half, kind) -> Array[Vector2]` (derecha, adelante en metros, el mismo contrato que hoy devuelve `Orders._formation`).

Tres scripts chicos, uno por familia de forma. Cada `.tres` lleva sus números en el inspector:

| Script | Knobs `@export` | `.tres` |
|---|---|---|
| `RowFormation` | `row_size` (0 = una fila), `anchor` (centro / izquierda / derecha), `stagger` (0 o medio paso atrás de por medio), `guard_flank` (abrir alrededor del escoltado), `guard_back` (m detrás del escoltado) | `line.tres` (centro, `row_size` 12, `guard_flank`; **reproduce exactamente el `_formation` de hoy**), `flank_left.tres`, `flank_right.tres`, `phalanx.tres` (`row_size` 4), `skirmish.tres` (`stagger`) |
| `ArcFormation` | `arc_deg` (180 / 360) | `semicircle.tres`, `circle.tres` |
| `WedgeFormation` | `attack_forward` (sin adelanto al atacar) | `wedge.tres` |

`FormationCatalog` (Resource): `formations: Array[FormationType]` y `default_id = &"line"`. Un solo `data/orders/formations.tres`. **El servidor resuelve el `id` contra el catálogo**: nunca recibe un Resource por la red.

### 1.2 Estado de la formación (servidor)

- `UnitOrders` (`scenes/world/units/unit_orders.gd`) suma `var formation_id: StringName = &"line"`. Es estado de partida: vive en el nodo, no en el `.tres`.
- `Orders` suma `@export var catalog: FormationCatalog`. `_formation` pasa a:
  1. elegir la formación que más tengan las unidades (empates: el orden del catálogo, como el original);
  2. pedirle `slots(...)`.

  `row_size`, `spacing_*` y `max_spacing` siguen siendo knobs de `Orders` y de `line.tres`.
- `_match_rows` solo se usa si `formation.match_rows` y hay más de una fila. Si no, `_match` (greedy, el del original).
- Comando nuevo `"formation"` en `COMMANDS` (no es un `UnitOrders.Command`): `_apply` lo intercepta y pone `formation_id` en las unidades propias. **No mueve a nadie.**
- **IA:** no cambia. Sus unidades quedan en línea. `apply_for` acepta el argumento pero la IA no lo usa (P5). Por eso el banco no se mueve.

### 1.3 Menú radial (cliente)

| Pieza | Qué es | Responsabilidad (una) |
|---|---|---|
| `RadialMenu` (`radial_menu.tscn`, `Control`) | `Center` (icono del centro) + slots instanciados de `radial_slot.tscn` en dos anillos | Mostrar las entradas, resolver qué entrada apunta el puntero (por ángulo y distancia al origen) y emitir `entry_chosen(entry)` o `cancelled`. No conoce órdenes ni red |
| `radial_slot.tscn` | `TextureRect` + resaltado, `StyleBox` guardado en la escena | Un ícono del anillo |
| `RadialEntry` (Resource) | `id`, `label` (español, para el tooltip y `%Battle`), `icon`, `action` (`ARM_ORDER`, `ORDER_NOW`, `FORMATION`, `ABILITY`, `CONTEXT`), `order: StringName`, `formation: FormationType` | Qué hace una entrada |
| `RadialLayout` (Resource, `data/ui/radial/orders_layout.tres`) | `inner: Array[RadialEntry]` (atacar, escoltar, mover, retirada, habilidad), `outer: Array[RadialEntry]` (las 8 formaciones), `inner_radius_px`, `outer_radius_px`, `dead_zone_px`, `hold_s` (0,25) | Qué hay en el menú y su tamaño, todo editable |
| `OrderRadial` (`scenes/world/order_radial.gd`, nodo en `high_noon.tscn`) | Sockets `@export`: `menu: RadialMenu`, `view: Control` (`%View`), `command: MatchCommand`, `orders` | **El único dueño del botón derecho**: toque = `command.right_at(screen)` (lo de hoy), mantener ≥ `hold_s` = abrir el menú; al soltar, ejecutar la entrada |

**Qué hace cada `action`** (llama a métodos públicos de `MatchCommand`, que hoy son privados: `right_at`, `arm_order`, `retreat`, `use_ability`):
- `CONTEXT` (centro): lo mismo que un toque derecho donde se apretó.
- `ARM_ORDER`: `arm_order("attack" | "guard" | "move")`.
  - Atacar o escoltar armados, sobre suelo, dan avance o guardia de zona (ya funciona).
  - **Mover armado es nuevo**: `_left_at` suma la rama `"move"`.
- `ORDER_NOW`: retirada.
- `ABILITY`: la habilidad activa de la selección (`use_ability`).
- `FORMATION`: `Orders.request(units, "formation", ..., formation_id)` y `%Battle.say(display_name)`.

**Entrada (InputMap):**

| Acción | Tecla | Qué hace |
|---|---|---|
| (botón derecho sobre `%View`) | — | Toque o mantener, como el original. Lo atiende `OrderRadial` por `view.gui_input`, no una acción (el clic derecho del mundo hoy tampoco es acción) |
| `order_menu` (ya existe) | `Tab` | **Cambia de significado:** mantener `Tab` abre el radial en el puntero y soltar ejecuta. **Se borra el ciclo `ORDER_MENU_ORDER`** y el modo `"menu"` de `MatchCommand` |
| `formation_1` … `formation_8` | `Alt+1` … `Alt+8` (P6) | Formación directa, sin menú |

- Mientras el menú está abierto, `OrderRadial` ignora `WorldCamera.is_dragging()`. Al soltar, devuelve el puntero a la cámara.
- `WorldInput.blocked` (pausa u opciones) cierra el menú.
- `TargetProbe` suma el `RadialMenu` a `hud_controls`: el cursor cambia sobre él.

### 1.4 Red

- **Un solo RPC, el de hoy:** `submit_order(unit_paths, command, target_pos, target_path, facing, formation_id: StringName)`.
  - El argumento nuevo viaja siempre (`&""` cuando no aplica). Cliente y dedicado son el mismo binario.
  - Para `"formation"`, el servidor valida que el `id` esté en el catálogo; si no, descarta.
- El dueño se valida como hoy (`MpAuthority.command_slot` + `_can_order`): nadie puede cambiar la formación de unidades ajenas.
- `formation_id` **no se replica**. El cliente solo lo necesita para resaltar la formación actual en el menú, y eso queda fuera (P7).
- La retirada sigue siendo `"retreat"` por el mismo camino.

## 2. Árbol de archivos

```text
scenes/world/orders/
├── formation_type.gd          # class_name FormationType (Resource base): id, display_name, icon, match_rows, slots()
├── row_formation.gd           # class_name RowFormation: línea, flancos, falange, escaramuza
├── arc_formation.gd           # class_name ArcFormation: semicírculo, círculo
├── wedge_formation.gd         # class_name WedgeFormation: cuña
└── formation_catalog.gd       # class_name FormationCatalog: lista + default_id + find(id)

data/orders/
├── formations.tres            # FormationCatalog con los 8
└── line.tres  flank_left.tres  flank_right.tres  phalanx.tres  semicircle.tres  circle.tres  wedge.tres  skirmish.tres

scenes/ui/radial/
├── radial_menu.tscn           # Control: Center + Inner + Outer; corre solo con F6 (@tool preview_open)
├── radial_menu.gd             # class_name RadialMenu: open_at, point_at, confirm, cancel; entry_chosen / cancelled
├── radial_slot.tscn           # un icono del anillo con su StyleBox
├── radial_slot.gd
├── radial_entry.gd            # class_name RadialEntry (Resource)
└── radial_layout.gd           # class_name RadialLayout (Resource)

data/ui/radial/
├── orders_layout.tres         # RadialLayout: anillo interior (órdenes) + exterior (formaciones)
└── entry_attack.tres  entry_guard.tres  entry_move.tres  entry_retreat.tres  entry_ability.tres
    entry_line.tres … entry_skirmish.tres   # RadialEntry de formación: apuntan al FormationType

scenes/world/order_radial.gd     # class_name OrderRadial: botón derecho (toque/mantener), Tab, formation_N
scenes/world/orders.gd           # catalog, comando "formation", mayoría, slots() en lugar de _formation; 6.º arg del RPC
scenes/world/units/unit_orders.gd   # + formation_id
scenes/world/match_command.gd    # right_at/arm_order/retreat/use_ability públicos; rama "move" armada; fuera ORDER_MENU_ORDER y modo "menu"; fuera el manejo del botón derecho (pasa a OrderRadial)
scenes/world/high_noon.tscn      # + Hud/RadialMenu, + OrderRadial (sockets), Orders.catalog
data/ui/command_cues.tres        # + aim_icons["move"] = vom1
project.godot                    # + formation_1..8

debug/
├── formation_cases.gd         # headless: slots() de cada .tres contra una tabla escrita a mano desde las fórmulas del original
└── orders_radial.tscn         # heredada de orders_group.tscn: own_count 8, foe_gap_m 60 (mismo script, otros números)

agent/flows/
├── f038_radial_open.json      # mantener derecho, captura, apuntar a cada anillo
├── f038_formation_wedge.json  # elegir Cuña, clic derecho al suelo, posiciones finales
└── f80_cues_orders.json, f80_hud_text.json, rfc033_shots.json   # se actualizan: usaban el ciclo de Tab
agent/harness/formation_probe.gd   # lee formation_id y posiciones de las unidades y las compara con slots()
```

### Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `FormationType` y sus 3 scripts | Calcular los puestos de una forma | Resource | Otra forma con los mismos números = otro `.tres`; otra familia = otro script chico, no un `match` en `Orders` |
| `FormationCatalog` | Resolver `id` → forma, valor por defecto | Resource | El servidor valida contra él; el menú no lo necesita |
| `Orders` (cambio) | Validar y aplicar órdenes en el servidor | Nodo existente | Pierde `_formation`: gana la mayoría y el comando `"formation"` |
| `UnitOrders.formation_id` | Recordar la formación de una criatura | Var de nodo | Es estado de partida, no tipo |
| `RadialMenu` | Mostrar y elegir una entrada | Packed scene | Corre sola con F6; sirve para otro radial (hechizos) sin cambios |
| `RadialEntry` / `RadialLayout` | Qué entradas hay y qué hacen | Resource | Reordenar o quitar entradas sin código |
| `OrderRadial` | Botón derecho (toque/mantener) y traducir entrada → llamada | Nodo | Saca 60+ líneas de `MatchCommand` (682) en vez de sumarle |
| `MatchCommand` (cambio) | Selección, hechizos y órdenes por clic | Nodo existente | Solo expone métodos y pierde el ciclo roto |

### Qué es qué

- **Resource de tipo:** `FormationType` (8 `.tres`), `FormationCatalog`, `RadialEntry`, `RadialLayout`. Ninguno se muta en partida.
- **Nodo:** `RadialMenu`, `radial_slot`, `OrderRadial`, y los que ya existen (`Orders`, `UnitOrders`, `MatchCommand`).
- **`@export` de instancia:**
  - `OrderRadial`: `menu`, `view`, `command`, `orders`, `layout`.
  - `Orders`: `catalog`.
  - `RadialMenu`: `layout`, `hud_scale`, `preview_open` (`@tool`, solo editor).

## 3. Escena de prueba

- **`debug/orders_radial.tscn`:** heredada de `debug/orders_group.tscn` (que instancia `high_noon.tscn`, `unit.tscn` y `debug/rules/orders_group.tres`). Solo cambia `own_count` a 8 y `foe_gap_m` a 60, para que la cuña se vea y el Druid no se meta.
- **Estado inicial:** 8 Trogg propios en un grupo delante del mago, todos en línea (`formation_id = line`), quietos. Druid enemigo lejos.
- **Qué no está todavía:** ninguna formación elegida, nadie se movió.
- **Acciones del playtester:**
  - `check_tick` (selecciona los 8, ya existe);
  - mantener el botón derecho sobre el suelo, apuntar a «Cuña», soltar;
  - clic derecho al suelo;
  - mantener `Tab`, apuntar a «Mover», soltar, clic izquierdo al suelo;
  - mantener el derecho sobre el Druid (centro = atacar).

## 4. Cortes

| Corte | Qué entra | Prueba barata |
|---|---|---|
| **038a** — formaciones como datos | 4 scripts + 8 `.tres` + catálogo. `Orders._formation` llama a `line.tres` (sin comando nuevo) | `debug/formation_cases.gd` headless: los 8 con 1, 5 y 12 unidades y con o sin escoltado, contra la tabla a mano; PASS. `rules_suite` PASS. **`quick` PASS sin regrabar** (la línea es idéntica) |
| **038b** — formación en el servidor | `formation_id`, comando `"formation"`, mayoría, 6.º argumento de `submit_order`, `apply_for` acepta el argumento | Caso headless en `orders_group`: `request(units, "formation", wedge)` y luego `move`; a los 10 s cada Trogg está a ≤ 1 m de su puesto de cuña (`formation_probe`). Caso de rechazo: id desconocido no cambia nada. `run_034e` (dedicado) E2E PASS con un paso de formación. `quick` PASS sin regrabar |
| **038c** — `RadialMenu` sola | Escena, slot, `RadialEntry`, `RadialLayout`, `orders_layout.tres` con los iconos de `xmenu/` | F6 de `radial_menu.tscn` con `preview_open`. Flow sobre la escena: apuntar a 13 ángulos y radios conocidos; los `id` emitidos son los esperados; centro dentro de `dead_zone_px`; captura a 720 y 1080 con `HudScale` 0,8 y 1,2 |
| **038d** — integración | `OrderRadial`, botón derecho tocar/mantener, `Tab`, `formation_N`, «mover» armado, fuera el ciclo y el modo `"menu"`, `aim_icons["move"]` | Flows `f038_radial_open` y `f038_formation_wedge` en `debug/orders_radial.tscn`, AGENT_OK. Toque derecho sigue moviendo (`f27_orders` AGENT_OK). Se actualizan y pasan `f80_cues_orders`, `f80_hud_text` (auditoría 0) y `rfc033_shots` |
| **038e** — cierre | RULES/FEATURES (F80 deja de tener la deuda) | Playtest con ventana, Solo contra la IA (`pt038`): menú, cuña, círculo, retirada desde el menú; AGENT_OK sin errores. `run_determinism.sh all` PASS |

Orden: 038a → 038b → 038c → 038d → 038e. **038c no depende de 038a/b** y puede ir antes si conviene; Godot de a uno, igual. Review: 038b y 038d (cambian red y entrada); 038a y 038c sin review separada (RULES §Fidelidad).

## 5. Riesgos

- **R1 — Botón derecho con dos dueños.** Si `MatchCommand` sigue escuchando el derecho, un toque largo abre el menú **y** ordena. Por eso el derecho pasa entero a `OrderRadial` en 038d (un dueño, no un parche de orden).
- **R2 — Formas grandes.** El original corta a 12 por grupo. El port no tiene tope: una cuña o un círculo con 150 criaturas son enormes y pueden caer en barrancos. `EdgeClamp` y el navmesh ya recortan el destino; se mira en el playtest de 038e. Si molesta, cada `.tres` suma un `max_units` y el resto va en línea detrás.
- **R3 — Flows viejos con `Tab`.** `f80_cues_orders`, `f80_hud_text` y `rfc033_shots` usan el ciclo que se borra. Se actualizan en 038d, no se dejan rotos.
- **R4 — Firma del RPC.** Agregar el argumento cambia la firma. Cliente y dedicado de builds distintos no se entienden, pero eso ya pasa con cualquier cambio de RPC (mismo binario por regla del PRD).

## 6. Fuera de alcance

- Que la IA use formaciones.
- El centro «Manalith» y «Convert» del menú: quedan como hoy, con el hechizo desde el libro.
- «Cambiar cámara».
- Encolar órdenes con `Shift`.
- Sonidos del menú (`unmx`, `kabI`): no hay audio original en el primer corte (PRD).
- Mostrar la formación actual en el menú (P7).

## 7. Cómo verifica un humano en el editor

1. Abrir `data/orders/wedge.tres`: se ven los knobs; cambiar `attack_forward` y correr `debug/orders_radial.tscn` (F6).
2. Abrir `scenes/ui/radial/radial_menu.tscn`: con `preview_open` el menú se ve en el editor; F6 lo abre en el centro.
3. Abrir `data/ui/radial/orders_layout.tres`: quitar «Habilidad» del anillo interior y correr: ya no aparece.
4. En `debug/orders_radial.tscn` (F6): `check_tick`, mantener el derecho, «Cuña», soltar, clic derecho al suelo. Los 8 Trogg forman una V. Toque derecho corto: mueven como siempre, y siguen en cuña (la formación quedó guardada).

## 8. Preguntas abiertas

- **P1 — ¿Cómo se abre?** **Recomendación:** como el original, mantener el derecho 0,25 s (`hold_s` en el `.tres`), con el toque corto igual que hoy. Además, `Tab` mantenido para quien use teclado.
- **P2 — ¿Cruz del original o anillo?** La cruz del original sale de un grafo que no está exportado y se navega por direcciones. **Recomendación:** dos anillos estándar (órdenes adentro, formaciones afuera), elegidos por ángulo, con los iconos del original. Es más fácil de usar y de editar. Copiar la cruz no es algo que el jugador note más allá de los iconos.
- **P3 — ¿La formación queda guardada en la criatura o va con cada orden?** **Recomendación:** guardada en la criatura, en el servidor, como el original. Elegirla no mueve; la orden siguiente usa la de la mayoría.
- **P4 — ¿Argumento nuevo en `submit_order` o codificar la formación en un campo existente?** **Recomendación:** argumento nuevo `formation_id: StringName`, mismo RPC. Meter el `id` en `target_path` o en `command` sería un parche difícil de leer.
- **P5 — ¿La IA usa formaciones?** **Recomendación:** no en este RFC. La IA porta `shiny.d` y queda en línea, así que el banco no se mueve. Se puede sumar después por el mismo `apply_for` (RULES §IA).
- **P6 — ¿Atajos de formación?** **Recomendación:** `Alt+1` … `Alt+8`, editables en el InputMap. Hoy `1`–`0` son grupos y `Ctrl+1`… define grupos. No se buscan las teclas del original.
- **P7 — ¿Resaltar en el menú la formación actual?** Haría falta replicar `formation_id`. **Recomendación:** no por ahora. `%Battle` dice el nombre de la formación al elegirla.

## Decisión 2026-10-18 (orquestador, cola delegada)

Se aplican las recomendaciones de todas las preguntas. El usuario puede revisarlas al volver; la más visible es P1 de 037: el clic en el minimapa no mueve la cámara, como en el original.
