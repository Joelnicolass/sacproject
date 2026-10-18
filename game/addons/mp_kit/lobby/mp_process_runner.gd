class_name MpProcessRunner
extends Resource

## Process access for the launcher. Real by default; `MpProcessRunnerStub` simulates it.


func spawn(executable: String, args: PackedStringArray) -> int:
	return OS.create_process(executable, args)


func is_running(pid: int) -> bool:
	return pid_alive(pid)


## Works for any pid, child or not (OS.is_process_running errors on non-children). A zombie is dead.
static func pid_alive(pid: int) -> bool:
	if pid <= 0:
		return false
	if OS.get_name() == "Windows":
		return OS.is_process_running(pid)
	var out: Array = []
	if OS.execute("ps", PackedStringArray(["-o", "stat=", "-p", str(pid)]), out) != 0:
		return false
	var stat := str(out[0]).strip_edges() if not out.is_empty() else ""
	return not stat.is_empty() and not stat.begins_with("Z")


func kill(pid: int) -> void:
	if pid > 0:
		OS.kill(pid)


func own_pid() -> int:
	return OS.get_process_id()
