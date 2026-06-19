extends RefCounted
class_name GodotASketchShaderValidator

const REQUIRED_UNIFORMS := [
	"splat_mask",
	"mask_channel",
	"layer_weight",
	"layer_albedo",
]


static func is_layer_shader(shader: Shader) -> bool:
	if shader == null:
		return false
	var names := _uniform_names(shader)
	for required in REQUIRED_UNIFORMS:
		if required not in names:
			return false
	return true


static func missing_uniforms(shader: Shader) -> PackedStringArray:
	var missing := PackedStringArray()
	if shader == null:
		return PackedStringArray(REQUIRED_UNIFORMS)
	var names := _uniform_names(shader)
	for required in REQUIRED_UNIFORMS:
		if required not in names:
			missing.append(required)
	return missing


static func _uniform_names(shader: Shader) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in shader.get_shader_uniform_list():
		if entry is Dictionary and entry.has("name"):
			names.append(String(entry["name"]))
	return names
