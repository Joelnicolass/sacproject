@tool
class_name AmbientLifeSet
extends Resource

## The ambient life of one god (embedded in `scenes/look/<god>.tres` -> Life): the swarms in the air
## around the camera (at most three, the rig's pool) and the ones each habitat of the map shows in
## its LifeSpots. In each list the first swarm that shows at this hour and weather is the one drawn
## (so «pollen, then fireflies» = pollen by day, fireflies by night). Swarms are shared `.tres` from
## `scenes/look/life/`.

## Where a LifeSpot lives on the map.
enum Habitat { MEADOW, WATER, WOODS, ROCK }

## Swarms around the camera, one per slot of the rig's pool (Air1..Air3).
@export var air: Array[AmbientSwarm] = []

@export_group("Habitats")
@export var meadow: Array[AmbientSwarm] = []
@export var water: Array[AmbientSwarm] = []
@export var woods: Array[AmbientSwarm] = []
@export var rock: Array[AmbientSwarm] = []


## The swarm a spot of `habitat` shows now (null = none).
func swarm_for(habitat: Habitat, sample: AtmosphereSample) -> AmbientSwarm:
	var listed: Array[AmbientSwarm] = [meadow, water, woods, rock][habitat]
	for swarm in listed:
		if swarm and swarm.shows_in(sample):
			return swarm
	return null
