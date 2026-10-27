extends RefCounted

## What the AI decided from the flag and status words of a track before 055f f1, copied literally so ai_names_cases can prove the
## named fields of AiTrack give the same answers: the BLDG words of the four structures, how a structure's and a body's words were
## set, the old category, wizAttack's weight and weightTriple over the old task commands. It dies with debug/ when the refactor ends.
## Preloaded by path (no class_name).
## Ref: ai_perception.gd (_setup, _bldg_flags, _status_of_structure), ai_track.gd, ai_field.gd and ai_task.gd at 51b17307.

const OWN := 1
const ALLY := 2
const ENEMY := 4
const SEEN := 0x80
const BODY := 0x10
const STRUCTURE := 0x20
const WIZARD := 0x100
const ALTAR := 0x200
const CAPTURABLE := 0x100
const ACTIVE := 0x1
const WIZARD_STATUS := 0x2000e
const READY := 0x1000
const UNBUILT := 0x8000
const MANALITH := 0x4000

const BLDG_ALTAR := 0x1407
const BLDG_FOUNT := 0x2810
const BLDG_MANALITH := 0x55a0
const BLDG_SHRINE := 0x15a6
## The old taskCmd of each task: idle, guard, capture, focus.
const COMMAND_IDLE := 0x64692e70
const COMMAND_GUARD := 1
const COMMAND_CAPTURE := 2
const COMMAND_FOCUS := 3


## The relation word of _setup from the relation index (0 own, 1 ally, 2 neutral, 3 enemy).
static func relation_flags(relation: int) -> int:
	return [OWN, ALLY, 0, ENEMY][relation]


## categoryFromFlags.
static func category(flags: int) -> int:
	if flags & OWN:
		return 0
	if flags & ALLY:
		return 1
	return 3 if (flags & ENEMY) else 2


## The flags _setup gave a structure of BLDG word `bfl` (relation bits apart).
static func structure_flags(bfl: int) -> int:
	var flags := STRUCTURE
	if bfl & 1:
		flags |= 0x300
	if bfl & 0xc17:
		flags |= CAPTURABLE
	return flags


## _status_of_structure from a status of 0, for a structure of BLDG word `bfl` (a fount when `is_fount`) whose top is free or not.
static func structure_status(bfl: int, is_fount: bool, top_free: bool) -> int:
	var status := 0
	if is_fount:
		if (bfl & 0x10) and top_free:
			status |= UNBUILT
		else:
			status &= ~UNBUILT
	else:
		top_free = true
	if top_free and (bfl & 0xc00):
		status |= READY
	else:
		status &= ~READY
	if bfl & 0x4000:
		status |= MANALITH
	else:
		status &= ~MANALITH
	if bfl & 2:
		status |= 0x40000
	else:
		status &= ~0x40000
	return status


## The flags of a body (relation bits apart).
static func body_flags(is_wizard: bool) -> int:
	return BODY | 0x40 | WIZARD if is_wizard else BODY | 0x40


## The status of a body: a wizard always WIZARD_STATUS | ACTIVE; a creature ACTIVE when it fights, a Manahoar READY when it channels.
static func body_status(is_wizard: bool, active: bool, ready: bool) -> int:
	if is_wizard:
		return WIZARD_STATUS | ACTIVE
	var status := 0
	if active:
		status |= ACTIVE
	if ready:
		status |= READY
	return status


## The old ACTIVE test of a creature type.
static func type_active(type: CreatureType) -> bool:
	return type != null and (type.abilities().size() > 0 or type.aggressiveness != 0)


## wizAttack's weight over the status word.
static func attack_weight(distance: float, thr: float, status: int, sac_doctor: bool) -> float:
	var w := 0.0
	if distance <= 10.0:
		w = 1.0
	elif not (distance < thr):
		return 0.0
	else:
		w = AiField.safediv(thr - distance, thr - 10.0)
		if w == 0.0:
			return 0.0
	if (status & 0x6) == 0:
		w *= 0.5
	if (status & 0x1800) == 0:
		w *= 0.3333333432674408
	if sac_doctor:
		w *= 10.0
	return w


## weightTriple over the old task command.
static func weight_triple(command: int, ratio: float, aggression: float) -> Array[float]:
	var m := 1.0 - ratio
	var o0 := 0.0
	var o1 := 0.0
	var o2 := 0.0
	if command <= 1:
		o0 = AiField.f32(aggression * (1.0 - m) * (1.0 / 6.0))
		o1 = AiField.f32(1.0 - m)
		o2 = m * aggression
	elif command == 2:
		o0 = AiField.f32(aggression * (1.0 - m) * 0.5)
		o1 = AiField.f32((1.0 - m) * (1.0 / 3.0))
		o2 = m * aggression
	var total := (o2 + o1) + o0
	if total <= 0.0:
		return [0.333299994468689, 0.333299994468689, 0.333299994468689]
	return [AiField.f32(AiField.safediv(o0, total)), AiField.f32(AiField.safediv(o1, total)), AiField.f32(AiField.safediv(o2, total))]
