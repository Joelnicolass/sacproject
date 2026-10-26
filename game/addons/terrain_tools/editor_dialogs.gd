@tool
extends RefCounted

## The terrain tools' dialogs in the editor: a message (also printed to the Output) and a question with «OK» and
## «Cancelar». Each dialog frees itself once closed. Not: what the tools do.


## Shows `text` under `title` and prints it.
static func say(title: String, text: String) -> void:
	print("%s: %s" % [title, text])
	_show(AcceptDialog.new(), title, text)


## Asks `text` under `title`; `on_yes` runs when it is accepted.
static func ask(title: String, text: String, on_yes: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.confirmed.connect(on_yes)
	_show(dialog, title, text)


static func _show(dialog: AcceptDialog, title: String, text: String) -> void:
	dialog.title = title
	dialog.dialog_text = text
	dialog.dialog_autowrap = true
	dialog.min_size = Vector2i(520, 0)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
