extends Control

## Book of the local wizard, laid out like sacengine renderSpellbook (renderer.d:4872-4975) in
## HUD units (sized by the shared `hud_scale`, see HudScale): three 48×48
## tabs (creatures, spells, structures) 80 units above the bottom-left corner, and only the
## active tab's 32×32 pages along the bottom edge, on a frame strip of max(10, 2·n) segments.
## Pressing a creature or spell key shows its tab first (switchSpellbookTab, dagonBackend.d:80,104).
## Hidden while the wizard is dying or a ghost (spellbookVisible, state.d:28104; renderer.d:4991).

signal spell_pressed(index: int)
signal creature_pressed(index: int)
signal structure_pressed(index: int)

enum Tab { CREATURE, SPELL, STRUCTURE }

const PAGE := 32.0
const TAB := 48.0
const SEGMENT := Vector2(16.0, 8.0)
const CAP := Vector2(48.0, 16.0)
## Sheet regions of SacHud (renderer.d:4204-4213), in pixels of the 128×128 tabs/fram and 64×64 page.
const TAB_REGIONS: Array[Rect2] = [Rect2(1, 0, 46, 48), Rect2(49, 0, 46, 48), Rect2(1, 48, 46, 48)]
const SELECTOR_REGION := Rect2(49, 48, 46, 48)
const PAGE_REGIONS: Array[Rect2] = [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Rect2(0, 32, 32, 32)]
const FRAME_SEGMENT_REGION := Rect2(64, 40, 16, 8)
const FRAME_CAP_REGION := Rect2(80.5, 32.5, 47.5, 15.5)
const TAB_TEXT: PackedStringArray = ["Criaturas", "Hechizos", "Estructuras"]

@export var slot_scene: PackedScene
## Frame piece (a TextureRect; texture, rect and rotation are set here).
@export var piece_scene: PackedScene
## Shared HUD size (the roster, the armed icon and the cursor read the same one).
@export var hud_scale: HudScale = preload("res://data/ui/hud_scale.tres")
@export var min_frame_segments := 10

var tab: int = Tab.CREATURE

var _book: Node
var _wizard: Node
var _slots: Array[Node] = []


## Shown only when the script runs in the editor (@tool); kept for the shared-size check.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var scale_warning := HudScale.socket_warning(hud_scale)
	if not scale_warning.is_empty():
		warnings.append(scale_warning)
	return warnings


func _ready() -> void:
	visible = false
	var tabs: Array[Button] = [%CreatureTab, %SpellTab, %StructureTab]
	for i in tabs.size():
		var texture := HudIcons.region("tabs", TAB_REGIONS[i])
		tabs[i].icon = texture
		tabs[i].text = "" if texture else TAB_TEXT[i]
		tabs[i].pressed.connect(show_tab.bind(i))
	%TabSelector.texture = HudIcons.region("tabs", SELECTOR_REGION)
	get_viewport().size_changed.connect(_fit_screen)
	if hud_scale:
		hud_scale.changed.connect(_fit_screen)
	_fit_screen()


func bind(wizard: Node) -> void:
	var book := wizard.get_node_or_null("Spellbook") if wizard else null
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


## sacengine switchSpellbookTab.
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
	var creatures: int = _book.call("creature_count") if _book else 0
	var spells: int = _book.call("size") if _book else 0
	var structures: int = _book.call("structure_count") if _book else 0
	var page := HudIcons.region("page", PAGE_REGIONS[tab])
	var spirit := HudIcons.sheet("spi2")
	var count := 0
	match tab:
		Tab.CREATURE:
			count = creatures
		Tab.SPELL:
			count = spells
		Tab.STRUCTURE:
			count = structures
	for i in count:
		var slot: Node = slot_scene.instantiate()
		%Slots.add_child(slot)
		slot.call("set_spirit", spirit)
		if tab == Tab.CREATURE:
			var creature: CreatureType = _book.call("creature_at", i)
			slot.name = "Creature%d" % (i + 1)
			slot.call("show_creature", creature, key_label("creature_%d" % (i + 1)), page, icon_for(creature.tag))
			slot.pressed.connect(creature_pressed.emit.bind(i))
		else:
			var spell: SpellType = _book.call("structure_at", i) if tab == Tab.STRUCTURE else _book.call("spell_at", i)
			slot.name = "Structure%d" % (i + 1) if tab == Tab.STRUCTURE else "Spell%d" % (i + 1)
			slot.call("show_spell", spell, key_label("spell_%d" % (i + 1)), page, icon_for(spell.tag))
			if tab == Tab.STRUCTURE:
				slot.pressed.connect(structure_pressed.emit.bind(i))
			else:
				slot.pressed.connect(spell_pressed.emit.bind(i))
		_slots.append(slot)
	%TabSelector.position = Vector2(TAB * tab, 0.0)
	_build_frame(count)
	_refresh_visible()


