class_name GroundHugFlight
extends ShotInFlight

## The Rhinok's Spikey Death (hrba) runs along the ground: on every update the shot moves and its height is then put on
## the top of the land or of a building under it. RangedShot moves the shot and calls fly() before
## it checks its hit, so this node puts the shot back on that height in the same tick (+ `lift`) and the 5 m box
## (ShotLook.hit_size, rhinokProjectileSize) looks for its body there. This node owns the shot's height
## (holds_height): RangedShot does not burst it on the ground, it ends on a body or at the end of its range.
## The velocity is not touched: the shot counts its range by the same step as the original's remainingDistance.
## The spikes it raises on its way (movingSpikeRate 3 per update in a disk of movingRange 2.5 m, Spike effects)
## are presentation: one SpikeField event (FxBus.broadcast_scene) every `spike_every_s` with
## 3 · that many spikes, on every peer.
## Deviation (declared): it flies `lift` m over the ground (the original: on it); off the map it keeps its height.
## Ref: F151 (RFC-030 030n-b), sacengine updateRhinokProjectile state.d:24963-24974, rhinokProjectileSize 24933, 24961-24978, spikes 25017-25022.

## Meters over the ground (land or building top).
@export var lift := 0.05
## The spikes along the way: spike_field.tscn (an FxScene) played by FxBus on every peer (empty: none).
@export var spike_scene: PackedScene
## One event every this long of flight (0: none).
@export_range(0.0, 1.0, 0.0001, "suffix:s") var spike_every_s := 0.1
## Spikes per tick of flight (movingSpikeRate).
@export var spikes_per_tick := 3
## The disk around the shot where a spike rises (m) (movingRange).
@export var spike_radius := 2.5
## Height of each spike placed on the way.
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
	var spike_every_ticks := MatchClock.ticks_for(spike_every_s)
	if spike_scene != null and spike_every_ticks > 0 and (ticks - 1) % spike_every_ticks == 0:
		FxBus.broadcast_scene(spike_scene, shot.global_position, {
			"inner": 0.0, "outer": spike_radius, "count": spikes_per_tick * spike_every_ticks, "height": spike_height,
			"seed": MatchSeed.derive(["spikes", String(shot.name), MatchClock.now()])})
