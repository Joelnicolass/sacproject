# fx

Visual effects. Every effect is a typed resource (`ParticleType`, `BeamType`) or a `PackedScene` whose root extends
`FxScene`, played by the `FxBus` autoload at a body socket or a `Marker3D`.
- `FxBus.broadcast*` sends one RPC with the resource path (`FxWire`); `FxBus.play*` is local. A headless process only
  emits `FxBus.played` (sounds, camera shake and checks listen to it).
- No API takes an effect by name: drag the `.tres` or scene onto an `@export`. Look, light, sound and `camera_trauma`
  live in the effect's `.tres` in `scenes/fx/effects/`.
