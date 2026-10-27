class_name MpProcessRunner
extends Resource

## Process access for the launcher. Real by default; `MpProcessRunnerStub` simulates it.
## Pid detection and identity checks read /proc on Linux (there on every Linux, a container's minimal image included,
## where `ps` is often missing) and ask `ps` elsewhere (macOS); on Windows they are best effort (identity is not
## checked).


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
	if _has_proc():
		## "pid (name) S …": the state letter follows the last ")" (a name may hold spaces or parentheses).
		var stat := _read_proc(pid, "stat").get_string_from_utf8()
		var close := stat.rfind(")")
		return close > 0 and stat.length() > close + 2 and stat[close + 2] != "Z"
	var out: Array = []
	if OS.execute("ps", PackedStringArray(["-o", "stat=", "-p", str(pid)]), out) != 0:
		return false
	var stat := str(out[0]).strip_edges() if not out.is_empty() else ""
	return not stat.is_empty() and not stat.begins_with("Z")


## True if the live process command line contains `needle` (guards against a recycled pid).
func command_contains(pid: int, needle: String) -> bool:
	if OS.get_name() == "Windows":
		return is_running(pid)
	if _has_proc():
		## The arguments, separated by NUL bytes.
		var raw := _read_proc(pid, "cmdline")
		for i in raw.size():
			if raw[i] == 0:
				raw[i] = 32
		return raw.get_string_from_utf8().contains(needle)
	var out: Array = []
	if OS.execute("ps", PackedStringArray(["-o", "command=", "-p", str(pid)]), out) != 0 or out.is_empty():
		return false
	return str(out[0]).contains(needle)


func kill(pid: int) -> void:
	if pid > 0:
		OS.kill(pid)


func own_pid() -> int:
	return OS.get_process_id()


static func _has_proc() -> bool:
	return OS.get_name() == "Linux" and DirAccess.dir_exists_absolute("/proc/self")


## A /proc/<pid>/ file (their size reads 0, so this reads what is there). Empty when the process is gone.
static func _read_proc(pid: int, file: String) -> PackedByteArray:
	var f := FileAccess.open("/proc/%d/%s" % [pid, file], FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var out := f.get_buffer(65536)
	f.close()
	return out
