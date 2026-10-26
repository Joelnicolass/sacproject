extends RefCounted

## RFC-057 057z network cases of terrain_cases (criterion 9), in one process. A match is never joined half way: the only peer that
## arrives in the middle is a seat that dropped and rejoins within its grace time, with a fresh ground. Three cases:
## - net_inflight: the server keeps one more change while the seat loads; its RPC reaches the seat before the snapshot (which the
##   server takes after it) and the seat ends with the server's checksum and rev, in either order of arrival;
## - net_rejoin_mid_volcano: the seat rejoins 20 s into a Volcano: it loads the snapshot and gets the zone's stamps with the
##   server's synced_ticks and pattern (what the zone's synchronizer carries); its ticks stay within resync_ticks of the server's and
##   its ground at the center within TOLERANCE_M (plus the redraw step of Live, see below) of the server's, and the checksum is equal;
## - net_quake_client: a client gets the copy of the Quake's ground in quake_ring.tscn: its two stamps play there while it lasts and
##   the server's ground is not touched.
## A seat is a bed of High Noon whose branch runs a client's MultiplayerAPI (SeatPeer: never connected to anything, peer id 2), so its
## Terrain is not the authority, as on a real client. It goes first among the children of the world, so Terrain.of of a node inside
## it finds its ground (the stamps ask Terrain.of in _ready, as in a client process with one ground); the server's zone and its
## stamps were born before, with the suite's ground. While a seat lives (3 s), what the server's zone asks Terrain.of each tick
## (where a lava ball lands) reads the seat's ground, which mirrors the server's. Every bed is freed at once when its case ends. It borrows the world of TerrainCases (`cases`).
## Ref: RFC-057 057z; RFC-034 034g (rejoin_grace_s).

const BED := preload("res://debug/map/terrain_bed.tscn")
const RING := preload("res://scenes/fx/quake_ring.tscn")
const CENTER := Vector2(1260.0, 1270.0)
const REJOIN_S := 20.0
const WATCH_S := 3.0
## Each peer redraws a slow stamp only when it moved by its Live's min_step_m, at its own moment: the gap allowed between two peers
## is this plus that step.
const TOLERANCE_M := 0.05
const VOLCANO_STAMPS: Array[String] = ["Mound", "Crater"]
## The Quake's stamps last 0.5 s (30 ticks); a client must show both on nearly every one of them.
const QUAKE_TICKS_WITH_TWO := 25

var _c


## A client's end of a network that never connects: peer 2, connected, no packets. Only so a branch of the tree is not the server.
class SeatPeer extends MultiplayerPeerExtension:
	func _get_unique_id() -> int: return 2
	func _is_server() -> bool: return false
	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus: return MultiplayerPeer.CONNECTION_CONNECTED
	func _poll() -> void: pass
	func _close() -> void: pass
	func _disconnect_peer(_peer: int, _force: bool) -> void: pass
	func _get_available_packet_count() -> int: return 0
	func _get_max_packet_size() -> int: return 1 << 16
	func _get_packet_script() -> PackedByteArray: return PackedByteArray()
	func _put_packet_script(_buffer: PackedByteArray) -> Error: return OK
	func _get_packet_peer() -> int: return 1
	func _get_packet_channel() -> int: return 0
	func _get_packet_mode() -> MultiplayerPeer.TransferMode: return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	func _set_transfer_channel(_channel: int) -> void: pass
	func _get_transfer_channel() -> int: return 0
	func _set_transfer_mode(_mode: MultiplayerPeer.TransferMode) -> void: pass
	func _get_transfer_mode() -> MultiplayerPeer.TransferMode: return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	func _set_target_peer(_peer: int) -> void: pass
	func _is_server_relay_supported() -> bool: return false
	func _set_refuse_new_connections(_enable: bool) -> void: pass
	func _is_refusing_new_connections() -> bool: return true


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"net_inflight": _inflight, "net_rejoin_mid_volcano": _rejoin_mid_volcano, "net_quake_client": _quake_client}


