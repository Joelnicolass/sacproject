class_name BodyMount
extends Node

## Which body scene a creature, wizard or doctor wears, and the size and sockets that come with it (BodyFacts).
## It is the one place that says it: whoever sets the type of the body calls `wear(type.body)`, and everyone else (BodyCollider,
## the melee, the avoidance) reads `facts` or listens to `worn`. Wearing the same scene twice does nothing, so it can be asked
## in any order (spawn, replication, a late join).
## What it does not do: size the physics capsule (BodyCollider), draw the model or play sounds (the appearance, which comes later).

## The body now wears another scene; `facts` are its size and sockets.
signal worn(facts: BodyFacts)

## The body scene being worn (scenes/units/bodies/<name>.tscn or scenes/wizards/bodies/<name>.tscn); null until the first `wear`.
var scene: PackedScene
## The facts of `scene`; the unknown-model default until something is worn.
var facts: BodyFacts = BodyFacts.fallback()


## Dresses the body in `body`. The same scene again is ignored; an empty one keeps what is worn.
func wear(body: PackedScene) -> void:
	if body == null or body == scene:
		return
	scene = body
	facts = BodyFacts.of(body)
	worn.emit(facts)


## True once a scene has been worn.
func is_worn() -> bool:
	return scene != null
