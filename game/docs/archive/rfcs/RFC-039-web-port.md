# RFC-039 — Port web (cliente en el navegador, red por WebSocket)

Estado: propuesto (2026-10-18). Pedido del usuario: «el port web, con ws. Deberíamos pensar en reducir efectos y tamaño de modelos para hacerlo liviano.»

## 0. Conflictos con artefactos de mayor autoridad

- **PRD §Fuera del primer corte** dice «export web», y **PRD** abre con «Juego de escritorio». **RFC-034 §Fuera de alcance** dice «Export web y WebSocket» (034n ya hizo WS). El PRD gana: este RFC **no arranca** hasta editar el PRD (§9). El pedido explícito del usuario es la decisión que habilita el cambio.
- **RULES §Red** («El host LAN no es el camino de internet») y **§Fidelidad** no chocan: el cliente web solo pinta en online, y en solo simula como hoy el proceso solo.
- Memoria «Conservar el cielo original»: el preset web puede bajar el costo del cielo, pero no cambia su look (sin nubes nuevas, sin saturar).

## 1. Objetivo (criterios de aceptación)

1. Un export web (`web`) arranca en Chrome/Firefox de escritorio, muestra el menú y juega **Contra la IA** completo en el navegador. La simulación corre en la pestaña, igual que `play_solo()` hoy.
2. El cliente web entra a una sala del servidor de salas y juega un 1v1 contra el dedicado por **WebSocket** (`ws://` en local, `wss://` en el VPS), con la misma API de MpKit.
3. «Servidor local» no aparece en web. En su lugar se ve un aviso corto.
4. El preset de calidad `web` y el achique de texturas solo se aplican al export web. Los presets y el export de escritorio quedan **idénticos** a hoy.
5. Hay metas medibles: tamaño de descarga, FPS en una laptop media, memoria y tiempo hasta el menú. Se miden con `?probe=1`, sin depender del ojo.

## 2. Objetivo técnico y restricciones

### 2.1 Godot 4.7 Web

| Tema | Qué implica | Decisión propuesta |
|---|---|---|
| Renderer | En web solo existe **Compatibility** (GLES3 → WebGL2). Forward+ no. | `rendering/renderer/rendering_method.web="gl_compatibility"` explícito en `project.godot`. Escritorio sigue en Forward+. |
| Threads | Con threads hace falta `SharedArrayBuffer`, que pide los headers `Cross-Origin-Opener-Policy: same-origin` y `Cross-Origin-Embedder-Policy: require-corp`. Sin threads no hace falta nada. | **Sin threads** (`variant/thread_support=false`). Ver P1. |
| Memoria | wasm32: el heap tope es 4 GB y en la práctica una pestaña sufre arriba de ~2 GB. Hoy 987 de 999 texturas se importan **sin pérdida** (`compress/mode=0`), así que en VRAM ocupan RGBA8 sin comprimir. | Meta: `Performance.MEMORY_STATIC` ≤ 1 GB y pestaña ≤ 1,5 GB (039e). |
| Tamaño | El `.pck` del dedicado hoy pesa **247 MB** (F184). itch.io limita cada archivo a 200 MB. El `.wasm` del template ronda las decenas de MB y comprime bien con brotli. | Metas en §6. |
| Audio | Hoy no hay audio (0 `.ogg`/`.wav`; el audio original está fuera de alcance). | Nada en este RFC. Cuando llegue: Ogg Vorbis para música y loops, WAV corto para SFX. En web el `AudioContext` arranca tras el primer clic, y Godot lo maneja. |
| Entrada | El navegador no confina el mouse (`MOUSE_MODE_CONFINED`): el scroll por borde de `world_camera.gd` falla si el puntero sale del canvas. Algunos atajos chocan con el navegador (Ctrl+W, F5, Ctrl+número). | Pantalla completa con el botón del juego (necesita un gesto del usuario). Revisar el InputMap contra los atajos del navegador en 039c. |
| Args | En web no hay `OS.get_cmdline_user_args()`. | `MpBoot` lee la query de la URL (`?lobby=…&probe=1`) en web (§3.1). |
| `user://` | En web es IndexedDB. `user_settings.cfg` persiste. | Sin cambio. |

### 2.2 Qué se rompe hoy si exportamos (inventario para 039b/039c)

