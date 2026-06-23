extends RefCounted
class_name GodotASketchMeshUV

const Constants := preload("res://addons/godot_a_sketch/godot_a_sketch_constants.gd")
const EPS := 0.0005


static func cache(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var triangle_mesh: TriangleMesh = _triangle_mesh_for(mesh_instance)
	if triangle_mesh == null:
		mesh_instance.set_meta(Constants.MESH_UV_META, [])
		return
	var faces: PackedVector3Array = triangle_mesh.get_faces()
	var mesh: Mesh = mesh_instance.mesh
	var face_uvs: Array = []
	for fi in range(faces.size() / 3):
		var a: Vector3 = faces[fi * 3]
		var b: Vector3 = faces[fi * 3 + 1]
		var c: Vector3 = faces[fi * 3 + 2]
		var tri_uv := _find_uvs_for_triangle(mesh, a, b, c)
		face_uvs.append(tri_uv)
	mesh_instance.set_meta(Constants.MESH_UV_META, face_uvs)


static func clear(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance and mesh_instance.has_meta(Constants.MESH_UV_META):
		mesh_instance.remove_meta(Constants.MESH_UV_META)


static func hit_uv(
	mesh_instance: MeshInstance3D,
	face_index: int,
	local_position: Vector3,
	local_normal: Vector3 = Vector3.UP
) -> Vector2:
	if mesh_instance == null:
		return Vector2(-1, -1)
	if face_index >= 0:
		var triangle_mesh: TriangleMesh = _triangle_mesh_for(mesh_instance)
		if triangle_mesh == null:
			return _planar_uv(mesh_instance, local_position, local_normal)
		var expected_faces: int = triangle_mesh.get_faces().size() / 3
		if not mesh_instance.has_meta(Constants.MESH_UV_META):
			cache(mesh_instance)
		var face_uvs: Array = mesh_instance.get_meta(Constants.MESH_UV_META)
		if face_uvs.size() != expected_faces:
			cache(mesh_instance)
			face_uvs = mesh_instance.get_meta(Constants.MESH_UV_META)
		if face_index < face_uvs.size():
			var tri_uvs: PackedVector2Array = face_uvs[face_index]
			if tri_uvs.size() == 3:
				var faces := triangle_mesh.get_faces()
				var tri_start := face_index * 3
				if tri_start + 2 < faces.size():
					var a: Vector3 = faces[tri_start]
					var b: Vector3 = faces[tri_start + 1]
					var c: Vector3 = faces[tri_start + 2]
					var bary := Geometry3D.get_triangle_barycentric_coords(local_position, a, b, c)
					return tri_uvs[0] * bary.x + tri_uvs[1] * bary.y + tri_uvs[2] * bary.z
	return _planar_uv(mesh_instance, local_position, local_normal)


static func resolve_uv(mesh_instance: MeshInstance3D, local_pos: Vector3, local_normal: Vector3) -> Dictionary:
	var face_index := -1
	var at := local_pos
	var n := local_normal.normalized()
	if n.is_zero_approx():
		n = Vector3.UP
	var triangle_mesh: TriangleMesh = _triangle_mesh_for(mesh_instance)
	if triangle_mesh != null:
		var probe := 0.05
		if mesh_instance.mesh != null:
			probe = maxf(probe, mesh_instance.mesh.get_aabb().size.length() * 0.002)
		var seg := triangle_mesh.intersect_segment(local_pos - n * probe, local_pos + n * probe)
		if seg.is_empty():
			seg = triangle_mesh.intersect_segment(local_pos - n * probe * 8.0, local_pos + n * probe * 8.0)
		if not seg.is_empty():
			face_index = int(seg.get("face_index", -1))
			at = seg.get("position", local_pos)
			n = seg.get("normal", n)
	var uv := hit_uv(mesh_instance, face_index, at, n)
	return {"uv": uv, "planar": not has_mesh_uvs(mesh_instance) or face_index < 0}


static func resolve_uv_ray(
	mesh_instance: MeshInstance3D,
	local_origin: Vector3,
	local_direction: Vector3
) -> Dictionary:
	var face_index := -1
	var at := local_origin
	var local_normal := Vector3.UP
	var triangle_mesh: TriangleMesh = _triangle_mesh_for(mesh_instance)
	if triangle_mesh != null:
		var dir := local_direction.normalized()
		if dir.is_zero_approx():
			return resolve_uv(mesh_instance, local_origin, Vector3.UP)
		var seg := triangle_mesh.intersect_segment(local_origin, local_origin + dir * 1000.0)
		if not seg.is_empty():
			face_index = int(seg.get("face_index", -1))
			at = seg.get("position", local_origin)
			local_normal = seg.get("normal", Vector3.UP)
	var uv := hit_uv(mesh_instance, face_index, at, local_normal)
	return {"uv": uv, "planar": not has_mesh_uvs(mesh_instance) or face_index < 0}


static func has_mesh_uvs(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or not mesh_instance.has_meta(Constants.MESH_UV_META):
		return false
	for tri_uvs in mesh_instance.get_meta(Constants.MESH_UV_META) as Array:
		if (tri_uvs as PackedVector2Array).size() == 3:
			return true
	return false


static func _find_uvs_for_triangle(mesh: Mesh, a: Vector3, b: Vector3, c: Vector3) -> PackedVector2Array:
	for surface_idx in mesh.get_surface_count():
		var st := mesh.surface_get_arrays(surface_idx)
		var verts: PackedVector3Array = st[Mesh.ARRAY_VERTEX]
		var uvs := _pick_uv_array(st)
		if uvs.is_empty():
			continue
		var indices: PackedInt32Array = st[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(0, verts.size(), 3):
				if i + 2 >= verts.size():
					break
				if _triangle_match(verts[i], verts[i + 1], verts[i + 2], a, b, c):
					return PackedVector2Array([uvs[i], uvs[i + 1], uvs[i + 2]])
		else:
			for i in range(0, indices.size(), 3):
				if i + 2 >= indices.size():
					break
				var ia := indices[i]
				var ib := indices[i + 1]
				var ic := indices[i + 2]
				if ia >= verts.size() or ib >= verts.size() or ic >= verts.size():
					continue
				if _triangle_match(verts[ia], verts[ib], verts[ic], a, b, c):
					if ia >= uvs.size() or ib >= uvs.size() or ic >= uvs.size():
						continue
					return PackedVector2Array([uvs[ia], uvs[ib], uvs[ic]])
	return PackedVector2Array()


static func _triangle_match(va: Vector3, vb: Vector3, vc: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	return (
		(_near(va, a) and _near(vb, b) and _near(vc, c))
		or (_near(va, a) and _near(vb, c) and _near(vc, b))
		or (_near(va, b) and _near(vb, a) and _near(vc, c))
		or (_near(va, b) and _near(vb, c) and _near(vc, a))
		or (_near(va, c) and _near(vb, a) and _near(vc, b))
		or (_near(va, c) and _near(vb, b) and _near(vc, a))
	)


static func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_squared_to(b) <= EPS * EPS


static func _pick_uv_array(st: Array) -> PackedVector2Array:
	var uvs: PackedVector2Array = st[Mesh.ARRAY_TEX_UV]
	if not uvs.is_empty():
		return uvs
	return st[Mesh.ARRAY_TEX_UV2]


static func _planar_uv(mesh_instance: MeshInstance3D, local_pos: Vector3, local_normal: Vector3) -> Vector2:
	var aabb := mesh_instance.mesh.get_aabb()
	var size := aabb.size
	if size.length_squared() < 0.0001:
		return Vector2(0.5, 0.5)
	var p := local_pos - aabb.position
	var n := local_normal.abs()
	if n.y >= n.x and n.y >= n.z:
		return Vector2(_safe_ratio(p.x, size.x), _safe_ratio(p.z, size.z))
	if n.x >= n.z:
		return Vector2(_safe_ratio(p.z, size.z), _safe_ratio(p.y, size.y))
	return Vector2(_safe_ratio(p.x, size.x), _safe_ratio(p.y, size.y))


static func _safe_ratio(v: float, size: float) -> float:
	return clampf(v / size, 0.0, 1.0) if size > 0.0001 else 0.5


static func _triangle_mesh_for(mesh_instance: MeshInstance3D) -> TriangleMesh:
	if mesh_instance.has_meta(Constants.TRIANGLE_MESH_META):
		return mesh_instance.get_meta(Constants.TRIANGLE_MESH_META)
	if mesh_instance.mesh == null:
		return null
	var triangle_mesh: TriangleMesh = mesh_instance.mesh.generate_triangle_mesh()
	if triangle_mesh:
		mesh_instance.set_meta(Constants.TRIANGLE_MESH_META, triangle_mesh)
	return triangle_mesh
