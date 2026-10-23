class_name MatchRules
extends Resource

@export var starting_souls: int = 12
## RFC-036 036d. Live creatures a player may own at once (summons in progress count). 0 = no cap.
@export var max_creatures_per_player: int = 0
@export var soul_collect_distance: float = 5.0
@export var manafount_rate: float = 33.333
@export var manafount_radius: float = 50.0
@export var altar_rate: float = 16.667
@export var altar_radius: float = 50.0
## sacengine manahoar mana aura (state.d ManaEntries.addManahoar): max 20 mana/s, radius 40.
@export var manahoar_rate: float = 20.0
@export var manahoar_radius: float = 40.0
## sacengine addManahoar ramps with distance to allied manaliths from 50 to 1000.
@export var manahoar_near_distance: float = 50.0
@export var manahoar_far_distance: float = 1000.0
## Negative: wizards start with full mana. Debug rules lower it to watch the sources fill it.
@export var start_mana: float = -1.0
@export var ghost_health_per_mana: float = 4.2
@export var ghost_speed_factor: float = 1.75
@export var cast_drain_per_s: float = 500.0
@export var extra_cooldown_s: float = 1.5
@export var other_spell_cooldown_s: float = 1.0
## Empty: the server draws a god theme per match. Debug rules force one.
@export var biome_god: StringName = &""
## 0: random seed per match. Otherwise ThemeApplier.pick_random(biome_seed). With a match_seed
## and biome_seed 0 the biome follows the match seed (MatchSeed.derive).
@export var biome_seed: int = 0
## RFC-024 §5.1. 0: the match draws one and prints `semilla <n>`. Otherwise every source of
## chance (bodies, ghosts, separation ties, biome) derives from it, see MatchSeed.
@export var match_seed: int = 0
## Negative: wizards start with full health. Debug rules lower it to watch Heal fill it.
@export var start_health: float = -1.0
## sacengine option enableDropSoul (options.d:106): P drops one soul.
@export var enable_drop_soul: bool = true
## RFC-024 024f: seats the AI takes in this match (AiRoster in high_noon). Empty = no AI (a match of humans, as before).
## «Contra la IA» does not fill it: it comes through SacrificeFlow.solo_ai_seats. The bench (debug/ai_match) seats its own.
@export var ai_seats: Array[AiSeat] = []

@export_group("Sacrificios")
# 020b
## Sac Doctor fall: the vortex hangs doctor_drop_height over the ground and the doctor leaves it
## doctor_exit_depth below (sacengine doctorHeight / doctorOffset, state.d:2639-2641, 15489).
@export var doctor_drop_height: float = 15.0
@export var doctor_exit_depth: float = 2.25
## Invention of the port: the original `bounce` animation is not exported. Invulnerable all along.
@export var doctor_bounce_s: float = 1.0
## sacengine doctor death: 70 + 50 frames at 60 fps (state.d:13999).
@export var doctor_death_s: float = 2.0
## Invention of the port (the user chose it, RFC-020 section 20): the original has no limit. A doctor
## that makes no progress toward its goal this long dies. 0 = never.
@export var doctor_stuck_abort_s: float = 45.0

# 020a
## sacengine AltarDestruction: disappear 4 s + float 4 s + explode 3 s (state.d:5289-5291); the
## altar is gone at the end and its side is defeated (state.d:26062).
@export var altar_collapse_s: float = 11.0
## A wizard that dies under ritual vanishes in 4 s (state.d:14010); one with no altar left in 1 s.
@export var wizard_vanish_ritual_s: float = 4.0
@export var wizard_vanish_s: float = 1.0

