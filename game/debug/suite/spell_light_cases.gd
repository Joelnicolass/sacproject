extends RefCounted

## Light pass of RFC-061: every spell of the wizard lights the ground around its effect with its own colour. The cases walk the table below
## (spell tag -> the scenes and resources that carry its light) and check each light: a colour that is not white, an energy above 0,
## a moderate reach, no shadow, and that the thing which switches it on is wired (a ward's `shown_changed`, a zone, a state's type).
## It also checks the places a light must NOT be left (a wizard's reveal light is not a spell's). Nothing here is drawn: the scenes are
## instantiated without entering the tree, so a headless run (where lights free themselves) still sees them. `run(host)` is synchronous.

const SCENE := "scene"
const PARTICLE := "particle"
const BEAM := "beam"
const AFFLICTION := "affliction"

## spell tag -> [kind, path]. A spell may have several (the cast, the lasting glow, the burst).
const SPELLS := {
	"htlm": [[SCENE, "res://scenes/map/props/manafount.tscn"]],
	"pcas": [[SCENE, "res://scenes/map/props/manafount.tscn"]],
	"pups": [[PARTICLE, "res://data/fx/speedup.tres"]],
	"ndrg": [[SCENE, "res://scenes/spells/guardian/guardian_tether.tscn"]],
	"ccas": [[SCENE, "res://scenes/sacrifice/red_vortex.tscn"]],
	"ucas": [[SCENE, "res://scenes/sacrifice/red_vortex.tscn"]],
	"elet": [[PARTICLE, "res://data/fx/teleport_in.tres"], [PARTICLE, "res://data/fx/teleport_out.tres"]],
	"laeh": [[PARTICLE, "res://data/fx/heal.tres"]],
	"oalf": [[SCENE, "res://scenes/spells/wrath_strike.tscn"], [PARTICLE, "res://data/fx/wrath_explosion1.tres"]],
	"brif": [[SCENE, "res://scenes/spells/fireball_projectile.tscn"]],
	"ntil": [[BEAM, "res://data/fx/beams/lightning.tres"]],
	"kcor": [[SCENE, "res://scenes/spells/rock_projectile.tscn"], [PARTICLE, "res://data/fx/rock.tres"]],
	"mrws": [[SCENE, "res://scenes/spells/swarm_projectile.tscn"]],
	"niks": [[SCENE, "res://scenes/spells/wards/skin_of_stone.tscn"]],
	"dlhs": [[SCENE, "res://scenes/spells/wards/air_shield.tscn"]],
	"mrfe": [[SCENE, "res://scenes/spells/wards/ethereal_form.tscn"]],
	"mrff": [[SCENE, "res://scenes/spells/wards/fireform.tscn"]],
	"rwsp": [[SCENE, "res://scenes/spells/wards/protective_swarm.tscn"]],
	"ruah": [[SCENE, "res://scenes/spells/wards/healing_aura.tscn"]],
	"zerf": [[AFFLICTION, "res://data/afflictions/frozen.tres"]],
	"eniv": [[AFFLICTION, "res://data/afflictions/vined.tres"]],
	"rapf": [[AFFLICTION, "res://data/afflictions/rings_of_fire.tres"]],
	"htel": [[AFFLICTION, "res://data/afflictions/slimed.tres"], [SCENE, "res://scenes/spells/slime_ball.tscn"]],
	"pmcd": [[SCENE, "res://scenes/spells/carrier/soul_mole.tscn"]],
	"dnws": [[SCENE, "res://scenes/spells/carrier/soul_wind.tscn"]],
	"deda": [[SCENE, "res://scenes/spells/animate_dead/animate_dead_fx.tscn"], [PARTICLE, "res://data/fx/animate_dead_burst.tres"]],
	"pxef": [[SCENE, "res://scenes/spells/zones/explosion_zone.tscn"], [PARTICLE, "res://data/fx/explosion_blast.tres"]],
	"zorf": [[SCENE, "res://scenes/spells/zones/frozen_ground.tscn"], [PARTICLE, "res://data/fx/snowball_burst.tres"], [PARTICLE, "res://data/fx/ice_shard.tres"]],
	"tfir": [[SCENE, "res://scenes/spells/zones/demonic_rift.tscn"], [SCENE, "res://scenes/spells/zones/rift_spirit.tscn"]],
	"rter": [[SCENE, "res://scenes/spells/stalks/stalk.tscn"], [PARTICLE, "res://data/fx/stalk_grab.tres"]],
	"nrot": [[SCENE, "res://scenes/spells/tornado/tornado.tscn"]],
}
const WIZARD_SCENE := "res://scenes/wizards/wizard_body.tscn"
const UNIT_SCENE := "res://scenes/units/unit.tscn"
## A light that reads on the ground without burning it.
const MAX_ENERGY := 3.0
const MAX_FX_ENERGY := 16.0
const MIN_RANGE_M := 3.0
const MAX_RANGE_M := 40.0
## (max - min) / max of the colour: below this it counts as white.
const MIN_SATURATION := 0.1


