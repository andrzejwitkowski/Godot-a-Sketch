class_name GodotASketchRaycast


static func cast_from_camera(camera: Camera3D, screen_pos: Vector2, scene_root: Node3D) -> Dictionary:
	var world := scene_root.get_world_3d()
	if world == null:
		return {}

	var space_state := world.direct_space_state
	if space_state == null:
		return {}

	var origin := camera.project_ray_origin(screen_pos)
	var end := origin + camera.project_ray_normal(screen_pos) * GodotASketchConstants.RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = GodotASketchConstants.PAINT_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {}

	var collider: Object = result.get("collider")
	if collider == null or not (collider is Node):
		return {}

	var brushable := GodotASketchBrushable.find_brushable_ancestor(collider as Node)
	if brushable == null:
		return {}

	result["brushable_node"] = brushable
	return result
