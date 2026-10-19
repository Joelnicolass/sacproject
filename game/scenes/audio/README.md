# scenes/audio/

Sonido del juego (RFC-052). Todo es del cliente: ninguna RPC nueva, nada escribe en la simulación y nada usa el generador global (`randf()`, `randi()`, `AudioStreamRandomizer`, el shuffle de `AudioStreamPlaylist`).

- `AudioGate`: ¿este proceso tiene audio? Cerrado en `--dedicated`, `--room-server` y headless (salvo `--audio-probe`). Con el gate cerrado no se crea ni se carga nada.
- `AudioPrefs` (`data/ui/audio_prefs.tres`): volumen lineal 0..1 por bus y «Silenciar», en `[audio]` de `user://settings.cfg` por `UserSettings`. Bajo AgentKit `Master` arranca en 0 salvo con `--audio-on`.
- `SoundCue`, `SoundSet`: Resources de tipo (`.tres` en `data/audio/`). `SoundEvent`: el vocabulario de eventos.
- `SoundLibrary`: tag -> set; busca en `data/audio/custom/` (los propios, ganan) y después en `data/audio/` (los del original). Sin set, o con un set cuyos archivos faltan, silencio sin aviso.
- `SoundBus` (autoload, después de `FxBus`): pools 3D (32) y 2D (8), `max_voices`, `cooldown_s` y prioridad por cue, RNG propio, `SoundLog`, y aplica `AudioPrefs` a los buses.
- `SoundLog`: los últimos pedidos (tocados o descartados), para las pruebas y el lab.
- `UnitSounds` (hijo de `unit.tscn`) y `WizardSounds` (hijo de `wizard_body.tscn`), sobre `BodySounds`: pasan estado replicado a eventos. La criatura: `summon` (modo `SUMMONING`), `swing`/`shoot` (`UnitBody.swung`/`shot_started`), `damaged` (baja `Health.current`; a lo sumo una vez cada 1,5 s por cuerpo) y `death` (modo `DEAD`). El mago: `incantation` (empieza `Caster.cast_fx_shown`), `damaged`, `death` (`GhostForm` `DYING`) y `ghost` (`RISING`). El cue sale del set propio, después de `aliases` (`swing` → `Xhit`, `shoot` → `swing`) y al final del set compartido (`world`: ahí está `summon`). Sin set: silencio. Suenan igual en solo y en un cliente de un dedicado (`bash agent/runs/run_audio_net.sh`).
- `ListenerFocus` (en `match.tscn`): el `AudioListener3D` sobre el mago local (`MatchWorld.local_wizard_changed`), girado con la cámara; sin mago, en la cámara.

Buses: `default_bus_layout.tres` (Master > Music, SFX, Voice, Ambience). Opciones → Sonido: `scenes/ui/options/audio_tab.tscn`.

Agregar uno nuevo: un nodo `*Sounds`/`*Voice`/`*Director` que pasa estado replicado o señales locales a un `SoundEvent` y llama a `SoundBus`. Pruebas: `debug/audio/` (`bash agent/runs/run_audio_cases.sh`, que también corre el lab `debug/audio/f360_audio_lab.tscn` con cada `lab_<corte>.tres`, con y sin el original).
