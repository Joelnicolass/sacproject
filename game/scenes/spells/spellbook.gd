class_name Spellbook
extends Node

## Book of a wizard: the god's creatures and spells up to the wizard's level in one
## list sorted by level and position (BookOrder). Two tabs read it: creature entry 0 is creature_1 (Q), 1 is
## creature_2 (Shift+Q)…; spell entry 0 is spell_1 (X), 1 spell_2 (R)…
## Cooldowns are derived state: each entry keeps the MatchClock tick it is ready again, and
## cooldown() = (ready − now) / 60. Nothing writes them per tick, so they follow the ticks of the match, not the render
## delta, and stand still while the game is paused. The server sets them (over the whole book) and pushes
## the seconds left to the owner client, which turns them into ticks of its own clock.

signal book_changed
signal cooldowns_changed

@export var rules: MatchRules
## The wizard whose book this is (the scene wires it to the root).
@export var wizard: WizardBody

## CreatureType or SpellType, sorted by level and position (BookOrder).
var _entries: Array[BookEntry] = []
var _creature_rows := PackedInt32Array()
var _spell_rows := PackedInt32Array()
var _structure_rows := PackedInt32Array()
## MatchClock tick at which each entry is ready again (0 = ready).
var _ready_tick := PackedInt64Array()
var _max_cooldowns := PackedFloat32Array()
## The book and the level the entries were built from: the rebuild key.
var _built_from: GodBook
var _level := 0
var _warned_override := false


func _ready() -> void:
	if wizard == null:
		push_error("Spellbook without a wizard: set the `wizard` socket")
		return
	wizard.pick_changed.connect(_rebuild)
	wizard.book_changed.connect(_rebuild)
	_rebuild()


## The book this wizard casts from: his own override, else the one of his god, else none.
func current_book() -> GodBook:
	if wizard.book != null:
		return wizard.book
	return wizard.god_type.book if wizard.god_type != null else null


func size() -> int:
	return _spell_rows.size()


func spell_at(index: int) -> SpellType:
	if index < 0 or index >= _spell_rows.size():
		return null
	return _entries[_spell_rows[index]]


func spell_by_tag(tag: String) -> SpellType:
	var index := index_of(tag)
	if index < 0:
		return null
	return spell_at(index)


func index_of(tag: String) -> int:
	return _tab_index(_spell_rows, tag)


func cooldown(index: int) -> float:
	return _cooldown_at(_spell_rows, index)


func max_cooldown(index: int) -> float:
	return _max_cooldown_at(_spell_rows, index)


func structure_count() -> int:
	return _structure_rows.size()


func structure_at(index: int) -> SpellType:
	if index < 0 or index >= _structure_rows.size():
		return null
	return _entries[_structure_rows[index]]


func structure_by_tag(tag: String) -> SpellType:
	var index := structure_index_of(tag)
	if index < 0:
		return null
	return structure_at(index)


func structure_index_of(tag: String) -> int:
	return _tab_index(_structure_rows, tag)


func structure_cooldown(index: int) -> float:
	return _cooldown_at(_structure_rows, index)


func structure_max_cooldown(index: int) -> float:
	return _max_cooldown_at(_structure_rows, index)


func creature_count() -> int:
	return _creature_rows.size()


func creature_at(index: int) -> CreatureType:
	if index < 0 or index >= _creature_rows.size():
		return null
	return _entries[_creature_rows[index]]


func creature_index_of(tag: String) -> int:
	return _tab_index(_creature_rows, tag)


func creature_cooldown(index: int) -> float:
	return _cooldown_at(_creature_rows, index)


func creature_max_cooldown(index: int) -> float:
	return _max_cooldown_at(_creature_rows, index)


## The cast entry waits casting time (level) + cooldown + extra; every
## other entry casting time + generic + extra. A running cooldown is never shortened.
func apply_cooldown(tag: String) -> void:
	var row := _row_of(tag)
	if row < 0 or rules == null:
		return
	var cast := _entries[row]
	var casting := CastTime.seconds(cast, _level)
	for i in _entries.size():
		var base := cast.cooldown_s if i == row else rules.other_spell_cooldown_s
		_raise(i, casting + base + rules.extra_cooldown_s)
	cooldowns_changed.emit()
	_push_to_owner()


