extends VBoxContainer

## The chat of the room. The log is the client's mirror (`chat_log`, cleared when the room changes);
## sending is a command. Rate and length errors come back through the screen's notice, not from here.
## Ref: RFC-034 034f.

@export var line_max_len: int = 200


func _ready() -> void:
	%ChatLine.max_length = line_max_len
	%ChatSend.pressed.connect(_on_send)
	%ChatLine.text_submitted.connect(_on_submitted)
	MpLobby.client.chat_received.connect(_on_chat)
	MpLobby.client.room_updated.connect(_on_room)
	MpLobby.client.room_left.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var log_view: RichTextLabel = %ChatLog
	log_view.clear()
	for entry: Dictionary in MpLobby.client.chat_log:
		_append(str(entry["name"]), str(entry["text"]))


## A new room starts an empty log; the same room keeps what is on screen.
func _on_room(_room: Dictionary) -> void:
	var log_view: RichTextLabel = %ChatLog
	if MpLobby.client.chat_log.is_empty() and log_view.get_parsed_text().length() > 0:
		log_view.clear()


func _on_chat(_seat: int, display_name: String, text: String) -> void:
	_append(display_name, text)


func _append(display_name: String, text: String) -> void:
	var log_view: RichTextLabel = %ChatLog
	log_view.add_text("%s: %s\n" % [display_name, text])


func _on_send() -> void:
	var text: String = %ChatLine.text.strip_edges()
	if text.is_empty():
		return
	MpLobby.client.send_chat(text)
	%ChatLine.text = ""


func _on_submitted(_text: String) -> void:
	_on_send()
