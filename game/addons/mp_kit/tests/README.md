# mp_kit/tests
What: the kit's own tests, headless and without the game: slots (MpIds), input frames, the sync builder, MpKit roles.
Not: network play between processes. That is the lab e2e, next to the addon in the kit repo: `mpkit_lab/run/all.sh` (and `session.sh`, `arena.sh`, `rooms.sh`, `private.sh`, `instances.sh`, `wizard.sh`, `web.sh`, `play.sh`).
Talks to: `mp_test_runner.gd` loads every `test_*.gd` here and calls every `test_*` method; each extends `mp_test.gd` (`check`).
Edit: add a `func test_x()` to a file, or a new `test_<thing>.gd`. Nothing to register.
Check: `godot --headless --path <project> --script res://addons/mp_kit/tests/mp_test_runner.gd` → `MPKIT TESTS PASS (n)`.
