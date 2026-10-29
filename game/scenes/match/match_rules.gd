class_name MatchRules
extends Resource

## The rules of a match: souls, mana sources, rituals, spells, guardians and friendly fire.
## One file per rule set (scenes/match/match_rules.tres is the product's); MatchWorld reads it.

@export var starting_souls: int = 12
## Live creatures a player may own at once (summons in progress count). 0 = no cap.
@export var max_creatures_per_player: int = 0
## Where the reaches (souls, mana of a fount and an altar, the Manahoar aura, arming and leashing a
## Guardian) live as shapes. The radii live there, not here.
@export var reach_places: PackedScene = preload("res://scenes/match/reach_places.tscn")
@export var manafount_rate: float = 33.333
@export var altar_rate: float = 16.667
## Mana aura of the Manahoar: max 20 mana/s, radius 40.
@export var manahoar_rate: float = 20.0
## It ramps with distance to allied manaliths from 50 to 1000.
## Negative: wizards start with full mana. Debug rules lower it to watch the sources fill it.
@export var start_mana: float = -1.0
@export var ghost_health_per_mana: float = 4.2
@export var ghost_speed_factor: float = 1.75
@export var cast_drain_per_s: float = 500.0
@export var extra_cooldown_s: float = 1.5
@export var other_spell_cooldown_s: float = 1.0
## The land of the match (the god whose look the map wears). Empty: the server draws a god per
## match. Debug rules force one.
@export var biome: GodType
## 0: random seed per match. Otherwise BiomeRules.pick_god(biome_seed, gods). With a match_seed
## and biome_seed 0 the biome follows the match seed (MatchSeed.derive).
@export var biome_seed: int = 0
## Pins the hour of the match (0..24; 11 day, 0 night). -1: the land's own clock.
@export_range(-1.0, 24.0, 0.25) var sky_hour: float = -1.0
## Forces the weather of the match. Empty: the land's weather plan.
@export var weather: WeatherState
## The map's forest trees (MapProps/Forest, ForestScatter). Off: they are taken away before the
## match starts on every peer and the navmesh is baked again without them.
@export var forest: bool = true
## 0: the match draws one and prints `seed <n>`. Otherwise every source of
## chance (bodies, ghosts, separation ties, biome) derives from it, see MatchSeed.
@export var match_seed: int = 0
## Negative: wizards start with full health. Debug rules lower it to watch Heal fill it.
@export var start_health: float = -1.0
## P drops one soul.
@export var enable_drop_soul: bool = true
## Seats the AI takes in this match (AiRoster in high_noon). Empty = no AI (a match of humans).
## «Contra la IA» does not fill it: it comes through SacrificeFlow.solo_ai_seats. A test scene may
## seat its own.
@export var ai_seats: Array[AiSeat] = []

@export_group("Sacrifices")
## The places of the sacrifice (ring, push, reach, hang, vortex) as a scene that is only read, never
## instanced (SacrificeFacts). An inherited scene is a variant.
@export var sacrifice_places: PackedScene = preload("res://scenes/sacrifice/sacrifice_places.tscn")
## How long a doctor's death takes: 70 + 50 frames at 60 fps.
@export var doctor_death_s: float = 2.0
## Invention of the port (the user chose it): the original has no limit. A doctor
## that makes no progress toward its goal this long dies. 0 = never.
@export var doctor_stuck_abort_s: float = 45.0

# Altar and wizard death.
## Disappear 4 s + float 4 s + explode 3 s; the
## altar is gone at the end and its side is defeated.
@export var altar_collapse_s: float = 11.0
## A wizard that dies under ritual vanishes in 4 s; one with no altar left in 1 s.
@export var wizard_vanish_ritual_s: float = 4.0
@export var wizard_vanish_s: float = 1.0

# Desecrate and Convert.
## The enemy altar must be this close to the wizard on the plane.
@export var desecrate_altar_range: float = 75.0
## The carried creature catches up at this multiple of the doctor's pace.
@export var carry_speed_factor: float = 1.1
## A creature a doctor carries (or pumps back to life) dies when the doctor dies and drops it; its
## soul stays where it lands.
## Off: it lands alive and stunned, as the original does.
@export var carried_dies_when_dropped: bool = true

