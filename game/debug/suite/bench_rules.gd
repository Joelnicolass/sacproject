class_name BenchRules
extends MatchRules

## MatchRules of a bench match (debug/ai_match): the round rules of the parent plus what the runner
## puts on the field. It is still a MatchRules for the world; the runner reads the extra part.
## F139: a bench inherits the script's friendly_fire = false (an ally takes nothing), not the product's, so the benches
## and their digests stay as they were. A bench that wants it on says so (f139_ff_*.tres, ai_duel_seeded_ff.tres).

## Groups to spawn when the match starts, in order.
@export var groups: Array[BenchGroup] = []
## Where the groups are centered (X, Z of the world; Y comes from the ground).
@export var anchor := Vector3(1270.0, 0.0, 1270.0)
## With a window the runner waits for check_tick (Enter). Headless it starts by itself.
@export var start_paused := true
## RFC-024 addendum 1 (024b2): the map's NPC (26 Farmers, 6 Taurocks) stand on the field. The 024a duels keep
## the field empty so their record does not change with the villagers.
@export var npcs := false
## RFC-030 030b (F113): the god of the human wizard (slot 1). Empty = the pick of SacrificeFlow (James by default).
@export var human_god: StringName = &""

@export_group("IA (024c)")
# The seats the AI takes are MatchRules.ai_seats (024f moved them there): the runner spawns the wizard of each
# (WizardSpawner.spawn_slot) and an AiSide, and turns off the AiRoster of the world.

## Structures put on the field at the start.
@export var structures: Array[BenchStructure] = []
@export var events: Array[BenchEvent] = []
## The text of the label while the bench waits for Enter.
@export var pending_text := "Pendiente"
## The match runs its minutes even if a side is wiped (the AI scenes measure the AI, not who wins).
@export var ignore_annihilation := false
## Extra measurement of the scene: «defend» (ai_defend: when the first foe is within 280 m, the first attack spell against it, the
## first tick two creatures of the AI fight foes).
@export var probe := ""

@export_group("Criterios (053a)")
## F370: buildings of the map put on the field (a gravestone next to the guards).
@export var buildings: Array[BenchBuilding] = []
## F370: what ExpectJudge measures; with any, the run ends once every one is decided and prints EXPECT DONE.
@export var expects: Array[BenchExpect] = []
## F370: labels whose bodies ExpectJudge prints every `trace_every_s` (health, mode, target): the diagnostic lines TRACE.
@export var trace_labels: PackedStringArray = PackedStringArray()
@export var trace_every_s := 0.5

@export_group("Final (024d)")
## > 0: the AI wizards start `ai_start_distance_m` from the altar of that slot (ai_endgame).
@export var ai_start_near_altar_of := 0
@export var ai_start_distance_m := 45.0
## 024f: > 0: the human wizard (slot 1) starts `human_start_distance_m` from the altar of that slot (ai_endgame_human:
## the human desecrates the AI).
@export var human_start_near_altar_of := 0
@export var human_start_distance_m := 40.0
