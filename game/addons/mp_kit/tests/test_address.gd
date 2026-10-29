extends "res://addons/mp_kit/tests/mp_test.gd"

## MpAddress: what a person types to reach a server, read the same way by the menu, the lobby and MpFlow.


func test_forms() -> void:
	var a := MpAddress.parse("192.168.1.5", 7777)
	check(a.is_valid() and a.host == "192.168.1.5" and a.port == 7777, "an IP takes the default port")
	a = MpAddress.parse(" play.example.com:7800 ", 7777)
	check(a.is_valid() and a.host == "play.example.com" and a.port == 7800, "a name with :port")
	a = MpAddress.parse("127.0.0.1:7810#ab12cd", 7777)
	check(a.is_valid() and a.port == 7810 and a.code == "AB12CD", "#code at the end, in upper case")
	a = MpAddress.parse("wss://relay.example.com/x", 7777)
	check(a.is_valid() and a.url == "wss://relay.example.com/x", "a full URL is kept as is")
	check(MpAddress.parse("127.0.0.1:7800#AB", 0).to_text() == "127.0.0.1:7800#AB", "to_text gives it back")


func test_errors() -> void:
	check(MpAddress.parse("  ", 7777).error == "empty", "empty")
	check(MpAddress.parse("host:99999", 7777).error == "bad_port", "a port out of range")
	check(MpAddress.parse("host:abc", 7777).error == "bad_port", "a port that is not a number")
	check(MpAddress.parse("bad host!", 7777).error == "bad_host", "a host that is neither an IP nor a name")
