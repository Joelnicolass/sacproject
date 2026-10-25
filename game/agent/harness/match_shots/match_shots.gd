extends Node

## Capture harness: starts a 1v1 match against the AI on the map and the god of the command line, waits, then saves PNGs
## from a few fixed viewpoints (the local wizard from behind, an overview, the nearest mana fountain) every few seconds
## and quits. It only watches: it plays no input and moves no actor; the camera is its own.
## It lives in a subfolder because AgentKit mounts every .gd of agent/harness/ itself.
## Args after `--`: --map=<tag> --god=<god of the local wizard> [--biome=<god whose land the map wears; default --god>] [--ai-god=<god>] [--wizard=<tag>] [--after=<s> before the first
## round] [--shots=<n> rounds] [--every=<s>, from 0.02: a burst of shots; the files end in the milliseconds, _t001500] [--out=<dir>] [--views=wizard,wizard_close,halo,foe_close,aim,scar,zone,rift,cloud,tornado,tornado_far,overview,fountain,manahoar,tower,wall,ground,rim,hud] [hud view (055h-1): the game's own camera and HUD as the player sees them, plus a <png>.json with every widget's rectangle, the cursor size and the pointer/world check; --mana=<0..1> sets the wizard's mana, --select=<n> selects up to n of his creatures, --radial opens the order menu in the middle; the window size is the run's (agent/harness/godot60_res.sh PT_RES) and --ui-scale=<0.75..1.4> the interface size] [--ground-at=<x>,<z> world metres, the point the "ground" view stands over; default the local wizard] [--ground-yaw=<degrees> where it looks, 0 = toward -z] [--hover=wizard] [--structure=htlm|pcas, the Manalith or the Shrine of the wizard's god raised over the free fountain closest to him, before the first round (no casting time, no mana); the match's own flags
## [--cast=<spell tag>[,<tag>…], the local wizard casts them one after the other once --after has passed, before the first round: a spell that aims at himself (a ward, Healing Aura) on himself,
## one that aims at a soul (pmcd, dnws, deda) on the closest soul he may fetch (the harness makes one when there is none), a wall (lwrf, laws, laww, lawv, cnef) on the ground half way to the closest enemy (--cast-wait=6 to see it grown); any other on the closest enemy (a zone, on the ground at its feet; Rainbow on himself, the first body of its chain; 061e needs --level=4 or more: ntlc, wobr, rifd, olah; 061j needs --level=8: rter with --god=persephone, nrot with --god=stratos); 061i needs --level=8 or more: mrhc, egar, pavi, ivob, taed (the "carrier" view follows the carrier; the report prints the side, rage and swelling of the closest enemy); mana is filled first; --cast-wait=<s> is the wait after the last cast (a cloud rains after its cast: 10 shows the rain, 14 Cloudkill's bolts; Explosion goes off 3.8 s after it starts: 4.5)] (--seed=…, --quality=low|medium|high…) go through as usual. Headless runs the same clock and saves nothing.
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
## The "halo" view: the wizard from behind with the sky over his head in frame (the Halo of Earth orbits 5 m up: wizard_close cuts it off).
@export_range(4.0, 30.0, 0.5, "suffix:m") var halo_m := 11.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var halo_up_m := 5.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var halo_look_up_m := 4.0
## The "foe_close" view: the closest enemy of the wizard (the target of --cast) from the wizard's side, to read a state on it.
@export_range(2.0, 30.0, 0.5, "suffix:m") var foe_close_m := 7.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var foe_close_up_m := 2.0
## The "carrier" view: the first spell carrier in flight from this far back and this high (Death is 12 m tall: use 30 and 10).
@export_range(2.0, 80.0, 0.5, "suffix:m") var carrier_m := 8.0
@export_range(0.0, 40.0, 0.5, "suffix:m") var carrier_up_m := 4.0
## The "aim" view: the place the last --cast aimed at, from the wizard's side this far back and this high (a cow falling there, the mark it leaves).
@export_range(5.0, 120.0, 0.5, "suffix:m") var aim_m := 30.0
@export_range(0.0, 80.0, 0.5, "suffix:m") var aim_up_m := 18.0
## The "zone" view: the camera stands this far from the first ground zone (the one of --cast=pxef|zorf|tfir), toward the wizard, this high.
@export_range(10.0, 200.0, 1.0, "suffix:m") var zone_m := 45.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var zone_up_m := 28.0
## The "rift" view (Demonic Rift, --cast=tfir): the camera stands this far from the rift (2.5 m wide), toward the wizard, this high, looking at its mouth
## with the spirits that leave it; the "zone" view is 45 m away and loses it.
@export_range(4.0, 60.0, 0.5, "suffix:m") var rift_m := 12.0
@export_range(0.0, 40.0, 0.5, "suffix:m") var rift_up_m := 6.0
## The "cloud" view (061h: --cast=grfr|rifr|galp|likc|rtem): the camera looks at the middle between the first zone's land and its cloud, from 1.9 times
## the cloud's height away (at least this far) and a third of it up, on the first of 8 bearings with a clear line to the land.
@export_range(10.0, 200.0, 1.0, "suffix:m") var cloud_min_m := 45.0
## The "tornado" view (061j: --god=stratos --cast=nrot): the camera stands this far from the Tornado's foot (toward the wizard), this high, and looks
## this high up the funnel, so the funnel is seen from outside. "tornado_far" is the same from far enough to see its whole height.
@export_range(10.0, 300.0, 1.0, "suffix:m") var tornado_m := 90.0
@export_range(0.0, 300.0, 1.0, "suffix:m") var tornado_up_m := 40.0
@export_range(0.0, 500.0, 1.0, "suffix:m") var tornado_look_up_m := 120.0
@export_range(100.0, 1500.0, 5.0, "suffix:m") var tornado_far_m := 450.0
@export_range(0.0, 600.0, 1.0, "suffix:m") var tornado_far_up_m := 200.0
@export_range(0.0, 500.0, 1.0, "suffix:m") var tornado_far_look_up_m := 220.0
## The "scar" view: the camera stands this far from the last mark painted on the ground (toward the wizard), this high, looking at it.
@export_range(5.0, 80.0, 1.0, "suffix:m") var scar_m := 22.0
@export_range(2.0, 80.0, 0.5, "suffix:m") var scar_up_m := 16.0
@export_range(30.0, 300.0, 5.0, "suffix:m") var overview_m := 110.0
## The "wall" view: the newest wall standing, seen from the wizard's side this far from its middle and this high.
@export_range(5.0, 120.0, 1.0, "suffix:m") var wall_m := 45.0
@export_range(0.0, 60.0, 0.5, "suffix:m") var wall_up_m := 14.0
@export_range(4.0, 60.0, 0.5, "suffix:m") var fount_m := 16.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var fount_up_m := 6.0
## The "manahoar" view: the camera stands this far from the nearest Manahoar (any bearing the wizard's side is) and this high.
@export_range(2.0, 30.0, 0.5, "suffix:m") var manahoar_m := 6.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var manahoar_up_m := 1.5