| Pieza | Problema en Compatibility/web | Acción |
|---|---|---|
| `data/look/env_base.tres` | `volumetric_fog_enabled`, `ssao_enabled` (y SSIL/SDFGI si aparecen) no existen en Compatibility: se ignoran con aviso. Glow y la niebla de profundidad sí funcionan. | El preset web los apaga explícitamente (campos nuevos en `LookQuality`, §4.1), para que el log quede limpio y escritorio no cambie. |
| `LookQuality.scaling_mode` | FSR 1/2 y MetalFX no existen en Compatibility; solo bilineal. | El preset web usa bilineal. |
| `screen_space_aa` | Verificar FXAA en Compatibility 4.7. | Si no existe: `msaa_3d` 2x o nada. |
| 21 `.gdshader` | Uso de `hint_depth_texture`/`hint_screen_texture` (partículas suaves, cielo), `global uniform`s y builtins propios de Forward+. | 039c compila cada uno en web. Si alguno falla, se ramifica **en el mismo archivo** con `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY`. No se hace un shader paralelo. |
| `scenes/fx/sprite_particles*` (GPUParticles3D) | Compatibility soporta GPUParticles. La colisión SDF y algunos modos no. | Verificar en 039c. Si algo falla, se cambia a `CPUParticles3D` solo en el `.tres` del tipo afectado. |
| `FxLightLayer` (OmniLight3D) | En Compatibility cada luz suma una pasada por objeto (tope `max_lights_per_object`). | Web: `fx_max_lights` entre 0 y 2. |
| Sombras del sol | Funcionan, pero cuestan más. | Web: 2 splits, atlas de 1024, tope de 80 m. |
| `minimap_terrain_bake` (SubViewport `UPDATE_ONCE`) | Debería andar en WebGL2. | Verificar en 039c (el minimapa no queda negro). |
| `NavRebake` (`WorkerThreadPool` + `wait_for_task_completion`) | Sin threads la tarea corre en el hilo principal. El bake completo de High Noon tarda «un par de segundos» en escritorio y más en wasm. En solo, el navegador **se congela** cada vez que cae o aparece un edificio. En online no pasa: el dedicado mueve los cuerpos. | **Riesgo mayor.** Se mide en 039c (`WEBPROBE nav_rebake_ms`). Si pasa de 300 ms: (a) un `NavBakeSettings` web con celda más gruesa (otro `.tres` del mismo script), o (b) el export con threads (P1). |
| Navegación/evasión | `map_use_async_iterations=false` y la evasión sin threads ya están en `project.godot`. | Sin cambio. |
| Separación dedicado/headless | Web nunca corre `--dedicated` ni `--room-server`, ni `OS.create_process` (`MpProcessRunner`), ni los archivos de ticket. | La UI no ofrece esas puertas en web (§3.2). |
| Autoload `AgentKit` | Se exporta (vive en `addons/`). | Verificar en 039b que sin flags quede inerte y no abra sockets. Si no, guarda `OS.has_feature("web")` en el kit. |
| Opciones → Gráficos | En web no se controlan la pantalla completa sin gesto, el VSync ni el tope de FPS. | `graphics_tab` oculta esas filas en web. |

## 3. Red

### 3.1 Cliente web → salas y dedicados por WebSocket

- **Transporte:** en web `MpKit.transport` vale `ws` por defecto (el navegador no tiene UDP). El cambio va en el kit, es genérico y es una línea en `MpBoot`/`MpKit`. Escritorio sigue en ENet salvo `--transport=ws`.
- **Endpoint:** `MpLobbyEndpoint` (kit) suma dos campos:
  - `url: String`: si no está vacío, gana sobre `host:port`. Ejemplo: `wss://sac.dominio/lobby`.
  - `match_url_template: String`: ejemplo `wss://sac.dominio/m/{port}`. Si está vacío, el cliente usa `host:port` como hoy.
  - `MpTransport.create_client` ya acepta una URL completa como `host`.
  - El `.tres` del juego (`data/net/lobby_endpoint.tres`) suma `web_url` y `web_match_url_template`, que se usan cuando `OS.has_feature("web")`.
  - Alternativa más simple: dos `.tres` y un `@export` por plataforma en el glue. Ver P8.
