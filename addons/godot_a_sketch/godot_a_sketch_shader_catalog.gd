extends RefCounted
class_name GodotASketchShaderCatalog

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")

static var _entries: Array[GodotASketchShaderCatalogEntry] = []
static var _scanned := false


static func rescan(probe_shaders: bool = false) -> Array[GodotASketchShaderCatalogEntry]:
	_entries.clear()
	_scan_dir(Constants.BUNDLED_SHADER_DIR, "bundled")
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		var root := fs.get_filesystem()
		if root:
			_walk_fs_dir(root)
	_scanned = true
	_entries.sort_custom(_sort_entries)
	if probe_shaders:
		for entry in _entries:
			probe_entry(entry)
	return _entries.duplicate()


static func get_entries() -> Array[GodotASketchShaderCatalogEntry]:
	if not _scanned:
		rescan(false)
	return _entries.duplicate()


static func probe_entry(entry: GodotASketchShaderCatalogEntry) -> void:
	if entry == null or entry.probed:
		return
	entry.probed = true
	entry.has_contract = GodotASketchShaderContract.source_has_contract(entry.path)
	if not ResourceLoader.exists(entry.path):
		entry.loadable = false
		entry.paint_ready = false
		return
	var shader: Shader = load(entry.path) as Shader
	entry.loadable = shader != null
	entry.paint_ready = entry.loadable and GodotASketchShaderValidator.is_layer_shader(shader)


static func total_count() -> int:
	return get_entries().size()


static func paint_ready_count() -> int:
	var count := 0
	for entry in get_entries():
		if not entry.probed:
			probe_entry(entry)
		if entry.paint_ready:
			count += 1
	return count


static func shader_from_mesh(mesh: MeshInstance3D) -> Shader:
	if mesh == null:
		return null
	var override_mat := mesh.material_override
	if override_mat is ShaderMaterial:
		return (override_mat as ShaderMaterial).shader
	for i in mesh.get_surface_override_material_count():
		var surf := mesh.get_surface_override_material(i)
		if surf is ShaderMaterial:
			var sh: Shader = (surf as ShaderMaterial).shader
			if sh:
				return sh
	if mesh.mesh:
		for i in mesh.mesh.get_surface_count():
			var active := mesh.get_active_material(i)
			if active is ShaderMaterial:
				var sh: Shader = (active as ShaderMaterial).shader
				if sh:
					return sh
	return null


static func _sort_entries(a: GodotASketchShaderCatalogEntry, b: GodotASketchShaderCatalogEntry) -> bool:
	if a.source == b.source:
		return a.display_name.nocasecmp_to(b.display_name) < 0
	return a.source == "bundled"


static func _scan_dir(dir_path: String, source: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gdshader"):
			_add_shader_path(dir_path.path_join(file_name), source)
	for subdir: String in dir.get_directories():
		if subdir == "." or subdir == "..":
			continue
		var full := dir_path.path_join(subdir)
		if source == "project" and _skip_project_dir(full):
			continue
		_scan_dir(full, source)


static func _skip_project_dir(path: String) -> bool:
	return path.begins_with("res://.godot")


static func _walk_fs_dir(dir: EditorFileSystemDirectory) -> void:
	for i in dir.get_file_count():
		var path := dir.get_file_path(i)
		if path.ends_with(".gdshader"):
			_add_shader_path(path, "project")
	for i in dir.get_subdir_count():
		_walk_fs_dir(dir.get_subdir(i))


static func _add_shader_path(path: String, source: String) -> void:
	for entry in _entries:
		if entry.path == path:
			if source == "bundled":
				entry.source = "bundled"
			return
	if not ResourceLoader.exists(path):
		return
	var item := GodotASketchShaderCatalogEntry.new()
	item.path = path
	item.display_name = path.get_file().get_basename()
	item.source = source
	_entries.append(item)
