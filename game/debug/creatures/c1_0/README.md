# debug/creatures/c1_0
What: the disposable probe of 055c1 sub-cut c1-0: cost of loading the clip libraries, weight of the `.res` clips in git, and whether an AnimationTree fires the method tracks stored inside each Animation.
Not: production code; nothing here is read by `scenes/`. It writes only under `user://c1_0` (and a temporary copy in `tmp/` for the import probe). Deleted when c1 closes.
Talks to: reads `scenes/bodies/models/*.tscn`, the `.glb` in `assets/original/models`, `data/catalog/creatures|wizards/*.tres`; the three scripts talk through `user://c1_0/manifest.json`.
Edit: `--models=auto|all|eorc,jnwr,...` in the build step (auto = the creature with most clips, the one with fewest, the wizard `hero`, `eorc`, `jnwr`).
Check: `bash debug/creatures/c1_0/run_c1_0.sh` then `bash debug/creatures/c1_0/run_import_probe.sh`.

---

Needs the `.glb` imported and real (not Git LFS pointers). Run from `game/`; every script quits by itself (watchdog 120 s, exit 1 with `C1_0 FAIL <reason>`).

| Step | Script | Lines | Answers |
|---|---|---|---|
| 1 | `c1_0_build.gd` | `C1_0 res_bytes=…`, `C1_0 est_all74 …`, `C1_0 VERDICT git=OK/LFS` | git weight of the ~900 clips (q. 2/4 of the plan) |
| 2 | `c1_0_load.gd` | `C1_0 load_ms=… mem_mb=…`, `C1_0 est_all74 …`, `C1_0 VERDICT load=… mem=…` | cost of loading the libraries, budget +1 s / +100 MB (q. 1/3) |
| 3 | `c1_0_tree.gd` | `C1_0 markers ok=n/m`, `C1_0 markers variant=…`, `C1_0 VERDICT events_in_library=YES/NO` | method tracks inside the Animation fire at the dictionary frame (q. 8/12) |
| 4 | `run_import_probe.sh` | `C1_0 import …`, `C1_0 VERDICT import …` | what the native .glb import can do by role (q. 2) |

`--models=all` builds the 74 libraries (about 900 `.res`) and gives the direct numbers instead of the extrapolation.