- **Override de prueba:** `?lobby=ws://127.0.0.1:7700&match_url=ws://127.0.0.1:{port}` en la URL. `MpBoot` traduce la query a `--clave=valor` en web, así que lo existente (`--lobby=`) funciona sin código nuevo en el juego.
- **TLS (VPS):** una página servida por `https://` solo puede abrir `wss://`, porque el navegador bloquea el contenido mixto. Se propone **Caddy** en el VPS: certificado automático de Let's Encrypt, un solo puerto 443/TCP abierto, y los Godot escuchan TCP solo en `127.0.0.1`.
  ```
  sac.dominio {
      root * /srv/sacrifice/web
      file_server { precompressed br gzip }
      handle /lobby { reverse_proxy 127.0.0.1:7700 }
      @match path_regexp m ^/m/(78[0-3][0-9])$
      handle @match { reverse_proxy 127.0.0.1:{re.m.1} }
  }
  ```
  Firewall: 443/TCP abierto. 7700 y 7800-7831/TCP cerrados hacia afuera. UDP solo si sigue habiendo un lobby ENet (P4).
  Hay que verificar que `WebSocketMultiplayerPeer` en modo servidor acepte cualquier path (`/lobby`, `/m/7801`). Si no lo acepta, Caddy reescribe el path a `/` (`uri replace`).
- **Versión de build:** el navegador cachea el cliente viejo. El handshake de MpKit hoy no compara versiones. Se suma `MpKit.build_id` (un `@export` o un setting del proyecto, ej. el hash de git en el export), y el servidor rechaza con `admission_rejected("build")`. La UI dice «Recargá la página». Es un cambio genérico del kit, en 039f.

### 3.2 «Servidor local» en web: no

El navegador no puede escuchar sockets ni lanzar procesos (`OS.create_process`). Unirse desde una página `https` a un servidor local ajeno exige `wss://` con un certificado válido, algo impracticable para un jugador.

- `boot.gd`: `%LocalServer.visible = not OS.has_feature("web")`.
- En su lugar va una etiqueta: «Servidor local: solo en la versión de escritorio».
- Online del navegador = solo las salas del VPS.

### 3.3 Solo contra la IA: todo en el navegador

`SacrificeFlow.play_solo()` no abre servidor, y la IA vive en el proceso que simula (RULES §IA), así que corre entera en la pestaña. No hace falta red.

Costos a medir (039c): CPU de la simulación + IA + física en wasm de un solo hilo, y el `NavRebake` (§2.2). El determinismo del banco no aplica en web: el banco sigue en escritorio.

## 4. Hacerlo liviano

### 4.1 Preset de calidad `web`

`data/look/quality_web.tres` es otro `.tres` del mismo `LookQuality`, no un script nuevo. Punto de partida (039d lo ajusta con números):

| Campo | Web | Nota |
|---|---|---|
| `scaling_mode` / `scale` | bilineal / 0,75 | Compatibility no tiene FSR |
| `msaa_3d` / `screen_space_aa` | off / FXAA si existe | |
| `shadow_splits` / atlas / filtro / tope | 2 / 1024 / hard / 80 m | |
| `ssao_enabled` / `ssil_enabled` | false / false | No existen en Compatibility |
| `ground_layers` / `triplanar` / `stochastic` / `macro` | 2 / false / false / false | |
| `grass_enabled` | false | Ya está apagado en todos los presets |
| `fx_soft_particles` / `fx_frame_blend` | false / false | Ahorra la lectura de profundidad |
| `fx_max_lights` | 0 (o 2 si 039d lo permite) | |
| **nuevo** `volumetric_fog_enabled` | false | Escritorio: `true` (igual a hoy) |
| **nuevo** `glow_enabled` | true; se mide | Escritorio: `true` |
| **nuevo** `sky_realtime` | false: radiancia una vez por partida | Escritorio: el valor de hoy. Sin cambio de look (memoria «cielo original») |

- Los campos nuevos tienen como default el valor actual. Así `quality_low/medium/high.tres` no cambian: verificable con `git diff`.
- `GraphicsPrefs` suma `@export var web_presets: Array[LookQuality]` (`[quality_web, quality_web_low]`). `presets_for_platform()` devuelve esos en web.
- `data/ui/graphics_prefs.tres` sigue siendo la única instancia compartida (boot y High Noon).
- `quality_web_low.tres`: lo mismo con `scale` 0,6 y sin sombras, para la laptop floja.

