class_name ActionKeyLabel
extends RefCounted

## The text of the first key bound to an InputMap action («Q», «Shift+1»), or "" when it has none. Presentation only.


static func of(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
			var text := UiText.t("UI_KEY_SPACE") if code == KEY_SPACE else OS.get_keycode_string(code)
			if key.alt_pressed:
				text = "Alt+" + text
			if key.shift_pressed:
				text = "Shift+" + text
			if key.ctrl_pressed:
				text = "Ctrl+" + text
			return text
	return ""
