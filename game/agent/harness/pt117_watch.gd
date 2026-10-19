extends Node

## Read-only observer for the F117 playtest (RFC-030 030f, damage passives). It never moves, orders or damages anything.
## It listens to every unit's UnitBody.struck (the blow as the attacker computed it) and Health.hit (what the target
## really lost) and prints one line per melee blow:
##   PT117 HIT <attacker>(<tag>) h_att=<attacker health/max> -> <target>(<tag>) h_tgt_before=<..> struck=<amount>
##         taken=<health lost> in_ratio=<taken/struck> raw=<recomputed raw blow> out_ratio=<struck/raw>
## in_ratio is the target's incoming factor (Taurock korq); out_ratio is the attacker's outgoing melee factor
## (Firefist ahtf). raw is recomputed here from the same data MeleeAttack.roll_damage reads (anim frames, facing,
## roll, strength, resistance), so out_ratio does not trust the product's own factor.
## Tolerates scene == null: arm() just finds nothing.
##   arm()     connects to the units present (group "unit"). Returns the count.
##   report()  prints the totals.
## Props for wait_until: units, taurock_hits (blows taken by a raeb), firefist_hits (blows dealt by a lrtf).

const _MA := preload("res://scenes/units/attacks/melee_attack.gd")

var units := 0
var taurock_hits := 0
var firefist_hits := 0

var _last_hit: Dictionary = {}   # unit -> {amount, before}
var _lines: Array[String] = []


func arm() -> String:
	for node in get_tree().get_nodes_in_group("unit"):
		if not node is Node3D or not node.has_signal("struck"):
			continue
		var health := node.get_node_or_null("Health")
		if health == null:
			continue
		if not node.is_connected("struck", _on_struck):
			node.connect("struck", _on_struck.bind(node))
			health.connect("hit", _on_hit.bind(node, health))
			units += 1
			print("PT117 UNIT %s tag=%s slot=%d hp=%.2f/%.2f h=%.3f" % [node.name, _tag(node), int(node.get("owner_slot")),
				float(health.get("current")), float(health.get("maximum")), _h(health)])
	return "armed %d" % units


func _tag(node: Node) -> String:
	var type: Variant = node.get("type")
	return str(type.get("tag")) if type != null else "?"


func _h(health: Node) -> float:
	var m := float(health.get("maximum"))
	return float(health.get("current")) / m if m > 0.0 else 0.0


func _on_hit(amount: float, _from_slot: int, _was_full: bool, unit: Node, health: Node) -> void:
	var m := float(health.get("maximum"))
	var before := (float(health.get("current")) + amount) / m if m > 0.0 else 0.0
	_last_hit[unit] = {"amount": amount, "before": before}


func _raw(attacker: Node, target: Node3D, chance: float, roll: float) -> float:
	var ma := attacker.get_node_or_null("MeleeAttack")
	if ma == null:
		return NAN
	var anim: Dictionary = ma.get("_anim")
	var ticks: Array = anim.get("attack_ticks", [])
	var pending := float(anim.get("frames", 1)) / (float(anim.get("framerate", 30)) * float(maxi(1, ticks.size())))
	var facing := 1.5 + 0.5 * _MA.facing_of(attacker as Node3D).dot(_MA.facing_of(target))
	var damage := facing * pending
	if roll >= chance:
		damage *= (1.0 - roll) / (1.0 - chance)
	var type: Variant = ma.get("type")
	damage *= float(type.get("melee_strength"))
	var foe := _MA.profile_of(target)
	damage *= float(ma.get("melee_resistance_scale")) * maxf(0.0, float(foe.get("resistance", 1.0)))
	var th := target.get_node_or_null("Health")
	if th != null:
		damage *= maxf(0.0, float(th.get("damage_factor")))
	return damage


func _on_struck(target: Node3D, amount: float, chance: float, roll: float, attacker: Node) -> void:
	var ah := attacker.get_node_or_null("Health")
	var h_att := _h(ah) if ah != null else NAN
	var info: Dictionary = _last_hit.get(target, {"amount": NAN, "before": NAN})
	_last_hit.erase(target)
	var taken := float(info["amount"])
	var raw := _raw(attacker, target, chance, roll)
	var line := "PT117 HIT %s(%s) h_att=%.3f -> %s(%s) h_tgt_before=%.3f struck=%.2f taken=%.2f in_ratio=%.4f raw=%.2f out_ratio=%.4f p=%.3f r=%.3f hit=%s" % [
		attacker.name, _tag(attacker), h_att, target.name, _tag(target), float(info["before"]), amount, taken,
		taken / amount if amount > 0.0 else NAN, raw, amount / raw if raw > 0.0 else NAN, chance, roll, str(roll < chance)]
	print(line)
	_lines.append(line)
	if _tag(target) == "raeb":
		taurock_hits += 1
	if _tag(attacker) == "lrtf":
		firefist_hits += 1


func report() -> String:
	for node in get_tree().get_nodes_in_group("unit"):
		var health := node.get_node_or_null("Health")
		if health != null:
			print("PT117 STATE %s(%s) hp=%.2f/%.2f h=%.3f" % [node.name, _tag(node), float(health.get("current")),
				float(health.get("maximum")), _h(health)])
	var r := "PT117 REPORT units=%d taurock_hits=%d firefist_hits=%d" % [units, taurock_hits, firefist_hits]
	print(r)
	return r