# 020c
## sacengine closestEnemyAltar: the enemy altar must be this close to the wizard on the plane (state.d:28083).
@export var desecrate_altar_range: float = 75.0
## The vortex hangs this far from the sacrificed creature, on the wizard's side; the doctor lands halfway
## (state.d:10190, 10205, findSacDocPositions 10162-10179). The original uses 25 m (exe 0x44a8e0, 0x44ac90).
@export var doctor_drop_distance: float = 20.0
## The doctor lifts the creature once it is this close on the plane (state.d:15714-15715).
@export var desecrate_pickup_distance: float = 10.0
## The carried creature floats this high, this far behind the doctor, and catches up at this multiple
## of the doctor's pace: 2 + 0.5 * |scale| with scale 1 (state.d:15759-15766).
@export var carry_height: float = 3.5
@export var carry_distance: float = 2.7
@export var carry_speed_factor: float = 1.1
## A creature a doctor carries (or pumps back to life) dies when the doctor dies and drops it; its soul stays where it lands.
## Off: it lands alive and stunned, as the original does (state.d:15776-15779).
@export var carried_dies_when_dropped: bool = true
## The carrier asks for the ritual once it is this close to the site, in 3D (state.d:15780).
@export var ritual_start_distance: float = 20.0

# 020d
## The 4 Sac Doctors stand on a ring around the site: radius 20 m, shrinking by `ritual_walk_shrink`
## in the last fifth of each walk (sacengine ritualPositions, state.d:15854-15863).
@export var ritual_radius: float = 20.0
@export var ritual_walk_shrink: float = 3.0
## Preparation, then rounds of walk + shoot + wait (sacengine state.d:2713, 15948-15951).
@export var ritual_setup_s: float = 5.0
@export var ritual_walk_s: float = 4.5
@export var ritual_shoot_s: float = 4.5
@export var ritual_wait_s: float = 4.5
## The drain of the wizard is spread over a window of the shoot phase: it starts 20 ticks in (0.33 s)
## and lasts 250 ticks (4.17 s) (state.d:15975, 15997-16011).
@export var ritual_drain_start_s: float = 0.3333
@export var ritual_drain_s: float = 4.1667
## Per round, times (1 + souls of the creature) (state.d:16010-16011). The unit conversion of the
## original executable could not be reconciled with these numbers (RESEARCH-victory section 3).
@export var desecrate_health_per_round: float = 200.0
@export var desecrate_mana_per_round: float = 40.0
## The creature hangs this high over the site while the ritual lasts (state.d:15928).
@export var ritual_creature_height: float = 15.0
## Everything within `ritual_push_radius` of the site is pushed out, except the ritual's doctors and
## creature: full speed at `ritual_push_inner`, falling to `ritual_push_edge_speed` at the edge.
## sacengine values: 20 m, 5 m, 20 m/s and 0 at the edge (state.d:16051, 8614-8628). The push ends
## exactly where the doctors stand, so melee creatures can reach a doctor and cancel the ritual
## (measured in debug/sacrifice/ritual_push.tscn). The user decided to keep it that way (2026-10-13),
## although the original ReadMe speaks of a barrier that keeps melee attackers out.
@export var ritual_push_radius: float = 20.0
@export var ritual_push_inner: float = 5.0
@export var ritual_push_speed: float = 20.0
## Push speed left at the edge. 0 = sacengine. Raising it together with the radius (for example
## 24 m and 15 m/s, see debug/rules/ritual_barrier.tres) keeps melee creatures out.
@export var ritual_push_edge_speed: float = 0.0
## Invention of the port: how long a finished ritual node stays so every peer sees how it ended.
@export var ritual_linger_s: float = 1.5

# 020e
## Convert: the Sac Doctor starts pumping once it is this close to the corpse, on the plane
## (sacengine `(sacDoc.position-soulPosition).xy.lengthsqr<4.0f`, state.d:15693).
@export var convert_reach: float = 2.0
## The pump lasts (souls of the corpse + 1) times this (state.d:15697: `(soulNumber+1)*5*updateFPS`).
@export var convert_pump_s_per_soul: float = 5.0
## The creature stands up with min(max(convert_revive_min_health, convert_revive_fraction * max health),
## max health) (convertRevive, state.d:8679). The original marks it `TODO: ok?`.
@export var convert_revive_min_health: float = 400.0
@export var convert_revive_fraction: float = 0.5
## Rounds of the Convert ritual: int(max health / this) + 1 (state.d:16027).
@export var convert_health_per_round: float = 550.0

