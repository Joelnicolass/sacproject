extends Node

## Debug only: `debug_hit` (K) stuns the local wizard, which cuts the cast it is doing (Caster interrupts it). Nothing in the
## product cuts a cast on a key, so the cut of a rising tower needs this. Solo / server only.

@export var world: MatchWorld
@export var stunned_type: AfflictionType
## Stun cooldown handed to Stunned (the stun itself lasts its clips).
@export var cooldown_s := 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_hit") or world == null:
		return
	var wizard := world.local_wizard()
	var afflictions := Afflictions.of(wizard)
	var stunned := afflictions.child_for(stunned_type) as Stunned if afflictions != null else null
	if stunned != null:
		print("stun_key: %s" % ("aturdido" if stunned.stun_with_cooldown(MatchClock.ticks_for(cooldown_s)) else "no se pudo aturdir"))
