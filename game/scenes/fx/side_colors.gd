@tool
class_name SideColors
extends RefCounted

## Player colors and the Manalith column color.
## Static and @tool so the editor and a headless run use it without autoloads. The port has no
## color assigned to a slot yet: slot N takes palette entry N % 8 (slot 0 = white). The sides no player takes
## (Farmers and Taurocks of High Noon, slots 3 and 4: SideRelations.is_npc_slot) have no player color: they get
## the gray the neutral side has (half white), so nothing mistakes them for a third player.

const PALETTE: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.0, 0.0, 1.0),
	Color(0.0, 1.0, 0.0),
	Color(1.0, 1.0, 0.0),
	Color(1.0, 0.0, 1.0),
	Color(182.0 / 255.0, 47.0 / 255.0, 0.0),
	Color(47.0 / 255.0, 0.0, 182.0 / 255.0),
	Color(0.0, 1.0, 1.0),
]

const NPC_COLOR := Color(0.5, 0.5, 0.5)


static func side_color(slot: int) -> Color:
	if SideRelations.is_npc_slot(slot):
		return NPC_COLOR
	return PALETTE[posmod(slot, PALETTE.size())]


## manaColor: 0.8 * side + 0.2 white, normalised so r + g + b = 3.
static func mana_color(slot: int) -> Color:
	var c := side_color(slot)
	var mixed := Color(0.8 * c.r + 0.2, 0.8 * c.g + 0.2, 0.8 * c.b + 0.2)
	var total := mixed.r + mixed.g + mixed.b
	var k := 3.0 / total
	return Color(mixed.r * k, mixed.g * k, mixed.b * k)


## manaEnergy: sides with little green get 160, the rest 20 (8x). Under the game's AgX 8x clips to
## white, so the multiplier is softened; the base energy lives in the ParticleType.
static func mana_energy_scale(slot: int) -> float:
	return 2.0 if side_color(slot).g < 0.15 else 1.0
