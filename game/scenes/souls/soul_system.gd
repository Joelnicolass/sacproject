class_name SoulSystem
extends Node

## Souls of the match. The server (or solo) spawns one soul on each creature corpse once it has
## fallen (sacengine spawnSoul when dying ends, state.d:14016), hands each soul to the wizard
## that passes over it (updateSoul, state.d:14925) and drops one on P (dropSoul, state.d:9501).
## Clients only send the drop and show the answer (`message`: MatchCommand says it on %Battle, RFC-025c).

signal message(text: String)
signal soul_spawned(soul: Node3D)
## A wizard takes `count` souls into its purse, announced right before the purse changes. `origin` says where they
## came from (npc / creature / wizard), for the souls ledger of the bench (RFC-024 §5.2); Convert says its own
## on SacrificeSystem.souls_converted.
signal soul_collected(slot: int, count: int, origin: StringName)

## Collect priority (state.d:14926, CollectStance): own side first, then an ally's (RFC-049 049c), then souls with no side, then the enemy's.
enum Stance { OWN, ALLY, NEUTRAL, ENEMY }

const SOUL_SCENE := preload("res://scenes/souls/soul.tscn")
const _SOUL := preload("res://scenes/souls/soul.gd")
const NO_SOULS := Refusal.NO_SOULS
## Where a soul comes from (adenda 1, ledger `by_origin`): the dead of the map's NPC sides, any other creature,
## and the soul a wizard dropped with P.
const ORIGIN_NPC := &"npc"
const ORIGIN_CREATURE := &"creature"
const ORIGIN_WIZARD := &"wizard"

## Holds `rules: MatchRules` and `local_wizard()` (MatchWorld). Convert (RFC-020e) lives in SacrificeSystem.
@export var world: Node
@export var souls_root: Node3D
@export var spawner: MpSpawner

var _serial := 0


func _enter_tree() -> void:
	spawner.spawn_function = _make


func _ready() -> void:
	add_to_group("soul_system")
	if not is_multiplayer_authority():
		set_physics_process(false)
		return
	get_tree().node_added.connect(_watch)
	## A unit placed in the scene joins the group in its own _ready, which runs after this one when it
	## comes later in the tree: look for those once everything is ready.
	_watch_placed_units.call_deferred()


## `data`: x, y, z, number, owner_slot, attached, dropped, emerging. Server or solo only.
func spawn_soul(data: Dictionary) -> Node3D:
	if not is_multiplayer_authority():
		return null
	_serial += 1
	data["name"] = "Soul%d" % _serial
	var soul := spawner.spawn_here(data) as Node3D
	soul_spawned.emit(soul)
	return soul


func request_drop() -> void:
	if MpAuthority.should_send_command():
		submit_drop.rpc_id(MpAuthority.SERVER_PEER)
		return
	if not drop_soul(MpKit.local_slot()) and drop_allowed():
		_say(NO_SOULS)


## The match lets P drop a soul (MatchRules.enable_drop_soul of the world's rules, options.d:106; RFC-031 031d sets it
## from the boot or --[no-]drop-soul). Server or solo: a client's world keeps the product rules.
func drop_allowed() -> bool:
	var rules := _rules()
	return rules == null or rules.enable_drop_soul


## sacengine dropSoul: one soul off the purse, emerging at the wizard's feet with its side. Nothing (and no answer)
## when the match does not allow it.
func drop_soul(slot: int) -> bool:
	if not drop_allowed():
		print("soltar almas desactivado: el slot %d no suelta" % slot)
		return false
	var wizard := _wizard_for(slot)
	if wizard == null:
		return false
	var purse := wizard.get_node_or_null("SoulPurse") as SoulPurse
	if purse == null or not purse.spend(1):
		return false
	var at := wizard.global_position
	spawn_soul({"x": at.x, "y": at.y, "z": at.z, "number": 1, "owner_slot": slot, "dropped": true, "origin": String(ORIGIN_WIZARD)})
	return true


