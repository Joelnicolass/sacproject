extends Node

## The lobby screen of the menu connects through `data/net/online_config.tres` (relay) with no transport flag.
## Run against a local relay + room server: `-- --relay-url=ws://127.0.0.1:8099 --relay-room=sacrifice-local`
## (flags win over the resource's relay address, never needed to pick the transport). Prints `LOBBY ONLINE PASS|FAIL`.

const WATCHDOG_S := 20.0


func _ready() -> void:
	var timer := get_tree().create_timer(WATCHDOG_S)
	timer.timeout.connect(func() -> void: _finish(false, "timeout, transport=%s" % MpLobby.client.transport))
	var screen: Control = load("res://scenes/ui/lobby/lobby_screen.tscn").instantiate()
	add_child(screen)
	var before := MpKit.transport
	screen.call("_on_connect_requested", "Probe", "")
	print("transport before=%s lobby_client=%s kit=%s room=%s" % [before, MpLobby.client.transport, MpKit.transport, MpTransport.relay_room_for(7700)])
	var client := MpLobby.client
	while not client.is_online():
		await get_tree().process_frame
	var ok := client.transport == MpTransport.RELAY and MpKit.transport == MpTransport.RELAY
	_finish(ok, "online=%s kit=%s" % [client.is_online(), MpKit.transport])


func _finish(ok: bool, detail: String) -> void:
	print("LOBBY ONLINE %s %s" % ["PASS" if ok else "FAIL", detail])
	get_tree().quit(0 if ok else 1)
