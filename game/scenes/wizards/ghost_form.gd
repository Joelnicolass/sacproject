class_name GhostForm
extends Node

## A wizard's death and ghost (sacengine state.d). At health 0 the wizard plays a death
## animation (dying, 14000-14014); if its side has an altar it rises as a ghost (deadToGhost,
## 14081: mana set to 0, alpha 1 → 0.36), else it disappears. A ghost (idleGhost/movingGhost)
## moves 1.75× faster (1090), takes no damage and is no target (8916, 138), cannot cast or
## collect souls (9520, 243) and each point of mana a source gives it heals 4.2 health, even
## with a full pool (8827, 14409). With full health it turns back where it stands
## (ghostToIdle, 13959 and 14091: alpha 0.36 → 1). Other sides do not see a ghost
## (renderer.d:1412). The server (or solo) runs the stages; `stage` is replicated and every
## peer fades the body on its own. A see-through wizard is drawn shadeless with energy
## 1 → ghostEnergy (state.d:14084, 14094; shadeless.d:114: texture · energy) and, being in the
## transparent pass, casts no shadow (renderShadowCastingEntities3D, renderer.d:5658-5661).

enum Stage { ALIVE, DYING, RISING, GHOST, UNGHOSTING, GONE }

signal stage_changed(stage: Stage)

## sacengine ghostAlpha.
const GHOST_ALPHA := 0.36
## sacengine ghostEnergy.
const GHOST_ENERGY := 10.0
const ETHEREAL_FADE_S := 0.5  ## Ethereal Form fades the living wizard to the ghost's alpha and back in 30 ticks.
## sacengine updateFPS / updateAnimFactor: one animation frame lasts 2 ticks at 60 fps.
const ANIM_FPS := 30.0
## Group of every GhostForm: DefeatRule finds the wizards that already exist.
const GROUP := &"ghost_form"
## Without MatchRules: sacengine disappear(updateFPS) with no altar left (1 s), and under ritual (4 s,
## state.d:14010).
const VANISH_S := 1.0
const VANISH_RITUAL_S := 4.0
const STAGE_NAMES: PackedStringArray = ["vivo", "muere", "se levanta", "fantasma", "vuelve", "desaparece"]

@export var rules: MatchRules
@export var visual: GeometryInstance3D
@export var health: Health
@export var mana: ManaPool
## Lays the body down when it dies and stands it up for the ghost (empty = the body just stays as it is).
@export var death_look: WizardDeathLook
## Converts a dagon shadeless energy to Godot's light scale. Shadeless is texture · energy like
## the ambient (albedo · 1, deferred.d:403), so it takes the ambient's ratio: π/14
## (the old theme's ambient_light_energy with ambient 1).
@export_range(0.0, 2.0, 0.001) var energy_scale := 0.224
@export var stage: Stage = Stage.ALIVE:
	set(value):
		if stage == value:
			return
		stage = value
		if is_node_ready():
			_show_stage(true)
		stage_changed.emit(stage)

## A Desecrate ritual is held on this wizard's altar: with it, or with no altar in play, he does
## not rise as a ghost, he vanishes (state.d:14009-14010). Replicated.
@export var under_ritual := false

## How many rituals of Desecrate are held on this wizard's altar. Only the server writes it.
var desecrations := 0

var _left := 0.0
var _ethereal := false
var _fade: Tween
var _rng := RandomNumberGenerator.new()
## RFC-023f: the see-through look of THIS body (its own meshes, or the rig's), never of the others.
var _look := SeeThroughLook.new()

@onready var _wizard: Node3D = get_parent()


func _ready() -> void:
	add_to_group(GROUP)
	_look.visual = visual
	_look.ghost_alpha = GHOST_ALPHA
	_look.ghost_energy = GHOST_ENERGY
	MatchSeed.seed_rng(_rng, ["ghost", int(_wizard.get("owner_slot"))])
	_show_stage(false)
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	health.died.connect(_on_died)
	mana.given.connect(_on_mana_given)


