extends Node

## The game-wide event bus (autoload `Events`): facts that systems which do not know each other care about (combat,
## HUD, audio, camera, notices). Only signals: no state, no methods. The owner of each fact emits it, once, on every peer
## where the fact becomes visible (the server and the clients alike), so a listener never asks who is the authority.
## Local events between a parent and its children stay plain signals of their own nodes.

## A body's health went down on this peer: a hit on the server, or the replicated `current` dropping on a client.
## `body` is the node that owns the Health (a creature, a wizard, a building, a Sac Doctor); `lost` is how much it dropped;
## `current` and `maximum` are the bar after the drop (`current` 0 = it died). Emitted by Health.
signal body_hurt(body: Node3D, lost: float, current: float, maximum: float)

## A sacrifice ritual began on this peer (it left its OFF phase), or a client received one already running.
## Read its `kind`, `caster_slot` and `target_slot`. Emitted by Ritual.
signal ritual_started(ritual: Ritual)

## A ritual that was running ended on this peer: `completed` true when its last round finished, false when it was
## cancelled. Emitted by Ritual.
signal ritual_ended(ritual: Ritual, completed: bool)

## The match has a result on this peer. `winner_slots` is the winning team (empty: nobody is left); `defeated_slots`
## the sides that lost before the end. Emitted by MatchState (the server when it decides, a client when the snapshot
## arrives).
signal match_ended(winner_slots: Array[int], defeated_slots: Array[int])
