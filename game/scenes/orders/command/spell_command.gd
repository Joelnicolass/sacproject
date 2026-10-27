class_name SpellCommand
extends Node

## The spellbook's side of the player's input: a creature key summons at once, a spell or a structure is armed (an
## unaffordable or cooling one is not) and the next left click, on the screen or on the minimap, casts it where the
## cursor points. What a structure's click aims at (ground, own creature, soul, own building) is the `pick` of the
## entry's SpellAction (RFC-021). The server answers; `ArmedCommand` ends the wait when it does.

const _SPELL_BOOK := preload("res://scenes/ui/spell_book/spell_book.gd")

@export var armed: ArmedCommand
@export var ray: PointerRay
@export var feedback: CommandFeedback
## The wizard's book (spell_book.gd). Empty (the book was removed): the keys do nothing.
@export var book: Control

@onready var _log: CommandLog = %Battle
var _book: _SPELL_BOOK


func _ready() -> void:
	_book = book as _SPELL_BOOK
	if _book == null:
		return
	_book.spell_pressed.connect(arm_spell)
	_book.creature_pressed.connect(summon)
	_book.structure_pressed.connect(arm_structure)


## The key of a spell or structure entry: the book's open tab says which one it is.
func arm_by_key(index: int) -> void:
	if _book != null and int(_book.tab) == _SPELL_BOOK.Tab.STRUCTURE:
		arm_structure(index)
	else:
		arm_spell(index)


## A creature has no target; it appears in front of the wizard at once.
func summon(index: int) -> void:
	if _book != null:
		_book.show_tab(_SPELL_BOOK.Tab.CREATURE)
	var caster := _caster_ready()
	if caster == null:
		return
	var book: Spellbook = caster.spellbook
	if index >= book.creature_count():
		return
	armed.mode = ""
	var status := caster.summon_status(index)
	if not status.is_empty():
		_log.say(status)
		return
	var type: CreatureType = book.creature_at(index)
	caster.request_summon(type.tag)


## An unaffordable or cooling spell is not armed.
## Ref: sacengine selectSpell.
func arm_spell(index: int) -> void:
	if _book != null:
		_book.show_tab(_SPELL_BOOK.Tab.SPELL)
	var caster := _caster_ready()
	if caster == null:
		return
	var book: Spellbook = caster.spellbook
	if index >= book.size():
		return
	var status := caster.arm_status(index)
	if not status.is_empty():
		_log.say(status)
		return
	var spell: SpellType = book.spell_at(index)
	var action := caster.action_for(spell.tag) if spell else null
	if action != null and action.pick == SpellAction.Pick.SELF:
		_cast_on_self(caster, spell)
		return
	armed.mode = "spell"
	armed.spell_index = index
	armed.cast_pending = ""
	_log.arm("spell", spell.icon if spell else null, "Elegí el blanco")


## A spell that aims at the wizard himself (a ward) starts on the key: there is nothing to click.
func _cast_on_self(caster: Caster, spell: SpellType) -> void:
	armed.mode = ""
	armed.cast_pending = spell.tag
	caster.request_cast(spell.tag, Vector3.ZERO, null)


## Structure tab entries are armed here and applied on the next left click.
func arm_structure(index: int) -> void:
	if _book != null:
		_book.show_tab(_SPELL_BOOK.Tab.STRUCTURE)
	var caster := _caster_ready()
	if caster == null:
		return
	var book: Spellbook = caster.spellbook
	if index >= book.structure_count():
		return
	var status := caster.structure_status(index)
	if not status.is_empty():
		_log.say(status)
		return
	var action: SpellAction = caster.structure_action(index)
	if action == null:
		_log.say(Refusal.NOT_IMPLEMENTED)
		return
	armed.mode = "structure"
	armed.structure_index = index
	armed.cast_pending = ""
	var spell: SpellType = book.structure_at(index)
	_log.arm("structure", spell.icon if spell else null, action.prompt, _accepts_of(action))


func cast_at(screen: Vector2) -> void:
	cast_on(ray.soul_under(screen) if _armed_picks_soul() else ray.body_under(screen, false), ray.ground(screen))


