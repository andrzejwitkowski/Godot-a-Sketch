extends RefCounted
class_name GodotASketchPaintSession

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const SplatMapAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map_assign.gd")
const SplatEngine := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_engine.gd")
const MAX_STAMPS_PER_LINE := 8

var _engines: Dictionary = {}
var _active_mesh: MeshInstance3D
var _painting := false


func begin_stroke(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	_active_mesh = mesh
	_painting = true
	var engine := _engine_for(mesh)
	var map: GodotASketchSplatMap = SplatMapAssign.begin_edit(mesh)
	if map:
		engine.ensure_open(map)
	engine.begin_paint()


func end_stroke() -> MeshInstance3D:
	if not _painting or _active_mesh == null:
		return null
	var mesh := _active_mesh
	var engine: GodotASketchSplatEngine = _engines.get(mesh.get_instance_id())
	if engine:
		engine.end_paint()
	var map: GodotASketchSplatMap = SplatMapAssign.commit_edit(mesh)
	_painting = false
	_active_mesh = null
	return mesh if map else null


func stamp_line(
	mesh: MeshInstance3D,
	from_uv: Vector2,
	to_uv: Vector2,
	brush_size: float,
	opacity_pct: float,
	hardness_pct: float,
	layer: GodotASketchShaderStackLayer
) -> void:
	if mesh == null or layer == null:
		return
	var engine: GodotASketchSplatEngine = _engine_for(mesh)
	var map: GodotASketchSplatMap = SplatMapAssign.working_map(mesh)
	if map == null:
		map = SplatMapAssign.ensure_map(mesh)
	if map == null:
		return
	engine.ensure_open(map)
	var radius := _uv_radius(brush_size, map.size.x)
	var strength := opacity_pct / 100.0
	var hardness := hardness_pct / 100.0
	var channel := clampi(layer.mask_channel, 0, 3)
	var blend := int(layer.blend_mode)
	if from_uv.x < 0.0:
		engine.stamp(to_uv, radius, strength, hardness, channel, blend)
		return
	var delta := to_uv - from_uv
	var dist := delta.length()
	if dist < 0.0001:
		engine.stamp(to_uv, radius, strength, hardness, channel, blend)
		return
	var spacing := maxf(radius * 0.25, 0.001)
	var steps := mini(maxi(1, int(ceil(dist / spacing))), MAX_STAMPS_PER_LINE)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		engine.stamp(from_uv.lerp(to_uv, t), radius, strength, hardness, channel, blend)


func preview_texture(mesh: MeshInstance3D) -> Texture2D:
	if mesh == null:
		return null
	var engine: GodotASketchSplatEngine = _engines.get(mesh.get_instance_id()) as GodotASketchSplatEngine
	if engine:
		var live := engine.get_texture()
		if live:
			return live
	var map: GodotASketchSplatMap = SplatMapAssign.load_map(mesh)
	return map.to_texture() if map else null


func is_painting() -> bool:
	return _painting


func sync_preview(mesh: MeshInstance3D) -> void:
	var engine: GodotASketchSplatEngine = _engines.get(mesh.get_instance_id()) as GodotASketchSplatEngine
	if engine:
		engine.sync_preview()


func _engine_for(mesh: MeshInstance3D) -> GodotASketchSplatEngine:
	var id := mesh.get_instance_id()
	if not _engines.has(id):
		_engines[id] = SplatEngine.new()
	return _engines[id] as GodotASketchSplatEngine


static func _uv_radius(brush_size: float, map_width: int) -> float:
	return maxf(brush_size / float(map_width), 0.008)