### 4.2 Peso de modelos y texturas

Hechos de hoy:
- 213 `.glb`, ~996 `.png`.
- Mallas con compresión de Godot activa y sin LOD.
- Animaciones a 30 fps, sin compresión.
- Texturas: 987 sin pérdida y 12 VRAM.
- Son modelos del 2000 y tienen pocos polígonos.
- **Hipótesis:** el peso está en las texturas (sin pérdida, sin VRAM) y en las animaciones, no en los triángulos. 039a lo confirma o lo tira abajo.

Propuesta: un **EditorExportPlugin** (`addons/web_shrink/`, solo editor y excluido del export) que actúa solo si el preset tiene la feature `web`, vía `_begin_customize_resources` y `_customize_resource`. El import y el escritorio no se tocan.

- **Reglas = Resource:** `WebShrinkRules` (`data/web/shrink_rules.tres`). Es una lista de `{glob, max_size, mode}`. Ejemplo:
  - `assets/original/models/**` → 512, Basis (ETC1S);
  - `assets/original/maps/**` y `textures/**` (suelo) → 1024, Basis;
  - `assets/original/ui/**` → sin cambio de tamaño, WebP con pérdida 0,85 (la UI queda nítida);
  - `fx/**` → 256, WebP.
- **Formato:** `PortableCompressedTexture2D`.
  - Basis Universal da una descarga chica y queda comprimida en la GPU: se transcodifica a BC en escritorio y a ETC2/ASTC en móvil.
  - WebP con pérdida baja la descarga, pero en VRAM queda RGBA8.
  - S3TC/BPTC solo sirve para escritorio y descarga más.
  - Recomendación: Basis para 3D, WebP para UI/FX chicos.
  - **El primer paso de 039e es un spike de una textura:** confirmar que `_customize_resource` puede devolver un `PortableCompressedTexture2D` donde había un `CompressedTexture2D`, y que se ve bien en WebGL2. Si falla, se usa S3TC con `vram_texture_compression/for_desktop` y se reimporta solo en una copia de export (más lento, último recurso).
- **Mallas:** sin simplificar, salvo que 039a muestre lo contrario.
- **Animaciones:** si 039a muestra que pesan, el mismo plugin devuelve `Animation` con `compress()` solo en web.
- **Costo del esqueleto:**
  - Medir en 039c con la batalla más grande del probe (`WEBPROBE units= fps=`).
  - Si molesta, pausar el `AnimationTree` de los cuerpos fuera de pantalla (`VisibleOnScreenNotifier3D` en la escena del modelo). Eso beneficia a los dos targets y es otro corte, fuera de 039.

### 4.3 Carga perezosa por dios/bioma

`ProjectSettings.load_resource_pack()` sobre un `.pck` bajado con `HTTPRequest` a `user://`. El export se hace por presets «patch» con recursos elegidos (`dios_<x>.pck`).

Es caro: un preset por dios, rutas compartidas, el orden de carga en el menú y la caché del navegador. **Solo se hace (039h) si después de 039e la descarga inicial pasa la meta.** Ver P5.

### 4.4 Medición (comandos para 039a; no se corren ahora)

```bash
cd /Users/joelsartori/Development/sacproject/game
# fuentes
du -sh assets/original/* | sort -h
for e in png glb json; do printf "%s " $e; find assets -name "*.$e" -print0 | xargs -0 du -ch | tail -1; done
# lo que entra al pck (importado)
for e in ctex scn res mesh; do printf "%s " $e; find .godot/imported -name "*.$e" -print0 | xargs -0 du -ch | tail -1; done
ls -S .godot/imported/*.ctex | head -30 | xargs du -h
grep -l 'compress/mode=0' $(find assets -name '*.png.import') | wc -l
# código
find . -path ./.godot -prune -o \( -name '*.gd' -o -name '*.gdshader' -o -name '*.tscn' -o -name '*.tres' \) -print0 | xargs -0 cat | wc -c
# export web (por la cola: 1 Godot headless)
mkdir -p build/web
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release web build/web/index.html
ls -l build/web
for f in build/web/index.wasm build/web/index.pck build/web/index.js; do printf "%s br=" $f; brotli -q 11 -c $f | wc -c; done
python3 -I tools/web/size_report.py build/web/index.pck --by ext,top-dir --top 40
```

