@tool
extends EditorPlugin

const AUTOLOAD_NAME := "AgentKit"
const AUTOLOAD_PATH := "res://addons/agent_kit/agent_kit.gd"
const Cli := preload("res://addons/agent_kit/agent_cli.gd")


func _enter_tree() -> void:
	add_tool_menu_item("AgentKit: Print CLI help", _on_print_help)


func _exit_tree() -> void:
	remove_tool_menu_item("AgentKit: Print CLI help")


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _on_print_help() -> void:
	print(Cli.help_text())
