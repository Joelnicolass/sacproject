# scenes/audio/

Sonido del juego (RFC-052). Todo es del cliente: ninguna RPC nueva, nada escribe en la simulación y nada usa el generador global (`randf()`, `randi()`, `AudioStreamRandomizer`, el shuffle de `AudioStreamPlaylist`).

- `AudioGate`: ¿este proceso tiene audio? Cerrado en `--dedicated`, `--room-server` y headless (salvo `--audio-probe`). Con el gate cerrado no se crea ni se carga nada.
- `AudioPrefs` (`data/ui/audio_prefs.tres`): volumen lineal 0..1 por bus y «Silenciar», en `[audio]` de `user://settings.cfg` por `UserSettings`. Bajo AgentKit `Master` arranca en 0 salvo con `--audio-on`.
- `SoundCue`, `SoundSet`: Resources de tipo (`.tres` en `data/audio/`). `SoundEvent`: el vocabulario de eventos.
- `SoundLibrary`: tag -> set; busca en `data/audio/` y después en `data/audio/original/`. Sin set, silencio sin aviso.
- `SoundBus` (autoload, después de `FxBus`): pools 3D (32) y 2D (8), `max_voices`, `cooldown_s` y prioridad por cue, RNG propio, `SoundLog`, y aplica `AudioPrefs` a los buses.
- `SoundLog`: los últimos pedidos (tocados o descartados), para las pruebas y el lab.

Buses: `default_bus_layout.tres` (Master > Music, SFX, Voice, Ambience). Opciones → Sonido: `scenes/ui/options/audio_tab.tscn`.

Agregar uno nuevo: un nodo `*Sounds`/`*Voice`/`*Director` que pasa estado replicado o señales locales a un `SoundEvent` y llama a `SoundBus`. Pruebas: `debug/audio/` (`bash agent/runs/run_audio_cases.sh`).
