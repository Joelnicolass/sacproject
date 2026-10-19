@tool
class_name LifeShield
extends Node3D

## F126 (RFC-030 030o-a): the one owner of a body's life shield (sacengine effects.lifeShield). Life Shield (hsba, the
## Druid's and the Shrike's) and Protector (HSba, the Ent's, on itself and its allies) start it here; Health asks factor().
##   start(ticks)  sacengine lifeShield (state.d:13092-13100): refused (false) while one is on; else on for `ticks`
##                 (ability.duration · 60 = 1200), counted with MatchClock.
##   is_on()       the server's own clock: on from the tick it started until start + ticks (updateLifeShield removes it at
##                 frame 1200, state.d:25122-25155). It is derived from the tick, so whoever asks in a tick reads the same.
##   factor()      dealDamage (state.d:8962-8963): ×damage_factor (0.5) while on; peirceShield skips it (Health's caller).
## It also ends when the body dies (canShield, state.d:218-224, is false from dying on).
## `shown` is replicated: every peer grows the bubble from it over grow_ticks (LifeShield.scaleFrames = 15).
## Divergences (declared): it ends by its time or by death only (the other modes without canShield are not modelled);
## there is no shieldBlocked; the bubble is a placeholder.


## The body it shields: its box sizes the bubble; its name goes in the log.
@export var body: Node3D
## On its death the shield ends. Optional: empty = it only ends by its time.
@export var health: Health
## The look (shield_bubble.tscn). Optional: empty = no look.
@export var bubble: Node3D
## sacengine dealDamage: `if(effects.lifeShield) damageMultiplier *= 0.5`.
@export var damage_factor := 0.5
## sacengine LifeShield.scaleFrames: the bubble grows (and shrinks) over these ticks.
@export var grow_ticks := 15
## The bubble's size over the body's box (per axis). sacengine renders scale·1.4·boxSize.
@export var bubble_scale := 1.4


## Replicated by the unit's MultiplayerSynchronizer ("LifeShield:shown"). The server writes it; every peer draws it.
@export var shown := false:
	set(value):
		if value == shown:
			return
		shown = value
		if is_node_ready() and not Engine.is_editor_hint():
			_show(shown)

## MatchClock tick at which the shield is off. -1 = no shield.
var _until := -1
var _tween: Tween


## The LifeShield of `node`, or null (a body without one is never shielded).
static func of(node: Node) -> LifeShield:
	return (node.get_node_or_null("LifeShield") as LifeShield) if node else null


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint():
		return
	if body == null:
		body = get_parent() as Node3D
	if health and _has_authority():
		health.died.connect(_on_died)
	if bubble:
		bubble.visible = shown
		if shown:
			_show(true)


## Server (or solo): the shield of a SPEL (Life Shield, Protector): its duration in ticks. The one place the formula lives.
func start_for(ability: AbilityType) -> bool:
	return start(ticks_for(ability))


static func ticks_for(ability: AbilityType) -> int:
	return roundi((ability.duration if ability else 20.0) * MatchClock.TICKS_PER_SECOND_F)


## Server (or solo). sacengine lifeShield: false (nothing changes) when a shield is already on.
func start(ticks: int) -> bool:
	if not _has_authority() or is_on() or ticks <= 0:
		return false
	_until = MatchClock.now() + ticks
	shown = true
	set_physics_process(true)
	if DebugLog.on(&"shields"):
		print("escudo %s %d ticks (tick %d)" % [_who(), ticks, MatchClock.now()])
	return true


func is_on() -> bool:
	if not _has_authority():
		return shown
	return _until >= 0 and MatchClock.now() < _until


## What a hit is multiplied by for this shield (1 without one).
func factor() -> float:
	return damage_factor if is_on() else 1.0


## Ticks left (0 without a shield). For the HUD and the log.
func ticks_left() -> int:
	return maxi(0, _until - MatchClock.now()) if is_on() else 0


## Server (or solo): turns it off now (death; later, Dispel).
func stop(reason := "fin") -> void:
	if _until < 0:
		return
	_until = -1
	shown = false
	set_physics_process(false)
	if DebugLog.on(&"shields"):
		print("escudo %s %s (tick %d)" % [_who(), reason, MatchClock.now()])


func _physics_process(_delta: float) -> void:
	if _until >= 0 and MatchClock.now() >= _until:
		stop()


func _on_died(_from_slot: int) -> void:
	stop("muerte")


## Every peer, from `shown`: the bubble grows to the body's box or shrinks away.
func _show(on: bool) -> void:
	if bubble == null:
		return
	if _tween:
		_tween.kill()
	var full := _bubble_size()
	if on:
		bubble.position = _bubble_center()
		bubble.scale = Vector3.ONE * 0.01
		bubble.visible = true
	_tween = bubble.create_tween()
	_tween.tween_property(bubble, "scale", full if on else Vector3.ONE * 0.01, grow_ticks / MatchClock.TICKS_PER_SECOND_F)
	if not on:
		_tween.tween_callback(bubble.hide)


func _bubble_center() -> Vector3:
	return body.to_local(BodyNudge.center(body)) if body else Vector3.UP * 0.9


func _bubble_size() -> Vector3:
	return (BodyNudge.box(body).size if body else Vector3(0.6, 1.8, 0.6)) * bubble_scale


func _who() -> String:
	return str(body.name) if body else "?"


func _has_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if bubble == null:
		warnings.append("Sin burbuja: el escudo no se ve.")
	if health == null:
		warnings.append("Sin Health: el escudo no termina con la muerte.")
	return warnings
