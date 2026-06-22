@tool
extends Resource
class_name GodotASketchShaderStack

const ShaderStackLayer := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack_layer.gd")
const ShaderValidator := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_validator.gd")

@export var layers: Array[ShaderStackLayer] = []


func add_layer(layer) -> void:
	if layer == null:
		return
	layer.order = layers.size()
	layers.append(layer)
	_sync_order()


func remove_layer(idx: int) -> void:
	if idx < 0 or idx >= layers.size():
		return
	layers.remove_at(idx)
	_sync_order()


func move_layer(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= layers.size():
		return
	if to_idx < 0 or to_idx >= layers.size():
		return
	if from_idx == to_idx:
		return
	var layer = layers[from_idx]
	layers.remove_at(from_idx)
	layers.insert(to_idx, layer)
	_sync_order()


func duplicate_stack() -> GodotASketchShaderStack:
	return duplicate(true) as GodotASketchShaderStack


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for i in layers.size():
		var layer = layers[i]
		if layer == null:
			errors.append("Layer %d: layer resource is null" % i)
			continue
		if layer.shader == null:
			continue
		if not ShaderValidator.is_layer_shader(layer.shader):
			var missing := ShaderValidator.missing_uniforms(layer.shader)
			errors.append(
				'Layer %d (%s): missing uniforms: %s' % [i, layer.display_name, ", ".join(missing)]
			)
	return errors


func _sync_order() -> void:
	for i in layers.size():
		if layers[i] != null:
			layers[i].order = i
