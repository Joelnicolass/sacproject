@tool
class_name GodStructure
extends Resource

## One structure a god raises: the spell that casts it and the tower scene that appears over the manafount (that god's
## Manalith or Shrine). Lives in GodType.structures. Does not cast anything: StructureAction does.

@export var spell: SpellType
@export var scene: PackedScene
