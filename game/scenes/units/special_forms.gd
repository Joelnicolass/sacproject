class_name SpecialForms
extends Node

## The shapes a creature takes on purpose: playing dead (it lies still, half faded, and heals), stealth (faded out, nobody can target it,
## shown to every peer through the replicated `stealth`) and stone (rock form: it drops its orders and stands as a rock until told to move).
## Not: how long a form lasts (the ability that turns it on: TimedStateAbility, Rockform) nor what a form does to damage.

enum Form { PLAYING_DEAD, STEALTH }

const _ORDERS := preload("res://scenes/units/unit_orders.gd")

@export var body: UnitBody
@export var orders: _ORDERS
## The model that fades.
@export var visual: BodyVisual
## Only the server writes `stealth`; the setter shows it on every peer. Replicated by the synchronizer of unit.tscn.
var stealth := false:
	set(value):
		if stealth == value:
			return
		stealth = value
		if body != null and body.is_node_ready():
			present()
			body.clips.update()
var playing_dead := false


## The look of a body that joins in a form (UnitBody._ready) and of a form that changes.
func present() -> void:
	if visual != null:
		visual.set_fade(0.75 if stealth else 0.0)


## Turns a form on or off (server or solo).
func set_form(form: Form, on: bool) -> void:
	match form:
		Form.PLAYING_DEAD:
			set_playing_dead(on)
		Form.STEALTH:
			stealth = on


func set_playing_dead(on: bool) -> void:
	if playing_dead == on:
		return
	playing_dead = on
	if visual != null:
		visual.set_fade(0.5 if on else 0.0)
	if on:
		body.halt()
	body.clips.update()


## Guardian: a creature on a post shows no form.
func clear() -> void:
	set_playing_dead(false)
	stealth = false


## Drops its order and target and stands as a rock (the Earthfling's Rockform).
func enter_rock() -> void:
	if orders != null:
		orders.clear()
	body.engagement.drop()
	body.mode = UnitBody.Mode.ROCK_FORM
