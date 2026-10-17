class_name SkeletalCompareSetup
extends Resource

## RFC-023 (023b): where debug/skeletal_compare.tscn starts. skeletal_compare_jnwr.tres opens on the wizard casting.
## Pass it with `-- --setup=res://debug/skeletal_compare_jnwr.tres`.

@export var model := "eorc"
@export var role := "idle"
## Start with the original's frame by frame look (nearest key) instead of the smooth interpolation.
@export var stepped := false
