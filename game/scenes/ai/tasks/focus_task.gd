class_name FocusTask
extends AiTask

## RFC-053 053d (F373), «kill X» (not in the original: its AI only escorts the wizard or follows him, so every creature fought what it
## met, each from where it stood). On every replan it looks at the enemy bodies the side sees within AiTactics.focus_radius_m of an
## own group; for each it takes the free own creatures that can fight within that radius of it (the nearest first, at most
## focus_max_members) and estimates how long they need to kill it (AiKillEstimate: known health over their DPS less the healing the
## side sees). Score = worth (souls of a creature, focus_wizard_worth of a wizard) · healer_weight if it heals / kill seconds. The
## best one with kill seconds <= focus_kill_window_s and a local strength (AiStance influence of the own and allied groups over the
## enemy ones around it) >= focus_power_ratio becomes the commitment: it lasts commit_hold_s, or until the target dies, is no
## longer seen or leaves the radius of every own group; meanwhile no other one is picked. Its record claims those creatures first
## (the first child of the board) and each gets the same order a human's right click gives: attack it (AiOrder.ATTACK, CreatureBrain).
## AttackPhase reads `committed()`: the wizard's spells go to the same target. Uses only what the side knows (AiPerception).
## Take this node out and the side never commits.

## Diagnostic for the report: commitments made and the last one («name kill_s score»).
var commits := 0
var last_commit := ""

var _target_id := 0
var _until_tick := 0


func kind() -> Kind:
	return Kind.FOCUS


## The target the side is committed to now, or null.
func committed() -> AiTrack:
	if _target_id == 0 or board == null:
		return null
	var t: AiTrack = board.perception.tracks.get(_target_id)
	if t == null or not _holds(t, board.port.now_tick()):
		return null
	return t


func replan() -> void:
	records.clear()
	var now := board.port.now_tick()
	var target := committed()
	if target == null:
		_target_id = 0
		target = _pick()
		if target == null:
			return
		_target_id = target.id
		_until_tick = now + MatchClock.ticks_for(_tactics().commit_hold_s)
		commits += 1
	var record := board.new_record(target)
	record.score = 1.0
	insert_sorted(record)


## The free own creatures nearest the target go to it, up to focus_max_members.
func claim(free: Array[AiTrack]) -> float:
	if records.is_empty():
		return 0.0
	var record := records[0]
	var total := 0.0
	for t in _members_near(board.perception.pos_of(record.target), free):
		total += board.claim_member(record, free, t)
	return total


func _tactics() -> AiTactics:
	return board.wizard_brain.tactics if board.wizard_brain != null and board.wizard_brain.tactics != null else AiTactics.or_normal(null)


## The commitment holds: in time, the target alive, seen and within the radius of an own group.
func _holds(t: AiTrack, now: int) -> bool:
	if now >= _until_tick or not _fightable(t) or not board.perception.knows_live(t):
		return false
	return _near_own_group(board.perception.pos_of(t))


func _pick() -> AiTrack:
	var perception := board.perception
	var tactics := _tactics()
	var own: Array[AiTrack] = []
	for t: AiTrack in perception.bodies(0):
		if AiTaskBoard.claimable(t) and fighter(t):
			own.append(t)
	if own.is_empty():
		return null
	var best: AiTrack
	var best_score := 0.0
	for foe: AiTrack in perception.bodies(3):
		if not foe.is_body() or not _fightable(foe) or not perception.knows_live(foe):
			continue
		var worth := _worth(foe, tactics)
		if worth <= 0.0:
			continue
		var at := perception.pos_of(foe)
		if not _near_own_group(at):
			continue
		var members := _members_near(at, own)
		if members.is_empty():
			continue
		var kill_s := AiKillEstimate.kill_seconds(perception, foe, members)
		if DebugLog.on(&"ai_focus"):
			print("ai_focus slot %d candidato %s miembros %d muere en %.2f s" % [perception.slot, foe.node.name, members.size(), kill_s])
		if kill_s > tactics.focus_kill_window_s:
			continue
		var score := worth / maxf(kill_s, 0.1)
		if foe.kind == AiTrack.Kind.CREATURE and AiKillEstimate.is_healer(foe.node.get("type") as CreatureType):
			score *= tactics.healer_weight
		if score <= best_score or not _strong_enough(at, tactics):
			continue
		best_score = score
		best = foe
		last_commit = "%s %.2f %.3f" % [foe.node.name, kill_s, score]
	if DebugLog.on(&"ai_focus") and best != null:
		print("ai_focus slot %d compromiso %s" % [perception.slot, last_commit])
	return best


## A body the side may fight (TargetRules: alive, not a ghost or a rock, an enemy with health).
func _fightable(t: AiTrack) -> bool:
	return AiWizardBrain.target_alive(t) and TargetRules.is_valid_foe_of(board.perception.slot, t.node)


## What `foe` is worth as a focus: a creature its souls (at least 1), a wizard focus_wizard_worth; a passive NPC times npc_passive_weight.
func _worth(foe: AiTrack, tactics: AiTactics) -> float:
	var worth := tactics.focus_wizard_worth
	if foe.kind != AiTrack.Kind.WIZARD:
		worth = maxf(1.0, float(AiGroups.souls_pair(foe).x))
	if TargetRules.is_passive_npc(foe.node):
		worth *= tactics.npc_passive_weight
	return worth


## An own creature that can fight (status bit 1, not a pacifist).
static func fighter(t: AiTrack) -> bool:
	if t.kind != AiTrack.Kind.CREATURE or not t.fights:
		return false
	var type := t.node.get("type") as CreatureType
	return type != null and type.aggressiveness > 0 and AiKillEstimate.dps_of(type) > 0.0


## The fighters of `pool` within focus_radius_m of `at`, nearest first (ties in the order of `pool`), at most focus_max_members.
func _members_near(at: Vector3, pool: Array[AiTrack]) -> Array[AiTrack]:
	var tactics := _tactics()
	var radius_sq := tactics.focus_radius_m * tactics.focus_radius_m
	var near: Array = []
	for i in pool.size():
		var t := pool[i]
		if not fighter(t) or not AiTaskBoard.claimable(t):
			continue
		var d := t.cur_pos.distance_squared_to(at)
		if d <= radius_sq:
			near.append([d, i, t])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[AiTrack] = []
	for row in near:
		if out.size() >= tactics.focus_max_members:
			break
		out.append(row[2])
	return out


func _near_own_group(at: Vector3) -> bool:
	var radius := _tactics().focus_radius_m
	for group: AiGroup in board.groups.list(0):
		if group.count > 0 and group.center.distance_to(at) <= radius:
			return true
	return false


## The own and allied bodies around `at` outweigh the enemy ones by focus_power_ratio (AiStance.local_strength: the rates of the
## bodies within focus_radius_m, each by the health the side knows it has).
func _strong_enough(at: Vector3, tactics: AiTactics) -> bool:
	var ratio := power_ratio(board.stance, at, tactics.focus_radius_m)
	if DebugLog.on(&"ai_focus"):
		print("ai_focus slot %d fuerza local %.2f (minimo %.2f)" % [board.perception.slot, ratio, tactics.focus_power_ratio])
	return ratio >= tactics.focus_power_ratio


## Own and allied strength over the enemy's around `at` (INF with no enemy there).
static func power_ratio(stance: AiStance, at: Vector3, radius: float) -> float:
	var foe := stance.local_strength(3, at, radius)
	if foe <= 0.0:
		return INF
	return (stance.local_strength(0, at, radius) + stance.local_strength(1, at, radius)) / foe
