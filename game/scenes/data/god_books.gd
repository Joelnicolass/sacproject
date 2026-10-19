@tool
class_name GodBooks
extends Resource

## What each god's book offers (RFC-040 040a): god -> {creatures, spells, structures, levels}. `levels` maps a tag to the
## wizard level at which it enters the book. Plain data in data/catalog/books.tres, editable in the inspector.
## A typed entry per god arrives with RFC-042.

const PATH := "res://data/catalog/books.tres"

@export var books: Dictionary = {}