func run(_host: Node3D) -> Dictionary:
	var out := {}
	out["spell_lights_present"] = _spells_have_light()
	out["spell_lights_wired_wards"] = _wards_wired()
	out["spell_lights_wired_afflictions"] = _afflictions_wired()
	out["spell_lights_state_window"] = _state_window()
	return out


## Every spell of the table has at least one light and each one is valid.
func _spells_have_light() -> Dictionary:
	var problems: Array[String] = []
	for tag in SPELLS:
		var found := 0
		for source in SPELLS[tag]:
			var lights := _lights_of(source[0], source[1], problems, tag)
			found += lights
		if found == 0:
			problems.append("%s: no light" % tag)
	return {"ok": problems.is_empty(), "problems": problems, "spells": SPELLS.size()}


## Number of lights found in one source (problems are appended).
func _lights_of(kind: String, path: String, problems: Array[String], tag: String) -> int:
	match kind:
		SCENE:
			var scene := load(path) as PackedScene
			if scene == null:
				problems.append("%s: %s does not load" % [tag, path])
				return 0
			var root := scene.instantiate()
			var count := 0
			for node in _actor_lights(root):
				count += 1
				_check_actor_light(node, tag, path, problems)
			root.free()
			return count
		PARTICLE:
			var type := load(path) as ParticleType
			if type == null or type.light == null:
				problems.append("%s: %s has no light" % [tag, path])
				return 0
			_check_spec(type.light, tag, path, problems)
			return 1
		BEAM:
			var beam := load(path) as BeamType
			if beam == null or beam.light == null:
				problems.append("%s: %s has no light" % [tag, path])
				return 0
			_check_spec(beam.light, tag, path, problems)
			return 1
		AFFLICTION:
			var type := load(path) as AfflictionType
			if type == null or type.glow == null:
				problems.append("%s: %s has no glow" % [tag, path])
				return 0
			var root := type.glow.instantiate()
			var lights := _actor_lights(root)
			for node in lights:
				_check_actor_light(node, tag, path, problems)
			root.free()
			return lights.size()
	return 0


func _actor_lights(root: Node) -> Array[ActorLight]:
	var out: Array[ActorLight] = []
	if root is ActorLight:
		out.append(root as ActorLight)
	for node in root.find_children("*", "ActorLight", true, false):
		out.append(node as ActorLight)
	return out


