extends Node

## Player input in the world (sacengine dagonBackend.d:947-1300). Left button: a spell or an
## order icon waiting for its target takes the click; otherwise it selects (see Selection).
## Right click orders the selection by what is under the cursor: ground = move, enemy =
## attack, corpse = guard the spot, anything else (own creature or wizard) = guard it.
## Ctrl+R / Ctrl+A arm attack / guard for the next left click (a body, else advance / guard
## the spot); a right click cancels an armed icon. Ctrl+Space calls every creature back to
## the wizard. Ctrl+Q / Shift+B uses the selection's active ability. An armed spell or ability
## stays armed after a refused click, as in sacengine (dagonBackend.d:1236-1250).
## Nothing is drawn as text (RFC-025c): what is armed goes to %Battle (CommandLog) with the tag of its
## icon, CommandCue draws it on the cursor and a refusal flashes `ncst`; the words only stay in
## `%Battle.text` for the log and the flows.

const _SPELL_BOOK := preload("res://scenes/ui/spell_book.gd")
const SPELL_KEYS := 11
const CREATURE_KEYS := 11
const GROUP_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const ORDER_TEXT := {
	"move": "Orden",
	"attack": "Ataque",
	"guard": "Escolta",
	"guard_area": "Guardia",
	"advance": "Avance",
	"retreat": "Retirada",
}
const ORDER_MENU_ORDER := ["attack", "guard", "advance", "guard_area", "retreat"]

## sacengine rectangleThreshold.
@export var rect_threshold_px := 3.0
## A click on the minimap finds a body within this many minimap units of it (meters = units × the minimap zoom).
@export var minimap_pick_units := 3.0

var _mode := "":
	set(value):
		_mode = value
		if value.is_empty():
			%Battle.disarm()
var _spell_index := -1
var _structure_index := -1
## Name the caster answers once the armed spell starts; until then it stays armed.
var _cast_pending := ""
var _ability_tag := ""
var _menu_index := 0
var _caster: Node
var _left_down := false
var _press_at := Vector2.ZERO
var _press_ctrl := false
var _rect := false


func _ready() -> void:
	add_to_group("match_command")
	%Battle.say("Mago")
	_prepare_ping()
	%View.gui_input.connect(_on_view_event)
	%Minimap.ground_pointed.connect(_on_minimap_pointed)
	%SpellBook.spell_pressed.connect(_arm_spell)
	%SpellBook.creature_pressed.connect(_summon)
	%SpellBook.structure_pressed.connect(_arm_structure)
	%SelectionRoster.ability_pressed.connect(_use_ability)
	%Units.child_entered_tree.connect(_on_unit_entered)
	%Selection.changed.connect(_on_selection_changed)
	var world := get_parent()
	if world.has_signal("local_wizard_changed"):
		world.local_wizard_changed.connect(_on_local_wizard)
	_on_local_wizard(_wizard())
	_connect_soul_messages.call_deferred()


## «Sin almas» (the drop answer) is a refusal like the others: said on %Battle, it flashes `ncst`.
func _connect_soul_messages() -> void:
	var souls := get_tree().get_first_node_in_group("soul_system")
	if souls and souls.has_signal("message"):
		souls.message.connect(%Battle.say)


func _prepare_ping() -> void:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.35
	pole.bottom_radius = 0.35
	pole.height = 1.4
	%Ping.mesh = pole
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.28, 0.08)
	%Ping.material_override = mat


func _on_local_wizard(wizard: Node3D) -> void:
	var caster := wizard.get_node_or_null("Caster") if wizard else null
	if caster == _caster:
		return
	if _caster and is_instance_valid(_caster):
		_caster.feedback.disconnect(_on_feedback)
	_caster = caster
	if _caster:
		_caster.feedback.connect(_on_feedback)


func _on_feedback(text: String) -> void:
	if (_mode == "spell" or _mode == "structure") and not _cast_pending.is_empty() and text == _cast_pending:
		_mode = ""
		_cast_pending = ""
	%Battle.say(text)


