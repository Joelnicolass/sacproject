> **Nota del orquestador (2026-10-25):** este plan se escribió como «055k», pero en RFC-055 la letra 055k es la **cámara** (C-8a) y los IDs no se renumeran. El audio pasa a ser **055o**, un corte propio que junta lo de audio que la auditoría repartía entre 055i (`CreatureType.sounds`) y 055x (el sonido dentro del FX). La pregunta 1 del plan (qué letra lleva la cámara) queda resuelta: la cámara sigue siendo 055k.

# 055o — Audio por recursos tipados (plan del tech lead, pendiente de aprobación)

Fuente: RFC-055 §13.2b fila C-8d, auditoría `research/055R-legacy-audit.md` §3.8 (fila Audio) y §3.1, CONVENTIONS §2b (C17, C21) y §2c. Medido en `main` al 2026-10-25 (`be9943c8`), rutas relativas a `game/`.

**Contradicciones entre artefactos (gana lo que se cita):**
- **Nombre del corte.** RFC-055 §13.2b fila C-8a y §15 llaman **055o a la cámara** (`Curve` de zoom), y la fila de audio C-8d la reparte entre 055i-b y 055x. El orquestador llama ahora 055o al audio. En este plan, 055o es el audio. Hay que darle otra letra a la cámara (pregunta 1). El «055o-a» que aparece en el orden de 055R §4, paso 3, era la cámara.
- **RFC-052 contra C17/C21.** RFC-052 (y `AudioGate`) pide que el servidor, los bancos y los headless «never load an AudioStream». Por eso hoy todo se nombra por texto y se resuelve tarde. Una referencia tipada (`@export var cue: SoundCue`) carga los streams al cargar la escena o el `.tres`. Gana RFC-055/CONVENTIONS (más nuevo, aprobado por el usuario: «una referencia es un tipo»), pero el costo se mide antes de seguir (055o-a paso 1, pregunta 2).
- **El audio del original «sin el original».** Hoy `SoundLibrary` saltea un set cuyos archivos faltan (`ResourceDeps`) y el lab corre `--audio-no-original`. `assets/original/audio/` está versionado por LFS, igual que los modelos, y un clon lo trae. El «sin el original» de la memoria es *sin la instalación del juego*. Con referencias tipadas, un stream que falta aborta la carga del `.tres` que lo nombra (Godot por defecto aborta ante dependencias faltantes). Esto está **NO VERIFICADO** en 4.7 y se mide en 055o-a paso 1 (pregunta 3).

## Objetivo (criterios de aceptación)
- Cada sonido que el juego toca sale de un `SoundCue`/`SoundSet`/`MusicSet`/`AmbienceSet` asignado por `@export` (o embebido) en el recurso o la escena que suena. Cero búsquedas por ruta, por tag o por clave de texto en `scenes/`.
- `CreatureType.sounds` y `WizardType.sounds` son `SoundSet`. `GodType.music` es un `MusicSet` y `GodType.ambience` es un `AmbienceSet`. El sonido de un FX vive en su `ParticleType`/`BeamType` o en su escena. Se borran `FxSoundMap`, `data/audio/fx_sounds.tres` y `SoundLibrary`.
- **Se mantienen** `SoundBus`, el pool (32 voces 3D + 8 voces 2D, prioridad, `cooldown_s`, `max_voices`, RNG propio), `SoundCue`, `SoundSet` (ahora con campos con nombre), `AudioGate`, `SoundLog` y el `default_bus_layout`.
- En solo, en un listen-server y en el cliente de un dedicado suena lo mismo que hoy (paridad de streams 100 %, lab y `run_audio_net.sh` verdes). Un late join no reproduce de nuevo los one-shots.
- Lint: C17 (ampliado al sonido) baja 130, C18 −2, C9 −28, C15 −4, C1b −1, y no sube ninguno.

---

## 1. Inventario

### 1.1 Búsquedas por texto, ruta o tag (los 130 que mide C17 ampliado, §6)

| Tipo | Dónde (archivo:línea) | Cuántos |
|---|---|---|
| Por ruta | `SoundLibrary.find(rel)` / `find_all` / `sound_set` con `"creatures/%s"`, `"wizards/%s"`, `"music/<dios>"`, `"ambience/<dios>"`, `"advisor"`, `"ui"`, `"world"`, `"fx_sounds"`: `sound_library.gd:23,36,59,74,80`, `music_director.gd:94,96`, `ambience_director.gd:65`, `advisor_voice.gd:130`, `body_sounds.gd:41`, `sound_bus.gd:124,136` | 17 llamadas en `scenes/` (`SoundLibrary.`, `SoundBus.lookup/fx_cue`, `FxSoundMap`) |
| Por tag | `SoundLibrary.creature(body.creature_tag)` (`unit_sounds.gd:39`, `command_voice.gd:77`) y `.wizard(body.wizard_tag)` (`wizard_sounds.gd:46`). Por dentro llaman `GameData.creature/wizard(tag)` (`sound_library.gd:74,80`, **C18 = 2**) y el nombre del archivo del catálogo (`EHTH` → `EHTH_2`) | 3 + 2 C18 |
| `@export` de texto | `SoundEmitter3D.source := "fx_sounds"` y `.cue: StringName` (`sound_emitter_3d.gd:17,19`), `BodySounds.shared_set := "world"` (`:18`), `SoundBus.ui_set` / `ui_click_key` (`:46-47`), `MenuSounds.ui_set` (`:15`), `MusicDirector.set_path` / `fallback_path` (`:23,25`), `AmbienceDirector.set_path` (`:16`), `AdvisorVoice.set_path` (`:26`), `AmbienceSet.one_shot_source` (`:15`) | 12 |
| Códigos del original en `@export` | `AdvisorWatch`: `wizard_attacked := &"watt"` … `sacrifice_complete := &"sacc"` (`advisor_watch.gd:29-36`) | 8 |
| Diccionarios de texto | `SoundSet.cues: Dictionary[StringName, SoundCue]` (`sound_set.gd:9`), `BodySounds.aliases {swing: Xhit, shoot: swing}` (`:16`), `CommandVoice.aliases` (`:44`, `attack_ack` → `Xcat`, `annoyed` → `Xann`), `AdvisorVoice.refusal_events/priorities/cooldowns` (`:28,38,50`), `MenuSounds.cues/events` (`:17,19`) | 7 |
| Claves en los datos | `.tscn`/`.tres` con `cue = &"…"` (74 nodos `SoundEmitter3D` en 39 escenas), `source = "world"` (4: `Xquk` ×2, `Xanm`, `Xfbl`), `set_path = "music/menu"` (`boot.tscn:149`), `fallback_path`, `metadata/ui_sound` (`spell_slot.tscn`), `one_shot_keys` (5 `ambience/<dios>.tres`) | 86 líneas |
| Nombre del FX → sonido | `FxBus.played(kind, fx_name, at)` → `SoundBus._on_fx_played` → `FxSoundMap.fx_cue` (`sound_bus.gd:438-442`). Las 99 claves de `fx_sounds.tres` son: **31 nombres de `ParticleType`**, **6 de `BeamType`**, **5 nombres de archivo de escena** (`explosion_burst`, `ice_shatter`, `quake_ring`, `spike_field`, `wall_spike`), **56 claves de `SoundEmitter3D`** y **1 huérfana** (`wall_vine_up`). `ShakeMap` usa `FxSoundMap.key_of` (`shake_map.gd:24`) | 99 claves |
| Raíces que se pisan | `SoundLibrary.roots = [data/audio/custom/, data/audio/]` y `find_all` clave por clave: un `custom/` pisa por nombre de archivo | 1 mecanismo |

