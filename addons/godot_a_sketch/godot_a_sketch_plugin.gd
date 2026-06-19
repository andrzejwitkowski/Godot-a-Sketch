@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GodotASketch"
const AUTOLOAD_PATH := "res://addons/godot_a_sketch/godot_a_sketch_autoload.gd"

var _dock: EditorDock
var _dock_panel: Control
var _last_hit: Dictionary = {}
var _input_pressed := false
var _input_dragging := false


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	var panel := preload("res://addons/godot_a_sketch/godot_a_sketch_dock.tscn").instantiate()
	_dock_panel = panel
	_dock = EditorDock.new()
	_dock.add_child(panel)
	_dock.title = "Godot-a-Sketch"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	add_dock(_dock)
	set_input_event_forwarding_always_enabled()


func _exit_tree() -> void:
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null
	_dock_panel = null
	remove_autoload_singleton(AUTOLOAD_NAME)


func _handles(object: Object) -> bool:
	return object is Node3D


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or _dock_panel == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not _dock_panel.is_raycast_modifier_active(event):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		_update_input_state(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		if _input_pressed:
			_input_dragging = true
		_cast_and_update_debug(camera, event.position, root)
	elif event is InputEventMouseButton:
		_cast_and_update_debug(camera, event.position, root)

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func get_last_hit() -> Dictionary:
	return _last_hit


func is_input_pressed() -> bool:
	return _input_pressed


func is_input_dragging() -> bool:
	return _input_dragging


func _cast_and_update_debug(camera: Camera3D, screen_pos: Vector2, root: Node3D) -> void:
	var hit := GodotASketchRaycast.cast_from_camera(camera, screen_pos, root)
	_last_hit = hit
	_dock_panel.update_raycast_debug(hit)


func _update_input_state(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_input_pressed = event.pressed
	if not event.pressed:
		_input_dragging = false
