extends SceneTree

## Headless probe for the manafount VFX (RFC-019c): both emitters have an atlas texture, and the fount swaps FreeFx / ManalithFx on occupy() / release() with the occupant's
## tint. Run: Godot --headless --path game --script res://debug/fount_fx_probe.gd

var _failed := false


func _initialize() -> void:
	var fount: Node3D = load("res://scenes/world/props/manafount.tscn").instantiate()
	root.add_child(fount)
	var occupant := Node3D.new()
	occupant.name = "Manalith"
	occupant.set_script(_slot_script())
	occupant.set("owner_slot", 2)
	root.add_child(occupant)
	await process_frame
	var free_fx: SpriteEmitter = fount.get_node("%FreeFx")
	var column_fx: SpriteEmitter = fount.get_node("%ManalithFx")
	_check("FreeFx y ManalithFx con atlas", free_fx.type.atlas != null and column_fx.type.atlas != null)
	_check("libre: FreeFx on, ManalithFx off", free_fx.is_active() and not column_fx.is_active())
	_check("occupy ok", fount.occupy(occupant.get_path()))
	_check("ocupado: FreeFx off, ManalithFx on", not free_fx.is_active() and column_fx.is_active())
	var expected := SideColors.mana_color(2)
	_check("columna teñida con el slot 2", column_fx.tint.is_equal_approx(Color(expected.r, expected.g, expected.b, expected.a)))
	fount.release(occupant.get_path())
	_check("release: vuelve el chorro", free_fx.is_active() and not column_fx.is_active())
	occupant.queue_free()
	fount.queue_free()
	await process_frame
	print("RESULT ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)


func _slot_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar owner_slot := 0\n"
	script.reload()
	return script


func _check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok:
		_failed = true
