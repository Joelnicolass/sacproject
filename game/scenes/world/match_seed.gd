class_name MatchSeed
extends RefCounted

## The seed of the match in this process (RFC-024 §5.1). HighNoon calls begin() from _enter_tree,
## before any child is ready. Every source of chance then asks for a stream by name:
## rng_for([...]) or derive([...]) = hash([seed, ...parts]). Reproducible with the same binary on the
## same machine; not across architectures.

## 0 until a match begins: callers fall back to randomize() as they did before.
static var current := 0
## Ties of BodySeparation (state.uniform(2)). Not the global RNG, so effects that call randf() do not
## move the simulation.
static var separation := RandomNumberGenerator.new()


## Takes `rules.match_seed`, or draws one when it is 0 (or there are no rules), seeds the global RNG
## and the separation stream, prints `semilla <n>` and returns it.
static func begin(rules: Variant) -> int:
	var wanted := int((rules as MatchRules).match_seed) if rules is MatchRules else 0
	if wanted == 0:
		wanted = maxi(1, int(randi() & 0x7fffffff))
	current = wanted
	seed(wanted)
	separation.seed = derive(["separation"])
	print("semilla %d" % wanted)
	return wanted


static func is_active() -> bool:
	return current != 0


## hash([seed, ...parts]): the same parts always give the same number inside one match seed.
static func derive(parts: Array) -> int:
	var all: Array = [current]
	all.append_array(parts)
	return hash(all)


## A generator of its own for `parts` (a node name, a slot). Without a match it is randomized.
static func rng_for(parts: Array) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if is_active():
		rng.seed = derive(parts)
	else:
		rng.randomize()
	return rng
