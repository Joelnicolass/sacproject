# Recetas juicy (Godot 4)

Knobs `@export`. IDs en inglés. El padre llama `play()` / `play_hit()`.

## Camera shake (2D)

Hijo de `Camera2D`. Trauma 0–1, decay por segundo, ruido en `offset`.

```gdscript
class_name CameraShake
extends Node

@export var decay: float = 1.6
@export var max_offset: Vector2 = Vector2(12, 10)
@export var max_roll: float = 0.04

var trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _cam: Camera2D


func _ready() -> void:
	_cam = get_parent() as Camera2D
	_noise.seed = randi()
	_noise.frequency = 18.0


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if _cam == null:
		return
	if trauma <= 0.0:
		_cam.offset = Vector2.ZERO
		_cam.rotation = 0.0
		return
	trauma = maxf(trauma - decay * delta, 0.0)
	var t := trauma * trauma
	var n := Time.get_ticks_msec() * 0.001
	_cam.offset = Vector2(
		max_offset.x * t * _noise.get_noise_2d(n, 0.0),
		max_offset.y * t * _noise.get_noise_2d(0.0, n)
	)
	_cam.rotation = max_roll * t * _noise.get_noise_2d(n, n)
```

3D: mismo trauma sobre `h_offset` / `v_offset` de `Camera3D`, o un `Node3D` pivot padre de la cámara.

## Hit squash

Ver [godot-animation](../godot-animation/SKILL.md). Tween si es un punch de escala; `AnimationPlayer` si el hit mueve varios sprites.

## Partículas one-shot

`GPUParticles2D`: `one_shot = true`, `explosiveness` alta, `emitting = false` en editor. Al hit: `restart()`. Preset de cantidad / lifetime `@export`. No dejes `emitting` infinito en un impacto.

## Flash de pantalla

`CanvasLayer` + `ColorRect` full rect, `mouse_filter = IGNORE`, modulate.a 0. Tween a un `@export flash_alpha` y de vuelta a 0.

## Pass de post

[patterns.md](../godot-composition-first/patterns.md) § PostFx stack. Un efecto = una packed scene. Buscá en [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) antes de escribir un `.gdshader`. Gameplay tweenea `shader_parameter` del pass, no copia el shader.

## Hit-stop visual

```gdscript
@export var freeze_duration: float = 0.05

func play_freeze(anim: AnimationPlayer) -> void:
	anim.pause()
	await get_tree().create_timer(freeze_duration).timeout
	anim.play()
```

`Engine.time_scale` solo si es 1P y restaurás en el mismo método. No lo uses como default en MP.

## Cómo llamarlo

El sistema de daño emite `damaged` / el input llama `apply_attack`. Un hijo juicy escucha o el contenedor llama `juicy_hit.play()`. Lo jugoso **no** decide si el golpe es válido.
