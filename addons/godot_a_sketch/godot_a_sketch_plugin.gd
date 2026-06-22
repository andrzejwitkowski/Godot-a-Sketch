@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GodotASketch"
const AUTOLOAD_PATH := "res://addons/godot_a_sketch/godot_a_sketch_autoload.gd"

const GhostBrushScript := preload("res://addons/godot_a_sketch/godot_a_sketch_ghost_brush.gd")
const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const ShaderValidator := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_validator.gd")
const PaintSession := preload("res://addons/godot_a_sketch/godot_a_sketch_paint_session.gd")
const Raycast := preload("res://addons/godot_a_sketch/godot_a_sketch_raycast.gd")
const DockPanel := preload("res://addons/godot_a_sketch/godot_a_sketch_dock.gd")
const Brushable := preload("res://addons/godot_a_sketch/godot_a_sketch_brushable.gd")

var _dock: EditorDock
var _dock_panel: DockPanel
var _ghost: Node3D
var _paint_session: PaintSession
var _last_hit: Dictionary = {}
var _paint_last_uv := Vector2(-1.0, -1.0)
var _input_pressed := false
var _input_dragging := false


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	var panel := preload("res://addons/godot_a_sketch/godot_a_sketch_dock.tscn").instantiate() as DockPanel
	_dock_panel = panel
	_dock = EditorDock.new()
	_dock.add_child(panel)
	_dock_panel.ghost_settings_changed.connect(_on_ghost_settings_changed)
	_dock.title = "Godot-a-Sketch"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	add_dock(_dock)
	set_input_event_forwarding_always_enabled()

	var template: Shader = load(Constants.LAYER_TEMPLATE_PATH) as Shader
	assert(template != null and ShaderValidator.is_layer_shader(template))
	var selection := get_editor_interface().get_selection()
	selection.selection_changed.connect(_on_selection_changed)

	_ghost = GhostBrushScript.new()
	_ghost.name = Constants.GHOST_NODE_NAME
	_paint_session = PaintSession.new()
	scene_changed.connect(_on_scene_changed)
	_attach_ghost_to_edited_scene()


func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _ghost:
		if _ghost.get_parent():
			_ghost.get_parent().remove_child(_ghost)
		_ghost.queue_free()
		_ghost = null
	_paint_session = null
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
		_hide_ghost()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		if btn.button_index == MOUSE_BUTTON_LEFT:
			if not btn.pressed and _input_pressed:
				_handle_paint_release()
			_update_input_state(btn)
			if btn.pressed and _is_paint_mode():
				_handle_paint_press(camera, btn.position, root)

	var paint_mode := _is_paint_mode()
	var raycast_on := _is_raycast_active()

	if not raycast_on and not paint_mode:
		_hide_ghost()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion:
		if _input_pressed:
			_input_dragging = true
		if raycast_on:
			_cast_and_update_debug(camera, event.position, root)
		if paint_mode and _input_dragging and _paint_session and _paint_session.is_painting():
			_handle_paint_drag(camera, event.position, root)
	elif event is InputEventMouseButton and raycast_on:
		_cast_and_update_debug(camera, event.position, root)

	if paint_mode and _paint_session and _paint_session.is_painting():
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func get_last_hit() -> Dictionary:
	return _last_hit


func is_input_pressed() -> bool:
	return _input_pressed


func is_input_dragging() -> bool:
	return _input_dragging


func _is_raycast_active() -> bool:
	if _dock_panel == null:
		return false
	if _dock_panel.is_ghost_enabled():
		return true
	return _dock_panel.is_modifier_held()


func _is_paint_mode() -> bool:
	return _dock_panel != null and _dock_panel.get_brush_mode() == Constants.BrushMode.PAINT


func _handle_paint_press(camera: Camera3D, screen_pos: Vector2, root: Node) -> void:
	if _paint_session == null:
		return
	var hit := Raycast.cast_for_paint(camera, screen_pos, root)
	if hit.is_empty() or not hit.has("uv"):
		_dock_panel.set_status(_paint_miss_message(camera, screen_pos, root))
		return
	var mesh := _mesh_from_hit(hit)
	if mesh == null:
		_dock_panel.set_status("Paint miss — brushable mesh could not be resolved")
		return
	_dock_panel.set_context_mesh(mesh)
	var layer := _dock_panel.get_active_stack_layer(mesh)
	if layer == null:
		_dock_panel.set_status(
			"No stack layer on %s — use Add → template layer, or double-click a shader in the catalog"
			% mesh.name
		)
		return
	_paint_last_uv = hit.uv
	_paint_session.begin_stroke(mesh)
	if hit.get("uv_planar_fallback"):
		_dock_panel.set_status("Painting with planar UV (no TEX_UV on mesh)")
	_paint_session.stamp_line(
		mesh,
		Vector2(-1.0, -1.0),
		hit.uv,
		_dock_panel.get_brush_size(),
		_dock_panel.get_brush_opacity_percent(),
		_dock_panel.get_brush_hardness_percent(),
		layer
	)
	_paint_session.sync_preview(mesh)
	_dock_panel.set_splat_preview_texture(_paint_session.preview_texture(mesh))
	_dock_panel.update_paint_target_label(layer)


