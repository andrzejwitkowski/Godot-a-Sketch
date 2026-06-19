extends RefCounted
class_name GodotASketchShaderContract

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")

const INC_INCLUDE := '#include "res://addons/godot_a_sketch/shaders/layer_common.gdshaderinc"'
const MARKER := "// Godot-a-Sketch: paint layer contract"


static func source_has_contract(shader_path: String) -> bool:
	var source := read_text(shader_path)
	if source.is_empty():
		return false
	return MARKER in source or "layer_common.gdshaderinc" in source


static func build_patched_source(source: String) -> String:
	if MARKER in source or "layer_common.gdshaderinc" in source:
		return ""
	if not _is_spatial_shader(source):
		return ""
	if _declares_any_required_uniform(source):
		return ""
	var lines := source.split("\n")
	var insert_at := -1
	for i in lines.size():
		if lines[i].strip_edges().begins_with("shader_type"):
			insert_at = i + 1
			break
	if insert_at < 0:
		return ""
	lines.insert(insert_at, "")
	lines.insert(insert_at + 1, MARKER)
	lines.insert(insert_at + 2, INC_INCLUDE)
	return "\n".join(lines)


static func patch_error(source: String) -> String:
	if source.is_empty():
		return "Empty shader source"
	if MARKER in source or "layer_common.gdshaderinc" in source:
		return "Shader already includes the layer contract"
	if not _is_spatial_shader(source):
		return "Only shader_type spatial supports the paint layer contract"
	if _declares_any_required_uniform(source):
		return "Shader already declares splat uniforms — remove duplicates first"
	if build_patched_source(source).is_empty():
		return "Could not find shader_type line"
	return ""


static func read_text(shader_path: String) -> String:
	var abs := ProjectSettings.globalize_path(shader_path)
	var file := FileAccess.open(abs, FileAccess.READ)
	if file == null:
		file = FileAccess.open(shader_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func write_text(shader_path: String, text: String) -> bool:
	var abs := ProjectSettings.globalize_path(shader_path)
	var file := FileAccess.open(abs, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(shader_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.update_file(shader_path)
	return true


static func after_patch(shader_path: String) -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()
	var shader: Shader = ResourceLoader.load(shader_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Shader
	if shader:
		EditorInterface.edit_resource(shader)


static func _is_spatial_shader(source: String) -> bool:
	for line in source.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("shader_type"):
			return stripped.contains("spatial")
	return false


static func _declares_any_required_uniform(source: String) -> bool:
	for line in source.split("\n"):
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("//"):
			continue
		if not stripped.begins_with("uniform"):
			continue
		for name in GodotASketchShaderValidator.REQUIRED_UNIFORMS:
			if _line_declares_name(stripped, name):
				return true
	return false


static func _line_declares_name(line: String, uniform_name: String) -> bool:
	for token in line.split(" ", false):
		if token.strip_edges().trim_suffix(";") == uniform_name:
			return true
	return false
