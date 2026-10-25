# mp_kit/tests
What: the kit's own tests, headless and without the game: slots (MpIds), input frames, the sync builder, MpKit roles.
Not: network play between processes. That is the lab e2e (`run_mpkit_arena.sh`, `_rooms`, `_private`, `_instances`, `_wizard`, `_web`), which lives with the project that hosts the lab (in sacproject: `game/agent/runs/` and `mpkit_lab/`).
Talks to: `mp_test_runner.gd` loads every `test_*.gd` here and calls every `test_*` method; each extends `mp_test.gd` (`check`).
Edit: add a `func test_x()` to a file, or a new `test_<thing>.gd`. Nothing to register.
Check: `godot --headless --path <project> --script res://addons/mp_kit/tests/mp_test_runner.gd` → `MPKIT TESTS PASS (n)`.
