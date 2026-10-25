class_name LaunchPlan
extends RefCounted

## What a process starts a match with, read from its command line (LaunchFlags) or from the ticket of a room (TicketPlan): the
## setup over the rules, the AI seats, the picks already known, how many humans fit and whether the world waits for picks.
## It is plain data. SacrificeFlow applies it; nothing here touches the flow, the network or the tree.

## The overrides of the rules (level, souls, friendly fire, seed, land, map and mode).
var setup := MatchSetup.new()
## The seats an AI plays (empty = only humans).
var ai_seats: Array[AiSeat] = []
## The picks the process already knows, by MpKit slot.
var picks: Dictionary[int, WizardPick] = {}
## The seats a human can take.
var max_players := 2
## True while a seat's pick is still to come (the world does not start before it).
var wait_for_picks := false
