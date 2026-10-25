# data/audio/

Sets de sonido (RFC-052), un `.tres` por emisor. El de una criatura o un mago se asigna en su ficha: `CreatureType.sounds` / `WizardType.sounds` (055o-b). Los demás (`world`, `advisor`, `music/`, `ambience/`) todavía se buscan por ruta con `SoundLibrary` hasta 055o-c. La UI (clics y menú X) ya es tipada: `cues/ui_click.tres`, `ui_book_click.tres`, `menu_open.tres` y `menu_back.tres` (055o-d).

## Cómo se asigna un sonido a una criatura

`data/catalog/creatures/<tag>.tres` → `Sounds` → el `SoundSet` de `creatures/<nombre>.tres`. El set tiene un campo por evento (`Selected`, `Ack`, `Attack Ack`, `Annoyed`, `Swing`, `Shoot`, `Damaged`, `Death`, `Summon`, `Incantation`, `Ghost`) y un `Fallback`: el set de golpes compartido (`melee/fist`, `saw`, `stab`). Un campo vacío suena como el del `Fallback`; `Summon` vacío suena como `UnitSounds.summon` (`cues/summon.tres`, el de todas).

## Qué hay

| Archivo | Qué es | De dónde sale |
|---|---|---|
| `creatures/<nombre>.tres` | `SoundSet` de una criatura (`trogg.tres`; los dos Faestus llevan su dios) | `creatureSSET` del `CRE8` |
| `wizards/<nombre>.tres` | `SoundSet` de un mago | `wizardSSET` del `WIZD` |
| `melee/<set>.tres` | sets de golpes compartidos (`fist`, `saw`, `stab`) con `swing` y `shoot` | `meleeSSET`; es el `fallback` de la criatura o del mago |
| `world.tres` | el mundo: sacrificio, almas, invocación, hechizos, ambiente `A*` | set `spel` |
| `advisor.tres` | los avisos del consejero, bus `Voice` | set `advi` |
| `cues/<nombre>.tres` | un `SoundCue` por sonido de FX o de emisor del mundo (`fireball_cast.tres`, `fountain_loop.tres`, `heal.tres`…); lo arrastrás a `ParticleType.sound`, `BeamType.sound` o `SoundEmitter3D.cue` | migrado de `fx_sounds.tres` (055o-a), sobre los `SAMP` del original |
| `music/<dios>.tres`, `music/common.tres`, `music/menu.tres` | `MusicSet`: `calm` del dios (`<dios>_normal`) con `fallback` a `common` (battle 1-5, sacrifice 1, sacrifice victory/losing, victory y defeat theme); el menú toca `menu` y guarda God Realm en `extras` | a mano (052f), sobre los MP3 |
| `ambience/<dios>.tres` | `AmbienceSet`: fondo en bucle y códigos `A*` de `spel` | a mano (052g) |

## Sonidos propios (no necesitan el juego original)

- Una criatura nueva: «Nueva criatura desde modelo…» (`tools/bake/new_creature.gd`) crea `creatures/<nombre>.tres` sobre `melee/fist.tres` y lo asigna a su `Sounds`. Si existe `assets/custom/sounds/creatures/<nombre>/` con `<evento>[_n].ogg|wav` (por ejemplo `death_1.ogg`, `death_2.ogg`), los pone en los campos; si no, el set queda vacío y se arrastran los archivos a los campos en el inspector.
- Cada archivo de un evento es una variante del mismo cue. Los eventos son los campos del set; un `swing` sin `shoot` suena también al disparar (el mismo cue). `selected`, `ack`, `attack_ack`, `annoyed` e `incantation` van al bus `Voice`; el resto, a `SFX`.
- No pisa un `.tres` que ya existe (con `-- --force` sí, y se pierde lo que editaste). Un set propio nunca nombra `assets/original/` (lo valida `debug/suite/catalog_cases.gd`).
- Prueba: `lab_052i.tres` en `bash agent/runs/run_audio_cases.sh` (dos `.wav` de `debug/audio/fixtures/custom_sounds/creatures/testmonster/`).

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
| `Xsac` (`spel`) | `sacrifice_round` | ronda del sacrificio |
| `Xgib` (`spel`) | `sacrifice_end` | final del sacrificio |
| `spir` (`spel`) | `soul` | alma |
| `SUMN` (`spel`) | `summon` | invocación |
| `clik` (`ifac`) | `cues/ui_click.tres` | clic de botón (`Mcl1-4`; `UiClickSounds.click`) |
| `Iclk`, `Ibak`, `XMNU` (`ifac`) | `cues/ui_book_click.tres`, `menu_back.tres`, `menu_open.tres` | clic de la interfaz en partida (libro: dato `ui_sound`), volver, menú X (`MenuSounds`) |

El mago además emite `ghost` al levantarse como fantasma; el original no trae sonido para eso (ni para la muerte del mago), así que suena solo con un set propio. `shoot` no tiene código en el original: los sets migrados llevan el cue del `swing` también en `Shoot`.
