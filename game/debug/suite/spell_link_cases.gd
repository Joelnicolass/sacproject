extends RefCounted

## RFC-055e e3 cases of rules_suite: how a spell is wired to what casts it. Every one of the 53 SpellType points at an action scene
## whose script extends SpellAction directly (depth 1); a fresh wizard has nothing under `Caster/Actions`; `Caster.action_for(tag)`
## instances `spell.action` once and hands back an action whose `spell` is the very SpellType of the book (and whose `tag` getter
## agrees); the three balls that fly (Fireball, Rock, Insect Swarm) carry their look as a `%Mesh` child of the scene. No network.

const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const ACTION_SCRIPT := preload("res://scenes/spells/actions/spell_action.gd")
const SPELLS_DIR := "res://data/catalog/spells/"
const GODS := ["james", "stratos", "persephone", "charnel", "pyro"]
const BALLS := ["res://scenes/spells/fireball_projectile.tscn", "res://scenes/spells/rock_projectile.tscn",
	"res://scenes/spells/swarm_projectile.tscn"]

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "SpellLinkCases"
	_host.add_child(_root)
	var out := {}
	out["link_actions_depth1"] = _all_have_action()
	out["link_actions_empty"] = await _actions_empty()
	out["link_action_for"] = await _action_for()
	out["link_ball_mesh"] = _ball_meshes()
	_root.queue_free()
	## rules_suite reads `ok`: a case passes when every one of its checks holds.
	for key: String in out:
		var checks: Dictionary = out[key]
		var ok := true
		for check: String in checks:
			if check != "ok":
				ok = ok and bool(checks[check])
		checks["ok"] = ok
		print("SPELL LINK %s ok=%s" % [key, ok])
	return out


## The 53 spells: `action` is set, its root is a SpellAction whose script extends SpellAction itself, and the scene names no spell.
func _all_have_action() -> Dictionary:
	var checks := {}
	var count := 0
	for file in DirAccess.get_files_at(SPELLS_DIR):
		if not file.ends_with(".tres"):
			continue
		count += 1
		var tag := file.get_basename()
		var spell := GameData.spell(tag)
		var scene := spell.action if spell != null else null
		checks[tag + "_has_action"] = scene != null
		if scene == null:
			continue
		var node := scene.instantiate()
		var script := node.get_script() as Script
		checks[tag + "_depth1"] = node is SpellAction and script != null and (script == ACTION_SCRIPT or script.get_base_script() == ACTION_SCRIPT)
		checks[tag + "_no_spell_yet"] = node is SpellAction and (node as SpellAction).spell == null and (node as SpellAction).tag.is_empty()
		node.free()
	checks["spells_53"] = count == 53
	return checks


## A wizard just born has no action: they are instanced when a spell asks.
func _actions_empty() -> Dictionary:
	var checks := {}
	var wizard := await _wizard("pyro", 3)
	var caster := wizard.get_node("Caster") as Caster
	checks["actions_node"] = caster.actions != null
	checks["no_children"] = caster.actions != null and caster.actions.get_child_count() == 0
	wizard.queue_free()
	return checks


## For every spell and structure of the five books at level 8: the action matches by `spell`, is the same node the second time,
## and a tag outside the book answers null.
func _action_for() -> Dictionary:
	var checks := {}
	for god: String in GODS:
		var wizard := await _wizard(god, 8)
		var caster := wizard.get_node("Caster") as Caster
		var book := wizard.get_node("Spellbook") as Spellbook
		var entries: Array[SpellType] = []
		for i in book.size():
			entries.append(book.spell_at(i))
		for i in book.structure_count():
			entries.append(book.structure_at(i))
		var instanced := 0
		var good := not entries.is_empty()
		for spell in entries:
			var action := caster.action_for(spell.tag)
			good = good and action != null and action.spell == spell and action.tag == spell.tag
			good = good and caster.action_for(spell.tag) == action and action.get_parent() == caster.actions
			instanced += 1
		checks[god + "_every_spell"] = good
		checks[god + "_one_child_each"] = caster.actions.get_child_count() == instanced
		checks[god + "_unknown_null"] = caster.action_for("zzzz") == null
		wizard.queue_free()
	return checks


## Fireball, Rock and Insect Swarm: the ball's look is a MeshInstance3D named Mesh, unique in the scene (`%Mesh`).
func _ball_meshes() -> Dictionary:
	var checks := {}
	for path in BALLS:
		var node := (load(path) as PackedScene).instantiate()
		var mesh := node.get_node_or_null("%Mesh") as MeshInstance3D
		checks[path.get_file() + "_mesh"] = mesh != null and mesh.mesh != null
		node.free()
	return checks


func _wizard(god: String, level: int) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.level = level
	_root.add_child(wizard)
	wizard.god_type = GameData.god(god)
	await _host.get_tree().process_frame
	return wizard
