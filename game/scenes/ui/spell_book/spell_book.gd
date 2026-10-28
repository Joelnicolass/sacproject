extends Control

## The local wizard's book at the bottom-left corner: three 58×58 tabs (creatures, spells, structures) over the pages of the
## active tab, 38×38 each, along the bottom edge on a frame strip of max(10, 2·n) segments with a cap at its end. Sizes are
## canvas pixels of the 1280×720 base; Godot's stretch scales them, so nothing here reads the window. Tabs, pages and the spirit
## mark are icons of the theme type `SpellBook`, the strip and the cap are the theme variations HudBookStrip and HudBookCap
## (data/ui/theme.tres). This script only counts segments and moves the cap.
## Pressing a creature or spell key shows its tab first. Hidden while the wizard is dying or a ghost.

signal spell_pressed(index: int)
signal creature_pressed(index: int)
signal structure_pressed(index: int)

enum Tab { CREATURE, SPELL, STRUCTURE }

const TAB := 58.0
## Width of one frame segment and of the cap, and the theme type that holds the book's icons.
const SEGMENT_WIDTH := 19.0
const CAP_WIDTH := 19.0
const THEME_TYPE := &"SpellBook"
const TAB_ICONS: Array[StringName] = [&"tab_creature", &"tab_spell", &"tab_structure"]
const PAGE_ICONS: Array[StringName] = [&"page_creature", &"page_spell", &"page_structure"]

@export var slot_scene: PackedScene
@export var min_frame_segments := 10

var tab: int = Tab.CREATURE

var _book: Spellbook
var _wizard: Node
var _slots: Array[SpellSlot] = []


func _ready() -> void:
	visible = false
	var tabs: Array[Button] = [%CreatureTab, %SpellTab, %StructureTab]
	for i in tabs.size():
		tabs[i].icon = get_theme_icon(TAB_ICONS[i], THEME_TYPE)
		tabs[i].pressed.connect(show_tab.bind(i))
	%TabSelector.texture = get_theme_icon(&"tab_selector", THEME_TYPE)


func bind(wizard: Node) -> void:
	var book := wizard.get_node_or_null("Spellbook") as Spellbook if wizard else null
	if wizard != _wizard:
		var ghost := _ghost_of(_wizard)
		if ghost and ghost.stage_changed.is_connected(_on_stage_changed):
			ghost.stage_changed.disconnect(_on_stage_changed)
		_wizard = wizard
		ghost = _ghost_of(_wizard)
		if ghost:
			ghost.stage_changed.connect(_on_stage_changed)
	if book == _book:
		_refresh_visible()
		return
	if _book and is_instance_valid(_book):
		_book.book_changed.disconnect(_rebuild)
	_book = book
	if _book:
		_book.book_changed.connect(_rebuild)
	_rebuild()


## Switches the spellbook tab.
func show_tab(next: int) -> void:
	if next == tab:
		return
	tab = next
	_rebuild()


func _rebuild() -> void:
	for child in %Slots.get_children():
		%Slots.remove_child(child)
		child.queue_free()
	_slots.clear()
	var counts: Array[int] = [0, 0, 0]
	if _book:
		counts = [_book.creature_count(), _book.size(), _book.structure_count()]
	var count: int = counts[tab]
	var page := get_theme_icon(PAGE_ICONS[tab], THEME_TYPE)
	var spirit := get_theme_icon(&"spirit", THEME_TYPE)
	for i in count:
		var slot := slot_scene.instantiate() as SpellSlot
		%Slots.add_child(slot)
		slot.set_spirit(spirit)
		if tab == Tab.CREATURE:
			var creature := _book.creature_at(i)
			slot.name = "Creature%d" % (i + 1)
			slot.show_creature(creature, ActionKeyLabel.of("creature_%d" % (i + 1)), page)
			slot.pressed.connect(creature_pressed.emit.bind(i))
		else:
			var spell := _book.structure_at(i) if tab == Tab.STRUCTURE else _book.spell_at(i)
			slot.name = "Structure%d" % (i + 1) if tab == Tab.STRUCTURE else "Spell%d" % (i + 1)
			slot.show_spell(spell, ActionKeyLabel.of("spell_%d" % (i + 1)), page)
			if tab == Tab.STRUCTURE:
				slot.pressed.connect(structure_pressed.emit.bind(i))
			else:
				slot.pressed.connect(spell_pressed.emit.bind(i))
		_slots.append(slot)
	%TabSelector.position = Vector2(TAB * tab, 0.0)
	_fit_frame(count)
	_refresh_visible()


func _refresh_visible() -> void:
	var has_entries := (
		is_instance_valid(_book)
		and _book.creature_count() + _book.size() + _book.structure_count() > 0
	)
	var wizard_allows: bool = (
		not (_wizard is WizardBody and is_instance_valid(_wizard))
		or (_wizard as WizardBody).spellbook_visible()
	)
	visible = has_entries and wizard_allows


func _on_stage_changed(_stage: int) -> void:
	_refresh_visible()


static func _ghost_of(wizard: Node) -> Node:
	if wizard == null or not is_instance_valid(wizard):
		return null
	return wizard.get_node_or_null("GhostForm")


## spellbookFrame1 segments 8 units above the pages, spellbookFrame2 turned 90° as the end cap.
func _fit_frame(count: int) -> void:
	var width := SEGMENT_WIDTH * maxi(min_frame_segments, 2 * count)
	(%Strip as Control).size.x = width
	(%Cap as Control).position.x = width
	offset_right = maxf(TAB * 3.0, width + CAP_WIDTH)


func _process(_delta: float) -> void:
	if _book == null or not is_instance_valid(_book):
		return
	var mana := 0.0
	var souls := 0
	if _wizard and is_instance_valid(_wizard):
		var pool: Node = _wizard.get("mana")
		var purse: Node = _wizard.get("souls")
		mana = float(pool.get("current")) if pool else 0.0
		souls = int(purse.get("count")) if purse else 0
	for i in _slots.size():
		var slot := _slots[i]
		slot.show_readiness(mana, souls)
		if tab == Tab.CREATURE:
			slot.show_cooldown(_book.creature_cooldown(i), _book.creature_max_cooldown(i))
		elif tab == Tab.STRUCTURE:
			slot.show_cooldown(_book.structure_cooldown(i), _book.structure_max_cooldown(i))
		else:
			slot.show_cooldown(_book.cooldown(i), _book.max_cooldown(i))
