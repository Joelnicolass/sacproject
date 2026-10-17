# 031-R — El menú de opciones del Sacrifice original

Investigación de RFC-031 (sección 031-R). No incluye código de juego. Se comparan los FORM del original con lo que el port implementó en 031c (Opciones → Gráficos) y 031d (Jugabilidad).

**Etiquetas de fuente**
- **[WAD]:** leído de `~/Downloads/sacgame/Sacrifice/data/menus.wad` (`MENU.WAD!/*.FORM`). Los textos salen de `data/local/lang_english.wad` (`ENGL.LANG/menu.FLDR` para las etiquetas y `hlpt.FLDR` para la ayuda al pasar el mouse) y de `langp3_english.wad` (`addl.LANG`). El formato es el de `sacengine/source/form.d` (cabecera de 49 bytes y elementos de 88) y el del lector de WAD de `wadmanager.d`.
- **[EXE]:** bytes de `Sacrifice.exe`, leídos a mano. La tabla de configuración está en el offset de archivo `0xc8db8`–`0xc9258` (`.data`), en registros de 32 bytes: `tag, nombre*, tipo, flag, var*, default, min, max`. La tabla de atajos está en `0xc9380`. Para encontrarlas se buscaron los tags crudos y los strings. No se abrió Ghidra.
- **[SAC archivo:línea]:** sacengine.
- **[DOC]:** `MANUAL.PDF` (texto extraído con PDFKit) y `ReadMe.txt`.

Los tags se escriben como los nombres de archivo del WAD (`opts`, `gopt`…). sacengine guarda los mismos tags con los bytes invertidos (`stpo`, `tpog`…), como en `renderer.d:5643`.

---

## 1. Resumen

1. **`UNEM` no es un FORM.** Es el id del comando de atajo «Options Menu» (`hotkeys_.d:34`). En el exe, ese comando apunta al FORM **`gmnu`**, el menú de pausa: el par de dwords `MENU`→`gmnu` está en `0xc9380` [EXE]. Se abre con **Esc** («Menu Esc», `ReadMe.txt:146`; «The pause menu is called up when the escape key is pressed», MANUAL §E) [DOC].
2. **Hay dos árboles de opciones:**
   - **Desde el título** (`titl` → «Options»): `opts`, una pantalla de 640×480 con una botonera vertical a la izquierda y un panel de 480×480 a la derecha. El panel cambia entre `gopt` (Gráficos), `sopt` (Sonido), `kopt` (Teclado), `copt` (Misceláneas) y `cmpt` (Información del sistema).
   - **En partida** (`gmnu` → «Options»): `igop`, un diálogo compacto centrado de 480×352 con lo más usado (sonido, mouse y XMenu). Tiene dos botones a sub-diálogos, `iggo` (Gráficos reducido) e `ikop` (Teclado), y «OK».
3. **El fuego amigo estaba en dos lugares:**
   - Como preferencia local, en *Miscellaneous* (`copt/ffir`).
   - Como regla de la partida, en *Game Settings* (`cgam/ffir`), junto con el slider *Friendly Damage* (`fdam`). `fdam` vale 64/128 = **0,5** por defecto (0..128) [EXE], el mismo factor que el port.
   - Las almas iniciales (`nspr`) también son de `cgam`, no de Opciones.
4. **Comparación con el port:**
   - Gráficos y Jugabilidad cubren una parte chica del original.
   - Faltan Sonido, Teclado, casi todo Misceláneas, gamma, el framerate objetivo y la pausa con Objetivos, Historial, Guardar y Cargar.
   - **Sobran** pantalla completa, VSync, límite de FPS, tamaño del HUD y el preset de calidad. Son modernos y razonables, y conviene quedarse con ellos.
   - También sobra «Soltar almas con P»: no es opción del original, es una extensión de sacengine (`options.d:107 enableDropSoul`).
   - La estructura difiere: el port usa pestañas en un overlay único, y el original, una botonera lateral y paneles.

---

## 2. Cómo se llega a cada menú

