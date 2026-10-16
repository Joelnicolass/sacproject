extends Node

## RFC-025c audit: counts the texts the game draws on screen that are not on the allowed list. It walks
## the whole tree (every CanvasLayer and Control, not only `Hud`: «Sin almas» once lived in another layer)
## and counts every visible Label, RichTextLabel and Button whose text has a letter, except the nodes of
## the group `hud_text_allowed` («Mago · Dios», «Vida/Maná/Almas», «Fantasma», the ritual notice, the
## match result). Digits alone (cooldown seconds, the count of a roster cell) do not count. Skipped:
## AgentKit itself and the test benches' own `Overlay` layer (their measures, not the product).
## Read only: it never changes the scene.
##
##   audit()      fills `found` and `list`; returns `found`.
##   selftest()   adds a Label inside Hud and another in a CanvasLayer outside it: must find 2.

var found := 0
## What the last selftest() found.
var selftest_found := 0
## One line per text found: `Node/Path: text`.
var list := ""

var _letters := RegEx.new()


func _init() -> void:
	_letters.compile("[^\\W\\d_]")


func audit() -> int:
	found = 0
	list = ""
	var scene := get_tree().current_scene
	if scene == null:
		list = "no scene"
		return -1
	_walk(get_tree().root)
	print("HUD_TEXT_AUDIT found=%d %s" % [found, list])
	return found


## Control for the audit itself: a visible Label with a prompt of the old HUD inside Hud, and another in
## a layer outside Hud, must both be found (returns 2); both are gone afterwards.
func selftest() -> int:
	var scene := get_tree().current_scene
	var hud := scene.find_child("Hud", true, false) if scene else null
	if hud == null:
		return -1
	var bait := Label.new()
	bait.text = "Elegí el blanco"
	hud.add_child(bait)
	var layer := CanvasLayer.new()
	var stray := Label.new()
	stray.text = "Sin almas"
	layer.add_child(stray)
	scene.add_child(layer)
	var n := audit()
	hud.remove_child(bait)
	bait.free()
	scene.remove_child(layer)
	layer.free()
	found = 0
	selftest_found = n
	return n


func _walk(node: Node) -> void:
	if node == self or node.name == "AgentKit" or (node is CanvasLayer and node.name == "Overlay"):
		return
	if _drawn_text(node) and not node.is_in_group("hud_text_allowed"):
		var text := _text_of(node)
		if _letters.search(text) != null:
			found += 1
			list += "%s: %s | " % [node.get_path(), text.replace("\n", " ")]
	for child in node.get_children():
		_walk(child)


func _drawn_text(node: Node) -> bool:
	if not (node is Label or node is RichTextLabel or node is BaseButton):
		return false
	return (node as CanvasItem).is_visible_in_tree()


func _text_of(node: Node) -> String:
	if node is RichTextLabel:
		return (node as RichTextLabel).get_parsed_text()
	return str(node.get("text"))