`tools/web/size_report.py` lee la tabla de archivos del `.pck` (ruta y tamaño) y agrupa por extensión y por carpeta raíz. Es la única forma de ver el desglose real después del export y del plugin.

## 5. Pipeline

- **`export_presets.cfg`:**
  - `web`: release, sin threads, `vram_texture_compression/for_desktop=true`, `for_mobile=false` (P6), PWA off, `exclude_filter` = el del dedicado + `debug/*, addons/web_shrink/*, assets/mm/*, build/*`.
  - `web_probe`: lo mismo + `custom_features="web_probe"` + incluye `debug/web/*`.
  - `dedicated_server` sin cambios.
- **`project.godot`:**
  - `rendering_method.web="gl_compatibility"`;
  - `application/run/main_scene.web_probe="res://debug/web/web_probe.tscn"` (override por feature: solo el preset de prueba arranca en el probe).
- **Import:** Godot 4 no tiene import por plataforma. Por eso el achique va en el export plugin (§4.2) y los `.import` del repo no se tocan.
- **Servidor local de prueba:** `tools/web/serve.sh` = `python3 -I -m http.server 8060 --bind 127.0.0.1 -d build/web`. Sin threads no hacen falta headers. El `.wasm` sale con `application/wasm`.
- **Despliegue:** `tools/deploy/Caddyfile` + una sección «Web» en `tools/deploy/README.md`: copiar `build/web/*` a `/srv/sacrifice/web` con `.br`/`.gz` precomprimidos. Escrito y revisado, sin desplegar (como 034g).

## 6. Escena de prueba

- **El criterio de jugador empieza en `boot.tscn`**, la escena que abre el jugador. Para el juego no hay debug: export `web`, abrir la URL, clic en «Contra la IA» (o «Jugar online»).
- **Para medir:** `res://debug/web/web_probe.tscn`, main scene solo en el preset `web_probe`.
  - Instancia la escena de producto `res://scenes/ui/boot.tscn` (menú, para cronometrar hasta el menú). Después llama al mismo `SacrificeFlow.play_solo(setup)` que el botón «Contra la IA», con dios, nivel y `match_seed` de `debug/web/probe_solo_ai.tres` (`WebProbeConfig`: `warmup_s=10`, `sample_s=60`, `ai_god`, `ai_level`, `seed`, `camera_preset`).
  - **Estado inicial:** menú cargado. **Todavía no hay** partida ni números.
  - **Acción:** ninguna del InputMap. El probe arranca solo con `?probe=1`; sin el parámetro queda en el menú para jugar a mano.
  - `probe_battle.tres` es el mismo script con otra semilla y `ai_level=hard` para forzar una batalla grande. Es un atajo de debug y no tiene `.gd` propio.
  - **Salida en la consola del navegador:**
    `WEBPROBE boot_ms=… menu_ms=… match_ms=… fps_avg=… fps_p1=… frame_ms_max=… mem_static_mb=… units=… nav_rebake_ms_max=… renderer=…`
- **Quién lo mira:**
  - El orquestador abre `http://127.0.0.1:8060/index.html?probe=1` en el panel Browser y lee `read_console_messages` con el patrón `WEBPROBE`, más una captura del menú y otra de la partida.
  - El panel puede renderizar por software: **ahí no vale el FPS**, solo que carga y corre.
  - El FPS lo mide un humano en Chrome real (Mac y laptop media).
  - El playtester de AgentKit no maneja el navegador.

## 7. Árbol de archivos y responsabilidades

