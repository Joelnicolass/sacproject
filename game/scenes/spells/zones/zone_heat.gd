class_name ZoneHeat
extends Node

## A ring of heat around a zone: while the zone acts, every body between `full_m` and `reach_m` of its center is hurt at a rate that
## falls from full to nothing across the ring, and every creature there is set alight (the look of burning) and pushed away from the
## center, a little more the closer it is. One tick at a time, server (or solo) only. The same node does the volcano's burn (hurts,
## lights and pushes along the ground) and its slow push (pushes only). It does not time the zone (GroundZone) nor draw the fire (Burning).
## Ref: sacengine volcanoBurn, pushAll (state.d:22379-22403, 8614-8633).

@export var zone: GroundZone
## Between the center and `full_m` the effect is at full strength; it falls to nothing at `reach_m` (flat distance).
@export_range(0.0, 200.0, 0.5, "suffix:m") var full_m := 20.0
@export_range(1.0, 200.0, 0.5, "suffix:m") var reach_m := 50.0
@export_group("Hurt")
## Damage per second at full strength, as a share of the spell's damage (0 = it does not hurt).
@export_range(0.0, 4.0, 0.01) var damage_share := 0.0
## The fire a creature keeps (no damage: it is the look), and the sprite it puffs. 0 = it does not light anyone.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var burn_s := 0.0
@export var burn_look: ParticleType
@export_group("Push")
## Metres per second away from the center at full strength (0 = it does not push).
@export_range(0.0, 20.0, 0.01, "suffix:m/s") var push_m_s := 0.0
## The push and the distance go along the ground (no up part).
@export var push_flat := true
## Where the distance is counted from (nothing = the zone itself).
@export var origin: Marker3D

var _lit_until := {}
var _ticks := 0


func _ready() -> void:
	set_physics_process(zone != null and zone.is_authority() and not Engine.is_editor_hint())


## The strength at `distance` from the center: 1 up to `full_m`, 0 from `reach_m`.
func strength_at(distance: float) -> float:
	return 1.0 - maxf(0.0, distance - full_m) / maxf(reach_m - full_m, 0.001) if distance < reach_m else 0.0


func _physics_process(_delta: float) -> void:
	if zone.cancelled or zone.phase != GroundZone.Phase.ACTIVE:
		return
	_ticks += 1
	var center: Vector3 = (origin if origin != null else zone).global_position
	for body in SplashDamage.bodies_within(get_tree(), center, reach_m):
		var away: Vector3 = BodyNudge.center(body) - center
		if push_flat:
			away.y = 0.0
		var strength := strength_at(away.length())
		if strength <= 0.0:
			continue
		if damage_share > 0.0:
			SplashDamage.hurt(body, float(zone.spell.damage) * damage_share * strength / MatchClock.TICKS_PER_SECOND_F, zone.from_slot, Health.DIRECT_SPELL)
		if body.is_in_group(UnitBody.GROUP) or body.is_in_group(WizardBody.GROUP):
			_ignite(body)
			if push_m_s > 0.0 and away.length() > 0.001:
				BodyNudge.push(body, away.normalized() * push_m_s * strength)


## A fire of no damage (the look of burning) that is renewed when it runs out, never one on top of another.
func _ignite(body: Node3D) -> void:
	var id := body.get_instance_id()
	var burn_ticks := MatchClock.ticks_for(burn_s)
	if burn_ticks > 0 and int(_lit_until.get(id, 0)) <= _ticks:
		_lit_until[id] = _ticks + burn_ticks
		Burning.ignite(body, 0.0, burn_ticks, Health.DIRECT_SPELL, zone.from_slot, 0.0, false, burn_look)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if zone != null else PackedStringArray(["Falta la zona (GroundZone) cuyo calor es."])
