# Plan 069: pantalla de carga con precalentado de shaders

Tech lead, 2026-10-26. Estado: **aprobado** 2026-10-26 («ok a todo con tus recomendaciones»). Pedido del usuario: «deberíamos aplicarlo para tener el juego productivo».

## Contradicción a decidir
RFC-068: «Solo y Contra la IA no arman la puerta». Este plan necesita que en solo el mundo no avance mientras precalienta (si no, `MatchClock` y la IA corren 1–3 s detrás de la pantalla). Propuesta: armar la puerta en solo en modo «solo espera al host», sin asientos ni red (`MpMatchGate` ya es el único dueño de «la partida espera para arrancar»).

## 1. Hoy
- Nada de precalentado: `ShaderWarmup` solo figura como pendiente. `burst_pool.gd:33` `prewarm_all()` crea emisores, no los dibuja.
- Carga síncrona: `mp_flow.gd:364-381` `goto_world()`; `world_loading` sin oyentes. `sacrifice_flow.gd:146-148` → `map_catalog.gd:50` carga el mapa en el hilo principal; `match_world.gd:36-53` lo instancia.
- «Cargué» = «mundo listo»: `mp_spawner.gd:160-164` → `mp_kit.gd:249`, `:548-562` → `gate.mark_loaded`. `match_biome.gd:27-31` manda el bioma recién en `client_world_ready` → hay que separar el «cargué» de la puerta del `world_ready` de los spawners.
- La puerta pausa también al servidor (`mp_match_gate.gd:378-380`); `MatchClock` no cuenta pausado.
- Proyecto en Forward+ por defecto; solo hay preset `dedicated_server`.

## Godot
`ResourceLoader.load_threaded_request` + `change_scene_to_packed`. Desde 4.4 ubershaders y precompilación al cargar mallas; quedan las compilaciones DRAW (materiales cambiados en runtime, partículas, sombras, niebla): se dibujan una vez frente a la cámara real tapadas por la pantalla (guía oficial «pipeline compilations»). Fin = contadores `RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW/SPECIALIZATION` quietos `settle_frames` (nombre exacto en 4.7: verificar con `--doctool`). 4.5+: «Shader baker» en el preset de export del cliente.

## 2. Árbol
```
addons/mp_kit/                      (genérico → fix al kit)
  [+] mp_world_loader.gd    dueño de la fase de carga (IDLE → FILES → WORLD → READY), load_threaded_*, progreso
  [~] mp_flow.gd            goto_world delega; signals world_load_progressed / world_loaded; report_world_progress / report_world_loaded;
                            virtuales _before_world_load(), _extra_world_loads(); @export world_reports_loaded := false
  [~] mp_kit.gd             report_loaded(): cliente → rpc_seat_loaded; servidor/solo → gate.mark_host_loaded()
  [~] mp_match_gate.gd      loaded_on_world_ready; wait_host + mark_host_loaded(); arm([], 0) válido (solo)
  [~] tests/, GUIDE.md
scenes/ui/loading/          [+] README.md, loading_screen.tscn, loading_screen.gd
  LoadingScreen (CanvasLayer 100, ALWAYS) ─ Backdrop (negro, traga input) · %Title · %Phase · %Bar
scenes/core/flow/sacrifice_flow.{tscn,gd}   [~] instancia LoadingScreen; _before_world_load; _extra_world_loads
scenes/core/catalog/active_match.gd         [~] load_paths(), warm_roots()
scenes/look/warmup/         [+] README.md, shader_warmup.tscn/.gd, warm_collect.gd, warm_hook.gd
scenes/match/match.tscn     [~] Camera/WarmupStage (Marker3D), Warmup, LoadReport
scenes/net/load_report.gd   [+] warmup → MpFlow.report_world_*
ganchos WarmHook: scenes/fx/fx_bus.tscn (flash_all de Bursts y Beams sin sonido ni temblor),
  scenes/fx/blood/spray_marks, scenes/look/atmosphere/precipitation_look.gd
data/i18n/strings.csv       [~] UI_LOADING_WORLD, UI_LOADING_SHADERS
agent/perf/warmup_probe.gd, agent/runs/run_warmup.sh   [+] medición
```
Secuencia: pantalla visible → elección de mapa → carga en hilo (0–0,5) → cambio de escena → espera `MatchBiome.applied` → dibuja por lotes en `WarmupStage` y avisa a los WarmHook (0,5–1) → `report_loaded` → fade → `MatchWait` si faltan jugadores. Dedicado headless reporta al instante.

## 3. Qué se precalienta (sin listas)
Raíces: el mapa instanciado, `ActiveMatch.warm_roots()` (dioses y magos), escenas de los `MultiplayerSpawner` de `match.tscn`, el `LookProfile` del bioma. Se baja por `GodType.book` → `type.body` → `BodyLook.of_body` → `get_dependencies`. `BodyLook`/`FxScene` se instancian; lo que simula no (solo mallas y materiales). Lo que el recorrido no ve lo dibuja su dueño con un `WarmHook`.

## 4. Medición (`warmup_probe.gd`, solo contra IA, `test_flat4`, caché de pipelines borrada)
1. Δ DRAW + SPECIALIZATION tras `world_loaded` = 0 (base > 0).
2. Frames > 50 ms = 0; frame máximo ≤ 2× mediana.
3. Carga ≤ 8 s en frío, ≤ 3 s con caché.
4. VRAM a 60 s ≤ base + 15 %.
5. `run_068_gate.sh` verde; «slot N cargó» después del precalentado.

## 5. Riesgos
Web/Compatibility (sin ubershaders, quizás sin contadores, sin hilos → acotar a los dioses de la partida). Memoria y tiempo (`max_s` 20 < `load_timeout_s` 60). Cambiar gráficos en partida crea variantes nuevas. La pantalla traga ESC. `mp_flow.gd` ya tiene 595 líneas → la carga va en `mp_world_loader.gd`.

## 6. Sub-cortes
W1 kit (`addons/mp_kit/`) · W2 pantalla (`scenes/ui/loading/`, `scenes/core/flow/`, `data/i18n/`) · W3 precalentado (`scenes/look/warmup/`, `match.tscn`, `load_report.gd`, `active_match.gd`) · W4 ganchos (`scenes/fx/`, `scenes/look/atmosphere/`) · W5 medición (`agent/`). En paralelo; W3 deja primero `warm_hook.gd`.
