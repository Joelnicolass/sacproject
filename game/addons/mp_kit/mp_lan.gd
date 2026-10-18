class_name MpLan
extends RefCounted


## DNS-style name: dot-separated labels of letters, digits and inner hyphens.
static func is_valid_hostname(value: String) -> bool:
	if value.is_empty() or value.length() > 253:
		return false
	for label in value.split("."):
		if label.is_empty() or label.length() > 63:
			return false
		if label.begins_with("-") or label.ends_with("-"):
			return false
		for i in label.length():
			var c := label.unicode_at(i)
			var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 45
			if not ok:
				return false
	return true


static func is_valid_ipv4(value: String) -> bool:
	var parts := value.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if part.is_empty() or not part.is_valid_int():
			return false
		if part.length() > 1 and part.begins_with("0"):
			return false
		var octet := int(part)
		if octet < 0 or octet > 255:
			return false
	return true


static func get_local_ipv4() -> String:
	var addresses: PackedStringArray = IP.get_local_addresses()
	var fallback := ""
	for address in addresses:
		if not is_valid_ipv4(address):
			continue
		if address.begins_with("127."):
			continue
		if address == "0.0.0.0":
			continue
		if _is_private_lan(address):
			return address
		if fallback.is_empty():
			fallback = address
	return fallback


## Parent the returned beacon (or it is already added to `parent`).
static func advertise(parent: Node, room_name: String = "MpKit", game_port: int = -1) -> MpLanBeacon:
	var beacon := MpLanBeacon.new()
	parent.add_child(beacon)
	beacon.start_advertise(room_name, game_port)
	return beacon


static func browse(parent: Node) -> MpLanBeacon:
	var beacon := MpLanBeacon.new()
	parent.add_child(beacon)
	beacon.start_browse()
	return beacon


static func _is_private_lan(address: String) -> bool:
	if address.begins_with("10."):
		return true
	if address.begins_with("192.168."):
		return true
	if address.begins_with("172."):
		var second := int(address.split(".")[1])
		return second >= 16 and second <= 31
	return false
