class_name MatchBiome
extends Node

## The land of the match: the god whose look the map wears. The one who simulates (solo, host,
## dedicated) takes the god the setup chose (rules.biome) or draws one per match (BiomeRules) and
## starts the sky's clock (MatchSky); a client is told both by BiomeLink and calls `adopt`. Every
## peer with a screen then hands that god's look to the map's LookRig, after the world's _ready (the
## rig exists). It does not talk to the network (BiomeLink does) and does not work out the hour or
## the weather (AtmosphereRules, from MatchSky).

## The land is on the map's look rig: the GodType whose `look` (with its music and ambience) the
## match uses (MusicDirector and AmbienceDirector listen).
signal applied(god: GodType)

@export var world: MatchWorld
## The sky clock of the match (Context/Sky): the authority starts it here.
@export var sky: MatchSky

## The god of the land; null until it is drawn (the authority) or adopted (a client), or when the
## draw gave a god with no look.
var god: GodType
## False on a process with no screen (the dedicated server, BiomeLink says): it keeps the god but
## shows no land.
var shows_look := true
var _world_ready := false


func _ready() -> void:
	if is_multiplayer_authority():
		_draw()
		_begin_sky()
	_on_world_ready.call_deferred()


func _draw() -> void:
	var rules: MatchRules = world.rules if world else null
	var forced: GodType = null
	var match_seed := 0
	if rules:
		forced = rules.biome
		match_seed = rules.biome_seed
	if match_seed == 0:
		# the biome stream of the match (randomized without one)
		match_seed = MatchSeed.rng(["biome"]).seed
	if forced != null and forced.look == null:
		push_warning("MatchBiome: '%s' has no land; one is drawn." % forced.id())
	var picked := BiomeRules.choose(forced, match_seed, GameCatalog.shared().gods)
	if picked == null or picked.look == null:
		if DebugLog.on(&"biome"):
			print("biome without a look")
		return
	god = picked
	if DebugLog.on(&"biome"):
		print("biome %s seed %d" % [god.id(), match_seed])


## The sky's seed is a hash of the match seed (it moves no stream); 0 is kept for «no match».
func _begin_sky() -> void:
	var sky_seed := MatchSeed.derive(["sky"]) & 0x7fffffff
	if sky == null:
		push_error("MatchBiome: sky must be set in match.tscn.")
		return
	var rules: MatchRules = world.rules if world else null
	if rules:
		sky.begin(maxi(1, sky_seed), rules.sky_hour, rules.weather)
	else:
		sky.begin(maxi(1, sky_seed))
	if DebugLog.on(&"atmosphere"):
		print("atmosphere seed %d" % MatchSky.sky_seed())


## A client: the land the server sent (BiomeLink adopted the sky's clock first). A god with no look
## is ignored.
func adopt(received: GodType) -> void:
	if received == null or received.look == null:
		return
	god = received
	if DebugLog.on(&"biome"):
		print("biome %s" % god.id())
	if DebugLog.on(&"atmosphere"):
		print("atmosphere seed %d" % MatchSky.sky_seed())
	_apply()


func _on_world_ready() -> void:
	_world_ready = true
	_apply()


func _apply() -> void:
	if not _world_ready or god == null or world == null or not shows_look:
		return
	var rig := world.map.look if world.map else null
	if is_instance_valid(rig) and not rig.is_queued_for_deletion():
		rig.apply_profile(god.look)
	applied.emit(god)
