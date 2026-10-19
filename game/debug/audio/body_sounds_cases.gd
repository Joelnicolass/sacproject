extends RefCounted

## RFC-052 052c (F362): how a body finds its set, without the original's audio (fixture sets only).
## - SoundLibrary.creature(tag) uses the file name of the CreatureType: EHTH's catalog file is EHTH_2.tres, so its set is
##   creatures/EHTH_2.tres; ehtH (its own file ehtH.tres) does not take it. A tag the catalog lacks keeps the tag (`test`).
## - A tag with no set anywhere is null (silence) and the lookup prints nothing.
## Runs only with the gate open (`--audio-probe`).

const FIXTURE_ROOT := "res://debug/audio/fixtures/sets/"
const EMPTY_ROOT := "res://debug/audio/fixtures/empty/"


func run(_host: Node) -> Dictionary:
	var results := {}
	SoundLibrary.roots = PackedStringArray([FIXTURE_ROOT])
	SoundLibrary.clear_cache()
	var ehth := SoundLibrary.creature(&"EHTH")
	var other := SoundLibrary.creature(&"ehtH")
	var plain := SoundLibrary.creature(&"test")
	results["body_sounds_catalog_file"] = {
		"ok": ehth != null and ehth.resource_path == FIXTURE_ROOT + "creatures/EHTH_2.tres" and other == null and plain != null,
		"EHTH": ehth.resource_path if ehth else "",
		"ehtH": other.resource_path if other else "",
		"test": plain.resource_path if plain else "",
		"file_of_EHTH": SoundLibrary.type_file(GameData.creature("EHTH"), &"EHTH"),
	}
	SoundLibrary.roots = PackedStringArray([EMPTY_ROOT])
	SoundLibrary.clear_cache()
	results["body_sounds_no_set"] = {"ok": SoundLibrary.creature(&"nmuh") == null and SoundLibrary.wizard(&"cwa0") == null \
		and SoundLibrary.sound_set("world") == null}
	SoundLibrary.reset_roots()
	return results
