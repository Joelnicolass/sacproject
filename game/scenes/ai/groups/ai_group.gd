class_name AiGroup
extends RefCounted

## A group of nearby bodies of one category (shiny.d:105-124 `AIGroup`, slot-4 groups): center, status OR, and the
## aggregates the stance and the threat read. Made by AiGroups every 60 ticks and refreshed every 6.

var prio := 0
var members: Array[AiTrack] = []
var status_or := 0
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
