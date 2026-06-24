@tool
extends RefCounted
class_name GodotASketchSplatMapAssign

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const SplatMap := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map.gd")
const ShaderStackAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack_assign.gd")

static var _working: Dictionary = {}
static var _by_path: Dictionary = {}
# ponytail: debounced disk flush — paint stays in RAM until flush_disk_persists()
static var _disk_persist_pending: Dictionary = {}


static func _layer_key(target: Node3D, layer_index: int) -> String:
	return "%d:%d" % [target.get_instance_id(), layer_index]


## Legacy mesh-level API — prefer load_layer_map for per-layer stacks.
static func map_path(target: Node3D) -> String:
	if target == null or not target.has_meta(Constants.SPLAT_MAP_META):
		return ""
	return String(target.get_meta(Constants.SPLAT_MAP_META))


static func load_map(target: Node3D) -> GodotASketchSplatMap:
	return latest_map(target)


## Painted splat still in RAM (working buffer or debounced disk queue) wins over disk.
static func latest_map(target: Node3D, layer_index: int = 0) -> GodotASketchSplatMap:
	if target == null:
		return null
	var layer_key := _layer_key(target, layer_index)
	var live: GodotASketchSplatMap = _working.get(layer_key)
	if live:
		return live
	for path in _disk_persist_pending.keys():
		var item: Dictionary = _disk_persist_pending[path]
		if int(item.get("target_id", -1)) == target.get_instance_id() and int(item.get("layer_index", 0)) == layer_index:
			var pending: GodotASketchSplatMap = item.get("map")
			if pending:
				return pending
	var legacy_path := map_path(target)
	if not legacy_path.is_empty() and ResourceLoader.exists(legacy_path):
		if _by_path.has(legacy_path):
			return _by_path[legacy_path]
		var legacy := ResourceLoader.load(legacy_path) as GodotASketchSplatMap
		if legacy:
			legacy.ensure_rgba8()
			_by_path[legacy_path] = legacy
			return legacy
	var stack := ShaderStackAssign.load_stack(target)
	if stack and layer_index >= 0 and layer_index < stack.layers.size():
		var layer = stack.layers[layer_index]
		if layer:
			var lp := layer_map_path(layer, target, layer_index)
			var cached := _cached_map_for_path(lp)
			if cached:
				return cached
			return load_layer_map(target, layer, layer_index)
	return null


## In-memory splat only — no stack reload or disk parse (for fast selection/hover UI).
static func peek_map(target: Node3D, layer_index: int = 0) -> GodotASketchSplatMap:
	if target == null:
		return null
	var layer_key := _layer_key(target, layer_index)
	var live: GodotASketchSplatMap = _working.get(layer_key)
	if live:
		return live
	for path in _disk_persist_pending.keys():
		var item: Dictionary = _disk_persist_pending[path]
		if int(item.get("target_id", -1)) == target.get_instance_id() and int(item.get("layer_index", 0)) == layer_index:
			var pending: GodotASketchSplatMap = item.get("map")
			if pending:
				return pending
	var legacy_path := map_path(target)
	if not legacy_path.is_empty() and _by_path.has(legacy_path):
		return _by_path[legacy_path]
	var default_path := Constants.splat_layer_path(target, layer_index)
	if _by_path.has(default_path):
		return _by_path[default_path]
	if _disk_persist_pending.has(default_path):
		return _disk_persist_pending[default_path].get("map")
	return null


static func reload_map(target: Node3D) -> GodotASketchSplatMap:
	if target == null:
		return null
	var path := map_path(target)
	if not path.is_empty():
		_by_path.erase(path)
	_working.erase(_mesh_work_key(target))
	var stack := ShaderStackAssign.load_stack(target)
	if stack:
		for i in stack.layers.size():
			var layer = stack.layers[i]
			if layer == null:
				continue
			var lp := layer_map_path(layer, target, i)
			if not lp.is_empty():
				_by_path.erase(lp)
			_working.erase(_layer_key(target, i))
	return latest_map(target)