```
game/
├── project.godot                          [~] 039a rendering_method.web; 039b main_scene.web_probe
├── export_presets.cfg                     [~] 039a preset web; 039b web_probe
├── addons/
│   ├── mp_kit/
│   │   ├── mp_boot.gd                     [~] 039f en web, query de la URL → args --clave=valor
│   │   ├── mp_kit.gd                      [~] 039f transport ws por defecto en web; build_id en el handshake
│   │   └── lobby/mp_lobby_endpoint.gd     [~] 039f url, match_url_template
│   │       (+ el cliente del lobby / join_endpoint usa la plantilla)
│   └── web_shrink/                        [+] 039e solo editor
│       ├── plugin.cfg, plugin.gd          registra el export plugin
│       ├── web_shrink_export.gd           EditorExportPlugin: _customize_resource si feature web
│       └── web_shrink_rules.gd            class_name WebShrinkRules extends Resource
├── data/
│   ├── look/quality_web.tres              [+] 039d
│   ├── look/quality_web_low.tres          [+] 039d
│   ├── ui/graphics_prefs.tres             [~] 039d web_presets
│   ├── net/lobby_endpoint.tres            [~] 039f web_url, web_match_url_template
│   └── web/shrink_rules.tres              [+] 039e
├── scenes/
│   ├── world/look/look_quality.gd         [~] 039d volumetric_fog_enabled, glow_enabled, sky_realtime
│   ├── world/look/quality_applier.gd      [~] 039d los aplica (Environment, cielo)
│   ├── ui/options/graphics_prefs.gd       [~] 039d web_presets + presets_for_platform()
│   ├── ui/options/graphics_tab.gd         [~] 039d oculta pantalla completa/VSync/FPS en web
│   ├── ui/boot.gd, boot.tscn              [~] 039f oculta Servidor local + etiqueta en web
│   └── **/*.gdshader                      [~] 039c solo los que no compilen: #if CURRENT_RENDERER
├── debug/web/
│   ├── web_probe.tscn, web_probe.gd       [+] 039b instancia boot.tscn, cronometra, juega, imprime WEBPROBE
│   ├── web_probe_config.gd                [+] class_name WebProbeConfig extends Resource
│   ├── probe_solo_ai.tres                 [+]
│   └── probe_battle.tres                  [+] 039c
└── tools/
    ├── web/size_report.py                 [+] 039a desglose del .pck
    ├── web/serve.sh                       [+] 039b servidor estático local
    └── deploy/Caddyfile, README.md        [+]/[~] 039g
```

| Responsabilidad | Dueño |
|---|---|
| Qué renderer usa web | `project.godot` (override `.web`) |
| Qué efectos se ven en web | `quality_web*.tres` → `QualityApplier` (el mismo de hoy) |
| Qué presets ofrece la UI por plataforma | `GraphicsPrefs` |
| Tamaño de texturas en web | `WebShrinkRules` (datos) + `web_shrink_export.gd` (aplica) |
| Transporte y URL en web | `MpKit`/`MpBoot`/`MpLobbyEndpoint` (kit, genérico) |
| Qué puertas del menú existen en web | `boot.gd` |
| TLS y estáticos | Caddy (fuera de Godot) |
| Medir | `web_probe` (debug, no entra en `web`) |

## 8. Resource, nodo, `@export`

- **Resource de tipo:** `LookQuality` (`quality_web*.tres`), `WebShrinkRules`, `WebProbeConfig` (`probe_*.tres`), `MpLobbyEndpoint`.
- **Nodo:** `WebProbe` (debug, hijo raíz de su escena; instancia `boot.tscn`). Los demás ya existen (`QualityApplier`, `GraphicsApplier`, boot).
- **`@export` de instancia:** `GraphicsPrefs.web_presets`; `WebProbe.config: WebProbeConfig`; `WebShrinkExport.rules` (el plugin carga `data/web/shrink_rules.tres` por `@export` en `plugin.gd`).

## 9. Cambio al PRD (lo aprueba el usuario)

- Arranque: «Juego de escritorio en Godot 4» → «Juego de escritorio y web (navegador de escritorio) en Godot 4».
- §Decisiones, nueva viñeta: «Web: cliente en el navegador (Compatibility/WebGL2, sin threads). Online por WebSocket (`wss://` vía proxy TLS) a las mismas salas y dedicados del VPS. Solo contra la IA corre entero en el navegador. Sin "Servidor local" en web. Sin móvil (RFC-039).»
- §Fuera del primer corte: sacar «export web».
- RFC-034 §Fuera de alcance: anotar «export web → RFC-039».

## 10. Riesgos

1. **`NavRebake` sin threads** congela la pestaña en solo (§2.2). Medido en 039c; mitigación en P1.
2. **Memoria por texturas sin pérdida:** sin 039e, la pestaña puede pasar 2 GB y caerse.
3. **El spike de `_customize_resource` + Basis** puede no funcionar → plan B con S3TC (más descarga).
4. **CPU de la simulación + IA en wasm:** si `fps_avg` < 30 en la batalla del probe, ni los efectos ni el tamaño lo arreglan. Opciones: preset más bajo, menos tasa de IA en web (no: la IA no debe cambiar por plataforma), o threads.
5. **Cliente cacheado contra un servidor nuevo** → `build_id` (039f).
6. **Contenido mixto:** una página `https` con `ws://` falla en silencio. La plantilla de URL debe ser `wss://` en producción.
7. **Edge-scroll y atajos** del navegador (§2.1).
8. **El panel Browser renderiza por software:** su FPS no sirve como métrica.