func _refresh_visible() -> void:
	var has_entries := false
	if _book and is_instance_valid(_book):
		has_entries = int(_book.call("creature_count")) + int(_book.call("size")) + int(_book.call("structure_count")) > 0
	var wizard_allows := true
	if _wizard and is_instance_valid(_wizard) and _wizard.has_method("spellbook_visible"):
		wizard_allows = bool(_wizard.call("spellbook_visible"))
	visible = has_entries and wizard_allows


func _on_stage_changed(_stage: int) -> void:
	_refresh_visible()


static func _ghost_of(wizard: Node) -> Node:
	if wizard == null or not is_instance_valid(wizard):
		return null
	return wizard.get_node_or_null("GhostForm")


## spellbookFrame1 segments 8 units above the pages, spellbookFrame2 turned 90° as the end cap.
func _build_frame(count: int) -> void:
	for child in %Frame.get_children():
		%Frame.remove_child(child)
		child.queue_free()
	var segments := maxi(min_frame_segments, 2 * count)
	var piece := HudIcons.region("fram", FRAME_SEGMENT_REGION)
	if piece:
		for i in segments:
			var rect: TextureRect = piece_scene.instantiate()
			rect.texture = piece
			rect.position = Vector2(SEGMENT.x * i, size.y - PAGE - SEGMENT.y)
			rect.size = SEGMENT
			%Frame.add_child(rect)
	var cap_texture := HudIcons.region("fram", FRAME_CAP_REGION)
	if cap_texture:
		var cap: TextureRect = piece_scene.instantiate()
		cap.texture = cap_texture
		cap.size = CAP
		cap.rotation = PI * 0.5
		cap.position = Vector2(SEGMENT.x * segments + CAP.y, size.y - CAP.x)
		%Frame.add_child(cap)
	offset_right = maxf(TAB * 3.0, SEGMENT.x * segments + CAP.y)


func _fit_screen() -> void:
	var height := get_viewport().get_visible_rect().size.y
	var factor := hud_scale.factor(height) if hud_scale else height / HudScale.SACENGINE_HEIGHT
	pivot_offset = Vector2(0.0, size.y)
	scale = Vector2(factor, factor)


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
		slot.call("show_readiness", mana, souls)
		if tab == Tab.CREATURE:
			slot.call("show_cooldown", _book.call("creature_cooldown", i), _book.call("creature_max_cooldown", i))
		elif tab == Tab.STRUCTURE:
			slot.call("show_cooldown", _book.call("structure_cooldown", i), _book.call("structure_max_cooldown", i))
		else:
			slot.call("show_cooldown", _book.call("cooldown", i), _book.call("max_cooldown", i))


## The CRE8/SPEL icon exported by tools/import_ui.py, or null.
static func icon_for(spell_tag: String) -> Texture2D:
	return HudIcons.icon(spell_tag)


static func key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
			var text := "Espacio" if code == KEY_SPACE else OS.get_keycode_string(code)
			if key.alt_pressed:
				text = "Alt+" + text
			if key.shift_pressed:
				text = "Shift+" + text
			if key.ctrl_pressed:
				text = "Ctrl+" + text
			return text
	return ""
