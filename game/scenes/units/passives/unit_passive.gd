@tool
class_name UnitPassive
extends Node

## Something one kind of creature always has: the Firefist's fury, the Phoenix's shield, the Storm
## Giant's lightning charge, the cloud a Cog leaves when it dies. It is a node of that creature's
## `<name>_passives.tscn` (the `Passives` instance of its body scene), with its numbers in the
## inspector. PassiveMount moves it under the creature on every peer and calls attach(); a creature
## without the node does not have the passive.

## The creature that carries it. Set by attach().
var body: UnitBody


## Takes the parts of the creature it works with from `mount`. It may run before the body is in the
## tree: what needs the tree (authority, groups, signals that fire in play) waits for `_ready`. An
## override calls `super(mount)` first.
func attach(mount: PassiveMount) -> void:
	body = mount.body
