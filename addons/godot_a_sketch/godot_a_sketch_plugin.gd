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
const SplatMapAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map_assign.gd")

var _dock: EditorDock
var _dock_panel: DockPanel
var _ghost: Node3D
var _paint_session: PaintSession
var _last_hit: Dictionary = {}
var _paint_last_uv := Vector2(-1.0, -1.0)
var _input_pressed := false
var _input_dragging := false
var _uniform_refresh_pending := false
var _pending_uniform_mesh: MeshInstance3D
var _canvas_stroke_mesh: MeshInstance3D


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	var panel := preload("res://addons/godot_a_sketch/godot_a_sketch_dock.tscn").instantiate() as DockPanel
	_dock_panel = panel
	_dock = EditorDock.new()
	_dock.add_child(panel)
	_dock_panel.ghost_settings_changed.connect(_on_ghost_settings_changed)
	_dock_panel.tool_active_changed.connect(_on_tool_active_changed)
	_dock_panel.splat_stroke_begin.connect(_on_splat_canvas_stroke_begin)
	_dock_panel.splat_stroke_uv.connect(_on_splat_canvas_stroke_uv)
	_dock_panel.splat_stroke_end.connect(_on_splat_canvas_stroke_end)
	_dock.title = "Godot-a-Sketch"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	add_dock(_dock)
	set_input_event_forwarding_always_enabled()

	var template: Shader = load(Constants.LAYER_TEMPLATE_PATH) as Shader
	assert(template != null and ShaderValidator.is_layer_shader(template))
	var selection := get_editor_interface().get_selection()
	selection.selection_changed.connect(_on_selection_changed)
	var inspector := get_editor_interface().get_inspector()
	inspector.property_edited.connect(_on_inspector_property_edited)

	_ghost = GhostBrushScript.new()
	_ghost.name = Constants.GHOST_NODE_NAME
	_paint_session = PaintSession.new()
	scene_changed.connect(_on_scene_changed)
	_attach_ghost_to_edited_scene()


func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	var inspector := get_editor_interface().get_inspector()
	if inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.disconnect(_on_inspector_property_edited)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _dock_panel:
		if _dock_panel.ghost_settings_changed.is_connected(_on_ghost_settings_changed):
			_dock_panel.ghost_settings_changed.disconnect(_on_ghost_settings_changed)
		if _dock_panel.tool_active_changed.is_connected(_on_tool_active_changed):
			_dock_panel.tool_active_changed.disconnect(_on_tool_active_changed)
		if _dock_panel.splat_stroke_begin.is_connected(_on_splat_canvas_stroke_begin):
			_dock_panel.splat_stroke_begin.disconnect(_on_splat_canvas_stroke_begin)
		if _dock_panel.splat_stroke_uv.is_connected(_on_splat_canvas_stroke_uv):
			_dock_panel.splat_stroke_uv.disconnect(_on_splat_canvas_stroke_uv)
		if _dock_panel.splat_stroke_end.is_connected(_on_splat_canvas_stroke_end):
			_dock_panel.splat_stroke_end.disconnect(_on_splat_canvas_stroke_end)
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
	SplatMapAssign.clear_working()
	remove_autoload_singleton(AUTOLOAD_NAME)


func _handles(object: Object) -> bool:
	return object is Node3D


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or _dock_panel == null:
		_hide_ghost()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if not _dock_panel.is_tool_active():
		_hide_ghost()
		_reset_paint_input()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var armed := _dock_panel.is_input_armed()
	var paint_mode := _is_splat_stroke_mode()
	var show_ghost := _dock_panel.is_ghost_enabled()

	if event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		if btn.button_index == MOUSE_BUTTON_LEFT:
			if not btn.pressed and _input_pressed:
				_handle_paint_release()
				_reset_paint_input()
			elif btn.pressed and paint_mode and armed:
				_input_pressed = true
				_handle_paint_press(camera, btn.position, root)
			elif not btn.pressed:
				_reset_paint_input()

	if event is InputEventMouseMotion:
		if _input_pressed:
			_input_dragging = true
		if show_ghost:
			_cast_and_update_debug(camera, event.position, root)
		if paint_mode and _input_dragging and armed and _paint_session and _paint_session.is_painting():
			_handle_paint_drag(camera, event.position, root)
	elif event is InputEventMouseButton and show_ghost:
		var btn := event as InputEventMouseButton
		_cast_and_update_debug(camera, btn.position, root)

	if not show_ghost:
		_hide_ghost()

	if _paint_session and _paint_session.is_painting():
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _is_splat_stroke_mode() -> bool:
	if _dock_panel == null:
		return false
	var mode := _dock_panel.get_brush_mode()
	return mode == Constants.BrushMode.PAINT or mode == Constants.BrushMode.ERASE


