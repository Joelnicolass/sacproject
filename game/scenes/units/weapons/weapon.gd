class_name Weapon
extends Node

## A way for a creature to hurt something: one node under its Weapons. It says when it applies to a foe (`wants`), whether the
## body must walk closer, hold still or start (`aim`), and runs its attack animation until it ends (`advance`).
## Not: choosing who to attack (the states do) nor the damage rules (each kind of weapon owns its own).
## Edit: drop a melee_weapon.tscn or ranged_weapon.tscn under Weapons; the order of the children is the priority.
## Server (or solo) only: a client never calls it.

signal struck(target: Node3D, amount: float, hit_chance: float, roll: float)
## A blow reached its target on the attack tick, whatever the damage roll gave (the on-hit passives listen).
signal connected(target: Node3D, was_frozen: bool)
signal fired(target: Node3D, damage: float, mana_before: float, mana_after: float)

## What a weapon asks of the body this tick: walk on, stand and turn toward the aim, or the attack has just started.
enum Step { APPROACH, HOLD, FIRE }

## Off: the container skips this weapon (the creature keeps the node but never uses it).
@export var enabled := true

## The creature that carries it and the container that holds it. Set by Weapons.setup.
var body: UnitBody
var weapons: Weapons


## The container hands over the creature, its type and the stream of random numbers of its body (never the global one).
func setup(unit: UnitBody, _creature: CreatureType, _rng: RandomNumberGenerator) -> void:
	body = unit


## True when the weapon can attack at all (a ranged weapon with no attack is a node that never fires).
func armed() -> bool:
	return enabled


## True when this weapon is the one to use against `target` right now.
func wants(_target: Node3D) -> bool:
	return false


## One chase tick toward `target`: APPROACH (keep walking), HOLD (stand and turn) or FIRE (the attack started).
## Only called for a target `wants` accepted.
func aim(_target: Node3D) -> Step:
	return Step.APPROACH


## The flat direction the body turns to while it holds or fires; zero = it does not turn.
func aim_direction(_target: Node3D) -> Vector3:
	return Vector3.ZERO


func start(_target: Node3D) -> void:
	pass


## Advances the attack by `delta`. False once its animation has ended.
func advance(_delta: float) -> bool:
	return false


func cancel() -> void:
	pass


## Seconds before it can start again (0 = ready).
func cooldown_left() -> float:
	return 0.0


## The clip that plays while the attack runs.
func clip_role() -> String:
	return "idle"


## The name of the UnitState that runs while the attack lasts (a child of the unit's States).
func busy_state() -> StringName:
	return &"Idle"


## Bumps the replicated counter of the attack so every peer plays it (UnitBody.swings or shots).
func announce() -> void:
	pass
