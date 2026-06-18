@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GodotASketch"
const AUTOLOAD_PATH := "res://addons/godot_a_sketch/godot_a_sketch_autoload.gd"


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
