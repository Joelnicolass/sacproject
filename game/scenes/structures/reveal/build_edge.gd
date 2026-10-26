class_name BuildEdge
extends Node3D

## The rising edge of a tower being cast: this node rides the cut line of `reveal` (in the middle of its glowing band), its
## `rings` child throws flat blue rings while the tower rises and its `light` child grows with `build_progress` along
## `energy_curve`. The rings stop a little before the end (`rings_until_progress`); when the tower stands the light fades out
## in `fade_out_s`. A tower that was already standing when it appeared (late join, placed by hand) shows neither.
## Does not mark the start, the end or the cut (BuildCues), nor tint by side, nor change the match. A headless process does
## nothing (the light frees itself there).
## Ref: state.d:15237-15244 (BlueRing: rings in the band of the cut, none in the last 0.5 s).

@export var tower: CastTower
@export var reveal: BuildReveal
@export var rings: SpriteEmitter
@export var light: ActorLight
## Share of the light's energy (y) over the progress (x): it starts dim and ends full.
@export var energy_curve: Curve
## The rings are on from this progress...
@export_range(0.0, 1.0, 0.001) var rings_from_progress := 0.01
## ...up to this one (0.955 of an 11.1 s Manalith = the last 0.5 s without rings).
@export_range(0.0, 1.0, 0.001) var rings_until_progress := 0.955
## Seconds the light takes to go out when the tower stands.
@export_range(0.0, 5.0, 0.05, "suffix:s") var fade_out_s := 1.0
## Seconds a tower seen standing from the start is watched (its progress may arrive a moment later) before this node rests.
@export var settle_s := 2.0

var _seen_rising := false
var _standing_s := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tower == null:
		warnings.append("Asigná `tower` (la raíz de la torre, un CastTower).")
	if reveal == null:
		warnings.append("Asigná `reveal` (el BuildReveal de la torre: da la altura de la línea).")
	if rings == null:
		warnings.append("Asigná `rings` (el SpriteEmitter EdgeRings con data/fx/build_edge_ring.tres).")
	if light == null:
		warnings.append("Asigná `light` (el ActorLight EdgeLight).")
	return warnings


func _ready() -> void:
	var on := not Engine.is_editor_hint() and not LookRig.is_presentationless() \
			and tower != null and reveal != null and rings != null and light != null
	set_process(on)
	if on:
		_show_rising(false)


func _process(delta: float) -> void:
	var progress := tower.build_progress
	if progress < 1.0:
		_seen_rising = true
		_standing_s = 0.0
		global_position.y = reveal.line_y() + reveal.edge_width_m * 0.5
		_show_rising(true, progress)
		return
	if _seen_rising:
		_show_rising(false, 1.0, fade_out_s)
		set_process(false)
		return
	_standing_s += delta
	_show_rising(false)
	if _standing_s >= settle_s:
		set_process(false)


## Rising: rings inside their window and the light at curve(progress). Standing: no rings, the light out (over `fade_s`).
func _show_rising(rising: bool, progress := 1.0, fade_s := 0.0) -> void:
	var rings_on := rising and progress >= rings_from_progress and progress < rings_until_progress
	if rings.is_active() != rings_on:
		rings.set_active(rings_on)
	if not is_instance_valid(light):
		return
	if not rising:
		if light.is_lit():
			light.set_lit(false, fade_s)
		return
	if not light.is_lit():
		light.set_lit(true)
	light.set_level(energy_curve.sample(progress) if energy_curve != null else 1.0)
