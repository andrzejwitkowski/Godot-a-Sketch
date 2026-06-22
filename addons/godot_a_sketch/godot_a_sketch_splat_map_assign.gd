@tool
extends RefCounted
class_name GodotASketchSplatMapAssign

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const SplatMap := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map.gd")

# ponytail: in-memory map while painting — load_map must not run every mouse move
static var _working: Dictionary = {}


static func map_path(mesh: MeshInstance3D) -> String:
	if mesh == null or not mesh.has_meta(Constants.SPLAT_MAP_META):
		return ""
	return String(mesh.get_meta(Constants.SPLAT_MAP_META))


static func load_map(mesh: MeshInstance3D) -> GodotASketchSplatMap:
	var live := working_map(mesh)
	if live:
		return live
	var path := map_path(mesh)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var map := ResourceLoader.load(path) as GodotASketchSplatMap
	if map == null or map.get_script() == null:
		return null
	map.ensure_rgba8()
	return map


static func working_map(mesh: MeshInstance3D) -> GodotASketchSplatMap:
	if mesh == null:
		return null
	return _working.get(mesh.get_instance_id())


static func begin_edit(mesh: MeshInstance3D) -> GodotASketchSplatMap:
	var map := load_map(mesh)
	if map == null:
		map = SplatMap.create_default(default_resolution())
		assign_map(mesh, map)
	map.ensure_rgba8()
	_working[mesh.get_instance_id()] = map
	return map


static func commit_edit(mesh: MeshInstance3D) -> GodotASketchSplatMap:
	var map: GodotASketchSplatMap = _working.get(mesh.get_instance_id())
	if map:
		assign_map(mesh, map)
		_working.erase(mesh.get_instance_id())
		return map
	return load_map(mesh)


static func default_resolution() -> int:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(Constants.SETTINGS_SPLAT_SIZE):
		return int(settings.get_setting(Constants.SETTINGS_SPLAT_SIZE))
	return Constants.DEFAULT_SPLAT_SIZE


static func assign_map(mesh: MeshInstance3D, map: GodotASketchSplatMap, path: String = "") -> String:
	if mesh == null or map == null:
		return "Invalid mesh or splat map"
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = map_path(mesh)
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = _default_path(mesh)
	if ResourceLoader.exists(path) and not ResourceLoader.exists(path, "GodotASketchSplatMap"):
		return "Refusing to overwrite non-splat resource at %s" % path
	var err := _ensure_parent_dir(path)
	if err != "":
		return err
	var save_err := ResourceSaver.save(map, path)
	if save_err != OK:
		return "Failed to save splat map: %s" % error_string(save_err)
	mesh.set_meta(Constants.SPLAT_MAP_META, path)
	EditorInterface.mark_scene_as_unsaved()
	return ""


static func ensure_map(mesh: MeshInstance3D) -> GodotASketchSplatMap:
	var live := working_map(mesh)
	if live:
		return live
	var map := load_map(mesh)
	if map:
		return map
	map = SplatMap.create_default(default_resolution())
	if assign_map(mesh, map) != "":
		return null
	return map


static func detach_map(mesh: MeshInstance3D, delete_file: bool = true) -> void:
	_working.erase(mesh.get_instance_id())
	if mesh == null or not mesh.has_meta(Constants.SPLAT_MAP_META):
		return
	var path := String(mesh.get_meta(Constants.SPLAT_MAP_META))
	mesh.remove_meta(Constants.SPLAT_MAP_META)
	if not delete_file or not path.begins_with(Constants.SPLAT_MAP_DEFAULT_DIR):
		return
	var abs := ProjectSettings.globalize_path(path)
	if abs.is_empty() or not FileAccess.file_exists(abs):
		return
	if DirAccess.remove_absolute(abs) != OK:
		push_warning("Godot-a-Sketch: could not delete splat map %s" % path)
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.call_deferred("scan")


static func _default_path(mesh: MeshInstance3D) -> String:
	return Constants.SPLAT_MAP_DEFAULT_DIR.path_join("%s.tres" % Constants.mesh_resource_slug(mesh))


static func _ensure_parent_dir(path: String) -> String:
	var dir_path := path.get_base_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return ""
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return "Could not create directory %s" % dir_path
	return ""
