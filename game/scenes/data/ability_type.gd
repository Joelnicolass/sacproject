class_name AbilityType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
@export var mana_cost: int = 0
@export var cast_range: float = 0.0
@export var cooldown_s: float = 0.0
@export var casting_time_s: float = 0.0
@export var speed: float = 0.0
@export var acceleration: float = 0.0
@export var damage: int = 0
## SPEL `amount2` (u32 at 96): what the AI's rater reads of an ability (shiny.d:175-180 `abilityAcc`).
@export var amount2: int = 0
@export var damage_range: float = 0.0
@export var effect_range: float = 0.0
@export var duration: float = 0.0
@export var flags: int = 0
@export var flags1: int = 0
@export var flags2: int = 0