## The "tower" view: the camera stands this far from the nearest tower, toward the local wizard, and this high.
@export_range(10.0, 80.0, 1.0, "suffix:m") var tower_m := 40.0
@export_range(0.0, 40.0, 0.5, "suffix:m") var tower_up_m := 14.0

## The "ground" view: the camera stands this high over --ground-at and looks at the ground this far ahead; a JSON with the 10 m
## cell borders in the picture is saved next to the PNG (tools/import/measure_seams.py reads both).
@export_range(1.0, 40.0, 0.5, "suffix:m") var ground_up_m := 8.0
@export_range(2.0, 60.0, 0.5, "suffix:m") var ground_ahead_m := 15.0
@export_range(5.0, 60.0, 1.0, "suffix:m") var ground_grid_reach_m := 30.0

## The "rim" view: the edge of the land closest to the wizard (the top of a wall under the rim), seen from this far back over the
## land and this high, looking this far down the wall: the wall, its cliff texture and the void under it (sky_underside) in frame.
@export_range(5.0, 120.0, 1.0, "suffix:m") var rim_m := 35.0
@export_range(0.0, 80.0, 1.0, "suffix:m") var rim_up_m := 30.0
@export_range(0.0, 50.0, 1.0, "suffix:m") var rim_look_down_m := 25.0

