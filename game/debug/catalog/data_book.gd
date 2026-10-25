extends Control

const _BOOK_GODS: PackedStringArray = ["james", "persephone"]
const _GOD_NAMES := {"james": "James", "persephone": "Persephone"}
const _TROGG := "ycro"
const _ROCK := "kcor"

@onready var _book: Label = %Book


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_show()
		get_viewport().set_input_as_handled()


func _show() -> void:
	if not GameData.is_loaded():
		_book.text = "Faltan los datos: corré tools/import/export_stats.py"
		print(_book.text)
		return
	var lines := PackedStringArray()
	for god in _BOOK_GODS:
		lines.append(_book_line(god))
	lines.append(_trogg_line())
	lines.append(_rock_line())
	lines.append(_wizards_line())
	_book.text = "\n".join(lines)
	print(_book.text)


func _book_line(god: String) -> String:
	var book := GameData.book(god)
	var creatures := PackedStringArray()
	for type in book["creatures"]:
		creatures.append(type.display_name)
	var spells := PackedStringArray()
	for type in book["spells"]:
		spells.append(type.display_name)
	return "%s: %s / %s" % [_GOD_NAMES.get(god, god), ", ".join(creatures), ", ".join(spells)]


func _trogg_line() -> String:
	var trogg := GameData.creature(_TROGG)
	if trogg == null:
		return "Trogg: sin datos"
	var souls := "alma" if trogg.souls == 1 else "almas"
	return "%s %d vida %s m/s %d %s" % [trogg.display_name, trogg.health, _number(trogg.run_speed_m_s), trogg.souls, souls]


func _rock_line() -> String:
	var rock := GameData.spell(_ROCK)
	if rock == null:
		return "Rock: sin datos"
	return "%s %d maná alcance %s cooldown %s s" % [rock.display_name, rock.mana_cost, _number(rock.cast_range_m), _number(rock.cooldown_s)]


func _wizards_line() -> String:
	var names := PackedStringArray()
	for wizard in GameData.wizards():
		names.append(wizard.display_name)
	return "%d magos: %s" % [names.size(), ", ".join(names)]


func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.01))