func _check_actor_light(light: ActorLight, tag: String, path: String, problems: Array[String]) -> void:
	var who := "%s: %s/%s" % [tag, path.get_file(), light.name]
	if light.always_on:
		problems.append(who + " is always_on (the budget must be able to turn it off)")
	if light.shadow_enabled:
		problems.append(who + " casts shadows")
	if light.light_energy <= 0.0 or light.light_energy > MAX_ENERGY:
		problems.append("%s energy %.2f outside (0, %.1f]" % [who, light.light_energy, MAX_ENERGY])
	if light.omni_range < MIN_RANGE_M or light.omni_range > MAX_RANGE_M:
		problems.append("%s range %.1f outside [%.0f, %.0f]" % [who, light.omni_range, MIN_RANGE_M, MAX_RANGE_M])
	if not _is_tinted(light.light_color):
		problems.append("%s colour is white" % who)


func _check_spec(spec: FxLightSpec, tag: String, path: String, problems: Array[String]) -> void:
	var who := "%s: %s" % [tag, path.get_file()]
	if spec.energy <= 0.0 or spec.energy > MAX_FX_ENERGY:
		problems.append("%s energy %.2f outside (0, %.0f]" % [who, spec.energy, MAX_FX_ENERGY])
	if spec.range_m < MIN_RANGE_M or spec.range_m > MAX_RANGE_M:
		problems.append("%s range %.1f outside [%.0f, %.0f]" % [who, spec.range_m, MIN_RANGE_M, MAX_RANGE_M])
	if not _is_tinted(spec.color):
		problems.append("%s colour is white" % who)


static func _is_tinted(color: Color) -> bool:
	var top := maxf(color.r, maxf(color.g, color.b))
	var low := minf(color.r, minf(color.g, color.b))
	return top > 0.0 and (top - low) / top >= MIN_SATURATION


## Every ward of the wizard's body switches its light on and off with `shown_changed`.
func _wards_wired() -> Dictionary:
	var problems: Array[String] = []
	var body := (load(WIZARD_SCENE) as PackedScene).instantiate()
	var wards := Wards.of(body)
	var seen := 0
	for child in wards.get_children():
		var ward := child as Ward
		if ward == null or ward.spell == null:
			continue
		var light: StateLight = null
		for node in ward.get_children():
			if node is StateLight:
				light = node
		if light == null:
			problems.append("%s: no StateLight" % ward.name)
		elif not ward.shown_changed.is_connected(light.show_lit):
			problems.append("%s: its light is not connected to shown_changed" % ward.name)
		else:
			seen += 1
	body.free()
	return {"ok": problems.is_empty() and seen >= 6, "problems": problems, "wards": seen}


## The states Freeze, Grasping Vines, Rings of Fire and Slime have a glow in their type, on a unit and on a wizard.
func _afflictions_wired() -> Dictionary:
	var problems: Array[String] = []
	var glowing := 0
	for path in [UNIT_SCENE, WIZARD_SCENE]:
		var body := (load(path) as PackedScene).instantiate()
		var afflictions := Afflictions.of(body)
		var ids: Array[StringName] = []
		for child in afflictions.get_children():
			var state := child as Affliction
			if state != null and state.type != null and state.type.glow != null:
				ids.append(state.type.id)
				if not (state.type.glow.instantiate() is StateLight):
					problems.append("%s: the glow of %s is not a StateLight" % [path.get_file(), state.type.id])
		for id in [&"frozen", &"vined", &"rings_of_fire", &"slimed"]:
			if not ids.has(id):
				problems.append("%s: %s has no glow" % [path.get_file(), id])
			else:
				glowing += 1
		body.free()
	return {"ok": problems.is_empty() and glowing == 8, "problems": problems, "glowing": glowing}


## The phase window of a zone light is inclusive on both ends.
func _state_window() -> Dictionary:
	var light := StateLight.new()
	light.from_phase = GroundZone.Phase.CASTING
	light.to_phase = GroundZone.Phase.ARMING
	var inside := light.in_window(GroundZone.Phase.CASTING) and light.in_window(GroundZone.Phase.ARMING)
	var outside := not light.in_window(GroundZone.Phase.ACTIVE) and not light.in_window(GroundZone.Phase.ENDING)
	light.free()
	return {"ok": inside and outside}
