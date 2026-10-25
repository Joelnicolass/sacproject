class_name RitualStarter
extends Node

## Starts the ritual when a carrier reaches its site holding the creature: it spawns the ritual and the four doctors of the ring and hands
## the creature over. If the site is taken the carrier waits and is tried again every frame (SacrificeSystem calls retry_waiting first).
## What it does not do: run the rounds (Ritual does), choose the site or open the cast.
## Ref: sacengine updateSacDocCasting / ritual start, state.d:15780, 15866.

@export var system: SacrificeSystem
@export var spawns: SacrificeSpawns
@export var targets: SacrificeTargets

## Carriers at their site waiting for it to be free (a second carrier waits).
var _waiting: Array[CarryErrand] = []


## A carrier reached its site: tell the system, start the ritual if the site is free, else wait.
func on_reached(errand: CarryErrand) -> void:
	print("sacrificio: el portador de slot %d llegó al altar de slot %d" % [errand.caster_slot, errand.site.owner_slot()])
	system.carrier_arrived.emit(errand)
	if start(errand) == null:
		_waiting.append(errand)


## Tries again the carriers that were waiting; drops the ones that are gone.
func retry_waiting() -> void:
	var still: Array[CarryErrand] = []
	for errand in _waiting:
		if not is_instance_valid(errand) or not errand.is_carrying():
			continue
		if start(errand) == null:
			still.append(errand)
	_waiting = still


## The carrier holds its creature at the site: the ritual starts if the site is free. Returns the ritual, or null if it has to wait.
func start(errand: CarryErrand) -> Ritual:
	var site := errand.site
	if site == null or not errand.is_carrying() or not site.is_standing() or not site.is_free():
		return null
	var facts := system.facts()
	var center := site.center()
	var creature := errand.creature
	var ritual := spawns.spawn_ritual({
		"name": spawns.next_ritual_name(),
		"x": center.x, "y": center.y, "z": center.z,
		"kind": int(errand.kind),
		"caster": errand.caster_slot, "target": site.owner_slot(),
		"creature": str(creature.get_path()),
	})
	if ritual == null:
		return null
	if not site.occupy(ritual):
		ritual.queue_free()
		return null
	var ring: Array[DoctorBody] = []
	for k in 4:
		var at := SacrificeMath.ring_point(center, k, 0.0, facts.ring_m, facts.walk_shrink_m())
		at.y = SacrificeGround.height(self, at)
		var doctor := spawns.spawn_doctor({
			"name": spawns.next_doctor_name(),
			"x": at.x, "y": at.y, "z": at.z,
			"yaw": SacrificeMath.yaw_toward(at, center),
			"slot": errand.caster_slot, "ritual": true,
		})
		if doctor != null:
			ring.append(doctor)
	## The carrier hands the creature over and is gone ("the carrier dies"): the ritual moves it now.
	if errand.captive != null:
		errand.captive.hand_to_ritual()
	errand.hand_over()
	errand.body.kill()
	## Convert drains nobody: it has no wizard to name.
	ritual.begin(creature, site, ring, targets.wizard_of(site.owner_slot()) if errand.kind == Ritual.Kind.DESECRATE else null)
	return ritual
