class_name Burning
extends DamageOverTime

## F123 (RFC-030l): one fire on a body (sacengine Fire, state.d:2578-2587). setAblaze / setAblazeWithManaDrain
## (27670-27676) make it with `damage / lifetime` per frame; updateFire (15112-15130) then, once per frame:
##   deals that as ranged or spell damage (dealFireDamage, 9421-9427), with the fire's DamageMod (the Pyromaniac's
##     peirceShield skips Life Shield, Rockform, petrified and Skin of Stone, 8962-8969);
##   drains `mana_drain / lifetime` mana (drainMana, 8822-8825: never under 0; the Tickferno's heat ray);
##   puts 3 fire particles on a creature (not on a building);
##   ends after the update whose lifetime reached 0 (`return lifetime-- > 0`): lifetime + 1 updates, as DamageOverTime.
## A fire of no damage on a building ends on its first update (the Bombard's visual fire, 24521-24527).
##
## A fire keeps no sum with the others (sacengine refreshAblaze is a spell's, 030r), so there is no owner of aggregates
## as Poisoning: each Burning is its own owner. It lives under the body it burns (freed with it), steps itself once per
## physics tick and frees itself when DamageOverTime.step() says it is over. Server (or solo) only: BurnImpact makes it
## there; the look goes through FxBus.

const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")

## Mana drained per update (sacengine manaDrainPerFrame).
var mana_drain_per_tick := 0.0
## FxBus fire puffed on the body every `fire_every_ticks` updates while it burns, whatever it takes (a creature only).
var fire_fx := ""
var fire_every_ticks := 10
var fire_height_m := 0.8
## Mana this fire drained so far (for the log).
var drained := 0.0

var _health: Health
var _mana: ManaPool


## sacengine setAblaze / setAblazeWithManaDrain: `damage` over `lifetime` frames (`damage / lifetime` per update) as
## `kind`, and `mana_drain` over the same frames. Null when nothing would happen (a dead body, a building with no
## damage) or the body has no Health.
static func ignite(target: Node3D, damage: float, lifetime: int, kind: StringName, from_slot: int, mana_drain := 0.0,
		pierce := false, fx := "") -> Burning:
	if target == null or not is_instance_valid(target) or not _ROCK.is_live_body(target):
		return null
	var health := target.get_node_or_null("Health") as Health
	var creature := target.is_in_group(&"unit") or target.is_in_group(&"wizard")
	if health == null or (damage <= 0.0 and not creature):
		return null
	var frames := maxi(1, lifetime)
	var fire := Burning.new()
	fire.name = "Burning"
	fire.per_second = maxf(0.0, damage) / float(frames) * float(MatchClock.TICKS_PER_SECOND)
	fire.lifetime = frames
	fire.kind = kind
	fire.from_slot = from_slot
	fire.ignore_friendly = false
	fire.fx_name = ""
	fire.mana_drain_per_tick = maxf(0.0, mana_drain) / float(frames) if creature else 0.0
	fire.pierce_shield = pierce
	fire.fire_fx = fx if creature else ""
	target.add_child(fire, true)
	return fire


func _ready() -> void:
	_health = get_parent().get_node_or_null("Health") as Health
	_mana = get_parent().get_node_or_null("ManaPool") as ManaPool


func _physics_process(_delta: float) -> void:
	if _health == null or not step(_health):
		print(end_line(str(get_parent().name), _health) if _health else "fuego terminado sin vida")
		set_physics_process(false)
		queue_free()


## updateFire's order: the damage (DamageOverTime), then the mana, then the particles.
func step(health: Health) -> bool:
	var going := super.step(health)
	if mana_drain_per_tick > 0.0 and _mana:
		drained += _mana.drain(mana_drain_per_tick)
	if not fire_fx.is_empty() and fire_every_ticks > 0 and (updates - 1) % fire_every_ticks == 0:
		var on := get_parent() as Node3D
		if on:
			FxBus.broadcast(fire_fx, on.global_position + Vector3.UP * fire_height_m)
	return going


func end_line(who: String, health: Health) -> String:
	var line := super.end_line(who, health)
	if mana_drain_per_tick > 0.0:
		line += " maná -%.2f (queda %.2f)" % [drained, _mana.current if _mana else 0.0]
	return line


func _log_word() -> String:
	return "fuego"
