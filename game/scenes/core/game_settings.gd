class_name GameSettings
extends RefCounted

## The settings the game ships with, read from `config.cfg` at the project root: the version
## (`[game] version`) and the issuer of the online rooms (`[online] issuer_url_b64`, base64url, and
## `game_id`). Read once and kept; never written at runtime.
## Not: the player's options (user://), the network rules of a match (MpNetConfig).

const PATH := "res://config.cfg"

static var _file: ConfigFile


## The game's version, "" when the file has none.
static func version() -> String:
	return str(_settings().get_value("game", "version", "")).strip_edges()


## Makes `version()` the project's version (application/config/version), the one the network kit
## sends to the issuer. Called once at startup.
static func apply_version() -> void:
	var value := version()
	if value.is_empty():
		push_error("GameSettings: [game] version is missing in %s" % PATH)
		return
	ProjectSettings.set_setting("application/config/version", value)


## The issuer URL, decoded; "" (with an error) when it is missing or not base64url.
static func issuer_url() -> String:
	var url := decode_base64url(str(_settings().get_value("online", "issuer_url_b64", "")))
	if url.is_empty():
		push_error("GameSettings: [online] issuer_url_b64 in %s is missing or not base64url" % PATH)
	return url


## This game's id on the issuer, "" when the file has none.
static func game_id() -> String:
	return str(_settings().get_value("online", "game_id", "")).strip_edges()


## base64url (RFC 4648 §5, with or without padding) -> UTF-8 text; "" when it does not decode.
static func decode_base64url(encoded: String) -> String:
	var text := encoded.strip_edges().replace("-", "+").replace("_", "/")
	if text.is_empty() or text.length() % 4 == 1:
		return ""
	text += "=".repeat((4 - text.length() % 4) % 4)
	var bytes := Marshalls.base64_to_raw(text)
	return bytes.get_string_from_utf8() if not bytes.is_empty() else ""


static func _settings() -> ConfigFile:
	if _file == null:
		_file = ConfigFile.new()
		if _file.load(PATH) != OK:
			push_error("GameSettings: cannot read %s" % PATH)
	return _file
