extends Node3D

## Self-test of the determinism module: bodies in a box, a fixed seed, a sample every few ticks.
## Same seed, same digest, in every mode of det_run.sh. Options after `--`:
##   --seed=N   (default 1)   --ticks=N (default 600)   --sample-every=N (default 30)   --bodies=N (default 20)
##   --break    compile a script with a syntax error, then idle (the runner must kill the run: script_error_kill)

@export var recorder: DetRecorder
@export var body_count := 20

var _bodies: Array[RigidBody3D] = []
var _args := {}
var _max_ticks := 600
var _sample_every := 30
var _done := false


func _ready() -> void:
	_args = DetCli.args()
	if _args.has("break"):
		var broken := GDScript.new()
		broken.source_code = "func broken(:\n\tpass\n"
		broken.reload()
		return  # idle: only the watchdog of the runner ends this run
	_max_ticks = int(_args.get("ticks", _max_ticks))
	_sample_every = maxi(1, int(_args.get("sample-every", _sample_every)))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_args.get("seed", 1))
	for i in int(_args.get("bodies", body_count)):
		var body := RigidBody3D.new()
		body.name = "Body%02d" % i
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.4
		shape.shape = sphere
		body.add_child(shape)
		add_child(body)
		body.position = Vector3(rng.randf_range(-3.0, 3.0), 1.0 + float(i) * 0.9, rng.randf_range(-3.0, 3.0))
		body.linear_velocity = Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
		_bodies.append(body)
	recorder.keep_lines = not DetCli.events_path().is_empty()
	recorder.start()


func _physics_process(_delta: float) -> void:
	if _done or not recorder.running:
		return
	recorder.advance()
	if recorder.tick % _sample_every == 0:
		recorder.sample(_bodies)
	if recorder.tick >= _max_ticks:
		_done = true
		recorder.stop()
		recorder.write_outputs({"seed": int(_args.get("seed", 1)), "bodies": _bodies.size()})
		get_tree().quit()
