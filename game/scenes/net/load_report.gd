class_name LoadReport
extends Node

## Tells the flow how far this peer's world has loaded: the warm-up's progress (0..1, the loading screen's bar) and its end, which
## is this peer's «I loaded» for the match gate (a client tells the server, the server or solo opens its own seat). The warm-up's
## signals arrive here by the connections of match.tscn. The one node of the match that talks to the flow about loading.
## What it does not do: warm, draw or decide when the match starts (MpMatchGate).
## Contract: MpFlow.report_world_progress(ratio: float) and MpFlow.report_world_loaded().


## The warm-up moved (`ShaderWarmup.progressed`).
func report_progress(ratio: float) -> void:
	var flow := MpFlow.find_in_tree(self)
	if flow != null:
		flow.report_world_progress(ratio)


## The warm-up ended (`ShaderWarmup.finished`): this peer's world is loaded.
func report_loaded() -> void:
	var flow := MpFlow.find_in_tree(self)
	if flow != null:
		flow.report_world_loaded()
