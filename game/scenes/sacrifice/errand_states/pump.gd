extends ErrandStep

## Convert: the doctor stands over the corpse and pumps it back to life. When it starts the creature
## stands up with max(400, 50 % of its max health) and is nobody's target; the doctor works (soul
## number + 1) times rules.convert_pump_s_per_soul seconds, then the soul is gone, the creature is
## taken and goes on to Haul. If the site falls the doctor dies. If the doctor dies here,
## CarryErrand drops the creature (it dies again and leaves its soul on its own side): the soul that
## was hidden while it pumped is replaced by the one its new death drops.

## The burst over the corpse when it stands up (scenes/fx/effects/heal.tres).
@export var heal_fx: ParticleType
## Where on the corpse it bursts (a socket of its BodyFrame: move the marker there with the gizmo).
@export var heal_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER

var _left := 0.0
## The corpse really stood up: only then there is something to undo if the doctor dies.
var _pumping := false


func enter() -> void:
	super.enter()
	_pumping = false
	var body := errand.body
	var soul := errand.soul
	var corpse := soul.corpse as UnitBody if soul != null and is_instance_valid(soul) else null
	var captive := Captive.of(corpse) if corpse != null else null
	var rules := body.rules
	if (
		captive == null
		or not captive.revive(
			rules.convert_revive_min_health if rules else 400.0,
			rules.convert_revive_fraction if rules else 0.5
		)
	):
		# If the revive fails, the soul is freed and the doctor dies.
		errand.release_soul()
		body.kill()
		return
	_pumping = true
	errand.creature = corpse
	errand.captive = captive
	soul.state = Soul.State.REVIVING
	_left = SacrificeMath.pump_seconds(soul.number, rules.convert_pump_s_per_soul if rules else 5.0)
	body.begin_work(DoctorBody.Work.PUMP)
	if heal_fx != null:
		FxBus.broadcast(heal_fx, BodyFacts.point(corpse, heal_socket))


func physics_update(delta: float) -> void:
	var body := errand.body
	if body.is_dead():
		return
	if not errand.site_standing():
		body.kill()
		return
	_left -= delta
	if _left > 0.0:
		return
	body.end_work()
	_drop_soul()
	if errand.captive == null or not errand.captive.take(body):
		body.kill()
		return
	transition(&"Haul")


## The creature keeps its soul from now on; the one on the map goes.
func _drop_soul() -> void:
	var soul := errand.soul
	errand.soul = null
	if soul != null and is_instance_valid(soul):
		soul.queue_free()
