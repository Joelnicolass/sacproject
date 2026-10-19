@tool
class_name LookProfile
extends Resource

## What one biome uses to look the way it does: references only, so each part is swapped alone.
## Every socket is neutral when empty. A GodTheme with `look = null` is the classic mode.
## 022a only defines the shape; each later cut gives its socket a typed Resource and a layer.

@export var god: StringName = &""
## Name shown by the gallery.
@export var label: String = ""

@export_group("Sockets (filled by later cuts)")
## 022c: GroundSet (PBR ground layers by zone, slope and height).
@export var ground: GroundSet
## 022e1: GrassSet (the stylized grass around the camera).
@export var grass: GrassSet
## 022e2: ScatterSet.
@export var scatter: Resource
## 022d: SkyLook (layers over the original sky, plus the invisible source for ambient and fog).
@export var sky: SkyLook
## 022b: sun, shadows, fill, ambient, exposure, SSAO.
@export var light: LightLook
## 022f: AtmosphereLook.
@export var atmosphere: Resource
## 022h: color correction, one gradient per god.
@export var grade: GradientTexture1D
