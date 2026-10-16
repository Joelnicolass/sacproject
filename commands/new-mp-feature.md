Create **one** replicated multiplayer feature in the **game’s Godot project** (not this skills repo). Same layout as Project → Tools → MpKit: New replicated feature.

If the game has no `addons/mp_kit`, stop and ask to install the addon.

1. Ask: id (`snake_case`), folder (`res://features` by default, or `src/features` if Clean), root (`CharacterBody2D` / `CharacterBody3D` / `Node2D` / `Node3D`), whether they want `MpCustomPipe` (Dictionary tunnel).
2. Create `res://…/<id>/<id>.gd` and `<id>.tscn` matching `MpFeatureScaffold` (submit_/apply_, MpReplicate, MultiplayerSynchronizer, optional pipe). Prefer running the addon scaffold if the user is in Godot; otherwise write the files.
3. Do not put score, copy, or this title’s loop. Leave `apply_action` empty.
4. Remind: register the scene on the match `MpSpawner`; LAN and dedicated use the same feature; tunnel = `send_custom` with no auto-broadcast.
5. If the project has no `.vscode/mpkit.code-snippets`, copy `addons/mp_kit/editor/mpkit.code-snippets`.

Return the paths you created.
