class_name Pull
extends AbilityEffect

## The Gremlin's Web pull and the Seraph's Cage pull: they drag a foe to the caster. The same mechanic,
## two scenes (web_pull.tscn, cage_pull.tscn) that only change the look. The body prepares up to the load tick
## `liba` of its clip, frame 27, i.e. 2 · 27 = 54 ticks; there the pull starts and drains
## the mana. The pull has no cooldown (`starts_cooldown` off).
## This effect judges the target and starts the pull; the simulation of the pull is Pulling's (the user's state).
##
## Target (flags: creatures, wizards, no ally): a live
## creature or wizard that is not an ally, within the spell's range (50 m, feet to feet), and not shielded: the crowd control
## flag refuses a cc-protected body that is shielded (Life Shield); a petrified or frozen one, cc-protected but not shielded, is
## pulled all the same.
## fire(): a ray from the shot origin to the target's center; the first valid body on the way, of any
## side, becomes the target. A body, not a structure or a soul (declared in Pulling).

## The frame of the clip where the pull is loaded (`liba`, not exported: SPs1 and LSs1 have it at 27).
@export var load_frame := 27
## Which of the creature's shoot clips it plays (AbilityEffect.SHOOT_ROLES): 0 = `shoot`, 1 = `shoot2`.
@export var clip_index := 0
## How fast the target is pulled (m/s).
@export var pull_speed := 16.5
## The window after a pull in which the target is pulled along.
@export_range(0.0, 5.0, 0.0001, "suffix:s") var pull_s := 0.4166
## The stun cooldown of the first pull.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var stun_s := 8.0
## It ends when the target's box is this close to the user's center.
@export var min_thread := 3.0
## With this many pulls done it ends at the end of the clip loop.
@export var max_pulls := 4
## The thread (pull_thread.tscn / cage_thread.tscn), played by Pulling with FxBus.broadcast_scene.
@export var thread_scene: PackedScene
## The burst played at the target when it ends (64 particles), and the socket of the target it leaves from. Empty = none.
@export var break_fx: ParticleType
@export var break_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER


## 2 ticks per frame up to the load frame. The one owner of the preparation of a pull (AbilitySlot asks).
func windup() -> int:
	return FRAME_TICKS * load_frame


func status(_target_pos: Vector3, target: Node3D) -> String:
	if ability == null or user == null or Pulling.of(user) == null or frames() <= 0:
		return Refusal.BAD_TARGET
	if not applicable(target):
		return Refusal.BAD_TARGET
	if user.global_position.distance_to(target.global_position) > ability.cast_range_m:
		return Refusal.OUT_OF_RANGE
	return ""


## True even if the target is gone by the load tick: the mana is drained there all the same (AbilitySlot spends).
func fire(_target_pos: Vector3, target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	var pulling := Pulling.of(user)
	if pulling == null or frames() <= 0 or not is_live(target):
		if DebugLog.on(&"pull"):
			print("pull %s without a valid target (tick %d)" % [who(user), MatchClock.now()])
		return false
	var hit := first_body_on_path(target)
	if hit != target and DebugLog.on(&"pull"):
		print("pull %s: the ray stops at %s instead of %s (tick %d)" % [who(user), who(hit), who(target), MatchClock.now()])
	return pulling.start(hit, self, loop_ticks(), pull_frame())


## The rules that apply to the target of the ability and to the pull at each of its pulls: range, mana and
## cooldown do not count after the start.
func applicable(target: Node3D) -> bool:
	if not is_live(target) or target == user:
		return false
	if SideRelations.stance(_slot(user), _slot(target)) == SideRelations.Stance.ALLY:
		return false
	var wards := Wards.of(target)
	return wards == null or not wards.shielded()


## A ray from the shot origin to the target's center: the nearest valid body (any side, not the user) whose
## box the segment crosses. The target itself is one of them, so the ray only changes it for a body in front of it.
func first_body_on_path(target: Node3D) -> Node3D:
	var from := _origin()
	var to := BodyNudge.center(target)
	var best := target
	var best_distance := INF
	for group in [&"wizard", &"unit"]:
		for node in user.get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or body == user or not is_live(body):
				continue
			var point: Variant = BodyNudge.box(body).intersects_segment(from, to)
			if point == null:
				continue
			var distance := from.distance_to(point as Vector3)
			if distance < best_distance:
				best_distance = distance
				best = body
	return best


## Frames of the user's clip (LSs1 82, SPs1 102), from its CreatureType. 0 = the creature has no such clip.
func frames() -> int:
	var type: CreatureType = user.get("type") if user else null
	if type == null or clip_index >= SHOOT_ROLES.size():
		return 0
	return type.clip_facts().frames(SHOOT_ROLES[clip_index])


## The loop of the clip in ticks, and the tick of the loop where it pulls (its last frame; no `lrba`).
func loop_ticks() -> int:
	return FRAME_TICKS * frames()


func pull_frame() -> int:
	return FRAME_TICKS * (frames() - 1)


## A live creature or wizard on the field: what a pull can hold.
static func is_live(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree() or node.is_in_group(Corpse.GROUP):
		return false
	if not node.is_in_group(UnitBody.GROUP) and not node.is_in_group(WizardBody.GROUP):
		return false
	if not GameBody.targetable(node):
		return false
	var health := node.get_node_or_null("Health") as Health
	return health == null or not health.is_dead()


## Where the thread leaves: the user's shot origin, else its center.
func _origin() -> Vector3:
	var ranged := user.weapons.ranged
	if ranged != null:
		return ranged.shot_origin()
	return BodyNudge.center(user)


static func _slot(body: Node) -> int:
	return int(body.get("owner_slot")) if "owner_slot" in body else 0
