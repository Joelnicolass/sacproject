class_name BloodMoreChecks
extends Node

## The rest of the blood lab's checks (debug only): the hit flash and the gib's pool. BloodChecks.run calls `run` and prints the result with its own.

@export var trogg_a: UnitBody
@export var trogg_b: UnitBody
@export var spray_marks: SprayMarks


static func flash_of(body: Node3D) -> HitFlash:
	for child in body.get_children():
		if child is HitFlash:
			return child
	return null


func run(c: BloodChecks) -> void:
	await _flash(c)
	await _gib(c)


## A hit blinks the body up to `peak` and back to 0 in `flash_s` (+0.05 s), then takes the overlay off; a body in stealth never blinks.
func _flash(c: BloodChecks) -> void:
	var flash := flash_of(trogg_a)
	await c.wait(0.4)
	var before := flash.flashes
	BloodChecks.hit(trogg_a, 0.2)
	var top := 0.0
	var until := Time.get_ticks_msec() + int((flash.flash_s + 0.05) * 1000.0)
	while Time.get_ticks_msec() < until:
		top = maxf(top, flash.amount())
		await get_tree().process_frame
	await get_tree().process_frame
	c.check("flash peak %.2f" % top, flash.flashes == before + 1 and top > 0.0 and top <= flash.peak + 0.001)
	c.check("flash gone", flash.amount() == 0.0 and not flash.is_lit() and not _has_overlay(trogg_a))
	var hidden := flash_of(trogg_b)
	trogg_b.special_forms.stealth = true
	await c.wait(0.1)
	before = hidden.flashes
	BloodChecks.hit(trogg_b, 0.2)
	await c.wait(0.05)
	c.check("no flash in stealth", hidden.flashes == before and not _has_overlay(trogg_b))
	trogg_b.special_forms.stealth = false


## A gib leaves at least 8 marks within SprayMarks' radius (last: it frees the body).
func _gib(c: BloodChecks) -> void:
	await c.wait(0.2)
	var before := spray_marks.painted
	var burst := Gib.burst(trogg_b)
	await c.wait(0.1)
	c.check("gib pool (%d marks)" % (spray_marks.painted - before), burst and spray_marks.painted - before >= 8)


static func _has_overlay(body: Node3D) -> bool:
	for node in body.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).material_overlay != null:
			return true
	return false
