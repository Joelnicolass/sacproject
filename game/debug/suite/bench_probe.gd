class_name BenchProbe
extends Node

## F376 (RFC-053 053g): a measuring child of an ExpectJudge. The judge finds its BenchProbe children, calls begin() once the field
## is ready and step() every tick, and asks value_of() for each «probe» row of BenchRules.expects whose `measure` it measures().
## A probe only reads the simulation (it never writes it), so a bench with it keeps its digest. Remove the child and its rows
## fail with «sin_sonda». Debug code.


## `bodies`: label -> Array[Node3D] (the groups and buildings of the rules).
func begin(_bodies: Dictionary) -> void:
	pass


func step(_tick: int) -> void:
	pass


## The AI's audit (its requests), when the bench has one. Called once after begin().
func listen_audit(_audit: AiAudit) -> void:
	pass


func measures(_measure: String) -> bool:
	return false


## The measured number of `expect.measure` over `bodies` (the bodies of the row's subject).
func value_of(_expect: BenchExpect, _bodies: Array) -> float:
	return 0.0


## Extra lines printed (as EXPECT_NOTE) once the row is decided: who and why.
func notes_of(_expect: BenchExpect, _bodies: Array) -> PackedStringArray:
	return PackedStringArray()