## 11. Fuera de alcance

- Móvil y táctil.
- WebRTC y que un jugador web sea host.
- Servidor local en web.
- Audio.
- Simplificar mallas.
- PWA/offline.
- Pausar animaciones fuera de pantalla (otro RFC, sirve a los dos targets).
- Que escritorio y web jueguen con ENet y WS a la vez en el mismo lobby (P4 lo resuelve con un solo transporte).
- Carga perezosa, salvo que 039e no llegue a la meta (039h).

## 12. Cortes

Cada corte usa a lo sumo 1 Godot headless (export) y nunca abre ventana de Godot. Escritorio: `quick` en los cortes que tocan `scenes/` o el kit.

| Corte | Qué | Chequeo barato |
|---|---|---|
| **039a** Medición base | Preset `web` (sin threads, Compatibility), `rendering_method.web`, `tools/web/size_report.py`; correr §4.4 y volcar la tabla en el F | El export sale con código 0 y deja `index.{html,js,wasm,pck}`. La tabla del F tiene MB por `ctex/scn/res/mesh/código` + `.wasm`/`.pck` en bruto y en brotli. `git diff` sin cambios en `data/look/quality_{low,medium,high}.tres` |
| **039b** Carga en el navegador | Preset `web_probe`, `debug/web/web_probe*`, `serve.sh`, AgentKit inerte en web | Panel Browser en `127.0.0.1:8060/?probe=1`: captura del menú, `WEBPROBE boot_ms=… menu_ms=…` en la consola y **0** `SCRIPT ERROR`. Se anotan los `WARNING` de renderer en el F (inventario de §2.2) |
| **039c** Solo en el navegador | Arreglos de Compatibility: shaders con `#if CURRENT_RENDERER`, partículas, minimapa y entrada; `probe_battle.tres` | `?probe=1`: la partida contra la IA corre 60 s y escribe `WEBPROBE fps_avg … nav_rebake_ms_max … units …`. Capturas: unidades, partículas y minimapa visibles (no negros). `nav_rebake_ms_max` anotado; si > 300 ms, se abre P1. `quick` PASS en escritorio |
| **039d** Preset web | `quality_web*.tres`, campos nuevos de `LookQuality`, `GraphicsPrefs.web_presets`, `graphics_tab` en web | Chrome real en la Mac: `fps_avg` ≥ 60 a 1280×720. Laptop media del usuario: `fps_avg` ≥ 30 y `fps_p1` ≥ 20 con `probe_battle`. Escritorio: `git diff` vacío en los tres presets y `pt22c_quality` AGENT_OK |
| **039e** Peso | Spike de 1 textura; `addons/web_shrink` + `shrink_rules.tres` | `size_report`: `.pck` ≤ **120 MB** en bruto (y < 200 MB, el tope de itch). Descarga total con brotli (wasm+js+pck) ≤ **80 MB** (deseable ≤ 50). `mem_static_mb` ≤ **1024** en `probe_battle`. El `.pck` de `dedicated_server` mide lo mismo que antes (±1 %). Captura web lado a lado con escritorio en la cámara fija del probe: sin texturas negras ni rosas |
| **039f** Red WS | Kit: transporte ws en web, query → args, `url`/`match_url_template`, `build_id`. Juego: `lobby_endpoint.tres`, boot sin Servidor local en web | Local: salas con `--transport=ws` + 1 cliente web (`?lobby=ws://127.0.0.1:7700&match_url=ws://127.0.0.1:{port}`) + 1 cliente de escritorio `--transport=ws`. La sala se llena, arranca, ambos ven el mundo y la partida termina (rendición o fin) con el resultado en los dos. Un cliente con otro `build_id` queda rechazado con el texto «Recargá la página». `TRANSPORT=ws bash agent/run_034e.sh` PASS, `run_034e.sh` (ENet) PASS, `quick` PASS. Captura web sin el botón Servidor local |
| **039g** Despliegue escrito | `Caddyfile`, sección Web en `tools/deploy/README.md`, precompresión | Review de texto. `caddy validate --config tools/deploy/Caddyfile` si Caddy está instalado; si no, revisión. La prueba en el VPS la hace el usuario (como 034g) |
| **039h** (condicional) Carga perezosa por dios | Solo si 039e no llega a la meta | Descarga inicial hasta el menú ≤ meta; elegir un dios baja su pack una vez (segunda vez desde la caché) |

