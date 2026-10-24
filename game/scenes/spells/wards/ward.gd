@tool
class_name Ward
extends Node3D

## One shield or temporary form of a body (Life Shield, Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective
## Swarm): while it is on, hits on the body are scaled by `factor`, it may make the body immune, and its look grows around
## the body. It does not decide how a hit is scaled across several wards (Wards) nor what the body does to its neighbours
## (BodyAura). The server (or solo) starts and stops it; `shown` is replicated, so every peer draws the look from it.
## It ends by its time or when the body dies.
## Ref: sacengine lifeShield, skinOfStone, airShield, protectiveSwarm (state.d:8962-8969, 13092-13100).

## The ward went on (true) or off (false). Every peer, from `shown`.
signal shown_changed(on: bool)
## The cast of this ward's spell began (true) or ended or was cut (false). Every peer, from the Caster's replicated cast particle.
signal casting_changed(on: bool)

## The body it protects: its box sizes the look; its name goes in the log.
@export var body: Node3D
## On its death the ward ends. Optional: empty = it only ends by its time.
@export var health: Health
## The spell that starts it (Wards.ward_for). Empty for a ward an ability starts (Life Shield).
@export var spell: SpellType
@export_group("Protection")
## Every hit is multiplied by this while the ward is on.
@export var factor := 1.0
## Hits of the ranged kinds are multiplied by this too (Air Shield: another x0.5).
@export var ranged_factor := 1.0
## The body takes no damage at all while the ward is on, not even a hit that pierces shields (Ethereal Form).
@export var immune := false
## The body counts as shielded: Freeze, Petrify and Pull refuse it.
@export var counts_as_shield := true
@export_group("Casting")
## The particle the hands throw while this spell is cast (HandFx plays it, from `data/fx/`). Every ward has its own, and that is how every peer
## knows which spell is being cast: it is the one whose type is showing. Empty = the ward does not follow the cast.
@export var cast_type: ParticleType
@export_group("Look")
## What is drawn. Optional: empty = no look.
@export var look: Node3D
## The look grows from nothing to the body's box (and back) over these ticks.
@export var grow_ticks := 15
## Size of the look over the body's box, per axis. Zero = the look keeps its own size and only shows or hides.
@export var look_scale := Vector3.ONE * 1.4
## While on, the body is drawn as stone (Afflictions owns that look; this only says the ward wants it).
@export var stone_skin := false

## Replicated by the body's MultiplayerSynchronizer ("Wards/<Name>:shown"). The server writes it; every peer draws it.
@export var shown := false:
	set(value):
		if value == shown:
			return
		shown = value
		if is_node_ready() and not Engine.is_editor_hint():
			_show(shown)
		shown_changed.emit(shown)

## MatchClock tick at which the ward is off. -1 = no ward.
var _until := -1
var _tween: Tween
## True while the wizard casts this ward's spell (casting_changed).
var casting := false


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint():
		return
	if body == null:
		body = get_parent().get_parent() as Node3D
	if health and has_authority():
		health.died.connect(_on_died)
	_follow_cast()
	if look:
		look.visible = shown
		if shown:
			_show(true)


## The FxBus name of `cast_type` (the file under data/fx/ without extension), "" without one. WardAction hands it to the Caster.
func cast_fx_name() -> String:
	return cast_type.resource_path.trim_prefix(FxBus.TYPES_DIR).get_basename() if cast_type != null else ""


## Listens to the wizard's cast particle: while it is this ward's own, the spell is being cast.
func _follow_cast() -> void:
	var caster := Caster.of(body)
	if caster == null or cast_type == null:
		return
	caster.cast_fx_changed.connect(_on_cast_fx)
	_on_cast_fx(caster.cast_fx_shown)


func _on_cast_fx(type_name: String) -> void:
	var on := not type_name.is_empty() and type_name == cast_fx_name()
	if on != casting:
		casting = on
		casting_changed.emit(on)


## Server (or solo): the ward of a SPEL for its duration. The one place the formula lives.
func start_for(type: SpellType) -> bool:
	return start(ticks_for_seconds(type.duration if type else 20.0))


static func ticks_for_seconds(seconds: float) -> int:
	return roundi(seconds * MatchClock.TICKS_PER_SECOND_F)


## Server (or solo). False (nothing changes) when the ward is already on.
func start(ticks: int) -> bool:
	if not has_authority() or is_on() or ticks <= 0:
		return false
	_until = MatchClock.now() + ticks
	shown = true
	set_physics_process(true)
	if DebugLog.on(&"shields"):
		print("escudo %s %s %d ticks (tick %d)" % [name, _who(), ticks, MatchClock.now()])
	return true


## The server's own clock: on from the tick it started until start + ticks. Derived from the tick, so whoever asks in a tick
## reads the same. A client trusts `shown`.
func is_on() -> bool:
	if not has_authority():
		return shown
	return _until >= 0 and MatchClock.now() < _until


## What a hit of `kind` is multiplied by for this ward (1 while off).
func factor_for(kind: StringName) -> float:
	if not is_on():
		return 1.0
	var ranged := kind == Health.DIRECT_RANGED or kind == Health.SPLASH_RANGED
	return factor * (ranged_factor if ranged else 1.0)


## Ticks left (0 while off). For the HUD and the log.
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
		print("escudo %s %s %s (tick %d)" % [name, _who(), reason, MatchClock.now()])


func _physics_process(_delta: float) -> void:
	if _until >= 0 and MatchClock.now() >= _until:
		stop()


func _on_died(_from_slot: int) -> void:
	stop("muerte")


## Every peer, from `shown`: the look grows to the body's box or shrinks away.
func _show(on: bool) -> void:
	if look == null:
		return
	if _tween:
		_tween.kill()
	if look_scale == Vector3.ZERO:
		look.visible = on
		return
	var full := (BodyNudge.box(body).size if body else Vector3(0.6, 1.8, 0.6)) * look_scale
	if on:
		look.position = body.to_local(BodyNudge.center(body)) if body else Vector3.UP * 0.9
		look.scale = Vector3.ONE * 0.01
		look.visible = true
	_tween = look.create_tween()
	_tween.tween_property(look, "scale", full if on else Vector3.ONE * 0.01, grow_ticks / MatchClock.TICKS_PER_SECOND_F)
	if not on:
		_tween.tween_callback(look.hide)


func _who() -> String:
	return str(body.name) if body else "?"


## True on the server (or in a solo match): the only peer that decides.
func has_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if health == null:
		warnings.append("Sin Health: el escudo no termina con la muerte.")
	return warnings
