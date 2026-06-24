@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GodotASketch"
const AUTOLOAD_PATH := "res://addons/godot_a_sketch/godot_a_sketch_autoload.gd"

const ViewportGhostOverlay := preload("res://addons/godot_a_sketch/godot_a_sketch_viewport_ghost_overlay.gd")
const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const ShaderValidator := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_validator.gd")
const Raycast := preload("res://addons/godot_a_sketch/godot_a_sketch_raycast.gd")
const DockPanel := preload("res://addons/godot_a_sketch/godot_a_sketch_dock.gd")
const Brushable := preload("res://addons/godot_a_sketch/godot_a_sketch_brushable.gd")
const ShaderStackAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack_assign.gd")
const SplatMapAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map_assign.gd")
const SplatMap := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map.gd")

var _dock: EditorDock
var _dock_panel: DockPanel
var _viewport_overlay: Control
var _viewport_overlay_parent: SubViewportContainer
var _last_hit: Dictionary = {}
var _paint_last_uv := Vector2(-1.0, -1.0)
var _viewport_paint_pressed := false
var _uniform_refresh_pending := false
var _pending_uniform_mesh: MeshInstance3D
var _canvas_stroke_mesh: MeshInstance3D
var _grass_rebuild_pending := false
var _preview_refresh_at := 0
var _stroke_grass_mesh: MeshInstance3D
var _stroke_viewport_mesh: MeshInstance3D
var _stroke_grass_timer: Timer
var _stroke_viewport_timer: Timer
const PREVIEW_REFRESH_MS := 80
const STROKE_GRASS_REBUILD_SEC := 0.45
const STROKE_VIEWPORT_REFRESH_SEC := 0.12


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

	var template: Shader = load(Constants.LAYER_TEMPLATE_PATH) as Shader
	assert(template != null and ShaderValidator.is_layer_shader(template))
	assert(SplatMap.self_check_from_channel())
	assert(SplatMap.self_check_resize())
	var settings := get_editor_interface().get_editor_settings()
	if not settings.has_setting(Constants.SETTINGS_SPLAT_SIZE):
		settings.set_setting(Constants.SETTINGS_SPLAT_SIZE, Constants.DEFAULT_SPLAT_SIZE)
	var inspector := get_editor_interface().get_inspector()
	inspector.property_edited.connect(_on_inspector_property_edited)

	_stroke_grass_timer = Timer.new()
	_stroke_grass_timer.one_shot = true
	_stroke_grass_timer.wait_time = STROKE_GRASS_REBUILD_SEC
	_stroke_grass_timer.timeout.connect(_flush_stroke_grass_rebuild)
	add_child(_stroke_grass_timer)
	_stroke_viewport_timer = Timer.new()
	_stroke_viewport_timer.one_shot = true
	_stroke_viewport_timer.wait_time = STROKE_VIEWPORT_REFRESH_SEC
	_stroke_viewport_timer.timeout.connect(_flush_stroke_viewport_refresh)
	add_child(_stroke_viewport_timer)
	scene_changed.connect(_on_scene_changed)
	call_deferred("_attach_viewport_overlay")


func _exit_tree() -> void:
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
	_detach_viewport_overlay()
	if _stroke_viewport_timer:
		_stroke_viewport_timer.queue_free()
		_stroke_viewport_timer = null
	if _stroke_grass_timer:
		_stroke_grass_timer.queue_free()
		_stroke_grass_timer = null
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null
	_dock_panel = null
	SplatMapAssign.flush_disk_persists()
	SplatMapAssign.clear_working()
	remove_autoload_singleton(AUTOLOAD_NAME)


func _handles(_object: Object) -> bool:
	return false


func _forward_3d_gui_input(_camera: Camera3D, _event: InputEvent) -> int:
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _is_splat_stroke_mode() -> bool:
	if _dock_panel == null:
		return false
	var mode := _dock_panel.get_brush_mode()
	return mode == Constants.BrushMode.PAINT or mode == Constants.BrushMode.ERASE


func _handle_paint_press(camera: Camera3D, screen_pos: Vector2, root: Node) -> void:
	if _dock_panel == null:
		return
	var hit := _raycast_paint_hit(camera, screen_pos, root)
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
	var layer_info := _dock_panel.resolve_paint_layer(mesh)
	var layer: GodotASketchShaderStackLayer = layer_info[0]
	var layer_index: int = layer_info[1]
	if layer == null:
		_dock_panel.set_status(
			"No stack layer on %s — use Add → template layer, or double-click a shader in the catalog"
			% mesh.name
		)
		return
	_paint_last_uv = hit.uv
	if not _dock_panel.begin_splat_stroke(mesh, "Painting splat mask (3D view)"):
		return
	_dock_panel.stamp_splat_uv(Vector2(-1.0, -1.0), hit.uv)
	_dock_panel.flush_splat_canvas(mesh, false, false)
	_throttled_3d_viewport_feedback(mesh)
	if hit.get("uv_planar_fallback"):
		_dock_panel.set_status("Painting with planar UV (no TEX_UV on mesh)")
	_dock_panel.update_paint_target_label(layer)


