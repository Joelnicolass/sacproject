# data/audio/

Sets de sonido (RFC-052), un `.tres` por emisor. `SoundLibrary` los encuentra por convención, sin campos en el catálogo.

## Dónde busca

1. `data/audio/custom/<tipo>/<tag>.tres`: los tuyos. Ganan siempre.
2. `data/audio/<tipo>/<tag>.tres`: los horneados del original.

Si un set nombra un archivo que no está (por ejemplo, un clon sin el audio del original), `SoundLibrary` lo saltea sin cargarlo y sin avisos: el juego corre en silencio.

## Qué hay

| Archivo | Qué es | De dónde sale |
|---|---|---|
| `creatures/<archivo>.tres` | `SoundSet` de una criatura (su voz) | `creatureSSET` del `CRE8` |
| `wizards/<archivo>.tres` | `SoundSet` de un mago | `wizardSSET` del `WIZD` |
| `melee/<set>.tres` | sets de cuerpo a cuerpo compartidos (`fist`, `bsaw`, `stab`) | `meleeSSET`; es el `fallback` de la criatura o del mago |
| `world.tres` | el mundo: sacrificio, almas, invocación, hechizos, ambiente `A*` | set `spel` |
| `advisor.tres` | los avisos del consejero, bus `Voice` | set `advi` |
| `ui.tres` | clics de menú, volver, menú X, subir de nivel | set `ifac` |
| `fx_sounds.tres` | `FxSoundMap`: nombre de FX de `FxBus` → cue, y las claves de los `SoundEmitter3D` | a mano (052d), sobre los `SAMP` del original |
| `music/<dios>.tres`, `music/common.tres`, `music/menu.tres` | `MusicSet`: `calm` del dios (`<dios>_normal`) con `fallback` a `common` (battle 1-5, sacrifice 1, sacrifice victory/losing, victory y defeat theme); el menú toca `menu` y guarda God Realm en `extras` | a mano (052f), sobre los MP3 |
| `ambience/<dios>.tres` | `AmbienceSet`: fondo en bucle y códigos `A*` de `spel` | a mano (052g) |
| `custom/<tipo>/<tag>.tres` | los tuyos | `assets/custom/sounds/<tipo>/<tag>/` |

`<archivo>` es el nombre del `.tres` de esa criatura en `data/catalog/` (`EHTH` → `EHTH_2`, porque macOS ve `EHTH` y `ehtH` como el mismo archivo) o el tag si el catálogo no la tiene. Los nombres de set con mayúsculas se escriben con `_` + minúscula (`Hfae` → `_hfae`).

## Cómo se hornean

- **Original:** `tools/import/import_audio.py` (necesita el juego original instalado) escribe `assets/original/audio/` e `index.json`. Después, `tools/bake/bake_sound_sets.gd` («Hornear sonidos» en Project > Tools) escribe estos `.tres`. El horneado no necesita el original: lee `index.json`.
- **Propios:** poné `.ogg` o `.wav` en `assets/custom/sounds/<tipo>/<tag>/<evento>[_n].ogg` (por ejemplo `creatures/mibicho/death_1.ogg` y `death_2.ogg`) y corré «Hornear sonidos». Cada archivo de un evento es una variante del mismo cue. Los eventos `selected`, `ack`, `incantation` y `advice` van al bus `Voice`; el resto, a `SFX`.
- Ninguno pisa un `.tres` que ya existe. Con `-- --force` se reescribe y se pierde lo que editaste a mano.
- Un set propio nunca nombra `assets/original/` (lo valida `debug/suite/catalog_cases.gd`).

## Códigos SSET → eventos

La tabla vive en `SoundEvent` (`CREATURE_CODES`, `WORLD_CODES`, `UI_CODES`, en `scenes/audio/sound_event.gd`); el horneado y el juego leen los mismos nombres.

