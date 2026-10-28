@tool
class_name LookProfile
extends Resource

## What one biome uses to look the way it does: references only, so each part is swapped alone.
## `GodType.look` points at one of these (`scenes/look/<god>.tres`). A part left empty is neutral:
## its layer simply has nothing to show.

@export var display_name: String = ""
## The god of this biome (`gods/<god>/<god>.tres`).
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

@export_group("Ambience")
## How the day goes by over the approved light (night, moon, stars). Empty = no cycle: always the
## approved light.
@export var day: DayCycle
## How the weather goes (the five gods share `scenes/look/weather/plan.tres`). Empty = always clear.
@export var weather: WeatherPlan
## Pollen, fireflies, embers...: in the air around the camera and in the map's LifeSpots. Empty = no
## ambient life.
@export var life: AmbientLifeSet

@export_group("Ground and plants")
## The god's four kinds of ground (open, earth, rock, path), laid on each map's ground roles. Empty
## = the plain «no look» ground.
@export var ground: GodGround
## The stylized grass around the camera.
@export var grass: GrassSet
## The god's trees, shrubs and ground cover, drawn where the map's FloraLayers paint those roles.
## Empty = every layer draws its own species.
@export var flora: GodFlora

@export_group("Audio")
## What plays in a match on this land: the music by mood. Empty: the match's default music.
@export var music: MusicSet
## The ambience of this land (bed and one-shots). Empty: no ambience.
@export var ambience: AmbienceSet
