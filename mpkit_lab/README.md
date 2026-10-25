# mpkit_lab
What: a tiny Godot project that runs the kit's example and tests apart from Sacrifice (only MpKit and the probe are autoloads).
Not: a game. `addons/mp_kit` is a symlink to `game/addons/mp_kit`, so there is one copy of the kit.
Talks to: `probe/lab_probe.gd` plays the arena_2d example from the command line (`--probe=solo|client|late|watch`).
Edit: nothing to configure; the e2e script starts every process.
Check: `bash game/agent/runs/run_mpkit_arena.sh` (add `TRANSPORT=ws` for WebSocket) and the kit tests (`addons/mp_kit/tests/README.md`).