## The armed spell aims at a soul (Soul Mole, Animate Dead, Soul Wind): the click looks for souls, not bodies.
func _armed_picks_soul() -> bool:
	var book := _spellbook()
	var spell: SpellType = book.spell_at(armed.spell_index) if book else null
	var action := armed.caster.action_for(spell.tag) if spell else null
	return action != null and action.pick == SpellAction.Pick.SOUL


func cast_on(body: Node3D, ground: Variant) -> void:
	var book := _spellbook()
	var spell: SpellType = book.spell_at(armed.spell_index) if book else null
	if spell == null:
		armed.mode = ""
		_log.say("Mago")
		return
	var point: Vector3 = body.global_position if body else (ground if ground != null else Vector3.ZERO)
	if body == null and ground == null:
		_log.say(Refusal.NO_TARGET)
		return
	feedback.show_ping(point)
	armed.cast_pending = spell.tag
	armed.caster.request_cast(spell.tag, point, body)


func structure_at(screen: Vector2) -> void:
	var book := _spellbook()
	var spell: SpellType = book.structure_at(armed.structure_index) if book else null
	if spell == null:
		armed.mode = ""
		_log.say("Mago")
		return
	var action: SpellAction = armed.caster.structure_action(armed.structure_index)
	if action == null:
		armed.mode = ""
		_log.say(Refusal.NOT_IMPLEMENTED)
		return
	match action.pick:
		SpellAction.Pick.GROUND:
			_structure_on_ground(spell, ray.ground(screen))
		SpellAction.Pick.OWN_UNIT:
			_structure_on_body(spell, ray.unit_under(screen))
		SpellAction.Pick.SOUL:
			_structure_on_body(spell, ray.soul_under(screen))
		SpellAction.Pick.OWN_BUILDING:
			_structure_on_body(spell, ray.building_under(screen))


## The minimap only gives a ground point: a structure that aims at a creature finds one near it, the others do not apply.
func structure_at_point(point: Vector3) -> void:
	var book := _spellbook()
	var spell: SpellType = book.structure_at(armed.structure_index) if book else null
	var action: SpellAction = armed.caster.structure_action(armed.structure_index) if spell else null
	if action == null:
		armed.mode = ""
		_log.say("Mago" if spell == null else Refusal.NOT_IMPLEMENTED)
		return
	match action.pick:
		SpellAction.Pick.GROUND:
			_structure_on_ground(spell, point)
		SpellAction.Pick.OWN_UNIT:
			_structure_on_body(spell, ray.body_near(point, true))
		_:
			_log.say(Refusal.NO_TARGET)


func _structure_on_ground(spell: SpellType, ground: Variant) -> void:
	if ground == null:
		_log.say(Refusal.NO_GROUND)
		return
	feedback.show_ping(ground)
	armed.cast_pending = spell.tag
	armed.caster.request_structure(armed.structure_index, ground)


## A structure tab spell that aims at a body: the server checks the body is valid (own, in range…).
func _structure_on_body(spell: SpellType, body: Node3D) -> void:
	if body == null:
		_log.say(Refusal.NO_TARGET)
		return
	feedback.show_ping(body.global_position)
	armed.cast_pending = spell.tag
	armed.caster.request_cast(spell.tag, body.global_position, body)


## The local Caster when the wizard can cast, else null (and a refusal said when there is no wizard).
func _caster_ready() -> Caster:
	var caster := armed.caster
	if caster == null or not is_instance_valid(caster):
		_log.say(Refusal.NO_WIZARD)
		return null
	return caster if caster.wizard_can_cast() else null


func _spellbook() -> Spellbook:
	var caster := armed.caster
	return caster.spellbook if caster and is_instance_valid(caster) else null


## The classes of target (TargetProbe) a structure's click can land on, from what its action picks.
func _accepts_of(action: SpellAction) -> PackedStringArray:
	match action.pick:
		SpellAction.Pick.GROUND:
			return PackedStringArray(["ground"])
		SpellAction.Pick.OWN_UNIT:
			return PackedStringArray(["own_unit"])
		SpellAction.Pick.SOUL:
			return PackedStringArray(["soul", "own_soul"])
		SpellAction.Pick.OWN_BUILDING:
			return PackedStringArray(["own_building"])
		SpellAction.Pick.SELF:
			return PackedStringArray()
	return PackedStringArray()
