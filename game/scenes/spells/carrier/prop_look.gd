@tool
class_name PropLook
extends MeshInstance3D

## Draws one of the game's static prop models with its textures, at this node's place and size: the Soul Mole's rock.
## It does not move, spin or hide it; the node it hangs from does. Never draws in a headless process (the mesh is not loaded there).

## The prop's name (the Soul Mole's rock is "rock").
@export var model := "rock":
	set(value):
		model = value
		if is_node_ready():
			_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	mesh = BodyCatalog.mesh(model)
