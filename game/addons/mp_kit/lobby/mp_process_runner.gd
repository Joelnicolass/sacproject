class_name MpProcessRunner
extends Resource

## Process access for the launcher. Real by default; `MpProcessRunnerStub` simulates it.


func spawn(executable: String, args: PackedStringArray) -> int:
	return OS.create_process(executable, args)


func is_running(pid: int) -> bool:
	return pid > 0 and OS.is_process_running(pid)


func kill(pid: int) -> void:
	if pid > 0:
		OS.kill(pid)


func own_pid() -> int:
	return OS.get_process_id()
