@tool
extends Node3D

const SHADER_PATH := "res://addons/godot_a_sketch/ghost_brush.gdshader"
const SURFACE_OFFSET := 0.01

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _cached_hit: Dictionary = {}


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
	add_child(_mesh_instance)
	visible = false


func update_from_hit(
	hit: Dictionary,
	size: float,
	opacity_pct: float,
	hardness_pct: float,
	mode: int
) -> void:
	if hit.is_empty():
		hide_brush()
		return

	_cached_hit = hit
	_apply_transform(hit)
	_apply_appearance(size, opacity_pct, hardness_pct, mode)
	visible = true


func update_appearance(
	size: float,
	opacity_pct: float,
	hardness_pct: float,
	mode: int
) -> void:
	if _cached_hit.is_empty():
		return
	_apply_transform(_cached_hit)
	_apply_appearance(size, opacity_pct, hardness_pct, mode)
	visible = true


func hide_brush() -> void:
	_cached_hit = {}
	visible = false


func _apply_transform(hit: Dictionary) -> void:
	var pos: Vector3 = hit.get("position", Vector3.ZERO)
	var normal: Vector3 = hit.get("normal", Vector3.UP).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	global_transform = _surface_transform(pos, normal)


func _apply_appearance(
	size: float,
	opacity_pct: float,
	hardness_pct: float,
	mode: int
) -> void:
	# ponytail: dock size is in arbitrary units; /10 keeps
	# default 32 → ~3.2 world units on the quad mesh.
	var diameter: float = size / 10.0
	_mesh_instance.scale = Vector3(diameter, diameter, 1.0)

	var brush_color: Color = GodotASketchConstants.COLOR_PAINT
	if mode == GodotASketchConstants.BrushMode.ERASE:
		brush_color = GodotASketchConstants.COLOR_ERASE

	_material.set_shader_parameter("brush_color", brush_color)
	_material.set_shader_parameter("opacity", opacity_pct / 100.0)
	_material.set_shader_parameter("hardness", hardness_pct / 100.0)


func _surface_transform(pos: Vector3, normal: Vector3) -> Transform3D:
	var up_axis := Vector3.UP
	if absf(normal.dot(up_axis)) > 0.99:
		up_axis = Vector3.RIGHT
	var basis := Basis.looking_at(-normal, up_axis)
	return Transform3D(basis, pos + normal * SURFACE_OFFSET)
