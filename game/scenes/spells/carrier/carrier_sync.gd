class_name CarrierSync
extends RefCounted

## What a SpellCarrier reads from its spawn data and what it replicates to the clients: a soul-trip carrier its position (the look is a rock or
## a funnel walking) and its phase (it turns to LEAVING when it takes the soul: the clients hear it); every other one also its rotation and
## scale (the look follows them). Nothing else.

const PROPS_SOUL_TRIP: Array[String] = [".:position", ".:phase"]
const PROPS_OTHER: Array[String] = [".:position", ".:rotation", ".:scale", ".:phase"]


## Server, client and solo: the carrier's `Net` child, once, as `setup` runs.
static func attach(carrier: SpellCarrier) -> void:
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray(
		PROPS_SOUL_TRIP if carrier.motion == SpellCarrier.Motion.SOUL_TRIP else PROPS_OTHER
	)
	MpAuthority.ensure_sync(carrier, net.sync_properties)
	carrier.add_child(net)


## Reads the carrier's ProjectileLaunch: where it starts, who casts it, what it goes for, the spell's numbers.
static func read(carrier: SpellCarrier, data: Dictionary) -> void:
	var launch := ProjectileLaunch.from_dict(data)
	carrier.name = launch.name
	carrier.position = launch.from
	carrier.wizard_path = launch.caster
	carrier.soul_path = launch.target
	carrier.from_slot = launch.slot
	carrier.damage = launch.damage
	carrier.speed = launch.speed_m_s
	carrier.damage_range = launch.damage_range_m
	carrier.start = carrier.position
