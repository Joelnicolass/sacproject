class_name AgentDiff
extends RefCounted

const Ops := preload("res://addons/agent_kit/agent_ops.gd")


static func compare(
	path_a: String,
	path_b: String,
	out_path: String,
	threshold: float,
	stats: Dictionary = {}
) -> String:
	if path_a.strip_edges().is_empty() or path_b.strip_edges().is_empty():
		return "missing --a= or --b="
	var image_a := _load_png(path_a)
	if image_a == null:
		return "cannot load --a=%s" % path_a
	var image_b := _load_png(path_b)
	if image_b == null:
		return "cannot load --b=%s" % path_b
	if image_a.get_size() != image_b.get_size():
		image_b.resize(image_a.get_width(), image_a.get_height(), Image.INTERPOLATE_BILINEAR)
	var w := image_a.get_width()
	var h := image_a.get_height()
	var overlay := Image.create(w, h, false, Image.FORMAT_RGBA8)
	overlay.fill(Color(0, 0, 0, 1))
	var changed := 0
	var total := w * h
	var cutoff := clampf(threshold, 0.0, 1.0)
	for y in h:
		for x in w:
			var ca := image_a.get_pixel(x, y)
			var cb := image_b.get_pixel(x, y)
			var delta := maxf(
				absf(ca.r - cb.r),
				maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))
			)
			if delta > cutoff:
				changed += 1
				overlay.set_pixel(x, y, Color(1, 0, 1, 1))
			else:
				var gray := (ca.r + ca.g + ca.b) / 3.0 * 0.35
				overlay.set_pixel(x, y, Color(gray, gray, gray, 1))
	var percent := 0.0
	if total > 0:
		percent = 100.0 * float(changed) / float(total)
	print("AGENT_DIFF changed=%d total=%d percent=%.3f" % [changed, total, percent])
	stats["changed"] = changed
	stats["total"] = total
	stats["percent"] = percent
	if not out_path.strip_edges().is_empty():
		Ops.ensure_parent_dir(out_path)
		var err := overlay.save_png(Ops.fs_path(out_path))
		if err != OK:
			return "save overlay failed (%d)" % err
	return ""


static func _load_png(path: String) -> Image:
	var image := Image.new()
	var err := image.load(Ops.fs_path(path))
	if err != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image
