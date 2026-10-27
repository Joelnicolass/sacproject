extends RefCounted

## RFC-055e e4 cases of rules_suite: the book of a wizard. Without an override he casts from the book of his god at his
## level; with `WizardBody.book` he casts from that one; clearing it goes back; the book is built once per change; and
## `GodBook.level_of` finds a spell by the resource itself. No network: the server paths run as solo.

const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const MIXED_BOOK := preload("res://debug/spells/mixed_book.tres")
const MIXED_TAGS: Array[String] = ["kcor", "laeh", "niks", "zerf"]

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "BookCases"
	_host.add_child(_root)
	var out := {}
	out["book_god_level3"] = await _god_book()
	out["book_override"] = await _override()
	out["book_cleared"] = await _cleared()
	out["book_rebuild_once"] = await _rebuild_once()
	out["book_level_of"] = _level_of()
	_root.queue_free()
	## rules_suite reads `ok`: a case passes when every one of its checks holds.
	for key: String in out:
		var checks: Dictionary = out[key]
		var ok := true
		for check: String in checks:
			ok = ok and bool(checks[check])
		checks["ok"] = ok
	return out


## No override: the book of Pyro at level 3 is what GodBook.up_to says for that level.
func _god_book() -> Dictionary:
	var checks := {}
	var wizard := await _wizard("pyro", 3)
	var book := wizard.get_node("Spellbook") as Spellbook
	var expected := GameData.book("pyro", 3)
	var in_book := _tags_of(book)
	var wanted := _tags(expected["spells"])
	in_book.sort()
	wanted.sort()
	checks["wired"] = book.wizard == wizard
	checks["is_gods_book"] = book.current_book() == wizard.god_type.book
	checks["spells"] = in_book == wanted
	checks["structures"] = book.structure_count() == (expected["structures"] as Array).size()
	checks["creatures"] = book.creature_count() == (expected["creatures"] as Array).size()
	checks["no_rock"] = book.spell_by_tag("kcor") == null
	wizard.queue_free()
	return checks


## With the mixed book: its four spells and its tower, nothing of Pyro's.
func _override() -> Dictionary:
	var checks := {}
	var wizard := await _wizard("pyro", 3)
	var book := wizard.get_node("Spellbook") as Spellbook
	wizard.book = MIXED_BOOK
	checks["current_is_override"] = book.current_book() == MIXED_BOOK
	var tags := _tags_of(book)
	tags.sort()
	checks["four_spells"] = tags == MIXED_TAGS
	checks["tower"] = book.structure_count() == 1 and book.structure_at(0).tag == "htlm"
	checks["no_creatures"] = book.creature_count() == 0
	checks["no_fireball"] = book.spell_by_tag("brif") == null
	checks["sorted_by_order"] = _sorted_by_order(book)
	wizard.queue_free()
	return checks


## Clearing the override goes back to the book of the god.
func _cleared() -> Dictionary:
	var checks := {}
	var wizard := await _wizard("pyro", 3)
	var book := wizard.get_node("Spellbook") as Spellbook
	var before := _tags_of(book)
	wizard.book = MIXED_BOOK
	wizard.book = null
	checks["back_to_god"] = _tags_of(book) == before and book.current_book() == wizard.god_type.book
	wizard.queue_free()
	return checks


## One change of book, one rebuild; the same book again does nothing.
func _rebuild_once() -> Dictionary:
	var checks := {}
	var wizard := await _wizard("pyro", 3)
	var book := wizard.get_node("Spellbook") as Spellbook
	var counter := [0]
	book.book_changed.connect(func() -> void: counter[0] += 1)
	wizard.book = MIXED_BOOK
	checks["one_rebuild"] = counter[0] == 1
	wizard.book = MIXED_BOOK
	checks["same_book_nothing"] = counter[0] == 1
	wizard.level = 4
	checks["level_rebuilds"] = counter[0] == 2
	wizard.queue_free()
	return checks


## `level_of` takes the spell itself: the catalog instance finds its line, a copy of it does not.
func _level_of() -> Dictionary:
	var checks := {}
	var pyro := GameData.god("pyro").book
	var volcano := GameData.spell("clov")
	var level := pyro.level_of(volcano)
	checks["volcano_has_a_level"] = level > 3
	checks["same_as_game_data"] = GameData.creature_level("pyro", volcano) == level
	checks["not_in_book_at_3"] = not _tags(pyro.up_to(3)["spells"]).has("clov")
	checks["in_book_at_level"] = _tags(pyro.up_to(level)["spells"]).has("clov")
	checks["copy_is_not_found"] = pyro.level_of(volcano.duplicate()) == -1
	checks["mixed_has_no_lines"] = MIXED_BOOK.level_of(GameData.spell("kcor")) == -1 and (MIXED_BOOK.up_to(0)["spells"] as Array).size() == 4
	return checks


func _wizard(god: String, level: int) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.level = level
	_root.add_child(wizard)
	## The wizard reads its seat's pick when it enters; the case says its god again.
	wizard.god_type = GameData.god(god)
	await _host.get_tree().process_frame
	return wizard


func _tags_of(book: Spellbook) -> Array[String]:
	var tags: Array[String] = []
	for i in book.size():
		tags.append(book.spell_at(i).tag)
	return tags


func _tags(types: Array) -> Array[String]:
	var tags: Array[String] = []
	for type in types:
		tags.append(type.tag)
	return tags


func _sorted_by_order(book: Spellbook) -> bool:
	for i in range(1, book.size()):
		if book.spell_at(i - 1).order_key() > book.spell_at(i).order_key():
			return false
	return true
