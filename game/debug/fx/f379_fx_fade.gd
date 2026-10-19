extends Node3D

## RFC-053 053i (F379): the effects end with a fade, not a cut. Runs headless (FxLightLayer and ParticleType do not need a
## window; the sprites themselves never draw headless). Prints `FX_FADE <case> PASS|FAIL ...` and `FX_FADE PASS|FAIL`.
##   spark      a short spark (rock_spark, decay 0.2 s) lights for attack + FxLightLayer.min_decay_s, falling all the way.
##   hand_off   the same source plays again elsewhere: its old light fades out in fade_out_s (energy only goes down), then hides.
##   quality    the cap drops from 8 to 1 with 3 lights on: 2 fade out (none cut) and are dark after fade_out_s.
##   bursts     every burst type of data/fx (rate_per_s 0) ends at alpha 0 (ParticleType.alpha_ramp with SpriteParticles'
##              tail_fade_s); prints how many ended at full alpha before (no tail).
##   freed      the layer freed after all that: gone the next frame, no orphan nodes left.
## A wall watchdog quits with 1 after `watchdog_s`. With a window: same, it quits at the end with `-- --quit`.

@export var strong: FxLightSpec
@export var spark: FxLightSpec
@export var sprite_particles: PackedScene
@export var watchdog_s := 20.0

@onready var _layer: FxLightLayer = %FxLight

var _failed := false
var _deadline := 0


func _ready() -> void:
	_deadline = Time.get_ticks_msec() + int(watchdog_s * 1000.0)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _deadline > 0 and Time.get_ticks_msec() > _deadline:
		print("FX_FADE FAIL watchdog")
		get_tree().quit(1)


func _run() -> void:
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_layer.apply_look(LookProfile.new(), null)
	_layer.apply_quality(_quality(8))
	await _spark_case()
	await _hand_off_case()
	await _quality_case()
	_bursts_case()
	await _freed_case(orphans_before)
	_deadline = 0
	print("FX_FADE %s" % ("FAIL" if _failed else "PASS"))
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--quit"):
		get_tree().quit(1 if _failed else 0)


func _spark_case() -> void:
	var source := RefCounted.new()
	_layer.flash(source, spark, Vector3(0.0, 0.0, -5.0))
	var light := _lit_light()
	var lit_s := 0.0
	var peak := 0.0
	var last := 0.0
	var rising := true
	var smooth := true
	while light != null and light.visible and lit_s < 3.0:
		await get_tree().process_frame
		lit_s += get_process_delta_time()
		peak = maxf(peak, light.light_energy)
		if light.light_energy < last:
			rising = false
		elif not rising and light.light_energy > last + 1e-4:
			smooth = false
		last = light.light_energy
	var expected := spark.attack_s + maxf(spark.decay_s, _layer.min_decay_s)
	var ok := light != null and absf(lit_s - expected) <= 0.02 and smooth and peak > 0.0
	_check("spark", ok, "encendida %.3f s (esperado %.3f; antes %.3f) pico %.2f" % [lit_s, expected, spark.total_s(), peak])


func _hand_off_case() -> void:
	var source := RefCounted.new()
	_layer.flash(source, strong, Vector3(0.0, 0.0, -5.0))
	await _frames(30)
	var old := _lit_light()
	var from := old.light_energy if old != null else 0.0
	_layer.flash(source, strong, Vector3(4.0, 0.0, -5.0))
	var fading_s := 0.0
	var monotone := true
	var last := from
	while old != null and old.visible and fading_s < 3.0:
		await get_tree().process_frame
		fading_s += get_process_delta_time()
		if old.light_energy > last + 1e-4:
			monotone = false
		last = old.light_energy
	var ok := old != null and from > 0.0 and absf(fading_s - _layer.fade_out_s) <= 0.02 and monotone and _layer.fading_count() == 0
	_check("hand_off", ok, "se apaga en %.3f s (fade_out_s %.2f; antes 0,10) desde %.2f" % [fading_s, _layer.fade_out_s, from])
	await _settle()


func _quality_case() -> void:
	for i in 3:
		_layer.flash(RefCounted.new(), strong, Vector3(float(i) * 3.0, 0.0, -6.0))
	await _frames(20)
	_layer.apply_quality(_quality(1))
	var fading := _layer.fading_count()
	var active := _layer.active_count()
	await _seconds(_layer.fade_out_s + 0.02)
	var ok := active == 1 and fading == 2 and _layer.fading_count() == 0
	_check("quality", ok, "tope 1: activas %d, fundiendo %d (antes 0: cortadas); a los %.2f s fundiendo %d" % [active, fading, _layer.fade_out_s + 0.02, _layer.fading_count()])
	_layer.apply_quality(_quality(8))
	await _settle()


func _bursts_case() -> void:
	var tail := 0.25
	if sprite_particles != null:
		var probe := sprite_particles.instantiate() as SpriteParticles
		tail = probe.tail_fade_s
		probe.free()
	var types := 0
	var hard_before := 0
	var hard_now := 0
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(FxBus.TYPES_DIR):
		if not file.trim_suffix(".remap").ends_with(".tres"):
			continue
		var type := load(FxBus.TYPES_DIR + file.trim_suffix(".remap")) as ParticleType
		if type == null or type.rate_per_s > 0.0 or type.lifetime_s <= 0.0:
			continue
		types += 1
		if Color(type.alpha_ramp(1.0, 0.0).sample(1.0)).a > 0.01:
			hard_before += 1
		var ramp := type.alpha_ramp(1.0, tail)
		if ramp.sample(1.0).a > 0.01 or ramp.sample(0.0).a < 0.99:
			hard_now += 1
			names.append(type.resource_path.get_file())
	_check("bursts", hard_now == 0 and types > 0, "%d tipos de rafaga; terminaban a alfa plena (sin cola) %d; ahora %d %s (cola %.2f s)" % [
		types, hard_before, hard_now, ", ".join(names), tail])


func _freed_case(orphans_before: int) -> void:
	var layer_ref: WeakRef = weakref(_layer)
	_layer.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("freed", layer_ref.get_ref() == null and orphans <= orphans_before, "capa liberada %s, nodos huerfanos %d (al empezar %d)" % [
		str(layer_ref.get_ref() == null), orphans, orphans_before])


func _lit_light() -> OmniLight3D:
	var lit: OmniLight3D = null
	for child in _layer.get_children():
		if child is OmniLight3D and (child as OmniLight3D).visible:
			lit = child as OmniLight3D
	return lit


func _quality(cap: int) -> LookQuality:
	var quality := LookQuality.new()
	quality.fx_max_lights = cap
	return quality


## Waits until every light of the layer is dark.
func _settle() -> void:
	var waited := 0.0
	while (_layer.active_count() > 0 or _layer.fading_count() > 0) and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _check(tag: String, ok: bool, detail: String) -> void:
	_failed = _failed or not ok
	print("FX_FADE %s %s %s" % [tag, "PASS" if ok else "FAIL", detail])
