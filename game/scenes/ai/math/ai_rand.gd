class_name AiRand
extends RefCounted

## The `rand()` of MSVC the original AI calls (shiny.d:31-38 `ShinyRand`): a 32-bit linear congruential
## generator, state = state * 214013 + 2531011, and the answer is bits 16..30 of the new state (0..32767).
## One per AI side, seeded from the match seed (MatchSeed.derive) so a match repeats. Only wizSacrifice uses
## it (shiny.d:3123), to decide whether this replan may think of the emergency Manahoar.

const MULTIPLIER := 214013
const INCREMENT := 2531011
const MASK := 0xFFFFFFFF

## `ShinyRand.state=1` in the engine (shiny.d:32).
var state := 1


## A generator whose first state is `seed_value` truncated to 32 bits (0 would give a short cycle at the start;
## it is kept as the engine's own 1).
static func with_seed(seed_value: int) -> AiRand:
	var rng := AiRand.new()
	rng.state = (seed_value & MASK) if (seed_value & MASK) != 0 else 1
	return rng


## shiny.d:34-37.
func next() -> int:
	state = (state * MULTIPLIER + INCREMENT) & MASK
	return (state >> 16) & 0x7fff


## `rand() * 3.0518509447574615e-05f` (shiny.d:3123): 0 <= value < 1.
func unit() -> float:
	return float(next()) * 3.0518509447574615e-05