| Código | Evento (`SoundEvent`) | Qué es en el original |
|---|---|---|
| `Xcnt` | `selected` | lo seleccionaste |
| `Xcnf` | `ack` | acusa una orden de moverse |
| `Xcat` | `attack_ack` | acusa una orden de atacar (052e: `CommandVoice` la busca por alias; el horneado deja la clave `Xcat`) |
| `Xann` | `annoyed` | lo molestaste (052e: alias, clave `Xann`) |
| `Xatt` | `swing` | golpe cuerpo a cuerpo |
| `Xdam` | `damaged` | recibe daño |
| `Xdie` | `death` | muere |
| `Xinc` | `incantation` | encantamiento del mago |
| `Xsac` (`spel`) | `sacrifice_round` | ronda del sacrificio |
| `Xgib` (`spel`) | `sacrifice_end` | final del sacrificio |
| `spir` (`spel`) | `soul` | alma |
| `SUMN` (`spel`) | `summon` | invocación |
| `clik` (`ifac`) | `click` | clic de botón |

El mago además emite `ghost` al levantarse como fantasma; el original no trae sonido para eso (ni para la muerte del mago), así que suena solo con un set propio. `shoot` no tiene código: `UnitSounds` usa el `swing` del set (`aliases`), y un set de cuerpo a cuerpo sin `swing` (`fist`, `stab`) usa su `Xhit`.

Un código sin evento todavía queda con su código como clave, y lo mapea un corte posterior. Algunos ejemplos:

- `Xres`: rescatado.
- `Xhit`: impacto del golpe, en `fist`.
- `Xstn`: aturdido.
- `TNT1`–`TNT4`: burlas.
- `grp0`–`grp9`, `asg0`–`asg9`: grupos.
- `attU`, `movG`, `grdM`…: órdenes.
- `fcir`…: formaciones.
- En `spel`: `Xfbl` y los demás hechizos, y `A*` para el ambiente.
- En `advi`: los avisos del consejero (tabla de abajo).

## El audio del original

`assets/original/audio/` se versiona por Git LFS (`.gitattributes`):

- `sfx/` en WAV, porque son cortos, sin hueco y sirven para bucles.
- `voice/` en Ogg Vorbis, comprimido con ffmpeg.
- `music/` en MP3, copiado tal cual.

Solo se importan el inglés y las voces que nombra algún set de escaramuza. La música se importa completa.

## Sonidos de FX y de emisores (`fx_sounds.tres`)

`FxSoundMap` (un `SoundSet`): la clave es el nombre del FX como lo recibe `FxBus` (un `ParticleType`, un `BeamType`, o el nombre de archivo de una escena de `broadcast_scene`), o la clave que nombra un `SoundEmitter3D`. Se escribe a mano, no lo hornea `bake_sound_sets`: los hechizos y los edificios del original tocan `SAMP` por nombre, sin `SSET`, así que donde no hay entrada de `spel` el cue nombra el `.wav` directo. Un `custom/fx_sounds.tres` pisa solo las claves que tiene.

| Clave | Sonido | Del original |
|---|---|---|
| `blood` | `char/bld1-2` | `spel` `Xbld` |
| `hover_blood` | `gib!/gib1-4` | `spel` `Xgib` (gib) |
| `heal`, `speedup`, `teleport_out` | `comn/heal`, `spup`, `tele` | por nombre |
| `wrath_particle` | `pyro/fbx1-3` | `spel` `Xfbx` (explota la bola de fuego; la de la Ira comparte el FX) |
| `rock`, `petrify_rocks` | `jams/rxp1-2`, `jams/rkfm` | `spel` `Xrxp`; por nombre |
| `freeze_shards`, `oil_splash`, `oil_blast`, `fire` | `stra/ish1-4`, `pyro/oil1-2`, `pyro/ign1-2`, `pyro/onf1-2` | `spel` `Xice`, `Xoil`, `Xign`, `Xonf` |
| `lightning`, `styx`, `gnome_flame`, `locust_ray` (rayos) | `stra/ltn1-6`, `char/stxs`, `pyro/flam`, `char/buzz` | `spel` `Xltn`; por nombre |
| `spike_field`, `quake_ring` (escenas) | `jams/rspk`, `jams/sms7` | por nombre |
| `fireball_cast`, `rock_cast`, `swarm_cast`, `wrath_cast` | `pyro/fbal…`, `jams/pelt`, `char/swr1-3`, `pers/rths` | `spel` `Xfbl`, `Xswr`; por nombre |
| `fountain_loop`, `manalith_loop`, `altar_loop` | `ambi/font`, `mlth`, `afir` | bucles de los edificios |