**Orden:** 039a → 039b → 039c → (039d ∥ 039e en serie, de a uno) → 039f → 039g → [039h]. 039f puede ir antes de 039d/e si el usuario prioriza el online: solo depende de 039b.

## 13. Verificación humana

1. Exportar `web_probe` (Proyecto → Exportar, o el comando de §4.4 con `web_probe`) y correr `tools/web/serve.sh`.
2. Chrome → `http://127.0.0.1:8060/index.html` → menú. Clic en «Contra la IA» y jugar un rato.
3. Con `?probe=1`: abrir DevTools → Consola y anotar la línea `WEBPROBE`.
4. En el editor:
   - Inspector de `data/ui/graphics_prefs.tres`: `web_presets` lista los dos `.tres` web.
   - `quality_web.tres`: los campos de §4.1.
   - `data/web/shrink_rules.tres`: las reglas.
   - F6 sobre `debug/web/web_probe.tscn` en escritorio corre la misma partida (sirve para comparar FPS Forward+ contra web).
5. Red: terminal 1 `Godot --headless --path game res://scenes/net/room_server.tscn -- --room-server --transport=ws --lobby-config=res://scenes/net/lobby_config_local.tres`. Navegador con `?lobby=ws://127.0.0.1:7700&match_url=ws://127.0.0.1:{port}`. Un cliente de escritorio con `--transport=ws`.

## 14. Preguntas abiertas (con recomendación)

- **P1. ¿Threads o no?** (a) Sin threads: anda en cualquier hosting y en itch sin tildar nada **[recomendado]**. (b) Con threads, si `nav_rebake_ms_max` > 300 ms o la CPU de la IA no da: requiere COOP/COEP (Caddy los pone; itch tiene la casilla «SharedArrayBuffer»).
- **P2. Hosting.** (a) El mismo VPS con Caddy: estáticos + `wss` en el mismo origen, headers bajo control y brotli precomprimido **[recomendado]**. (b) itch.io como vitrina después: tope de 200 MB por archivo, y el `wss` igual apunta al VPS.
- **P3. TLS.** (a) Caddy con Let's Encrypt automático; hace falta un dominio (o subdominio) apuntado al VPS **[recomendado]**. (b) `TLSOptions.server` en cada Godot, con certificados en disco y renovación a mano.
- **P4. ¿Un lobby o dos?** (a) En el VPS, el servidor de salas corre en **WS para todos**: el escritorio online también usa `wss` (`lobby_endpoint.tres` con `url`) y web y escritorio comparten salas. ENet queda para LAN, Servidor local y el banco **[recomendado]**. (b) Dos servidores de salas (ENet UDP 7700 y WS): salas separadas por plataforma.
- **P5. ¿Los 5 dioses de una?** (a) Sí, un solo `.pck`, si 039e entra en la meta **[recomendado]**. (b) Carga perezosa por dios (039h) solo si no entra.
- **P6. ¿Móvil?** (a) No: es un RTS de mouse, clic derecho y atajos. Solo `for_desktop` (S3TC/BPTC) y Basis **[recomendado]**. (b) Sí: otro RFC (táctil, ETC2/ASTC, UI).
- **P7. ¿Qué navegadores?** (a) Chrome, Edge y Firefox de escritorio son el objetivo; Safari, «mejor esfuerzo» **[recomendado]**.
- **P8. Endpoint web.** (a) Campos `web_*` en el mismo `lobby_endpoint.tres` **[recomendado]**: una sola instancia. (b) Un `lobby_endpoint_web.tres` aparte, elegido por plataforma en el glue.
- **P9. ¿Qué metas de tamaño?** (a) `.pck` ≤ 120 MB y descarga con brotli ≤ 80 MB para la v1 web; se ajustan con la tabla de 039a **[recomendado]**. (b) Ir directo a ≤ 50 MB (probablemente exige 039h).
