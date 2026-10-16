# Captura Godot (fallback)

**Prefer AgentKit** (`godot-agent-kit`): autoload, survives `change_scene`, does not skip game autoloads.

```bash
addons/agent_kit/cli.sh /abs/game capture --scene=res://scenes/ui/boot.tscn --out=res://agent/out/boot.png
```

Fallback **only** if the addon is missing. Temporary `SceneTree` script (`/tmp`); **delete** it after. Do not reference game `class_name` types in that script.

```gdscript
extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	var packed := load("res://path/to/scene.tscn") as PackedScene
	root.add_child(packed.instantiate())
	create_timer(1.1).timeout.connect(_shot)

func _shot() -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("user://playtest.png")
	img.save_png(path)
	print("saved ", path)
	quit(0)
```

```bash
Godot --path /abs/game --resolution 1152x648 -s /tmp/capture.gd
```

`create_timer` in `_initialize` works; a child `Timer` is often not in the tree yet.

Do not use `--headless` if you need real pixels. Headless is for parse / `--quit-after`.
