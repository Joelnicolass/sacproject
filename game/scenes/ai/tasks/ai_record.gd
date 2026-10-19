class_name AiRecord
extends RefCounted

## A claim of a task (shiny.d:134-157 `AIRecord`): what it aims at (`target`, a track or null), where (`anchor`), who
## goes (`members`, with a `leader` if a wizard is among them) and how much it is worth (`score`).

var score := 0.0
var target: AiTrack
var leader: AiTrack
var flags := 0
var required_status := 0
var anchor := Vector3.ZERO
var target_acc := AiRater.new_acc()
var members: Array[AiTrack] = []
var count := 0
var status_or := 0
var center := Vector3.ZERO
var predicted := Vector3.ZERO
var prev_center := Vector3.ZERO
var vel_acc := Vector3.ZERO
var stddev := Vector3.ZERO
var members_acc := AiRater.new_acc()
