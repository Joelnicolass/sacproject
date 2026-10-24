extends Node

## Capture harness: starts a 1v1 match against the AI on the map and the god of the command line, waits, then saves PNGs
## from a few fixed viewpoints (the local wizard from behind, an overview, the nearest mana fountain) every few seconds
## and quits. It only watches: it plays no input and moves no actor; the camera is its own.
## It lives in a subfolder because AgentKit mounts every .gd of agent/harness/ itself.
## Args after `--`: --map=<tag> --god=<god of the local wizard> [--biome=<god whose land the map wears; default --god>] [--ai-god=<god>] [--wizard=<tag>] [--after=<s> before the first
## round] [--shots=<n> rounds] [--every=<s>] [--out=<dir>] [--views=wizard,wizard_close,foe_close,overview,fountain,manahoar,tower] [--hover=wizard] [--structure=htlm|pcas, the Manalith or the Shrine of the wizard's god raised over the free fountain closest to him, before the first round (no casting time, no mana); the match's own flags
## [--cast=<spell tag>[,<tag>…], the local wizard casts them one after the other once --after has passed, before the first round: a spell that aims at himself (a ward) on himself,
## any other on the closest enemy; mana is filled first] (--seed=…, --quality=low|medium|high…) go through as usual. Headless runs the same clock and saves nothing.
## Windowed: `-- --agent=flow --flow=match_shots.json` (the flow gives the sandbox that applies the quality preset).

const GROUP_FOUNT := &"manafount"
const GROUP_UNIT := &"unit"
const TAG_MANAHOAR := &"oham"
## Where each view puts the camera, from its subject.
@export_group("Views")
@export_range(4.0, 40.0, 0.5, "suffix:m") var behind_m := 12.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var behind_up_m := 5.0
## The "wizard_close" view: the wizard from behind, close enough to read a ward on his body.
@export_range(2.0, 20.0, 0.5, "suffix:m") var wizard_close_m := 5.5
@export_range(0.0, 10.0, 0.5, "suffix:m") var wizard_close_up_m := 1.8
## The "foe_close" view: the closest enemy of the wizard (the target of --cast) from the wizard's side, to read a state on it.
@export_range(2.0, 30.0, 0.5, "suffix:m") var foe_close_m := 7.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var foe_close_up_m := 2.0
@export_range(30.0, 300.0, 5.0, "suffix:m") var overview_m := 110.0
@export_range(4.0, 60.0, 0.5, "suffix:m") var fount_m := 16.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var fount_up_m := 6.0
## The "manahoar" view: the camera stands this far from the nearest Manahoar (any bearing the wizard's side is) and this high.
@export_range(2.0, 30.0, 0.5, "suffix:m") var manahoar_m := 6.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var manahoar_up_m := 1.5

## The "tower" view: the camera stands this far from the nearest tower, toward the local wizard, and this high.
@export_range(10.0, 80.0, 1.0, "suffix:m") var tower_m := 40.0
@export_range(0.0, 40.0, 0.5, "suffix:m") var tower_up_m := 14.0

@export var camera: Camera3D

var _shot_count := 0


