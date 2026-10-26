# fx
What: every visual effect is a typed Resource (ParticleType, BeamType, or a PackedScene whose root is an FxScene) played through the `FxBus` autoload at a socket of a body or a Marker3D.
Not: sounds (SoundBus), the simulation (nothing in `sim` reads an effect), blood (RFC-060), GPUParticles3D.
Talks to: a node calls `FxBus.broadcast(fx, BodyFacts.point(body, socket))` -> one RPC carries `FxWire.id_of(fx)` (the resource path) -> each peer's `FxWire.resource(id)` -> `%Bursts` / `%Beams` pools draw it. Every play emits `FxBus.played(kind, fx, at)` first: FxSounds (the `sound` of the type), CameraShake (its `camera_trauma`, fall-off in `ShakeMap`), checks and the agent listen. A headless process only emits `played`.
Edit: the look, light (`FxLightSpec`), `sound` and `camera_trauma` live in the effect's `.tres` (data/fx); where it leaves from is `@export var <role>_socket: BodyFacts.Socket` or a Marker3D of the scene (`BurstSpot`, `SummonSpot`).
Check: rules_suite `fx_wire_cases` (ids round trip, camera_trauma, headless `played`, sockets) · debug/fx/fx_gallery.tscn (one typed `FxSlot` per type) · debug/fx/fx_sockets_lab.tscn (F6, `check_tick`) · agent/harness/fx_sockets_capture.gd, fx_net_probe.gd.
Add: a burst = duplicate a `.tres` of data/fx and drag it onto the field; a scene effect = a scene whose root extends `FxScene` (override `play(params)`, set `camera_trauma` in the inspector), dragged onto an `@export var x: PackedScene`. The pool warms up by itself and the id comes from the path.
Transition (055x x1..x6): `FxBus` still accepts a String (an old `data/fx` name or a scene path) and `FxWire.as_particle/as_beam/as_scene` resolve it, warning once about an unknown name; x7 removes that door. Migrate data with `python3 tools/migrate/fx_refs_055x.py --dry-run --dirs <folders>`.

---

Efectos: rayos, atlas de FX, shaders y partículas del juego. Un efecto nuevo es una packed scene con su shader; el bus es `FxBus`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/fx/`.
