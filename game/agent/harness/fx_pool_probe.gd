extends Node

## Read-only (RFC-029 029b playtest): counts FxBus's pool from its children (`<type>_<n>`, visible while
## playing, hidden when idle). Plays nothing, moves no actor, edits no rule. The trail count is printed
## by debug/rock_hit.gd (`fx_trail <n>`); the CPU cost by debug/fx_pool_bench.tscn.
## Flows assert on the properties below (`prop` of /root/AgentKit/fx_pool_probe), never on a node name.

const _POOL := preload("res://debug/fx_pool_count.gd")

## Emitters playing now (visible), all types.
var playing: int:
	get:
		return _sum().x
## Emitters idle now (hidden), all types.
var idle: int:
	get:
		return _sum().y
## Σ caps of the types FxBus holds.
var cap: int:
	get:
		return _sum().z
## Children of FxBus (emitters and anything else).
var children: int:
	get:
		return FxBus.get_child_count()
## Emitters beyond their type's cap, summed over types: 0 = no pool grew past its cap.
var excess: int:
	get:
		var out := 0
		for row: Vector3i in _POOL.by_type(FxBus).values():
			out += maxi(0, row.x + row.y - row.z)
		return out
## Types whose playing count reached their cap since watch_pool() (a live puff may have restarted).
var capped: String:
	get:
		var out := PackedStringArray()
		for type_name: String in _peaks.keys():
			if int(_peaks[type_name]) >= int(_caps.get(type_name, 0)):
				out.append(type_name)
		out.sort()
		return ",".join(out)
## "<type> pico/tope" for every type that played since watch_pool().
var peaks: String:
	get:
		var out := PackedStringArray()
		for type_name: String in _peaks.keys():
			out.append("%s %d/%d" % [type_name, int(_peaks[type_name]), int(_caps.get(type_name, 0))])
		out.sort()
		return " · ".join(out)

var _watch := false
var _peaks: Dictionary = {}
var _caps: Dictionary = {}


## "fx_pool activos n libres m · hijos h · tope t".
func pool() -> String:
	return _POOL.line(FxBus)


## "<type> activos/tope" for one type, e.g. pool_of("spit_trail").
func pool_of(type_name: String) -> String:
	var row: Vector3i = _POOL.by_type(FxBus).get(type_name, Vector3i.ZERO)
	return "%s activos %d libres %d tope %d" % [type_name, row.x, row.y, row.z]


## Starts recording, every frame, the most emitters of each type playing at once (read only).
func watch_pool() -> String:
	_watch = true
	_peaks.clear()
	_caps.clear()
	return "midiendo picos del pool"


func _process(_delta: float) -> void:
	if not _watch:
		return
	var rows := _POOL.by_type(FxBus)
	for type_name: String in rows.keys():
		var row: Vector3i = rows[type_name]
		if row.x <= 0:
			continue
		_peaks[type_name] = maxi(int(_peaks.get(type_name, 0)), row.x)
		_caps[type_name] = row.z


func _sum() -> Vector3i:
	var out := Vector3i.ZERO
	for row: Vector3i in _POOL.by_type(FxBus).values():
		out += row
	return out