Conteos del lint en `scenes/audio/` hoy: **C9 28**, C1a 5 (`advisor_voice` 165, `advisor_watch` 157, `combat_gauge` 160, `music_director` 205, `sound_bus`), **C1b 1** (`sound_bus.gd` 450), **C15 4** (`AudioStreamPlayer.new()` en `advisor_voice:79`, `ambience_director:39`, `command_voice:64`, `music_director:57`; el pool de `sound_bus` está en la allowlist), C6 4, C5 2, C12 3, **C18 2**, **C17 0** (el patrón de hoy no ve `cue`/`source`/`set_path`: ver §6). Los 23 C17 que quedan son `FxBus.broadcast("…")` y pasan a 055x.

El disparo por texto fuera de `scenes/audio/`: `ReachedCue` (`spells/carrier/reached_cue.gd`, del corte anterior) ya va por nodo (`@export var sound: SoundEmitter3D`) y solo hereda la clave `soul_mole_take`. `wall_spike.tscn` existe solo para que el nombre de archivo suene distinto (`spks`). `AfflictionCues`, `ZoneSound`, `WallSound`, `BoreDrill`, `Altar` y `ManafountBody` ya mandan a un `SoundEmitter3D` hijo, y solo heredan la clave.

### 1.2 Lo copiado 1 a 1 del original
- `SoundEvent.CREATURE_CODES` (6), `WORLD_CODES` (4) y `UI_CODES` (1): **las 11 claves de texto**, códigos `SSET` del original pasados a eventos (`sound_event.gd:50-69`). Solo las usa el horneado.
- Los sets agrupados como en el WAD: `world.tres` = set `spel` (66 claves: sacrificio, alma, invocación, códigos de hechizos `X*` y ambiente `A*`), `ui.tres` = `ifac` (11 claves, 4 usadas), `advisor.tres` = `advi` (22 claves, 14 usadas).
- Claves horneadas con el código del original, que el código traduce con `aliases`: `Xhit`, `Xcat`, `Xann`. Las que nadie toca: `Xres` 67, `Xrun`/`Xhrd`/`Xgat`/`Xfrm`/`Xcow` 6 cada una, y en los 15 magos, 39 códigos de órdenes (`grp0-9`, `asg0-9`, `att*`, `grd*`, `f*`, `TNT1-4`).
- Los nombres de archivo de los sets salen del archivo del catálogo (`EHTH_2.tres`, `cwa0.tres`, `_hfae`), y el juego los encuentra por convención.
- El consejero: 14 códigos `advi` de 4 letras como claves, con prioridades y silencios «como el original».
- Las claves `Xquk`, `Xanm` y `Xfbl` en `source = "world"` de 4 escenas de hechizos.
- `SoundEmitter3D` one-shot «does not follow the node: the original does not either» (es una regla razonable; se mantiene con `## Ref:` al final).
- 28 encabezados `##` que abren con `RFC-052 052x (Fxxx)` en lugar de decir qué hacen (C9).

**Razonable, se mantiene:** el pool de 32+8 con prioridad, la caída lineal a 200 m (`SoundCue.max_distance_m`), los silencios del consejero como valores de datos, `annoy_after`, las voces solo para el jugador local, la música por humor (`MusicMood` pura) y que el audio sea solo presentación.

---

## 2. Árbol de archivos