@export var camera: Camera3D

const GroundGrid := preload("res://agent/harness/match_shots/ground_grid.gd")
const HudLayout := preload("res://agent/harness/match_shots/hud_layout.gd")
## selection.gd has no class_name.
const SelectionScript := preload("res://scenes/orders/selection.gd")

var _shot_count := 0
## Where the last --cast aimed (the place of the foe it named): the "aim" view frames it, to see a mark or a fall there after the target is gone.
var _aim_at := Vector3.ZERO


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
	SacrificeFlow.set_pick(MatchWire.decode_pick({"wizard": arg("wizard", "cwa0"), "god": god}))
	## The land is the product's: the setup's biome (the capture wears the wizard's god unless --biome says otherwise).
	var chosen := MatchSetup.new()
	chosen.biome_god = StringName(arg("biome", god))
	SacrificeFlow.play_vs_ai(MatchWire.decode_god(arg("ai-god")), chosen)
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
	var every_s := maxf(float(arg("every", "5")), 0.02)
	var elapsed_s := maxf(float(arg("after", "10")), 0.0)
	await tree.create_timer(elapsed_s).timeout
	if not arg("cast").is_empty():
		await _cast_all(world, arg("cast").split(",", false))
		await tree.create_timer(maxf(float(arg("cast-wait", "1.5")), 0.0)).timeout
	var map_tag := String(MapCatalog.active().tag)
	for round in rounds:
		for view in views:
			await _shoot(world, view, "%s/%s_%s_%s_t%06d.png" % [out, map_tag, god, view, roundi(elapsed_s * 1000.0)])
		elapsed_s += every_s
		if round < rounds - 1:
			await tree.create_timer(every_s).timeout
	print("MATCH_SHOTS done: %d shots in %s (preset %s)" % [_shot_count, out, _preset(world)])
	tree.quit(0)


## --cast: each tag through the wizard's own Caster (cost, cooldown and casting time as in play), mana refilled before each one.
func _cast_all(world: MatchWorld, tags: PackedStringArray) -> void:
	var wizard := world.local_wizard() as WizardBody
	var caster := wizard.get_node("Caster") as Caster
	var known := []
	for i in caster.spellbook.size():
		known.append(caster.spellbook.spell_at(i).tag)
	print("match_shots: the book has %s" % [known])
	caster.feedback.connect(func(text: String) -> void: print("match_shots: the caster says «%s»" % text))
	for tag in tags:
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.current = pool.maximum
		var action := caster.action_for(tag)
		var foe := _closest_foe(wizard)
		var on_himself := action == null or action.pick == SpellAction.Pick.SELF or action is WardAction or _heals_own(action)
		var aimed := null if on_himself else foe
		if action != null and action.pick == SpellAction.Pick.SOUL:
			aimed = await _soul_for(world, wizard, action)
		var point := aimed.global_position if aimed != null else wizard.global_position
		if action is WallAction and foe != null:
			## A wall goes on the ground half way between the wizard and the enemy, across the line that joins them.
			point = (wizard.global_position + foe.global_position) * 0.5
			aimed = null
		_aim_at = point
		caster.request_cast(tag, point, aimed)
		print("match_shots: cast %s (casting: %s)" % [tag, caster.is_casting()])
		while caster.is_casting():
			await get_tree().physics_frame


## A spell that lands on the wizard's own side (Rainbow): the cast names nobody and the wizard himself is the first body of the chain.
func _heals_own(action: SpellAction) -> bool:
	var target: Variant = action.get("target")
	return target is SpellTarget and (target as SpellTarget).who == SpellTarget.Who.ALLY_OR_SELF