func _input(event: InputEvent) -> void:
	## A modal UI (pause, options) silences the hotkeys and the actions on the world (WorldInput, RFC-031 031c).
	## `walk_order` is this node's own check: the walk-order debug scene drives the world by itself.
	if get_tree().get_first_node_in_group("walk_order") or WorldInput.blocked(self):
		return
	if event is InputEventMouseButton:
		return
	for i in CREATURE_KEYS:
		if event.is_action_pressed("creature_%d" % (i + 1), false, true):
			_summon(i)
			return
	for i in SPELL_KEYS:
		if event.is_action_pressed("spell_%d" % (i + 1), false, true):
			if int(%SpellBook.tab) == _SPELL_BOOK.Tab.STRUCTURE:
				_arm_structure(i)
			else:
				_arm_spell(i)
			return
	for i in GROUP_KEYS.size():
		if event.is_action_pressed("group_set_%s" % GROUP_KEYS[i], false, true):
			%Selection.define_group(i)
			return
		if event.is_action_pressed("group_%s" % GROUP_KEYS[i]):
			if event is InputEventKey and (event as InputEventKey).shift_pressed:
				%Selection.extend_group(i)
			else:
				%Selection.select_group(i)
			return
	if event.is_action_pressed("order_menu", false, true):
		_toggle_order_menu()
	elif event.is_action_pressed("order_attack", false, true):
		_arm_order("attack")
	elif event.is_action_pressed("order_guard", false, true):
		_arm_order("guard")
	elif event.is_action_pressed("order_retreat", false, true):
		_retreat()
	elif event.is_action_pressed("use_ability", false, true):
		_use_ability()
	elif event.is_action_pressed("order_units"):
		_right_at(_action_pointer(), true)
	elif event.is_action_pressed("select"):
		_left_at(_action_pointer(), false, false)


func _on_view_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_left_down = true
				_press_at = button.position
				_press_ctrl = button.ctrl_pressed
				_rect = false
			elif _left_down:
				_left_down = false
				_release_left(button)
		elif button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed:
			if not _camera_dragged():
				_right_at(button.position, false)
	elif event is InputEventMouseMotion and _left_down:
		var at := (event as InputEventMouseMotion).position
		if not _rect and _mode.is_empty() and not _press_ctrl and not _camera_dragged():
			_rect = absf(at.x - _press_at.x) >= rect_threshold_px or absf(at.y - _press_at.y) >= rect_threshold_px
		if _rect:
			%Selection.show_box(_press_at, at)


func _release_left(button: InputEventMouseButton) -> void:
	if _rect:
		_rect = false
		%Selection.select_rect(_press_at, button.position, button.shift_pressed)
		return
	if _camera_dragged():
		return
	_left_at(button.position, button.shift_pressed, button.ctrl_pressed)


func _camera_dragged() -> bool:
	var cam := get_node_or_null("%Camera")
	return cam != null and cam.has_method("is_dragging") and bool(cam.call("is_dragging"))


## sacengine: a creature has no target; it appears in front of the wizard at once.
func _summon(index: int) -> void:
	%SpellBook.show_tab(_SPELL_BOOK.Tab.CREATURE)
	if _caster == null or not is_instance_valid(_caster):
		%Battle.say("Sin mago")
		return
	if not bool(_caster.call("wizard_can_cast")):
		return
	var book: Node = _caster.get("spellbook")
	if index >= int(book.call("creature_count")):
		return
	_mode = ""
	var status := str(_caster.call("summon_status", index))
	if not status.is_empty():
		%Battle.say(status)
		return
	var type: CreatureType = book.call("creature_at", index)
	_caster.call("request_summon", type.tag)


## sacengine selectSpell: an unaffordable or cooling spell is not armed.
func _arm_spell(index: int) -> void:
	%SpellBook.show_tab(_SPELL_BOOK.Tab.SPELL)
	if _caster == null or not is_instance_valid(_caster):
		%Battle.say("Sin mago")
		return
	if not bool(_caster.call("wizard_can_cast")):
		return
	var book: Node = _caster.get("spellbook")
	if index >= int(book.call("size")):
		return
	var status := str(_caster.call("arm_status", index))
	if not status.is_empty():
		%Battle.say(status)
		return
	_mode = "spell"
	_spell_index = index
	_cast_pending = ""
	var armed_spell: SpellType = book.call("spell_at", index)
	%Battle.arm("spell", armed_spell.tag if armed_spell else "", "Elegí el blanco")


