extends ErrandStep

## The doctor walks to the ritual site with the creature hanging behind it (Captive follows it).
## sacengine SacDocCarry `move` (state.d:15750-15790): if the creature is gone or the site fell, the
## doctor dies; on the ground and closer than rules.ritual_start_distance (3D) it stops and says
## `reached_site`. From then on it waits holding the creature: RFC-020d starts the ritual from that
## signal (and hands the errand over); until then, and while the site is busy, the carrier stays.
## If the doctor dies here the creature is let go: alive, its original owner's, falling to the ground
## (state.d:15776-15779).


func physics_update(_delta: float) -> void:
	var body := errand.body
	if body.is_dead():
		return
	if not errand.is_carrying() or not errand.site_standing():
		body.kill()
		return
	if errand.arrived:
		return
	var center := errand.site.center()
	var start := body.rules.ritual_start_distance if body.rules else 20.0
	if body.is_targetable() and body.global_position.distance_to(center) < start:
		errand.arrive()
		return
	body.walk_to(center)
