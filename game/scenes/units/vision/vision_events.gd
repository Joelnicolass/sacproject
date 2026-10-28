class_name VisionEvents
extends RefCounted

## The news of every Vision in one place (`VisionSides.events`): a body was learned by a Vision of
## side `side`, because it came into sight while that Vision did not have it in mind (absent, or
## remembered once but lapsed), or because it struck a body of that side. Whoever wants to know what
## the sides see listens here instead of asking every tick (the AI's SightIntake). It only
## announces: it keeps nothing and does not decide what anyone knows.

signal learned(side: int, node: Node3D)
