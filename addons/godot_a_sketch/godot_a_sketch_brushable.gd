extends RefCounted
class_name GodotASketchBrushable

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const MeshUV := preload("res://addons/godot_a_sketch/godot_a_sketch_mesh_uv.gd")
const SplatMapAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map_assign.gd")
const ShaderStackAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack_assign.gd")
const ShaderStackLayer := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack_layer.gd")
const ShaderValidator := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_validator.gd")


static func mark(node: Node3D) -> String:
	var target := resolve_paint_target(node)
	if target == null:
		return "Select a MeshInstance3D or MultiMeshInstance3D"
	if target is MultiMeshInstance3D:
		return _mark_multimesh(target as MultiMeshInstance3D)
	return _mark_surface_mesh(target as MeshInstance3D)


static func unmark(node: Node3D) -> String:
	var target := resolve_paint_target(node)
	if target == null:
		return "Select a MeshInstance3D or MultiMeshInstance3D"
	if target is MultiMeshInstance3D:
		return _unmark_multimesh(target as MultiMeshInstance3D)
	return _unmark_surface_mesh(target as MeshInstance3D)


static func _mark_surface_mesh(mesh: MeshInstance3D) -> String:
	if mesh.mesh == null:
		return "MeshInstance3D has no mesh"
	var body := _find_paint_body(mesh)
	if body:
		body.set_collision_layer_value(Constants.PAINT_LAYER, true)
	else:
		var err := _create_auto_body(mesh)
		if err != "":
			return err
	mesh.set_meta(Constants.BRUSHABLE_META, true)
	mesh.add_to_group(Constants.BRUSHABLE_GROUP)
	_cache_triangle_mesh(mesh)
	MeshUV.cache(mesh)
	SplatMapAssign.ensure_map(mesh)
	snapshot_base_material_override(mesh)
	_sync_paint_body(mesh)
	_mark_scene_edited(mesh)
	return ""


static func _mark_multimesh(multimesh: MultiMeshInstance3D) -> String:
	if multimesh.multimesh == null or multimesh.multimesh.mesh == null:
		return "MultiMeshInstance3D has no multimesh mesh"
	multimesh.set_meta(Constants.BRUSHABLE_META, true)
	multimesh.add_to_group(Constants.BRUSHABLE_GROUP)
	SplatMapAssign.ensure_map(multimesh)
	snapshot_base_material_override(multimesh)
	rebuild_material_stack(multimesh)
	_mark_scene_edited(multimesh)
	return ""


static func _unmark_surface_mesh(mesh: MeshInstance3D) -> String:
	mesh.remove_from_group(Constants.BRUSHABLE_GROUP)
	if mesh.has_meta(Constants.BRUSHABLE_META):
		mesh.remove_meta(Constants.BRUSHABLE_META)
	if mesh.has_meta(Constants.TRIANGLE_MESH_META):
		mesh.remove_meta(Constants.TRIANGLE_MESH_META)
	MeshUV.clear(mesh)
	ShaderStackAssign.detach_stack(mesh)
	SplatMapAssign.detach_map(mesh)
	if mesh.has_meta(Constants.AUTO_BODY_META) and mesh.get_meta(Constants.AUTO_BODY_META):
		var auto_body := mesh.get_node_or_null(Constants.AUTO_BODY_NAME)
		if auto_body:
			auto_body.queue_free()
		mesh.remove_meta(Constants.AUTO_BODY_META)
	else:
		var body := _find_paint_body(mesh)
		if body:
			body.set_collision_layer_value(Constants.PAINT_LAYER, false)
	_mark_scene_edited(mesh)
	return ""


static func _unmark_multimesh(multimesh: MultiMeshInstance3D) -> String:
	multimesh.remove_from_group(Constants.BRUSHABLE_GROUP)
	if multimesh.has_meta(Constants.BRUSHABLE_META):
		multimesh.remove_meta(Constants.BRUSHABLE_META)
	ShaderStackAssign.detach_stack(multimesh)
	SplatMapAssign.detach_map(multimesh)
	_clear_stack_material_override(multimesh)
	_mark_scene_edited(multimesh)
	return ""


static func _mark_scene_edited(_target: Node3D) -> void:
	EditorInterface.mark_scene_as_unsaved()


