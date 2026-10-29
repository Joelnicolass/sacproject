# RFC-039 (v2): Sacrifice en el navegador

Estado: propuesto, 2026-10-28. Reemplaza al RFC-039 de 2026-10-18 (`docs/archive/rfcs/RFC-039-web-port.md`) y a su enmienda WebRTC. Rama `web-port`, worktree `../sacproject-web`. El escritorio (`refactor/godot-standard`) no cambia por este RFC.

Pedido: el usuario aprobó el replan y un spike de export (2026-10-28), coordinado con la sesión de la web promocional (`sacrifice-godot-web`, ruta `/[lang]/play`).

## 0. Qué cambió desde la v1

| v1 (2026-10-18) | Ahora |
|---|---|
| Sin threads | **Con threads.** Hay más trabajo en workers: el navmesh por zonas de PropKit, su índice y el pasto. Vercel sirve COOP/COEP sin problema. |
| Online por WebRTC P2P, señalización en Railway | **El relay WebSocket de MpKit 0.18** (`wss://relay-godot.fly.dev`, tokens del emisor). MpKit ya elige WebSocket o relay en web (`MpTransport`, `MpNetConfig`), hospeda la sala en la pestaña (`MpOnline`: LISTEN) y la mantiene viva con la pestaña oculta (`MpWebKeepAlive`). Ni WebRTC, ni Railway, ni TURN. |
| Salas y dedicados en un VPS | Apagados desde el 2026-10-27 (`room_server_enabled`). En web solo hay salas de jugadores y solo contra la IA. |
| Sin audio | Hay audio: 78 MB, entre Ogg y MP3. |
| `.pck` de 247 MB | 402 MB: se sumaron audio, normal maps (RFC-067) y mapas. |

## 1. Spike (2026-10-28): lo medido

Export `Web` (Compatibility, `thread_support=true`), Godot 4.7.2 stable, proyecto entero (no solo `test_flat`: el `.pck` lleva todo lo que la partida puede cargar). El preset y el `rendering_method.web` están solo en la rama `web-port`.

**Archivos** (en `game/build/web/`, no versionados): `index.html`, `index.js`, `index.wasm`, `index.pck` separado, `index.audio.worklet.js`, `index.audio.position.worklet.js`, `index.png`, `index.icon.png` e `index.apple-touch-icon.png`.

| Archivo | Bruto | gzip -9 | brotli -9 |
|---|---|---|---|
| `index.wasm` | 38,8 MB | 10,1 MB | 7,9 MB |
| `index.pck` | 402 MB | 343 MB | 329 MB |

Qué hay dentro del `.pck` (20 336 archivos):

| Contenido | MB |
|---|---|
| Texturas importadas (`.ctex`; las más grandes son normal maps y albedo de 9 MB) | 182 |
| Modelos y escenas importadas (`.scn` de los `.glb`) | 78 |
| Recursos (`.res`: mallas, navmesh, catálogo) | 47 |
| Audio: música en `mp3str` (27) y `oggvorbisstr` (44) | 71 |
| Audio: efectos (`sample`) | 7 |
| JSON, escenas de texto y scripts | 12 |

**En el navegador:** Chromium 152 con COOP/COEP y `crossOriginIsolated=true`, servido desde `127.0.0.1:8060`.
- **Arranca:** carga el menú del mago con el modelo 3D, el menú de inicio y una partida «Contra la IA» en High Noon. Se ven mago, pasto, cielo, HUD y minimapa. El heap de JS queda en 563 MB.
- **Shaders:**
  - *Instance uniforms*: «Too many instances using shader instance variables … Maximum items supported by this hardware is: 1024». Los usan 17 shaders, entre ellos `terrain_deform.gdshaderinc`, los sprites de FX, las barras de vida y las almas. Pasado el tope, la instancia se dibuja mal: el altar sale azul plano.
  - *Screen y depth*: 6 shaders leen `hint_screen_texture`/`hint_depth_texture`; falta revisarlos uno por uno. Ninguno ramifica por `CURRENT_RENDERER`.
- **UI:** el menú de inicio todavía ofrece «Servidor local», que en web no puede andar.
- **No medido:**
  - los fps: el panel del navegador estaba oculto y la pestaña corría frenada en segundo plano, así que hay que medir en Chrome real;
  - Safari;
  - el audio;
  - las salas online desde web.

## 2. Decisiones

