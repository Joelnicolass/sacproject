extends Node

## RFC-043 043a/043b, one time, on the text of high_noon_layout.tscn (so the diff of the scene is only what changes):
##  - 043a: a building or spawn with a `facing_deg` line gets the turn in its own saved transform, the same operation the game ran
##    in _ready (rotation.y = -deg_to_rad(facing_deg)); every `facing_deg` line is removed.
##  - 043b: a `tag = "x"` line becomes a reference to data/catalog/buildings/x.tres (`building`, under Buildings) or
##    data/catalog/creatures/x.tres (`creature`, under NpcSpawns). A tag with no file is kept and reported.
## It does nothing to a scene it already migrated, so it can be run again.
## "$GODOT" --headless --path game res://tools/migrate_layout_043.tscn
## Check it with res://tools/check_layout_transforms.tscn (its baseline was taken before the migration).

const LAYOUT := "res://scenes/map/high_noon_layout.tscn"
const KINDS := {
	"Buildings": {"property": "building", "folder": "res://data/catalog/buildings/"},
	"NpcSpawns": {"property": "creature", "folder": "res://data/catalog/creatures/"},
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var text := FileAccess.get_file_as_string(LAYOUT)
	if text.is_empty():
		push_error("migrate_layout_043: %s does not load" % LAYOUT)
		get_tree().quit(1)
		return
	var lines := text.split("\n")
	var out := PackedStringArray()
	var ext_lines := PackedStringArray()
	var ext_ids := {}
	var turned := 0
	var typed := 0
	var missing := PackedStringArray()
	var k := 0
	while k < lines.size():
		var header := lines[k]
		# The block: the header and its lines up to the next section.
		var end := k + 1
		while end < lines.size() and not lines[end].begins_with("["):
			end += 1
		var block := PackedStringArray(Array(lines.slice(k, end)))
		var parent := _parent_of(header)
		if header.begins_with("[node ") and KINDS.has(parent):
			var result := _migrate_block(block, KINDS[parent], ext_ids, ext_lines, missing)
			turned += result["turned"]
			typed += result["typed"]
			block = result["block"]
		out.append_array(block)
		k = end
	# The new ext_resources go right after the last existing one, before the first node.
	var final_lines := PackedStringArray()
	var inserted := false
	for line in out:
		if not inserted and line.begins_with("[node "):
			while final_lines.size() > 0 and final_lines[final_lines.size() - 1].is_empty():
				final_lines.remove_at(final_lines.size() - 1)
			final_lines.append_array(ext_lines)
			final_lines.append("")
			inserted = true
		final_lines.append(line)
	var file := FileAccess.open(LAYOUT, FileAccess.WRITE)
	file.store_string("\n".join(final_lines))
	file.close()
	print("migrate_layout_043: %d nodes turned, %d tags became references, %d tags without a file%s" % [
		turned, typed, missing.size(), (": " + ", ".join(missing)) if not missing.is_empty() else ""])
	get_tree().quit(0)


func _parent_of(header: String) -> String:
	var at := header.find(" parent=\"")
	if at < 0:
		return ""
	var start := at + 9
	return header.substr(start, header.find("\"", start) - start)


func _migrate_block(block: PackedStringArray, kind: Dictionary, ext_ids: Dictionary, ext_lines: PackedStringArray, missing: PackedStringArray) -> Dictionary:
	var facing := 0.0
	var transform_at := -1
	for i in block.size():
		var line := block[i]
		if line.begins_with("facing_deg = "):
			facing = float(line.substr(13))
		elif line.begins_with("transform = "):
			transform_at = i
	var turned := 0
	var typed := 0
	var result := PackedStringArray()
	for i in block.size():
		var line := block[i]
		if line.begins_with("facing_deg = "):
			continue
		if i == transform_at and facing != 0.0:
			var old := str_to_var(line.substr(12)) as Transform3D
			var turned_transform := Transform3D(Basis.from_euler(Vector3(0.0, -deg_to_rad(facing), 0.0)), old.origin)
			line = "transform = " + var_to_str(turned_transform)
			turned += 1
		elif line.begins_with("tag = \""):
			var tag := line.substr(7, line.length() - 8)
			var path: String = kind["folder"] + tag + ".tres"
			if ResourceLoader.exists(path):
				if not ext_ids.has(path):
					var id := "%d_%s" % [ext_ids.size() + 20, tag]
					ext_ids[path] = id
					ext_lines.append("[ext_resource type=\"Resource\" path=\"%s\" id=\"%s\"]" % [path, id])
				line = "%s = ExtResource(\"%s\")" % [kind["property"], ext_ids[path]]
				typed += 1
			else:
				missing.append(tag)
		result.append(line)
	if facing != 0.0 and transform_at < 0:
		push_error("migrate_layout_043: %s has a facing and no transform line" % block[0])
	return {"block": result, "turned": turned, "typed": typed}
