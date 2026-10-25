extends Node2D

## A bell of the world that belongs to no player: anyone rings it with net.to_server(&"ring"), the server runs
## mp_sv_ring and knows who it was (sender_slot). Every peer sees the count, a late joiner too.

const GROUP := &"bell"

@export var rings: int = 0:
	set(value):
		rings = value
		if is_node_ready():
			$Label.text = "Bell %d" % rings

@onready var net: MpActor = $MpActor


func _ready() -> void:
	add_to_group(GROUP)
	$Label.text = "Bell %d" % rings


func ring() -> void:
	net.to_server(&"ring")


func mp_sv_ring() -> void:
	rings += 1
	MpState.of(self).set_value(&"bell_by", net.sender_slot())