## Ethereal Form went on or off (its Ward says so on every peer): the living body fades to the ghost's look and back.
func set_ethereal(on: bool) -> void:
	_ethereal = on
	if is_node_ready():
		_show_stage(true)


func owner_slot() -> int:
	return int(_wizard.get("owner_slot"))


## A ritual of Desecrate starts or ends on this wizard's altar (server).
func add_desecration() -> void:
	desecrations += 1
	under_ritual = true


func remove_desecration() -> void:
	desecrations = maxi(desecrations - 1, 0)
	under_ritual = desecrations > 0


## How long the body takes to vanish (state.d:14010): longer under ritual.
func vanish_seconds() -> float:
	if under_ritual:
		return rules.wizard_vanish_ritual_s if rules else VANISH_RITUAL_S
	return rules.wizard_vanish_s if rules else VANISH_S


## sacengine isValidAttackTarget / canDamage: only a living wizard.
func is_targetable() -> bool:
	return stage == Stage.ALIVE


## sacengine isObstacle (state.d:120-126): a ghost keeps its hitbox; a vanished wizard has none.
func is_obstacle() -> bool:
	return stage != Stage.GONE


## sacengine isValidGuardTarget (state.d:145-151): not while dying, but a ghost can be guarded.
func is_guard_target() -> bool:
	return stage != Stage.DYING and stage != Stage.GONE


## sacengine isGhost: idleGhost or movingGhost.
func is_ghost() -> bool:
	return stage == Stage.GHOST


## Dying, rising and turning back stand still; a ghost moves.
func can_move() -> bool:
	return stage == Stage.ALIVE or stage == Stage.GHOST


func speed_factor() -> float:
	return rules.ghost_speed_factor if stage == Stage.GHOST and rules else 1.0


## sacengine canCast: idle or moving.
func can_cast() -> bool:
	return stage == Stage.ALIVE


## sacengine canRegenerateMana (state.d:168-175).
func can_take_mana() -> bool:
	return stage == Stage.ALIVE or stage == Stage.GHOST or stage == Stage.UNGHOSTING


## sacengine canCollectSouls (state.d:243-249): ghostToIdle already collects.
func can_collect_souls() -> bool:
	return stage == Stage.ALIVE or stage == Stage.UNGHOSTING


## sacengine spellbookVisible (state.d:28104): not dying, not a ghost, not dead.
func spellbook_visible() -> bool:
	return stage == Stage.ALIVE or stage == Stage.UNGHOSTING


## Shown while the body is see-through: rising, ghost and turning back.
func shows_ghost() -> bool:
	return stage == Stage.RISING or stage == Stage.GHOST or stage == Stage.UNGHOSTING


func _physics_process(delta: float) -> void:
	match stage:
		Stage.DYING:
			_left -= delta
			if _left <= 0.0:
				_after_dying()
		Stage.RISING:
			_left -= delta
			if _left <= 0.0:
				_enter(Stage.GHOST, 0.0)
		Stage.GHOST:
			## A ritual on the altar brings the ghost back to the body so it can be drained and killed
			## (sacengine state.d:13959-13962); with at least 1 life so it does not die on the way.
			if desecrations > 0 and health.current < 1.0:
				health.current = 1.0
			if desecrations > 0 or health.is_full():
				_enter(Stage.UNGHOSTING, _seconds(_type().float_to_stance_frames if _type() else 0))
		Stage.UNGHOSTING:
			_left -= delta
			if _left <= 0.0:
				_enter(Stage.ALIVE, 0.0)


func _on_died(_from_slot: int) -> void:
	if stage != Stage.ALIVE:
		return
	_enter(Stage.DYING, _seconds(_death_frames()))


## sacengine: dying → dead → deadToGhost with an altar, else disappear (state.d:14004-14014);
## under ritual he disappears even with one (state.d:14009-14010).
func _after_dying() -> void:
	if desecrations > 0 or not _has_altar():
		_enter(Stage.GONE, 0.0)
		return
	mana.current = 0.0
	_enter(Stage.RISING, _seconds(_type().corpse_rise_frames if _type() else 0))