```text
titl (640×480, pantalla de título)
 ├─ g_1p  Single Player
 ├─ g_mp  Multiplayer
 ├─ lgam  Load Game
 ├─ opts  Options ───────────────► FORM opts (pantalla completa, 640×480)
 └─ quit  Quit

Esc en partida (atajo «MENU»/UNEM) ─► FORM gmnu (208×208, centrado, sin título)
 ├─ vobj  Mission Objectives
 ├─ hist  Speech History
 ├─ sgam  Save Game
 ├─ lgam  Load Game
 ├─ opts  Options ─────────────► FORM igop (480×352, centrado, «Options»)
 │                                ├─ ikop → FORM ikop (Keyboard Options)
 │                                └─ igop → FORM iggo (Graphics Options)
 ├─ surr  Surrender  /  exit Finished   (misma posición; se muestra uno u otro)
 └─ cncl  Resume Game  (default y Esc)

Lobby multijugador ─► «Game Settings» ─► FORM cgam (reglas de la partida)
```
[WAD; DOC MANUAL §E y lobby]

---

## 3. Árbol de FORM con ids y textos [WAD]

Notación: `tipo id «texto»` (ayuda entre paréntesis cuando existe) @ (x, y) ancho×alto, en píxeles de 640×480.
- Los sliders son un sub-FORM genérico, `SLID` de 432×16 o `slid` de 208×16, con tres partes: `name` (etiqueta), `slid` (barra) y `numb` (valor). El texto de la plantilla dice siempre «Double Click Speed».
- El rótulo real sale del texto cuyo tag coincide con el id del contenedor. Por ejemplo, `ctr!` es «Character Texture Resolution». Es una inferencia: los textos existen con esos tags, pero sacengine no hace el reemplazo.

### 3.1 `opts` — Options (640×480, sin título; default `gopt`, Esc `menu`)
Botonera izquierda de 160 de ancho, botones cada 32 px:

| id | Texto | Ayuda | y |
|---|---|---|---|
| `gopt` | Graphics Options | Change graphics options | 128 |
| `sopt` | Sound Options | Change sound options | 160 |
| `kopt` | Keyboard Options | Change keyboard options | 192 |
| `copt` | Miscellaneous | Change miscellaneous options | 224 |
| `cmpt` | System Information | View system information | 256 |
| `dflt` | Redetect defaults | Click here to redetect the default settings for your machine. | 368 |
| `menu` | Main Menu | Return to main menu | 400 |

A la derecha, en (160,0), cinco sub-FORM de 480×480 superpuestos (`GOPT`, `SOPT`, `KOPT`, `COPT`, `CMPT`). Se ve uno por vez. Todos tienen título, borde y fondo. `dflt` abre el diálogo `dflt` «Redetect defaults» (OK / Cancel, 336×96).

### 3.2 `gopt` — Graphics Options (480×480)
| Tipo | id | Texto | Ayuda / valores |
|---|---|---|---|
| lista | `resn` | Resolution | List of available resolutions (144×208, columna izquierda) |
| check | `dmap` | Use Detail Textures | Use detail textures. |
| check | `bmap` | Use Bump Detail Maps | — |
| check | `lmap` | Use Light Maps | Use light maps. |
| check | `mtex` | Use Multitexture | Enable multi-texturing |
| check | `fsaa` | Full Scene Antialias | — |
| check | `tbuf` | Triple Buffering | Enable triple buffering |
| check | `widj` | Widgets | Draw widgets |
| check | `bscr` | Blood Stains | Draw blood stains |
| check | `xscr` | Explosion Scars | Draw explosion scars |
| check | `-fog` | Disable Fogging | Turns off fogging in game |
| check | `strp` | Disable triangle strips | Turns off triangle strips (slower, but works with older video cards). |
| slider | `ctr!` | Character Texture Resolution | Resolution for texture maps on characters |
| slider | `mscr` | Max Scars | Maximum number of scars to be drawn on landscape |
| slider | `rate` | Target Framerate | Desired framerate in frames per second |
| slider | `gama` | Gamma Correction | Gamma correction (brightness) |
| ciclo | `tfil` | Texture Filter Mode | Point / Bilinear / Trilinear (`tf_0..2`) |
| ciclo | `tres` | Texture resolution | High / Medium / Low / Very low (`tr_0..3`) |
| ciclo | `gdet` | Detail level | Insane / Very high / High / Normal / Medium / Low / Very low / Lowest (`gd_0..7`) |