func _handle_paint_drag(camera: Camera3D, screen_pos: Vector2, root: Node) -> void:
	if _dock_panel == null or not _dock_panel.is_splat_stroking():
		return
	var hit := _raycast_paint_hit(camera, screen_pos, root)
	if hit.is_empty() or not hit.has("uv"):
		return
	var mesh := _mesh_from_hit(hit)
	if mesh == null:
		return
	_dock_panel.stamp_splat_uv(_paint_last_uv, hit.uv)
	_paint_last_uv = hit.uv
	_dock_panel.flush_splat_canvas(mesh, false, false)
	_throttled_3d_viewport_feedback(mesh)


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
	var mesh: MeshInstance3D = null
	if _dock_panel and _dock_panel.is_splat_stroking():
		mesh = _dock_panel.end_splat_stroke(true)
	_canvas_stroke_mesh = null
	_paint_last_uv = Vector2(-1.0, -1.0)


func _on_splat_canvas_stroke_begin() -> void:
	pass


func _on_splat_canvas_stroke_uv(_from_uv: Vector2, _to_uv: Vector2) -> void:
	pass


func _on_splat_canvas_stroke_end() -> void:
	pass


func _handle_paint_release() -> void:
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
	call_deferred("_deferred_scene_changed")


func _deferred_scene_changed() -> void:
	if _stroke_grass_timer:
		_stroke_grass_timer.stop()
	if _stroke_viewport_timer:
		_stroke_viewport_timer.stop()
	_stroke_grass_mesh = null
	_stroke_viewport_mesh = null
	ShaderStackAssign.invalidate_stack_cache()
	call_deferred("_attach_viewport_overlay")
	if _dock_panel:
		_dock_panel.on_editor_selection_changed()


func _throttled_splat_preview(mesh: MeshInstance3D) -> void:
	if _dock_panel == null or mesh == null:
		return
	var now := Time.get_ticks_msec()
	if now - _preview_refresh_at < PREVIEW_REFRESH_MS:
		return
	_preview_refresh_at = now
	_dock_panel.flush_splat_canvas(mesh, false, false)


