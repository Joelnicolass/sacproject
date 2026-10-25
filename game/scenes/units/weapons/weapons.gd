@tool
class_name Weapons
extends Node

## The weapons a creature carries: its children. The order of the children is the priority (the first weapon that wants the foe is the
## one used), and a weapon whose `enabled` is off or that has nothing to fire is skipped. It hands each weapon the creature, its type
## and the stream of random numbers of its body, and tells the creature when one struck or fired.
## Not: choosing who to attack (the chase state) nor how a weapon works (each Weapon).
## Edit: drop a melee_weapon.tscn or ranged_weapon.tscn as a child; delete one to take it away.

signal struck(target: Node3D, amount: float, hit_chance: float, roll: float)
signal fired(target: Node3D, damage: float, mana_before: float, mana_after: float)

## What a ranged weapon spends on each shot.
@export var mana: ManaPool
## The creature's health and its damage passive: the Firefist's passive scales a blow by the health it has left.
@export var health: Health
@export var passive: DamagePassive

## The first armed melee and ranged weapon (a ranged weapon with no attack still answers, for the origin of a shot). Null = none.
var melee: MeleeWeapon
var ranged: RangedWeapon

var _armed: Array[Weapon] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for weapon: Weapon in _children():
		weapon.weapons = self
		weapon.struck.connect(_on_struck)
		weapon.fired.connect(_on_fired)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_child_count() == 0:
		warnings.append("Suelta un melee_weapon.tscn o un ranged_weapon.tscn como hijo.")
	if mana == null:
		warnings.append("Asigná en `mana` el ManaPool de la unidad (el arma a distancia lo gasta).")
	return warnings


## The weapons that can be used, in priority order.
func ordered() -> Array[Weapon]:
	return _armed


## Hands every weapon the creature and works out which ones are in use. Safe to repeat (the body changed model).
func setup(unit: UnitBody, creature: CreatureType, rng: RandomNumberGenerator) -> void:
	_armed.clear()
	melee = null
	ranged = null
	var inert: RangedWeapon = null
	for weapon: Weapon in _children():
		weapon.setup(unit, creature, rng)
		if not weapon.armed():
			if inert == null and weapon is RangedWeapon and weapon.enabled:
				inert = weapon as RangedWeapon
			continue
		_armed.append(weapon)
		if melee == null and weapon is MeleeWeapon:
			melee = weapon as MeleeWeapon
		if ranged == null and weapon is RangedWeapon:
			ranged = weapon as RangedWeapon
	if ranged == null:
		ranged = inert


func cancel_all() -> void:
	for weapon: Weapon in _children():
		weapon.cancel()


func _children() -> Array[Weapon]:
	var found: Array[Weapon] = []
	for child: Node in get_children():
		var weapon := child as Weapon
		if weapon != null:
			found.append(weapon)
	return found


func _on_struck(target: Node3D, amount: float, hit_chance: float, roll: float) -> void:
	struck.emit(target, amount, hit_chance, roll)


func _on_fired(target: Node3D, damage: float, mana_before: float, mana_after: float) -> void:
	fired.emit(target, damage, mana_before, mana_after)
