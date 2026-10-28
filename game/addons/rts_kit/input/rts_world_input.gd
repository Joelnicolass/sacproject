class_name RtsWorldInput
extends RefCounted

## The one owner of "does the player's input reach the world?". A node that covers the world with a
## modal UI (a pause menu, an options screen) joins the group `modal_group` while it is open; every
## reader of world input in the kit (RtsCommandInput, RtsSelectInput, RtsOrderButton, the cameras)
## asks `blocked(self)`.

## The group a modal UI joins while it is open. A game whose modals already join another group sets
## this once at startup.
static var modal_group: StringName = &"rts_modal"


## True while a modal UI is open in `from`'s tree (false outside a tree).
static func blocked(from: Node) -> bool:
	if from == null or not from.is_inside_tree():
		return false
	return from.get_tree().get_first_node_in_group(modal_group) != null
