class_name AiSightIntake
extends Node

## How what the side's Visions see reaches the AI. It hears every body a Vision learns (VisionSides.events.learned) and, when the AI
## looks (`take_new`), hands over the ones its side remembers now and the AI does not track yet, in name order. It also forgets a
## foe whose last known place one of the side's bodies is looking at while the foe is not there, and hands it back once the side
## sees it again. It does not look (Vision) nor decide anything; AiPerception adds and drops the tracks.
## Ref: shiny.d:616-635 botSeen.

## Bodies forgotten because the side looked where they were and they were not there.
var forgotten := 0

## Every body some Vision learned (any side: a body learned by a foe or by a side that later becomes an ally, or by a creature that
## later changes side, may be remembered by this side), by instance id. Freed bodies leave on the next `take_new`.
var _heard: Dictionary = {}
## id -> body of the foes forgotten by `forget_checked`, in the order they were forgotten.
var _lost: Dictionary = {}


func _enter_tree() -> void:
	if not VisionSides.events.learned.is_connected(_on_learned):
		VisionSides.events.learned.connect(_on_learned)
	## What the Visions learned before this side existed.
	for node in VisionSides.remembered():
		_heard[node.get_instance_id()] = true


func _exit_tree() -> void:
	if VisionSides.events.learned.is_connected(_on_learned):
		VisionSides.events.learned.disconnect(_on_learned)


func _on_learned(_side: int, node: Node3D) -> void:
	_heard[node.get_instance_id()] = true


## The bodies side `side` remembers now that are not in `tracks` yet, sorted by name: the ones the AI takes in.
func take_new(side: int, tracks: Dictionary) -> Array[Node3D]:
	var known := VisionSides.known(side)
	var found: Array[Node3D] = []
	for id: int in _heard.keys():
		var node := instance_from_id(id) as Node3D
		if node == null:
			_heard.erase(id)
			continue
		if known.has(id) and node.is_inside_tree() and not tracks.has(id):
			found.append(node)
	found.sort_custom(VisionRules.by_name)
	return found


## The bodies of another side (lists 1..3 of `bodies`) whose place `belief` does not know now (not seen, not on the minimap), whose
## last known place lies inside the sight of one of the side's own bodies (list 0), are not there any more (they would have been
## marked). They are kept as lost until the side sees them again; the caller drops their tracks (else a group seen near the wizard
## and gone stays there for good and keeps his threat up). The original never needs it: it reads the real position.
func forget_checked(bodies: Array, side: int, belief: AiBelief) -> Array[AiTrack]:
	var lookers: Array = []
	for own: AiTrack in bodies[0]:
		if own.is_valid():
			var eyes := VisionSides.of(own.node)
			var sight := eyes.range_m() if eyes != null else 0.0
			if sight > 0.0:
				lookers.append([own.node.global_position, sight * sight])
	var gone: Array[AiTrack] = []
	if lookers.is_empty():
		return gone
	for k in [1, 2, 3]:
		for t: AiTrack in bodies[k]:
			if not t.is_valid() or belief.knows_where(t, side):
				continue
			for looker: Array in lookers:
				var at: Vector3 = looker[0]
				if Vector2(t.cur_pos.x - at.x, t.cur_pos.z - at.z).length_squared() <= float(looker[1]):
					gone.append(t)
					break
	for t in gone:
		_lost[t.id] = t.node
		forgotten += 1
	return gone


## The lost bodies side `side` sees again, in the order they were lost: the caller knows them again (and marks them seen).
## Dead or freed ones are dropped.
func take_recalled(side: int) -> Array[Node3D]:
	var back: Array[Node3D] = []
	if _lost.is_empty():
		return back
	for id in _lost.keys():
		## Variant: the body may have been freed since (a typed Node3D would not take a freed instance)
		var held: Variant = _lost[id]
		if not is_instance_valid(held) or AiBody.is_dead(held as Node3D):
			_lost.erase(id)
			continue
		var node := held as Node3D
		if VisionSides.sees(side, node):
			_lost.erase(id)
			back.append(node)
	return back