static func working_map(target: Node3D) -> GodotASketchSplatMap:
	if target == null:
		return null
	return _working.get(_mesh_work_key(target))


static func begin_edit(target: Node3D, layer = null, layer_index: int = 0) -> GodotASketchSplatMap:
	if target == null:
		return null
	if layer != null:
		var key := _layer_key(target, layer_index)
		var map: GodotASketchSplatMap = _working.get(key)
		if map == null:
			map = latest_map(target, layer_index)
		if map == null:
			map = load_layer_map(target, layer, layer_index)
		if map == null:
			map = SplatMap.create_default(default_resolution())
			bind_layer_map_memory(target, layer, layer_index, map)
		map.ensure_rgba8()
		_working[key] = map
		return map
	var stack := ShaderStackAssign.load_stack(target)
	if stack and not stack.layers.is_empty() and stack.layers[0]:
		return begin_edit(target, stack.layers[0], 0)
	var legacy_map := load_map(target)
	if legacy_map == null:
		legacy_map = SplatMap.create_default(default_resolution())
		if assign_map(target, legacy_map) != "":
			return null
	legacy_map.ensure_rgba8()
	_working[_mesh_work_key(target)] = legacy_map
	return legacy_map


static func commit_edit(target: Node3D, layer = null, layer_index: int = 0) -> GodotASketchSplatMap:
	if target == null:
		return null
	if layer != null:
		var key := _layer_key(target, layer_index)
		var layer_map: GodotASketchSplatMap = _working.get(key)
		if layer_map == null:
			return load_layer_map(target, layer, layer_index)
		if _commit_layer_memory(target, layer, layer_index, layer_map, key) != "":
			push_warning("Godot-a-Sketch: splat map commit failed — stroke kept in memory")
			return layer_map
		_queue_disk_persist(target, layer, layer_index, layer_map)
		return layer_map
	var stack := ShaderStackAssign.load_stack(target)
	if stack and not stack.layers.is_empty() and stack.layers[0]:
		return commit_edit(target, stack.layers[0], 0)
	var mesh_key := _mesh_work_key(target)
	var map: GodotASketchSplatMap = _working.get(mesh_key)
	if map == null:
		return load_map(target)
	if assign_map(target, map) != "":
		push_warning("Godot-a-Sketch: splat map save failed — stroke kept in memory")
		return map
	_working.erase(mesh_key)
	var legacy_path := map_path(target)
	if not legacy_path.is_empty():
		_by_path[legacy_path] = map
	return map


static func assign_map(target: Node3D, map: GodotASketchSplatMap, path: String = "") -> String:
	if target == null or map == null:
		return "Invalid mesh or splat map"
	var old_path := map_path(target)
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = old_path
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = _legacy_flat_path(target)
	if ResourceLoader.exists(path) and not ResourceLoader.exists(path, "GodotASketchSplatMap"):
		return "Refusing to overwrite non-splat resource at %s" % path
	var err := _ensure_parent_dir(path)
	if err != "":
		return err
	var save_err := ResourceSaver.save(map, path)
	if save_err != OK:
		return "Failed to save splat map: %s" % error_string(save_err)
	if not old_path.is_empty() and old_path != path:
		_by_path.erase(old_path)
	target.set_meta(Constants.SPLAT_MAP_META, path)
	_by_path[path] = map
	EditorInterface.mark_scene_as_unsaved()
	_notify_filesystem(path)
	return ""


static func ensure_map(target: Node3D) -> GodotASketchSplatMap:
	var stack := ShaderStackAssign.load_stack(target)
	if stack and not stack.layers.is_empty() and stack.layers[0]:
		return ensure_layer_map(target, stack.layers[0], 0)
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
	_working.erase(_mesh_work_key(target))
	if not path.is_empty():
		_by_path.erase(path)
	if target.has_meta(Constants.SPLAT_MAP_META):
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


static func _mesh_work_key(target: Node3D) -> String:
	return "%d" % target.get_instance_id()


