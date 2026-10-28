class_name AnimateDeadFx
extends SpellProjectile

## What everybody sees while Animate Dead brings a creature back: a burst of violet sparks over it when it starts, and, while it rises, about
## fifteen streams a second from the wizard to it (StreamerFx), in the original's rhythm: every second tick, one time in two. It lasts as
## long as the revival and frees itself. Presentation only, on every peer: it never touches the creature (FastRevive does) and makes
## nothing in a headless process.

## One stream. Its look is its own BeamType.
@export var streamer_scene: PackedScene
## The burst over the creature (a one-shot SpriteEmitter child). The effect is born on the creature, so its sound plays there too.
@export var burst: SpriteEmitter
## A stream is born every this long, with `chance` of it really being born (30 rolls a second, half of them).
@export_range(0.0166, 0.5, 0.0001, "suffix:s") var every_s := 0.0333
@export_range(0.0, 1.0, 0.05) var chance := 0.5

var wizard_path := NodePath()
var creature_path := NodePath()
var ticks := 300
var _age := 0
var _rng := RandomNumberGenerator.new()


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	wizard_path = NodePath(str(data.get("caster", "")))
	creature_path = NodePath(str(data.get("target", "")))
	ticks = int(data.get("ticks", 300))
	_rng.seed = hash(name)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var creature := get_node_or_null(creature_path) as Node3D
	if burst != null and creature != null:
		burst.global_position = BodyNudge.center(creature)
		burst.set_active(true)


func _physics_process(_delta: float) -> void:
	_age += 1
	if _age > ticks:
		queue_free()
		return
	if DisplayServer.get_name() == "headless" or streamer_scene == null or _age % maxi(1, MatchClock.ticks_for(every_s)) != 0:
		return
	if _rng.randf() >= chance:
		return
	var from := get_node_or_null(wizard_path) as Node3D
	var to := get_node_or_null(creature_path) as Node3D
	if from == null or to == null:
		return
	var stream := streamer_scene.instantiate() as StreamerFx
	add_child(stream)
	stream.play(from, to, _rng.randi())
