class_name LaunchPoint
extends RefCounted

## Where a wizard's ball leaves his hands. It does not aim, pick a target or spawn anything
## (ProjectileLaunch says what the projectile is told).


## Where a thrown ball leaves: the Muzzle marker of the wizard's body scene (hand height, in front
## of his hit box).
static func from_hand(wizard: WizardBody) -> Vector3:
	return from_hand_facing(wizard, wizard.facing_flat())


## The same spot with the wizard turned to `facing` (flat, unit): the AI asks where the ball will
## leave once he turns to his target.
static func from_hand_facing(wizard: WizardBody, facing: Vector3) -> Vector3:
	var muzzle := BodyFacts.of_body(wizard).muzzle
	var at := wizard.global_position + Vector3(0.0, muzzle.y, 0.0)
	at += facing * muzzle.z
	return at
