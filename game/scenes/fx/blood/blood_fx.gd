@tool
class_name BloodFx
extends Node

## A body bleeds when it loses health: a red spray from its center and a mark of blood on the ground at its feet. Every drop of
## `Health.current` counts (a blow, a shot, a spell, a wall, poison, a fall), on every peer, because `current` is replicated. A
## blow always bleeds; drops close together (poison) bleed now and then (BloodRules). The blood is the `blood` of the look the body
## wears (BodyMount.look) or `fallback` (red).
## Presentation only: it never writes the simulation, sends nothing and draws nothing headless (the dedicated server). It is quiet
## with «Sangre» off (FeelPrefs.blood), while the body is hidden (a gib throws its own blood) and, on a networked client, during its first `quiet_s` (the first value
## that reaches a peer that joins late is not a hit).
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
## Seconds after entering the tree in which a networked client does not bleed.
@export_range(0.0, 5.0, 0.05, "suffix:s") var quiet_s := 0.5

## How many sprays and painted marks this body made (the inspector's Remote tab and the checks read them).
var sprays := 0
var marks := 0

var _active := false
var _last := 0.0
var _lost := 0.0
var _born_s := 0.0
var _last_spray_s := -INF
var _last_drop_s := -INF
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint() or body == null or health == null:
		return
	_active = BodyLook.loads_meshes()
	if not _active:
		return
	_rng.seed = get_instance_id()
	_last = health.current
	_born_s = _now()
	health.changed.connect(_on_health_changed)


## False headless, or with «Sangre» off.
func is_active() -> bool:
	return _active and (prefs == null or prefs.blood())


## The blood this body shows now: its look's, or `fallback`.
func blood_type() -> BloodType:
	var look := mount.look if mount != null else null
	return look.blood if look != null and look.blood != null else fallback


func _on_health_changed(current: float, maximum: float) -> void:
	var drop := _last - current
	_last = current
	if drop <= 0.0 or maximum <= 0.0:
		return
	var now := _now()
	var since_drop := now - _last_drop_s
	_last_drop_s = now
	if not is_active() or not body.is_visible_in_tree() or _quiet(now):
		return
	_lost += drop / maximum
	var type := blood_type()
	var kind := BloodRules.kind_for(drop / maximum, _lost, now - _last_spray_s, since_drop, type)
	if kind == BloodRules.Kind.NONE:
		return
	_lost = 0.0
	_last_spray_s = now
	_bleed(type, kind == BloodRules.Kind.HEAVY)


func _bleed(type: BloodType, heavy: bool) -> void:
	var center := BodyFacts.point(body, BodyFacts.Socket.CENTER)
	var spray := type.spray_for(heavy)
	if spray != null:
		FxBus.play(spray, center)
	sprays += 1
	var scars := GroundScars.of(self)
	if scars != null and type.mark != null:
		var feet := BodyFacts.point(body, BodyFacts.Socket.FEET)
		for point in BloodRules.mark_points(feet, type.marks_for(heavy), type.mark_radius_m, _rng):
			if scars.stamp(type.mark, point, type.mark_max_height_m):
				marks += 1
	bled.emit(center, heavy)


func _quiet(now: float) -> bool:
	var remote := multiplayer.has_multiplayer_peer() and not multiplayer.is_server()
	return remote and now - _born_s < quiet_s


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


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
