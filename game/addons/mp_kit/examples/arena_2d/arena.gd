extends Node2D

## The example's match rules: the first player to 3 points wins; a player who comes back (rejoin) is counted
## (MpState back_N) and one who stays away past the grace loses. The server decides; MpMatch tells every peer, and after
## a moment each player leaves (back to the lobby for an online match, to the menu otherwise).

const WIN_SCORE := 3

@onready var score: MpState = $Score
@onready var match_node: MpMatch = $Match


func _ready() -> void:
	score.changed.connect(_on_score)
	match_node.finished.connect(_on_finished)
	match_node.player_back.connect(func(slot: int) -> void: score.add(StringName("back_%d" % slot)))
	match_node.player_abandoned.connect(_on_abandoned)


## A player who stays away past the grace loses; the first other seat wins.
func _on_abandoned(slot: int) -> void:
	for other in match_node.seats():
		if other != slot:
			match_node.finish({"winner": "p%d" % other, "abandoned": slot})
			return


func _on_score(key: StringName, value: Variant) -> void:
	if MpKit.is_authority() and int(value) >= WIN_SCORE:
		match_node.finish({"winner": String(key)})


func _on_finished(result: Dictionary) -> void:
	%Info.text = "%s wins!" % str(result.get("winner", "?")).to_upper()
	if MpKit.is_dedicated():
		return
	await get_tree().create_timer(2.0).timeout
	MpFlow.find_in_tree(self).leave_match()
