extends Node

## Capture harness: starts a 1v1 match against the AI on the map and the god of the command line, waits, then saves PNGs
## from a few fixed viewpoints (the local wizard from behind, an overview, the nearest mana fountain) every few seconds
## and quits. It only watches: it plays no input and moves no actor; the camera is its own.
## It lives in a subfolder because AgentKit mounts every .gd of agent/harness/ itself.
## Args after `--`: --map=<tag> --god=<god of the local wizard> [--biome=<god whose land the map wears; default --god>] [--ai-god=<god>] [--wizard=<tag>] [--after=<s> before the first
## round] [--shots=<n> rounds] [--every=<s>] [--out=<dir>] [--views=wizard,overview,fountain,manahoar] [--hover=wizard]; the match's own flags
## (--seed=…, --quality=low|medium|high…) go through as usual. Headless runs the same clock and saves nothing.
## Windowed: `-- --agent=flow --flow=match_shots.json` (the flow gives the sandbox that applies the quality preset).

const GROUP_FOUNT := &"manafount"
const GROUP_UNIT := &"unit"
const TAG_MANAHOAR := &"oham"
## Where each view puts the camera, from its subject.
@export_group("Views")
@export_range(4.0, 40.0, 0.5, "suffix:m") var behind_m := 12.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var behind_up_m := 5.0
@export_range(30.0, 300.0, 5.0, "suffix:m") var overview_m := 110.0
@export_range(4.0, 60.0, 0.5, "suffix:m") var fount_m := 16.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var fount_up_m := 6.0
## The "manahoar" view: the camera stands this far from the nearest Manahoar (any bearing the wizard's side is) and this high.
@export_range(2.0, 30.0, 0.5, "suffix:m") var manahoar_m := 6.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var manahoar_up_m := 1.5

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
	var out := arg("out", "res://agent/out/match_shots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var views := arg("views", "wizard,overview,fountain").split(",", false)
	var rounds := maxi(int(arg("shots", "3")), 1)
	var every_s := maxf(float(arg("every", "5")), 0.1)
	var elapsed_s := maxf(float(arg("after", "10")), 0.0)
	await tree.create_timer(elapsed_s).timeout
	var map_tag := String(MapCatalog.active().tag)
	for round in rounds:
		for view in views:
			await _shoot(world, view, "%s/%s_%s_%s_t%03d.png" % [out, map_tag, god, view, roundi(elapsed_s)])
		elapsed_s += every_s
		if round < rounds - 1:
			await tree.create_timer(every_s).timeout
	print("MATCH_SHOTS done: %d shots in %s (preset %s)" % [_shot_count, out, _preset(world)])
	tree.quit(0)


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
		_:
			push_warning("match_shots: unknown view '%s'" % view)
			return
	camera.position = spot
	camera.look_at(look)
	camera.make_current()
	if arg("hover") == "wizard":
		_hover(world, wizard)
	await _save(file)


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