`summon` no tiene clave a propósito: la invocación ya suena por `UnitSounds`. Los tres bucles se importan con `edit/loop_mode=2` (adelante) en su `.import`, así suenan sin hueco.

## El consejero (`advisor.tres`, 052e)

`AdvisorVoice` usa las claves del set `advi` tal cual. Cada código es un `SAMP` `_a_dNN` (la tabla del original, `AdvisorHelpSound`). Prioridad: 0 rechazo, 1 importante, 2 crucial (`priorities`); silencio entre dos avisos iguales: `cooldowns` (los del original).

| Código | Qué dice | Lo dispara | Prioridad | Silencio |
|---|---|---|---|---|
| `lowm` | poco maná | rechazo `no_mana` | 0 | 5 s |
| `nred` | no está listo | rechazo `cooling` | 0 | 2 s |
| `orng` | fuera de alcance | rechazo `out_of_range` | 0 | 2 s |
| `invl` | blanco inválido | rechazos `bad_target`, `no_target` | 0 | 2 s |
| `spir` | faltan almas | rechazo `no_souls` | 0 | 2 s |
| `ealt` | hay que estar cerca del altar enemigo | rechazo `far_from_altar` | 0 | 2 s |
| `watt` | atacan a tu mago | baja la vida del mago local | 1 | 15 s |
| `whlt` | poca vida | el mago local queda bajo el 25 % | 2 | 5 s |
| `uatt` | atacan a tus criaturas | baja la vida de una criatura propia | 1 | 15 s |
| `cdie` | mueren tus criaturas | una criatura propia llega a 0 | 1 | 5 s |
| `bdam` | atacan un edificio | baja la vida de un edificio propio (grupo `structure`) | 2 | 5 s |
| `bdst` | edificio en ruinas | un edificio propio llega a 0 | 1 | 1 s |
| `dese` | profanan tu altar | empieza un ritual de profanación sobre tu altar | 2 | 5 s |
| `sacc` | sacrificio completo | termina completo un ritual que lanzaste | 1 | 2 s |

Sin evento todavía (no hay uno que encaje limpio): `slaw` (el ejército masacrado), `ewiz` (un mago enemigo se acerca a tu altar), `sawe` (enemigo a la vista), `gib!` (caen los enemigos), `mhor` y `mlth` (sin manahoars, sin manalitos), `audi` (alguien pide audiencia), `mana` (otra toma de `lowm`). Los rechazos `casting`, `occupied`, `no_altar`, `no_fount`, `far_from_building`, `no_ground`, `nobody`, `no_wizard`, `no_ability`, `not_implemented` y `creature_limit` no dicen nada.

## Música y ambiente (052f, 052g)

Los MP3 que suenan en bucle (`<dios>_normal`, `battle_*`, `sacrifice_*`, `menu`, `god_realm`) tienen `loop=true` en su `.import`; `victory_theme` y `defeat_theme` suenan una vez. `music_mood_cases` (`original_loops`) lo verifica.

| Dios | Sueltos (`A*` de `spel`) | Fondo en bucle |
|---|---|---|
| `james` | `AjaN`, `AjaU` | — |
| `persephone` | `ApeC` | — |
| `pyro` | `Avul` | `pyro/lava` |
| `stratos` | `AstU`, `Astr` | `ambi/rain` |
| `charnel` | `AchC`, `AchN`, `AchU` | `ambi/rain` |

El original no trae un fondo por dios; los fondos son `SAMP` que ningún set usa como suelto (`rain`, `lava`), porque un WAV con `loop_mode=2` tocado como suelto no terminaría nunca. Para otro fondo, poné un `bed` en `custom/ambience/<dios>.tres` con un WAV propio en bucle.