func _tab_index(rows: PackedInt32Array, tag: String) -> int:
	for i in rows.size():
		if _entries[rows[i]].tag == tag:
			return i
	return -1


func _row_of(tag: String) -> int:
	for i in _entries.size():
		if _entries[i].tag == tag:
			return i
	return -1


func _cooldown_at(rows: PackedInt32Array, index: int) -> float:
	return _seconds_left(rows[index]) if index >= 0 and index < rows.size() else 0.0


## Seconds until entry `row` is ready, in whole ticks of the match.
func _seconds_left(row: int) -> float:
	return maxi(0, _ready_tick[row] - MatchClock.now()) / float(MatchClock.TICKS_PER_SECOND)


func _max_cooldown_at(rows: PackedInt32Array, index: int) -> float:
	return _max_cooldowns[rows[index]] if index >= 0 and index < rows.size() else 0.0


## A cooldown of `value` seconds from now, rounded up to whole ticks; a running one is never shortened.
func _raise(index: int, value: float) -> void:
	var now := MatchClock.now()
	if _ready_tick[index] <= now or value > _max_cooldowns[index]:
		_max_cooldowns[index] = value
	_ready_tick[index] = maxi(_ready_tick[index], now + MatchClock.ticks_for(value))


func _push_to_owner() -> void:
	if not MpKit.is_networked() or not MpKit.is_server():
		return
	var peer := MpKit.peer_id_for(wizard.owner_slot)
	if peer > 0 and peer != multiplayer.get_unique_id():
		var remaining := PackedFloat32Array()
		remaining.resize(_ready_tick.size())
		for i in _ready_tick.size():
			remaining[i] = _seconds_left(i)
		_receive_cooldowns.rpc_id(peer, remaining, _max_cooldowns)


## The seconds left on the server, turned into ticks of this peer's MatchClock (the countdown is local; up to 1 tick
## of rounding).
@rpc("authority", "call_remote", "reliable")
func _receive_cooldowns(remaining: PackedFloat32Array, maximum: PackedFloat32Array) -> void:
	if remaining.size() != _ready_tick.size():
		return
	var now := MatchClock.now()
	for i in remaining.size():
		_ready_tick[i] = now + MatchClock.ticks_for(remaining[i])
	_max_cooldowns = maximum
	cooldowns_changed.emit()


func _rebuild() -> void:
	var book := current_book()
	var level := wizard.level
	if book == _built_from and level == _level and not _entries.is_empty():
		return
	_built_from = book
	_level = level
	_warn_if_override()
	# TODO: a level change rebuilds the book and clears every cooldown. Today the level is fixed for the
	# match; when XP raises it mid-match, keep the cooldowns of the entries that stay (by tag).
	var rows: Dictionary = book.up_to(level) if book != null else {}
	var sorted: Array[BookEntry] = []
	for creature in rows.get("creatures", []):
		sorted.append(creature)
	for spell in rows.get("spells", []):
		sorted.append(spell)
	for structure in rows.get("structures", []):
		sorted.append(structure)
	sorted.sort_custom(func(a: BookEntry, b: BookEntry) -> bool: return BookOrder.key(a) < BookOrder.key(b))
	_entries = sorted
	_creature_rows = PackedInt32Array()
	_spell_rows = PackedInt32Array()
	_structure_rows = PackedInt32Array()
	for i in _entries.size():
		if _entries[i] is CreatureType:
			_creature_rows.append(i)
		elif _entries[i] is SpellType and (_entries[i] as SpellType).is_structure:
			_structure_rows.append(i)
		else:
			_spell_rows.append(i)
	_ready_tick = PackedInt64Array()
	_ready_tick.resize(_entries.size())
	_max_cooldowns = PackedFloat32Array()
	_max_cooldowns.resize(_entries.size())
	book_changed.emit()


## A book override is not replicated: online, the other peers would build the god's book. Said once.
func _warn_if_override() -> void:
	if wizard.book != null and MpKit.is_networked() and not _warned_override:
		_warned_override = true
		push_warning("WizardBody.book is an override of this peer only; it does not travel on the network")
