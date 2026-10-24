class_name CarrierSync
extends RefCounted

## What a SpellCarrier reads from its spawn data and what it replicates to the clients: a soul-trip carrier only its position (the look is a rock or
## a funnel walking); every other one also its rotation, scale and phase (the look follows them). Nothing else.


## Server, client and solo: the carrier's `Net` child, once, as `setup` runs.
static func attach(carrier: SpellCarrier) -> void:
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray([".:position"] if carrier.motion == SpellCarrier.Motion.SOUL_TRIP else [".:position", ".:rotation", ".:scale", ".:phase"])
	MpAuthority.ensure_sync(carrier, net.sync_properties)
	carrier.add_child(net)


## The keys every guided projectile's `setup` reads (AimedAction.projectile_data): where it starts, who casts it, what it aims at, the spell's numbers.
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