## Structure tab entries are armed here and applied on the next left click. What the click
## aims at (ground, own creature, soul, own building) is the `pick` of the entry's SpellAction.
func _arm_structure(index: int) -> void:
	%SpellBook.show_tab(_SPELL_BOOK.Tab.STRUCTURE)
	if _caster == null or not is_instance_valid(_caster):
		%Battle.say("Sin mago")
		return
	if not bool(_caster.call("wizard_can_cast")):
		return
	var book: Node = _caster.get("spellbook")
	if index >= int(book.call("structure_count")):
		return
	var status := str(_caster.call("structure_status", index))
	if not status.is_empty():
		%Battle.say(status)
		return
	var action: SpellAction = _caster.call("structure_action", index)
	if action == null:
		%Battle.say("No implementado")
		return
	_mode = "structure"
	_structure_index = index
	_cast_pending = ""
	var armed_structure: SpellType = book.call("structure_at", index)
	%Battle.arm("structure", armed_structure.tag if armed_structure else action.tag, action.prompt, _accepts_of(action))


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
	return PackedStringArray()


## Ctrl+R / Ctrl+A only arm while no other icon waits (mouse.status == standard).
func _arm_order(kind: String) -> void:
	if not _mode.is_empty():
		return
	_mode = kind
	_arm_order_icon(kind)


## The icon of an armed order on the cursor: attack Matt, guard Mgua… (CueSet.aim_icons).
func _arm_order_icon(kind: String) -> void:
	%Battle.arm(kind, _order_icon(kind), "Elegí el blanco", TargetProbe.ORDER_TARGETS)


func _order_icon(kind: String) -> String:
	var cues: CueSet = %Battle.cues
	return cues.aim_icon(kind) if cues else ""


func _arm_menu_entry() -> void:
	var order: String = ORDER_MENU_ORDER[_menu_index]
	%Battle.arm("menu:%s" % order, _order_icon(order), "Menú: %s" % ORDER_TEXT.get(order, "Orden"), TargetProbe.ORDER_TARGETS)


func _toggle_order_menu() -> void:
	if _mode == "menu":
		_menu_index = (_menu_index + 1) % ORDER_MENU_ORDER.size()
		_arm_menu_entry()
		return
	if not _mode.is_empty():
		return
	_mode = "menu"
	_menu_index = 0
	_arm_menu_entry()


func _left_at(screen: Vector2, shift: bool, ctrl: bool) -> void:
	match _mode:
		"spell":
			_cast_at(screen)
		"structure":
			_structure_at(screen)
		"ability":
			_ability_at(screen)
		"attack", "guard":
			_order_icon_at(screen)
		"menu":
			var kind: String = ORDER_MENU_ORDER[_menu_index]
			_mode = kind
			_arm_order_icon(kind)
		_:
			var unit := _unit_under(screen)
			var building := _building_first(screen) if unit == null else null
			if unit:
				%Selection.click(unit, screen, shift, ctrl)
			elif building:
				# RFC-028b: a building shows its bar (StructureInspector); the selection stays.
				%Inspector.inspect(building)
			elif not shift and not ctrl and _is_empty_at(screen):
				# RFC-025 3.2: a plain left click on the ground or on nothing drops the selection
				# (an armed icon never gets here; the original keeps it: dagonBackend.d:1171-1198).
				%Selection.clear()
				%Inspector.clear()


## dagonBackend.d:1215-1233: attack or guard a body; on the ground, advance or guard the spot.
func _order_icon_at(screen: Vector2) -> void:
	var body := _body_under(screen, false)
	_order_icon_on(body, _ray_ground(screen))


func _order_icon_on(body: Node3D, ground: Variant) -> void:
	var kind := _mode
	_mode = ""
	if body and not _is_corpse(body):
		_order(kind, body.global_position, body)
		return
	if ground == null:
		%Battle.say("Sin suelo")
		return
	_order("advance" if kind == "attack" else "guard_area", ground, null)


func _cast_at(screen: Vector2) -> void:
	_cast_on(_body_under(screen, false), _ray_ground(screen))


func _cast_on(body: Node3D, ground: Variant) -> void:
	var book: Node = _caster.get("spellbook") if _caster and is_instance_valid(_caster) else null
	var spell: SpellType = book.call("spell_at", _spell_index) if book else null
	if spell == null:
		_mode = ""
		%Battle.say("Mago")
		return
	var point: Vector3 = body.global_position if body else (ground if ground != null else Vector3.ZERO)
	if body == null and ground == null:
		%Battle.say("Sin blanco")
		return
	_show_ping(point)
	_cast_pending = spell.display_name
	_caster.call("request_cast", spell.tag, point, body)


