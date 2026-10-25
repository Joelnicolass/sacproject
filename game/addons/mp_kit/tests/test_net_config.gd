extends "res://addons/mp_kit/tests/mp_test.gd"

## MpNetConfig: one .tres for the network; the desktop keeps its transport, TLS only when asked for.


func test_desktop_defaults() -> void:
	var cfg := MpNetConfig.new()
	check(MpNetConfig.can_host(), "a desktop build can host")
	check(cfg.effective_transport() == MpTransport.ENET, "with no flag, the transport of the .tres (ENet)")
	cfg.transport = "ws"
	check(cfg.effective_transport() == MpTransport.WS, "a .tres with ws gives WebSocket")
	check(cfg.effective_port() == cfg.port, "with no flag, the port of the .tres")


func test_tls_only_when_set() -> void:
	var cfg := MpNetConfig.new()
	check(cfg.server_tls() == null and cfg.client_tls() == null, "no certificate and no client TLS = plain ws://")
	cfg.tls_client = true
	check(cfg.client_tls() != null, "client TLS on = wss:// with the system's CAs")
	cfg.tls_common_name = "game.example.com"
	check(cfg.client_tls() != null, "a certificate name of its own is accepted")
	check(MpTransport.server_tls("", "") == null and MpTransport.client_tls_from_flags() == null, "no TLS files and no flags = plain")
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	cfg.tls_key = key
	cfg.tls_certificate = crypto.generate_self_signed_certificate(key, "CN=mpkit.test")
	check(cfg.server_tls() != null, "certificate + key = the server speaks wss:// itself")
