class_name TargetInfo
extends RefCounted

## RFC-053 053e (F374): what the info box says about a body (sacengine's mouse-over box, renderer.d:5036-5230, described, not
## copied). `describe` is the one owner of that text and of the health the box shows; it reads the body and writes nothing.
## - Creature (or Sac Doctor): its icon and «<name> de <wizard of its side>»; an NPC side or nobody's: «<name> de la aldea».
## - Wizard: its name.
## - Building: `BuildingType.display_name`, else «Edificio». Altar and manafount have fixed names; the Manalith and the Shrine take theirs from their BuildingType.
## - Corpse: «Cadáver de <name>». Soul: «Alma»; a red soul for `local_slot` (another side's): «Alma pagana. Convertila.».
## - `fraction` = current / maximum of its Health; NaN when it has none or its maximum is 0 (indestructible): no bar.

var title := ""
var icon: Texture2D
## 0…1, or NaN (no bar).
var fraction := NAN
## The Health the bar follows (null when there is no bar).
var health: Health


func has_bar() -> bool:
	return not is_nan(fraction)


## What the box says about `node` seen by `local_slot`, or null when it has nothing to say (ground, a freed node).
static func describe(node: Node, local_slot: int) -> TargetInfo:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null
	var info := TargetInfo.new()
	if node is Soul:
		var red := (node as Soul).color_for(local_slot) == Soul.SoulColor.RED
		info.title = UiText.t(&"TARGET_INFO_SOUL_PAGAN" if red else &"TARGET_INFO_SOUL")
		return info
	if node.is_in_group("corpse") or _is_dead(node):
		info.title = UiText.t(&"TARGET_INFO_CORPSE") % _name_of(node)
		return info
	if node is Altar:
		info.title = UiText.t(&"TARGET_INFO_ALTAR")
		return info
	if node is ManafountBody:
		info.title = UiText.t(&"TARGET_INFO_MANAFOUNT")
		return info
	if node is MapBuilding:
		var type := (node as MapBuilding).type
		var named := type != null and not type.display_name.is_empty()
		info.title = type.display_name if named else UiText.t(&"TARGET_INFO_BUILDING")
	elif node is WizardBody:
		info.title = (node as WizardBody).display_name()
	elif node.has_method("display_name") and "owner_slot" in node:
		info.title = _creature_title(node)
		info.icon = CreatureType.icon_of(node)
	else:
		return null
	_read_health(info, node)
	return info


static func _creature_title(node: Node) -> String:
	var slot := int(node.get("owner_slot"))
	var who := _name_of(node)
	if slot <= 0 or SideRelations.is_npc_slot(slot):
		return UiText.t(&"TARGET_INFO_VILLAGE") % who
	var wizard := wizard_name(node.get_tree(), slot)
	return who if wizard.is_empty() else UiText.t(&"TARGET_INFO_OF") % [who, wizard]


## The name of the wizard of `slot` in `tree` ("" when there is none).
static func wizard_name(tree: SceneTree, slot: int) -> String:
	if tree == null:
		return ""
	for wizard in tree.get_nodes_in_group("wizard"):
		if wizard is WizardBody and (wizard as WizardBody).owner_slot == slot:
			return (wizard as WizardBody).display_name()
	return ""


static func _read_health(info: TargetInfo, node: Node) -> void:
	var health := node.get_node_or_null("Health") as Health
	if health == null or health.maximum <= 0.0:
		return
	info.health = health
	info.fraction = clampf(health.current / health.maximum, 0.0, 1.0)


static func _name_of(node: Node) -> String:
	if node.has_method("display_name"):
		return str(node.call("display_name"))  # dynamic: unit, wizard and doctor bodies answer it
	return str(node.name)


## A creature or doctor that died and is not a corpse yet (it is falling): the cursor already calls it a corpse.
static func _is_dead(node: Node) -> bool:
	return (node is UnitBody or node is DoctorBody) and bool(node.call("is_dead"))  # dynamic: both answer it
