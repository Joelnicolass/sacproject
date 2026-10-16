class_name AgentCli
extends RefCounted

## Parse `--agent=verb` and `--key=value` from user args (after `--`) and cmdline.

const DEFAULT_UA := "AgentKit/0.1.4 (Godot studio kit; agent tools)"


static func help_text() -> String:
	return """AgentKit 0.1.4 — tools for AI agents (no gameplay).

godot --path PROJECT [--resolution WxH] -- --agent=VERB [flags]

Verbs:
  help      Print this text
  info      Project / engine JSON (includes res://agent workspace)
  capture   Screenshot current or --scene=  → --out=file.png
  flow      Run JSON steps (click, press/hold, select, call/harness, repeat, wait_until/signal, diff) → --flow= --out=dir
  fetch     HTTP GET/POST → --url= --out=file [--method=GET] [--ua=]
  inspect   Node tree / unique names → --scene= [--node=%X] [--unique]
  diff      Compare two PNGs → --a= --b= [--out=diff.png] [--threshold=0.02]

Flags (after --):
  --scene=res://...     Change to this scene first
  --out=                PNG file (capture) or directory (flow) or dest file
  --wait=1.1            Seconds after scene load before capture/flow
  --flow=               Flow spec: res://, absolute, or name under res://agent/flows/
  --url= --method= --ua=
  --a= --b=             Diff inputs
  --node=               Inspect this node (%UniqueName or path)
  --unique              Inspect: only unique names
  --threshold=0.02      Diff: per-channel delta 0..1
  --fail-on-error       Fail the verb if Godot logged ERROR / SCRIPT ERROR

Host workspace (not the addon): res://agent/flows, harness, fixtures, out.
press only accepts an InputMap action that already exists in the editor.
A missing action is a product bug — do not send keycodes. Harness must not
move actors or inject keys. Do not add agent_* methods to src/.

Do not use `godot -s /tmp/foo.gd extends SceneTree` for captures: class_name
scripts compile before autoloads (PortraitCache / DraftCopy missing).

Wrapper: addons/agent_kit/cli.sh PROJECT capture --scene=res://x.tscn --out=res://agent/out/a.png
"""


static func parse() -> Dictionary:
	var cmd := {
		"verb": value("agent"),
		"scene": first(["scene", "agent-scene"]),
		"out": first(["out", "agent-out"]),
		"wait": first(["wait", "agent-wait"], "1.1"),
		"flow": first(["flow", "agent-flow"]),
		"url": first(["url", "agent-url"]),
		"method": first(["method", "agent-method"], "GET"),
		"ua": first(["ua", "user-agent", "agent-ua"], DEFAULT_UA),
		"a": first(["a", "agent-a"]),
		"b": first(["b", "agent-b"]),
		"node": first(["node", "agent-node"]),
		"unique": flag("unique") or flag("agent-unique"),
		"threshold": first(["threshold", "agent-threshold"], "0.02"),
		"fail_on_error": flag("fail-on-error") or flag("agent-fail-on-error"),
	}
	return cmd


static func first(names: PackedStringArray, default: String = "") -> String:
	for name in names:
		var got := value(name)
		if not got.is_empty():
			return got
	return default


static func value(name: String, default: String = "") -> String:
	var prefix := "--%s=" % name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	for arg in OS.get_cmdline_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default


static func flag(name: String) -> bool:
	var needle := "--%s" % name
	for arg in OS.get_cmdline_user_args():
		if arg == needle or arg.begins_with(needle + "="):
			return arg == needle or arg.ends_with("=1") or arg.ends_with("=true")
	for arg in OS.get_cmdline_args():
		if arg == needle or arg.begins_with(needle + "="):
			return arg == needle or arg.ends_with("=1") or arg.ends_with("=true")
	return false


static func wait_seconds(cmd: Dictionary) -> float:
	return maxf(0.0, float(str(cmd.get("wait", "1.1"))))


static func threshold(cmd: Dictionary) -> float:
	return clampf(float(str(cmd.get("threshold", "0.02"))), 0.0, 1.0)
