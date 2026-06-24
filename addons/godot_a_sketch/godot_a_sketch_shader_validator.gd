extends RefCounted
class_name GodotASketchShaderValidator

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")

const REQUIRED_UNIFORMS := [
	"splat_mask",
	"layer_weight",
	"layer_albedo",
]

const INSTANCE_SOURCE_TOKENS := [
	"INSTANCE_CUSTOM",
	"INSTANCE_ID",
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


static func source_uses_instance_data(source: String) -> bool:
	for token in INSTANCE_SOURCE_TOKENS:
		if token in source:
			return true
	return false


static func shader_uses_instance_data(shader: Shader) -> bool:
	if shader == null:
		return false
	var path := shader.resource_path
	if path.is_empty():
		return false
	return source_uses_instance_data(GodotASketchShaderContract.read_text(path))


static func layer_mesh_compat_error(shader: Shader, target: Node3D) -> String:
	if shader == null or target == null:
		return ""
	var shader_label := shader.resource_path.get_file() if shader.resource_path else "shader"
	if target is MultiMeshInstance3D:
		if shader.resource_path == Constants.LAYER_TEMPLATE_PATH:
			return (
				"\"%s\" is for surface splat painting — add it to a ground MeshInstance3D, "
				+ "not MultiMeshInstance3D \"%s\"."
				% [shader_label, target.name]
			)
		return ""
	if target is MeshInstance3D:
		if not shader_uses_instance_data(shader):
			return ""
		return (
			"\"%s\" uses MultiMesh instance data (INSTANCE_CUSTOM). "
			+ "It cannot be stacked on surface mesh \"%s\". "
			+ "Mark the MultiMeshInstance3D brushable and add the shader there."
			% [shader_label, target.name]
		)
	return ""


static func _uniform_names(shader: Shader) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in shader.get_shader_uniform_list():
		if entry is Dictionary and entry.has("name"):
			names.append(String(entry["name"]))
	return names
