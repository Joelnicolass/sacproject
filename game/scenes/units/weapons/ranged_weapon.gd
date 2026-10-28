class_name RangedWeapon
extends Weapon

## A shot: the creature stops, turns until it faces the aim, spends mana and fires on the shoot ticks of its clip, then waits out
## the cooldown. What flies is the AbilityType in `attack_type` (or the creature's own); how it looks and what it does on arrival
## is that ability's `shot_look` (a ShotLook scene of data/shots/): a breath is this weapon with a ShotLook whose in_flight is a wave.
## Not: the flight (RangedShot) nor who to shoot (the chase state).
## Server (or solo) only.

## The ranged attack this weapon fires. Empty = the creature's own (CreatureType.ranged_attack).
@export var attack_type: AbilityType
## It shoots unless the foe is in melee contact: its box within this many metres of ours.
@export var melee_distance := 0.5
## It stops to shoot at max(range_factor·range, range − range_margin) from the body to the target's box.
@export var range_factor := 0.8
@export var range_margin := 30.0
## It shoots once it faces the aim within what it turns in this long.
@export_range(0.0, 1.0, 0.0001, "suffix:s") var facing_s := 0.0666
## The shot leaves from the body's front at this fraction of its height (the baked bodies have no hand bones).
@export var shot_height := 0.7
## The line to the target is checked this far under both ends.
@export var clear_shot_drop := 0.2
@export_flags_3d_physics var ground_mask := 1

## The ability it fires and the look of that shot (a child of this node, made again when the ability changes).
var attack: AbilityType
var look: ShotLook
var type: CreatureType
var rng: RandomNumberGenerator
## Seconds before the next shot, and the foe the shot in course is for.
var cooldown := 0.0
var shooting_at: Node3D

var _clip := ShotClip.new()


func setup(unit: UnitBody, creature: CreatureType, stream: RandomNumberGenerator) -> void:
	super.setup(unit, creature, stream)
	type = creature
	rng = stream
	attack = attack_type if attack_type != null else (creature.ranged_attack if creature else null)
	if attack and attack.speed_m_s <= 0.0:
		attack = null
	if attack and attack.shot_look == null:
		push_error("RangedWeapon: the ranged attack %s has no shot_look; it flies as a plain ball." % attack.resource_path)
	if attack and unit.simulates():
		look = ShotLook.fit(self, look, attack.shot_look)
	elif look != null:
		look.queue_free()
		look = null


## A client counts it down too, but nothing there reads it: only the server starts a shot.
func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


func armed() -> bool:
	return enabled and attack != null


func cooldown_left() -> float:
	return cooldown


func cancel() -> void:
	_clip.active = false
	shooting_at = null


func wants(target: Node3D) -> bool:
	return RangedAim.wants(self, target)


func aim(target: Node3D) -> Step:
	var step := RangedAim.step(self, target)
	if step == Step.FIRE:
		start(target)
	return step


func aim_direction(target: Node3D) -> Vector3:
	return RangedAim.direction(self, target)


func announce() -> void:
	weapons.shots += 1


func busy_state() -> StringName:
	return &"Shoot"


## The shot clip when the model has it, else the rest pose.
func clip_role() -> String:
	return "shoot" if body.has_clip("shoot") else "idle"


func start(foe: Node3D) -> void:
	shooting_at = foe
	_clip.begin(type.clip_facts() if type else ClipFacts.of(null))


## Advances the shoot clip by delta. False once it has ended.
func advance(delta: float) -> bool:
	if not _clip.active:
		return false
	# Each layer of Slime makes the shot take 5x as long.
	for _shot in _clip.advance(delta / Afflictions.stat_factor_of(body, Afflictions.Stat.ATTACK_TIME)):
		RangedFire.tick(self, _clip.shots.size())
	if _clip.ended():
		_clip.active = false
		return false
	return true


## Where a shot leaves: the body's front at shot_height of its height. Public for a strike that follows its shooter.
func shot_origin() -> Vector3:
	return ShotAim.origin(body, shot_height)


## The target's centre where it will be when the shot arrives.
func predicted(target: Node3D) -> Vector3:
	return ShotAim.predicted(body, target, attack.speed_m_s if attack else 0.0)


func accuracy() -> float:
	return float(type.ranged_accuracy_milli()) if type else 0.0
