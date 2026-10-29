extends "res://addons/mp_kit/tests/mp_test.gd"

## MpCalls: only mp_sv_* / mp_all_* methods with a matching argument count can be called by name.

const SOURCE := """extends Node
var log: Array = []
func mp_sv_buy(item, count = 1):
	log.append([item, count])
func secret():
	log.append("secret")
"""


func test_names_and_arguments() -> void:
	var script := GDScript.new()
	script.source_code = SOURCE
	script.reload()
	var node: Node = script.new()
	var calls := MpCalls.new(node)
	check(calls.run("mp_sv_", &"buy", ["sword"]), "a call with the default argument left out runs")
	check(calls.run("mp_sv_", &"buy", ["shield", 2]), "a call with every argument runs")
	check(not calls.run("mp_sv_", &"buy", []), "too few arguments are refused")
	check(not calls.run("mp_sv_", &"buy", [1, 2, 3]), "too many arguments are refused")
	check(not calls.run("mp_sv_", &"secret", []), "a method without the prefix cannot be reached")
	check(not calls.run("mp_all_", &"buy", ["x"]), "the prefix is part of the name")
	check(node.log == [["sword", 1], ["shield", 2]], "only the accepted calls ran")
	node.free()
