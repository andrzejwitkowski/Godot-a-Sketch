@tool
extends RefCounted
class_name GodotASketchSplatMapAssign

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const SplatMap := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map.gd")

static var _working: Dictionary = {}
static var _by_path: Dictionary = {}


static func map_path(target: Node3D) -> String:
	if target == null or not target.has_meta(Constants.SPLAT_MAP_META):
		return ""
	return String(target.get_meta(Constants.SPLAT_MAP_META))


static func load_map(target: Node3D) -> GodotASketchSplatMap:
	var live := working_map(target)
	if live:
		return live
	var path := map_path(target)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if _by_path.has(path):
		return _by_path[path]
	var map := ResourceLoader.load(path) as GodotASketchSplatMap
	if map == null or map.get_script() == null:
		return null
	map.ensure_rgba8()
	_by_path[path] = map
	return map


static func reload_map(target: Node3D) -> GodotASketchSplatMap:
	if target == null:
		return null
	var path := map_path(target)
	if not path.is_empty():
		_by_path.erase(path)
	_working.erase(target.get_instance_id())
	return load_map(target)


static func working_map(target: Node3D) -> GodotASketchSplatMap:
	if target == null:
		return null
	return _working.get(target.get_instance_id())


static func clear_working() -> void:
	_working.clear()


static func begin_edit(target: Node3D) -> GodotASketchSplatMap:
	if target == null:
		return null
	var map := load_map(target)
	if map == null:
		map = SplatMap.create_default(default_resolution())
		if assign_map(target, map) != "":
			return null
	map.ensure_rgba8()
	_working[target.get_instance_id()] = map
	return map


static func commit_edit(target: Node3D) -> GodotASketchSplatMap:
	if target == null:
		return null
	var id := target.get_instance_id()
	var map: GodotASketchSplatMap = _working.get(id)
	if map == null:
		return load_map(target)
	var path := map_path(target)
	if assign_map(target, map) != "":
		push_warning("Godot-a-Sketch: splat map save failed — stroke kept in memory")
		return map
	_working.erase(id)
	if not path.is_empty():
		_by_path[path] = map
	return map


static func default_resolution() -> int:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(Constants.SETTINGS_SPLAT_SIZE):
		return int(settings.get_setting(Constants.SETTINGS_SPLAT_SIZE))
	return Constants.DEFAULT_SPLAT_SIZE


static func assign_map(target: Node3D, map: GodotASketchSplatMap, path: String = "") -> String:
	if target == null or map == null:
		return "Invalid mesh or splat map"
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = map_path(target)
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = _default_path(target)
	if ResourceLoader.exists(path) and not ResourceLoader.exists(path, "GodotASketchSplatMap"):
		return "Refusing to overwrite non-splat resource at %s" % path
	var err := _ensure_parent_dir(path)
	if err != "":
		return err
	var save_err := ResourceSaver.save(map, path)
	if save_err != OK:
		return "Failed to save splat map: %s" % error_string(save_err)
	target.set_meta(Constants.SPLAT_MAP_META, path)
	_by_path[path] = map
	EditorInterface.mark_scene_as_unsaved()
	_notify_filesystem(path)
	return ""


static func ensure_map(target: Node3D) -> GodotASketchSplatMap:
	var live := working_map(target)
	if live:
		return live
	var map := load_map(target)
	if map:
		return map
	map = SplatMap.create_default(default_resolution())
	if assign_map(target, map) != "":
		return null
	return map


static func detach_map(target: Node3D, delete_file: bool = true) -> void:
	if target == null:
		return
	var path := map_path(target)
	_working.erase(target.get_instance_id())
	if not path.is_empty():
		_by_path.erase(path)
	if not target.has_meta(Constants.SPLAT_MAP_META):
		return
	target.remove_meta(Constants.SPLAT_MAP_META)
	if not delete_file or not path.begins_with(Constants.SPLAT_MAP_DEFAULT_DIR):
		return
	var abs := ProjectSettings.globalize_path(path)
	if abs.is_empty() or not FileAccess.file_exists(abs):
		return
	if DirAccess.remove_absolute(abs) != OK:
		push_warning("Godot-a-Sketch: could not delete splat map %s" % path)
		return
	_notify_filesystem(path)


static func _default_path(target: Node3D) -> String:
	return Constants.SPLAT_MAP_DEFAULT_DIR.path_join("%s.tres" % Constants.paint_target_slug(target))


static func _ensure_parent_dir(path: String) -> String:
	var dir_path := path.get_base_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return ""
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return "Could not create directory %s" % dir_path
	return ""


static func _notify_filesystem(path: String) -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs == null:
		return
	fs.call_deferred("update_file", path)
