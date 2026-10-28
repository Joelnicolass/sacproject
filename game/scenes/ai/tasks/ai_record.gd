class_name AiRecord
extends RefCounted

## A claim of a task: what it aims at (`target`, a track or null), where (`anchor`), who
## goes (`members`, with a `leader` if a wizard is among them) and how much it is worth (`score`).

var score := 0.0
var target: AiTrack
var leader: AiTrack
## A capture record: its members go to the anchor (the original's record flag 2).
var capture := false
## Who the free bodies must count to take the record: one that fights / a wizard (the required
## status 1, 2 or 9 of the original).
var needs_fighter := false
var needs_wizard := false
var anchor := Vector3.ZERO
var target_acc := AiRater.new_acc()
var members: Array[AiTrack] = []
var count := 0
var center := Vector3.ZERO
var predicted := Vector3.ZERO
var prev_center := Vector3.ZERO
var vel_acc := Vector3.ZERO
var stddev := Vector3.ZERO
var members_acc := AiRater.new_acc()