- **Layout:** lista de resoluciones a la izquierda, 11 checks a la derecha (cada 20 px), 4 sliders a lo ancho debajo y 3 filas «etiqueta + botón que cicla» al pie.
- **Ciclos:** el «botón que cicla» es un botón cuyo texto es el valor actual. Cada clic pasa al siguiente.

### 3.3 `sopt` — Sound Options (480×480)
| Tipo | id | Texto | Ayuda / valores |
|---|---|---|---|
| caja texto | `prov` | Current 3D Provider | (driver en uso) |
| botón | `cprv` | Change 3D Provider | — |
| slider | `smpv` | Sound Volume | Sound effects volume level |
| slider | `strv` | Music Volume | Music volume level |
| ciclo | `spek` | Speaker Setup | 2 Speakers / Headphones / Surround / 4 Speakers (`spk0..3`); «Choose your speaker configuration» |
| check | `dmus` | Disable Music | Disables Music Streaming (can help performance) |
| check | `nadv` | Disable Advisor Help Speech | — |

### 3.4 `kopt` — Keyboard Options (480×480)
| Tipo | id | Texto | Ayuda |
|---|---|---|---|
| lista | `keym` | Control Keys | (movimiento; 352×96) |
| lista | `keyo` | Command Bindings | (todo lo demás; 352×268) |
| botón | `key+` | Add New Binding | Add new control binding |
| botón | `keyr` | Reset To Default | Reset key bindings to default configuration |

### 3.5 `copt` — Miscellaneous (480×480)
| Tipo | id | Texto | Ayuda |
|---|---|---|---|
| slider | `dblc` | Double Click Speed | — |
| slider | `xmnu` | XMenu Time | Delay before cross menu comes up |
| slider | `krst` | Key Repeat Start Delay | Delay before key repeat begins |
| slider | `krdl` | Key Repeat Delay | Delay between key repeats |
| slider | `mspd` | Mouse Speed | Mouse movement speed |
| check | `wscx` | Window Scroll - X | Scroll view when mouse moves off screen to the right or left |
| check | `wscy` | Window Scroll - Y | Scroll view when mouse moves off screen to the top or bottom |
| check | `mwzm` | Mouse Wheel Zoom | Zoom in/out with mouse wheel |
| check | `wdrx` | Reverse drag X | Click to reverse view dragging left/right axis. |
| check | `wdry` | Reverse drag Y | Click to reverse view dragging up/down axis. |
| check | `swap` | Swap mouse buttons | — |
| check | `ffir` | Friendly Fire | Enable friendly fire |
| check | `tipo` | Show gameplay tips | Show gameplay tips |
| check | `rdem` | Allow demo mode | — |
| botón | `cdky` | Enter your CD key | — |

Layout: 5 sliders arriba y dos columnas de checks (mouse y cámara a la izquierda; Friendly Fire, Tips y Demo a la derecha).

### 3.6 `cmpt` — System Information (480×480)
- `sysi`: caja «System Information».
- `cmpl`: caja «Compatibility».
- `afix`: botón «Attempt To Auto-Fix».

### 3.7 En partida
- **`gmnu`** (208×208, centrado, borde sin título; default y Esc = `cncl`). Botones de 160 de ancho, cada 24 px: Mission Objectives, Speech History, Save Game, Load Game, Options, Surrender o Finished, y Resume Game.
- **`igop` «Options»** (480×352, centrado; default y Esc = `opok`).
  - Columna izquierda, 8 checks: `dmus`, `nadv`, `wscx`, `wscy`, `mwzm`, `wdrx`, `wdry`, `swap`.
  - Columna derecha, 5 sliders cortos (`slid` 208×16): `smpv` Sound Volume, `strv` Music Volume, `dblc`, `xmnu` y `mspd`.
  - Al pie, tres botones apilados: «Keyboard Options» (`ikop`), «Graphics Options» (`igop` → FORM `iggo`) y «OK».
