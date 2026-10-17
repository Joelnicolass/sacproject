class_name Vined
extends Affliction

## F159 (RFC-030 030u-c): the Dragon's Grasping Vines (eniv, passiveOnHit of grdg), sacengine graspingVines (state.d:10795-10812) and
## updateGraspingVines (17852-17876). The blow ties the body to the ground: while it lasts the body is `fixed` (cannot walk nor be moved
## from outside), does not regenerate and is ccProtected (stats.d:73-94: vined → regenerationBlocked, ccProtected, fixed). The type
## (`vined.tres`: bit 8, coexists, holds = false, cc_protects, pins, blocks_regeneration) says all of that; this node owns the clock.
##
## Each blow brings its own timer (numVines += 1, one GraspingVines effect with its own `timer`): `_ends` holds the tick every one
## runs out on, and the bit is on while any is left. The duration of one is (wizard ? 0.25 : 1000 / max health) · the SPEL's 40 s in
## float32 (Affliction.cc_ticks): a Jabberocky of 5600 hp is 429 ticks. A flier is never tied (isHitboxFlying, 10799), and a body that is
## dead or dying loses every vine at once (canPersistCC: Afflictions ends the bit when it dies).
## The body's xz velocity is 0 in steer(); the xy position of sacengine is the port's xz (the vertical follows the land by itself).
##
## Look (reserve, every peer, from the replicated bit): 16 green vines that spiral up the body, grown in a second (lengthFactor
## +1/60 per tick from 0.1) and shrunk in a second when it ends (-1/60). Opaque MIX material, nothing additive. The shapes come from a
## presentation stream of their own (MatchSeed.seed_rng), so they never move the simulation's. Declared: the vines are not
## sacengine's `vine` meshes (no model), and one set serves every blow (a second blow only extends the time).

## Bench log (`ai_match` turns it on; off in the product).
static var log_vines := false


## Vine lifetime of a creature: creature_k / max health · the SPEL's duration (s); of a wizard: wizard_factor · duration.
@export var creature_k := 1000.0
@export var wizard_factor := 0.25
## The body's BodyVisual: its body_height() and body_radius() size the vines.
@export var visual: BodyVisual
@export_group("Look")
## sacengine GraspingVines.vines (16).
@export var vine_count := 16
@export var vine_color := Color(0.16, 0.36, 0.1)
## Segments along a vine and sides of its tube.
@export var vine_segments := 14
@export var vine_sides := 5
## Thickness of a vine's tube (m) at its root.
@export var vine_thickness := 0.09
## Seconds a vine takes to grow and to vanish (sacengine growthTime / vanishTime = updateFPS ticks).
@export var grow_seconds := 1.0

## Server: the tick each blow's vines run out on.
var _ends: PackedInt32Array = PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _vines: Node3D
## Presentation: how grown the vines are (sacengine lengthFactor, 0.1 → 1) and whether they are shrinking.
var _length := 0.1
var _shrinking := false


func _ready() -> void:
	set_physics_process(false)
	set_process(false)


## The Vined state under `node` is on (a body that is not a creature or has none: false).
static func is_vined(node: Node) -> bool:
	var vined := node.get_node_or_null("Afflictions/Vined") as Vined if node else null
	return vined != null and vined.is_on()


## F158: the on-hit passive. Every blow that connects ties the body, whatever its damage roll gave.
func inflict(spell: SpellType, _from_slot: int) -> bool:
	return grasp(spell)


## Server (or solo): sacengine graspingVines(target, spell). True when the vines took hold (a flier refuses them).
func grasp(spell: SpellType) -> bool:
	var body := _body()
	var owner_node := _afflictions()
	if body == null or spell == null or not _simulates() or BodyNudge.airborne(body):
		return false
	if owner_node.health != null and owner_node.health.is_dead():
		return false
	var ticks := cc_ticks(body.is_in_group(&"wizard"), owner_node.health.maximum if owner_node.health else 0.0, spell.duration,
		creature_k, wizard_factor)
	if ticks <= 0 or not owner_node.admit(self):
		return false
	var now := MatchClock.now()
	_ends.append(now + ticks)
	owner_node.mark(self, true)
	set_physics_process(true)
	if log_vines:
		print("enredado %s durante %d (n %d) (cuadro %d)" % [str(body.name), ticks, _ends.size(), now])
	return true


