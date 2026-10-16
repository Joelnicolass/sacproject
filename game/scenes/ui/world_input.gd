class_name WorldInput
extends RefCounted

## RFC-031 031c (F142): the one owner of «does the player's input reach the world?».
## A node that covers the world with a modal UI (PauseMenu, OptionsMenu) joins the group `MODAL` while it is open;
## the readers of world input (MatchCommand, WizardBody._read_forward, WorldCamera, SoulSystem) ask `blocked(self)`.
## Per-channel policies (a chat that blocks keys but not the camera) get added here when one is needed.
##
## The group keeps its 031b name, `menu_open`: the AgentKit harnesses of F141 (pt141_watch, pt141_play) count it.

const MODAL := &"menu_open"


## True while a modal UI is open in `from`'s tree (false outside a tree).
static func blocked(from: Node) -> bool:
	if from == null or not from.is_inside_tree():
		return false
	return from.get_tree().get_first_node_in_group(MODAL) != null