| Tema | Decisión | Por qué |
|---|---|---|
| Threads | **Sí**, con COOP `same-origin` y COEP `require-corp` en `/play` | El navmesh por zonas, su índice (unos 200 ms en Alpine) y el pasto corren en workers. En un solo hilo, cada cambio del terreno congela la pestaña. |
| Renderer | **Compatibility (WebGL 2)** | Es lo único estable en web. Se pierden la niebla volumétrica, SSAO, SSIL, FSR y la profundidad de campo; quedan el glow, la niebla de distancia, el pasto y las luces con tope. Se ve más modesto que en escritorio. |
| WebGPU | Investigación, sin fecha | No está en Godot estable. |
| Red | El relay de MpKit (WebSocket), con salas hospedadas por jugadores | Ya está en el kit. |
| Host en pestaña | **Fuera del primer corte público** | Hay que probar `MpWebKeepAlive` en partidas reales. En móvil el navegador congela la pestaña. |
| Peso | ≤ 120 MB en bruto y ≤ 80 MB con brotli, más el `.wasm`. Se baja solo en el export web | Tope práctico de descarga; R2 no tiene problema. |
| Hosting | La landing en Vercel; el `.pck` en Cloudflare R2 con CORS y `CORP: cross-origin`, y brotli precomprimido | Límites de tamaño por archivo de Vercel. |
| Arte original | **Builds privadas** (preview con login o URL no listada) hasta que el usuario decida si se distribuye | El `.pck` lleva modelos, texturas y audio de Shiny/Interplay. |

## 3. Cortes

Cada corte usa a lo sumo un Godot headless para exportar. El navegador corre en el panel o en Chrome real. Escritorio: GUT, más `check_map` cuando el corte toca mapas.

| Corte | Qué | Criterio de aceptación |
|---|---|---|
| **039a** Arranque limpio | `rendering_method.web` y preset `Web` (hechos en el spike), y en web se esconde «Servidor local» (`MpNetConfig.can_host()`) | El export sale con código 0. En el navegador: menú, partida contra la IA en `test_flat` y High Noon, 0 `SCRIPT ERROR` |
| **039b** Shaders en Compatibility | Los 17 shaders con *instance uniforms* pasan a uniforms de material o a `INSTANCE_CUSTOM` (MultiMesh) en web, ramificando con `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` en el mismo archivo. Se revisan los 6 que leen la pantalla o la profundidad | 0 errores de *instance variables* y 0 de `instance_buffer_pos.has(p_instance)` (material_storage.cpp:2098). Este último se repite por instancia y por cuadro: cada uno cruza a JS como `console.error` y por sí solo puede hundir los fps, así que va antes de medir 039c. Captura de una partida: altar, almas, barras y FX bien dibujados, sin azul plano ni negro |
| **039c** Preset web | `quality_web.tres`, elegido solo en web: sin volumétrica, SSAO, SSIL ni DoF; sombras de 2 splits en atlas de 1024; pasto y luces con tope. Opciones › Gráficos esconde VSync y FPS | Chrome real en la Mac: ≥ 60 fps a 1280×720 en High Noon contra la IA. Laptop media del usuario: ≥ 30 fps y p1 ≥ 20 |
| **039d** Peso | Solo en el export web: texturas a la mitad (los normal maps, más), audio a menor bitrate y una sola versión por pista. Medir si hace falta separar el pack por dios | `.pck` ≤ 120 MB en bruto y ≤ 80 MB con brotli. El `.pck` de escritorio no cambia (±1 %). Capturas web lado a lado con escritorio sin texturas negras ni rosas |
| **039e** `/play` privado | Integración con la landing: ruta `/[lang]/play`, `GODOT_CONFIG.mainPack` apuntando a R2 y headers en `vercel.json`. Lo hace la sesión de la web; el juego aporta el preset, los nombres y `index.sizes.json` (`tools/web_export/write_sizes.py` después de cada export, para la barra de progreso con brotli) | Un preview privado carga hasta la partida contra la IA en Chrome. Safari: arranca, o queda anotado qué falla |
| **039f** Online desde web | Salas por el relay desde web: unirse primero, hospedar después | Web se une a una sala hospedada en escritorio, la partida arranca y termina en los dos lados. Se prueba hospedar en pestaña con la pestaña oculta 5 min |
| **039g** (condicional) Packs por dios | Solo si 039d no llega: el `.pck` base, y un pack por dios que se baja al elegirlo | Descarga inicial ≤ la meta; la segunda vez sale de la caché |

**Orden:** 039a → 039b → 039c → 039d → 039e → 039f → [039g]. 039e puede empezar en paralelo del lado web con un export de prueba.

## 4. Riesgos

- **El índice del navmesh en wasm** puede tardar varias veces lo de escritorio, aunque corre en un worker. Se mide en 039c.
- **Memoria:** la sesión de la web midió un pico de 1328 MB de heap de JS en el menú, después de cargar el `.pck`, y 552 MB en la partida en High Noon, antes del preset web. El pico de carga cuenta para 039d. Con texturas sin comprimir para web podría pasar de 2 GB en mapas grandes. Se mide en 039c y 039d.
- **Safari:** soporte de COOP/COEP y de WebGL 2 con threads; se ve en 039e.
- **Distribución del arte original:** bloquea el lanzamiento público, no el trabajo técnico.

## 5. Fuera de alcance

Móvil, WebGPU, «Servidor local» y dedicados en web, campaña.
