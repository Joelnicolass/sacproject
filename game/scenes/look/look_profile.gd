@tool
class_name LookProfile
extends Resource

## What one biome uses to look the way it does: references only, so each part is swapped alone.
## `GodType.look` points at one of these (`data/look/<god>.tres`). A part left empty is neutral:
## its layer simply has nothing to show.

@export var display_name: String = ""
## The god of this biome (`data/gods/<god>.tres`): a map made of its land wears its own ground (NativeGround).
@export var god: StringName = &""

@export_group("Sky and light")
## The sky, the fog and the ambient (see SkyLook).
@export var sky: SkyLook
## Sun, shadows, fill, exposure and screen-space light.
@export var light: LightLook
## Bloom of the bright parts.
@export var glow: GlowLook
## Color correction, one gradient per god.
@export var grade: GradientTexture1D

@export_group("Ground and plants")
## The original's flat ground (atlas, edge and light map): what the terrain wears when `ground` is empty.
@export var ground_classic: ShaderMaterial
## PBR ground layers by zone, slope and height.
@export var ground: GroundSet
## The stylized grass around the camera.
@export var grass: GrassSet