## --cast of a spell that aims at a soul (Soul Mole, Soul Wind, Animate Dead): the closest soul the wizard may fetch; when the match has
## none, one is made: a free soul 30 m ahead of him, or, for the spell that revives, a creature of his side that dies 20 m ahead.
func _soul_for(world: MatchWorld, wizard: WizardBody, action: SpellAction) -> Soul:
	var revives := action is AnimateDeadAction
	var best: Soul
	for node in get_tree().get_nodes_in_group(&"soul"):
		var soul := node as Soul
		if soul != null and soul.fetchable_by(wizard.owner_slot) and (not revives or soul.corpse != null) \
				and (best == null or soul.global_position.distance_to(wizard.global_position) < best.global_position.distance_to(wizard.global_position)):
			best = soul
	if best != null:
		return best
	var system := get_tree().get_first_node_in_group(&"soul_system") as SoulSystem
	var ahead := wizard.facing_flat()
	if not revives:
		var at := wizard.global_position + ahead * 30.0
		print("match_shots: no soul to fetch; a free one 30 m ahead")
		return system.spawn_soul({"x": at.x, "y": at.y, "z": at.z, "number": 1, "owner_slot": 0, "emerging": false}) as Soul
	var creature := (load("res://scenes/units/unit.tscn") as PackedScene).instantiate() as UnitBody
	creature.creature_tag = "nmuh"
	creature.owner_slot = wizard.owner_slot
	creature.target_groups = PackedStringArray()
	wizard.get_parent().add_child(creature)
	creature.global_position = wizard.global_position + ahead * 20.0
	await get_tree().create_timer(0.5).timeout
	(creature.get_node("Health") as Health).damage(99999.0, 0)
	for _frame in 600:
		await get_tree().physics_frame
		for node in get_tree().get_nodes_in_group(&"soul"):
			if (node as Soul).corpse == creature:
				print("match_shots: no dead creature of his; one fell 20 m ahead")
				return node as Soul
	return null


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
	if view == "hud":
		await _shoot_hud(world, file)
		return
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
		"halo":
			look = focus + Vector3.UP * halo_look_up_m
			spot = focus + _away_from_foe(world, wizard) * halo_m + Vector3.UP * halo_up_m
		"foe_close":
			var foe := _closest_foe(wizard)
			if foe == null:
				print("match_shots: no enemy; view skipped")
				return
			look = BodyNudge.center(foe)
			var from_foe := (focus - foe.global_position) * Vector3(1.0, 0.0, 1.0)
			spot = look + (from_foe.normalized() if from_foe.length() > 0.1 else Vector3.BACK) * foe_close_m + Vector3.UP * foe_close_up_m
		"scar":
			if not ScarMark.last_painted_at.is_finite():
				print("match_shots: no ground mark painted yet; view skipped")
				return
			look = ScarMark.last_painted_at
			var toward_scar := (focus - look) * Vector3(1.0, 0.0, 1.0)
			spot = look + (toward_scar.normalized() if toward_scar.length() > 0.1 else Vector3.BACK) * scar_m + Vector3.UP * scar_up_m
		"zone":
			var zone := get_tree().get_first_node_in_group(GroundZone.GROUP) as GroundZone
			if zone == null:
				print("match_shots: no ground zone alive; view skipped")
				return
			look = _over_land(zone.global_position + Vector3.UP * 1.0, 1.0)
			var toward_zone := (focus - zone.global_position) * Vector3(1.0, 0.0, 1.0)
			spot = _clear_spot(look, toward_zone.normalized() if toward_zone.length() > 0.1 else Vector3.BACK)
		"tornado", "tornado_far":
			var twister: GroundZone = null
			for node in get_tree().get_nodes_in_group(GroundZone.GROUP):
				var found := node as GroundZone
				if found != null and found.spell != null and found.spell.tag == "nrot":
					twister = found
			if twister == null:
				print("match_shots: no Tornado alive (--god=stratos --cast=nrot); view skipped")
				return
			var far := view == "tornado_far"
			look = twister.global_position + Vector3.UP * (tornado_far_look_up_m if far else tornado_look_up_m)
			var toward_twister := (focus - twister.global_position) * Vector3(1.0, 0.0, 1.0)
			spot = _clear_spot(look, toward_twister.normalized() if toward_twister.length() > 0.1 else Vector3.BACK, tornado_far_m if far else tornado_m, tornado_far_up_m if far else tornado_up_m)
		"rift":
			var rift: GroundZone = null
			for node in get_tree().get_nodes_in_group(GroundZone.GROUP):
				var candidate := node as GroundZone
				if candidate != null and candidate.spell != null and candidate.spell.tag == "tfir":
					rift = candidate
			if rift == null:
				print("match_shots: no Demonic Rift alive (--cast=tfir); view skipped")
				return
			look = rift.global_position + Vector3.UP * 1.5
			var toward_rift := (focus - rift.global_position) * Vector3(1.0, 0.0, 1.0)
			spot = _clear_spot(look, toward_rift.normalized() if toward_rift.length() > 0.1 else Vector3.BACK, rift_m, rift_up_m)
		"cloud":
			var cloud_zone := get_tree().get_first_node_in_group(GroundZone.GROUP) as GroundZone
			if cloud_zone == null:
				print("match_shots: no ground zone alive; view skipped")
				return
			var cloud_at := cloud_zone.get_node_or_null("CloudAt") as Node3D
			var toward_cloud := (focus - cloud_zone.global_position) * Vector3(1.0, 0.0, 1.0)
			var bearing := toward_cloud.normalized() if toward_cloud.length() > 0.1 else Vector3.BACK
			## A cloud and the land under it in one frame, from a bearing with a clear line to the ground; a zone with no cloud (Bombardment: its rocks
			## cross the sky) is seen from farther and higher than the other zones.
			var up_m := cloud_at.global_position.y - cloud_zone.global_position.y if cloud_at != null else 0.0
			look = cloud_zone.global_position + Vector3.UP * maxf(up_m * 0.5, 1.0)
			spot = _clear_spot(look, bearing, maxf(up_m * 1.9, cloud_min_m) if cloud_at != null else zone_m * 2.0, maxf(up_m * 0.35, zone_up_m) if cloud_at != null else zone_up_m * 1.5, cloud_zone.global_position + Vector3.UP * 3.0)
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
		"carrier":
			var carriers := world.find_children("*", "SpellCarrier", true, false)
			if carriers.is_empty():
				print("match_shots: no spell carrier on its way; view skipped")
				return
			var carrier := carriers[0] as Node3D
			var box := _drawn_box(carrier)
			look = box.get_center() if box.size.length() > 0.0 else carrier.global_position + Vector3.UP * 0.5
			var from_wizard := (carrier.global_position - focus) * Vector3(1.0, 0.0, 1.0)
			var back := maxf(carrier_m, 2.0 * maxf(box.size.x, maxf(box.size.y, box.size.z)))
			spot = look - (from_wizard.normalized() if from_wizard.length() > 0.1 else Vector3.FORWARD) * back + Vector3.UP * maxf(carrier_up_m, 0.4 * back)
		"aim":
			look = _aim_at + Vector3.UP * 1.0
			var toward_aim := (focus - _aim_at) * Vector3(1.0, 0.0, 1.0)
			spot = look + (toward_aim.normalized() if toward_aim.length() > 0.1 else Vector3.BACK) * aim_m + Vector3.UP * aim_up_m
		"wall":
			var walls := world.find_children("*", "SpellWall", true, false)
			if walls.is_empty():
				print("match_shots: no wall standing; view skipped")
				return
			var wall := walls[walls.size() - 1] as SpellWall
			look = wall.point_at(0.0) + Vector3.UP * 3.0
			var from_wizard := (focus - wall.center) * Vector3(1.0, 0.0, 1.0)
			spot = look + (from_wizard.normalized() if from_wizard.length() > 0.1 else Vector3.BACK) * wall_m + Vector3.UP * wall_up_m
			print("match_shots: wall %s age %d left %.1f right %.1f top %.2f armed %s inside %d" % [wall.name, wall.age, wall.left, wall.right, wall.top(), wall.armed, wall.bodies_inside().size()])
		"tower":
			var tower := _nearest_tower(focus)
			if tower == null:
				print("match_shots: no tower in the match; view skipped")
				return
			look = tower.global_transform.origin + Vector3.UP * 8.0
			var toward := (focus - tower.global_transform.origin) * Vector3(1.0, 0.0, 1.0)
			spot = look + (toward.normalized() if toward.length() > 0.1 else Vector3.BACK) * tower_m + Vector3.UP * tower_up_m
		"ground":
			var shape := TerrainShape.of(world)
			if shape == null:
				print("match_shots: no ground loaded; view skipped")
				return
			var at := _ground_at(focus)
			var ahead := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(arg("ground-yaw", "0")))) * ground_ahead_m
			spot = Vector3(at.x, shape.height_at(at.x, at.y) + ground_up_m, at.y)
			look = Vector3(at.x + ahead.x, shape.height_at(at.x + ahead.x, at.y + ahead.z), at.y + ahead.z)
		"rim":
			var rim := _nearest_rim(world, focus)
			if not rim.is_finite():
				print("match_shots: no wall under a rim in the ground; view skipped")
				return
			look = rim + Vector3.DOWN * rim_look_down_m
			var toward_land := (focus - rim) * Vector3(1.0, 0.0, 1.0)
			spot = rim + (toward_land.normalized() if toward_land.length() > 0.1 else Vector3.BACK) * rim_m + Vector3.UP * rim_up_m
			print("match_shots: rim at %.0f, %.0f, %.0f" % [rim.x, rim.y, rim.z])
		_:
			push_warning("match_shots: unknown view '%s'" % view)
			return
	camera.position = spot
	camera.look_at(look)
	camera.make_current()
	_report_wards(wizard)
	_report_afflictions(wizard)
	_report_zones()
	_report_scars()
	_report_halo()
	_report_bolts()
	_report_carriers(wizard)
	if arg("hover") == "wizard":
		_hover(world, wizard)
	await _save(file)
	if view == "ground":
		GroundGrid.write(camera, TerrainShape.of(world), _ground_at(focus), ground_grid_reach_m, ProjectSettings.globalize_path(file.get_basename() + ".json"))


