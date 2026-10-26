extends RefCounted

## Reads FxBus's burst pool from the children of its %Bursts (RFC-029 029b), never through a play: emitters are named
## `<type>_<n>`, visible while their burst plays and hidden when idle. For the labs and benches of debug/.


## type name -> Vector3i(playing, idle, cap).
static func by_type(bus: Node) -> Dictionary:
	var pool := bus.get_node("%Bursts") as BurstPool
	var out := {}
	for child in pool.get_children():
		if not child is SpriteParticles:
			continue
		var type_name := type_of(child)
		var row: Vector3i = out.get(type_name, Vector3i(0, 0, pool.cap_of((child as SpriteParticles).type)))
		if (child as Node3D).visible:
			row.x += 1
		else:
			row.y += 1
		out[type_name] = row
	return out


## "fx_pool activos n libres m · hijos h · tope t": t = Σ caps of the types the pool holds.
static func line(bus: Node) -> String:
	var playing := 0
	var idle := 0
	var cap := 0
	for row: Vector3i in by_type(bus).values():
		playing += row.x
		idle += row.y
		cap += row.z
	return "fx_pool activos %d libres %d · hijos %d · tope %d" % [playing, idle, bus.get_node("%Bursts").get_child_count(), cap]


## `wrath_trail_12` -> `wrath_trail`.
static func type_of(emitter: Node) -> String:
	var text := String(emitter.name)
	var cut := text.rfind("_")
	return text.left(cut) if cut > 0 and text.substr(cut + 1).is_valid_int() else text
