class_name SpellSlot
extends Button

## One page of the book: the tab's page, the `icon` of the spell or creature shrunk and faded by mana/manaCost, the spirit mark when souls are
## short, and the cooldown sweep. Without an icon the name is written instead.

## Side of a page in canvas pixels (the 1280×720 base).
const SIZE := 38.0

var _mana_cost := 1.0
var _soul_cost := 0


func show_spell(spell: SpellType, key: String, page: Texture2D) -> void:
	_mana_cost = maxf(1.0, float(spell.mana_cost))
	_soul_cost = 0
	_show(spell.display_name, key, page, spell.icon)
	tooltip_text = tr("UI_SLOT_SPELL_TIP") % [spell.display_name, key, spell.mana_cost, roundi(spell.cast_range_m)]


func show_creature(creature: CreatureType, key: String, page: Texture2D) -> void:
	_mana_cost = maxf(1.0, float(creature.mana_cost))
	_soul_cost = creature.souls
	var souls := "%d %s" % [creature.souls, "alma" if creature.souls == 1 else "almas"]
	_show(creature.display_name, key, page, creature.icon)
	tooltip_text = tr("UI_SLOT_CREATURE_TIP") % [creature.display_name, key, roundi(_mana_cost), souls, creature.health]


func set_spirit(texture: Texture2D) -> void:
	%Spirit.texture = texture


## factor = min(1, mana/manaCost) scales and fades the icon; soulCost > souls shows the spirit.
func show_readiness(mana: float, souls: int) -> void:
	var factor := clampf(mana / _mana_cost, 0.0, 1.0)
	var side := SIZE * factor
	%Icon.size = Vector2(side, side)
	%Icon.position = Vector2(SIZE - side, SIZE - side) * 0.5
	%Icon.modulate.a = factor
	%Name.modulate.a = maxf(factor, 0.35)
	%Spirit.visible = _soul_cost > souls and %Spirit.texture != null


func show_cooldown(left: float, total: float) -> void:
	var cooling := left > 0.0 and total > 0.0
	%Cooldown.visible = cooling
	%Time.visible = cooling
	if not cooling:
		return
	%Cooldown.value = clampf(left / total, 0.0, 1.0)
	%Time.text = "%.1f" % left


func _show(title: String, key: String, page: Texture2D, icon: Texture2D) -> void:
	%Page.texture = page
	%Icon.texture = icon
	%Icon.visible = icon != null
	%Name.text = title
	%Name.visible = icon == null