func _apply_viewport_paint_feedback(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	Brushable.apply_paint_feedback(mesh, true)
	var layer_index := _dock_panel.get_active_stack_layer_index(mesh) if _dock_panel else 0
	var map = SplatMapAssign.latest_map(mesh, layer_index)
	if map:
		map.runtime_texture()


func _ensure_stroke_timers() -> void:
	if _stroke_viewport_timer == null or not is_instance_valid(_stroke_viewport_timer):
		_stroke_viewport_timer = Timer.new()
		_stroke_viewport_timer.one_shot = true
		_stroke_viewport_timer.wait_time = STROKE_VIEWPORT_REFRESH_SEC
		_stroke_viewport_timer.timeout.connect(_flush_stroke_viewport_refresh)
		add_child(_stroke_viewport_timer)
	if _stroke_grass_timer == null or not is_instance_valid(_stroke_grass_timer):
		_stroke_grass_timer = Timer.new()
		_stroke_grass_timer.one_shot = true
		_stroke_grass_timer.wait_time = STROKE_GRASS_REBUILD_SEC
		_stroke_grass_timer.timeout.connect(_flush_stroke_grass_rebuild)
		add_child(_stroke_grass_timer)


func _apply_viewport_splat_refresh(mesh: MeshInstance3D) -> void:
	_apply_viewport_paint_feedback(mesh)


func _queue_stroke_viewport_refresh(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	_ensure_stroke_timers()
	_stroke_viewport_mesh = mesh
	if _stroke_viewport_timer:
		_stroke_viewport_timer.start()
	else:
		_apply_viewport_paint_feedback(mesh)


func _flush_stroke_viewport_refresh() -> void:
	var mesh := _stroke_viewport_mesh
	_stroke_viewport_mesh = null
	if mesh:
		_apply_viewport_paint_feedback(mesh)


func _queue_stroke_grass_rebuild(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	_ensure_stroke_timers()
	_stroke_grass_mesh = mesh
	if _stroke_grass_timer:
		_stroke_grass_timer.start()
	else:
		Brushable.rebuild_grass_fields_for_surface(mesh)


func _flush_stroke_grass_rebuild() -> void:
	var mesh := _stroke_grass_mesh
	_stroke_grass_mesh = null
	if mesh:
		_rebuild_grass_for_surface(mesh)


func _rebuild_grass_for_surface(mesh: MeshInstance3D) -> void:
	if mesh:
		Brushable.rebuild_grass_fields_for_surface(mesh)


func _queue_grass_fields_rebuild() -> void:
	if _grass_rebuild_pending:
		return
	_grass_rebuild_pending = true
	call_deferred("_flush_grass_fields_rebuild")


func _flush_grass_fields_rebuild() -> void:
	_grass_rebuild_pending = false
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	# ponytail: scene switch only rebuilds editor-preview fields; others use _ready or splat paint
	for node in root.get_tree().get_nodes_in_group(&"grass_field"):
		if not node.has_method("_request_rebuild"):
			continue
		if Engine.is_editor_hint() and node.get("editor_preview_enabled") == false:
			continue
		node._request_rebuild()


func _on_inspector_property_edited(_property: StringName) -> void:
	if _dock_panel == null:
		return
	var edited := get_editor_interface().get_inspector().get_edited_object()
	if edited is Shader:
		return
	if edited is ShaderMaterial:
		var mat := edited as ShaderMaterial
		if mat.shader and mat.shader.resource_path.contains("grass_blade"):
			return
		_dock_panel.on_layer_material_edited(mat)


func _on_tool_active_changed(active: bool) -> void:
	_sync_plugin_process()
	if not active:
		_hide_ghost()
		_cancel_active_stroke()
		_reset_paint_input()
	_last_hit = {}


func _on_ghost_settings_changed() -> void:
	_sync_plugin_process()
	if _dock_panel == null or not _dock_panel.is_tool_active() or not _dock_panel.is_ghost_enabled():
		_hide_ghost()
		_last_hit = {}
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	var viewport := get_editor_interface().get_editor_viewport_3d(0)
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null or not is_instance_valid(camera):
		return
	var mouse := _editor_viewport_mouse(viewport)
	if mouse.x < 0.0:
		return
	_cast_and_update_debug(camera, mouse, root, float(viewport.size.y))


func _attach_viewport_overlay() -> void:
	_detach_viewport_overlay()
	var viewport := get_editor_interface().get_editor_viewport_3d(0)
	if viewport == null:
		return
	var parent := viewport.get_parent()
	if parent == null or not parent is SubViewportContainer:
		return
	_viewport_overlay_parent = parent as SubViewportContainer
	_viewport_overlay = ViewportGhostOverlay.new()
	_viewport_overlay.name = "_GodotASketchViewportGhost"
	_viewport_overlay_parent.add_child(_viewport_overlay)
	_viewport_overlay_parent.move_child(_viewport_overlay, -1)


func _detach_viewport_overlay() -> void:
	if _viewport_overlay and is_instance_valid(_viewport_overlay):
		_viewport_overlay.queue_free()
	_viewport_overlay = null
	_viewport_overlay_parent = null


func _cancel_active_stroke() -> void:
	if _dock_panel and _dock_panel.is_splat_stroking():
		_dock_panel.end_splat_stroke(true)
	_reset_paint_input()
	_canvas_stroke_mesh = null


func _reset_paint_input() -> void:
	_viewport_paint_pressed = false


func _raycast_paint_hit(camera: Camera3D, screen_pos: Vector2, root: Node) -> Dictionary:
	var hit := Raycast.cast_for_paint(camera, screen_pos, root)
	if not hit.is_empty():
		return hit
	if _dock_panel == null:
		return {}
	var target := _dock_panel.get_target_mesh() as MeshInstance3D
	if target and Brushable.is_paint_surface(target):
		hit = Raycast.cast_on_mesh(camera, screen_pos, target)
		if not hit.is_empty():
			return hit
		# ponytail: last resort — any paint surface under cursor (mesh cast)
		return Raycast.enrich_paint_hit(
			Raycast.cast_from_camera(camera, screen_pos, root), camera, screen_pos
		)
	return {}


func _editor_viewport_mouse(viewport: SubViewport) -> Vector2:
	if viewport == null:
		return Vector2(-1.0, -1.0)
	var mouse := viewport.get_mouse_position()
	var rect := Rect2(Vector2.ZERO, viewport.size)
	if not rect.has_point(mouse):
		return Vector2(-1.0, -1.0)
	return mouse


func _poll_3d_viewport() -> void:
	if _dock_panel == null or not _dock_panel.is_tool_active():
		if _viewport_paint_pressed:
			_cancel_viewport_paint()
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	var viewport := get_editor_interface().get_editor_viewport_3d(0)
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null or not is_instance_valid(camera):
		return
	var mouse := _editor_viewport_mouse(viewport)
	var in_viewport := mouse.x >= 0.0

	if in_viewport and _dock_panel.is_ghost_enabled():
		_cast_and_update_debug(camera, mouse, root, float(viewport.size.y))
	elif not _dock_panel.is_ghost_enabled():
		_hide_ghost()

	if not in_viewport:
		if _viewport_paint_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_cancel_viewport_paint()
		return

	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var armed := _dock_panel.is_input_armed() and _is_splat_stroke_mode()

	if armed and lmb and not _viewport_paint_pressed:
		_viewport_paint_pressed = true
		_handle_paint_press(camera, mouse, root)
		if not _dock_panel.is_splat_stroking():
			_viewport_paint_pressed = false
	elif armed and lmb and _viewport_paint_pressed and _dock_panel.is_splat_stroking():
		_handle_paint_drag(camera, mouse, root)
	elif _viewport_paint_pressed and not lmb:
		_cancel_viewport_paint()
	_sync_plugin_process()


func _sync_plugin_process() -> void:
	if _dock_panel == null or not _dock_panel.is_tool_active():
		set_process(false)
		return
	var run := (
		_dock_panel.is_ghost_enabled()
		or _dock_panel.is_modifier_held()
		or _dock_panel.is_splat_stroking()
		or _viewport_paint_pressed
	)
	set_process(run)


func _cancel_viewport_paint() -> void:
	_handle_paint_release()
	_reset_paint_input()


func _process(_delta: float) -> void:
	_poll_3d_viewport()


func _throttled_3d_viewport_feedback(mesh: MeshInstance3D) -> void:
	if _dock_panel:
		_dock_panel.throttled_viewport_feedback(mesh, false)
	_throttled_splat_preview(mesh)


func _cast_and_update_debug(
	camera: Camera3D, screen_pos: Vector2, root: Node, viewport_height: float = 720.0
) -> void:
	var hit: Dictionary = _raycast_paint_hit(camera, screen_pos, root)
	_dock_panel.update_raycast_debug(hit)
	_update_context_mesh_from_hit(hit)
	_last_hit = hit
	_update_viewport_ghost_overlay(hit, camera, viewport_height)


func _viewport_overlay_point(viewport: SubViewport, screen: Vector2) -> Vector2:
	if _viewport_overlay_parent == null or viewport == null:
		return screen
	var vp_size := viewport.size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return screen
	var scale: Vector2 = _viewport_overlay_parent.size / Vector2(vp_size)
	return Vector2(screen.x * scale.x, screen.y * scale.y)


func _update_viewport_ghost_overlay(
	hit: Dictionary, camera: Camera3D, viewport_height: float
) -> void:
	if _dock_panel == null:
		return
	if _viewport_overlay == null or not is_instance_valid(_viewport_overlay):
		_attach_viewport_overlay()
	if _viewport_overlay == null:
		return
	if not _dock_panel.is_tool_active() or not _dock_panel.is_ghost_enabled() or hit.is_empty():
		_hide_ghost()
		return
	if camera == null or not is_instance_valid(camera):
		_hide_ghost()
		return
	var pos: Vector3 = hit.get("position", Vector3.ZERO)
	if camera.is_position_behind(pos):
		_hide_ghost()
		return
	var viewport := get_editor_interface().get_editor_viewport_3d(0)
	if viewport == null:
		return
	var screen: Vector2 = camera.unproject_position(pos)
	screen = _viewport_overlay_point(viewport, screen)
	var size: float = _dock_panel.get_brush_size()
	var mode: int = _dock_panel.get_brush_mode()
	var color: Color = Constants.COLOR_PAINT
	if mode == Constants.BrushMode.ERASE:
		color = Constants.COLOR_ERASE
	color.a *= _dock_panel.get_brush_opacity_percent() / 100.0
	var dist: float = camera.global_position.distance_to(pos)
	var world_diam: float = size / 10.0
	var half_fov: float = deg_to_rad(camera.fov * 0.5)
	var vp_h := maxf(viewport_height, 1.0)
	var px: float = world_diam * vp_h / (2.0 * maxf(dist, 0.001) * tan(half_fov))
	if _viewport_overlay_parent and viewport.size.y > 0.0:
		px *= _viewport_overlay_parent.size.y / float(viewport.size.y)
	_viewport_overlay.set_ring(screen, maxf(px, 4.0), color)


func _update_context_mesh_from_hit(hit: Dictionary) -> void:
	if _dock_panel == null or hit.is_empty():
		return
	var mesh := Raycast.mesh_for_paint(hit)
	if mesh:
		_dock_panel.set_context_mesh(mesh)


func _hide_ghost() -> void:
	if _viewport_overlay and is_instance_valid(_viewport_overlay):
		_viewport_overlay.clear_ring()