- **`iggo` «Graphics Options»** (480×208; default y Esc = `gook`).
  - Checks: `dmap`, `bmap`, `lmap`, `mtex`, `fsaa`, `-fog`, `strp`.
  - Sliders: `rate` y `gama`.
  - Ciclos: `tfil` y `gdet`.
  - Botón «OK».
  - No tiene resolución, widgets, scars, triple buffer, `ctr!` ni `tres`: lo que exige reiniciar o recargar queda fuera de la partida.
- **`ikop` «Keyboard Options»:** igual a `kopt`, con «OK».
- **`qgam` «Quit»** (OK / Cancel) y `surr` «Surrender» son confirmaciones chicas de 336×96.

### 3.8 `cgam` — Game Settings (lobby, 480×432) — las reglas de la partida
- Mapa (`_map` + lista `maps`).
- `gtyp`: Game Type, más el parámetro `GT##`.
- Checks:
  - `rplc` Random Altar
  - `obs+` Observers
  - `obsc` Observer chat
  - `cust` Custom spellbooks
  - `avis` Allied vision
  - `aspr` Collect Allied Souls
  - **`ffir` Friendly Fire**
  - `agib` Always Gib
  - `nocr` No map creatures
  - `nobs` No map souls
  - `rvbs` Reveal blue souls
- Sliders:
  - **`nspr` Starting Souls** («Number of souls each side starts with»)
  - `lmin` Minimum Level
  - `lmax` Maximum Level
  - `gibc` Gib Chance
  - `xprt` XP Rate
  - **`fdam` Friendly Damage** («Friendly damage multiplier»)
  - `aidm` AI damage multiplier
- Botones OK y Cancel.

### 3.9 Otros FORM de opciones que no cuelgan de `opts`
`nopt` «Network Options» (Traffic Graph, Internet Simulator y 5 sliders de latencia) existe en el WAD, pero ningún botón de `opts` lo abre. Parece de depuración.

---

## 4. Variables que guarda el original [EXE]

Esta es la tabla de configuración del exe: qué se persiste y con qué valores por defecto y rangos.

| Tag | Nombre interno | Default | Rango | Nota |
|---|---|---|---|---|
| `mspd` | Mouse speed | 32 | 16–128 | |
| `ctr!` | Character texture detail | 7 | 5–9 | probablemente log2 (128–512 px) |
| `texr` | Texture detail | 0 | 0–3 | `tres` del menú |
| `gdet` | Graphic detail | 3 (Normal) | 0–7 | |
| `gfxo` | General graphics options | 0 | máscara | probable: dmap/bmap/lmap/mtex/fsaa/-fog/strp (inferencia) |
| `mscr` | Number of scars | 256 | 32–256 | |
| `scrf` | Types of scars allowed | 3 | máscara | probable: sangre + explosión (inferencia) |
| `land` | Landscape drawing modes | 120 | máscara | |
| `rate` | Target framerate | **20** | 10–30 | el manual recomienda 20 y aclara que no es un tope |
| `ffir` | Friendly fire | **1** | 0–1 | coincide con `options.d:98` |
| `fdam` | Friendly damage multiplier (x128) | **64** | 0–128 | 0,5 |
| `tipo` | Show gameplay tips | 1 | 0–1 | |
| `rdem` | Demo mode | 1 | 0–1 | |
| `swap` | Swap mouse buttons | 0 | 0–1 | |
| `dblc` | Double click time | 20 | 10–60 | |
| `xmnu` | Cross menu time | 15 | 0–60 | |
| `ctrl` | Control options | 7 | máscara | probable: wscx/wscy/mwzm encendidos (inferencia) |
| `gama` | Gamma correction (*1000) | 1300 | 1000–2000 | |
| `tbuf` | Triple buffering | 0 | 0–1 | |
| `tfil` | Texture filter | 1 (Bilinear) | 0–2 | |
| `widj` | Draw widgets | 1 | 0–1 | |
| `gfx!` / `snd!` / `sprv` | Renderer DLL / Sound Library / Sound Provider | `3d_d3d.dll` / `sound.dll` / «DirectSound3D 7+ Software - Pan and Volume» | — | |
| `resn` | Resolution | — | — | |
| `smpv` / `strv` | Sound FX / Music Volume | 100 / 100 | 0–100 | |
| `dmus` / `nadv` | Disable Music / No Advisor VO | 0 / 0 | 0–1 | |
| `spek` | Speaker Setup | 0 (2 Speakers) | 0–3 | |
| `krst` / `krdl` | Key repeat start / delay | 50 / 10 | 0–100 / 5–20 | |

