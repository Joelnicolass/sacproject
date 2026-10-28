class_name CreatureLink
extends Node

## Which creature a UnitBody is: it wears the body scene of its CreatureType (size, sockets, model
## id) and mounts the passives that come with it, takes its pace, sight and regeneration from it,
## hands the type to its weapons and abilities, gives it its health and mana once and bursts it if
## it falls into a hole. The body holds the type itself (the spawner sets `UnitBody.type` before it
## enters the tree).
## Not: what the creature does (States, Weapons, Engagement) nor how the type is found (the spawner
## and the catalog).

## The type was applied to the body: its pace, its sight and its body scene.
signal type_applied

@export var body: UnitBody
@export var health: Health
@export var mana: ManaPool
@export var regeneration: Regeneration
@export var health_bar: UnitHealthBar
@export var flight: Flight
@export var locomotion: Locomotion
## Where the passives of the body scene go (the Firefist's fury, the Phoenix's shield).
@export var passives: PassiveMount

## The stream of chance of its weapons, seeded from the name of the body (MatchSeed) when it
## simulates.
var rng := RandomNumberGenerator.new()

var _stats_ready := false


func _ready() -> void:
	if flight != null:
		flight.state_changed.connect(_on_flight_changed)
	locomotion.fell.connect(Gib.fall_into_hole.bind(body))
	health_bar.bind(health, body.owner_slot, body)


## The type of the body changed: its pace, its sight, its body scene and its passives follow; the
## model id comes from the body scene.
func adopt() -> void:
	var type := body.type
	_adopt_pace()
	if regeneration != null:
		regeneration.rate_per_s = type.regeneration_per_s if type else 0.0
		regeneration.always = type != null and type.regenerates_always
	if body.vision != null:
		body.vision.adopt_range(type.vision_m if type else 0.0)
	if type and body.mount != null:
		body.mount.wear(type.body)
		if passives != null:
			passives.mount(body.mount.facts.passives)
		if body.model.is_empty():
			body.model = body.mount.facts.model_id
	type_applied.emit()


## The model id is known: the health bar sits above the body and the weapons get the creature again.
func adopt_model() -> void:
	if body.model.is_empty():
		return
	if health_bar != null:
		health_bar.place_above(body.mount.facts.height_m)
	if body.is_node_ready():
		arm()


## The weapons get the creature again (they work out which ones are in use).
func arm() -> void:
	body.weapons.setup(body, body.type, rng)


## Every peer, once the body is ready: the type reaches its weapons and abilities.
func equip() -> void:
	body.weapons.struck.connect(body.struck.emit)
	arm()
	body.abilities.setup(body, body.type)


## Server or solo, once the body is ready: its health and mana, its stream of chance (seeded from
## its name), the ray casts that seat it on the ground and its weapons once more, now with the
## seeded stream.
func start_simulation() -> void:
	_init_stats()
	MatchSeed.seed_rng(rng, ["body", String(body.name)], body.rng_seed)
	if body.type and not body.is_flying():
		body.air.seat_left = body.air.seat_attempts
	arm()


func _init_stats() -> void:
	var type := body.type
	if type == null or _stats_ready:
		return
	_stats_ready = true
	health.setup(float(type.health))
	regeneration.last_health = float(type.health)
	mana.setup(float(type.mana))


## Every peer (Flight:state is replicated): the pace of the air or the ground, and the clip.
func _on_flight_changed(_state: Flight.State) -> void:
	_adopt_pace()
	body.clips.update()


func _adopt_pace() -> void:
	var type := body.type
	if type:
		body.move_speed = type.fly_speed_m_s if body.is_flying() else type.run_speed_m_s
	else:
		body.move_speed = 0.0