## Server, every tick while it is on: the body does not walk.
func steer(velocity: Vector3, _delta: float) -> Vector3:
	velocity.x = 0.0
	velocity.z = 0.0
	return velocity


## updateGraspingVines: `--timer <= 0` ends one blow's vines; the bit goes when the last one does.
func _physics_process(_delta: float) -> void:
	var now := MatchClock.now()
	var left := PackedInt32Array()
	for end in _ends:
		if end > now:
			left.append(end)
	if left.size() == _ends.size():
		return
	_ends = left
	if _ends.is_empty():
		_afflictions().mark(self, false)
		set_physics_process(false)
	_say_end()


func _say_end() -> void:
	if log_vines:
		print("enredado fin %s (n %d) (cuadro %d)" % [str(_body().name), _ends.size(), MatchClock.now()])


## Every peer, when the bit changes. On the server a bit turned off from outside (the body died) clears the clocks.
func _shown(on: bool) -> void:
	if not on and _simulates() and not _ends.is_empty():
		_ends = PackedInt32Array()
		set_physics_process(false)
		_say_end()
	if on:
		_grow()
	else:
		_shrinking = true
		set_process(_vines != null)


func _grow() -> void:
	_shrinking = false
	if _vines == null:
		_vines = _build_vines()
		if _vines == null:
			return
		_length = 0.1
		_vines.scale = Vector3(1.0, _length, 1.0)
	set_process(true)


func _process(delta: float) -> void:
	if _vines == null:
		set_process(false)
		return
	var step := delta / maxf(0.001, grow_seconds)
	_length = clampf(_length + (-step if _shrinking else step), 0.0, 1.0)
	_vines.scale = Vector3(1.0, maxf(_length, 0.001), 1.0)
	if _shrinking and _length <= 0.0:
		_vines.queue_free()
		_vines = null
		set_process(false)
	elif not _shrinking and _length >= 1.0:
		set_process(false)


## One child of the body with `vine_count` spiral tubes, rooted at its feet.
func _build_vines() -> Node3D:
	var body := _body()
	if body == null or not body.is_inside_tree():
		return null
	MatchSeed.seed_rng(_rng, ["vines_look", String(body.name)])
	var height := visual.body_height() if visual else 2.0
	var radius := maxf(0.4, visual.body_radius() * 0.9) if visual else 0.8
	var root := Node3D.new()
	root.name = "VinesLook"
	var material := StandardMaterial3D.new()
	material.albedo_color = vine_color
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in vine_count:
		var mesh := MeshInstance3D.new()
		mesh.mesh = _tube(height * _rng.randf_range(0.55, 1.0), radius * _rng.randf_range(0.8, 1.15), _rng.randf_range(0.8, 1.8),
			TAU * float(i) / float(vine_count) + _rng.randf_range(-0.2, 0.2), -1.0 if _rng.randf() < 0.5 else 1.0)
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	body.add_child(root)
	return root


## A vine: a tube that spirals up `height` metres around the axis at `radius`, `turns` turns, starting at angle `start`.
func _tube(height: float, radius: float, turns: float, start: float, direction: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for s in vine_segments + 1:
		var t := float(s) / float(vine_segments)
		var angle := start + direction * turns * TAU * t
		var at := Vector3(cos(angle) * radius * (1.0 + 0.12 * sin(t * 9.0)), t * height, sin(angle) * radius * (1.0 + 0.12 * sin(t * 9.0)))
		var tangent := Vector3(-sin(angle) * direction * turns * TAU * radius, height, cos(angle) * direction * turns * TAU * radius).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var up := side.cross(tangent).normalized()
		var thick := vine_thickness * (1.0 - 0.7 * t)
		var ring := PackedVector3Array()
		for k in vine_sides:
			var a := TAU * float(k) / float(vine_sides)
			ring.append(at + (side * cos(a) + up * sin(a)) * thick)
		rings.append(ring)
	for s in vine_segments:
		for k in vine_sides:
			var k2 := (k + 1) % vine_sides
			surface.add_vertex(rings[s][k])
			surface.add_vertex(rings[s + 1][k])
			surface.add_vertex(rings[s][k2])
			surface.add_vertex(rings[s][k2])
			surface.add_vertex(rings[s + 1][k])
			surface.add_vertex(rings[s + 1][k2])
	surface.generate_normals()
	return surface.commit()
