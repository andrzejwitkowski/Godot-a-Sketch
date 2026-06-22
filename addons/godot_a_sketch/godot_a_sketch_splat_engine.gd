extends RefCounted
class_name GodotASketchSplatEngine

var _map: GodotASketchSplatMap
var _preview_tex: ImageTexture
var _painting := false


func open(map) -> void:
	ensure_open(map)


func ensure_open(map) -> void:
	if map == null:
		return
	if _map == map and _preview_tex != null:
		return
	_bind_map(map)


func begin_paint() -> void:
	_painting = true


func end_paint() -> void:
	_painting = false
	sync_preview()


func is_painting() -> bool:
	return _painting


func get_map():
	return _map


func stamp(
	uv: Vector2,
	radius: float,
	strength: float,
	hardness: float,
	channel: int,
	blend_mode: int
) -> void:
	if _map == null or _map.image == null:
		return
	_paint_stamp(_map.image, uv, radius, strength, hardness, channel, blend_mode)


func sync_preview() -> void:
	if _map == null or _map.image == null:
		return
	_map.ensure_rgba8()
	var display: ImageTexture = _map.to_preview_texture()
	if display == null:
		return
	_preview_tex = display


func get_texture() -> Texture2D:
	return _preview_tex


func _bind_map(map) -> void:
	_map = map
	_preview_tex = map.to_texture()


func _paint_stamp(
	img: Image,
	uv: Vector2,
	radius: float,
	strength: float,
	hardness: float,
	channel: int,
	blend_mode: int
) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w < 1 or h < 1:
		return
	var cx := uv.x * float(w)
	var cy := uv.y * float(h)
	var r_px := maxf(radius * float(w), 1.0)
	var inner := r_px * (1.0 - hardness * 0.99)
	var x0 := clampi(int(floor(cx - r_px)), 0, w - 1)
	var x1 := clampi(int(ceil(cx + r_px)), 0, w - 1)
	var y0 := clampi(int(floor(cy - r_px)), 0, h - 1)
	var y1 := clampi(int(ceil(cy + r_px)), 0, h - 1)
	var ch := clampi(channel, 0, 3)
	for y in range(y0, y1 + 1):
		var v := (float(y) + 0.5) / float(h)
		for x in range(x0, x1 + 1):
			var u := (float(x) + 0.5) / float(w)
			var dist := Vector2(u - uv.x, v - uv.y).length() * float(w)
			var brush := 1.0 - smoothstep(inner, r_px, dist)
			brush *= strength
			if brush <= 0.0001:
				continue
			var old: Color = img.get_pixel(x, y)
			var channels := [old.r, old.g, old.b, old.a]
			var old_val: float = channels[ch]
			var new_val := old_val
			if blend_mode == 0:
				new_val = lerpf(old_val, 1.0, brush)
			elif blend_mode == 1:
				new_val = minf(1.0, old_val + brush)
			else:
				new_val = old_val + (1.0 - old_val) * brush
			channels[ch] = new_val
			img.set_pixel(x, y, Color(channels[0], channels[1], channels[2], channels[3]))
