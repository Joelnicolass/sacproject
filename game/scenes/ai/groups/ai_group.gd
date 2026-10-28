class_name AiGroup
extends RefCounted

## A group of nearby bodies of one relation (AiTrack.Relation): center, who is in it, and the
## aggregates the stance and the threat read. Made by AiGroups every 60 ticks and refreshed every 6.
## Ref: shiny.d:105-124 `AIGroup`, slot-4 groups.

var prio := 0
var members: Array[AiTrack] = []
## A member fights / a member is a wizard (the bits 1 and 8 of the original's status OR).
var has_fighter := false
var has_wizard := false
var center := Vector3.ZERO
var predicted := Vector3.ZERO
var prev_center := Vector3.ZERO
var avg_vel := Vector3.ZERO
var stddev := Vector3.ZERO
var count := 0
var acc := AiRater.new_acc()
var mana_sum := 0
var max_mana_sum := 0
var health_sum := 0
var health_sum2 := 0
var ready_count := 0
var souls_sum := 0
