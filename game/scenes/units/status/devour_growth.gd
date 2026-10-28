class_name DevourGrowth
extends Node

## What a creature that ate souls (Devour: Netherfiend crpd, Hellmouth nomd) has become. The one owner
## of the souls eaten, the regeneration they added, the resistance they took and the bulk the body draws.
## Per soul eaten: health and maximum +500; the regeneration increment is 0.25·maximum the first time
## and 0.75·increment + 125 after; regeneration += increment/60 a second; the five resistances ×0.9; numBulks +1. The bulk is
## render only: 2 − 0.75ⁿ, reached by a smoothing of exp(ln 0.1/60) a tick.
## Nobody else keeps these numbers: Health asks resistance_factor() (and MeleeWeapon through resistance_factor_of), UnitBody asks
## extra_regeneration_of() when it regenerates, Devour calls grow(). The cure (Rainbow) is HealEffect's.
## `shown` (the souls eaten) is replicated (the unit's MultiplayerSynchronizer, "DevourGrowth:shown"): every peer draws the bulk
## from it. Declared: the bulk is a scale of the mesh, not the original's bone bulge (placeholder).
## Server (or solo) only for grow().
## Ref: F131 (RFC-030 030t-a), sacengine devourSoul state.d:13138-13163, bulk 13943-13948.


## The body that grows (its name goes in the log). Empty = the parent.
@export var body: Node3D
## Where the maximum goes up and the bar is (Health.raise_maximum). Required.
@export var health: Health
## What is scaled for the bulk (the mesh of the body). Empty = nothing is drawn.
@export var visual: Node3D
@export_group("Per soul")
@export var health_per_soul := 500.0
## The first increment is this fraction of the maximum (after the +500), the next ones increment·keep + add.
@export var first_increment := 0.25
@export var increment_keep := 0.75
@export var increment_add := 125.0
## The increment heals over this long: regeneration per second goes up by increment / regeneration_over_s.
## Ref: state.d:13138-13163 (increment / updateFPS).
@export_range(1.0, 600.0, 0.0001, "suffix:s") var regeneration_over_s := 60.0
@export var resistance_step := 0.9
@export_group("Bulk")
## bulk target = 2 − bulk_step^n
@export var bulk_step := 0.75
## Smoothing per tick: 1 − exp(ln(0.1)/60).
@export var bulk_blend := 0.0376494
## The swelling of Intestinal Vaporization adds up to this much to the bulk when `inflation` is 1 (maxBulk 2.5 − 1).
@export var inflate_by := 1.5

## Replicated: souls eaten. The setter is the one place the bulk is asked.
@export var shown := 0:
	set(value):
		if value == shown:
			return
		shown = value
		set_physics_process(is_inside_tree() and _bulk_moving())

## Replicated: how swollen the body is, 0..1 (Intestinal Vaporization writes it each tick it lasts; nobody else). Drawn at once, with no smoothing.
@export_range(0.0, 1.0) var inflation := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if is_equal_approx(value, inflation):
			return
		inflation = value
		_show_bulk()

var _increment := -1.0
var _extra := 0.0
var _resistance := 1.0
var _bulk := 1.0


## The DevourGrowth of `node`, or null (a body that cannot devour has none).
static func of(node: Node) -> DevourGrowth:
	return (node.get_node_or_null("DevourGrowth") as DevourGrowth) if node else null


## ×0.9ⁿ the body took (1 with none). MeleeWeapon and Health multiply their resistance by it.
static func resistance_factor_of(node: Node) -> float:
	var growth := of(node)
	return growth.resistance_factor() if growth else 1.0


## What the souls added to the regeneration per second (0 with none). UnitBody adds it to the type's.
static func extra_regeneration_of(node: Node) -> float:
	var growth := of(node)
	return growth.extra_regeneration() if growth else 0.0


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	set_physics_process(_bulk_moving())


func resistance_factor() -> float:
	return _resistance


func extra_regeneration() -> float:
	return _extra


## Server (or solo). The body eats `souls` souls (the soul.number of what it devoured). `from` is what the log calls them.
func grow(souls: int, from := "") -> void:
	if not is_multiplayer_authority() or souls <= 0 or health == null:
		return
	var life := health.current
	var most := health.maximum
	for _i in souls:
		health.raise_maximum(health_per_soul)
		_increment = first_increment * health.maximum if _increment < 0.0 else increment_keep * _increment + increment_add
		_extra += _increment / regeneration_over_s
		_resistance *= resistance_step
		shown += 1
	if DebugLog.on(&"devour"):
		print("devora %s alma %s n %d vida %d->%d máx %d->%d incremento %.3f regeneración +%.3f/s resistencia %.4f (tick %d)" % [
			AbilityEffect.who(body), from, souls, roundi(life), roundi(health.current), roundi(most), roundi(health.maximum),
			_increment, _extra, _resistance, MatchClock.now()])


func _physics_process(_delta: float) -> void:
	var target := 2.0 - pow(bulk_step, float(shown))
	_bulk = (1.0 - bulk_blend) * _bulk + bulk_blend * target
	if absf(_bulk - target) < 0.0005:
		_bulk = target
		set_physics_process(false)
	_show_bulk()


func _show_bulk() -> void:
	if visual != null:
		visual.scale = Vector3.ONE * (_bulk + inflate_by * inflation)


func _bulk_moving() -> bool:
	return shown > 0 and absf(_bulk - (2.0 - pow(bulk_step, float(shown)))) >= 0.0005
