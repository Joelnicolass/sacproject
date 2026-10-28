class_name RangedFire
extends RefCounted

## What happens on a shoot tick of a RangedWeapon: the direction (led by the target's velocity, raised for a ballistic shot, then
## scattered by the ranged accuracy) and the packet that spawns the shot, the volley of shots or the strike of the ShotLook.
## Not: when it shoots (RangedWeapon) nor the flight (RangedShot).
## Ref: sacengine getShotDirectionWithGravity (state.d:11506, 11548-11800), shootOnTick (state.d:12631-12758).

## fallingAcceleration; 30 for every other tag.
## Ref: sacspell.d:120.
const FALLING_ACCELERATION := {"dkba": 10.0}
const DEFAULT_FALLING := 30.0
## Shots fired with getShotDirectionWithGravity: earthfling, flame minion, fallen, sylph, ranger, mutant, abomination, bombard,
## flurry, flummox. The rest fly straight.
const BALLISTIC: PackedStringArray = ["ekba", "fkba", "dkba", "aaba", "wobf", "babt", "tugt", "cfba", "caba", "crba"]


## A body a shot may be loosed at: targetable, with Health, alive.
static func is_live(body: Node) -> bool:
	if not GameBody.targetable(body):
		return false
	var health := body.get_node_or_null("Health") as Health
	return health != null and not health.is_dead()


## manaCost = max(1, cost).
## Ref: sacspell.d:194.
static func mana_cost(weapon: RangedWeapon) -> float:
	return maxf(1.0, float(weapon.attack.mana_cost)) if weapon.attack else INF


static func mana_left(weapon: RangedWeapon) -> float:
	return weapon.weapons.mana.current if weapon.weapons != null and weapon.weapons.mana != null else 0.0


## Off cooldown and with the mana of a whole shot.
static func loaded(weapon: RangedWeapon) -> bool:
	return not (weapon.cooldown > 0.0 or mana_left(weapon) < mana_cost(weapon))


## One shoot tick of the clip (the clip says how many shots it has): it drains its share of the mana (if it has that much), fires,
## and the cooldown starts on the first shot.
## Ref: sacengine state.d:12774-12776.
static func tick(weapon: RangedWeapon, tick_count: int) -> void:
	var target := weapon.shooting_at
	if target == null or not is_instance_valid(target) or not is_live(target):
		return
	var cost := mana_cost(weapon) / float(maxi(tick_count, 1))
	var before := mana_left(weapon)
	if before < cost:
		return
	fire(weapon, target)
	weapon.weapons.mana.spend(cost)
	if weapon.cooldown <= 0.0:
		weapon.cooldown = weapon.attack.cooldown_s
	weapon.fired.emit(target, float(weapon.attack.damage), before, mana_left(weapon))


static func fire(weapon: RangedWeapon, target: Node3D) -> void:
	var attack := weapon.attack
	var look := weapon.look
	var body := weapon.body
	var spawner := ShotSpawner.of(weapon.get_tree())
	if look.strike == null and spawner == null:
		push_warning("RangedWeapon: no hay ShotSpawner en el mundo.")
		return
	var origin := weapon.shot_origin()
	var predicted := weapon.predicted(target)
	var offset := predicted - origin
	var direction: Vector3 = offset.normalized() if offset.length_squared() > 0.000001 else body.facing_flat()
	var ballistic := BALLISTIC.has(attack.tag)
	var gravity := float(FALLING_ACCELERATION.get(attack.tag, DEFAULT_FALLING)) if ballistic else 0.0
	if ballistic:
		direction.y += 0.5 * gravity * offset.length() / (attack.speed_m_s * attack.speed_m_s)
	direction = ShotAim.scatter(direction, weapon.accuracy(), weapon.rng)
	if not ballistic:
		direction = direction.normalized()
	var velocity: Vector3 = direction * attack.speed_m_s
	var data := {
		"tag": attack.tag,
		"look": FxWire.id_of(look.source),
		"x": origin.x, "y": origin.y, "z": origin.z,
		"vx": velocity.x, "vy": velocity.y, "vz": velocity.z,
		"damage": float(attack.damage) * maxf(0.0, body.attack_factor),
		"slot": body.owner_slot,
		"gravity": gravity,
		"max_distance": INF if ballistic else attack.cast_range_m * look.range_factor,
		"target": str(target.get_path()),
		"shooter": str(body.get_path()),
		## The predicted point without accuracy, and the accuracy, for the strikes that aim again.
		"aim_x": predicted.x, "aim_y": predicted.y, "aim_z": predicted.z,
		"accuracy": weapon.accuracy(),
	}
	if look.strike != null:
		_strike(weapon, data)
		return
	## ShotLook.volley shots with this one direction (one accuracy roll); each packet says
	## which one it is and how far the aim was (SplitFlight fans them out).
	## Ref: sacengine boulderdashShoot state.d:11806-11808.
	var half := (maxi(look.volley, 1) - 1) / 2
	for index in range(-half, half + 1):
		var shot := data.duplicate()  # a new Dictionary per shot: the spawner writes its name
		shot["volley_index"] = index
		shot["aim_distance"] = offset.length()
		spawner.spawn_shot(shot)


## A ShotStrike (ShotLook.strike) in place of a flying shot: the Gnome's ray, the Styx's blow. Server (or solo) only, as a child of
## the weapon; it is not replicated (its look goes through FxBus).
static func _strike(weapon: RangedWeapon, data: Dictionary) -> void:
	var node := weapon.look.strike.instantiate()
	var strike := node as ShotStrike
	if strike == null:
		node.free()
		push_warning("RangedWeapon: el strike de %s no es un ShotStrike." % weapon.attack.tag)
		return
	weapon.add_child(strike)
	strike.launch(data, weapon.look, weapon.attack, weapon)
