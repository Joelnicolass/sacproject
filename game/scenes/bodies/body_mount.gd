class_name BodyMount
extends Node

## Which body scene a creature, wizard or doctor wears, the size and sockets that come with it
## (BodyFacts) and, on a client, the look it is drawn with (BodyLook). It is the one place that says
## it: whoever sets the type of the body calls `wear(type.body)`, and everyone else (BodyCollider,
## the melee, the avoidance, the sounds) reads `facts` and `look` or listens to `worn` and
## `dressed`. Wearing the same scene twice does nothing, so it can be asked in any order (spawn,
## replication, a late join).
## What it does not do: size the physics capsule (BodyCollider), play a clip (BodyRig) or load
## anything on the server: the look is built only where meshes are drawn.

## The body now wears another scene; `facts` are its size and sockets.
signal worn(facts: BodyFacts)
## A client built the look of the scene being worn and handed it to the rig.
signal dressed(look: BodyLook)

## Where the look goes (the BodyRig under the visual). Empty: the body is never drawn (a server-only
## or test body).
@export var rig: BodyRig

## The body scene being worn (scenes/units/bodies/<name>.tscn or scenes/wizards/bodies/<name>.tscn);
## null until the first `wear`.
var scene: PackedScene
## The facts of `scene`; the unknown-model default until something is worn.
var facts: BodyFacts = BodyFacts.fallback()
## The look being worn: its model, sounds and carried effect. Null on a server and until something
## is worn.
var look: BodyLook

var _sounds_of: PackedScene
var _saved_sounds: SoundSet


## Dresses the body in `body`. The same scene again is ignored; an empty one keeps what is worn.
func wear(body: PackedScene) -> void:
	if body == null or body == scene:
		return
	scene = body
	facts = BodyFacts.of(body)
	worn.emit(facts)
	_dress(body)


## True once a scene has been worn.
func is_worn() -> bool:
	return scene != null


## The sounds of the look being worn; null without one (a silent creature). A body that draws
## nothing (a headless client with audio, such as the audio probe) reads them from the saved look
## without building it. Only the sound nodes ask, and the server has none playing, so it never loads
## a look.
func sounds() -> SoundSet:
	if look != null:
		return look.sounds
	if scene == null:
		return null
	if _sounds_of != scene:
		_sounds_of = scene
		_saved_sounds = BodyLook.sounds_in(BodyLook.of_body(scene))
	return _saved_sounds


## Builds the look of the worn scene and gives it to the rig. A client only: the server and the room
## server draw nothing.
func _dress(body: PackedScene) -> void:
	if rig == null or not BodyLook.loads_meshes():
		return
	var packed := BodyLook.of_body(body)
	look = null
	if packed == null:
		return
	look = packed.instantiate() as BodyLook
	if look == null:
		return
	rig.mount(look)
	dressed.emit(look)
