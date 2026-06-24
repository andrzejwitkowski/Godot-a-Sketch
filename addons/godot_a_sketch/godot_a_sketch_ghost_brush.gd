@tool
extends Node3D

const SHADER_PATH := "res://addons/godot_a_sketch/ghost_brush.gdshader"
const SURFACE_OFFSET := 0.03

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _cached_hit: Dictionary = {}
var _camera: Camera3D
var _viewport_height: float = 720.0
var _brush_size: float = 32.0


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	_material.render_priority = 127

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = quad
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_mesh_instance)
	visible = false


func update_from_hit(
	hit: Dictionary,
	size: float,
	opacity_pct: float,
	hardness_pct: float,
	mode: int,
	camera: Camera3D = null,
	viewport_height: float = 720.0
) -> void:
	if hit.is_empty():
		hide_brush()
		return
	if camera != null:
		_camera = camera
	if viewport_height > 0.0:
		_viewport_height = viewport_height
	_brush_size = size
	_cached_hit = hit
	if not _apply_transform():
		return
	_apply_appearance(opacity_pct, hardness_pct, mode)
	visible = true
	_mesh_instance.visible = true


func hide_brush() -> void:
	_cached_hit = {}
	visible = false
	_mesh_instance.visible = false


func _apply_transform() -> bool:
	if not is_inside_tree() or _cached_hit.is_empty() or _camera == null:
		return false
	if not is_instance_valid(_camera):
		return false
	var pos: Vector3 = _cached_hit.get("position", Vector3.ZERO)
	var normal: Vector3 = _cached_hit.get("normal", Vector3.UP).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	pos += normal * SURFACE_OFFSET

	var to_cam: Vector3 = _camera.global_position - pos
	if to_cam.length_squared() < 0.0001:
		to_cam = Vector3.FORWARD
	var forward: Vector3 = to_cam.normalized()
	var up_axis := Vector3.UP
	if absf(forward.dot(up_axis)) > 0.99:
		up_axis = Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-forward, up_axis), pos)

	var dist: float = pos.distance_to(_camera.global_position)
	var half_fov: float = deg_to_rad(_camera.fov * 0.5)
	var world_diam: float = _brush_size / 10.0
	var screen_px: float = world_diam * _viewport_height / (2.0 * maxf(dist, 0.001) * tan(half_fov))
	screen_px = maxf(screen_px, 8.0)
	var world_size: float = screen_px * 2.0 * dist * tan(half_fov) / _viewport_height
	_mesh_instance.scale = Vector3(world_size, world_size, 1.0)
	return true


func _apply_appearance(opacity_pct: float, hardness_pct: float, mode: int) -> void:
	var brush_color: Color = GodotASketchConstants.COLOR_PAINT
	if mode == GodotASketchConstants.BrushMode.ERASE:
		brush_color = GodotASketchConstants.COLOR_ERASE
	_material.set_shader_parameter("brush_color", brush_color)
	_material.set_shader_parameter("opacity", opacity_pct / 100.0)
	_material.set_shader_parameter("hardness", hardness_pct / 100.0)
