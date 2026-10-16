extends Node

## Every interval_s of physics time prints `mana <value>` for the local wizard and shows
## the measured rate in %ManaProbe, named after the source it matches within tolerance.

@export var world: Node
@export var label: Label
@export var interval_s := 1.0
@export var tolerance := 0.1

var _elapsed := 0.0
var _last := NAN


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < interval_s:
		return
	var wizard: Node = world.call("local_wizard") if world else null
	var pool := wizard.get_node_or_null("ManaPool") if wizard else null
	if pool == null:
		_elapsed = 0.0
		return
	var mana := float(pool.get("current"))
	var rate := 0.0 if is_nan(_last) else (mana - _last) / _elapsed
	_last = mana
	_elapsed = 0.0
	print("mana %.1f" % mana)
	print("mana ritmo %.2f/s %s" % [rate, _match(rate)])
	if label:
		label.text = "Maná %d · %+.1f/s · %s" % [roundi(mana), rate, _match(rate)]


func _match(rate: float) -> String:
	var rules: MatchRules = world.get("rules") if world else null
	if absf(rate) < 1.0:
		return "sin fuente"
	if rules == null:
		return "otro"
	var named := {
		"manantial": rules.manafount_rate,
		"altar": rules.altar_rate,
		"ambos": rules.manafount_rate + rules.altar_rate,
	}
	for name in named:
		if absf(rate - float(named[name])) <= float(named[name]) * tolerance:
			return name
	return "otro"