```
scenes/audio/
  [~] README.md                         5 líneas What/Not/Talks to/Edit/Check; fuera "SoundLibrary", raíces y claves
  [+] sound_bus.tscn                    autoload como escena: knobs en el inspector (pool, max_loops_3d, click: SoundCue)
  [~] sound_bus.gd                      ≤150: play_3d/2d/on, claim/release_loop, prefs, log; fuera lookup/fx_cue/ui_set/FX_MAP
  [+] voice_pool.gd                     VoicePool (RefCounted ≤150): voces, _pick_voice, presupuesto 3D con bucles
  [+] ui_click_sounds.gd                UiClickSounds (hijo de SoundBus ≤60): engancha BaseButton; meta ui_sound = SoundCue
  [+] fx_sounds.gd                      FxSounds (hijo de SoundBus ≤50): FxBus.played → type.sound (ParticleType/BeamType)
  [~] sound_set.gd                      SoundSet: campos con nombre (selected, ack, attack_ack, annoyed, swing, shoot,
                                        damaged, death, summon, incantation, ghost) + fallback: SoundSet; fuera `cues`
  [~] sound_cue.gd                      sin cambios de campos; doc sin abrir citando el original
  [~] sound_event.gd                    solo los nombres de evento para SoundLog; fuera *_CODES (van al migrador)
  [~] sound_emitter_3d.gd               @export var cue: SoundCue (warning si falta); fuera source, lookup y restart()
  [~] body_sounds.gd                    own_set() = type.sounds; fuera aliases, shared_set y SoundLibrary
  [~] unit_sounds.gd                    body.type.sounds; @export var summon: SoundCue (el de todas las criaturas)
  [~] wizard_sounds.gd                  body type .sounds
  [~] command_voice.gd                  unit.type.sounds; fuera aliases; Channel = hijo del .tscn
  [~] menu_sounds.gd                    @export opened/chosen/cancelled: SoundCue (un solo usuario: el radial)
  [~] ritual_sounds.gd                  @export round, finished, converted: SoundCue
  [~] soul_sounds.gd                    @export collected: SoundCue
  [~] music_set.gd, ambience_set.gd     AmbienceSet: fuera one_shot_source/one_shot_keys (los A* van a one_shots)
  [~] music_director.gd(.tscn)          @export music: MusicSet, default_music: MusicSet; biome → god.music; players en .tscn
  [~] ambience_director.gd(.tscn)       @export ambience: AmbienceSet; biome → god.ambience; Bed en .tscn
  [+] advisor/advisor.tscn              AdvisorVoice + AdvisorWatch + Channel, con las 14 líneas embebidas
  [+] advisor/advisor_line.gd           AdvisorLine (Resource): cue: SoundCue, priority, quiet_s
  [~] advisor_voice.gd → advisor/       say(line: AdvisorLine); refusal_lines: Dictionary[StringName, AdvisorLine]
                                        (claves = Refusal.*, warning si alguna no existe); fuera priorities/cooldowns
  [~] advisor_watch.gd → advisor/       8 @export AdvisorLine en lugar de códigos; Health tipado (fuera C5/C6)
  [~] combat_gauge.gd                   C5/C6: grupo por const de UnitBody; Health tipado
  [-] sound_library.gd                  búsqueda por ruta/tag y raíces (borrado)
  [-] fx_sound_map.gd                   nombre del FX → sonido (borrado)
  [-] resource_deps.gd                  → se mueve a debug/suite/ (solo lo usa catalog_cases), o se borra (pregunta 3)
  [ ] audio_gate, audio_prefs, sound_log, voice_queue, music_mood, listener_focus: sin cambios (salvo C9)
scenes/units/[~] creature_type.gd       + @export var sounds: SoundSet
scenes/wizards/[~] wizard_type.gd       + @export var sounds: SoundSet
scenes/gods/[~] god_type.gd             + @export var music: MusicSet, ambience: AmbienceSet
scenes/fx/[~] particle_type.gd, beam_type.gd   + @export var sound: SoundCue (null = sin sonido)
scenes/fx/[~] fx_bus.gd                 play_scene ubica el nodo ANTES de add_child (el emisor one-shot suena donde va)
scenes/fx/[~] shake_map.gd              key_of propio (deja de nombrar FxSoundMap)
scenes/fx/[~] explosion_burst, ice_shatter, quake_ring, spike_field, wall_spike .tscn   + hijo Sound (SoundEmitter3D)
scenes/spells/**, scenes/map/props/{altar,manafount}.tscn, units/afflictions/**   [~] 39 escenas: cue = ExtResource(cue)
scenes/spells/carrier/[~] reached_cue.gd   escucha un estado replicado del carrier, no `reached` del servidor (§4)
scenes/units/[~] unit.tscn              UnitSounds.summon = data/audio/cues/summon.tres
scenes/sacrifice/[~] ritual.tscn · scenes/souls/[~] soul.tscn   cues tipados
scenes/ui/radial/[~] radial_menu.tscn · scenes/ui/spell_book/[~] spell_slot.tscn   cues tipados (055o-d, después de 055h)
scenes/core/[~] boot.tscn               MusicDirector.music = data/audio/music/menu.tres
scenes/match/[~] match.tscn             AdvisorVoice/AdvisorWatch → instancia de advisor.tscn (pregunta 6: MatchAudio)
project.godot                           [~] SoundBus="*res://scenes/audio/sound_bus.tscn"
data/audio/
  [~] README.md                         cómo se asigna un sonido; fuera "dónde busca", raíces y tabla SSET
  [+] cues/<nombre>.tres                los 98 cues de fx_sounds con nombre humano (fireball_cast.tres, fountain_loop.tres,
                                        heal.tres...) + summon, sacrifice_round, sacrifice_end, soul, ui_click, ui_book_click,
                                        menu_open, menu_back, quake (Xquk), animate_dead (Xanm), soul_wind (Xfbl)
  [~] creatures/<nombre humano>.tres    67 SoundSet con campos (trogg.tres; el tag queda en el doc del recurso)
  [~] wizards/<nombre humano>.tres      15 · melee/fist|bsaw|stab.tres (fallback de los de arriba, con swing = su Xhit)
  [~] music/*.tres, ambience/*.tres     los A* pasan a one_shots (cues embebidos)
  [-] fx_sounds.tres, world.tres, ui.tres, advisor.tres
data/catalog/creatures/*.tres [~] 72 (sounds = su set; 5 sin set quedan en null) · wizards/*.tres [~] 15
data/gods/*.tres [~] 5 (music, ambience) · data/fx/*.tres [~] 31 + data/fx/beams/*.tres [~] 6 (sound)
tools/
  [+] migrate/migrate_055o_audio.gd     una vez: lee lo de hoy, escribe lo tipado y el informe de paridad; se borra al cerrar
  [-] bake/bake_sound_sets.gd           (parte del original; congelado → borrado, pregunta 5)
  [~] bake/sound_set_writer.gd          escribe un SoundSet con campos; solo lo usa new_creature.gd
  [~] bake/new_creature.gd              asigna CreatureType.sounds al set que crea
  [ ] import/import_audio.py            ya dice «Requiere el juego original instalado (SAC_INSTALL)»; sin cambios
  [~] lint/conventions.sh               C17 ampliado al sonido (§6); baseline nueva
debug/audio/
  [+] sound_refs_cases.gd               sonda tipada (§6), corre en run_audio_cases.sh
  [~] audio_lab*.gd, *_cases.gd, lab_052*.tres   sin roots; los fixtures son SoundSet/SoundCue asignados
  [-] los 6 modos *_no_original de run_audio_cases.sh y --audio-no-original (pregunta 3)
agent/runs/[~] run_audio_cases.sh, run_audio_net.sh  (+ caso late join §4)
```