## Server and two rejoining seats (beds driven through their Net the way the RPC drives them): one more kept change in flight
## while the seats load, the snapshot taken after it.
func _inflight() -> Dictionary:
	var checks := {}
	var server := BED.instantiate() as Node3D
	var seats: Array[Node3D] = [BED.instantiate() as Node3D, BED.instantiate() as Node3D]
	for bed: Node3D in [server, seats[0], seats[1]]:
		_c._root.add_child(bed)
	await _c._frames(2)
	var host := server.get_node("Terrain") as Terrain
	var rect := TerrainGrid.vertex_rect(CENTER, 35.0)
	_c._keep(host, CENTER, 35.0, _numbers(rect.get_area(), 2.0))
	checks["hole_cut"] = host.cut_hole(CENTER + Vector2(0.0, 30.0)).size() == 1
	# The seats dropped and come back with a fresh ground. Meanwhile the server keeps one more: its RPC leaves first...
	var late_at := CENTER + Vector2(60.0, 0.0)
	var late_rect := TerrainGrid.vertex_rect(late_at, 20.0)
	var late := _numbers(late_rect.get_area(), -1.0)
	_c._keep(host, late_at, 20.0, late)
	var rev := host.field().rev
	# ...and the snapshot is taken after it.
	var snapshot := {TerrainNet.SNAPSHOT_KEY: host.field().to_snapshot()}
	var truth := host.field()
	var first := seats[0].get_node("Terrain/Net") as TerrainNet
	var first_ground := seats[0].get_node("Terrain") as Terrain
	first.rpc_commit(rev, "", late_rect, late)
	checks["rpc_alone_misses_the_rest"] = first_ground.field().checksum() != truth.checksum()
	first._on_snapshot(snapshot)
	checks["rpc_then_snapshot_same"] = first_ground.field().checksum() == truth.checksum() and first_ground.field().rev == truth.rev
	var second := seats[1].get_node("Terrain/Net") as TerrainNet
	var second_ground := seats[1].get_node("Terrain") as Terrain
	second._on_snapshot(snapshot)
	second.rpc_commit(rev, "", late_rect, late)
	checks["snapshot_then_rpc_same"] = second_ground.field().checksum() == truth.checksum() and second_ground.field().rev == truth.rev
	var more := PackedFloat32Array([0.5])
	_c._keep(host, TerrainGrid.point_of(rect.position), 0.0, more)
	for seat: TerrainNet in [first, second]:
		seat.rpc_commit(truth.rev, "", Rect2i(rect.position, Vector2i.ONE), more)
	checks["both_follow_after"] = first_ground.field().checksum() == truth.checksum() and second_ground.field().checksum() == truth.checksum()
	_c._note("net inflight crc/rev", [truth.checksum(), truth.rev])
	for bed: Node3D in [server, seats[0], seats[1]]:
		_c._root.remove_child(bed)
		bed.free()
	return _c._verdict("net_inflight", checks)