Además: `pnam` (Player name, «Eldred» por defecto), `ipad`, `ckey`, `trun` (# Times Run) y `comp` (lista de compatibilidad ignorada).

---

## 5. Original contra port

Port: `game/scenes/ui/options/`.
- `options_menu.tscn` es un overlay con título «Opciones», un `TabContainer` y el botón «Cerrar».
- `graphics_tab.tscn` (031c): Calidad, Pantalla completa, VSync, Límite de FPS y Tamaño del HUD.
- `gameplay_tab.tscn` (031d): Fuego amigo, Soltar almas con P y Almas iniciales; en partida es de solo lectura.
- Se abre desde el boot y desde `pause_menu` (Continuar / Opciones / Salir al menú).

Estado: **tiene** = el port cubre la intención; **parcial** = cubre algo con otra forma; **falta**; **sobra** = el port lo tiene y el original no; **n/a** = no aplica a un port moderno.

### 5.1 Gráficos
| Original | Port | Estado | Nota |
|---|---|---|---|
| `gdet` Detail level (8 niveles) | Calidad (Baja / Media / Alta, `LookQuality`) | parcial | Es el mismo concepto, un preset global. El port tiene 3 niveles. |
| `tres` Texture resolution | dentro del preset | parcial | |
| `ctr!` Character Texture Resolution | — | n/a | memoria de video del 2000 |
| `tfil` Texture Filter | dentro del preset (si aplica) | parcial | |
| `widj` Widgets (pasto, matas) | dentro del preset (densidad de pasto) | parcial | Candidato a check propio: el manual lo presenta como el corte de rendimiento más visible. |
| `bscr` / `xscr` Blood Stains / Explosion Scars, `mscr` Max Scars | — | falta | Solo si el port pinta marcas en el suelo. |
| `-fog` Disable Fogging | — | falta | La niebla del ambiente existe en el look. |
| `rate` Target Framerate (LOD adaptativo) | Límite de FPS | parcial | No es lo mismo: el original ajustaba el detalle para llegar a 20 fps; el port pone un tope. |
| `gama` Gamma Correction | — | **falta** | La RFC lo deja fuera de alcance. Es barato: un ajuste del `Environment` o de post. |
| `resn` Resolution | Pantalla completa | parcial | El port usa ventana o pantalla completa con la resolución nativa. |
| `tbuf` Triple Buffering | VSync | parcial | equivalente moderno |
| `dmap` `bmap` `lmap` `mtex` `fsaa` `strp` | — | n/a | Flags de Direct3D 7; si hace falta, el AA va dentro del preset. |
| — | Tamaño del HUD | **sobra** | útil en Retina; conservar |
| `dflt` Redetect defaults | — | falta | Podría ser «Restablecer» por pestaña. |
| `cmpt` System Information / Auto-Fix | — | n/a | |

### 5.2 Sonido (`sopt`)
| Original | Port | Estado |
|---|---|---|
| `smpv` Sound Volume | — | **falta** |
| `strv` Music Volume | — | **falta** |
| `dmus` Disable Music | — | falta (cae en Music Volume = 0) |
| `nadv` Disable Advisor Help Speech | — | falta (solo si hay voces del consejero) |
| `spek` Speaker Setup, `prov` / `cprv` 3D Provider | — | n/a (lo resuelve el SO) |

### 5.3 Teclado (`kopt`)
| Original | Port | Estado |
|---|---|---|
| `keym` Control Keys, `keyo` Command Bindings, `key+`, `keyr` | — | **falta** (la RFC deja el remapeo fuera de alcance; InputMap ya existe) |

### 5.4 Misceláneas (`copt`) y jugabilidad
| Original | Port | Estado | Nota |
|---|---|---|---|
| `ffir` Friendly Fire (preferencia local, default 1) | Fuego amigo (preferencia para la próxima partida que crea el jugador) | **tiene** | Default `true` en ambos. |
| `cgam/ffir` + `fdam` Friendly Damage (regla de la partida, 0,5) | `MatchRules.friendly_fire` + `ally_damage_factor` 0,5 en el `.tres`; la pestaña es de solo lectura en partida | parcial | El factor no se edita desde el menú. En el original era un slider del host. |
| `cgam/nspr` Starting Souls | Almas iniciales | **tiene** | En el original era regla del lobby, no una opción. |
| — | Soltar almas con P | **sobra** | Extensión de sacengine (`options.d:107`); en el original soltar alma es solo un atajo. |
| `mspd` Mouse Speed, `dblc` Double Click, `xmnu` XMenu Time | — | falta | `xmnu` importa si el port tiene el menú cruzado. |
| `wscx` / `wscy` Window Scroll, `mwzm` Wheel Zoom, `wdrx` / `wdry` Reverse drag, `swap` | — | falta | Opciones de cámara y mouse baratas y útiles. |
| `krst` / `krdl` Key repeat | — | n/a | |
| `tipo` Show gameplay tips | — | falta (solo si hay tips) | |
| `rdem` Allow demo mode, `cdky` CD key | — | n/a | |

### 5.5 Menú de pausa (`gmnu`)
| Original | Port (`pause_menu`) | Estado |
|---|---|---|
| Resume Game (default y Esc) | Continuar | tiene |
| Options → `igop` | Opciones → el mismo overlay del boot | parcial: el original usa un diálogo reducido |
| Surrender / Finished | Salir al menú (con confirmación) | parcial |
| Mission Objectives, Speech History | — | n/a por ahora (no hay campaña) |
| Save Game, Load Game | — | n/a por ahora |
| Pausa en un jugador | `get_tree().paused` solo; en red no pausa | tiene (el manual dice que pausar congela el juego) |

### 5.6 Estructura
| Original | Port | Estado |
|---|---|---|
| Pantalla completa 640×480 con botonera vertical a la izquierda y panel de 480×480 a la derecha | Overlay con `TabContainer` horizontal | difiere |
| Cada panel con título propio («Graphics Options») | Título único «Opciones» + nombre de la pestaña | difiere |
| Sliders con etiqueta a la izquierda, barra y número a la derecha | HSlider + etiqueta de valor (solo HUD) | tiene |
| Valores discretos como botón que cicla (Point → Bilinear → …) | OptionButton (desplegable) | difiere |
| Ayuda al pasar el mouse (`hlpt`) para casi todo | — | falta |
| En partida: diálogo compacto con lo frecuente + OK | El mismo overlay completo | difiere |
| Default y Esc declarados por FORM | Esc cierra (`pause_menu`) | tiene |

---

## 6. Recomendación de look y estructura

### Estructura (lo que conviene tomar)
1. **Botonera lateral en vez de pestañas.** A la izquierda, en orden: Gráficos, Sonido, Controles, Jugabilidad y, separado abajo, «Restablecer» y «Volver».
   - El panel de la derecha lleva el título de la sección, como `opts` (botones cada 32 px a 160 de ancho y panel de 480 en 640).
   - Se puede hacer con el mismo `TabContainer` con las pestañas ocultas y una columna de botones, así AgentKit sigue igual.
2. **En partida, un diálogo reducido**, como `igop`:
   - volúmenes, opciones de mouse y cámara, gamma
   - botones a «Gráficos» y «Controles»
   - «OK»

   Lo que exige recargar (preset de calidad) puede quedar en el diálogo completo, como hacía el original con resolución y texturas.
3. **Jugabilidad = reglas del lobby, no opciones.** En el original, fuego amigo con *Friendly Damage*, almas iniciales, niveles mínimo y máximo y XP Rate están en *Game Settings* (`cgam`), que define el host al crear la partida.
   - El port ya trata esas preferencias como «lo que vale para la próxima partida que creo» y las muestra de solo lectura en partida, que es el comportamiento de `cgam`.
   - Recomendación: cuando exista una pantalla de creación de partida (o el boot «Contra la IA»), mover ahí la pestaña con el nombre «Reglas de la partida». En Opciones queda como mucho el `ffir` local, el que en el original vive en *Miscellaneous*.
   - «Soltar almas con P» va en Reglas, marcada como extensión (no es del original).
4. **Próximas opciones, en orden de valor por costo:**
   1. Volumen de efectos y de música (`smpv`, `strv`; 0–100, default 100).
   2. Gamma (`gama`; 1,0–2,0, default 1,3).
   3. Opciones de cámara: scroll en el borde X/Y, zoom con la rueda, invertir arrastre X/Y y velocidad del mouse.
   4. Check «Pasto y detalles» (`widj`) separado del preset.
   5. Remapeo de teclas.

### Look
- **Marco:** paneles con el marco del original.
  - Textura de fondo `FMbg`, en mosaico de 32 px.
  - Borde `FMbo` de 16 px con esquinas de 32 (activa e inactiva en la misma textura).
  - Barra de título `FMtb` de 16 px.
  - Las texturas están en `interfac.wad`, `ifac.WAD!/form.FLDR`, con paletas `FP*.PALT`, y la geometría en `sacform.d:126-267`. Son 32×32 o 64×64 con paleta: se escalan con filtro *nearest* o se repintan al doble.
- **Botones:** `FBbg` normal, `FBbb` resaltado en azul. Checks y sliders: `FSbg`. Listas: `FLbg` y `FLbo`.
- **Fuentes:** `fn12` para títulos grandes, `fn08` para títulos chicos y `fnwt` para el texto (`sacform.d:47-60`). Si no se portan, una serif clara en blanco cálido sobre el fondo oscuro del marco.
- **Proporciones:** rejilla base de 640×480 escalada a la ventana, con el `HudScale` actual como multiplicador. Los paneles van centrados, salvo la pantalla de Opciones del título, que ocupa todo.
- **Ayuda por elemento:** usar los textos `hlpt` como tooltip o como una línea de ayuda al pie del panel.
- **Esto toca el look del menú:** según la decisión 11 de la RFC y `VISUAL.md`, hace falta el OK del usuario antes de implementar. Esto es una propuesta.

---

## 7. Lo que no se verificó
- Qué bits de `gfxo`, `scrf`, `land` y `ctrl` corresponden a cada check. Se infiere por el nombre; no se decompiló el código que los lee.
- El reemplazo del rótulo «Double Click Speed» por el texto del id del contenedor ocurre en el exe, no en sacengine. Inferencia por la existencia de los textos.
- Que `rate` sea un objetivo de LOD y no un tope sale solo del manual («Setting at 20 fps does not limit performance to 20 fps»).
- Si el `copt/ffir` local afecta el single player y `cgam/ffir` el multijugador, o si comparten la variable. La tabla de configuración tiene una sola `ffir`, así que lo probable es que `cgam` la inicialice.

### Cómo se reprodujo
- Un lector de WAD de ~30 líneas en Python que sigue `wadmanager.d:57-150`: directorio comprimido con zlib en `infoOff`, registros de 28 bytes y tipo 0/1/2.
- Un volcador de FORM que sigue `form.d`: cabecera de 49 bytes y elementos de 88.
- Un recorrido de la tabla del exe buscando `tag` imprimible + puntero a string.
- Los scripts quedaron fuera del repo, en el scratchpad de la sesión. Si se quiere repetir la investigación, conviene llevarlos a `game/tools/`.
