class_name MpProcessRunnerStub
extends MpProcessRunner

## Simulated processes for tests without Godot. Pids are fake and start at `first_pid`.

@export var first_pid: int = 100000
## 0 = never exits by itself.
@export var lifetime_s: float = 0.0
@export var spawn_fails: bool = false
@export var fake_own_pid: int = 99999

var spawned: Array[Dictionary] = []
var killed: Array[int] = []
var _next_pid: int = 0
var _alive: Dictionary = {}


func spawn(executable: String, args: PackedStringArray) -> int:
	if spawn_fails:
		return -1
	if _next_pid == 0:
		_next_pid = first_pid
	var pid := _next_pid
	_next_pid += 1
	_alive[pid] = Time.get_ticks_msec()
	spawned.append({"pid": pid, "executable": executable, "args": args})
	return pid


func is_running(pid: int) -> bool:
	if not _alive.has(pid):
		return false
	if lifetime_s > 0.0 and (Time.get_ticks_msec() - int(_alive[pid])) / 1000.0 >= lifetime_s:
		_alive.erase(pid)
		return false
	return true


func kill(pid: int) -> void:
	killed.append(pid)
	_alive.erase(pid)


func own_pid() -> int:
	return fake_own_pid
