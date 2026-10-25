extends RefCounted

## The variation of the flora (RFC-062 cut 4) (VegetationSpecies group «Variation»), without a window.
## - flora_variation_same: two runs with the same seed give the same transforms and colors, bit for bit (and another seed
##   gives other ones).
## - flora_variation_spread: for every species in data/vegetation/species, over SAMPLES instances the tint has a
##   deviation > 0, every color lies between tint_dark and tint_light, and the scale covers >= COVER of scale_range.
## - flora_variation_clusters: a species with tint_cluster_m > 0 has neighbours (1 m apart) alike and far plants (3 x the
##   blotch) less so.
## - flora_variation_buffer: the colors in a MultiMesh buffer (floats 12-15) vary and stay between the tints.

const SPECIES_DIR := "res://data/vegetation/species/"
const SEED := 62
const SAMPLES := 2000
const COVER := 0.9
const SIDE := 8.0


func run() -> Dictionary:
	var species := _species()
	return {
		"flora_variation_same": _same(species),
		"flora_variation_spread": _spread(species),
		"flora_variation_clusters": _clusters(species),
		"flora_variation_buffer": _buffer(species),
	}


func _species() -> Array[VegetationSpecies]:
	var out: Array[VegetationSpecies] = []
	var files := Array(DirAccess.get_files_at(SPECIES_DIR))
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			out.append(load(SPECIES_DIR + file) as VegetationSpecies)
	return out


## Instances of `species` as [scale, color, basis] over a run of cells (pose identity, so scale is the length of the x axis).
static func sample(species: VegetationSpecies, seed: int, n := SAMPLES) -> Array:
	var variation := species.variation()
	var tag := species.density_tag()
	var tag_h := FloraPlacement.tag_hash(tag)
	var out := []
	var tx := 0
	while out.size() < n:
		var spots := FloraPlacement.cell_instances(seed, tag, tx, tx * 3, 20, SIDE, Vector2(0.0, 1.0))
		for i in 20:
			var at := i * FloraPlacement.STRIDE
			var t := FloraVariation.instance_transform(variation, seed, tag_h, tx, tx * 3, i, spots[at + 2], spots[at + 3], Vector3.ZERO)
			var c := FloraVariation.instance_color(variation, seed, tag_h, tx, tx * 3, i, spots[at], spots[at + 1])
			out.append([t.basis.x.length(), c, t.basis])
		tx += 1
	return out


func _same(all: Array[VegetationSpecies]) -> Dictionary:
	var wrong := []
	for species in all:
		var a := sample(species, SEED)
		var b := sample(species, SEED)
		var other := sample(species, SEED + 1)
		if a != b or a == other:
			wrong.append(species.tag)
	return {"ok": wrong.is_empty() and not all.is_empty(), "species": all.size(), "wrong": wrong}


func _spread(all: Array[VegetationSpecies]) -> Dictionary:
	var wrong := {}
	var table := {}
	for species in all:
		var data := sample(species, SEED)
		var lo := INF
		var hi := -INF
		var sum := 0.0
		var sum_sq := 0.0
		var outside := 0
		for item: Array in data:
			var s: float = item[0]
			lo = minf(lo, s)
			hi = maxf(hi, s)
			var c: Color = item[1]
			var v := c.r + c.g + c.b
			sum += v
			sum_sq += v * v
			if not _between(c, species.tint_dark, species.tint_light):
				outside += 1
		var mean := sum / data.size()
		var deviation := sqrt(maxf(sum_sq / data.size() - mean * mean, 0.0))
		var width := species.scale_range.y - species.scale_range.x
		var cover := (hi - lo) / width if width > 0.0 else 1.0
		table[species.tag] = {"tint_dev": snappedf(deviation, 0.001), "cover": snappedf(cover, 0.01)}
		if deviation <= 0.0 or cover < COVER or outside > 0:
			wrong[species.tag] = {"tint_dev": deviation, "cover": cover, "outside": outside}
	return {"ok": wrong.is_empty() and not all.is_empty(), "wrong": wrong, "sample": table.get("PCF1", {})}


static func _between(c: Color, a: Color, b: Color) -> bool:
	for k in 3:
		if c[k] < minf(a[k], b[k]) - 1e-4 or c[k] > maxf(a[k], b[k]) + 1e-4:
			return false
	return true


func _clusters(all: Array[VegetationSpecies]) -> Dictionary:
	var checked := 0
	var wrong := {}
	for species in all:
		if species.tint_cluster_m <= 0.0:
			continue
		checked += 1
		var variation := species.variation()
		var tag_h := FloraPlacement.tag_hash(species.density_tag())
		var near := 0.0
		var far := 0.0
		for k in 400:
			var x := 37.0 + float(k) * 11.3
			var z := 91.0 + float(k) * 7.7
			# The same index everywhere, so only the noise (the place) moves the color.
			var base := FloraVariation.instance_color(variation, SEED, tag_h, 0, 0, 0, x, z).g
			near += absf(base - FloraVariation.instance_color(variation, SEED, tag_h, 0, 0, 0, x + 1.0, z).g)
			far += absf(base - FloraVariation.instance_color(variation, SEED, tag_h, 0, 0, 0, x + species.tint_cluster_m * 3.0, z).g)
		if near >= far:
			wrong[species.tag] = {"near": near, "far": far}
	return {"ok": wrong.is_empty() and checked > 0, "checked": checked, "wrong": wrong}


func _buffer(all: Array[VegetationSpecies]) -> Dictionary:
	var species := all[0]
	var variation := species.variation()
	var tag_h := FloraPlacement.tag_hash(species.density_tag())
	var buffer := PackedFloat32Array()
	buffer.resize(50 * MeshPlanter.XFORM_STRIDE)
	for i in 50:
		FloraVariation.write_instance(buffer, i, Transform3D.IDENTITY, FloraVariation.instance_color(variation, SEED, tag_h, 0, 0, i, i * 2.0, 0.0))
	var greens := {}
	var inside := true
	for i in 50:
		var at := i * MeshPlanter.XFORM_STRIDE
		greens[buffer[at + 13]] = true
		inside = inside and _between(Color(buffer[at + 12], buffer[at + 13], buffer[at + 14]), species.tint_dark, species.tint_light)
	return {"ok": greens.size() > 10 and inside and buffer[0] == 1.0, "distinct_greens": greens.size(), "inside": inside}
