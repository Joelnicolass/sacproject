class_name AgentLogSink
extends Logger

## Collects engine errors while `--agent=` runs. Do not print() here (recursion).

const TYPE_ERROR := 0
const TYPE_WARNING := 1
const TYPE_SCRIPT := 2
const TYPE_SHADER := 3

static var active: AgentLogSink

var _mutex := Mutex.new()
var records: Array = []


func mark() -> int:
	_mutex.lock()
	var n: int = records.size()
	_mutex.unlock()
	return n


func since(from: int) -> Array:
	_mutex.lock()
	var out: Array = records.slice(from)
	_mutex.unlock()
	return out


func snapshot() -> Array:
	_mutex.lock()
	var out: Array = records.duplicate(true)
	_mutex.unlock()
	return out


func has_failures() -> bool:
	for rec in snapshot():
		if is_failure(rec):
			return true
	return false


static func is_failure(rec: Dictionary) -> bool:
	if bool(rec.get("stderr", false)):
		return true
	var error_type := int(rec.get("error_type", -1))
	return (
		error_type == TYPE_ERROR
		or error_type == TYPE_SCRIPT
		or error_type == TYPE_SHADER
	)


func _log_message(message: String, error: bool) -> void:
	if not error:
		return
	_mutex.lock()
	records.append({
		"stderr": true,
		"error_type": TYPE_ERROR,
		"kind": "stderr",
		"text": message.strip_edges(),
	})
	_mutex.unlock()


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	var kind := "error"
	match error_type:
		TYPE_WARNING:
			kind = "warning"
		TYPE_SCRIPT:
			kind = "script"
		TYPE_SHADER:
			kind = "shader"
	var text := rationale if not rationale.strip_edges().is_empty() else code
	_mutex.lock()
	records.append({
		"stderr": false,
		"error_type": error_type,
		"kind": kind,
		"function": function,
		"file": file,
		"line": line,
		"code": code,
		"rationale": rationale,
		"text": "%s:%d %s" % [file, line, text],
	})
	_mutex.unlock()