func _soul_under(screen: Vector2) -> Node3D:
	var hit: Dictionary = _cast(screen, 4, false)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node and (body as Node).is_in_group("soul_target"):
		return (body as Node).get_parent() as Node3D
	return null


func _building_under(screen: Vector2) -> Node3D:
	var hit: Dictionary = _cast(screen, 1, false)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node3D and ((body as Node).is_in_group("structure") or (body as Node).is_in_group(Altar.GROUP)):
		return body as Node3D
	return null


## RFC-028b: a structure or altar only when it is the first thing under the cursor (mask 15, as
## _is_empty_at): a wizard, corpse or soul in front of a house keeps the click from inspecting it.
func _building_first(screen: Vector2) -> Node3D:
	var hit: Dictionary = _cast(screen, 15, false)
	var body: Object = null if hit.is_empty() else hit.get("collider")
	if body is Node3D and ((body as Node).is_in_group("structure") or (body as Node).is_in_group(Altar.GROUP)):
		return body as Node3D
	return null


func _structure_at(screen: Vector2) -> void:
	var book: Node = _caster.get("spellbook") if _caster and is_instance_valid(_caster) else null
	var spell: SpellType = book.call("structure_at", _structure_index) if book else null
	if spell == null:
		_mode = ""
		%Battle.say("Mago")
		return
	var action: SpellAction = _caster.call("structure_action", _structure_index)
	if action == null:
		_mode = ""
		%Battle.say("No implementado")
		return
	match action.pick:
		SpellAction.Pick.GROUND:
			_structure_on_ground(spell, _ray_ground(screen))
		SpellAction.Pick.OWN_UNIT:
			_cast_structure_on(spell, _unit_under(screen))
		SpellAction.Pick.SOUL:
			_cast_structure_on(spell, _soul_under(screen))
		SpellAction.Pick.OWN_BUILDING:
			_cast_structure_on(spell, _building_under(screen))


func _structure_on_ground(spell: SpellType, ground: Variant) -> void:
	if ground == null:
		%Battle.say("Sin suelo")
		return
	_show_ping(ground)
	_cast_pending = spell.display_name
	_caster.call("request_structure", _structure_index, ground)


## A structure tab spell that aims at a body: the server checks the body is valid (own, in range…).
func _cast_structure_on(spell: SpellType, body: Node3D) -> void:
	if body == null:
		%Battle.say("Sin blanco")
		return
	_show_ping(body.global_position)
	_cast_pending = spell.display_name
	_caster.call("request_cast", spell.tag, body.global_position, body)


## sacengine selectAbility (dagonBackend.d:152-178): the selection's ability (renderedSelection
## ability, state.d:30231). One that needs a target (requiresTarget = flags != 0) arms the next
## left click; any other is used at once with no target.
func _use_ability() -> void:
	var tag := _selection_ability()
	if tag.is_empty():
		return
	var ability: AbilityType = GameData.ability(tag)
	if ability and ability.flags != 0:
		_mode = "ability"
		_ability_tag = tag
		%Battle.arm("ability", tag, "Elegí el blanco", TargetProbe.ORDER_TARGETS)
		return
	_apply_ability(tag, null, null)


func _ability_at(screen: Vector2) -> void:
	var body := _body_under(screen, false)
	## RFC-030 030p-b: an ability that aims at souls or corpses (Breath of life) looks for them after the living body.
	if body == null and _aims_at_dead(_ability_tag):
		body = _soul_under(screen)
		if body == null:
			body = _corpse_under(screen)
	_ability_on(body, _ray_ground(screen))


func _ability_on(body: Node3D, ground: Variant) -> void:
	if body == null and ground == null:
		%Battle.say("Sin blanco")
		return
	var point: Vector3 = body.global_position if body else ground
	if _apply_ability(_ability_tag, point, body):
		_mode = ""
		_show_ping(point)


## spells.d:168-183: targetSouls (1 << 1) and targetCorpses (1 << 3).
func _aims_at_dead(tag: String) -> bool:
	var ability: AbilityType = GameData.ability(tag)
	return ability != null and (ability.flags & ((1 << 1) | (1 << 3))) != 0


## A corpse under the cursor (layer 8, mask 8): the body itself, group «corpse».
func _corpse_under(screen: Vector2) -> Node3D:
	var hit: Dictionary = _cast(screen, 8, false)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node3D and (body as Node).is_in_group("corpse"):
		return body as Node3D
	return null


