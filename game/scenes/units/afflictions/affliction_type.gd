class_name AfflictionType
extends Resource

## F120 (RFC-030i): what a state that takes a creature out of the fight (stunned, petrified, later frozen) means to
## the rest of the body. One .tres per state; the Affliction child of Afflictions that plays it points here. Afflictions
## is the only one that answers the body's questions, by these flags of the states that are on.

## The state's name in the log and in `cancels`.
@export var id: StringName = &""
## Its bit in Afflictions.shown (the mask replicated to the clients). One bit per type.
@export_range(0, 30) var bit := 0
## No AI, no orders carried out, no attacks, no turning, no ability (sacengine stunned: the mode switch skips them).
@export var holds := true
## The body is not seen, not hit and not in the way while it lasts (Firewalking: sacengine mode firewalk, state.d:124, 135, 141).
@export var hides := false
## Not even pushed: no separation and no pose (petrified, `effects.immobilized`).
@export var immobilizes := false
## A flier falls while it lasts (sacengine petrify startTumbling, state.d:11636): Flight lets gravity take it down to
## the ground and the body goes back up to its height when it ends. Off: a flier hangs where it is (stunned).
@export var drops_fliers := false
## Ends the body's own special mode when it starts (Rockform: sacengine petrify sets mode = stunned, state.d:11631-11640),
## so the rock's ×0.05 does not stack and the end can knock it down. The body reads it (UnitBody, on held_changed).
@export var breaks_special_modes := false
## Multiplies every hit the body takes while it lasts (petrified ×0.2, state.d:8965). Stunned: 1.
## Only for shields (dealDamage's `!peirceShield` block, state.d:8962-8969): a pierce_shield hit (the Pyromaniac's fire,
## F123) skips it in Health. A state whose factor is not a shield needs its own field, not this one.
@export var damage_factor := 1.0
## F159: the body cannot be moved from outside nor walk (sacengine effects.fixed = vined, state.d:8588-8590, stats.d:94): the Grasping
## Vines. Unlike `immobilizes` it still is an obstacle (the separation pushes others, not it) and keeps its pose and its AI.
@export var pins := false
## F159: the body does not regenerate while it lasts (sacengine regenerationBlocked: immobilized, rings of fire, slimed, vined, stats.d:73).
@export var blocks_regeneration := false
## Refuses the crowd control that asks ccProtected (petrify, state.d:11631-11640).
@export var cc_protects := false
## Blind Rage (sacengine isBlindlyRaging, state.d:1143): no order is carried out, no shot is fired and the target is the closest creature of any side.
@export var rages := false
## The ids of the states this one ends when it starts. A state that is on refuses a new one unless the new one
## cancels it, so who wins is said here, not by the order of the children (sacengine canStun refuses `stunned`).
@export var cancels: Array[StringName] = []
## F155: lives next to the other states (Oiled): admit neither refuses it for a state that is on nor refuses the others
## for it, and it cancels nothing. Off (default): the exclusive rule above.
@export var coexists := false
## F149: the mesh look while it is on (Afflictions.look, one StoneLook per body): a tint of the stone shader. Off: the
## state draws nothing on the mesh. Among the states that are on, the highest look_priority wins (petrified over frozen).
@export var has_look := false
@export var look_tint := Color(1.0, 1.0, 0.8)
@export var look_priority := 0
## F155: the rest of the stone shader's knobs for this look (the defaults are the stone's; the oil is dark and glossy).
@export var look_base := 0.3
@export var look_gain := 0.7
@export var look_roughness := 0.5
@export var look_metallic := 0.5
## A state that draws the body with another texture on every surface while it lasts (Slime: the wet skin `lthg`), with the surface's own UV
## and light. Applies together with the stone look when the body also has one. Off (empty): the state does not change the texture.
@export var look_texture: Texture2D
