extends SceneTree

## RFC-054 054a (F380): writes scenes/map/maps/<tag>/flora.res (FloraMap, binary, compressed) from the map's
## widgets.json, ntts.json and terrain (FloraMapBuilder; the clearings are bake_map_layout's). No original install
## needed. Re-baking is safe: the file is data only, nothing edits it by hand.
##   "$GODOT" --headless --path game --quit-after 6000 --script res://tools/bake/bake_flora_map.gd -- --map=<tag>
##   "$GODOT" --headless --path game --quit-after 6000 --script res://tools/bake/bake_flora_map.gd -- --all
## Add --check to compare the saved files with the JSON instead of writing (prints the counts and sizes; exit 1 on a
## difference). Needs the project imported once (class names).

var _failures: Array[String] = []


func _initialize() -> void:
	# Deferred: an error inside _initialize itself hangs the process instead of quitting.
	_run.call_deferred()


func _run() -> void:
	var check := false
	var every := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--check":
			check = true
		elif argument == "--all":
			every = true
	var tags := FloraMapBuilder.ORIGINAL_MAPS if every else PackedStringArray([String(MapCatalog.current_tag())])
	var catalog := MapCatalog.shared()
	for tag in tags:
		var map := catalog.find(StringName(tag))
		if map == null:
			_fail("%s: not in the map catalog" % tag)
			continue
		var builder := FloraMapBuilder.new()
		var flora := builder.build(map)
		if flora == null:
			_fail("%s: could not build" % tag)
			continue
		var path := FloraMapBuilder.path_of(map)
		if check:
			_check(tag, flora, path, builder.report)
		else:
			var error := ResourceSaver.save(flora, path, ResourceSaver.FLAG_COMPRESS)
			if error != OK:
				_fail("%s: could not write %s (error %d)" % [tag, path, error])
				continue
			print("bake_flora_map: %s written %s (%d plants of %d rows, %d over the cap, %d bytes)" % [
				tag, path, builder.report["kept"], builder.report["rows"], builder.report["capped"], _size(path)])
	if check:
		print("bake_flora_map: CHECK PASS" if _failures.is_empty() else "bake_flora_map: CHECK FAIL (%d)" % _failures.size())
	for failure in _failures:
		print("bake_flora_map: FAIL %s" % failure)
	quit(0 if _failures.is_empty() else 1)


func _check(tag: String, fresh: FloraMap, path: String, report: Dictionary) -> void:
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as FloraMap
	if saved == null:
		_fail("%s: %s does not load" % [tag, path])
		return
	if saved.tags != fresh.tags or saved.resolution != fresh.resolution or not is_equal_approx(saved.texel_m, fresh.texel_m):
		_fail("%s: tags or grid differ (%s vs %s)" % [tag, saved.tags, fresh.tags])
		return
	for i in fresh.tags.size():
		if i >= saved.counts.size() or saved.counts[i] != fresh.counts[i]:
			_fail("%s: counts of %s differ" % [tag, fresh.tags[i]])
	var parts := PackedStringArray()
	for i in saved.tags.size():
		parts.append("%s %d" % [saved.tags[i], saved.tag_total(i)])
	print("flora %s: %d plants (%s) · %d rows · %d over the cap · %d bytes" % [
		tag, saved.total(), ", ".join(parts), report["rows"], report["capped"], _size(path)])


func _size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file else -1


func _fail(text: String) -> void:
	_failures.append(text)