static func layer_map_path(layer, target: Node3D, layer_index: int) -> String:
	if layer == null:
		return ""
	var path := String(layer.splat_map_path)
	if not path.is_empty() and Constants.is_usable_resource_path(path):
		return path
	return Constants.splat_layer_path(target, layer_index)


static func load_layer_map(target: Node3D, layer, layer_index: int) -> GodotASketchSplatMap:
	if target == null or layer == null:
		return null
	var live := working_layer_map(target, layer_index)
	if live:
		return live
	var path := layer_map_path(layer, target, layer_index)
	var cached := _cached_map_for_path(path)
	if cached:
		_bind_layer_map(layer, path, cached)
		return cached
	if layer.splat_map != null and layer.splat_map.image != null:
		layer.splat_map.ensure_rgba8()
		if not path.is_empty() and not _by_path.has(path):
			_by_path[path] = layer.splat_map
		_bind_layer_map(layer, path, layer.splat_map)
		return layer.splat_map
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var map := ResourceLoader.load(path) as GodotASketchSplatMap
	if map == null or map.get_script() == null:
		return null
	map.ensure_rgba8()
	_bind_layer_map(layer, path, map)
	return map


static func _cached_map_for_path(path: String) -> GodotASketchSplatMap:
	if path.is_empty():
		return null
	if _by_path.has(path):
		return _by_path[path]
	if _disk_persist_pending.has(path):
		var item: Dictionary = _disk_persist_pending[path]
		var pending: GodotASketchSplatMap = item.get("map")
		if pending:
			return pending
	return null


static func _bind_layer_map(layer, path: String, map: GodotASketchSplatMap) -> void:
	if layer == null or map == null:
		return
	if not path.is_empty():
		layer.splat_map_path = path
		_by_path[path] = map
	layer.splat_map = map


static func reload_layer_map(target: Node3D, layer, layer_index: int) -> GodotASketchSplatMap:
	if target == null or layer == null:
		return null
	var path := layer_map_path(layer, target, layer_index)
	if not path.is_empty():
		_by_path.erase(path)
	_working.erase(_layer_key(target, layer_index))
	return load_layer_map(target, layer, layer_index)


static func working_layer_map(target: Node3D, layer_index: int) -> GodotASketchSplatMap:
	if target == null:
		return null
	return _working.get(_layer_key(target, layer_index))


static func clear_working() -> void:
	_working.clear()


static func flush_disk_persists() -> void:
	if _disk_persist_pending.is_empty():
		return
	var pending := _disk_persist_pending.duplicate()
	_disk_persist_pending.clear()
	for path in pending.keys():
		var item: Dictionary = pending[path]
		var map: GodotASketchSplatMap = item.get("map")
		if map == null:
			continue
		var save_err := ResourceSaver.save(map, path)
		if save_err != OK:
			push_warning("Godot-a-Sketch: splat map save failed for %s" % path)
			_disk_persist_pending[path] = item
			continue
		_notify_filesystem(path)


static func has_disk_persist_pending() -> bool:
	return not _disk_persist_pending.is_empty()


static func _commit_layer_memory(
	target: Node3D,
	layer,
	layer_index: int,
	map: GodotASketchSplatMap,
	working_key: String
) -> String:
	if target == null or layer == null or map == null:
		return "Invalid mesh, layer, or splat map"
	var path := layer_map_path(layer, target, layer_index)
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = Constants.splat_layer_path(target, layer_index)
	var err := _ensure_parent_dir(path)
	if err != "":
		return err
	layer.splat_map = map
	layer.splat_map_path = path
	_by_path[path] = map
	# ponytail: keep working buffer across strokes — erase only via reload_layer_map/clear_working
	EditorInterface.mark_scene_as_unsaved()
	return ""


static func _queue_disk_persist(target: Node3D, layer, layer_index: int, map: GodotASketchSplatMap) -> void:
	var path := layer_map_path(layer, target, layer_index)
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = Constants.splat_layer_path(target, layer_index)
	_disk_persist_pending[path] = {
		"target_id": target.get_instance_id(),
		"layer_index": layer_index,
		"map": map,
	}


