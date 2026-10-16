class_name Flight
extends Node

## F116 (RFC-030e): take off, fly and land of a hybrid flier (sacengine canFly && !mustFly: Blight, Gremlin, Ikarus,
## Pyrodactyl, Seraph, Dragon, Hellmouth, Silverback, Phoenix). A child of unit.tscn; take it away and every hybrid walks.
## A creature that must fly (CreatureType.is_flying) or has no fly clip never leaves GROUND here.
##
## GROUND   walks. On a walk it takes off when flying gets there first: takeoffTime + d/fly < d/ground
##          (state.d:12335-12339, startFlying 8692-8704).
## TAKEOFF  the takeoff clip on the spot, takeoff frames / 30 s (sacobject.d:125-128, state.d:14141-14150).
## FLYING   straight to the goal at the flying speed, climbing to `flying_height` at takeoffSpeed = flying speed
##          (state.d:14756-14763). Not walking any more: it comes down at landingSpeed = ½ flying speed.
## LANDING  touched the ground: the land clip on the spot (state.d:8113-8126, 14155-14160), then GROUND.
## Deviation: sacengine only lands with `land` (8706-8716, a debug key there); stopped fliers hover down to height 0 and
## stay "flying". Here a flier that stops lands (RFC-030 030e).
## The server (or solo) runs it; `state` is replicated and the body picks its clip and speed from it on every peer.

signal state_changed(state: State)

enum State { GROUND, TAKEOFF, FLYING, LANDING }

## The body it lifts (the parent unit).
@export var body: UnitBody
## sacengine CreatureStats.flyingHeight (stats.d:154).
@export var flying_height := 4.5
## sacengine downwardHoverSpeed (stats.d:148): a flier above its height while it flies on.
@export var downward_hover_speed := 3.0
## sacengine landingSpeed = 0.5 · flying speed (stats.d:145-147).
@export_range(0.0, 1.0) var landing_speed_factor := 0.5
## F120: while a state holds the body (stunned, petrified) its movement does not change (sacengine stunned keeps
## creatureState.movement, state.d:8138-8150, 14170-14212): no takeoff, no landing, and a flier keeps its height.
## Optional: empty = nothing holds it.
@export var afflictions: Afflictions
## Height over the ground at which a flier coming down has touched it.
@export var touch_m := 0.05

@export var state: State = State.GROUND:
	set(value):
		if value == state:
			return
		state = value
		state_changed.emit(state)

var _left := 0.0


func _ready() -> void:
	if body == null:
		body = get_parent() as UnitBody


func _get_configuration_warnings() -> PackedStringArray:
	if body == null and not get_parent() is UnitBody:
		return PackedStringArray(["Falta el cuerpo (body)."])
	return PackedStringArray()


## A hybrid flier: walks and flies.
func is_capable() -> bool:
	return body != null and body.type != null and body.type.is_hybrid_flier()


## In the air (its body is not held by the ground).
func is_airborne() -> bool:
	return state == State.FLYING


## Taking off or landing: the clip plays on the spot, the body does not move across the ground.
func holds_still() -> bool:
	return state == State.TAKEOFF or state == State.LANDING


## Server: a walk of `distance` meters to its goal. True when it goes by air (it already flies or takes off now): the
## body then goes straight, with no waypoints (sacengine resets the path of a flier, state.d:12298).
func goes_by_air(distance: float) -> bool:
	if state == State.FLYING or state == State.TAKEOFF:
		return true
	if state != State.GROUND or _held() or not is_capable() or distance <= 0.0:
		return false
	var type := body.type
	if type.takeoff_time_s() + distance / type.flying_speed >= distance / type.running_speed:
		return false
	_take_off()
	return true


## Server, once per physics tick before the body moves. `walking`: the body is on its way to a goal. `above`: its height
## over the ground under its center, `on_floor`: its capsule rests on something (a slope holds it above `above`); both only
## read while FLYING. Returns the vertical speed of a flier; 0 on the ground.
func advance(delta: float, walking: bool, above: float, on_floor: bool) -> float:
	if _held():
		return 0.0
	match state:
		State.TAKEOFF:
			_left -= delta
			if _left <= 0.0:
				state = State.FLYING
		State.LANDING:
			_left -= delta
			if _left <= 0.0:
				state = State.GROUND
		State.FLYING:
			return _vertical(delta, walking, above, on_floor)
	return 0.0


## Held: the state and the height wait (advance returns 0: a flier hangs where it is).
func _held() -> bool:
	return afflictions != null and afflictions.holds()


func _take_off() -> void:
	var takeoff := body.type.takeoff_time_s()
	if takeoff <= 0.0:
		state = State.FLYING
		return
	_left = takeoff
	state = State.TAKEOFF


func _vertical(delta: float, walking: bool, above: float, on_floor: bool) -> float:
	var step := maxf(delta, 0.000001)
	var fly := body.type.flying_speed
	if walking:
		if not is_finite(above):
			return 0.0
		if above < flying_height:
			return minf((flying_height - above) / step, fly)
		return -minf((above - flying_height) / step, downward_hover_speed)
	if not is_finite(above) or above <= touch_m or on_floor:
		_touch_down()
		return -maxf(above, 0.0) / step if is_finite(above) else 0.0
	return -minf(above / step, fly * landing_speed_factor)


func _touch_down() -> void:
	var land := body.type.land_time_s()
	if land <= 0.0:
		state = State.GROUND
		return
	_left = land
	state = State.LANDING
