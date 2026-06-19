@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GodotASketch"
const AUTOLOAD_PATH := "res://addons/godot_a_sketch/godot_a_sketch_autoload.gd"

var _dock: EditorDock


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	var panel := preload("res://addons/godot_a_sketch/godot_a_sketch_dock.tscn").instantiate()
	_dock = EditorDock.new()
	_dock.add_child(panel)
	_dock.title = "Godot-a-Sketch"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	add_dock(_dock)


func _exit_tree() -> void:
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null
	remove_autoload_singleton(AUTOLOAD_NAME)
