class_name MpCalls
extends RefCounted

## Calls by name on one node for MpActor: `run("mp_sv_", &"buy", [item])` calls `mp_sv_buy(item)` if that method
## exists and takes that many arguments (defaults counted). Anything else is refused with one warning per name, so
## a client can never call a method that is not an `mp_sv_*` / `mp_all_*` of that node. Not: the network (MpActor).

var _target: Node
var _arity: Dictionary = {}
var _warned: Dictionary = {}


func _init(target: Node) -> void:
	_target = target


func run(prefix: String, action: StringName, args: Array) -> bool:
	var method := prefix + String(action)
	if not accepts(method, args.size()):
		if not _warned.has(method):
			_warned[method] = true
			push_warning("MpActor '%s': no %s() taking %d arguments" % [_target.name, method, args.size()])
		return false
	_target.callv(method, args)
	return true


func accepts(method: String, count: int) -> bool:
	if not _arity.has(method):
		_arity[method] = Vector2i(-1, -1)
		for info in _target.get_method_list():
			if info["name"] == method:
				var total: int = info["args"].size()
				_arity[method] = Vector2i(total - info["default_args"].size(), total)
				break
	var bounds: Vector2i = _arity[method]
	return bounds.x >= 0 and count >= bounds.x and count <= bounds.y
