class_name BenchExpect
extends Resource

## One criterion of a bench scene (RFC-053 §4, F370): what ExpectJudge measures and prints as
## `EXPECT PASS|FAIL <check> <value>`. Bodies are named by the `label` of their BenchGroup / BenchBuilding (or its tag).
##   picked   each body of `subject` (all) or one (any) takes a body of `object` as its target within `within_s` of `from`.
##   struck   each (all) or one (any) body of `subject` strikes or shoots bodies of `object` at least `min_count` times within
##            `within_s` of `from` (a blow that lands, UnitBody.struck; a shot that leaves, RangedAttack.fired).
##   hurt     a body of `object` takes damage from the slot of `subject` within `within_s` of `from` (Health.hit).
##   dropped  each body of `subject` (all) or one (any) that had a body of `object` as its target stops having it within
##            `within_s` of the later of the tick it took it and the last tick that body of `object` lost health (`from` is
##            ignored): «it lets go of a target that stopped going down».
##   spared   bodies of `subject` (any body when empty) strike or shoot bodies of `object` (any body of health maximum 0 when
##            empty) at most `max_count` times during the whole run. Decided when every other criterion is.
## F371 (053b), the AI's casts and bursts. `subject` names the AI wizard (`ai<slot>`, the runner's label) or any body of its slot:
##   cast     the slot of `subject` starts at least `min_count` attack spells on bodies of `object` within `within_s` of the start.
##   uncast   ... at most `max_count` attack spells on bodies of `object` during the whole run (decided with the rest).
##   unharmed bodies of `object` take at most `max_count` damage in all from the slot of `subject` during the whole run.
##   burst    at most `max_count` plays of the FX `fx` within `near_m` (to its hit box, SplashDamage.box_distance) of a body of `object` during the whole run.
## F372 (053c): with `spell` (a tag, e.g. laeh) «cast» and «uncast» count the casts of that spell only, whatever its kind, and with
## an empty `object` the ones on any body:
##   first_cast  the first cast of `spell` (or attack spell) of the slot of `subject` within `within_s` goes to a body of `object`.
## F373 (053d), the finish:
##   killed       a body of `object` goes down (its health reaches 0, a wizard dying or a ghost, or freed) within `within_s` of the
##                start. The value is the seconds: the time to kill.
##   died_before  a body of `object` goes down before any body of `subject` does (decided by the first of them to go down).
## «picked» with the quantifier `at_least`: at least `min_count` bodies of `subject` take a body of `object` within `within_s`.
## A label may name several groups with «|» (`wizard1|charlotte`).
## `from`: start = the tick the bench starts; hurt = the first tick the subject body takes damage; near = the first tick a
## body of `object` is within `near_m` (flat) of the subject body. The value printed is the seconds (the slowest body with
## «all», the fastest with «any») or the count.

@export var check := "expect"
@export_enum("picked", "struck", "hurt", "dropped", "spared", "cast", "uncast", "unharmed", "burst", "first_cast", "killed", "died_before") var kind := "picked"
@export var subject := ""
@export var object := ""
@export_enum("all", "any", "at_least") var quantifier := "all"
@export_enum("start", "hurt", "near") var from := "start"
@export var near_m := 25.0
@export var within_s := 3.0
@export var min_count := 1
@export var max_count := 0
## F371: the FX name a «burst» criterion counts (FxBus.played), e.g. wrath_explosion1.
@export var fx := ""
## F372: the spell tag «cast», «uncast» and «first_cast» count (empty: every attack spell).
@export var spell := ""
## F372: a «spared», «uncast», «unharmed» or «burst» row is not decided (and keeps the run going) before this many seconds:
## «0 Heals in 30 s» watches the whole 30 s even once every other row is decided. 0: decided with the rest.
@export var watch_s := 0.0