## The "hud" view: the game's camera, the HUD as the player sees it (mana from --mana, creatures from --select, the order menu from --radial) and
## the measurements of HudLayout next to the PNG.
func _shoot_hud(world: MatchWorld, file: String) -> void:
	var wizard := world.local_wizard() as WizardBody
	var game_camera := world.get_node("Camera") as Camera3D
	game_camera.make_current()
	if not arg("mana").is_empty():
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.current = pool.maximum * clampf(float(arg("mana")), 0.0, 1.0)
	var wanted := int(arg("select", "0"))
	if wanted > 0:
		var mine: Array[Node3D] = []
		for node in get_tree().get_nodes_in_group(GROUP_UNIT):
			var unit := node as UnitBody
			if unit != null and unit.owner_slot == wizard.owner_slot and not unit.is_dead() and mine.size() < wanted:
				mine.append(unit)
		(world.get_node("Selection") as SelectionScript).select_only(mine)
		print("match_shots: %d creatures selected (asked %d)" % [mine.size(), wanted])
	var menu := world.find_child("RadialMenu", true, false) as RadialMenu
	if menu != null and OS.get_cmdline_user_args().has("--radial"):
		menu.open_at(world.get_viewport().get_visible_rect().size * 0.5)
		await get_tree().create_timer(0.4).timeout
	await _save(file)
	HudLayout.write(world, game_camera, ProjectSettings.globalize_path(file.get_basename() + ".json"))


