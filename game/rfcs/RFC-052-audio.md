# RFC-052: audio del juego (efectos, voces, música, ambiente)

Estado: 052a–052i hechos (F360–F368); 052z (F369) con el banco `all` igual y pendiente del playtest con ventana.
Pedido: «si, hagamos esto para tener el juego completo» (usuario, 2026-10-19).
Cambio previo: `changes/CHANGE-REQUEST-003.md` saca «audio original» de los no-goals del PRD y de FEATURES (Won't), y suma el dominio `scenes/audio/` y la carpeta `data/audio/` a RULES.md.

## 1. Hoy

- **Audio:** no hay nada. No hay `AudioStreamPlayer*` en `scenes/`, ni `.ogg`, `.wav` o `.mp3` en `res://`, ni `default_bus_layout.tres`, ni opciones de volumen. `project.godot` no tiene `[audio]`.
- **Opciones:** viven en `scenes/ui/options/`.
  - `OptionsMenu` tiene las pestañas Gráficos y Jugabilidad.
  - `UserSettings` guarda en `user://settings.cfg`, una sección por dueño, con escritura atómica y aislado bajo AgentKit.
  - El patrón `GraphicsPrefs` es un Resource compartido en `data/ui/graphics_prefs.tres` con un aplicador que no hace nada en el dedicado, en headless ni bajo AgentKit.
- **Importadores:** viven en `tools/import/`.
  - Todos resuelven la instalación del original con `sac_formats/install.py`, en este orden: `SAC_INSTALL`, `SAC_ROOT`, `tools/import/local.cfg`, la opción del editor `sacrifice/original_install_path`. Si no la encuentran, avisan en español y salen con código 2.
  - Escriben en `assets/original/`, son idempotentes, aceptan `--check` y `--out=DIR`, y nunca tocan un `.import`.
  - `OriginalAssets` (`scenes/core/catalog/original_assets.gd`) es el dueño de las rutas `res://assets/original/`.
- **Presentación que ya se replica (los puntos de enganche):**
  - `FxBus` (autoload) toca partículas, rayos y escenas. Desde el servidor, `broadcast*` manda un RPC `unreliable` con `call_local` a todos los pares. Hay unas 67 llamadas: impactos, muertes, sangre, hechizos, aflicciones, ritual. No hace nada en headless.
  - `UnitBody` sincroniza `mode` (`DEAD`, `SUMMONING`, `ATTACK`, `SHOOT`…), `swings` y `shots`. `swings` y `shots` son contadores con setter, que el cliente ya usa para el `lunge`. También se sincronizan `Health:current` (señal `Health.changed`), `Afflictions:shown` y `Flight:state`.
  - `ClipEvents.clip_event(kind)` (`attack`, `foot`, `sound`) se dispara en cada par desde las pistas de método de los clips.
  - `Caster.cast_fx_shown` se replica y emite `cast_fx_changed`.
  - `ritual.tscn` sincroniza `phase` (`Ritual.phase_changed`). `MatchState` emite `altar_state_changed`, `side_defeated` y `result_changed`.
  - `Selection.changed(units)` y `CommandLog.said(text, cue)` son locales. `CommandLog` recibe del servidor una clave `Refusal` (`&"no_mana"`, `&"out_of_range"`…).
  - `MatchBiome.applied(god)` avisa el dios del mapa. `MatchWorld.local_wizard_changed(wizard)` avisa el mago local.
- **Determinismo:**
  - `MatchSeed` siembra el generador global para la simulación.
  - `FxBus` usa su propio generador para no tocarlo.
  - El banco también corre en modo `window`, con audio en el mismo proceso que simula.

## 2. Cómo guarda el sonido el original

Fuente: medido en una instalación con `sac_formats/wad.py`. sacengine solo se usó como referencia de formato; no se copió código.

| Origen | Contenido | Tamaño |
|---|---|---|
| `data/sounds.wad` (`SFX_.WAD!`) | 388 `SAMP` en las carpetas `comb`, `comn`, `menu`, `sacr`, `ambi`, `gib!`, `spid` y una por dios; 86 `SSET` | 33 MB |
| `data/local/sfx_english.wad` (`SFXe.WAD!`) | 2488 `SAMP`: voces de criaturas, de los 14 magos (unas 72 cada uno) y del consejero `Wspw` | 162 MB |
| `data/music/*.mp3` (sueltos) | 17 temas: `menu`, `God Realm`, `<dios>_normal` (5), `Battle 1-5`, `Sacrifice 1`, `Sacrifice Losing`, `Sacrifice Victory`, `Victory Theme`, `Defeat Theme` | 26 MB |

- **`SAMP`:**
  - Cabecera de 32 bytes: tamaño u32 en el desplazamiento 12, 16 bits, `sampleRate` 22050, mono.
  - Después viene PCM16 crudo o un `RIFF/WAVE` IMA ADPCM mono. El IMA ADPCM usa bloques de `blockAlign` con una cabecera de 4 bytes (predictor i16, step index u8) y nibbles bajo/alto. Es el IMA estándar y se implementa desde la especificación pública.
  - Los de `sounds.wad` son PCM crudo; `sfx_english.wad` puede traer los dos.
- **`SSET`:**
  - Formato: nombre de 4 caracteres, `u32` con la cantidad de entradas, y por cada entrada un tipo de 4 caracteres, `u32 n` y `n` nombres de `SAMP` (variantes).
  - Tipos: `Xdie`, `Xdam`, `Xatt`, `Xcnt`, `Xann`, `Xinc`, `TNT1-3`, `grp0-9`, `attU`, `movG`…
  - Sets especiales: `spel` es el mundo (66 entradas: `Xsac`, `Xgib`, `SUMN`, `Xfbl`…, más ambiente `A*`). `advi` es el consejero (22 avisos: `dese`, `lowm`, `orng`, `sacc`, `watt`, `bdam`…).
- **Qué set usa cada uno:** el `CRE8` de `spells.wad` dice `creatureSSET` y `meleeSSET`; el `WIZD` dice `wizardSSET`. Hoy `export_stats.py` no los exporta.
- **Cuándo suena cada cosa:**
  - Los efectos suenan en un punto o siguen a un objeto, con atenuación lineal hasta 200 m. El manantial (`font`), el manalito (`mlth`) y el altar (`afir`) suenan en bucle. El consejero tiene un canal con cola y prioridad.
  - Música:
    - El tema `normal` del dios suena por defecto.
    - `battle1-5` (al azar) suena mientras el mago local recibió daño en los últimos 120 s.
    - `sacrifice` suena con un ritual a menos de 70 m de la cámara.
    - `winning` o `losing` suena durante una profanación.
    - `victory` o `defeat` suena una sola vez.
    - Fundido de 0,5 s entre temas.
- **Voces de dioses:** solo están en la campaña. En la escaramuza hay voces de magos, de criaturas y del consejero.

## 3. Objetivo (criterios de aceptación)

- **Sets de sonido:**
  - Cada criatura, mago, hechizo, la UI y el consejero tienen un `SoundSet` (`.tres`).
  - Cada dios tiene un `MusicSet` y un `AmbienceSet`.
  - Un humano agrega sonidos propios (`.ogg` o `.wav`) sin escribir código, también para las criaturas propias de RFC-051.
- **Importador:**
  - `tools/import/import_audio.py` necesita la instalación original y lo dice. Si no la encuentra, falla con el mensaje en español de `install.py` (código 2).
  - Sin los assets importados el juego corre en silencio, sin errores ni warnings de audio.
  - Nada lee el original en tiempo de ejecución.
- **Qué suena:**
  - Efectos 3D posicionales en el mundo y 2D en la UI, con límite de voces, pool y enfriamiento por cue.
  - Música por dios: calma, batalla, sacrificio, ganando o perdiendo, victoria o derrota. La batalla depende de la intensidad del combate cerca del jugador.
  - Ambiente por dios, y voces de magos, criaturas y consejero.
- **Buses y opciones:** buses `Master`, `Music`, `SFX`, `Voice` y `Ambience`. Opciones → Sonido tiene un slider por bus y se guarda en `user://settings.cfg`, sección `[audio]`.
- **Solo en el cliente:**
  - Sin RPC nuevas, sin tocar la simulación ni el generador global.
  - `agent/run_determinism.sh quick` da los mismos digests, sin regrabar.
  - El dedicado, el servidor de salas y los procesos headless no cargan ningún `AudioStream`.

## 4. Escena de prueba

`res://debug/audio/f360_audio_lab.tscn` (script `debug/audio/audio_lab.gd`).

- **Qué instancia:**
  - Dos `scenes/units/unit.tscn`: una criatura con set original (por ejemplo `zomb`) y la criatura propia de prueba de RFC-051.
  - Un `wizard_body.tscn`.
  - `ListenerFocus` sobre un `Camera3D` fijo.
  - `MusicDirector` con `data/audio/music/james.tres` y `AmbienceDirector` con `data/audio/ambience/james.tres`.
- **Estado inicial:**
  - Todo quieto: música en `calm`, ambiente sonando, `SoundLog` vacío.
  - Un `Label` muestra el último evento (`<emisor> <evento> <stream>`) y el pico de los cinco buses.
- **Modo manual:** la acción nueva `debug_audio_event` recorre estos eventos: `selected`, `swing`, `damaged`, `shoot`, `death`, `cast`, `fx`, `battle` (fuerza `CombatGauge` a 1) y `victory`.
- **Modo automático:** `--headless -- --audio-probe --audio-script` los recorre solo, imprime `AUDIO_LAB PASS|FAIL <evento> <stream>` y sale en segundos.
- **Variantes por corte:** son `.tres` de tipo `AudioLabScript` (`debug/audio/lab_<corte>.tres`), no otro `.gd`.

Opciones → Sonido se prueba desde `boot.tscn` → Opciones.

## 5. Árbol de archivos

```
game/
├── default_bus_layout.tres                  NUEVO  Master > Music, SFX, Voice, Ambience
├── project.godot                            CAMBIA autoload SoundBus (después de FxBus), bus layout, acción debug_audio_event
├── scenes/audio/                            NUEVO dominio
│   ├── README.md
│   ├── sound_event.gd          SoundEvent      constantes StringName del vocabulario de eventos
│   ├── sound_cue.gd            SoundCue        Resource: variantes y reglas de un evento
│   ├── sound_set.gd            SoundSet        Resource: evento -> SoundCue
│   ├── music_set.gd            MusicSet        Resource: humor -> streams (por dios)
│   ├── ambience_set.gd         AmbienceSet     Resource: fondo en bucle + sueltos al azar
│   ├── fx_sound_map.gd         FxSoundMap      Resource: nombre de FX de FxBus -> SoundCue
│   ├── audio_prefs.gd          AudioPrefs      Resource compartido (data/ui/audio_prefs.tres), sección [audio]
│   ├── audio_gate.gd           AudioGate       static: ¿este proceso tiene audio?
│   ├── sound_library.gd        SoundLibrary    static: tag -> SoundSet/MusicSet/AmbienceSet
│   ├── sound_log.gd            SoundLog        RefCounted: anillo de los últimos N pedidos (pruebas y lab)
│   ├── sound_bus.gd            (autoload)      pools 3D/2D, límites, RNG propio, AudioPrefs, puente FxBus, clics de UI
│   ├── sound_emitter_3d.gd/.tscn SoundEmitter3D AudioStreamPlayer3D con @export cue (al aparecer / en bucle)
│   ├── listener_focus.gd       ListenerFocus   AudioListener3D en el mago local, orientado con la cámara
│   ├── unit_sounds.gd          UnitSounds      hijo de unit.tscn: modo/golpe/disparo/daño/muerte -> SoundSet
│   ├── wizard_sounds.gd        WizardSounds    hijo de wizard_body.tscn: encantamiento, daño, muerte/fantasma
│   ├── command_voice.gd        CommandVoice    selección y acuse de órdenes (solo local)
│   ├── advisor_voice.gd        AdvisorVoice    avisos y rechazos con cola y prioridad (un canal, bus Voice)
│   ├── ritual_sounds.gd        RitualSounds    hijo de ritual.tscn: fases del sacrificio
│   ├── combat_gauge.gd         CombatGauge     intensidad 0..1 cerca del oyente (estado replicado)
│   ├── music_mood.gd           MusicMood       static pura: entradas -> humor
│   ├── music_director.gd/.tscn MusicDirector   dos AudioStreamPlayer con fundido cruzado, bus Music
│   └── ambience_director.gd/.tscn AmbienceDirector fondo 2D + sueltos 3D alrededor del oyente, bus Ambience
├── scenes/ui/options/audio_tab.gd/.tscn     NUEVO  pestaña «Sonido»: 5 sliders + silenciar
├── scenes/ui/options/options_menu.tscn      CAMBIA instancia AudioTab
├── scenes/units/unit_body.gd                CAMBIA señales swung, shot_started, mode_changed(was, now) en los setters existentes
├── scenes/units/unit.tscn                   CAMBIA hijo UnitSounds
├── scenes/wizards/wizard_body.tscn          CAMBIA hijo WizardSounds
├── scenes/fx/fx_bus.gd                      CAMBIA signal played(kind, name, at) (local, en cada par)
├── scenes/match/match.tscn                  CAMBIA MusicDirector, AmbienceDirector, CombatGauge, CommandVoice, AdvisorVoice, ListenerFocus
├── scenes/core/boot.tscn                    CAMBIA MusicDirector en modo menú
├── scenes/spells/*_projectile.tscn          CAMBIA SoundEmitter3D por proyectil
├── scenes/map/props/ (manantial, altar, manalito) CAMBIA SoundEmitter3D en bucle
├── scenes/sacrifice/ritual.tscn             CAMBIA hijo RitualSounds
├── scenes/core/catalog/original_assets.gd   CAMBIA rutas de assets/original/audio/
├── data/audio/                              NUEVO
│   ├── README.md
│   ├── creatures/<tag>.tres, wizards/<tag>.tres   SoundSet (horneado; editable)
│   ├── world.tres, advisor.tres, ui.tres, fx_sounds.tres
│   ├── music/<god>.tres, music/menu.tres          MusicSet
│   └── ambience/<god>.tres                        AmbienceSet
├── data/ui/audio_prefs.tres                 NUEVO
├── assets/original/audio/                   NUEVO (lo escribe el importador; LFS, ver §14.1)
│   ├── sfx/<carpeta>/<nombre>.wav, voice/<carpeta>/<nombre>.wav, music/<slug>.mp3
│   └── index.json                           sets SSET y tipos -> sets
├── assets/custom/sounds/<kind>/<tag>/<event>[_n].{ogg,wav}   NUEVO (convención para contenido propio)
├── tools/import/import_audio.py             NUEVO  requiere el original
├── tools/import/sac_formats/{samp.py,sset.py} NUEVO lectores (SAMP + IMA ADPCM, SSET); offsets SSET en CRE8/WIZD
├── tools/bake/bake_sound_sets.gd            NUEVO  no requiere el original: index.json + assets/custom -> data/audio/*.tres
├── tools/bake/new_creature.gd               CAMBIA hornea el SoundSet si hay assets/custom/sounds/creatures/<tag>/
├── addons/sacrifice_tools/plugin.gd         CAMBIA «Hornear sonidos»
├── debug/audio/                             NUEVO lab, AudioLabScript, lab_<cut>.tres y casos:
│   ├── audio_gate_cases.gd, audio_prefs_cases.gd, sound_bus_cases.gd, music_mood_cases.gd
│   └── fixtures/custom_sounds/              dos .wav cortos generados (sin datos del original)
├── debug/suite/catalog_cases.gd             CAMBIA valida data/audio (rutas existen; un set propio no nombra assets/original)
├── agent/flows/audio_*.json                 NUEVO  pruebas con ventana (log + picos de bus)
└── docs/HOWTO.md                            CAMBIA «Sonidos propios» y «Importar el audio del original»
```

## 6. Responsabilidades (un dueño por cosa)

| Pieza | Es dueño de | No hace |
|---|---|---|
| `AudioGate` | Decidir si hay audio. No hay en `--dedicated`, `--room-server` ni headless, salvo con `--audio-probe` | Cargar nada |
| `SoundLibrary` | Resolver un tag a su `.tres` y cachearlo; con el gate cerrado devuelve `null` | Tocar sonidos |
| `SoundBus` | Tocar cues: pools 3D (32) y 2D (8), `max_voices` y `cooldown_s` por cue, prioridad, RNG propio y `SoundLog`. También aplica `AudioPrefs` y conecta `FxBus.played` y los `BaseButton` | Decidir *cuándo* suena algo del juego |
| `UnitSounds`, `WizardSounds`, `RitualSounds` | Pasar estado replicado o señales locales a eventos | Leer o escribir la simulación |
| `CommandVoice`, `AdvisorVoice` | Las voces locales del jugador | Agregar RPC |
| `CombatGauge` | La intensidad cerca del oyente y el daño reciente al mago local, con histéresis | Elegir música |
| `MusicMood` | Una función pura de entradas a humor | Tocar |
| `MusicDirector` | Fundido cruzado, pista de batalla con RNG propio, temas que suenan una vez | Calcular intensidad |
| `AmbienceDirector` | Fondo y sueltos al azar por dios | — |
| `import_audio.py` | Pasar el original a `assets/original/audio/` | Escribir `data/` |
| `bake_sound_sets.gd` | Pasar `index.json` y `assets/custom/sounds/` a `data/audio/*.tres`. No pisa lo que existe salvo con `--force` | Leer el original |

## 7. Resources, nodos y `@export`

- **Resources de tipo** (no se modifican en tiempo de ejecución):
  - `SoundCue`: `streams`, `volume_db`, `pitch_jitter`, `bus`, `max_distance_m`, `unit_size`, `max_voices`, `cooldown_s`, `priority`.
  - `SoundSet`: `cues: Dictionary[StringName, SoundCue]` y `fallback: SoundSet`.
  - `MusicSet`, `AmbienceSet`, `FxSoundMap`, y `AudioPrefs` (compartido).
- **Nodos:** todo lo de `scenes/audio/` cuyo nombre termina en `Sounds`, `Voice`, `Director`, `Gauge` o `Focus`, más `SoundEmitter3D`. Para apagar uno, se lo saca del árbol.
- **`@export` de instancia:**
  - Sockets (`body`, `health`, `caster`, `selection`, `command_log`, `world`, `camera`). Los obligatorios llevan `@tool` y `_get_configuration_warnings()`.
  - Perillas de `CombatGauge`: `radius_m`, `enter`, `exit`, `hold_s`, `wizard_damage_s = 120`.
  - `AdvisorVoice`: `refusal_events`, `cooldown_s`.
  - `MusicDirector.set` y `AmbienceDirector.set`.
- **Sin campo nuevo en `CreatureType` ni en `WizardType`.** El set se encuentra por convención en `data/audio/creatures/<tag>.tres`, así el catálogo que lee el dedicado no carga audio.

## 8. Red y determinismo

- **Ninguna RPC nueva.** El cliente deduce cada sonido de lo que ya recibe (§1). Los FX de `FxBus.broadcast*` llevan su sonido por `FxSoundMap`.
- **El audio no escribe en la simulación.** Las señales nuevas de `UnitBody` se emiten en setters que ya existen.
- **RNG.**
  - `SoundBus` y `MusicDirector` usan generadores propios.
  - Quedan prohibidos `randf()`, `randi()`, `AudioStreamRandomizer` y el modo shuffle de `AudioStreamPlaylist`, porque pueden sacar su azar del generador global.
  - En 052a, `sound_bus_cases` lo mide: siembra el global, toca un randomizer y compara el siguiente `randi()`.
- **Dedicado y headless.** El gate está cerrado: ningún componente llega a `load()`. `audio_gate_cases` lo mide con `ResourceLoader.has_cached(<stream>) == false` después de un tick de partida.
- **Banco.** `quick` tiene que dar los mismos digests. Si cambia uno, es un bug de este RFC.

## 9. Cortes

Reglas para todos los cortes:
- Las pruebas corren en headless, en cola (`agent/harness/godot_run.sh`) y tardan segundos.
- «Ventana» marca los cortes que necesitan prueba con ventana. El audio no se juzga de oído: el criterio es una entrada en `SoundLog` (emisor, evento, stream, tick) y que el pico del bus pase de -60 dB mientras suena.

| Corte | F | Qué | Criterio | Prueba rápida | Ventana |
|---|---|---|---|---|---|
| **052a** buses y opciones | F360 | `default_bus_layout.tres`, `AudioGate`, `AudioPrefs`, `AudioTab`, `SoundBus` (pools, log, RNG), `SoundCue`/`SoundSet`, `SoundLibrary` | Opciones → Sonido: 5 sliders y «Silenciar», que guardan y leen `[audio]`. Con `--dedicated` no se crea ni carga nada. Caso del generador global | `audio_prefs_cases`, `audio_gate_cases`, `sound_bus_cases` | Sí: la pestaña se ve y un slider cambia `get_bus_volume_db` |
| **052b** importar el original | F361 | `import_audio.py`, `samp.py`/`sset.py`, offsets SSET, `index.json`, `OriginalAssets` | Con instalación: 388 + 2488 `.wav` y 17 `.mp3`, y `--check` idempotente. Sin instalación: código 2 con el mensaje. `bake_sound_sets` escribe los sets | `SAC_INSTALL=/nada … import_audio.py` → 2; `--check`; `catalog_cases` | No |
| **052c** unidades y magos | F362 | `UnitSounds`, `WizardSounds`, señales de `UnitBody`, `ListenerFocus` | Suenan `swing`, `damaged` (a lo sumo una vez cada 1,5 s), `death`, `summon` e `incantation`. Sin set: silencio sin warning. Igual en solo y como cliente de un dedicado | `lab_052c.tres`; `quick` igual | Sí: `audio_units.json` |
| **052d** FX, hechizos y edificios | F363 | `FxBus.played`, `FxSoundMap`, `SoundEmitter3D` | `FxBus.play("blood")` queda en el log. Los proyectiles suenan al aparecer y en bucle; manantial, manalito y altar, en bucle. Con 200 pedidos por cuadro hay ≤ 32 voces 3D | `lab_052d.tres`; `sound_bus_cases` | No |
| **052e** voces del jugador | F364 | `CommandVoice`, `AdvisorVoice` | Responden a la selección y a las órdenes. Avisos: `no_mana` → `lowm`, profanación → `dese`, mago atacado → `watt`. La cola respeta la prioridad | `lab_052e.tres` | No |
| **052f** música | F365 | `CombatGauge`, `MusicMood`, `MusicDirector`, `MusicSet` | Menú en boot. En partida, `calm` del dios; `battle` con intensidad ≥ `enter`, y sale tras `hold_s`. `sacrifice` con un ritual a < 70 m; `winning` o `losing`; `victory` o `defeat` una vez | `music_mood_cases`; `lab_052f.tres` | Sí: `audio_music.json` |
| **052g** ambiente | F366 | `AmbienceDirector`, `AmbienceSet` | El fondo del dios suena al aplicar el bioma; los sueltos usan el intervalo y el radio del `.tres` | `lab_052g.tres` | Sí, con 052f |
| **052h** UI y sacrificio | F367 | Clics en botones (meta `no_ui_sound` para excluir), libro y menú X, `RitualSounds`, almas | Los botones hacen `Mcl1`. El ritual toca `Xsac` por ronda y `Xgib` al final. Las almas hacen `spir` | `lab_052h.tres` | No |
| **052i** contenido propio | F368 | Convención `assets/custom/sounds/`, `bake_sound_sets`, `new_creature`, plugin, HOWTO | Dos `.wav` del fixture → «Hornear sonidos» → `data/audio/creatures/<tag>.tres` → el lab los toca. No usa nada del original | `lab_052i.tres` | No |
| **052z** cierre | F369 | Pasada completa | `run_determinism.sh all` igual. Partida solo de 5 min con ventana: ningún bus satura y no hay `FAIL` | Banco `all` | Sí |

052c a 052h se prueban sin el original, usando el fixture de 052i.

## 10. Riesgos

1. **Generador global (§8).** Es el riesgo principal para el banco. Se mide primero, en 052a.
2. **Tamaño.** Son unos 200 MB de `.wav` y 26 MB de `.mp3` (ver §14.1).
3. **Señales en un cliente remoto.** En 052c hay que confirmar que `Health.changed` y el setter de `mode` se disparan en el cliente. Si alguna señal es solo del servidor, el sonido se deduce del estado replicado; nunca con una RPC nueva.
4. **Oyente.** Con la cámara alta, atenuar desde la cámara no sirve. `ListenerFocus` pone el oyente en el mago local.
5. **Bajo AgentKit, `Master` arranca en 0** salvo con `--audio-on`. El log y los picos se miden antes del bus Master.
6. **`bake_sound_sets --force` pisa lo editado a mano.** Tiene el mismo aviso que `bake_catalog`.
7. **Port web.** MP3 y QOA andan en web, pero no se prueban acá.

## 11. Fuera de alcance

- Campaña y voces de dioses.
- Subtítulos.
- Música por mapa (va por dios).
- Reverb por zona.
- Otros idiomas (solo `sfx_english`).
- Excluir el audio del export del dedicado.
- Port web.

## 12. Orden

1. CR-003.
2. 052a.
3. 052i parcial (fixture y `bake_sound_sets` sobre `assets/custom`).
4. 052b.
5. 052c → 052d → 052e → 052f + 052g → 052h.
6. 052i completo.
7. 052z.

## 13. Cómo lo verifica un humano en el editor

- **Buses:** `default_bus_layout.tres` en el panel Audio muestra 5 buses bajo `Master`.
- **Sets:** `data/audio/creatures/zomb.tres` en el inspector muestra un cue por evento; ▶ toca un stream.
- **Sonidos propios:** dos `.ogg` en `assets/custom/sounds/creatures/<tag>/death_1.ogg`, `death_2.ogg` → Project > Tools > Sacrifice > «Hornear sonidos» → aparece el `.tres`.
- **Lab:** F6 sobre `debug/audio/f360_audio_lab.tscn` y pulsar `debug_audio_event`.
- **Opciones:** F5 → Opciones → Sonido: los sliders persisten al reabrir. En partida, la música pasa a batalla al pelear y vuelve a calma.
- **Dedicado:** `--dedicated` arranca igual y sin `AudioStream` en caché.

## 14. Decisiones (las tomó el orquestador; el usuario puede cambiarlas)

1. **El audio importado del original se versiona por Git LFS.** Decisión del usuario, 2026-10-19.
   - Pesa unos 103 MB:
     - efectos: 388 WAV PCM16, 34 MB;
     - voces de escaramuza en inglés: 2481 archivos en Ogg Vorbis q4, 42 MB (en WAV serían 168 MB);
     - música: los 17 MP3 completos, campaña incluida, 27 MB.
   - No entran los diálogos de campaña ni otros idiomas.
   - El MP3 se descarta para efectos y bucles: agrega 50 ms de silencio al principio.
   - Para comprimir, el importador usa ffmpeg (`--codec`). Si no lo encuentra, guarda WAV y avisa. Solo lo necesita quien importa.
   - Los sets del original se hornean versionados en `data/audio/`. Los propios van en `data/audio/custom/`, que tiene prioridad.
   - Un set cuyos streams faltan (por ejemplo, en un clon sin LFS) se saltea con `SoundLibrary.has_dependencies()`, sin error.
2. **Sin el original suena silencio**, no sonidos de relleno.
3. **Bajo AgentKit, `Master` en 0** salvo con `--audio-on`.
4. **La música de batalla se activa por cualquiera de dos condiciones:** intensidad cerca del oyente, o daño al mago local en los últimos 120 s, como el original.
5. **Pasos (`foot`):** quedan fuera por ahora; el evento existe vacío en los sets.
