# look/warmup

Behind the loading screen, every mesh, material and look scene the match can show is drawn once at `Camera/WarmupStage`,
so the first fireball or creature does not stall compiling a shader. It ends when the pipeline compilation count stays
still for `settle_s`. A dedicated server finishes at once.
Something made at runtime that the walk cannot find: add a `WarmHook` to its owner's scene and connect `asked` to a method
that draws it for one frame, with no sound, no shake and no `played`.
Edit: `match.tscn` › `Warmup` and `Camera/WarmupStage` (it must stay in view).
