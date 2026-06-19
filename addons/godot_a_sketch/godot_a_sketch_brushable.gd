extends RefCounted
class_name GodotASketchBrushable

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")

static func mark(node: Node3D) -> String:
	var mesh := _resolve_mesh(node)
	if mesh == null:
		return "Select a MeshInstance3D"
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
	_sync_paint_body(mesh)
	return ""


static func unmark(node: Node3D) -> String:
	var mesh := _resolve_mesh(node)
	if mesh == null:
		return "Select a MeshInstance3D"

	mesh.remove_from_group(Constants.BRUSHABLE_GROUP)
	if mesh.has_meta(Constants.BRUSHABLE_META):
		mesh.remove_meta(Constants.BRUSHABLE_META)
	if mesh.has_meta(Constants.TRIANGLE_MESH_META):
		mesh.remove_meta(Constants.TRIANGLE_MESH_META)

	if mesh.has_meta(Constants.AUTO_BODY_META) and mesh.get_meta(Constants.AUTO_BODY_META):
		var auto_body := mesh.get_node_or_null(Constants.AUTO_BODY_NAME)
		if auto_body:
			auto_body.queue_free()
		mesh.remove_meta(Constants.AUTO_BODY_META)
	else:
		var body := _find_paint_body(mesh)
		if body:
			body.set_collision_layer_value(Constants.PAINT_LAYER, false)

	return ""


static func is_brushable(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group(Constants.BRUSHABLE_GROUP):
		return true
	return node.has_meta(Constants.BRUSHABLE_META)


static func find_brushable_ancestor(node: Node) -> Node3D:
	var current := node
	while current:
		if current is Node3D and is_brushable(current):
			return current
		current = current.get_parent()
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


static func _resolve_mesh(node: Node3D) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
	return null


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