@export_group("Guardián")
# 021b (all numbers follow sacengine, `sacengine/source/state.d`; none checked against Sacrifice.exe).
## The wizard needs a standing building of his own (altar, shrine, Manalith) this close on the plane
## to arm Guardian: `candidateDistance>50.0f^^2` skips it (state.d:28082), else `mustBeNearBuilding`
## (state.d:29561).
@export var guardian_arm_radius: float = 50.0
## A guardian hits this much harder (attackDamageFactor, state.d:8884; poison too).
@export var guardian_attack_factor: float = 1.5
## A guardian takes this much of a spell's damage and of a ranged attack's; melee goes through
## (dealRawDamage, state.d:9007-9008).
@export var guardian_spell_factor: float = 0.5
@export var guardian_ranged_factor: float = 0.25
## It heals 1000 per minute on top of its own regeneration (`1000.0f/(60*updateFPS)` per update,
## state.d:14408), i.e. 16.667 per second.
@export var guardian_heal_per_s: float = 1000.0 / 60.0
## Farther than this from the post's attach point the guardian gets a move order back (state.d:15366)
## to this distance from the building (state.d:15368). sacengine leaves `TODO: bind creature to
## building` there (state.d:15393): the hard leash of the original is not verified.
@export var guardian_leash: float = 50.0
@export var guardian_return_distance: float = 20.0

@export_group("Teleport")
# 021c (numbers follow sacengine, `sacengine/source/state.d`; none checked against Sacrifice.exe). The carry radius and
# the distance to the building are the spell's effect_range (SpellType, 30).
## Each body that jumps sends rings out of its box for this long, at both ends (teleportEffectLifetime = 32 frames,
## state.d:16074). Presentation.
@export var teleport_effect_s: float = 32.0 / 60.0
## Each ring lives this long (teleportRingLifetime = 48 frames, state.d:16095).
@export var teleport_ring_s: float = 48.0 / 60.0
## A ring rises this much over its life (Vector3(0, 0, 0.25) / teleportRingLifetime per frame, state.d:16097).
@export var teleport_ring_rise: float = 0.25

@export_group("Libro")
# RFC-030 030b (F113)
## Wizard level of every wizard in the match, like sacengine synchronizeLevel (lobby.d:350): the book keeps the entries
## with level <= this one (getSpells, state.d:29512). 1 is the book of the first cut; the product (data/match_rules.tres)
## moves to 9 in 030c, when the wizard has the mana to pay for them.
@export_range(1, 9) var wizard_level: int = 1
## RFC-030 030c (F114): the level also raises the wizard, like sacengine makeWizard (state.d:2307-2311): +50 health and
## +100 mana per level, full. Off keeps the WIZD numbers (the level-0 stats every rules file has used so far). The
## casting-time bonus (CastTime) follows the level alone, as in the original.
@export var wizard_level_stats: bool = false
## Per level, when wizard_level_stats is on (state.d:2308-2311).
@export var health_per_level: float = 50.0
@export var mana_per_level: float = 100.0

@export_group("Daño entre aliados")
# RFC-049 049c (F292)
## sacengine option alliedVision (options.d:95): what a side sees is marked for its allies too (markAsVisible, state.d:29658-29665).
## Only matters when a mode has allies (2v2); in a 1v1 nobody is an ally.
@export var allied_vision: bool = true
# RFC-031 031a (F139)
## sacengine option friendlyFire (options.d:98). Off: a body takes nothing from its own side (dealDamage returns 0 for an ally,
## state.d:8961). On: it takes `ally_damage_factor` of every hit of its own side, melee, shot, spell, splash, cloud and
## buildings alike (dealRawDamage's sideDamageMultiplier, state.d:9005, 9175, 28892-28899); poison passes ignoreFriendly and
## takes ×1 (state.d:9415-9419). The script keeps it off so the benches and their digests do not change; the product
## (data/match_rules.tres) turns it on, the default of sacengine. MatchState takes it from the world's rules and Health asks it.
@export var friendly_fire: bool = false
## sideDamageMultiplier between allies (state.d:28892-28899).
@export_range(0.0, 1.0, 0.05) var ally_damage_factor: float = 0.5
