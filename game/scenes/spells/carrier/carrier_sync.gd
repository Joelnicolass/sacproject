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
	net.sync_properties = PackedStringArray(PROPS_SOUL_TRIP if carrier.motion == SpellCarrier.Motion.SOUL_TRIP else PROPS_OTHER)
	MpAuthority.ensure_sync(carrier, net.sync_properties)
	carrier.add_child(net)


## The keys every guided projectile's `setup` reads (LaunchPoint.projectile_data): where it starts, who casts it, what it aims at, the spell's numbers.
static func read(carrier: SpellCarrier, data: Dictionary) -> void:
	carrier.name = str(data["name"])
	carrier.position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	carrier.wizard_path = NodePath(str(data.get("caster", "")))
	carrier.soul_path = NodePath(str(data.get("target", "")))
	carrier.from_slot = int(data.get("slot", 0))
	carrier.damage = float(data.get("damage", 0.0))
	carrier.speed = float(data.get("speed", 0.0))
	carrier.damage_range = float(data.get("damage_range", 0.0))
	carrier.start = carrier.position