## Volcano on the suite's ground (the server); 20 s in, a seat rejoins and plays its stamps from the server's count.
func _rejoin_mid_volcano() -> Dictionary:
	var checks := {}
	var server: Terrain = _c._shape
	var wizard: Node3D = _c._wizard(1, _c._far_wizard_spot(), "pyro", 8)
	var zone: GroundZone = _c._volcano(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	while mound.ticks < MatchClock.ticks_for(REJOIN_S):
		await _c._frames(1)
	var seat := await _seat()
	var ground := seat.get_node("Terrain") as Terrain
	(seat.get_node("Terrain/Net") as TerrainNet)._on_snapshot({TerrainNet.SNAPSHOT_KEY: server.field().to_snapshot()})
	var holder := Node3D.new()
	holder.name = "Volcano"
	seat.add_child(holder)
	holder.global_transform = zone.global_transform
	checks["seat_is_a_client"] = not ground.is_authority()
	checks["seat_ground_first"] = Terrain.of(holder) == ground
	var pairs := _copy_stamps(_c._spawner.zones["Volcano"] as PackedScene, zone, holder)
	var copy := pairs[0][1] as TerrainStamp
	var center := mound.center()
	var id := TerrainGrid.vertex_id(center.x, center.y)
	var allowed_m: float = TOLERANCE_M + ground.live.min_step_m
	var worst_ticks := 0
	var worst_m := 0.0
	for tick in MatchClock.ticks_for(WATCH_S):
		for pair: Array in pairs:
			(pair[1] as TerrainStamp).synced_ticks = (pair[0] as TerrainStamp).synced_ticks
		await _c._frames(1)
		if tick < 2:
			continue
		worst_ticks = maxi(worst_ticks, absi(copy.ticks - mound.ticks))
		worst_m = maxf(worst_m, absf(ground.field().at(id) - server.field().at(id)))
	_c._note("rejoin: worst ticks / worst m (allowed) / center seat, server / live seat, server", [worst_ticks, worst_m, allowed_m,
		ground.field().at(id), server.field().at(id), ground.field().live_count(), server.field().live_count()])
	checks["ticks_within_resync"] = worst_ticks <= copy.resync_ticks
	checks["center_within_tolerance"] = worst_m <= allowed_m
	checks["mound_plays_on_the_seat"] = ground.field().live_count() == 1 and server.field().live_count() == 1
	checks["checksum_same"] = ground.field().checksum() == server.field().checksum() and ground.field().rev == server.field().rev
	_drop(seat)
	zone.queue_free()
	wizard.queue_free()
	await _c._frames(2)
	return _c._verdict("net_rejoin_mid_volcano", checks)


## The copy of a Quake's ground (quake_ring.tscn, as FxBus places it on a client) on a seat: two keys while it lasts, none after.
func _quake_client() -> Dictionary:
	var checks := {}
	var server: Terrain = _c._shape
	var seat := await _seat()
	var ground := seat.get_node("Terrain") as Terrain
	var ring := RING.instantiate() as QuakeRing
	ring.get_node("Sound").free()
	ring.position = Vector3(CENTER.x, ground.height_at(CENTER.x, CENTER.y), CENTER.y)
	seat.add_child(ring)
	checks["seat_is_a_client"] = not ground.is_authority()
	checks["seat_ground_first"] = Terrain.of(ring) == ground
	var server_keys := server.field().live_count()
	var server_rev := server.field().rev
	var most := 0
	var with_two := 0
	var server_touched := false
	for _i in 40:
		await _c._frames(1)
		var keys := ground.field().live_count()
		most = maxi(most, keys)
		with_two += 1 if keys == 2 else 0
		server_touched = server_touched or server.field().live_count() != server_keys
	_c._note("quake on a client: most keys / ticks with two / left", [most, with_two, ground.field().live_count()])
	checks["two_keys_while_it_lasts"] = most == 2 and with_two >= QUAKE_TICKS_WITH_TWO
	checks["over_after_it"] = ground.field().live_count() == 0
	checks["server_untouched"] = not server_touched and server.field().rev == server_rev
	ring.free()
	_drop(seat)
	return _c._verdict("net_quake_client", checks)


## A fresh bed of High Noon whose branch runs a client's MultiplayerAPI, first among the children of the world.
func _seat() -> Node3D:
	var seat := BED.instantiate() as Node3D
	seat.name = "Seat"
	var api := SceneMultiplayer.new()
	api.multiplayer_peer = SeatPeer.new()
	_c._host.get_tree().set_multiplayer(api, _seat_path())
	_c._root.add_child(seat)
	_c._root.move_child(seat, 0)
	await _c._frames(2)
	return seat


func _drop(seat: Node3D) -> void:
	_c._root.remove_child(seat)
	seat.free()
	_c._host.get_tree().set_multiplayer(null, _seat_path())


func _seat_path() -> NodePath:
	return NodePath(str(_c._root.get_path()) + "/Seat")


## The stamps of a fresh copy of `scene` (the one `zone` was made from) under `holder`, with the server's synced_ticks and pattern, as the zone's
## synchronizer brings them on the spawn. [[server stamp, seat stamp], ...]; the rest of the copy is freed.
func _copy_stamps(scene: PackedScene, zone: GroundZone, holder: Node3D) -> Array:
	var copy := scene.instantiate()
	var pairs := []
	for path in VOLCANO_STAMPS:
		var real := zone.get_node(path) as TerrainStamp
		var stamp := copy.get_node(path) as TerrainStamp
		copy.remove_child(stamp)
		stamp.owner = null
		stamp.synced_ticks = real.synced_ticks
		stamp.pattern = real.pattern.duplicate()
		holder.add_child(stamp)
		pairs.append([real, stamp])
	copy.free()
	return pairs


static func _numbers(count: int, base: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	for k in count:
		out[k] = base + sin(float(k))
	return out
