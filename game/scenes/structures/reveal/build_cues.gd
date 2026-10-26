class_name BuildCues
extends Node

## The three moments of a tower being cast, each a list of effects (ParticleType: look, light, sound, camera shake) played on
## this peer only:
## - start: the tower appears still at the bottom (`build_progress` <= `start_max_progress` on its first frame), at `spot`;
## - done: the progress reaches 1 after this peer saw it rise, at `spot`;
## - cut: the tower goes away still rising while the match goes on (the cast was cut), at the cut line of `reveal`.
## A tower that appears already high (late join) shows no start; one already standing shows nothing. Leaving the match (the
## scene going away) shows no cut. Everything comes from the replicated progress, the spawn and the despawn: no RPC.
## Does not decide when a tower rises or is cut (StructureAction), nor draw the rise (BuildReveal, BuildEdge). A headless
## process does nothing.

signal start_shown(at: Vector3)
signal done_shown(at: Vector3)
## Emitted when the tower leaves still rising; the effects themselves wait one frame to know the match goes on.
signal cut_shown(at: Vector3)

@export var tower: CastTower
@export var reveal: BuildReveal
## Where the start and the end are born (the base of the tower).
@export var spot: Marker3D
@export var start_fx: Array[ParticleType] = []
@export var done_fx: Array[ParticleType] = []
@export var cut_fx: Array[ParticleType] = []
## A tower whose first frame is above this progress was already rising before this peer saw it: no start.
@export_range(0.0, 1.0, 0.01) var start_max_progress := 0.05

var _seen_rising := false
var _done := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tower == null:
		warnings.append("Asigná `tower` (la raíz de la torre, un CastTower).")
	if reveal == null:
		warnings.append("Asigná `reveal` (el BuildReveal: el corte nace en su línea).")
	if spot == null:
		warnings.append("Asigná `spot` (el Marker3D BaseSpot donde nacen el inicio y el final).")
	return warnings


func _ready() -> void:
	var on := not Engine.is_editor_hint() and not LookRig.is_presentationless() \
			and tower != null and reveal != null and spot != null
	set_process(on)
	if on:
		tower.build_progress_changed.connect(_on_progress)
		tower.tree_exiting.connect(_on_tower_leaving)


## First frame only: a tower at the bottom is a start this peer sees.
func _process(_delta: float) -> void:
	set_process(false)
	if tower.is_rising():
		_seen_rising = true
		if tower.build_progress <= start_max_progress:
			_play(start_fx, spot.global_position)
			start_shown.emit(spot.global_position)


func _on_progress(progress: float) -> void:
	if progress < 1.0:
		_seen_rising = true
	elif _seen_rising and not _done:
		_done = true
		_play(done_fx, spot.global_position)
		done_shown.emit(spot.global_position)


func _on_tower_leaving() -> void:
	if not _seen_rising or _done or not tower.is_rising():
		return
	var at := spot.global_position
	at.y = maxf(at.y, reveal.line_y())
	cut_shown.emit(at)
	# This node leaves with the tower: the check runs on the script, a frame later, when a despawn and a scene going away differ.
	Callable(BuildCues, &"_play_if_alive").call_deferred(cut_fx, at, tower.get_parent())


## The cut plays only if the place the tower lived in is still in the tree (it was despawned, the match goes on).
static func _play_if_alive(effects: Array[ParticleType], at: Vector3, home: Node) -> void:
	if is_instance_valid(home) and home.is_inside_tree():
		_play(effects, at)


static func _play(effects: Array[ParticleType], at: Vector3) -> void:
	for fx in effects:
		if fx != null:
			FxBus.play(fx, at)
