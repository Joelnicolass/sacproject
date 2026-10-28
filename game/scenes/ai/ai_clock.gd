class_name AiClock
extends Node

## When each of the six jobs of an AI side runs: every `*_every_s` (times the difficulty's
## period_scale), always in the same order, and earlier when something wakes it (a body appeared, a
## structure changed hands). It does not know what a job does: it says `job_due` and the side runs
## it. It also keeps how long each tick and each job took (diagnostic, never read by the
## simulation). Child `Clock` of ai_side.tscn.
## Ref: shiny.d:459-488 run, 468 periods, 469 force masks, 504-514 scheduler, 517-546 forceFlags

## A job's time came (or something woke it): the side runs it now, before the next job is looked at.
signal job_due(job: Job)

enum Job { STATUS, STANCE, PERCEPTION, GROUPS, REPLAN, TASKS }
## What can make a job run before its time (the bits AiPerception.forced raises).
enum Wake { REPLAN = 1, STATS = 2, STANCE = 4, SCAN = 8, TASKS = 0x20 }
## Every wake bit; 0x10 is in it too, though nothing raises it.
const ANY_WAKE := 0x3f
## The wakes each job answers to, in Job order.
const FORCE_MASKS: Array[int] = [
	Wake.STATS | Wake.STANCE | Wake.SCAN,
	Wake.REPLAN | Wake.STATS | Wake.STANCE | Wake.SCAN,
	Wake.REPLAN,
	Wake.REPLAN,
	ANY_WAKE,
	Wake.REPLAN
]
## First tick of each job. With all six at tick 0 every 60th tick ran them together (~2 ms); groups
## and tasks start at 3 and 6 and perception at 1, so they no longer fall on the ticks of the replan
## and the tasks: the same periods and order, the work spread over more ticks (measured in
## ai_perf60: those ticks were the 1.7 % that set the p99).
const START_TICKS: Array[int] = [0, 0, 1, 3, 0, 6]

@export_group("How often (at Normal pace)")
## The first scan of the map and the stats.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var status_every_s := 0.2
## The numbers that sum up the field (AiStance).
@export_range(0.0, 10.0, 0.0001, "suffix:s") var stance_every_s := 1.0
## The bodies the side follows and the wizard's threat. One run is one «age» of a track
## (AiPlay.age_ticks).
@export_range(0.0, 10.0, 0.0001, "suffix:s") var perception_every_s := 0.1
## The centers and aggregates of the groups.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var groups_every_s := 0.1
## Groups, tasks and claims made again.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var replan_every_s := 1.0
## The brains of the records think.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var think_every_s := 0.2

## Set once by AiSide.setup (its difficulty scales the periods).
var play: AiPlay
## Ticks this clock has run.
var ticks_run := 0
var wakes := Wake.REPLAN | Wake.STATS | Wake.STANCE | Wake.SCAN
var next_run: Array[int] = []
## Diagnostic: ms of each tick (whole, and without the calls into the game through the port), µs of
## each run of each job, and the slowest tick with the jobs it ran.
var tick_ms := PackedFloat32Array()
var tick_ms_decisions := PackedFloat32Array()
var slot_us: Array[PackedInt32Array] = [
	PackedInt32Array(),
	PackedInt32Array(),
	PackedInt32Array(),
	PackedInt32Array(),
	PackedInt32Array(),
	PackedInt32Array()
]
var worst := {}
var _handled := 0
var _tick_slots := {}


func _init() -> void:
	next_run.assign(START_TICKS)


## Ticks of `job` at Normal pace.
func base_ticks(job: Job) -> int:
	var every: Array[float] = [
		status_every_s,
		stance_every_s,
		perception_every_s,
		groups_every_s,
		replan_every_s,
		think_every_s
	]
	return MatchClock.ticks_for(every[job])


## Ticks between two runs of `job` at this side's difficulty: rounded down, never under 1.
func ticks(job: Job) -> int:
	return maxi(1, int(floor(float(base_ticks(job)) * play.difficulty.period_scale + 0.0001)))


## One tick: each job whose time came, or that a wake it answers to asks for, in Job order.
func run() -> void:
	_handled = 0
	for job: Job in Job.values():
		if next_run[job] <= ticks_run:
			_due(job)
			next_run[job] += ticks(job)
		elif (wakes & FORCE_MASKS[job]) != 0:
			_due(job)
	wakes &= ~_handled
	ticks_run += 1


func wake(bits: int) -> void:
	wakes |= bits


func is_woken(bit: int) -> bool:
	return (wakes & bit) != 0


## The jobs of this tick answered `bits`: they are cleared once the tick ends.
func handle(bits: int) -> void:
	_handled |= bits


## The diagnostic of the tick that just ran: `spent_us` in all, `game_us` of it inside the game
## (through the port).
func note_tick(spent_us: int, game_us: int) -> void:
	if spent_us > int(worst.get("us", 0)):
		worst = {
			"tick": ticks_run - 1,
			"us": spent_us,
			"game_us": game_us,
			"slots": _tick_slots.duplicate()
		}
	_tick_slots.clear()
	tick_ms.append(float(spent_us) / 1000.0)
	tick_ms_decisions.append(float(spent_us - game_us) / 1000.0)


func _due(job: Job) -> void:
	var began := Time.get_ticks_usec()
	job_due.emit(job)
	slot_us[job].append(Time.get_ticks_usec() - began)
	_tick_slots["k%d" % job] = Time.get_ticks_usec() - began
