extends "res://addons/mp_kit/tests/mp_test.gd"

## Online rooms through the issuer, without a network: the relay URL with its token, the one-time room of
## MpTransport, the issuer's answers, who a request says this player is, codes, texts. The issuer and relay
## themselves: their npm tests; all of it together: mpkit_lab/run/online.sh.


func _relay_peer(made: Dictionary) -> MpRelayPeer:
	var peer: Variant = made.get("peer")
	while peer is MpLagPeer:
		peer = (peer as MpLagPeer).inner()
	return peer as MpRelayPeer


func test_relay_url_carries_the_token() -> void:
	var peer := MpRelayPeer.new()
	peer.start("ws://127.0.0.1:9", "p-ABC234", false, "", null, "a.b+c")
	check(peer._url == "ws://127.0.0.1:9/?role=client&room=p-ABC234&token=a.b%2Bc", "client URL: %s" % peer._url)
	check(peer._headers.is_empty(), "a token sends no secret header")
	peer.close()
	var plain := MpRelayPeer.new()
	plain.start("ws://127.0.0.1:9/", "game-7777", true, "s3cret")
	check(plain._url == "ws://127.0.0.1:9/?role=host&room=game-7777", "a server room has no token: %s" % plain._url)
	check(plain._headers == PackedStringArray(["X-Relay-Secret: s3cret"]), "a server room's host sends the secret")
	plain.close()


func test_issuer_room_is_for_one_connection() -> void:
	var url_before := MpTransport.relay_url
	MpTransport.use_relay_room("p-ROOM22", "tok1", "ws://127.0.0.1:9")
	check(MpTransport.has_relay_room(), "waiting for its connection")
	var first := _relay_peer(MpTransport.create_client(MpTransport.RELAY, "ROOM22", 7777))
	check(first != null and first._url.contains("room=p-ROOM22") and first._url.contains("token=tok1"), "first connection: %s" % (first._url if first else "none"))
	check(not MpTransport.has_relay_room(), "spent by that connection")
	var second := _relay_peer(MpTransport.create_client(MpTransport.RELAY, "x", 7777))
	check(second != null and second._url.contains("room=%s-7777" % MpTransport.relay_room) and not second._url.contains("token="), "the next one is a server room again")
	MpTransport.use_relay_room("p-HOST33", "tok2", "ws://127.0.0.1:9")
	var host := _relay_peer(MpTransport.create_server(MpTransport.RELAY, 7777, 8))
	check(host != null and host._url.contains("role=host&room=p-HOST33&token=tok2") and host._headers.is_empty(), "a host of an issuer room: token, no secret")
	for p in [first, second, host]:
		if p:
			p.close()
	MpTransport.relay_url = url_before


func test_issuer_answers() -> void:
	var created := MpIssuer.read_answer(HTTPRequest.RESULT_SUCCESS, 201, '{"code":"ABC234","room":"p-ABC234"}'.to_utf8_buffer())
	check(created["ok"] and created["data"]["code"] == "ABC234" and created["error"] == "", "201 is ok with its JSON")
	var full := MpIssuer.read_answer(HTTPRequest.RESULT_SUCCESS, 409, '{"error":"room_full"}'.to_utf8_buffer())
	check(not full["ok"] and full["status"] == 409 and full["error"] == "room_full", "a refusal carries the issuer's word")
	var odd := MpIssuer.read_answer(HTTPRequest.RESULT_SUCCESS, 502, "<html>".to_utf8_buffer())
	check(odd["error"] == "http_502" and odd["data"].is_empty(), "a body that is not JSON: http_<code>")
	var gone := MpIssuer.read_answer(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
	check(gone["error"] == "network", "no answer: network")
	var empty := MpIssuer.read_answer(HTTPRequest.RESULT_SUCCESS, 204, PackedByteArray())
	check(empty["ok"] and empty["data"].is_empty(), "204 with no body is ok")


func test_who_asks() -> void:
	var who := MpIssuer.who()
	for key in ["game", "version", "kit", "platform", "install", "session"]:
		check(who.has(key) and not str(who[key]).is_empty(), "who has %s" % key)
	check(who["kit"] == MpKit.VERSION, "the kit's version")
	check(str(who["install"]).length() >= 16 and str(who["install"]).length() <= 64, "install id length")
	check(MpIssuer.install_id() == who["install"], "the same install id every time")
	check(MpIssuer.session_id() != MpIssuer.install_id() and MpIssuer.session_id() == who["session"], "a session of its own")
	check(MpIssuer.game_version() == str(ProjectSettings.get_setting("application/config/version", "")).strip_edges() or MpIssuer.game_version() == "0", "the game's version or 0")


func test_kit_version_is_plugin_cfg() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://addons/mp_kit/plugin.cfg")
	check(err == OK and str(cfg.get_value("plugin", "version", "")) == MpKit.VERSION, "MpKit.VERSION %s = plugin.cfg %s" % [MpKit.VERSION, cfg.get_value("plugin", "version", "?")])


func test_seat_codes() -> void:
	var seen := {}
	for i in 200:
		var code := MpLocalServer.new_code()
		var valid := code.length() == MpLocalServer.CODE_LENGTH
		for c in code:
			valid = valid and MpLocalServer.CODE_CHARS.contains(c)
		check(valid, "code %s" % code)
		seen[code] = true
	check(seen.size() == 200, "200 codes, all different")


func test_online_texts() -> void:
	var flow := MpFlow.new()
	check(flow.online_text("room_full") == "That room is full", "a known word")
	check(flow.online_text("version_mismatch", {"host_version": "1.3.0"}).contains("1.3.0"), "the host's version")
	check(flow.online_text("version_too_old", {"min_version": "2.0"}).contains("2.0"), "the minimum version")
	check(flow.online_text("something_new") == flow.online_error_status % "something_new", "any other word")
	flow.free()


func test_online_mode_and_keepalive_off_the_web() -> void:
	check(MpOnline.default_mode() == (MpOnline.LISTEN if OS.has_feature("web") else MpOnline.DEDICATED), "desktop hosts through a match process")
	MpWebKeepAlive.enable()
	check(MpWebKeepAlive.is_enabled() == OS.has_feature("web"), "the keep-alive only exists in a browser")
	MpWebKeepAlive.disable()