### Árbol de nodos

`sound_bus.tscn` (autoload):
```
SoundBus (Node, sound_bus.gd)        pool_3d_size 32, pool_2d_size 8, max_loops_3d 8, rng_seed, log_capacity
├── UiClickSounds (ui_click_sounds.gd)   click = data/audio/cues/ui_click.tres
└── FxSounds (fx_sounds.gd)              escucha FxBus.played; KIND_PUFF nunca suena
   (Voice3D_0..31 / Voice2D_0..7 se arman en _ready: pool, allowlist C15)
```

Escena de criatura (`unit.tscn`, fragmento) y su dato:
```
Unit (UnitBody)  type: CreatureType ──► data/catalog/creatures/<x>.tres
├── Health                                 └─ sounds: SoundSet ──► data/audio/creatures/trogg.tres
└── UnitSounds  body, health,                    selected · ack · attack_ack · annoyed · swing · shoot ·
                summon = cues/summon.tres        damaged · death · summon (vacío = el de UnitSounds)
                                                 fallback: melee/fist.tres
```

Escena de hechizo (ejemplo `fireball_projectile.tscn`), igual en las 39:
```
FireballProjectile
└── Sound (SoundEmitter3D)   cue = data/audio/cues/fireball_cast.tres · loop off · play_on_ready on
```

`advisor/advisor.tscn` (instanciada en `match.tscn`):
```
AdvisorVoice (advisor_voice.gd)  command_log (lo asigna match.tscn), max_queued 3
│   refusal_lines { no_mana: LowMana, cooling: NotReady, out_of_range, bad_target, no_target, no_souls, far_from_altar }
├── Channel (AudioStreamPlayer, bus Voice)
└── AdvisorWatch (advisor_watch.gd)  wizard_attacked: WizardAttacked (AdvisorLine: cue, priority IMPORTANT, quiet_s 15) …
```

### Mapa de responsabilidades (dueños)
- **Qué suena:** el recurso o la escena dueña (`CreatureType.sounds`, `ParticleType.sound`, `SoundEmitter3D.cue`, `GodType.music`, la línea del consejero).
- **Cuándo suena:** el nodo `*Sounds`/`*Voice`/`*Director`/`SoundEmitter3D`, a partir de estado replicado o de una señal local.
- **Cómo suena:** `SoundBus` + `VoicePool` (variante, pitch, límites, presupuesto, log).
- **Volumen del jugador:** `AudioPrefs`.
- **¿Hay audio en este proceso?:** `AudioGate`.

Nadie más resuelve sonidos. Ningún nodo escribe en la simulación.

### Qué es Resource de tipo, qué es nodo y qué es `@export` de instancia
- **Resource de tipo (`.tres`, nunca se escribe en runtime):** `SoundCue`, `SoundSet`, `MusicSet`, `AmbienceSet`, `AdvisorLine` (embebidas en `advisor.tscn`). También los campos `sounds`/`music`/`ambience`/`sound` dentro de `CreatureType`, `WizardType`, `GodType`, `ParticleType` y `BeamType`.
- **Nodo:** `SoundBus` (autoload escena), `UiClickSounds`, `FxSounds`, `UnitSounds`, `WizardSounds`, `CommandVoice`, `AdvisorVoice`/`AdvisorWatch`, `MusicDirector`, `AmbienceDirector`, `RitualSounds`, `SoulSounds`, `MenuSounds`, `SoundEmitter3D`, `ListenerFocus`, y los `AudioStreamPlayer` de canal como hijos del `.tscn`.
- **`@export` de instancia:** el `cue` de cada `SoundEmitter3D` en su escena, `UnitSounds.summon`, `MusicDirector.music` (menú en `boot.tscn`), `loop`/`active`/`check_s` y los sockets (`body`, `health`, `caster`, `ghost`, `command_log`).

---

## 3. Cómo lo hace un humano