static func arg(arg_name: String, fallback: String = "") -> String:
	var prefix := "--%s=" % arg_name
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.substr(prefix.length())
	return fallback


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# Outlive the scene change: move to the root under a stub that the change can free.
	var stub := Node.new()
	tree.root.remove_child(self)
	tree.root.add_child(stub)
	tree.root.add_child(self)
	tree.current_scene = stub
	var god := arg("god", "persephone")
	SacrificeFlow.set_pick(arg("wizard", "cwa0"), god)
	## The land is the product's: the setup's biome (the capture wears the wizard's god unless --biome says otherwise).
	var chosen := MatchSetup.new()
	chosen.biome_god = StringName(arg("biome", god))
	SacrificeFlow.play_vs_ai(StringName(arg("ai-god")), chosen)
	var world := await _wait_world()
	if world == null:
		push_error("match_shots: the world never had a local wizard.")
		tree.quit(1)
		return
	if not arg("structure").is_empty():
		_raise_structure(world, arg("structure"))
	var out := arg("out", "res://agent/out/match_shots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var views := arg("views", "wizard,overview,fountain").split(",", false)
	var rounds := maxi(int(arg("shots", "3")), 1)
	var every_s := maxf(float(arg("every", "5")), 0.1)
	var elapsed_s := maxf(float(arg("after", "10")), 0.0)
	await tree.create_timer(elapsed_s).timeout
	if not arg("cast").is_empty():
		await _cast_all(world, arg("cast").split(",", false))
		await tree.create_timer(maxf(float(arg("cast-wait", "1.5")), 0.0)).timeout
	var map_tag := String(MapCatalog.active().tag)
	for round in rounds:
		for view in views:
			await _shoot(world, view, "%s/%s_%s_%s_t%03d.png" % [out, map_tag, god, view, roundi(elapsed_s)])
		elapsed_s += every_s
		if round < rounds - 1:
			await tree.create_timer(every_s).timeout
	print("MATCH_SHOTS done: %d shots in %s (preset %s)" % [_shot_count, out, _preset(world)])
	tree.quit(0)


## --cast: each tag through the wizard's own Caster (cost, cooldown and casting time as in play), mana refilled before each one.
func _cast_all(world: MatchWorld, tags: PackedStringArray) -> void:
	var wizard := world.local_wizard() as WizardBody
	var caster := wizard.get_node("Caster") as Caster
	for tag in tags:
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.current = pool.maximum
		var action := caster.action_for(tag)
		var foe := _closest_foe(wizard)
		var aimed := null if action == null or action.pick == SpellAction.Pick.SELF else foe
		var point := aimed.global_position if aimed != null else wizard.global_position
		caster.request_cast(tag, point, aimed)
		print("match_shots: cast %s (casting: %s)" % [tag, caster.is_casting()])
		while caster.is_casting():
			await get_tree().physics_frame


## The enemy body closest to `wizard` (a creature or a wizard of another side), or null.
func _closest_foe(wizard: WizardBody) -> Node3D:
	var best: Node3D
	var best_d := INF
	for group in [&"unit", &"wizard"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or body == wizard or SideRelations.stance(wizard.owner_slot, int(body.get("owner_slot"))) == SideRelations.Stance.ALLY:
				continue
			var d := body.global_position.distance_to(wizard.global_position)
			if d < best_d:
				best = body
				best_d = d
	return best


func _wait_world() -> MatchWorld:
	for frame in 1800:
		await get_tree().process_frame
		var world := get_tree().current_scene as MatchWorld
		if world != null and world.local_wizard() != null:
			return world
	return null


func _preset(world: MatchWorld) -> String:
	var rig := world.map.look if world.map != null else null
	return String(rig.quality_preset.id) if rig != null and rig.quality_preset != null else "none"


func _shoot(world: MatchWorld, view: String, file: String) -> void:
	var wizard := world.local_wizard()
	var focus := wizard.global_transform.origin
	var spot := Vector3.ZERO
	var look := focus + Vector3.UP * 1.5
	match view:
		"wizard":
			spot = focus + _away_from_foe(world, wizard) * behind_m + Vector3.UP * behind_up_m
		"wizard_close":
			look = focus + Vector3.UP * 1.4
			spot = focus + _away_from_foe(world, wizard) * wizard_close_m + Vector3.UP * wizard_close_up_m
		"foe_close":
			var foe := _closest_foe(wizard)
			if foe == null:
				print("match_shots: no enemy; view skipped")
				return
			look = BodyNudge.center(foe)
			var from_foe := (focus - foe.global_position) * Vector3(1.0, 0.0, 1.0)
			spot = look + (from_foe.normalized() if from_foe.length() > 0.1 else Vector3.BACK) * foe_close_m + Vector3.UP * foe_close_up_m
		"overview":
			var middle := (focus + _foe_position(world, wizard)) * 0.5
			spot = middle + Vector3(0.0, overview_m, overview_m * 0.55)
			look = middle
		"fountain":
			var fount := _nearest_fount(focus)
			if fount == null:
				print("match_shots: no mana fountain in the map; view skipped")
				return
			look = fount.global_transform.origin + Vector3.UP * 3.0
			var toward := (focus - fount.global_transform.origin) * Vector3(1.0, 0.0, 1.0)
			spot = look + toward.normalized() * fount_m + Vector3.UP * fount_up_m
		"manahoar":
			var hoar := _nearest_manahoar(focus)
			if hoar == null:
				print("match_shots: no Manahoar in the match; view skipped")
				return
			look = hoar.global_transform.origin + Vector3.UP * 1.2
			var side := (focus - hoar.global_transform.origin) * Vector3(1.0, 0.0, 1.0)
			spot = look + (side.normalized() if side.length() > 0.1 else Vector3.BACK) * manahoar_m + Vector3.UP * manahoar_up_m
		"tower":
			var tower := _nearest_tower(focus)
			if tower == null:
				print("match_shots: no tower in the match; view skipped")
				return
			look = tower.global_transform.origin + Vector3.UP * 8.0
			var toward := (focus - tower.global_transform.origin) * Vector3(1.0, 0.0, 1.0)
			spot = look + (toward.normalized() if toward.length() > 0.1 else Vector3.BACK) * tower_m + Vector3.UP * tower_up_m
		_:
			push_warning("match_shots: unknown view '%s'" % view)
			return
	camera.position = spot
	camera.look_at(look)
	camera.make_current()
	_report_wards(wizard)
	_report_afflictions(wizard)
	if arg("hover") == "wizard":
		_hover(world, wizard)
	await _save(file)


## One line per ward of the wizard at every shot: is it on, what the look and its emitters do and where they are, so a capture
## with nothing in it says why (ward off, look hidden, emitter not emitting, drawn far from the body).
func _report_wards(wizard: Node3D) -> void:
	var wards := Wards.of(wizard)
	if wards == null:
		return
	for child in wards.get_children():
		var ward := child as Ward
		if ward == null or not (ward.is_on() or ward.shown):
			continue
		var parts := PackedStringArray()
		for part in ward.find_children("*", "Node3D", true, false):
			if part is GeometryInstance3D or part is CPUParticles3D:
				var emitting := " emitting=%s" % (part as CPUParticles3D).emitting if part is CPUParticles3D else ""
				parts.append("%s visible=%s at (%.1f, %.1f, %.1f)%s" % [part.name, (part as Node3D).is_visible_in_tree(), part.global_position.x, part.global_position.y, part.global_position.z, emitting])
		print("match_shots: ward %s on=%s shown=%s ticks_left=%d look=%s wizard at (%.1f, %.1f, %.1f) | %s" % [ward.name, ward.is_on(), ward.shown, ward.ticks_left(),
			ward.look.is_visible_in_tree() if ward.look else "-", wizard.global_position.x, wizard.global_position.y, wizard.global_position.z, " | ".join(parts)])


## One line per state that is on in the enemy closest to the wizard (the target of --cast): its layers, the drawn parts under it (visible,
## where, emitting) and the skin texture, so a capture with nothing in it says why.
func _report_afflictions(wizard: Node3D) -> void:
	var foe := _closest_foe(wizard)
	var afflictions := Afflictions.of(foe)
	if afflictions == null:
		return
	for child in afflictions.get_children():
		var state := child as Affliction
		if state == null or not state.is_on():
			continue
		var parts := PackedStringArray()
		for part in state.find_children("*", "Node3D", true, false):
			if part is MeshInstance3D or part is CPUParticles3D or part is VineLook or part is RingsLook:
				var emitting := " emitting=%s" % (part as CPUParticles3D).emitting if part is CPUParticles3D else ""
				parts.append("%s visible=%s at (%.1f, %.1f, %.1f)%s" % [part.name, (part as Node3D).is_visible_in_tree(), part.global_position.x, part.global_position.y, part.global_position.z, emitting])
		var layers := " layers=%d" % (state as SpellAffliction).layers() if state is SpellAffliction else ""
		var skin := " skin=%s" % (afflictions.look.swap_texture != null) if afflictions.look != null else ""
		print("match_shots: affliction %s on%s%s foe %s at (%.1f, %.1f, %.1f) | %s" % [state.type.id, layers, skin, foe.name, foe.global_position.x, foe.global_position.y, foe.global_position.z, " | ".join(parts)])


## --hover=wizard: the pointer rests on the local wizard (the HoverFrame draws its frame). The probe stops naming what is
## under the real mouse; the harness names the wizard instead.
func _hover(world: MatchWorld, wizard: Node3D) -> void:
	for node in world.find_children("*", "TargetProbe", true, false):
		var probe := node as TargetProbe
		probe.process_mode = Node.PROCESS_MODE_DISABLED
		probe.hovered = wizard
		probe.kind = &"own_unit"


func _save(file: String) -> void:
	for frame in 3:
		await get_tree().process_frame
	_shot_count += 1
	if DisplayServer.get_name() == "headless":
		print("shot (headless, not saved): %s" % file)
		return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
	print("shot %s (%s)" % [file, error_string(error)])


func _foe_position(world: MatchWorld, wizard: Node3D) -> Vector3:
	for other in world.get_node("%Wizards").get_children():
		if other != wizard and other is Node3D:
			return (other as Node3D).global_transform.origin
	return wizard.global_transform.origin + Vector3(0.0, 0.0, -30.0)


## Flat unit vector from the foe to the wizard: standing there, the camera is behind the wizard.
func _away_from_foe(world: MatchWorld, wizard: Node3D) -> Vector3:
	var away := (wizard.global_transform.origin - _foe_position(world, wizard)) * Vector3(1.0, 0.0, 1.0)
	return away.normalized() if away.length() > 0.1 else Vector3(0.0, 0.0, 1.0)


## --structure=<spell tag>: the tower the local wizard's god raises with that spell, over the free fountain closest to him.
func _raise_structure(world: MatchWorld, tag: String) -> void:
	var wizard := world.local_wizard() as WizardBody
	var god := wizard.god_type()
	var entry := god.structure_for(GameData.spell(tag)) if god != null else null
	var fount := TowerRules.closest_free_fount(get_tree(), wizard.global_position, INF)
	var spawner := get_tree().get_first_node_in_group(StructureSpawner.GROUP) as StructureSpawner
	if entry == null or fount == null or spawner == null:
		push_warning("match_shots: cannot raise '%s' (god %s)." % [tag, wizard.god])
		return
	var tower := spawner.spawn_tower(entry.scene, fount, wizard.owner_slot, wizard.rotation.y)
	print("match_shots: %s raised over %s" % [tower.name if tower != null else "nothing", fount.name])


func _nearest_tower(from: Vector3) -> Node3D:
	var best: Node3D
	var best_d := INF
	for node in get_tree().get_nodes_in_group(CastTower.TOWER_GROUP):
		var tower := node as Node3D
		if tower != null and tower.global_transform.origin.distance_to(from) < best_d:
			best = tower
			best_d = tower.global_transform.origin.distance_to(from)
	return best


func _nearest_fount(from: Vector3) -> Node3D:
	var best: Node3D
	var best_d := INF
	for node in get_tree().get_nodes_in_group(GROUP_FOUNT):
		var fount := node as Node3D
		if fount != null and fount.global_transform.origin.distance_to(from) < best_d:
			best = fount
			best_d = fount.global_transform.origin.distance_to(from)
	return best


## The Manahoar (creature tag `oham`) closest to `from`; null when the match has none yet.
func _nearest_manahoar(from: Vector3) -> Node3D:
	var best: Node3D
	var best_d := INF
	for node in get_tree().get_nodes_in_group(GROUP_UNIT):
		var body := node as UnitBody
		if body == null or body.type == null or StringName(body.type.tag) != TAG_MANAHOAR:
			continue
		var d := body.global_transform.origin.distance_to(from)
		if d < best_d:
			best = body
			best_d = d
	return best
