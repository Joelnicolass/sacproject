@tool
class_name LifeShield
extends Ward

## The Druid's and the Shrike's Life Shield (hsba) and the Ent's Protector (HSba, on itself and its allies): a Ward that halves
## every hit for the SPEL's duration. It adds only how an ability starts it. The rest (time, factor, look) is Ward.
## Ref: sacengine lifeShield (state.d:13092-13100), updateLifeShield removes it at frame 1200 (state.d:25122-25155).


## The LifeShield of `node`, or null (a body without one is never shielded).
static func of(node: Node) -> LifeShield:
	return (node.get_node_or_null("Wards/LifeShield") as LifeShield) if node else null


## Server (or solo): the shield of an ability (Life Shield, Protector) for its duration.
func start_for_ability(ability: AbilityType) -> bool:
	return start(ticks_for(ability))


static func ticks_for(ability: AbilityType) -> int:
	return ticks_for_seconds(ability.duration_s if ability else 20.0)
