@tool
class_name RtsCommandType
extends Resource

## One kind of order (move, attack, guard…), as data: what it aims at, how a group lays out for it and
## who takes it. A type resource: it never changes during a match, and only its `id` travels over a
## network (RtsOrder.to_array). The kit decides who gets the order and where each unit stands; what a
## unit does with it is the game's (RtsUnit.order_started).
## Not: the order itself (RtsOrder, RtsUnitOrder), which unit accepts it (RtsUnit.accepts).

## What the order needs from the player's click.
enum Target {
	NONE,  ## Nothing (retreat: every unit of the side goes to its anchor).
	POINT,  ## A point of the ground (move).
	BODY,  ## A body (attack a unit).
	POINT_OR_BODY,  ## Either (guard a body, or a spot of the ground).
}

## How formations lay out for it (RtsFormation.slots reads it).
enum Role {
	MOVE,  ## Stand around the point.
	ATTACK,  ## Close on the target (a wedge keeps its tip on it).
	GUARD,  ## Keep around a body, turned the way it faces.
}

## Who takes it.
enum Scope {
	SELECTION,  ## The units of the order.
	SIDE,  ## Every unit of the side that sent it (retreat), whatever was selected.
}

@export var id: StringName = &""
## The words for the player (the kit says them through RtsCommandState.say).
@export var display_name := ""
@export var icon: Texture2D
@export var target := Target.POINT
@export var role := Role.MOVE
@export var scope := Scope.SELECTION
## Units stand in the group's formation. Off: every unit gets the order point itself (slot zero).
@export var uses_formation := true
## Ordered on a body that is a unit, each unit takes the foe nearest its own slot instead
## (RtsOrders.retarget_range); none in range: the body itself.
@export var retarget_nearest := false
## The order goes to the side's anchor (RtsOrders.anchor_for): its target is the anchor, whatever the
## click was.
@export var to_anchor := false
## For the presentation (pings, cues): the color this order is shown in.
@export var tone := Color.WHITE
## Documentation for the game that executes it: the unit reports `complete()` on its own when it gets
## there (move, attack). Off: it stays active until another order replaces it (guard).
@export var ends_on_its_own := true