## Every selected creature whose active ability is `tag` gets the order; the others skip it
## (applyOrder, state.d:29256). `point` null = no target (the creature's own spot).
func _apply_ability(tag: String, point: Variant, body: Node3D) -> bool:
	var used := 0
	var refusal := ""
	for unit in %Selection.units():
		if _ability_of(unit) != tag:
			continue
		var at: Vector3 = point if point != null else unit.global_position
		var reason := str(unit.call("request_ability", at, body))
		if reason.is_empty():
			used += 1
		elif refusal.is_empty():
			refusal = reason
	var ability: AbilityType = GameData.ability(tag)
	%Battle.say((ability.display_name if ability else tag) if used > 0 else refusal)
	return used > 0


## The selection's ability (see Selection.ability_tag).
func _selection_ability() -> String:
	return %Selection.ability_tag()


func _ability_of(unit: Node) -> String:
	if not is_instance_valid(unit) or not unit.has_method("request_ability"):
		return ""
	var type: CreatureType = unit.get("type")
	return type.active_ability_tag if type else ""


## The keyboard action has no cursor: it aims through the crosshair, which the third-person
## camera keeps on the wizard's head, so the local wizard is skipped there.
func _right_at(screen: Vector2, from_action: bool) -> void:
	if _cancel_armed():
		return
	var body := _body_under(screen, from_action)
	if body:
		if _is_corpse(body):
			_order("guard_area", body.global_position, null)
		elif _is_enemy(body):
			_order("attack", body.global_position, body)
		else:
			_order("guard", body.global_position, body)
		return
	var ground: Variant = _ray_ground(screen)
	if ground == null:
		%Battle.say("Sin suelo")
		return
	_order("move", ground, null)


## A right click drops an armed icon instead of ordering. True when it did.
func _cancel_armed() -> bool:
	if _mode.is_empty():
		return false
	_mode = ""
	_on_selection_changed(%Selection.units())
	return true


## RFC-037 037c: the minimap is another surface to point at. It only gives a ground point (no ray): a right click orders
## the selection there, a left click with an icon armed aims it there (a body near the point, else the spot).
## A left click with nothing armed does nothing (P2): the original keeps the camera on the wizard and has no box here.
func _on_minimap_pointed(point: Vector3, button: int) -> void:
	if get_tree().get_first_node_in_group("walk_order") or WorldInput.blocked(self):
		return
	if button == MOUSE_BUTTON_RIGHT:
		if not _cancel_armed():
			_order("move", point, null)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	match _mode:
		"spell":
			_cast_on(_body_near(point), point)
		"structure":
			_structure_at_point(point)
		"ability":
			_ability_on(_body_near(point), point)
		"attack", "guard":
			_order_icon_on(_body_near(point), point)
		"menu":
			var kind: String = ORDER_MENU_ORDER[_menu_index]
			_mode = kind
			_arm_order_icon(kind)


func _structure_at_point(point: Vector3) -> void:
	var book: Node = _caster.get("spellbook") if _caster and is_instance_valid(_caster) else null
	var spell: SpellType = book.call("structure_at", _structure_index) if book else null
	var action: SpellAction = _caster.call("structure_action", _structure_index) if spell else null
	if action == null:
		_mode = ""
		%Battle.say("Mago" if spell == null else "No implementado")
		return
	match action.pick:
		SpellAction.Pick.GROUND:
			_structure_on_ground(spell, point)
		SpellAction.Pick.OWN_UNIT:
			_cast_structure_on(spell, _body_near(point, true))
		_:
			%Battle.say("Sin blanco")


