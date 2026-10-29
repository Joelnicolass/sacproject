@tool
class_name RtsRadialRing
extends Resource

## One ring of a radial menu: its entries and its width. A ring can fill itself from the layout's
## catalogs (`fill`): every command (or the ones in `commands`, in that order) or every formation,
## after its own `entries`.

enum Fill { NONE, COMMANDS, FORMATIONS }

@export var entries: Array[RtsMenuEntry] = []
@export var fill := Fill.NONE
## Fill COMMANDS: only these command ids, in this order (empty = the whole catalog).
@export var commands: Array[StringName] = []
## Canvas pixels from its inner edge to its outer edge.
@export var width_px := 62.0
