extends "res://addons/mp_kit/tests/mp_test.gd"

## MpKit roles: is_authority, local_slot and has_local_slot in solo, listen host, dedicated and an unassigned client.

const PORT := 7795


func _kit() -> Node:
	var kit: Node = load("res://addons/mp_kit/mp_kit.gd").new()
	kit.name = "MpKitUnderTest"
	tree.root.add_child(kit)
	kit.configure(PORT, 4)
	return kit


func test_solo() -> void:
	var kit := _kit()
	check(kit.is_authority(), "solo is the authority")
	check(kit.local_slot() == 1 and kit.has_local_slot(), "solo plays slot 1")
	kit.free()


func test_listen_host() -> void:
	var kit := _kit()
	check(kit.host() == OK, "the listen host opens the port")
	check(kit.is_authority() and kit.is_listen_host(), "the host is the authority")
	check(kit.local_slot() == 1 and kit.has_local_slot(), "the host plays slot 1")
	kit.leave()
	kit.free()


func test_dedicated() -> void:
	var kit := _kit()
	check(kit.host_dedicated() == OK, "the dedicated opens the port")
	check(kit.is_authority() and kit.is_dedicated(), "the dedicated is the authority")
	check(kit.local_slot() == 0 and not kit.has_local_slot(), "the dedicated has no player")
	kit.leave()
	kit.free()


func test_client_without_slot() -> void:
	var kit := _kit()
	check(kit.join("127.0.0.1", PORT + 1) == OK, "a client peer starts")
	check(not kit.is_authority(), "a client is not the authority")
	check(kit.local_slot() == 0 and not kit.has_local_slot(), "before the server answers the client has no slot (no guess)")
	kit.leave()
	check(kit.is_authority() and kit.local_slot() == 1, "after leave it is solo again")
	kit.free()
