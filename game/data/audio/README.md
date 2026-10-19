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

- `Xcat`: acusa una orden de atacar.
- `Xann`: lo molestaste.
- `Xres`: rescatado.
- `Xhit`: impacto del golpe, en `fist`.
- `Xstn`: aturdido.
- `TNT1`–`TNT4`: burlas.
- `grp0`–`grp9`, `asg0`–`asg9`: grupos.
- `attU`, `movG`, `grdM`…: órdenes.
- `fcir`…: formaciones.
- En `spel`: `Xfbl` y los demás hechizos, y `A*` para el ambiente.
- En `advi`: `dese`, `lowm`, `watt` y los demás avisos.

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
