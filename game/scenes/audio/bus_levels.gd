class_name BusLevels
extends RefCounted

## Puts the player's volumes (AudioPrefs) on the AudioServer buses: the level of each one and
## whether it is muted.


## A bus the layout lacks is skipped.
static func apply(prefs: AudioPrefs) -> void:
	if prefs == null:
		return
	for bus in AudioPrefs.BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		AudioServer.set_bus_volume_db(index, prefs.db_for(prefs.volume(bus)))
		AudioServer.set_bus_mute(index, prefs.is_bus_silent(bus))
