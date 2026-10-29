# audio

Everything that sounds. Client only: no RPC, nothing here writes the simulation, and nothing uses the global random generator
(`randf()`, `AudioStreamRandomizer`).
Entry point: the `SoundBus` autoload (`sound_bus.tscn`, owner of the players and the pool limits). The `*Sounds`,
`*Voice` and `*Director` nodes turn replicated state or local signals into `SoundBus.play_2d` / `play_3d` / `play_on`.
A sound is a `SoundCue` `.tres` dragged onto a field. Where they live:

| What | Where |
|---|---|
| A creature's or a wizard's sounds (`SoundSet`, one field per event) | `<name>_sounds.tres` in its folder, set on its look's `Sounds` |
| The cues only one spell uses | `spells/<name>/sounds/` |
| A god's music and ambience (`MusicSet`, `AmbienceSet`) | `gods/<name>/<name>_music.tres`, `<name>_ambience.tres`, set on its look |
| Shared cues (UI, souls, sacrifice, summon, fountains) | `cues/` here |
| Shared melee sets, the `fallback` of a creature's set | `melee/` (`fist`, `saw`, `stab`) |
| Common and menu music | `music/` |

An empty field sounds like the set's `fallback`. Custom sounds: `docs/HOWTO.en.md`. The original's sound codes:
`docs/original-mapping/audio.md`.