# The ritual.
## Preparation, then rounds of walk + shoot + wait.
@export var ritual_setup_s: float = 5.0
@export var ritual_walk_s: float = 4.5
@export var ritual_shoot_s: float = 4.5
@export var ritual_wait_s: float = 4.5
## The drain of the wizard is spread over a window of the shoot phase: it starts 20 ticks in (0.33
## s) and lasts 250 ticks (4.17 s).
@export var ritual_drain_start_s: float = 0.3333
@export var ritual_drain_s: float = 4.1667
## Per round, times (1 + souls of the creature). The unit conversion of the
## original executable could not be reconciled with these numbers (RESEARCH-victory section 3).
@export var desecrate_health_per_round: float = 200.0
@export var desecrate_mana_per_round: float = 40.0
## Push speed at the full-speed core of the push (the radii live in sacrifice_places.tscn: 20 m, 5
## m).
@export var ritual_push_speed: float = 20.0
## Push speed left at the edge. 0 = the original's. Raising it together with the push radius (for
## example 24 m and 15 m/s) keeps melee creatures out.
@export var ritual_push_edge_speed: float = 0.0
## Invention of the port: how long a finished ritual node stays so every peer sees how it ended.
@export var ritual_linger_s: float = 1.5

## The pump lasts (souls of the corpse + 1) times this.
@export var convert_pump_s_per_soul: float = 5.0
## The creature stands up with min(max(convert_revive_min_health, convert_revive_fraction * max
## health), max health). The original marks it `TODO: ok?`.
@export var convert_revive_min_health: float = 400.0
@export var convert_revive_fraction: float = 0.5
## Rounds of the Convert ritual: int(max health / this) + 1.
@export var convert_health_per_round: float = 550.0

@export_group("Guardian")
# None of these numbers is verified against the original game.
## The wizard needs a standing building of his own (altar, shrine, Manalith) this close on the plane
## to arm Guardian (a building farther away is skipped).
## A guardian hits this much harder (poison too).
@export var guardian_attack_factor: float = 1.5
## A guardian takes this much of a spell's damage and of a ranged attack's; melee goes through.
@export var guardian_spell_factor: float = 0.5
@export var guardian_ranged_factor: float = 0.25
## It heals 1000 per minute on top of its own regeneration: 16.667 per second, written to the last
## digit because the simulation multiplies it by the tick's delta.
@export var guardian_heal_per_s: float = 16.666666666666668
## Farther than this from the post's attach point the guardian gets a move order back
## to this distance from the building. The original leaves `TODO: bind creature to
## building` there: the hard leash of the original is not verified.

@export_group("Teleport")
# None of these numbers is verified against the original game. The carry radius and
# the distance to the building are the spell's effect_range (SpellType, 30).
## Each body that jumps sends rings out of its box for this long, at both ends. Presentation.
@export var teleport_effect_s: float = 0.5333
## Each ring lives this long.
@export var teleport_ring_s: float = 0.8
## A ring rises this much over its life.
@export var teleport_ring_rise: float = 0.25

@export_group("Book")
## Wizard level of every wizard in the match: the book keeps the entries
## with level <= this one. The product (scenes/match/match_rules.tres) plays at 9.
@export_range(1, 9) var wizard_level: int = 1
## The level also raises the wizard: +50 health and
## +100 mana per level, full. Off keeps the WIZD numbers (the level-0 stats). The
## casting-time bonus (CastTime) follows the level alone, as in the original.
@export var wizard_level_stats: bool = false
## Per level, when wizard_level_stats is on.
@export var health_per_level: float = 50.0
@export var mana_per_level: float = 100.0

@export_group("Damage between allies")
## What a side sees is marked for its allies too.
## Only matters when a mode has allies (2v2); in a 1v1 nobody is an ally.
@export var allied_vision: bool = true
## Off: a body takes nothing from its own side.
## On: it takes `ally_damage_factor` of every hit of its own side, melee, shot, spell, splash, cloud
## and buildings alike; poison ignores the side and takes ×1. The script default is off; the product
## (scenes/match/match_rules.tres) turns it on, the default of the original. MatchState takes it
## from the world's rules and Health asks it.
@export var friendly_fire: bool = false
## Multiplier between allies.
@export_range(0.0, 1.0, 0.05) var ally_damage_factor: float = 0.5
