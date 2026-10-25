extends Node3D

## High Noon's earth hills from one fixed camera, wearing a god's ground (plan 062): the place where single rock cells showed
## as grey squares. What to look at: no lone square of another ground, and each god with its four kinds of ground.
## In the editor pick the god in `Map/Look` -> Preview god; with F6 the `god` below is applied. Only shows; simulates nothing.

const MAP_TAG := &"high_noon"

@export var map: MapRoot
@export var god: GodType
## A debug scene owns its preset (GraphicsApplier does not touch it here).
@export var quality: LookQuality


func _init() -> void:
	# The plants ask the active map for its tiles: it has to be this one before they are built.
	ActiveMatch.choose(MapCatalog.shared().find(MAP_TAG), null)


func _ready() -> void:
	_show.call_deferred()


func _show() -> void:
	if map == null or map.look == null:
		return
	if quality != null:
		map.look.apply_quality(quality)
	if god != null:
		map.look.apply_profile(god.look)
