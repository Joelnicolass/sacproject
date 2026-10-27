@tool
class_name BloodFx
extends Node

## A body bleeds when it loses health: a red spray from its center and a mark of blood on the ground at its feet. Every drop of
## `Health.current` counts (a blow, a shot, a spell, a wall, poison, a fall). A blow always bleeds; drops close together (poison)
## bleed now and then (BloodRules). The blood is the `blood` of the look the body wears (BodyMount.look) or `fallback` (red).
## One owner: the server decides each wound (in match seconds) and writes `wound`, replicated to every peer; every peer paints the
## wound it has not shown yet, its marks drawn from the match seed around the server's feet, so all of them see the same blood.
## Presentation only: it never writes the simulation and sends no RPC. Headless (the dedicated server) it decides but draws nothing;
## it is quiet with «Sangre» off (FeelPrefs.blood) and while the body is hidden (a gib throws its own blood).
## What it does not do: bleed buildings, choose the spray's look (BloodType, ParticleType) or own the marks (GroundScars).

signal bled(at: Vector3, heavy: bool)

## The body that bleeds: its CENTER socket is where the spray leaves, its FEET where the marks land, its visibility says if it shows.
@export var body: Node3D:
	set(value):
		body = value
		update_configuration_warnings()
@export var health: Health:
	set(value):
		health = value
		update_configuration_warnings()
## The body's BodyMount: the look it wears may bring its own `blood`.
@export var mount: BodyMount:
	set(value):
		mount = value
		update_configuration_warnings()
## The blood of a look that brings none.
@export var fallback: BloodType:
	set(value):
		fallback = value
		update_configuration_warnings()
## The player's «Sangre» (data/ui/feel_prefs.tres): off, nothing shows.
@export var prefs: FeelPrefs:
	set(value):
		prefs = value
		update_configuration_warnings()
## The last wound the server decided (BloodRules.wound_of: the feet where it landed, its index and whether it was heavy). The body's
## MultiplayerSynchronizer replicates it (spawn, on change); each new index is painted once, and the one a peer gets on spawn (a
## rejoin) counts as already shown.
@export var wound := Vector4.ZERO:
	set(value):
		wound = value
		if is_node_ready() and not Engine.is_editor_hint():
			_show(value)

## How many sprays and painted marks this body made on this peer (the inspector's Remote tab and the checks read them).
var sprays := 0
var marks := 0

var _active := false
var _shown := 0
var _last := 0.0
var _lost := 0.0
var _last_spray_s := -INF
var _last_drop_s := -INF


func _ready() -> void:
	if Engine.is_editor_hint() or body == null or health == null:
		return
	_active = BodyLook.loads_meshes()
	_shown = BloodRules.index_of(wound)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_last = health.current
		health.changed.connect(_on_health_changed)


## False headless, or with «Sangre» off.
func is_active() -> bool:
	return _active and (prefs == null or prefs.blood())


## The blood this body shows now: its look's, or `fallback`.
func blood_type() -> BloodType:
	var look: BodyLook = mount.look if mount != null else null
	return look.blood if look != null and look.blood != null else fallback


## The server only: whether this drop is a wound, and which.
func _on_health_changed(current: float, maximum: float) -> void:
	var drop := _last - current
	_last = current
	if drop <= 0.0 or maximum <= 0.0:
		return
	var now := float(MatchClock.now()) / MatchClock.TICKS_PER_SECOND_F
	var since_drop := now - _last_drop_s
	_last_drop_s = now
	_lost += drop / maximum
	var kind := BloodRules.kind_for(drop / maximum, _lost, now - _last_spray_s, since_drop, blood_type())
	if kind == BloodRules.Kind.NONE:
		return
	_lost = 0.0
	_last_spray_s = now
	var feet := BodyFacts.point(body, BodyFacts.Socket.FEET)
	wound = BloodRules.wound_of(feet, BloodRules.index_of(wound) + 1, kind == BloodRules.Kind.HEAVY)


## Every peer: paints `value` if it is a wound this peer has not shown.
func _show(value: Vector4) -> void:
	var index := BloodRules.index_of(value)
	if index <= _shown:
		return
	_shown = index
	if not is_active() or body == null or not body.is_visible_in_tree():
		return
	var type := blood_type()
	if type == null or not type.bleeds():
		return
	var heavy := BloodRules.is_heavy(value)
	var center := BodyFacts.point(body, BodyFacts.Socket.CENTER)
	var spray := type.spray_for(heavy)
	if spray != null:
		FxBus.play(spray, center)
	sprays += 1
	var scars := GroundScars.of(self)
	if scars != null and type.mark != null:
		var rng := MatchSeed.rng(["blood", String(body.name), index])
		var feet := Vector3(value.x, value.y, value.z)
		for point in BloodRules.mark_points(feet, type.marks_for(heavy), type.mark_radius_m, rng):
			if scars.stamp(type.mark, point, type.mark_max_height_m):
				marks += 1
	bled.emit(center, heavy)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if body == null:
		out.append("Asigná `body` (el cuerpo que sangra).")
	if health == null:
		out.append("Asigná `health` (su Health).")
	if mount == null:
		out.append("Asigná `mount` (su BodyMount: el look puede traer su sangre).")
	if fallback == null:
		out.append("Asigná `fallback` (data/fx/blood/red.tres).")
	var prefs_warning := FeelPrefs.socket_warning(prefs)
	if not prefs_warning.is_empty():
		out.append(prefs_warning)
	return out
