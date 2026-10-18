class_name MpMatchFiles
extends RefCounted

## Files of one match under `<root>/<match_id>/`: ticket.json, state.json, result.json, log.txt.
## The launcher writes the ticket; the match agent writes state and result.

const TICKET := "ticket.json"
const STATE := "state.json"
const RESULT := "result.json"
const LOG := "log.txt"
const REGISTRY := "registry.json"
const ID_MAX_LEN := 64


## Letters, digits, `_` and `-` only: the id becomes a folder name.
static func is_valid_id(match_id: String) -> bool:
	if match_id.is_empty() or match_id.length() > ID_MAX_LEN:
		return false
	for i in match_id.length():
		var c := match_id.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or c == 45
		if not ok:
			return false
	return true


static func dir_of(root: String, match_id: String) -> String:
	return "%s/%s" % [root, match_id]


static func path_of(root: String, match_id: String, file: String) -> String:
	return "%s/%s/%s" % [root, match_id, file]


static func registry_path(root: String) -> String:
	return "%s/%s" % [root, REGISTRY]


static func sha256(token: String) -> String:
	return token.sha256_text()


## 128-bit random token, hex.
static func new_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


static func ensure_dir(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


## Atomic write (tmp + rename). `private` sets 0600 where the platform supports it.
static func write_json(path: String, data: Dictionary, private: bool = false) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data))
	f.close()
	if private:
		FileAccess.set_unix_permissions(tmp, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## Empty Dictionary if the file is missing or is not a JSON object.
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		remove_dir("%s/%s" % [path, sub])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