func _handle_paint_drag(camera: Camera3D, screen_pos: Vector2, root: Node) -> void:
	if _paint_session == null:
		return
	var hit := Raycast.cast_for_paint(camera, screen_pos, root)
	if hit.is_empty() or not hit.has("uv"):
		return
	var mesh := _mesh_from_hit(hit)
	if mesh == null:
		return
	var layer := _dock_panel.get_active_stack_layer(mesh)
	if layer == null:
		return
	_paint_session.stamp_line(
		mesh,
		_paint_last_uv,
		hit.uv,
		_dock_panel.get_brush_size(),
		_dock_panel.get_brush_opacity_percent(),
		_dock_panel.get_brush_hardness_percent(),
		layer
	)
	_paint_last_uv = hit.uv


func _handle_paint_release() -> void:
	if _paint_session == null or not _paint_session.is_painting():
		return
	var mesh: MeshInstance3D = _paint_session.end_stroke()
	_paint_last_uv = Vector2(-1.0, -1.0)
	if mesh:
		Brushable.refresh_splat_on_mesh(mesh)
	if _dock_panel:
		_paint_session.sync_preview(mesh)
		_dock_panel.refresh_splat_preview(mesh)


func _mesh_from_hit(hit: Dictionary) -> MeshInstance3D:
	var mesh: MeshInstance3D = hit.get("mesh_instance")
	if mesh:
		return mesh
	return Raycast.mesh_for_paint(hit)


func _paint_miss_message(camera: Camera3D, screen_pos: Vector2, root: Node) -> String:
	var probe := Raycast.cast_from_camera(camera, screen_pos, root)
	if probe.is_empty():
		return "Paint miss — no brushable mesh under cursor (select mesh → Mark Brushable)"
	var mesh := Raycast.mesh_for_paint(probe)
	if mesh == null:
		return "Paint miss — hit collider is not a brushable mesh (re-mark brushable)"
	return "Paint miss — could not compute UV on %s" % mesh.name


func _on_scene_changed(_scene_root: Node) -> void:
	_attach_ghost_to_edited_scene()
	if _dock_panel:
		_dock_panel.refresh_shader_stack_ui()


func _on_selection_changed() -> void:
	if _dock_panel:
		_dock_panel.refresh_shader_stack_ui()


func _on_ghost_settings_changed() -> void:
	if _ghost == null or _dock_panel == null:
		return
	if not _dock_panel.is_ghost_enabled() or _last_hit.is_empty():
		_hide_ghost()
		return
	_ghost.update_from_hit(
		_last_hit,
		_dock_panel.get_brush_size(),
		_dock_panel.get_brush_opacity_percent(),
		_dock_panel.get_brush_hardness_percent(),
		_dock_panel.get_brush_mode()
	)


func _attach_ghost_to_edited_scene() -> void:
	if _ghost == null:
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		_hide_ghost()
		return
	if _ghost.get_parent() != root:
		if _ghost.get_parent():
			_ghost.get_parent().remove_child(_ghost)
		root.add_child(_ghost)
		_ghost.owner = null
	_hide_ghost()


func _cast_and_update_debug(camera: Camera3D, screen_pos: Vector2, root: Node) -> void:
	var hit: Dictionary = Raycast.cast_from_camera(camera, screen_pos, root)
	_last_hit = hit
	_dock_panel.update_raycast_debug(hit)
	_update_context_mesh_from_hit(hit)
	_update_ghost_from_hit(hit)


func _update_ghost_from_hit(hit: Dictionary) -> void:
	if _ghost == null or _dock_panel == null:
		return
	if not _dock_panel.is_ghost_enabled() or hit.is_empty():
		_hide_ghost()
		return
	var size: float = _dock_panel.get_brush_size()
	var opacity: float = _dock_panel.get_brush_opacity_percent()
	var hardness: float = _dock_panel.get_brush_hardness_percent()
	var mode: int = _dock_panel.get_brush_mode()
	_ghost.update_from_hit(hit, size, opacity, hardness, mode)


func _update_context_mesh_from_hit(hit: Dictionary) -> void:
	if _dock_panel == null or hit.is_empty():
		return
	var mesh := Raycast.mesh_for_paint(hit)
	if mesh:
		_dock_panel.set_context_mesh(mesh)


func _hide_ghost() -> void:
	if _ghost:
		_ghost.hide_brush()


func _update_input_state(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_input_pressed = event.pressed
	if not event.pressed:
		_input_dragging = false
