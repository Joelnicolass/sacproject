# audio

Everything that sounds. Client only: no RPC, nothing here writes the simulation, and nothing uses the global random generator
(`randf()`, `AudioStreamRandomizer`).
Entry point: the `SoundBus` autoload (`sound_bus.tscn`, owner of the players and the pool limits). The `*Sounds`,
`*Voice` and `*Director` nodes turn replicated state or local signals into `SoundBus.play_2d` / `play_3d` / `play_on`.
A sound is a `SoundCue` `.tres` in `data/audio/` dragged onto a field; a creature's sounds are its `SoundSet`
(`CreatureType.sounds`). Custom sounds: `docs/HOWTO.en.md`.