static func default_resolution() -> int:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(Constants.SETTINGS_SPLAT_SIZE):
		return clamp_splat_resolution(int(settings.get_setting(Constants.SETTINGS_SPLAT_SIZE)))
	return Constants.DEFAULT_SPLAT_SIZE


static func clamp_splat_resolution(resolution: int) -> int:
	var best := Constants.SPLAT_SIZE_OPTIONS[0]
	var best_dist := absi(resolution - best)
	for option in Constants.SPLAT_SIZE_OPTIONS:
		var dist := absi(resolution - option)
		if dist < best_dist:
			best = option
			best_dist = dist
	return best


static func resize_layer_map(
	target: Node3D,
	layer,
	layer_index: int,
	resolution: int
) -> GodotASketchSplatMap:
	if target == null or layer == null:
		return null
	resolution = clamp_splat_resolution(resolution)
	var key := _layer_key(target, layer_index)
	var map: GodotASketchSplatMap = _working.get(key)
	if map == null:
		map = latest_map(target, layer_index)
	if map == null:
		map = ensure_layer_map(target, layer, layer_index)
	if map == null:
		return null
	if map.size.x == resolution and map.size.y == resolution:
		_working[key] = map
		return map
	map.resize_to(resolution)
	_working[key] = map
	if _commit_layer_memory(target, layer, layer_index, map, key) != "":
		push_warning("Godot-a-Sketch: splat resize commit failed — kept in memory")
		return map
	_queue_disk_persist(target, layer, layer_index, map)
	return map


static func assign_layer_map(
	target: Node3D,
	layer,
	layer_index: int,
	map: GodotASketchSplatMap,
	path: String = ""
) -> String:
	if target == null or layer == null or map == null:
		return "Invalid mesh, layer, or splat map"
	var old_path := layer_map_path(layer, target, layer_index)
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = old_path
	if path.is_empty() or not Constants.is_usable_resource_path(path):
		path = Constants.splat_layer_path(target, layer_index)
	if ResourceLoader.exists(path) and not ResourceLoader.exists(path, "GodotASketchSplatMap"):
		return "Refusing to overwrite non-splat resource at %s" % path
	var err := _ensure_parent_dir(path)
	if err != "":
		return err
	var save_err := ResourceSaver.save(map, path)
	if save_err != OK:
		return "Failed to save splat map: %s" % error_string(save_err)
	if not old_path.is_empty() and old_path != path:
		_by_path.erase(old_path)
	layer.splat_map = map
	layer.splat_map_path = path
	_by_path[path] = map
	_save_stack_if_present(target)
	EditorInterface.mark_scene_as_unsaved()
	_notify_filesystem(path)
	return ""


static func bind_layer_map_memory(
	target: Node3D,
	layer,
	layer_index: int,
	map: GodotASketchSplatMap
) -> String:
	return _commit_layer_memory(target, layer, layer_index, map, _layer_key(target, layer_index))


static func ensure_layer_map(target: Node3D, layer, layer_index: int) -> GodotASketchSplatMap:
	if target == null or layer == null:
		return null
	var live := working_layer_map(target, layer_index)
	if live:
		return live
	var map := load_layer_map(target, layer, layer_index)
	if map:
		return map
	map = SplatMap.create_default(default_resolution())
	bind_layer_map_memory(target, layer, layer_index, map)
	_working[_layer_key(target, layer_index)] = map
	return map


static func detach_layer_maps(target: Node3D, delete_files: bool = true) -> void:
	if target == null:
		return
	var id := target.get_instance_id()
	var keys_to_erase: Array[String] = []
	for key in _working.keys():
		if String(key).begins_with("%d:" % id):
			keys_to_erase.append(key)
	for key in keys_to_erase:
		_working.erase(key)
	if not delete_files:
		return
	var dir := Constants.splat_layer_dir(target)
	if not dir.begins_with(Constants.SPLAT_MAP_DEFAULT_DIR):
		return
	var abs_dir := ProjectSettings.globalize_path(dir)
	if abs_dir.is_empty() or not DirAccess.dir_exists_absolute(abs_dir):
		return
	_delete_dir_recursive(abs_dir)
	_notify_filesystem(dir)


