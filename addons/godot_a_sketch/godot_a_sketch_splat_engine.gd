extends RefCounted
class_name GodotASketchSplatEngine


static func stamp(
	map: GodotASketchSplatMap,
	uv: Vector2,
	radius: float,
	strength: float,
	hardness: float,
	channel: int,
	blend_mode: int,
	erase: bool = false
) -> void:
	if map == null or map.image == null:
		return
	var img := map.image
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
	var rw := x1 - x0 + 1
	var rh := y1 - y0 + 1
	var ch := clampi(channel, 0, 3)
	var region_img := img.get_region(Rect2i(x0, y0, rw, rh))
	var data: PackedByteArray = region_img.get_data()
	for ly in range(rh):
		var gy := y0 + ly
		var v_norm := (float(gy) + 0.5) / float(h)
		for lx in range(rw):
			var gx := x0 + lx
			var u_norm := (float(gx) + 0.5) / float(w)
			var dist := Vector2(u_norm - uv.x, v_norm - uv.y).length() * float(w)
			var brush := 1.0 - smoothstep(inner, r_px, dist)
			brush *= strength
			if brush <= 0.0001:
				continue
			var idx := (ly * rw + lx) * 4
			var old_val := float(data[idx + ch]) / 255.0
			var new_val := old_val
			if erase:
				new_val = lerpf(old_val, 0.0, brush)
			elif blend_mode == 0:
				new_val = lerpf(old_val, 1.0, brush)
			elif blend_mode == 1:
				new_val = minf(1.0, old_val + brush)
			else:
				new_val = old_val + (1.0 - old_val) * brush
			data[idx + ch] = clampi(int(round(new_val * 255.0)), 0, 255)
	region_img.set_data(rw, rh, false, Image.FORMAT_RGBA8, data)
	img.blit_rect(region_img, Rect2i(0, 0, rw, rh), Vector2i(x0, y0))
	map.patch_preview_from_stamp(x0, y0, x1, y1)
	map.preview_texture(channel)
