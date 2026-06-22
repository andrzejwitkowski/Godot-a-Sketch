extends RefCounted
class_name GodotASketchRaycast

const Brushable := preload("res://addons/godot_a_sketch/godot_a_sketch_brushable.gd")
const MeshUV := preload("res://addons/godot_a_sketch/godot_a_sketch_mesh_uv.gd")
const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")


static func cast_from_camera(camera: Camera3D, screen_pos: Vector2, scene_root: Node) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var end: Vector3 = origin + direction * Constants.RAY_LENGTH

	var hit: Dictionary = _physics_cast(origin, end, camera, scene_root, Constants.PAINT_COLLISION_MASK)
	if hit.is_empty():
		hit = _physics_cast(origin, end, camera, scene_root, 0x7FFFFFFF)
	if hit.is_empty():
		hit = _mesh_cast(origin, direction, scene_root, Constants.RAY_LENGTH)
	return hit


static func cast_for_paint(camera: Camera3D, screen_pos: Vector2, scene_root: Node) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var hit := _mesh_cast(origin, direction, scene_root, Constants.RAY_LENGTH, true)
	if not hit.is_empty():
		return _finalize_paint_hit(hit, origin, direction)
	hit = cast_from_camera(camera, screen_pos, scene_root)
	if hit.is_empty():
		return {}
	return _finalize_paint_hit(hit, origin, direction)


static func mesh_for_paint(hit: Dictionary) -> MeshInstance3D:
	if hit.is_empty():
		return null
	var mesh: MeshInstance3D = hit.get("mesh_instance")
	if mesh and mesh.mesh:
		return mesh
	var brushable: Node3D = hit.get("brushable_node")
	if brushable:
		mesh = Brushable.resolve_mesh(brushable)
		if mesh and mesh.mesh:
			return mesh
	var collider: Node = hit.get("collider")
	if collider:
		var from_collider := Brushable.find_brushable_for_collider(collider)
		if from_collider:
			mesh = Brushable.resolve_mesh(from_collider)
			if mesh and mesh.mesh:
				return mesh
	return null


static func _finalize_paint_hit(hit: Dictionary, ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	if hit.has("uv"):
		var mesh: MeshInstance3D = hit.get("mesh_instance")
		if mesh:
			hit["brushable_node"] = mesh
		return hit
	var mesh := mesh_for_paint(hit)
	if mesh == null:
		return {}
	var xf_inv: Transform3D = mesh.global_transform.affine_inverse()
	var local_o: Vector3 = xf_inv * ray_origin
	var local_d: Vector3 = (xf_inv.basis * ray_direction).normalized()
	var uv_info := MeshUV.resolve_uv_ray(mesh, local_o, local_d)
	hit["mesh_instance"] = mesh
	hit["brushable_node"] = mesh
	hit["uv"] = uv_info.uv
	if uv_info.planar:
		hit["uv_planar_fallback"] = true
	return hit


static func _physics_cast(
	origin: Vector3,
	end: Vector3,
	camera: Camera3D,
	scene_root: Node,
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
	scene_root: Node,
	max_distance: float,
	with_uv: bool = false
) -> Dictionary:
	var best_distance: float = max_distance
	var best_hit: Dictionary = {}

	for node in scene_root.find_children("*", "MeshInstance3D", true, false):
		if not Brushable.is_brushable(node):
			continue
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
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
		var face_index: int = int(local_hit.get("face_index", -1))
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
			"mesh_instance": mesh_instance,
			"face_index": face_index,
		}
		if with_uv:
			var uv := MeshUV.hit_uv(mesh_instance, face_index, local_position, local_normal)
			best_hit["uv"] = uv
			if not MeshUV.has_mesh_uvs(mesh_instance) or face_index < 0:
				best_hit["uv_planar_fallback"] = true

	return best_hit


static func _with_brushable(result: Dictionary) -> Dictionary:
	var collider: Object = result.get("collider")
	if collider == null or not (collider is Node):
		return {}

	var brushable: Node3D = Brushable.find_brushable_for_collider(collider as Node)
	if brushable == null:
		return {}

	result["brushable_node"] = brushable
	return result
