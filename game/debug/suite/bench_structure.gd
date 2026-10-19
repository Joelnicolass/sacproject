class_name BenchStructure
extends Resource

## A structure the bench puts on the field before the match starts (RFC-024 024c): the AI's original accounting needs a
## Manalith (pool of mana = max mana x Manaliths, shiny.d:3140), so the debug scenes begin with one on the fount of
## the AI. It goes through the StructureSpawner like a built one and takes the fount.

@export var slot := 2
## SpellType tag of the structure (htlm = Manalith).
@export var spell_tag := "htlm"
## Name of the manafount under MapProps/Founts that it takes.
@export var fount := "FountWest"
