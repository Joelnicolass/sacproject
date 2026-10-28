class_name MatchSeed
extends Node

## The seed of the running match and the one owner of chance in the simulation. It is the node
## `Context/Seed` of match.tscn: MatchWorld calls begin() from its _enter_tree on every peer, before
## any child is ready (online they all take the seed the server announced, so the marks and the
## debris draw the same on every peer), and the seed is live from then until this node leaves the
## tree (`Context` leaves last). Every source of chance then asks for a stream of its own by name:
## rng([system, stable id]) or seed_rng(rng, [system, stable id]); derive([...]) = hash([seed,
## ...parts]) for the few that need a bare number. The stable id is a node name or a slot, never an
## instance_id (it differs between a window and headless). The global RNG (randf, randi, shuffle,
## pick_random) is for presentation only: begin seeds it from its own stream, so no simulation
## stream moves when an effect draws from it. The static functions are the way everybody reads it:
## they forward to the seed in the tree. Without a match the seed is 0 and rng() / seed_rng()
## randomize. Reproducible with the same binary on the same machine; not across architectures.

## The seed of the running match (set by begin, cleared in _exit_tree); null = no match.
static var _live: MatchSeed

## The seed of this match; 0 until begin().
var _value := 0


func _exit_tree() -> void:
	if _live == self:
		_live = null


## Takes `announced` (the seed every peer of a networked match shares,
## SacrificeFlow.active_match.match_seed()) when it is not 0, else `rules.match_seed`, else draws
## one; seeds the global RNG (presentation), prints `seed <n>` and returns it. From now on this is
## the seed everybody reads.
func begin(rules: Variant, announced := 0) -> int:
	var wanted := announced
	if wanted <= 0:
		wanted = int((rules as MatchRules).match_seed) if rules is MatchRules else 0
	if wanted <= 0:
		wanted = draw()
	_value = wanted
	_live = self
	seed(derive(["presentation"]))
	print("seed %d" % wanted)
	return wanted


## The seed of the running match; 0 = none.
static func current() -> int:
	return _live._value if _live != null else 0


## A new seed (never 0): the server draws the one it announces with it.
static func draw() -> int:
	return maxi(1, int(randi() & 0x7fffffff))


static func is_active() -> bool:
	return current() != 0


## hash([seed, ...parts]): the same parts always give the same number inside one match seed.
static func derive(parts: Array) -> int:
	var all: Array = [current()]
	all.append_array(parts)
	return hash(all)


## A generator of its own for `parts` ([system, stable id]). Without a match it is randomized.
static func rng(parts: Array) -> RandomNumberGenerator:
	var made := RandomNumberGenerator.new()
	seed_rng(made, parts)
	return made


## Seeds a generator that already exists (one a node hands to its children before it is ready):
## `override` when it is not 0 (an @export seed of the instance), else the stream of `parts` in this
## match, else randomized.
static func seed_rng(target: RandomNumberGenerator, parts: Array, override := 0) -> void:
	if override != 0:
		target.seed = override
	elif is_active():
		target.seed = derive(parts)
	else:
		target.randomize()
