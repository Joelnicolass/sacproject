class_name WizardLightTint
extends Node

## Paints the wizard's `ActorLight` with its god's `magic_color` whenever the pick (and so the god) changes.
## Presentation only: nothing in the simulation reads it.

@export var wizard: WizardBody
@export var light: ActorLight


func _ready() -> void:
	wizard.pick_changed.connect(_tint)
	_tint()


func _tint() -> void:
	var type := GameCatalog.shared().god(wizard.god)
	if type != null and is_instance_valid(light):
		light.tint(type.magic_color)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray([] if wizard and light else ["Assign `wizard` and `light`."])
