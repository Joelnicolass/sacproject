class_name HaloOfEarthAbility
extends AbilityEffect

## F127 (RFC-030 030p-a): the Rhinok's Halo of Earth (HRba). sacengine haloOfEarth (state.d:13232-13236) always applies
## (the cooldown, 40 s, outlives the rocks, 35 s): no preparation, no rule of its own. AbilitySlot spends the 650 mana and
## starts the cooldown when fire() returns true. fire() puts a HaloOfEarth coordinator in the shot container (the node
## the shot spawner spawns into), which makes the 6 rocks from the next tick.

## The coordinator's scene (halo_of_earth.tscn).
@export var halo_scene: PackedScene


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority() or halo_scene == null:
		return false
	var spawner := get_tree().get_first_node_in_group(&"shot_spawner")
	var container := spawner.get_node_or_null(spawner.get("spawn_path")) if spawner != null else null
	if container == null:
		push_warning("HaloOfEarthAbility: no hay contenedor de disparos (grupo shot_spawner).")
		return false
	var halo := halo_scene.instantiate() as HaloOfEarth
	if halo == null:
		push_warning("HaloOfEarthAbility: halo_scene no es un HaloOfEarth.")
		return false
	halo.setup(user, ability, spawner)
	container.add_child(halo)
	return true