## The top of the wall closest to `focus` in the map's ground mesh (a vertex marked as wall with UV.y 0), or INF without walls.
func _nearest_rim(world: MatchWorld, focus: Vector3) -> Vector3:
	var terrain := world.map.terrain if world.map != null else null
	if terrain == null or terrain.mesh == null:
		return Vector3.INF
	var arrays := terrain.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var best := Vector3.INF
	for i in points.size():
		if colors[i].a < 0.5 and i < uvs.size() and uvs[i].y < 0.5 and (not best.is_finite() or points[i].distance_squared_to(focus) < best.distance_squared_to(focus)):
			best = points[i]
	return best


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


## One line per rock of every Halo of Earth alive at each shot: is its body visible, where, how big and with what material, so a capture with
## no rocks says why (not born yet, buried, scaled to nothing, no material).
func _report_halo() -> void:
	for halo in get_tree().get_nodes_in_group(HaloOfEarth.GROUP):
		for rock: Node3D in (halo as HaloOfEarth).rock_nodes():
			var mesh := rock.get_node_or_null("Mesh") as MeshInstance3D
			var detail := "no mesh"
			if mesh != null and mesh.mesh != null:
				var material := mesh.mesh.surface_get_material(0)
				var size := mesh.mesh.get_aabb().size * mesh.scale
				detail = "mesh visible=%s scale %.2f size (%.2f, %.2f, %.2f) surfaces=%d material=%s" % [mesh.is_visible_in_tree(), mesh.scale.x, size.x, size.y, size.z,
					mesh.mesh.get_surface_count(), material.get_class() if material else "none"]
			print("match_shots: halo rock %s visible=%s at (%.1f, %.1f, %.1f) | %s" % [rock.name, rock.is_visible_in_tree(), rock.global_position.x, rock.global_position.y, rock.global_position.z, detail])