func _on_mana_given(amount: float) -> void:
	if stage == Stage.GHOST and rules:
		health.heal(rules.ghost_health_per_mana * amount)


func _enter(next: Stage, seconds: float) -> void:
	_left = seconds
	stage = next
	var at := _wizard.global_position
	print("mago %d %s en %.1f %.1f vida %d mana %d" % [owner_slot(), STAGE_NAMES[next], at.x, at.z, roundi(health.current), roundi(mana.current)])


## sacengine pickRandomAnimation(deathCandidatesOnGround): death0, death1 or death2.
func _death_frames() -> int:
	var type := _type()
	if type == null or type.death_frames.is_empty():
		return 0
	return type.death_frames[_rng.randi_range(0, type.death_frames.size() - 1)]


func _seconds(frames: int) -> float:
	return float(frames) / ANIM_FPS


func _type() -> WizardType:
	return _wizard.get("wizard_type") as WizardType


## sacengine hasAltar (state.d:13293): an altar of the wizard's side that stands.
func _has_altar() -> bool:
	var slot := owner_slot()
	for node in get_tree().get_nodes_in_group(Altar.GROUP):
		var altar := node as Altar
		if altar and altar.owner_slot == slot and altar.is_standing():
			return true
	return false


## Every peer: deadToGhost and ghostToIdle fade over their animation, a ghost is hidden from
## other sides, and a wizard without an altar fades out.
func _show_stage(animate: bool) -> void:
	if visual == null:
		return
	if _fade:
		_fade.kill()
		_fade = null
	visual.visible = true
	if death_look != null and stage != Stage.DYING and stage != Stage.RISING and stage != Stage.GONE:
		death_look.stand()
	var ethereal := _ethereal and stage == Stage.ALIVE
	var see_through := shows_ghost() or stage == Stage.GONE or ethereal
	_look.set_shadow(not see_through)
	_look.set_shadeless(shows_ghost() or ethereal)
	var ghost := 1.0 - GHOST_ALPHA
	match stage:
		Stage.ALIVE, Stage.DYING:
			_fade_to(ghost if ethereal else 0.0, ETHEREAL_FADE_S, animate)
			if animate and stage == Stage.DYING and death_look != null:
				death_look.fall()
		Stage.RISING:
			var rise_s := _seconds(_type().corpse_rise_frames if _type() else 0)
			if animate and rise_s > 0.0 and death_look != null and death_look.is_lying():
				_fade = death_look.rise(_look.set_transparency, _look.transparency, ghost, rise_s)
			else:
				_fade_to(ghost, rise_s, animate)
		Stage.GHOST:
			_look.set_transparency(ghost)
			visual.visible = _seen_by_viewer()
		Stage.UNGHOSTING:
			_fade_to(0.0, _seconds(_type().float_to_stance_frames if _type() else 0), animate)
		Stage.GONE:
			_fade_to(1.0, vanish_seconds(), animate)
			if _fade:
				_fade.tween_callback(func() -> void: visual.visible = false)
			elif not animate:
				visual.visible = false


func _fade_to(transparency: float, seconds: float, animate: bool) -> void:
	if not animate or seconds <= 0.0:
		return _look.set_transparency(transparency)
	_fade = visual.create_tween()
	_fade.tween_method(_look.set_transparency, _look.transparency, transparency, seconds)


## Energy follows the fade: 1 at alpha 1, GHOST_ENERGY at ghostAlpha (sacengine shadelessBoneMaterialBackend).
func _process(_delta: float) -> void:
	_look.energy_scale = energy_scale
	_look.update()


func _seen_by_viewer() -> bool:
	var viewer := MpKit.local_slot()
	return viewer <= 0 or viewer == int(_wizard.get("owner_slot"))