## The body (wizard or creature, not a corpse) closest to a world point and within `minimap_pick_units` HUD units of the
## minimap at its current zoom; an enemy that cannot be targeted (stealth) is not found. `own_only`: only the local side's.
func _body_near(point: Vector3, own_only := false) -> Node3D:
	var reach := minimap_pick_units * float(%Minimap.zoom)
	var best: Node3D = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("unit") + get_tree().get_nodes_in_group("wizard"):
		var body := node as Node3D
		if body == null or not Attackable.is_body(body) or _is_corpse(body):
			continue
		if own_only and _is_enemy(body):
			continue
		if _is_enemy(body) and body.has_method("is_targetable") and not bool(body.call("is_targetable")):
			continue
		var distance := Vector2(body.global_position.x - point.x, body.global_position.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func _retreat() -> void:
	var wizard := _wizard()
	if wizard == null:
		%Battle.say("Sin mago")
		return
	%Orders.request([], "retreat", wizard.global_position, wizard, _camera_yaw())
	%Battle.say("Retirada")


func _order(kind: String, point: Vector3, target: Node3D) -> void:
	var units: Array = %Selection.units()
	if units.is_empty():
		%Battle.say("Nadie")
		return
	_show_ping(point)
	%Orders.request(units, kind, point, target, _camera_yaw())
	%Battle.say(ORDER_TEXT.get(kind, "Orden"))


func _on_selection_changed(units: Array) -> void:
	if units.size() == 1:
		%Battle.say(str(units[0].call("display_name")))
	elif units.size() > 1:
		%Battle.say("%d unidades" % units.size())
	else:
		%Battle.say("Mago")


func _show_ping(point: Vector3) -> void:
	%Ping.global_position = point + Vector3(0.0, 0.15, 0.0)
	%Ping.visible = true


## The camera's debug pointer when set (AgentKit flows), else the crosshair.
func _action_pointer() -> Vector2:
	var cam := get_node_or_null("%Camera")
	if cam and "debug_pointer" in cam:
		var pointer: Vector2 = cam.get("debug_pointer")
		if pointer.x >= 0.0:
			return pointer
	return get_viewport().get_visible_rect().size * 0.5


func _camera_yaw() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var ahead := -cam.global_basis.z
	return atan2(ahead.x, ahead.z)


func _on_unit_entered(unit: Node) -> void:
	if unit.has_signal("summoned"):
		unit.summoned.connect(_on_unit_summoned.bind(unit), CONNECT_ONE_SHOT)


## sacengine newCreatureAddToSelection: the owner's new creature joins the selection.
func _on_unit_summoned(unit: Node) -> void:
	if is_instance_valid(unit) and int(unit.get("owner_slot")) == MpKit.local_slot():
		%Selection.add_summoned(unit)


func _wizard() -> Node3D:
	var world := get_parent()
	if world and world.has_method("local_wizard"):
		return world.call("local_wizard")
	return null


func _is_corpse(body: Node3D) -> bool:
	return body.is_in_group("corpse") or (body.has_method("is_dead") and bool(body.call("is_dead")))


func _is_enemy(body: Node3D) -> bool:
	var slot := int(body.get("owner_slot")) if "owner_slot" in body else 0
	return slot != MpKit.local_slot()


## True when the first thing under the cursor is ground or nothing: not a creature, wizard,
## structure, altar, corpse or soul. Mask 15 = layers 1-4: ground, units, souls and corpses (layer 8).
func _is_empty_at(screen: Vector2) -> bool:
	var hit: Dictionary = _cast(screen, 15, false)
	if hit.is_empty():
		return true
	var body: Object = hit.get("collider")
	if body is Node:
		var node := body as Node
		if Attackable.is_body(node) or node.is_in_group("corpse") or node.is_in_group("soul_target") \
				or node.is_in_group("structure") or node.is_in_group(Altar.GROUP):
			return false
	return true


func _ray_ground(screen: Vector2) -> Variant:
	var hit := _cast(screen, 1, true)
	return null if hit.is_empty() else hit.get("position")


func _unit_under(screen: Vector2) -> Node3D:
	var hit: Dictionary = _cast(screen, 2, false)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node3D and (body as Node).is_in_group("unit"):
		return body
	return null


## A wizard, creature or structure under the cursor, or null.
## `skip_own_wizard` ignores the local wizard.
func _body_under(screen: Vector2, skip_own_wizard: bool) -> Node3D:
	var skip: Array[RID] = []
	var own := _wizard()
	if skip_own_wizard and own is CollisionObject3D:
		skip.append((own as CollisionObject3D).get_rid())
	var hit: Dictionary = _cast(screen, 3, false, skip)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node3D:
		var node := body as Node
		if Attackable.is_body(node):
			return body
	return null


func _cast(screen: Vector2, mask: int, skip_wizards: bool, skip: Array[RID] = []) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var origin := cam.project_ray_origin(screen)
	var normal := cam.project_ray_normal(screen)
	var world := cam.get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + normal * 10000.0)
	query.collision_mask = mask
	var exclude := skip.duplicate()
	if skip_wizards:
		for wizard in get_tree().get_nodes_in_group("wizard"):
			if wizard is CollisionObject3D:
				exclude.append((wizard as CollisionObject3D).get_rid())
	query.exclude = exclude
	return world.direct_space_state.intersect_ray(query)
