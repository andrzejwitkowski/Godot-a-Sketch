extends RefCounted
class_name GodotASketchPaintSession

const SplatMapAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map_assign.gd")
const MAX_STAMPS_PER_LINE := 8

var _active_mesh: MeshInstance3D
var _active_layer
var _active_layer_index := -1
var _painting := false


func begin_stroke(mesh: MeshInstance3D, layer, layer_index: int) -> void:
	if mesh == null or layer == null:
		return
	var map: GodotASketchSplatMap = SplatMapAssign.begin_edit(mesh, layer, layer_index)
	if map == null:
		return
	_active_mesh = mesh
	_active_layer = layer
	_active_layer_index = layer_index
	_painting = true


func end_stroke() -> MeshInstance3D:
	if not _painting or _active_mesh == null or _active_layer == null:
		return null
	var mesh := _active_mesh
	var layer = _active_layer
	var layer_index := _active_layer_index
	var map: GodotASketchSplatMap = SplatMapAssign.commit_edit(mesh, layer, layer_index)
	_painting = false
	_active_mesh = null
	_active_layer = null
	_active_layer_index = -1
	return mesh if map else null


func stamp_line(
	mesh: MeshInstance3D,
	from_uv: Vector2,
	to_uv: Vector2,
	brush_size: float,
	opacity_pct: float,
	hardness_pct: float,
	layer,
	layer_index: int,
	erase: bool = false
) -> void:
	if mesh == null or layer == null:
		return
	var map: GodotASketchSplatMap = SplatMapAssign.working_layer_map(mesh, layer_index)
	if map == null:
		if _painting:
			push_warning("Godot-a-Sketch: stamp without working splat map — stroke ignored")
			return
		map = SplatMapAssign.ensure_layer_map(mesh, layer, layer_index)
		if map == null:
			return
	var radius := _uv_radius(brush_size, map.size.x)
	var strength := opacity_pct / 100.0
	var hardness := hardness_pct / 100.0
	var blend := int(layer.paint_blend_mode)
	var channel := clampi(layer.mask_channel, 0, 3)
	if from_uv.x < 0.0:
		GodotASketchSplatEngine.stamp(map, to_uv, radius, strength, hardness, channel, blend, erase)
		return
	var delta := to_uv - from_uv
	var dist := delta.length()
	if dist < 0.0001:
		GodotASketchSplatEngine.stamp(map, to_uv, radius, strength, hardness, channel, blend, erase)
		return
	var spacing := maxf(radius * 0.25, 0.001)
	var steps := mini(maxi(1, int(ceil(dist / spacing))), MAX_STAMPS_PER_LINE)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		GodotASketchSplatEngine.stamp(
			map, from_uv.lerp(to_uv, t), radius, strength, hardness, channel, blend, erase
		)


func is_painting() -> bool:
	return _painting


static func _uv_radius(brush_size: float, map_width: int) -> float:
	return maxf(brush_size / float(map_width), 0.008)