@rpc("any_peer", "call_remote", "reliable")
func submit_drop() -> void:
	var slot := MpAuthority.command_slot(self)
	if slot <= 0:
		return
	if not drop_soul(slot) and drop_allowed():
		_tell_no_souls.rpc_id(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _tell_no_souls() -> void:
	_say(NO_SOULS)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("drop_soul", false, true):
		return
	if WorldInput.blocked(self):
		return
	var match_world := world as MatchWorld
	if match_world == null or match_world.local_wizard() == null:
		return
	get_viewport().set_input_as_handled()
	request_drop()


func _say(text: String) -> void:
	message.emit(text)


func _physics_process(_delta: float) -> void:
	var facts := ReachFacts.of_rules(_rules())
	var wizards := get_tree().get_nodes_in_group("wizard")
	for soul in get_tree().get_nodes_in_group("soul"):
		if soul.state == _SOUL.State.NORMAL:
			_try_collect(soul, wizards, facts.soul_m, facts.soul_up_m)


## Nearest wizard within `reach` on the ground and `reach_up` up and down, best stance first; a tie leaves it.
## Ref: res://scenes/match/reach_facts.gd (soul_m, soul_up_m).
func _try_collect(soul: Node3D, wizards: Array[Node], reach: float, reach_up: float) -> void:
	var best: Node3D = null
	var best_stance := Stance.ENEMY + 1
	var best_d := INF
	var tied := false
	for node in wizards:
		var wizard := node as Node3D
		if wizard == null or not _can_collect(wizard):
			continue
		var slot := int(wizard.get("owner_slot"))
		if not (soul as Soul).can_be_collected_by(slot):
			continue
		var d := _center(wizard) - soul.global_position
		if Vector2(d.x, d.z).length_squared() > reach * reach or absf(d.y) > reach_up:
			continue
		var stance := _stance(soul, slot)
		var dist := d.length_squared()
		if stance > best_stance:
			continue
		if stance == best_stance:
			if dist > best_d:
				continue
			if dist == best_d:
				tied = true
				continue
		best = wizard
		best_stance = stance
		best_d = dist
		tied = false
	if best == null or tied:
		return
	var collected := soul as Soul
	collected.begin_collect(best, int(best.get("owner_slot")))
	soul_collected.emit(int(best.get("owner_slot")), collected.number, collected.origin)
	(best.get_node("SoulPurse") as SoulPurse).add(collected.number)
	collected.sever()


func _stance(soul: Node3D, slot: int) -> Stance:
	var soul_slot := int(soul.get("owner_slot"))
	if soul_slot == 0:
		return Stance.NEUTRAL
	if soul_slot == slot:
		return Stance.OWN
	return Stance.ALLY if SideRelations.stance(soul_slot, slot) == SideRelations.Stance.ALLY else Stance.ENEMY


## Dying and ghost wizards do not collect (canCollectSouls, state.d:243).
func _can_collect(wizard: Node3D) -> bool:
	if wizard.get_node_or_null("SoulPurse") == null:
		return false
	if wizard is WizardBody and not (wizard as WizardBody).can_collect_souls():
		return false
	var health := wizard.get_node_or_null("Health") as Health
	return health == null or not health.is_dead()


func _center(wizard: Node3D) -> Vector3:
	var col := wizard.get_node_or_null("Collision") as Node3D
	return col.global_position if col else wizard.global_position


func _wizard_for(slot: int) -> Node3D:
	for wizard in get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) == slot:
			return wizard as Node3D
	return null


func _watch_placed_units() -> void:
	for unit in get_tree().get_nodes_in_group("unit"):
		_watch(unit)


func _watch(node: Node) -> void:
	if not node is UnitBody:
		return
	var on_died := _on_unit_died.bind(node)
	if not node.is_connected("died", on_died):
		node.connect("died", on_died)


func _on_unit_died(_tag: String, slot: int, _at: Vector3, unit: Node3D) -> void:
	if not is_instance_valid(unit):
		return
	var type: CreatureType = (unit as UnitBody).type
	var count := type.souls if type else 0
	if not DeathRules.leaves_soul(count, false):
		return
	if (unit as UnitBody).gibbed:
		_spawn_free(unit, slot, count)
		return
	var remains := (unit as UnitBody).corpse()
	if not remains.is_settled:
		remains.settled.connect(_spawn_on_corpse.bind(unit, slot, count), CONNECT_ONE_SHOT)
		return
	_spawn_on_corpse(unit, slot, count)


## The origin of the souls a creature leaves: the NPCs of the map (group `npc`) are not the creatures of a wizard.
static func origin_of(unit: Node) -> StringName:
	return ORIGIN_NPC if unit != null and unit.is_in_group(&"npc") else ORIGIN_CREATURE


func _spawn_on_corpse(unit: Node3D, slot: int, count: int) -> void:
	if not is_instance_valid(unit) or not unit.is_inside_tree():
		return
	var at := (unit as UnitBody).soul_anchor()
	var soul := spawn_soul({"x": at.x, "y": at.y, "z": at.z, "number": count, "owner_slot": slot, "attached": true, "origin": String(origin_of(unit))})
	if soul:
		soul.set("corpse", unit)


## A creature that burst (Gib): its soul rises where it stood, off any corpse (sacengine gib, state.d:8341-8365).
func _spawn_free(unit: Node3D, slot: int, count: int) -> void:
	var at := (unit as UnitBody).soul_anchor()
	spawn_soul({"x": at.x, "y": at.y, "z": at.z, "number": count, "owner_slot": slot, "attached": false, "origin": String(origin_of(unit))})


func _make(data: Variant) -> Node:
	var soul := SOUL_SCENE.instantiate() as Soul
	soul.setup(data)
	return soul


func _rules() -> MatchRules:
	var rules: Variant = world.get("rules") if world else null
	return rules if rules is MatchRules else null
