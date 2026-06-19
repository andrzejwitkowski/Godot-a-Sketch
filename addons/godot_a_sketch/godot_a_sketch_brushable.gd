class_name GodotASketchBrushable


static func mark(node: Node3D) -> String:
	var mesh := _resolve_mesh(node)
	if mesh == null:
		return "Select a MeshInstance3D"
	if mesh.mesh == null:
		return "MeshInstance3D has no mesh"

	var body := _find_static_body(mesh)
	if body:
		body.collision_layer |= GodotASketchConstants.PAINT_COLLISION_MASK
	else:
		var err := _create_auto_body(mesh)
		if err != "":
			return err

	mesh.set_meta(GodotASketchConstants.BRUSHABLE_META, true)
	mesh.add_to_group(GodotASketchConstants.BRUSHABLE_GROUP)
	return ""


static func unmark(node: Node3D) -> String:
	var mesh := _resolve_mesh(node)
	if mesh == null:
		return "Select a MeshInstance3D"

	mesh.remove_from_group(GodotASketchConstants.BRUSHABLE_GROUP)
	if mesh.has_meta(GodotASketchConstants.BRUSHABLE_META):
		mesh.remove_meta(GodotASketchConstants.BRUSHABLE_META)

	if mesh.has_meta(GodotASketchConstants.AUTO_BODY_META) and mesh.get_meta(GodotASketchConstants.AUTO_BODY_META):
		var auto_body := mesh.get_node_or_null(GodotASketchConstants.AUTO_BODY_NAME)
		if auto_body:
			auto_body.queue_free()
		mesh.remove_meta(GodotASketchConstants.AUTO_BODY_META)
	else:
		var body := _find_static_body(mesh)
		if body:
			body.collision_layer &= ~GodotASketchConstants.PAINT_COLLISION_MASK

	return ""


static func is_brushable(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group(GodotASketchConstants.BRUSHABLE_GROUP):
		return true
	return node.has_meta(GodotASketchConstants.BRUSHABLE_META)


static func find_brushable_ancestor(node: Node) -> Node3D:
	var current := node
	while current:
		if current is Node3D and is_brushable(current):
			return current
		current = current.get_parent()
	return null


static func _resolve_mesh(node: Node3D) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
	return null


static func _find_static_body(root: Node) -> StaticBody3D:
	if root is StaticBody3D:
		return root
	for child in root.get_children():
		var found := _find_static_body(child)
		if found:
			return found
	return null


static func _create_auto_body(mesh: MeshInstance3D) -> String:
	if mesh.get_node_or_null(GodotASketchConstants.AUTO_BODY_NAME):
		return ""

	var shape := mesh.mesh.create_trimesh_shape()
	if shape == null:
		return "Could not create collision shape from mesh"

	var body := StaticBody3D.new()
	body.name = GodotASketchConstants.AUTO_BODY_NAME
	body.collision_layer = GodotASketchConstants.PAINT_COLLISION_MASK

	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	mesh.add_child(body)
	var owner_root := mesh.owner
	if owner_root == null and mesh.is_inside_tree():
		owner_root = mesh.get_tree().edited_scene_root
	body.owner = owner_root
	collision.owner = owner_root
	mesh.set_meta(GodotASketchConstants.AUTO_BODY_META, true)
	return ""
