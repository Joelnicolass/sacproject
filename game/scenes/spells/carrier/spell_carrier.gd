class_name SpellCarrier
extends SpellProjectile

## Something a spell sends on a trip (one piece for all of them; `motion` says which). SOUL_TRIP: the Soul Mole's rock and the Soul Wind's funnel
## walk to a soul and back (SoulTrip). GUIDED: the dragon, Charm's spirits, Blind Rage's fist and the vaporizing shot fly to the target (GuidedFlight).
## FALL: the cow arcs onto it (CarrierFall). HUNT: Death walks to the closest creature again and again (CarrierHunt). On arriving it says `arrived`;
## a CarrierHold makes it wait and then say `settled`. The other children listen and act (TargetEffect, SoulFetch, a pulse, the look). The server (or
## solo) moves it and replicates it; a client only draws. It does not know what it carries nor who is near.

## Server only: SOUL_TRIP stands on the soul (`reached`); the trip is over (`ended`, the node frees itself); it reached its target (`arrived`, null: a
## point; for HUNT each blow); the wait there is over or there was none (`settled`); FALL went through the land (`landed`).
signal reached(soul: Soul)
signal ended
signal arrived(target: Node3D)
signal settled(target: Node3D)
signal landed(at: Vector3)
## Every peer: the look follows the phase.
signal phase_changed(now: Phase)

enum Motion { SOUL_TRIP, GUIDED, FALL, HUNT }
enum Phase { WAITING, CASTING, FLYING, SHRINKING, HOLDING, LINGERING, STRIKING, LEAVING }

@export var motion := Motion.SOUL_TRIP
## SOUL_TRIP: time of the trip (half each way), how far it bends to the side (a part of the distance to the soul).
@export_range(0.0666, 60.0, 0.0001, "suffix:s") var roundtrip_s := 9.0
@export_range(0.0, 2.0, 0.05) var bend := 0.75
@export_flags_3d_physics var ground_mask := 1
@export_group("Guided")
@export var on_arrive: CarrierArrive
@export_range(0.1, 12.0, 0.1, "suffix:rad/s") var turn_rate := PI
@export_range(0.0, 5.0, 0.1, "suffix:m") var flying_height_m := 1.0
@export_range(0.1, 3.0, 0.05, "suffix:m") var arrive_distance_m := 0.75
@export_range(0.1, 5.0, 0.1, "suffix:s") var shrink_s := 1.0
@export_range(0.0, 10.0, 0.1, "suffix:m") var cast_height_m := 4.0
@export_group("Parts")
@export var hold: CarrierHold
@export var fall: CarrierFall
@export var hunt: CarrierHunt

var armed := false
var frame := 0
var wizard_path := NodePath()
var soul_path := NodePath()
var from_slot := 0
var damage := 0.0
var speed := 0.0
var damage_range := 0.0
var spell: SpellType
var start := Vector3.ZERO
var flight: GuidedFlight
var phase := Phase.WAITING:
	set(value):
		if value != phase:
			phase = value
			phase_changed.emit(value)

var _trip: SoulTrip
var _ended := false


func setup(data: Dictionary) -> void:
	CarrierSync.read(self, data)
	_trip = SoulTrip.new(self) if motion == Motion.SOUL_TRIP else null
	if motion == Motion.GUIDED:
		flight = GuidedFlight.new(self)
		scale = Vector3.ONE * 0.01
	CarrierSync.attach(self)


func _ready() -> void:
	set_physics_process(multiplayer.is_server() and motion == Motion.SOUL_TRIP)


func wizard() -> Node3D:
	return get_node_or_null(wizard_path) as Node3D if not wizard_path.is_empty() else null


func soul() -> Soul:
	return get_node_or_null(soul_path) as Soul if not soul_path.is_empty() else null


func target_body() -> Node3D:
	return get_node_or_null(soul_path) as Node3D if not soul_path.is_empty() else null


## Server or solo. The cast started: a guided carrier follows `caster` for `cast_ticks` ticks; a hunter appears; a falling one waits for `arm`.
func begin(caster: Node3D, spell_cast: SpellType, target: Node3D, point: Vector3, cast_ticks: int) -> void:
	spell = spell_cast
	if motion == Motion.GUIDED:
		flight.begin(caster, target, point, cast_ticks)
	elif motion == Motion.HUNT:
		hunt.begin(caster, cast_ticks)
		set_physics_process(true)
	if on_arrive != null:
		on_arrive.begin(self, caster, spell_cast, target)


## Server or solo. The casting time is over: a guided carrier is let go toward `target`, the cow falls, the hunter hunts.
func arm(target: Node3D = null) -> void:
	armed = true
	if motion == Motion.GUIDED:
		flight.release(target)
		if on_arrive != null:
			on_arrive.released(self, flight.target)
	elif motion == Motion.FALL:
		fall.begin(target)
		set_physics_process(true)
	elif motion == Motion.HUNT:
		hunt.release()


## Server or solo. It reached `target`: the children hear it, and it waits (CarrierHold) or is done.
func arrive_at(target: Node3D) -> void:
	arrived.emit(target)
	if hold != null:
		hold.begin(target)
	else:
		settled.emit(target)
		stop()


## Server or solo. The spell was cancelled or the trip is over: nothing moves any more and the node goes.
func stop() -> void:
	if _ended:
		return
	_ended = true
	set_physics_process(false)
	ended.emit()
	queue_free()


func _physics_process(_delta: float) -> void:
	if _ended:
		return
	match motion:
		Motion.SOUL_TRIP:
			_trip.step()
		Motion.GUIDED:
			flight.step()
		Motion.FALL:
			fall.step()
		Motion.HUNT:
			hunt.step()
