@tool
extends RefCounted
class_name GodotASketchShaderStackAssign

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const ShaderStack := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack.gd")

# ponytail: per-mesh RAM cache — upgrade path: reload_stack() after external .tres edits
static var _stack_cache: Dictionary = {}


static func stack_path(target: Node3D) -> String:
	if target == null or not target.has_meta(Constants.SHADER_STACK_META):
		return ""
	return String(target.get_meta(Constants.SHADER_STACK_META))


static func load_stack(target: Node3D) -> GodotASketchShaderStack:
	if target == null:
		return null
	var path := stack_path(target)
	if path.is_empty():
		return null
	var id := target.get_instance_id()
	var cached: Dictionary = _stack_cache.get(id, {})
	if cached.get("path", "") == path:
		var hit: GodotASketchShaderStack = cached.get("stack")
		if hit and not _is_placeholder(hit) and not hit.layers.is_empty():
			return hit
		if hit and hit.layers.is_empty():
			_stack_cache.erase(id)
	if not _resource_exists(path):
		return null
	var stack := ResourceLoader.load(path) as GodotASketchShaderStack
	if _is_placeholder(stack):
		push_warning("Godot-a-Sketch: stale stack resource at %s — will recreate" % path)
		return null
	for layer in stack.layers:
		if layer:
			layer.migrate_legacy_fields()
			layer.migrate_shader_to_material()
	_stack_cache[id] = {"path": path, "stack": stack}
	return stack


static func reload_stack(target: Node3D) -> GodotASketchShaderStack:
	invalidate_stack_cache(target)
	return load_stack(target)


static func invalidate_stack_cache(target: Node3D = null) -> void:
	if target:
		_stack_cache.erase(target.get_instance_id())
	else:
		_stack_cache.clear()


static func _is_placeholder(resource: Resource) -> bool:
	return resource == null or resource.get_script() == null


static func assign_stack(target: Node3D, stack: GodotASketchShaderStack, path: String = "") -> String:
	if target == null or stack == null:
		return "Invalid mesh or stack"
	var errors := stack.validate()
	if not errors.is_empty():
		return errors[0]
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = stack_path(target)
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = _default_path(target)
	if ResourceLoader.exists(path) and not ResourceLoader.exists(path, "GodotASketchShaderStack"):
		return "Refusing to overwrite non-stack resource at %s" % path
	var err := _ensure_parent_dir(path)
	if err != "":
		return err
	var save_err := ResourceSaver.save(stack, path)
	if save_err != OK:
		return "Failed to save stack: %s" % error_string(save_err)
	target.set_meta(Constants.SHADER_STACK_META, path)
	_stack_cache[target.get_instance_id()] = {"path": path, "stack": stack}
	EditorInterface.mark_scene_as_unsaved()
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.call_deferred("update_file", path)
	return ""


static func ensure_stack(target: Node3D) -> GodotASketchShaderStack:
	var stack := load_stack(target)
	if stack and not _is_placeholder(stack):
		return stack
	stack = ShaderStack.new()
	var err := assign_stack(target, stack)
	if err != "":
		push_warning("Godot-a-Sketch: %s" % err)
		return null
	return stack


static func ensure_stack_error(target: Node3D) -> String:
	var stack := load_stack(target)
	if stack and not _is_placeholder(stack):
		return ""
	stack = ShaderStack.new()
	return assign_stack(target, stack)


static func assign_stack_copy(target: Node3D, stack: GodotASketchShaderStack) -> String:
	return assign_stack(target, stack, _default_path(target))


static func detach_stack(target: Node3D, delete_file: bool = true) -> void:
	if target == null or not target.has_meta(Constants.SHADER_STACK_META):
		return
	var path := String(target.get_meta(Constants.SHADER_STACK_META))
	invalidate_stack_cache(target)
	target.remove_meta(Constants.SHADER_STACK_META)
	if not delete_file or not path.begins_with(Constants.SHADER_STACK_DEFAULT_DIR):
		return
	var abs := ProjectSettings.globalize_path(path)
	if abs.is_empty() or not FileAccess.file_exists(abs):
		return
	if DirAccess.remove_absolute(abs) != OK:
		push_warning("Godot-a-Sketch: could not delete stack file %s" % path)
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.call_deferred("scan")


static func _default_path(target: Node3D) -> String:
	var slug := Constants.paint_target_slug(target)
	var owned := stack_path(target)
	if not owned.is_empty() and Constants.is_usable_resource_path(owned):
		return owned
	var base := Constants.SHADER_STACK_DEFAULT_DIR.path_join("%s.tres" % slug)
	if not _resource_exists(base):
		return base
	var n := 2
	while n < 1000:
		var candidate := Constants.SHADER_STACK_DEFAULT_DIR.path_join("%s_%d.tres" % [slug, n])
		if not _resource_exists(candidate):
			return candidate
		n += 1
	return base


static func _resource_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	var abs := ProjectSettings.globalize_path(path)
	return not abs.is_empty() and FileAccess.file_exists(abs)


static func _ensure_parent_dir(path: String) -> String:
	var dir_path := path.get_base_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return ""
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return "Could not create directory %s" % dir_path
	return ""