| Verbo | Ejemplo | Qué abre y qué toca | Lugares |
|---|---|---|---|
| **Entender** | «¿Qué suena cuando muere un trogg?» | `data/catalog/creatures/<trogg>.tres` → `Sounds` → `Death`. El README de `scenes/audio/` dice quién toca qué | 1 |
| **Modificar** | «Bajar el sonido de la bola de fuego» | La escena del hechizo → nodo `Sound` → `Cue` → `Volume Db` (o abrir `data/audio/cues/fireball_cast.tres`) | 1 |
| **Modificar** | «Cambiar la música de un dios» | `data/gods/<dios>.tres` → `Music` → arrastrar otro `MusicSet`, o abrir el set y arrastrar pistas a `Calm` | 1 |
| **Modificar** | «Cambiar el clic de los botones» | `scenes/audio/sound_bus.tscn` → `UiClickSounds` → `Click` | 1 |
| **Agregar** | «Darle un sonido nuevo a un hechizo» | En su escena: instanciar `sound_emitter_3d.tscn` como hijo → `Cue` → Nuevo `SoundCue` → arrastrar el `.ogg` a `Streams`. Si es una ráfaga de partículas: `data/fx/<efecto>.tres` → `Sound` | 1 |
| **Agregar** | «Darle voz a una criatura» | `CreatureType` → `Sounds` → Nuevo `SoundSet` (o duplicar uno) → arrastrar archivos a `Death`, `Selected`… | 1–2 |
| **Quitar** | «Que el manantial no suene» | `manafount.tscn` → borrar el nodo `FountSound` (o vaciar `Cue`) | 1 |
| **Crear** | «Una criatura propia hecha en Blender» | «Nueva criatura desde modelo…» crea la ficha con un `SoundSet` vacío (fallback `melee/fist`). Si `assets/custom/sounds/creatures/<nombre>/` existe, lo llena; si no, se arrastran los archivos en el inspector | 1–2 |
| **Escalar** | «100 criaturas, un dios nuevo, 30 hechizos más» | Cada criatura apunta a su set y comparte el `fallback` de cuerpo a cuerpo. Un dios nuevo es su `.tres` con `Music`/`Ambience`. Cada hechizo lleva su `Sound`. Los topes viven en `sound_bus.tscn` (`pool_3d_size`, `max_loops_3d`) y en cada cue (`max_voices`, `cooldown_s`, `priority`). Ningún registro ni tabla central | 1 por pieza |

Rediseñado porque pedía código o más de dos lugares:
- Hoy, agregar el sonido de un hechizo es escribir una clave en `fx_sounds.tres` y repetir ese texto en la escena (2 lugares, sin aviso si hay un error de tipeo).
- Hoy, una voz propia es una carpeta con nombre de tag más el horneado más una raíz `custom/` que pisa por nombre de archivo.
- Hoy, para cambiar la música de un dios hay que saber que la ruta es `music/<tag>`.
- Hoy, un aviso del consejero es un código de 4 letras repetido en 3 diccionarios.

---

## 4. Red: quién toca qué en cada par

El sonido es presentación: nunca hay una RPC de audio, nada escribe en la simulación y nada usa el generador global. Esto no cambia.

| Sonido | Quién lo toca | De qué estado |
|---|---|---|
| Criatura/mago (`summon`, `swing`, `shoot`, `damaged`, `death`, `incantation`, `ghost`) | Cada par con audio, en el cuerpo | Replicado: `mode`, `swings`/`shots`, `Health.current`, `cast_fx_shown`, `GhostForm.stage` |
| FX (ráfaga, rayo, escena) | Cada par que lo dibuja | `FxBus.played` (llega por la RPC del FX que ya existe) |
| `SoundEmitter3D` one-shot | El par donde la escena entra al árbol (spawner) | Entrada al árbol |
| `SoundEmitter3D` bucle | Cada par, si está `active` y a menos de `max_distance_m` del oyente | Estado replicado del dueño (manantial, altar, zona, muro) |
| Voces (`CommandVoice`, consejero) | Solo el jugador de este proceso | Señales locales (`Selection`, `Orders`, `CommandLog`) y estado replicado filtrado por `local_slot` |
| Música y ambiente | Cada cliente | `MatchBiome.applied` → `GodType`, `CombatGauge`, `MatchState`, rituales replicados |
| Dedicado y room server | Nada | `AudioGate` cerrado: no crea players ni pool. Sí carga los `.tres` tipados (§0, pregunta 2) |

**Bug que arregla este corte:** `ReachedCue` (`sstl` del Soul Mole) escucha `SpellCarrier.reached`, que solo emite el servidor (`spell_carrier.gd:72`, `set_physics_process(multiplayer.is_server() …)`). En el cliente de un dedicado no suena. Pasa a escuchar un estado replicado del carrier (la fase o el destino tomado). Si no hay ninguno, el developer lo expone en el `MultiplayerSynchronizer` del carrier. Se verifica en `run_audio_net.sh` (+1 evento esperado en el cliente).

**Late join:**
- Los bucles se reclaman solos al entrar al árbol (`_look`). Un late joiner escucha los manantiales, el altar y las zonas vivas. Bien.
- Riesgo **NO VERIFICADO**: los one-shots con `play_on_ready` de escenas que el `MultiplayerSpawner` recrea al unirse (proyectiles en vuelo, muros) suenan de nuevo. Se mide primero.
  - Arreglo propuesto si se confirma: `SoundEmitter3D.play_once` no suena cuando el nodo nació en la sincronización inicial del spawner. Señal: el spawner local está en su replay de unión; el developer usa lo que `scenes/net/` ya expone, sin `MpKit.` nuevo fuera de la allowlist.
- `UnitSounds` en `SUMMONING` al nacer: hoy suena `summon` también en el late join. Se aplica la misma regla.
- Caso nuevo en `debug/net/late_join.tscn`: durante los 2 s después de unirse, el `SoundLog` del cliente tiene **0** entradas `cast`/`summon`/`advice` y **≥ 1** `loop`.

---

## 5. Los assets del original

- Los streams siguen en `assets/original/audio/` (LFS, versionados). Los `SoundCue` los referencian igual que hoy los `models/<tag>.tscn` referencian `.glb` de `assets/original/models/`. **Jugar desde un clon no necesita la instalación del original.**
- Nada en `scenes/` nombra `assets/original` (C13 no sube). Las rutas viven solo en los `.tres` de `data/audio/` como `ext_resource`, que es lo mismo que hacen los modelos.
- Sonidos propios: un `.ogg`/`.wav` en cualquier carpeta (`assets/custom/sounds/` por costumbre), arrastrado a un `SoundCue`. Nunca hace falta el original. `catalog_cases` sigue validando que un set propio no nombre `assets/original/`.
- Herramientas:
  - `import_audio.py` ya dice al arrancar «Requiere el juego original instalado (SAC_INSTALL)».
  - `migrate_055o_audio.gd` no necesita el original: lee los `.tres` de hoy. Si los streams no están (clon sin LFS), avisa al arrancar: «Faltan los archivos de assets/original/audio (git lfs pull): la paridad de streams no se puede medir».
  - `bake_sound_sets.gd` (necesita `index.json` del import) se borra (pregunta 5).
