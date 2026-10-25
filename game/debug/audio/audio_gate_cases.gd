extends RefCounted

## RFC-052 052a (F360): the AudioGate. The rule (every combination of flags) and this process: with the gate closed
## (plain headless, --dedicated, --room-server) SoundBus built nothing; with it open (--audio-probe) it works. `expect_open` comes from the runner's --expect-gate.


func run(host: Node, expect_open: bool) -> Dictionary:
	var results := {}
	results["audio_gate_rule"] = _rule()
	results["audio_gate_process"] = await _process(host, expect_open)
	return results


func _rule() -> Dictionary:
	var table := [
		# args, headless, dedicated, expected
		[[], false, false, true],
		[[], true, false, false],
		[["--audio-probe"], true, false, true],
		[["--dedicated"], false, false, false],
		[["--room-server"], false, false, false],
		[["--audio-probe", "--dedicated"], true, false, false],
		[["--audio-probe", "--room-server"], true, false, false],
		[["--audio-probe"], true, true, false],
		[[], false, true, false],
	]
	var wrong := []
	for row in table:
		var got := AudioGate.decide(PackedStringArray(row[0]), row[1], row[2])
		if got != row[3]:
			wrong.append({"args": row[0], "headless": row[1], "dedicated": row[2], "got": got})
	return {"ok": wrong.is_empty(), "wrong": wrong}


func _process(host: Node, expect_open: bool) -> Dictionary:
	var open := AudioGate.is_open()
	var cue := SoundCue.new()
	cue.streams = [preload_free_stream()]
	var played: bool = SoundBus.play_2d(cue, &"gate_case", SoundEvent.CLICK)
	for i in 3:
		await host.get_tree().process_frame
	var info := {
		"expected_open": expect_open,
		"open": open,
		"bus_active": SoundBus.is_active(),
		"bus_children": SoundBus.get_children().filter(func(c: Node) -> bool: return c is AudioStreamPlayer or c is AudioStreamPlayer3D).size(),
		"has_log": SoundBus.sound_log != null,
		"played": played,
	}
	var ok := open == expect_open
	if expect_open:
		ok = ok and info.bus_active and info.bus_children == SoundBus.pool_3d_size + SoundBus.pool_2d_size \
			and info.has_log and played
	else:
		ok = ok and not info.bus_active and info.bus_children == 0 and not info.has_log \
			and not played
	info["ok"] = ok
	return info


## A stream made here, not loaded from a file (the closed gate must not load one even to be handed it).
static func preload_free_stream() -> AudioStream:
	var stream := AudioStreamWAV.new()
	stream.data = PackedByteArray([0, 40, 0, 216])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 4
	return stream
