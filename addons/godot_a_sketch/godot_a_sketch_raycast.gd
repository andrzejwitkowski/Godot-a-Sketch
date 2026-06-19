extends RefCounted
class_name GodotASketchRaycast

const Brushable := preload("res://addons/godot_a_sketch/godot_a_sketch_brushable.gd")
const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")


static func cast_from_camera(camera: Camera3D, screen_pos: Vector2, scene_root: Node3D) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var end: Vector3 = origin + direction * Constants.RAY_LENGTH

	var hit: Dictionary = _physics_cast(origin, end, camera, scene_root, Constants.PAINT_COLLISION_MASK)
	if hit.is_empty():
		hit = _physics_cast(origin, end, camera, scene_root, 0x7FFFFFFF)
	if hit.is_empty():
		hit = _mesh_cast(origin, direction, scene_root, Constants.RAY_LENGTH)
	return hit


static func _physics_cast(
	origin: Vector3,
	end: Vector3,
	camera: Camera3D,
	scene_root: Node3D,
	collision_mask: int
) -> Dictionary:
	var world: World3D = camera.get_world_3d()
	if world == null:
		world = scene_root.get_world_3d()
	if world == null:
		return {}

	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		return {}

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.hit_back_faces = true
	query.hit_from_inside = true

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return {}

	return _with_brushable(result)


static func _mesh_cast(
	origin: Vector3,
	direction: Vector3,
	scene_root: Node3D,
	max_distance: float
) -> Dictionary:
	var best_distance: float = max_distance
	var best_hit: Dictionary = {}

	for node in scene_root.find_children("*", "MeshInstance3D", true, false):
		if not Brushable.is_brushable(node):
			continue
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var triangle_mesh: TriangleMesh = Brushable.triangle_mesh_for(mesh_instance)
		if triangle_mesh == null:
			continue

		var xf_inv: Transform3D = mesh_instance.global_transform.affine_inverse()
		var local_origin: Vector3 = xf_inv * origin
		var world_end: Vector3 = origin + direction * max_distance
		var local_end: Vector3 = xf_inv * world_end
		var local_hit: Dictionary = triangle_mesh.intersect_segment(local_origin, local_end)
		if local_hit.is_empty():
			continue

		var local_position: Vector3 = local_hit.get("position", Vector3.ZERO)
		var local_normal: Vector3 = local_hit.get("normal", Vector3.UP)
		var world_hit: Vector3 = mesh_instance.global_transform * local_position
		var distance: float = origin.distance_to(world_hit)
		if distance >= best_distance:
			continue

		var world_normal: Vector3 = (mesh_instance.global_transform.basis * local_normal).normalized()
		best_distance = distance
		best_hit = {
			"position": world_hit,
			"normal": world_normal,
			"collider": mesh_instance,
			"brushable_node": mesh_instance,
		}

	return best_hit


static func _with_brushable(result: Dictionary) -> Dictionary:
	var collider: Object = result.get("collider")
	if collider == null or not (collider is Node):
		return {}

	var brushable: Node3D = Brushable.find_brushable_ancestor(collider as Node)
	if brushable == null:
		return {}

	result["brushable_node"] = brushable
	return result