- Un clon sin el LFS del audio: ver pregunta 3. Hoy el juego corre mudo. Con referencias tipadas, si Godot aborta ante dependencias faltantes, una `CreatureType` con `sounds` no cargaría. Se mide en 055o-a paso 1 antes de tocar el catálogo (055o-b).

---

## 6. Criterios medibles

**Lint.** C17 se amplía al sonido, sin regla nueva, porque C17 ya dice «Un FX o sonido es un Resource tipado, no un texto». Se cuentan:
- `SoundLibrary\.`, `SoundBus\.(lookup|fx_cue)\(` y `FxSoundMap\b` en `scenes/`;
- `@export var (cue|source|set_path|fallback_path|shared_set|ui_set|ui_click_key|one_shot_source|one_shot_keys)` de tipo `String`/`StringName`;
- `@export … Dictionary[StringName, StringName|PackedStringArray|int|float]` en `scenes/audio/`;
- `@export var x := &"<4 letras>"` en `scenes/audio/`;
- en `.tscn`/`.tres`: `^cue = &"`, `^source = "`, `^set_path = "`, `^fallback_path = "`, `metadata/ui_sound = "`, `^one_shot_keys = `.

| Regla | Hoy | Al cerrar 055o |
|---|---|---|
| C17 ampliado | 23 + **130** = 153 (borrador del patrón; el developer fija el número exacto al agregarlo y reescribe la base) | **23** (solo los `FxBus.broadcast("…")` de 055x) |
| C18 | 131 | **129** (−2 `sound_library.gd`) |
| C9 en `scenes/audio/` | 28 | **0** |
| C15 | 43 | **39** (4 players a `.tscn`) |
| C1b | 24 | **23** (`sound_bus.gd` ≤ 150) |
| C5 / C6 en audio | 2 / 4 | 0 / 0 |
| C13 | 16 | 16 (no sube) |

**Sonda `debug/audio/sound_refs_cases.gd`** (en `run_audio_cases.sh`, headless con `--audio-probe`). Imprime `SOUND REFS typed=<n> text=<m> null=<k> parity=<p>/<q>` y falla si no se cumple:
1. Recorre todo `scenes/**/*.tscn`: cada `SoundEmitter3D` tiene `cue` no nulo y sin sonido vacío. Hoy son 74 nodos. Esperado: **74/74 tipados, 0 por texto**.
2. `CreatureType`: **67 con `sounds`** y 5 en null (los mismos 5 que hoy no tienen set). `WizardType`: **15/15**. `GodType`: **5/5** `music` y `ambience`. `ParticleType`/`BeamType` con `sound`: **31 + 6**. Escenas FX con hijo `Sound`: **5**.
3. Paridad, una sola vez antes de borrar lo viejo: para cada par (emisor, evento) que el juego tocaba hoy, el cue tipado tiene **el mismo conjunto de streams** (rutas) que daba `SoundLibrary` + `aliases` + `shared_set`. Son 99 − 1 huérfana claves de FX, 66 sets de cuerpo × sus eventos, 5 + 1 músicas, 5 ambientes, 14 líneas del consejero y 4 de UI. Esperado: **100 %**. El informe del migrador lista las claves que se descartan sin uso (`Xres`, `TNT*`, `grp*`… y `wall_vine_up`).
4. `grep -rn "SoundLibrary\|FxSoundMap\|fx_sounds" scenes/` = **0**.

**Costo de cargar todo tipado** (055o-a paso 1, antes de migrar). Se mide con `Performance.MEMORY_STATIC` y con el tiempo hasta `GameData` listo y hasta el `match` cargado:
- en un cliente, en `--dedicated --no-flow` y en un headless de banco;
- antes y después de asignar los sets a las 72 + 15 fichas y los cues a las 39 escenas, en una rama de prueba.

Hoy los streams que nombran los sets pesan 11,3 MB (FX), 39,8 MB (2 466 archivos de criaturas, magos y cuerpo a cuerpo), 18,7 MB (mundo, UI y consejero) y unos 26 MB (música).

Presupuesto propuesto: **+≤ 1,5 s de arranque y +≤ 150 MB en el dedicado**. Si se pasa, se aplica la alternativa de la pregunta 2 antes de 055o-b.

**Partida.** Los 7 labs `lab_052c…i` pasan con las mismas expectativas (los `_no_original` se borran o se reescriben, pregunta 3). `run_audio_net.sh` da las mismas cuentas por evento en solo y en el cliente del dedicado, +1 `soul_mole_take` en el cliente. Se agrega el caso de late join (§4). `rules_suite` y `quick` como humo: el audio no toca la sim y el digest no cambia.

---

## 7. Código 1 a 1 que borra este corte
- `scenes/audio/sound_library.gd` (97 líneas): rutas, raíces, `creature(tag)`/`wizard(tag)` y nombre por archivo del catálogo.
- `scenes/audio/fx_sound_map.gd` (28) y `data/audio/fx_sounds.tres` (99 claves de texto).
- `data/audio/world.tres` (`spel`), `ui.tres` (`ifac`) y `advisor.tres` (`advi`): los sets agrupados como en el WAD.
- `SoundEvent.CREATURE_CODES`/`WORLD_CODES`/`UI_CODES` (las 11 claves). Pasan al migrador y se van con él.
- `BodySounds.aliases`, `CommandVoice.aliases`, `BodySounds.shared_set`, `SoundBus.lookup`/`fx_cue`/`ui_set`/`ui_click_key`/`FX_MAP`, `MenuSounds.ui_set`/`cues`/`events`, `MusicDirector.set_path`/`fallback_path`, `AmbienceDirector.set_path`, `AdvisorVoice.set_path`/`priorities`/`cooldowns` (pasan a `AdvisorLine`), los 8 códigos de `AdvisorWatch`, y `AmbienceSet.one_shot_source`/`one_shot_keys`.
- `SoundEmitter3D.source` y `restart()` (solo existía porque cambiaban las raíces).
- `tools/bake/bake_sound_sets.gd` (162) y la entrada «Hornear sonidos» del menú (pregunta 5).
- En `debug/audio/`: el mecanismo de raíces de los cases y labs, y los modos `--audio-no-original` (pregunta 3).
- Las claves horneadas sin uso dentro de los sets (`Xres`, `Xrun`, `TNT*`, `grp*`, `asg*`, `att*`, `grd*`, `f*`). Los archivos de audio quedan en `assets/original/audio/`.

