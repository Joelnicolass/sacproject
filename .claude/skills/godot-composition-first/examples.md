# Examples — composición (genéricos)

Nada de un título concreto. Copiá y adaptá.

## Actor como contenedor

```
Actor (CharacterBody2D)
├── Visual         Sprite2D
├── Health         packed scene
├── States         FsmMachine
│   ├── Idle
│   ├── Move
│   └── Hurt
└── MultiplayerSynchronizer
```

Preferí el addon `fsm_kit` (`./install.sh --addon … fsm_kit`) a copiar una clase. `/add-state-machine`.

```gdscript
class_name IdleState
extends FsmState


func physics_update(_delta: float) -> void:
	if absf(actor.velocity.x) > 8.0:
		transition(&"Move")
```

## Socket `@export` + UniqueName

```gdscript
@export var health: Health
@onready var sprite: Sprite2D = %Sprite2D


func _get_configuration_warnings() -> PackedStringArray:
	if health == null:
		return PackedStringArray(["Assign a Health component."])
	return PackedStringArray()
```

## Resource de tipo + una escena

```gdscript
class_name ProjectileData
extends Resource

@export var display_name: String = "Default"
@export var damage: int = 1
@export var speed: float = 400.0
```

Un `projectile_fast.tres` y un `projectile_slow.tres` apuntan a la misma `projectile.tscn`.

## Juicy con Tween + inspector

```gdscript
@export_group("Land squash")
@export var squash_scale: Vector2 = Vector2(1.2, 0.8)
@export var squash_duration: float = 0.08
@export var recover_duration: float = 0.12

func play_land() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(%Visual, "scale", squash_scale, squash_duration)
	tw.tween_property(%Visual, "scale", Vector2.ONE, recover_duration)
```

Doce principios: [godot-animation](../godot-animation/SKILL.md). Este clip es one-shot paramétrico → Tween. Varios tracks / loop authorado → `AnimationPlayer`. No hardcodees esos floats.