static func is_brushable(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group(Constants.BRUSHABLE_GROUP):
		return true
	return node.has_meta(Constants.BRUSHABLE_META)


static func is_multimesh_target(target: Node) -> bool:
	return target is MultiMeshInstance3D


static func supports_splat_paint(target: Node) -> bool:
	return target is MeshInstance3D


static func resolve_paint_target(node: Node3D) -> Node3D:
	if node is MultiMeshInstance3D or node is MeshInstance3D:
		return node
	var multimeshes := node.find_children("*", "MultiMeshInstance3D", true, false)
	if not multimeshes.is_empty():
		return multimeshes[0] as Node3D
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty():
		return meshes[0] as Node3D
	return null


static func find_brushable_for_collider(node: Node) -> Node3D:
	if node.name == Constants.AUTO_BODY_NAME:
		var parent := node.get_parent()
		if parent is Node3D and is_brushable(parent):
			return parent
	var current := node
	while current:
		if current is Node3D and is_brushable(current):
			return current
		current = current.get_parent()
	return _find_brushable_paint_target_descendant(node)


static func resolve_mesh(node: Node3D) -> MeshInstance3D:
	var target := resolve_paint_target(node)
	if target is MeshInstance3D:
		return target
	return null


static func as_geometry(target: Node3D) -> GeometryInstance3D:
	if target is GeometryInstance3D:
		return target as GeometryInstance3D
	return null


static func refresh_material_on_mesh(target: Node3D) -> void:
	refresh_splat_uniforms_on_mesh(target)
	rebuild_material_stack(target)


static func refresh_splat_uniforms_on_mesh(target: Node3D) -> void:
	var geom := as_geometry(target)
	if geom == null:
		return
	var map_tex := _splat_texture_for_mesh(target)
	if map_tex == null:
		return
	var mat: Material = geom.material_override
	while mat:
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("splat_mask", map_tex)
		mat = mat.next_pass


static func has_viewport_stack(target: Node3D) -> bool:
	var stack := ShaderStackAssign.load_stack(target)
	if stack == null:
		return false
	return not _viewport_stack_layers(stack, is_multimesh_target(target)).is_empty()


static func rebuild_material_stack(target: Node3D) -> void:
	var geom := as_geometry(target)
	if geom == null:
		return
	var stack := ShaderStackAssign.load_stack(target)
	if stack == null or stack.layers.is_empty():
		_clear_stack_material_override(target)
		return
	var multimesh := is_multimesh_target(target)
	var layers := _viewport_stack_layers(stack, multimesh)
	if layers.is_empty():
		_clear_stack_material_override(target)
		return
	var map_tex := _splat_texture_for_mesh(target)
	var passes: Array[ShaderMaterial] = []
	for i in layers.size():
		var layer_shader: Shader = layers[i].get_shader()
		var compat_err := ShaderValidator.layer_mesh_compat_error(layer_shader, target)
		if compat_err != "":
			push_warning("Godot-a-Sketch: %s" % compat_err)
		var mat := pass_material_for_layer(layers[i], map_tex, i)
		if mat:
			passes.append(mat)
	if passes.is_empty():
		_clear_stack_material_override(target)
		return
	for i in range(passes.size() - 1):
		passes[i].next_pass = passes[i + 1]
	geom.material_override = passes[0]
	if Engine.is_editor_hint():
		_mark_scene_edited(target)


static func pass_material_for_layer(
	layer,
	map_tex: Texture2D,
	pass_index: int = 0
) -> ShaderMaterial:
	if layer == null:
		return null
	var src: ShaderMaterial = layer.ensure_layer_material()
	if src.shader == null:
		return null
	var mat: ShaderMaterial = src.duplicate() as ShaderMaterial
	mat.render_priority = pass_index
	_apply_layer_contract(mat, layer, map_tex)
	return mat


static func stack_uses_layer_material(target: Node3D, material: ShaderMaterial) -> bool:
	if target == null or material == null:
		return false
	var stack := ShaderStackAssign.load_stack(target)
	if stack == null:
		return false
	for layer in stack.layers:
		if layer != null and layer.layer_material == material:
			return true
	return false


static func _viewport_stack_layers(stack, multimesh: bool) -> Array:
	var out: Array = []
	for layer in stack.layers:
		if layer == null:
			continue
		var shader: Shader = layer.get_shader()
		if shader == null:
			continue
		if not _is_viewport_stack_shader(shader, multimesh):
			continue
		out.append(layer)
	return out


static func _is_viewport_stack_shader(shader: Shader, multimesh: bool) -> bool:
	if not ShaderValidator.is_layer_shader(shader):
		return false
	var path := shader.resource_path
	if path == Constants.LAYER_TEMPLATE_PATH:
		return false
	if path.ends_with("/ghost_brush.gdshader"):
		return false
	if multimesh:
		return true
	if ShaderValidator.shader_uses_instance_data(shader):
		return false
	return true


static func _clear_stack_material_override(target: Node3D) -> void:
	var geom := as_geometry(target)
	if geom == null:
		return
	if target.has_meta(Constants.BASE_OVERRIDE_META):
		geom.material_override = target.get_meta(Constants.BASE_OVERRIDE_META)
		target.remove_meta(Constants.BASE_OVERRIDE_META)
		return
	if geom.material_override is ShaderMaterial:
		geom.material_override = null


static func snapshot_base_material_override(target: Node3D) -> void:
	var geom := as_geometry(target)
	if geom == null or target.has_meta(Constants.BASE_OVERRIDE_META):
		return
	target.set_meta(Constants.BASE_OVERRIDE_META, geom.material_override)


static func _splat_texture_for_mesh(target: Node3D) -> Texture2D:
	var map = SplatMapAssign.working_map(target)
	if map == null:
		map = SplatMapAssign.load_map(target)
	if map == null:
		return null
	return map.to_texture()


static func _apply_layer_contract(mat: ShaderMaterial, layer, map_tex: Texture2D) -> void:
	if map_tex:
		mat.set_shader_parameter("splat_mask", map_tex)
	mat.set_shader_parameter("mask_channel", layer.mask_channel)
	mat.set_shader_parameter("layer_weight", layer.weight)


static func _find_brushable_paint_target_descendant(root: Node) -> Node3D:
	if (root is MeshInstance3D or root is MultiMeshInstance3D) and is_brushable(root):
		return root
	for child in root.get_children():
		var found := _find_brushable_paint_target_descendant(child)
		if found:
			return found
	return null


static func triangle_mesh_for(mesh_instance: MeshInstance3D) -> TriangleMesh:
	if mesh_instance.has_meta(Constants.TRIANGLE_MESH_META):
		return mesh_instance.get_meta(Constants.TRIANGLE_MESH_META)
	return _cache_triangle_mesh(mesh_instance)


static func _cache_triangle_mesh(mesh_instance: MeshInstance3D) -> TriangleMesh:
	if mesh_instance.mesh == null:
		return null
	var triangle_mesh: TriangleMesh = mesh_instance.mesh.generate_triangle_mesh()
	if triangle_mesh == null:
		return null
	mesh_instance.set_meta(Constants.TRIANGLE_MESH_META, triangle_mesh)
	return triangle_mesh


static func _find_paint_body(root: Node) -> CollisionObject3D:
	var found := _find_paint_body_recursive(root)
	if found:
		return found
	var parent := root.get_parent()
	if parent is CollisionObject3D:
		return parent
	return null


static func _find_paint_body_recursive(root: Node) -> CollisionObject3D:
	if root is CollisionObject3D:
		return root
	for child in root.get_children():
		var found := _find_paint_body_recursive(child)
		if found:
			return found
	return null


static func _create_auto_body(mesh: MeshInstance3D) -> String:
	if mesh.get_node_or_null(Constants.AUTO_BODY_NAME):
		return ""
	var shape := _shape_for_mesh(mesh.mesh)
	if shape == null:
		return "Could not create collision shape from mesh"
	var body := StaticBody3D.new()
	body.name = Constants.AUTO_BODY_NAME
	body.set_collision_layer_value(Constants.PAINT_LAYER, true)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	mesh.add_child(body)
	var owner_root := mesh.owner
	if owner_root == null and mesh.is_inside_tree():
		owner_root = mesh.get_tree().edited_scene_root
	body.owner = owner_root
	collision.owner = owner_root
	mesh.set_meta(Constants.AUTO_BODY_META, true)
	return ""


static func _shape_for_mesh(mesh: Mesh) -> Shape3D:
	if mesh is BoxMesh:
		var box_shape := BoxShape3D.new()
		box_shape.size = (mesh as BoxMesh).size
		return box_shape
	return mesh.create_trimesh_shape()


static func _sync_paint_body(mesh: MeshInstance3D) -> void:
	var body := mesh.get_node_or_null(Constants.AUTO_BODY_NAME) as CollisionObject3D
	if body == null:
		return
	body.global_transform = mesh.global_transform


static func rebuild_grass_fields_for_surface(surface: Node3D) -> void:
	if surface == null:
		return
	var tree := surface.get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(&"grass_field"):
		if not node.has_method("_request_rebuild"):
			continue
		var surface_path: NodePath = node.get("surface")
		if surface_path.is_empty():
			continue
		if node.get_node_or_null(surface_path) == surface:
			node._request_rebuild()