---

## 8. Sub-cortes y paralelo

| Corte | Qué | Archivos | En paralelo con 055h / 055i-a |
|---|---|---|---|
| **055o-a** FX y emisores tipados | 1) Medir el costo (§6) y la carga con dependencia faltante (pregunta 3). 2) `SoundEmitter3D.cue: SoundCue`; migrador → `data/audio/cues/` y 39 escenas; `ParticleType`/`BeamType.sound`; `FxSounds`; 5 escenas FX con `Sound`; `play_scene` ubica antes de `add_child`; `ReachedCue` replicado; `ShakeMap.key_of`; fuera `FxSoundMap` y `fx_sounds.tres` | `scenes/audio/` (emisor, bus), `scenes/fx/`, `scenes/spells/**`, `scenes/map/props/`, `scenes/units/afflictions/**`, `data/fx/`, `data/audio/cues/`, `tools/migrate/`, `debug/audio/` | **Sí con los dos**: no toca `scenes/ui/`, lobby, `sacrifice_flow`, catálogo ni `data/gods`. Las corridas de Godot van por la cola |
| **055o-b** cuerpos | `SoundSet` con campos; `CreatureType.sounds`/`WizardType.sounds`; 67 + 15 + 3 sets con nombre humano; `UnitSounds`/`WizardSounds`/`BodySounds`/`CommandVoice` tipados; `summon` en `unit.tscn` | `creature_type.gd`, `wizard_type.gd`, `data/catalog/{creatures,wizards}/`, `data/audio/{creatures,wizards,melee}/`, `unit.tscn`, `wizard_body.tscn`, `command_voice.gd` | **Sí con 055h.** Con 055i-a, solo si su árbol no edita `wizard_type.gd` ni `data/catalog/wizards/` (hay que confirmarlo, porque el lobby elige mago). Tiene que mergear **antes** de 055c1 + 055i-b, que reescriben `creature_type.gd` |
| **055o-c** partida | `GodType.music/ambience`; `MusicDirector`/`AmbienceDirector` tipados y con players en `.tscn`; `advisor.tscn` con `AdvisorLine`; `RitualSounds`/`SoulSounds` tipados; `one_shots` del ambiente; fuera `world.tres` y `advisor.tres` | `god_type.gd`, `data/gods/`, `scenes/audio/*director*`, `advisor/`, `ritual.tscn`, `soul.tscn`, `match.tscn`, `boot.tscn` | **No en paralelo con 055i-a** (`data/gods/`, `boot.tscn`, menú) ni con 055h si 055h toca `match.tscn`/`boot.tscn`. Va después de los dos, o se cede `boot.tscn` (2 líneas) a quien esté |
| **055o-d** UI | `UiClickSounds.click`, meta `ui_sound` con `SoundCue`, `MenuSounds` tipado; fuera `ui.tres` | `sound_bus.tscn`, `scenes/ui/radial/radial_menu.tscn`, `scenes/ui/spell_book/spell_slot.tscn`, `menu_sounds.gd` | **Después de 055h** (comparte `scenes/ui/`), o lo hace 055h como un renglón de su plan |
| **055o-e** cierre | `SoundBus` partido (≤ 150) y como escena autoload; borrar `SoundLibrary`, `ResourceDeps` (o moverlo a `debug/suite/`), el migrador y `bake_sound_sets`; C9 = 0; C5/C6; READMEs; C17 ampliado y baseline | `scenes/audio/`, `tools/`, `debug/audio/`, `project.godot`, `tools/lint/` | Sí con 055h (salvo `project.godot`, que es una línea) |

Orden: **055o-a** → (pregunta 2 resuelta) **055o-b** → **055o-c** y **055o-d** (cuando cierren 055i-a y 055h) → **055o-e**. Cada uno es un developer, sin review salvo 055o-b/c (cambian lo que se oye). El playtest con ventana se hace una sola vez, al cerrar 055o-c: una partida corta en High Noon, porque el cambio es audible y no visible (ver la pregunta 7).

## 9. Orden de implementación (pasos cortos)
1. **055o-a.1** En una rama de prueba: asignar tipado lo mínimo para medir el arranque y la memoria (cliente, dedicado, banco). Probar la carga de un `.tres` cuyo stream falta. Anotar los números en este plan.
2. **055o-a.2** `SoundEmitter3D.cue: SoundCue` (warning si falta) y la parte FX del migrador: `data/audio/cues/<clave>.tres` y la reescritura de los 74 nodos de las 39 escenas. Primero el informe de paridad.
3. **055o-a.3** `ParticleType.sound`, `BeamType.sound`, `FxSounds`. Las 5 escenas FX con `Sound`. `play_scene` ubica antes de `add_child`. `ReachedCue` replicado. Borrar `FxSoundMap`, `fx_sounds.tres` y `SoundBus.fx_cue`. Lab `052d` y `run_audio_net.sh`.
4. **055o-b.1** `SoundSet` con campos, más la parte de cuerpos del migrador (paridad), con renombres a nombre humano.
5. **055o-b.2** `CreatureType.sounds`/`WizardType.sounds` asignados. Lectores tipados. `UnitSounds.summon`. Fuera `aliases`/`shared_set`. Labs `052c`/`052e`.
6. **055o-c.1** `GodType.music/ambience`, directores tipados y players en `.tscn`. **055o-c.2** `advisor.tscn` + `AdvisorLine`, ritual y alma, `one_shots`. Labs `052f`/`052g`/`052h`. Caso de late join.
7. **055o-d** UI (después de 055h).
8. **055o-e** partir `SoundBus`, borrar lo que queda, C9, C5/C6, READMEs, C17 ampliado, `--update-baseline`, sonda final.

