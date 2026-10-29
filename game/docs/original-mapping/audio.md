# Audio del original

Cómo se llamaban los sonidos en el original. El juego ya no lee estos códigos.

## De dónde salieron los sets del original

`tools/import/import_audio.py` (necesita el juego original instalado) escribió `assets/original/audio/`; los sets de criaturas y magos son un dato del juego y los edita un humano (055o-b los migró de las claves de texto del `SSET` a campos con nombre; los códigos que ningún evento toca —`Xres`, `grp*`, `asg*`, `TNT*`…— se descartaron y sus archivos siguen en `assets/original/audio/`).

## Códigos SSET → eventos

Referencia de cómo se llamaban en el original (el juego ya no los lee: cada código es un campo del `SoundSet`).

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
| `Xsac` (`spel`) | `scenes/audio/cues/sacrifice_round.tres` | ronda del sacrificio (`RitualSounds.round_cue`) |
| `Xgib` (`spel`) | `scenes/audio/cues/sacrifice_end.tres` | final del sacrificio (`RitualSounds.finished_cue`) |
| `spir` (`spel`) | `scenes/audio/cues/soul.tres` | alma (`SoulSounds.collected_cue`, `RitualSounds.converted_cue`) |
| `SUMN` (`spel`) | `scenes/audio/cues/summon.tres` | invocación (`UnitSounds.summon`) |
| `clik` (`ifac`) | `cues/ui_click.tres` | clic de botón (`Mcl1-4`; `UiClickSounds.click`) |
| `Iclk`, `Ibak`, `XMNU` (`ifac`) | `cues/ui_book_click.tres`, `menu_back.tres`, `menu_open.tres` | clic de la interfaz en partida (libro: dato `ui_sound`), volver, menú X (`MenuSounds`) |

El mago además emite `ghost` al levantarse como fantasma; el original no trae sonido para eso (ni para la muerte del mago), así que suena solo con un set propio. `shoot` no tiene código en el original: los sets migrados llevan el cue del `swing` también en `Shoot`.
