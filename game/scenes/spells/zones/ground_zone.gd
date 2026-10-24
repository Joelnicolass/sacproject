class_name GroundZone
extends SpellProjectile

## A place on the ground with a clock: it goes through CASTING (the wizard is still casting it), ARMING (the cast ended, it waits), ACTIVE
## (it acts, for the spell's duration or until it is told it is done) and ENDING (it goes away), and its children do what their phase asks:
## pulses hurt or freeze the bodies near it, the look draws the balls, the ice or the rift. It does not know what the spell does to a body
## (ZonePulse and its classes do) nor how to draw (the scene does). The server (or solo) runs the clock and replicates `phase`; every peer
## counts the ticks of the phase so its look can follow.
## Ref: sacengine ExplosionCasting, FrozenGround, DemonicRift (state.d:3405-3425, 3547-3655).

## The zone entered phase `phase` (every peer, from the replicated `phase`).
signal phase_changed(phase: int)

enum Phase { CASTING, ARMING, ACTIVE, ENDING }

const GROUP := &"ground_zone"

## The spell whose numbers the zone uses: damage, ranges, duration.
@export var spell: SpellType
@export_group("Timeline")
## After the cast ends, seconds before it acts, unless the action says its own (`arm_ticks` in the spawn data).
@export_range(0.0, 10.0, 0.01, "suffix:s") var arm_s := 0.0
## How long it acts. Ignored when it lasts the spell's duration or until `finish()`.
@export_range(0.0, 120.0, 0.1, "suffix:s") var hold_s := 0.0
@export var hold_is_spell_duration := false
## It acts until something calls `finish()` (a rift ends when its last spirit is gone).
@export var open_ended := false
## The zone itself moves (a cloud that follows its target, a tornado): its position is replicated.
@export var replicates_position := false
## Properties of its children the server replicates with the zone, as paths from the zone (`Stalk1:tip`).
@export var synced := PackedStringArray()
## It takes this long to go away, and frees itself after.
@export_range(0.0, 10.0, 0.01, "suffix:s") var end_s := 0.5
## Its reach grows to the full radius in this time after it started acting (0 = at once).
@export_range(0.0, 10.0, 0.01, "suffix:s") var grow_s := 0.0

## Where it acts. The first is its anchor; Explosion has five.
var points := PackedVector3Array()
## The side that cast it and the wizard that did.
var from_slot := 0
var caster_path := NodePath()
## Where the wizard clicked (a rift's spirits look around it).
var aim_point := Vector3.ZERO
## The body the wizard clicked, when the spell follows it (a cloud that chases its target); empty = the ground.
var follow_path := NodePath()
## Ticks the cast lasts (the balls grow in that time), and the wait after it.
var cast_ticks := 0
var arm_ticks := 0
## Ticks counted in the current phase, on every peer. The ENDING of a zone ended by `cancel()` has `cancelled` set.
var phase_ticks := 0
## Replicated. The server writes it; every peer draws from it.
var phase := Phase.CASTING:
	set(value):
		if value == phase:
			return
		phase = value
		phase_ticks = 0
		phase_changed.emit(phase)
var cancelled := false


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	points = data.get("points", PackedVector3Array([position]))
	from_slot = int(data.get("slot", 0))
	caster_path = NodePath(str(data.get("caster", "")))
	aim_point = data.get("aim", position)
	follow_path = NodePath(str(data.get("follow", "")))
	cast_ticks = int(data.get("cast_ticks", 0))
	arm_ticks = int(data.get("arm_ticks", MatchClock.ticks_for(arm_s)))
	_attach_net()


func _ready() -> void:
	process_physics_priority = -1
	add_to_group(GROUP)


## Before entering the tree, so the spawn packet carries the synchronizer.
func _attach_net() -> void:
	var net := MpReplicate.new()
	net.name = "Net"
	net.interpolate = false
	net.sync_properties = PackedStringArray([".:phase", ".:cancelled", ".:position"] if replicates_position else [".:phase", ".:cancelled"]) + synced
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


## True on the server (and alone): the only peer that runs the clock and decides.
func is_authority() -> bool:
	return multiplayer.is_server()


## Server (or solo): the cast ended well; the zone waits its arming time and acts.
func release() -> void:
	if phase == Phase.CASTING:
		phase = Phase.ARMING if arm_ticks > 0 else Phase.ACTIVE


## Server (or solo): the cast was cut. The zone goes away without acting.
func cancel() -> void:
	if phase != Phase.ENDING:
		cancelled = true
		phase = Phase.ENDING


## Server (or solo): an open-ended zone is done.
func finish() -> void:
	if phase == Phase.ACTIVE:
		phase = Phase.ENDING


func hold_ticks() -> int:
	return maxi(1, MatchClock.ticks_for(spell.duration if hold_is_spell_duration and spell != null else hold_s))


func end_ticks() -> int: return MatchClock.ticks_for(end_s)


## The radius of ground the zone has reached for a full radius of `max_m`: nothing before ACTIVE, growing during `grow_s`, all after.
func grown_m(max_m: float) -> float:
	if phase < Phase.ACTIVE:
		return 0.0
	return max_m if phase > Phase.ACTIVE else ZoneRules.grown_radius(max_m, phase_ticks, MatchClock.ticks_for(grow_s))


func caster() -> Node3D:
	return get_node_or_null(caster_path) as Node3D if not caster_path.is_empty() else null


## The body the zone follows, or null (the ground, or it is gone).
func followed() -> Node3D:
	return get_node_or_null(follow_path) as Node3D if not follow_path.is_empty() else null


func _physics_process(_delta: float) -> void:
	phase_ticks += 1
	if not is_authority():
		return
	match phase:
		Phase.ARMING:
			if phase_ticks >= arm_ticks:
				phase = Phase.ACTIVE
		Phase.ACTIVE:
			if not open_ended and phase_ticks >= hold_ticks():
				phase = Phase.ENDING
		Phase.ENDING:
			if phase_ticks >= end_ticks():
				queue_free()