static func migrate_legacy_mesh_splat(target: Node3D, stack) -> void:
	if target == null or stack == null:
		return
	if not target.has_meta(Constants.SPLAT_MAP_META):
		var legacy_flat := _legacy_flat_path(target)
		if not ResourceLoader.exists(legacy_flat) and _layers_use_folder_paths(target, stack):
			return
	var legacy_path := ""
	if target.has_meta(Constants.SPLAT_MAP_META):
		legacy_path = String(target.get_meta(Constants.SPLAT_MAP_META))
	if legacy_path.is_empty():
		legacy_path = _legacy_flat_path(target)
	if legacy_path.is_empty() or not ResourceLoader.exists(legacy_path):
		_relocate_flat_layer_maps(target, stack)
		return
	var legacy := ResourceLoader.load(legacy_path) as GodotASketchSplatMap
	if legacy == null:
		target.remove_meta(Constants.SPLAT_MAP_META)
		return
	legacy.ensure_rgba8()
	for i in stack.layers.size():
		var layer = stack.layers[i]
		if layer == null:
			continue
		if not layer_map_path(layer, target, i).is_empty() and ResourceLoader.exists(
			layer_map_path(layer, target, i)
		):
			continue
		var ch := clampi(layer.mask_channel, 0, 3)
		var split := SplatMap.from_channel(legacy, ch)
		assign_layer_map(target, layer, i, split)
	_relocate_flat_layer_maps(target, stack)
	target.remove_meta(Constants.SPLAT_MAP_META)
	if legacy_path.begins_with(Constants.SPLAT_MAP_DEFAULT_DIR):
		var abs := ProjectSettings.globalize_path(legacy_path)
		if not abs.is_empty() and FileAccess.file_exists(abs):
			DirAccess.remove_absolute(abs)
		_notify_filesystem(legacy_path)


static func _legacy_flat_path(target: Node3D) -> String:
	return Constants.SPLAT_MAP_DEFAULT_DIR.path_join("%s.tres" % Constants.paint_target_slug(target))


static func _layers_use_folder_paths(target: Node3D, stack) -> bool:
	for i in stack.layers.size():
		var layer = stack.layers[i]
		if layer == null:
			continue
		var expected := Constants.splat_layer_path(target, i)
		if layer_map_path(layer, target, i) != expected:
			return false
		if not ResourceLoader.exists(expected):
			return false
	return true


static func _relocate_flat_layer_maps(target: Node3D, stack) -> void:
	if stack == null:
		return
	for i in stack.layers.size():
		var layer = stack.layers[i]
		if layer == null:
			continue
		var path := layer_map_path(layer, target, i)
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var expected := Constants.splat_layer_path(target, i)
		if path == expected:
			continue
		if not path.begins_with(Constants.SPLAT_MAP_DEFAULT_DIR):
			continue
		var map := ResourceLoader.load(path) as GodotASketchSplatMap
		if map == null:
			continue
		assign_layer_map(target, layer, i, map, expected)
		var abs := ProjectSettings.globalize_path(path)
		if not abs.is_empty() and FileAccess.file_exists(abs) and path != expected:
			DirAccess.remove_absolute(abs)
			_notify_filesystem(path)


static func _delete_dir_recursive(abs_dir: String) -> void:
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := abs_dir.path_join(name)
			if dir.current_is_dir():
				_delete_dir_recursive(child)
			else:
				DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_dir)


static func _save_stack_if_present(target: Node3D) -> void:
	var stack := ShaderStackAssign.load_stack(target)
	if stack:
		ShaderStackAssign.assign_stack(target, stack)


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