func _is_erase_mode() -> bool:
	return _dock_panel != null and _dock_panel.get_brush_mode() == Constants.BrushMode.ERASE


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
	if not Brushable.supports_splat_paint(mesh):
		_dock_panel.set_status(
			"Splat paint needs a surface MeshInstance3D — use stack-only on MultiMeshInstance3D"
		)
		return
	var layer := _dock_panel.get_active_stack_layer(mesh)
	if layer == null:
		_dock_panel.set_status(
			"No stack layer on %s — use Add → template layer, or double-click a shader in the catalog"
			% mesh.name
		)
		return
	_paint_last_uv = hit.uv
	_paint_session.begin_stroke(mesh)
	if not _paint_session.is_painting():
		_dock_panel.set_status("Could not open splat map — check Output panel")
		return
	_dock_panel.set_context_mesh(mesh)
	if hit.get("uv_planar_fallback"):
		_dock_panel.set_status("Painting with planar UV (no TEX_UV on mesh)")
	_stamp_line(mesh, Vector2(-1.0, -1.0), hit.uv, layer)
	_dock_panel.refresh_splat_canvas(mesh)
	_dock_panel.update_paint_target_label(layer)
	Brushable.refresh_splat_uniforms_on_mesh(mesh)


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
	_stamp_line(mesh, _paint_last_uv, hit.uv, layer)
	_paint_last_uv = hit.uv
	_request_splat_uniform_refresh(mesh)
	_dock_panel.refresh_splat_canvas(mesh)


func _request_splat_uniform_refresh(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	_pending_uniform_mesh = mesh
	if _uniform_refresh_pending:
		return
	_uniform_refresh_pending = true
	call_deferred("_flush_splat_uniform_refresh")


func _flush_splat_uniform_refresh() -> void:
	_uniform_refresh_pending = false
	var mesh := _pending_uniform_mesh
	_pending_uniform_mesh = null
	if mesh:
		Brushable.refresh_splat_uniforms_on_mesh(mesh)


func _finish_splat_stroke() -> void:
	if _paint_session == null or not _paint_session.is_painting():
		_canvas_stroke_mesh = null
		return
	var mesh: MeshInstance3D = _paint_session.end_stroke()
	_canvas_stroke_mesh = null
	_paint_last_uv = Vector2(-1.0, -1.0)
	if mesh:
		_flush_splat_uniform_refresh()
		Brushable.refresh_splat_uniforms_on_mesh(mesh)
		Brushable.rebuild_grass_fields_for_surface(mesh)
	if _dock_panel:
		_dock_panel.flush_splat_canvas(mesh)


func _on_splat_canvas_stroke_begin() -> void:
	if _dock_panel == null or _paint_session == null:
		return
	var mesh := _dock_panel.get_target_mesh()
	if mesh == null or not mesh is MeshInstance3D:
		return
	if not Brushable.supports_splat_paint(mesh):
		return
	var layer := _dock_panel.get_active_stack_layer(mesh)
	if layer == null:
		_dock_panel.set_status("Select a stack layer to edit the splat mask")
		return
	_paint_session.begin_stroke(mesh as MeshInstance3D)
	if not _paint_session.is_painting():
		_dock_panel.set_status("Could not open splat map — check Output panel")
		return
	_canvas_stroke_mesh = mesh as MeshInstance3D
	_paint_last_uv = Vector2(-1.0, -1.0)


func _on_splat_canvas_stroke_uv(from_uv: Vector2, to_uv: Vector2) -> void:
	if _dock_panel == null or _paint_session == null or not _paint_session.is_painting():
		return
	var mesh := _canvas_stroke_mesh
	if mesh == null:
		return
	var layer := _dock_panel.get_active_stack_layer(mesh)
	if layer == null:
		return
	_stamp_line(mesh, from_uv, to_uv, layer)
	_paint_last_uv = to_uv
	_request_splat_uniform_refresh(mesh)
	_dock_panel.refresh_splat_canvas(mesh)


func _handle_paint_release() -> void:
	_finish_splat_stroke()


func _on_splat_canvas_stroke_end() -> void:
	_finish_splat_stroke()


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
	_rebuild_grass_fields_in_scene()


func _rebuild_grass_fields_in_scene() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	for node in root.get_tree().get_nodes_in_group(&"grass_field"):
		if node.has_method("_request_rebuild"):
			node._request_rebuild()


func _on_selection_changed() -> void:
	if _dock_panel:
		_dock_panel.refresh_shader_stack_ui()


func _on_inspector_property_edited(_property: StringName) -> void:
	if _dock_panel == null:
		return
	var edited := get_editor_interface().get_inspector().get_edited_object()
	if edited is ShaderMaterial:
		_dock_panel.on_layer_material_edited(edited as ShaderMaterial)


func _on_tool_active_changed(active: bool) -> void:
	if not active:
		_hide_ghost()
		_cancel_active_stroke()


func _on_ghost_settings_changed() -> void:
	if _dock_panel == null or not _dock_panel.is_tool_active() or not _dock_panel.is_ghost_enabled():
		_hide_ghost()
		return
	_update_ghost_from_hit(_last_hit)


func _stamp_line(
	mesh: MeshInstance3D,
	from_uv: Vector2,
	to_uv: Vector2,
	layer: GodotASketchShaderStackLayer
) -> void:
	_paint_session.stamp_line(
		mesh,
		from_uv,
		to_uv,
		_dock_panel.get_brush_size(),
		_dock_panel.get_brush_opacity_percent(),
		_dock_panel.get_brush_hardness_percent(),
		layer,
		_is_erase_mode()
	)


func _cancel_active_stroke() -> void:
	if _paint_session and _paint_session.is_painting():
		var mesh := _paint_session.end_stroke()
		if mesh:
			Brushable.refresh_splat_uniforms_on_mesh(mesh)
			if _dock_panel:
				_dock_panel.refresh_splat_canvas(mesh)
	_reset_paint_input()
	_canvas_stroke_mesh = null


func _reset_paint_input() -> void:
	_input_pressed = false
	_input_dragging = false


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
