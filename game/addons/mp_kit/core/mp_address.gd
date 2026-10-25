class_name MpAddress
extends RefCounted

## What a person types to reach a server, read the same way everywhere (the boot menu's Join field, the lobby screen,
## MpFlow.join_address): "192.168.1.5", "play.example.com", either with ":port", "#CODE" at the end for a private
## match, or a full "ws://…" / "wss://…" URL (WebSocket and relay). Pure: no network. Not: connecting.

var host: String = ""
var port: int = 0
## The code after "#", in upper case ("" = none).
var code: String = ""
## A full URL when one was typed ("" otherwise); then host and port are not used.
var url: String = ""
## "" when the text is usable; otherwise why not ("empty", "bad_port", "bad_host").
var error: String = ""


static func parse(text: String, default_port: int) -> MpAddress:
	var out := MpAddress.new()
	var clean := text.strip_edges()
	if clean.contains("#"):
		out.code = clean.get_slice("#", 1).strip_edges().to_upper()
		clean = clean.get_slice("#", 0).strip_edges()
	if clean.is_empty():
		out.error = "empty"
		return out
	if clean.contains("://"):
		out.url = clean
		return out
	out.host = clean
	out.port = default_port
	if clean.count(":") == 1:
		out.host = clean.get_slice(":", 0)
		var raw := clean.get_slice(":", 1)
		if not raw.is_valid_int() or int(raw) < 1 or int(raw) > 65535:
			out.error = "bad_port"
			return out
		out.port = int(raw)
	if not MpLan.is_valid_ipv4(out.host) and not MpLan.is_valid_hostname(out.host):
		out.error = "bad_host"
	return out


func is_valid() -> bool:
	return error.is_empty()


## The text again ("host:port#CODE" or the URL), for a field that shows it.
func to_text() -> String:
	var base := url if not url.is_empty() else "%s:%d" % [host, port]
	return base + ("#" + code if not code.is_empty() else "")