## One line per SpellCarrier alive at each shot (the level-8 spells, Dragonfire, the souls): its scene, motion, phase and place, and what the
## spell did to the closest enemy (its side, whether it rages, how swollen it is), so a capture with nothing in it says why.
func _report_carriers(wizard: Node3D) -> void:
	for node in get_tree().root.find_children("*", "SpellCarrier", true, false):
		var carrier := node as SpellCarrier
		print("match_shots: carrier %s motion=%d phase=%d at (%.1f, %.1f, %.1f)" % [carrier.name, carrier.motion, carrier.phase, carrier.global_position.x, carrier.global_position.y, carrier.global_position.z])
		for part in carrier.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := part as MeshInstance3D
			var material: Material = mesh_node.material_override if mesh_node.material_override != null else (mesh_node.get_surface_override_material(0) if mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0 else null)
			print("match_shots:   mesh %s visible=%s mesh=%s shapes=%d material=%s size (%.1f, %.1f, %.1f) at (%.1f, %.1f, %.1f)" % [mesh_node.name, mesh_node.is_visible_in_tree(),
				mesh_node.mesh.get_class() if mesh_node.mesh != null else "none", mesh_node.get_blend_shape_count(), material.get_class() if material != null else "none",
				mesh_node.get_aabb().size.x * mesh_node.global_basis.get_scale().x, mesh_node.get_aabb().size.y * mesh_node.global_basis.get_scale().y,
				mesh_node.get_aabb().size.z * mesh_node.global_basis.get_scale().z, mesh_node.global_position.x, mesh_node.global_position.y, mesh_node.global_position.z])
	var foe := _closest_foe(wizard)
	if foe != null and not get_tree().root.find_children("*", "SpellCarrier", true, false).is_empty():
		var afflictions := Afflictions.of(foe)
		var growth := DevourGrowth.of(foe)
		print("match_shots: foe %s side=%d raging=%s inflation=%.2f" % [foe.name, int(foe.get("owner_slot")), afflictions != null and afflictions.raging(), growth.inflation if growth != null else 0.0])


## The box (world) of what a carrier draws: its visible meshes of the first fifty, so a view can stand as far as its size asks (Death is 12 m tall).
static func _drawn_box(carrier: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part in carrier.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := part as MeshInstance3D
		if mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
			continue
		var world := mesh_node.global_transform * mesh_node.get_aabb()
		box = world if first else box.merge(world)
		first = false
	return box


## One line per beam FxBus has on screen at each shot (a bolt, an arc): its type, if it is drawn and where it starts and ends.
func _report_bolts() -> void:
	for node in get_tree().root.find_children("*", "BeamFx", true, false):
		var beam := node as BeamFx
		if beam.visible:
			print("match_shots: beam %s visible=%s drawn=%s" % [beam.name, beam.is_visible_in_tree(), beam.mesh != null and (beam.mesh as ImmediateMesh).get_surface_count() > 0])


## A camera point `zone_m` from `look` and `zone_up_m` above it: the bearing closest to `toward` (then every 45 degrees around) from which a ray
## to `look` meets nothing (an altar or a tower between them hides the zone). The point is never under the ground as it is now: a mound that
## rose over the zone (Volcano) lifts it to `up` above the land under it.
func _clear_spot(look: Vector3, toward: Vector3, distance := zone_m, up := zone_up_m, seen := Vector3.INF) -> Vector3:
	var space := camera.get_world_3d().direct_space_state
	var target := look + Vector3.UP * 3.0 if seen == Vector3.INF else seen
	var spot := _over_land(look + toward * distance + Vector3.UP * up, up)
	for step in 8:
		var bearing := toward.rotated(Vector3.UP, TAU * float(step + 1 >> 1) / 8.0 * (1.0 if step % 2 == 0 else -1.0))
		var candidate := _over_land(look + bearing * distance + Vector3.UP * up, up)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(candidate, target, 0xFFFFFFFF))
		if hit.is_empty():
			return candidate
	return spot


