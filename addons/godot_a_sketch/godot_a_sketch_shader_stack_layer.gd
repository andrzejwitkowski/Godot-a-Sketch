@tool
extends Resource
class_name GodotASketchShaderStackLayer

enum PaintBlendMode { MIX, ADD, MULTIPLY }
enum CompositeMode { MIX, ADD, SUBTRACT, MULTIPLY }

@export var display_name: String = "Layer"
@export var layer_material: ShaderMaterial
@export var shader: Shader
@export_range(0.0, 1.0) var weight: float = 1.0
@export var paint_blend_mode: PaintBlendMode = PaintBlendMode.MIX
@export var composite_mode: CompositeMode = CompositeMode.MIX
@export var splat_map: GodotASketchSplatMap
@export var splat_map_path: String = ""
@export_range(0, 3) var mask_channel: int = 0
@export var order: int = 0


func get_shader() -> Shader:
	ensure_layer_material()
	if layer_material and layer_material.shader:
		return layer_material.shader
	return shader


func ensure_layer_material() -> ShaderMaterial:
	if layer_material == null:
		layer_material = ShaderMaterial.new()
	if layer_material.shader == null and shader != null:
		layer_material.shader = shader
	return layer_material


func assign_shader(shader_ref: Shader) -> void:
	shader = shader_ref
	ensure_layer_material().shader = shader_ref


func migrate_shader_to_material() -> void:
	if layer_material != null:
		if shader != null and layer_material.shader == null:
			layer_material.shader = shader
		return
	if shader == null:
		return
	layer_material = ShaderMaterial.new()
	layer_material.shader = shader


func migrate_legacy_fields() -> void:
	var legacy_blend = get("blend_mode")
	if legacy_blend != null:
		paint_blend_mode = int(legacy_blend) as PaintBlendMode