## 10. Cómo lo verifica un humano en el editor
- Abrir `scenes/spells/fireball_projectile.tscn` → nodo `Sound`: el inspector muestra `Cue` = `fireball_cast.tres`. Clic en el recurso → `Streams`, `Volume Db`. Con F6 suena una vez.
- Abrir una ficha de `data/catalog/creatures/`: el campo `Sounds` muestra un `SoundSet` con renglones por nombre (`Selected`, `Death`…) y su `Fallback`.
- Abrir `data/gods/pyro.tres`: `Music` y `Ambience` con el set del dios.
- Borrar el `Cue` de un emisor: el árbol de escena muestra el ⚠ «Asigná `cue`».
- F5 en High Noon: invocar, lanzar Fireball, sacrificar, tomar un alma. Se oye lo mismo que antes y el panel de Opciones → Sonido sigue igual.
- Headless: `bash agent/runs/run_audio_cases.sh` (con la línea `SOUND REFS`), `bash agent/runs/run_audio_net.sh` y `bash tools/lint/conventions.sh`.

## Fuera de alcance
- Los `FxBus.broadcast("…")` y `broadcast_scene(path)` por texto (C17 23): **055x**. Ahí `FxBus.played` pasa a llevar el recurso y `FxSounds` deja de resolver nombres.
- La cámara (la vieja 055o, pregunta 1).
- La identidad de las fichas por tag y los nombres humanos de `data/catalog/`: 055i-b. Las referencias tipadas sobreviven a sus renombres.
- Contenido de audio nuevo (eventos sin sonido hoy: `ghost`, `foot`, `slaw`, `ewiz`…).
- El port web (otro worktree). La memoria del navegador con todo tipado se anota como riesgo con los números del paso 1.
- MpKit.

## Riesgos
- **Costo de carga tipada** en el dedicado, el room server (un proceso por sala) y el web. Se mide en 055o-a.1. La alternativa está en la pregunta 2.
- **Dependencia faltante aborta la carga** (pregunta 3, NO VERIFICADO en 4.7).
- **`match.tscn` y `boot.tscn` son archivos calientes:** 055o-c va en serie.
- **One-shots en el late join** (§4, NO VERIFICADO).
- **Los labs dependen de las raíces:** reescribir `debug/audio/` (2 501 líneas) es la parte más larga. Se hace por sub-corte, y cada uno deja su lab verde.

## 11. Preguntas abiertas (con recomendación)
1. **¿Qué letra lleva la cámara?** RFC-055 llama 055o a la cámara. **Recomiendo** dejar 055o para el audio (como lo pidió el orquestador), pasar la cámara a **055m** y corregir RFC-055 §13.2b C-8a/C-8d, §15 y 055R §4 en el mismo commit de 055o-a.
2. **¿Se acepta que el dedicado y el room server carguen los streams?** (rompe la meta de RFC-052 «never load an AudioStream»). **Recomiendo que sí**, dentro del presupuesto medido (+≤ 1,5 s, +≤ 150 MB), porque es lo que hace cualquier juego Godot con referencias tipadas y el export dedicado de Godot puede quitarlos después (NO VERIFICADO para audio). Si se pasa: `CreatureType.sounds` se mueve a la escena por criatura que trae 055c (se carga al instanciar), y la música queda en `GodType`.
3. **¿Un clon sin el LFS del audio tiene que correr mudo?** **Recomiendo que no**: tratar el audio como los modelos (parte del repo), borrar `--audio-no-original` y `ResourceDeps` del producto, y que `check_original_assets.sh` avise si faltan. Si el usuario quiere mantenerlo, el paso 1 mide si `ResourceLoader.set_abort_on_missing_resources(false)` al arrancar alcanza, con un solo aviso en el log.
4. **¿Los cues de FX van en archivos (`data/audio/cues/<nombre>.tres`) o embebidos en cada escena?** **Recomiendo archivos**: 11 claves se usan en 2 o 3 lugares (`ward_air` ×3, `rings_*`, `explosion_loop`, `cloud_loop`…), y bajar un sonido tiene que cambiarlo en todos lados. Embebido solo para lo que se usa una vez y se crea a mano.
5. **¿Se borra `bake_sound_sets.gd`?** **Recomiendo que sí**: después de la migración los sets son de los humanos y volver a hornear los pisaría (lo mismo que se decidió para `bake_catalog`). Se mantiene `sound_set_writer.gd` para «Nueva criatura desde modelo…».
6. **¿Se juntan los nodos de audio de la partida en una escena `match_audio.tscn`?** (`ListenerFocus`, `CommandVoice`, el consejero, `CombatGauge`, `MusicDirector`, `AmbienceDirector`). **Recomiendo** hacerlo solo con el consejero en este corte (`advisor.tscn`) y dejar el resto en `match.tscn`. Juntarlo todo pide una raíz que reparta 6 sockets, y es justo el archivo que más se pisa con 055h/055i-a.
7. **¿Hace falta playtest con ventana?** La memoria dice «ventana solo con cambios visibles», y esto es audible. **Recomiendo** una sola partida corta con ventana al cerrar 055o-c, escuchada por el usuario. Lo automático (sonda, labs, red) cubre los números.
8. **¿Se descartan las claves horneadas que el juego no toca** (`Xres`, `TNT*`, `grp*`, `asg*`, órdenes de los magos)? **Recomiendo que sí**: el informe del migrador las lista, los archivos quedan en `assets/original/audio/`, y un corte de contenido las agrega como campos con nombre cuando tengan un evento.
