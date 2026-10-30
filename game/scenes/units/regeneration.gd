class_name Regeneration
extends Node

## How a body (a creature or a wizard) heals by itself: at rest, once the pause after a hit is over,
## in proportion to the mana it has left; a body that regenerates always (the Troll) heals in any
## mode that can heal, with no pause. A blocked body (Afflictions) heals nothing in either case.
## Not: when to heal or what «at rest» is (the body asks once per physics step, in its own order:
## this node never processes by itself) nor what heals it from outside (spells, auras).

## The body that heals: the souls it devoured add to the rate (DevourGrowth), and a dead one does
## not regenerate always.
@export var body: GameBody
@export var health: Health
@export var mana: ManaPool
## Seconds after a hit before it heals again.
@export_range(0.0, 10.0, 0.01, "suffix:s") var pause_s := 0.5

## Health per second at full mana. The owner sets it from its type (CreatureLink, WizardBody).
var rate_per_s := 0.0
## It heals in any mode that can heal, with no pause (the Troll). The owner sets it from its type.
var always := false
## The health the last change left it with; a drop below it is a hit and starts the pause. Creature
## seeds it with the full health.
var last_health := 0.0

var _since_damage := INF


func _ready() -> void:
	health.changed.connect(_on_health_changed)


## The first thing a step does: time passes since the last hit.
func age(delta: float) -> void:
	_since_damage += delta


## Once per step. `resting`: the body is at rest (a creature: the state of its mode, or playing
## dead, is one that regenerates; a wizard: it stands and does not cast).
func step(delta: float, resting: bool) -> void:
	if resting:
		heal(delta, true)
	elif always and not body.is_dead() and not health.is_dead():
		heal(delta, false)


## Regeneration per second times mana over full mana (1 without mana). `paused`: not during
## `pause_s` after a hit.
func heal(delta: float, paused := true) -> void:
	if (paused and _since_damage < pause_s) or health.is_full():
		return
	var full := mana.maximum
	var factor := 1.0 if full <= 0.0 else mana.current / full
	health.regenerate((rate_per_s + DevourGrowth.extra_regeneration_of(body)) * factor * delta)
	last_health = health.current


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < last_health:
		_since_damage = 0.0
	last_health = current
