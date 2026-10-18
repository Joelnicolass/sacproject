class_name DetCli
extends RefCounted

## Reads the options the determinism runner (det_run.sh) passes after `--`:
## `--out=path.json`, `--events=path.events`, plus whatever the project adds (`--seed=7`, `--flag`).
## Pure static helpers, no state.


## Every `--key=value` (or bare `--flag`, value true) of OS.get_cmdline_user_args().
static func args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var cut := body.find("=")
		if cut < 0:
			out[body] = true
		else:
			out[body.substr(0, cut)] = body.substr(cut + 1)
	return out


## Where to write the JSON report ("" when --out is not a .json path).
static func out_path() -> String:
	var path := str(args().get("out", ""))
	return absolute(path) if path.ends_with(".json") else ""


## Where to write the event lines ("" when --events was not given).
static func events_path() -> String:
	var path := str(args().get("events", ""))
	return absolute(path) if not path.is_empty() else ""


## Relative paths are relative to the project.
static func absolute(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)
