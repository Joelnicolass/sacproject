class_name GroundHug
extends ShotInFlight

## F151 (RFC-030 030n-b): the Rhinok's Spikey Death (hrba) runs along the ground, sacengine updateRhinokProjectile,
## phase moving (state.d:24963-24974): on every update position += speed/60 · direction and then position.z =
## getHeight(position), the top of the land or of a building under it. RangedShot moves the shot and calls fly() before
## it checks its hit, so this node puts the shot back on that height in the same tick (+ `lift`) and the 5 m box
## (ShotLook.hit_size, rhinokProjectileSize, 24933) looks for its body there. This node owns the shot's height
## (holds_height): RangedShot does not burst it on the ground, it ends on a body or at the end of its range (24961-24978).
## The velocity is not touched: the shot counts its range by the same step as sacengine's remainingDistance.
## The spikes it raises on its way (movingSpikeRate 3 per update in a disk of movingRange 2.5 m, Spike effects,
## 25017-25022) are presentation: one SpikeField event (FxBus.broadcast_scene) every `spike_every_ticks` ticks with
## 3 · that many spikes, on every peer.
## Deviation (declared): it flies `lift` m over the ground (sacengine: on it); off the map it keeps its height.

## Meters over the ground (land or building top).
@export var lift := 0.05
## The spikes along the way: SpikeField scene played by FxBus on every peer (empty: none).
@export_file("*.tscn") var spike_scene := "res://scenes/fx/spike_field.tscn"
## One event every this many ticks of flight (0: none).
@export_range(0, 60) var spike_every_ticks := 6
## sacengine movingSpikeRate: spikes per tick of flight.
@export var spikes_per_tick := 3
## sacengine movingRange: the disk around the shot where a spike rises (m).
@export var spike_radius := 2.5
## sacengine placeSpike(…, 2.0) on the way.
@export var spike_height := 2.0


func holds_height() -> bool:
	return true


func _fly(shot: RangedShot, at: Vector3) -> void:
	var ground := shot.ground_height(at)
	if ground > -INF:
		shot.global_position.y = ground + lift
	if DebugLog.on(&"flight"):
		var now := shot.global_position
		print("pegado %s tick %d en (%.3f, %.3f, %.3f) suelo %s (cuadro %d)" % [shot.name, ticks, now.x, now.y, now.z,
			"%.3f" % ground if ground > -INF else "ninguno", MatchClock.now()])
	if not spike_scene.is_empty() and spike_every_ticks > 0 and (ticks - 1) % spike_every_ticks == 0:
		FxBus.broadcast_scene(spike_scene, shot.global_position, {
			"inner": 0.0, "outer": spike_radius, "count": spikes_per_tick * spike_every_ticks, "height": spike_height,
			"seed": MatchSeed.derive(["spikes", String(shot.name), MatchClock.now()])})
