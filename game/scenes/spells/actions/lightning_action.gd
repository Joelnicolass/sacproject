class_name LightningAction
extends AimedAction

## Lightning (ntil): an instant strike on a living enemy when the casting ends (sacengine castLightning).
## The bolt is a BeamType drawn by FxBus; the damage is DamageMod.lightning, which charges a Storm Giant.

const _HEALTH := preload("res://scenes/components/health.gd")

## BeamType of the strike (res://data/fx/beams/), RFC-029 029d.
@export var beam := "lightning"


func finish(wizard: WizardBody, spell: SpellType, target: Node3D) -> String:
	if target == null or not _ROCK.is_live_body(target):
		return ""
	## F130: DamageMod.lightning, which charges a Storm Giant (state.d:9017-9022).
	var taken := (target.get_node("Health") as Health).damage_typed(float(spell.damage), _HEALTH.DIRECT_SPELL, wizard.owner_slot, false, false, _HEALTH.LIGHTNING)
	_ROCK.report(target, taken, _HEALTH.DIRECT_SPELL)
	FxBus.broadcast_beam(beam, _origin(wizard), _ROCK.body_center(target), target)
	return ""


## sacengine updateLightningCasting (state.d:16322-16341): the bolt starts 0.5 above the top of the
## wizard's hitbox and 0.75 ahead of its front. Presentation only.
func _origin(wizard: WizardBody) -> Vector3:
	var facts := BodyFacts.of_body(wizard)
	var at := wizard.global_position + Vector3(0.0, facts.top.y + 0.5, 0.0)
	at += wizard.facing_flat() * (facts.reach_m + 0.75)
	return at
