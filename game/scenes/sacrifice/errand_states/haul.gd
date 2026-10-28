extends ErrandStep

## The doctor walks to the ritual site with the creature hanging behind it (Captive follows it).
## If the creature is gone or the site fell, the doctor dies; on the ground and closer than `carrier_stop_m` of SacrificeFacts (3D) it
## stops and says `reached_site`. From then on it waits holding the creature: the ritual starts from that signal (and takes the errand
## over); until then, and while the site is busy, the carrier stays. If the doctor dies here the creature is let go: alive, its
## original owner's, falling to the ground.


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
	if body.is_targetable() and body.global_position.distance_to(center) < SacrificeFacts.of_rules(body.rules).carrier_stop_m:
		errand.arrive()
		return
	body.motor.walk_to(center)