## `spot` raised to `margin` above the land (with its displacement) under it.
func _over_land(spot: Vector3, margin: float) -> Vector3:
	var shape := TerrainShape.of(self)
	var ground := shape.height_at(spot.x, spot.z) if shape != null else NAN
	if not is_nan(ground):
		spot.y = maxf(spot.y, ground + margin)
	return spot


## One line per ground zone alive at every shot: its phase and ticks, where it stands, how many points it has, and its drawn parts (visible,
## where, emitting), so a capture with nothing in it says why. Rift spirits are counted.
## The marks on the ground: what GroundScars holds and one line per request to paint it got (accepted, or refused and why).
func _report_scars() -> void:
	var scars := get_tree().get_first_node_in_group(GroundScars.GROUP) as GroundScars
	print("match_shots: GroundScars %s" % (("active=%s painted=%d of %d, globals index=%s tiles=%s" % [scars.is_active(), scars.painted_tiles(), scars.capacity(),
			RenderingServer.global_shader_parameter_get(GroundScars.INDEX_PARAM), RenderingServer.global_shader_parameter_get(GroundScars.TILES_PARAM)]) if scars != null else "missing from the match"))
	for line in GroundScars.log_lines:
		print("match_shots: scar %s" % line)


func _report_zones() -> void:
	for node in get_tree().get_nodes_in_group(GroundZone.GROUP):
		var zone := node as GroundZone
		var parts := PackedStringArray()
		for part in zone.find_children("*", "Node3D", true, false):
			if part is GeometryInstance3D or part is CPUParticles3D:
				var emitting := " emitting=%s" % (part as CPUParticles3D).emitting if part is CPUParticles3D else ""
				parts.append("%s visible=%s%s" % [part.name, (part as Node3D).is_visible_in_tree(), emitting])
		print("match_shots: zone %s phase %s (%d ticks) cancelled=%s at (%.1f, %.1f, %.1f) points=%d spirits=%d drops=%d | %s" % [zone.name, GroundZone.Phase.keys()[zone.phase], zone.phase_ticks,
			zone.cancelled, zone.global_position.x, zone.global_position.y, zone.global_position.z, zone.points.size(), get_tree().get_nodes_in_group(RiftSpirit.GROUP).size(), get_tree().get_nodes_in_group(ZoneDrop.GROUP).size(), " | ".join(parts)])
		_report_stalks_and_tornado(zone)


## Meanstalks and Tornado (061j): one line per stalk (mode, how much is out, where its tip is) or the tornado's size, so a capture with no
## stalk in it says if they had not grown or were holding someone.
func _report_stalks_and_tornado(zone: GroundZone) -> void:
	for node in zone.find_children("*", "Stalk", true, false):
		var stalk := node as Stalk
		print("match_shots: stalk %s %s growth %.2f root (%.1f, %.1f, %.1f) tip (%.1f, %.1f, %.1f) holds=%s" % [stalk.name, Stalk.Mode.keys()[stalk.mode], stalk.growth,
			stalk.global_position.x, stalk.global_position.y, stalk.global_position.z, stalk.tip.x, stalk.tip.y, stalk.tip.z, stalk.grip.held() != null])
	var drift := zone.get_node_or_null("Drift") as TornadoDrift
	if drift != null:
		print("match_shots: tornado size %.2f speed %.2f m/s at (%.1f, %.1f, %.1f)" % [drift.size, drift.velocity.length(), zone.global_position.x, zone.global_position.y, zone.global_position.z])


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


## --ground-at=x,z (world metres), or the local wizard's x, z.
func _ground_at(focus: Vector3) -> Vector2:
	var parts := arg("ground-at").split(",", false)
	return Vector2(float(parts[0]), float(parts[1])) if parts.size() == 2 else Vector2(focus.x, focus.z)


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
