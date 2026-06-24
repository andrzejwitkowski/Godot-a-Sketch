@tool
extends Resource
class_name GodotASketchSplatMap

@export var size: Vector2i = Vector2i(256, 256)
@export var image: Image

var _runtime_tex: ImageTexture
var _preview_tex: ImageTexture
var _preview_img: Image
var _preview_src: Image
var _preview_dirty := Rect2i()
var _preview_channel := -999


static func create_default(resolution: int = 256) -> GodotASketchSplatMap:
	var map := GodotASketchSplatMap.new()
	map.size = Vector2i(resolution, resolution)
	map.image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	map.image.fill(Color.BLACK)
	return map


static func from_channel(source: GodotASketchSplatMap, channel: int) -> GodotASketchSplatMap:
	var map := create_default(source.size.x)
	if source == null or source.image == null:
		return map
	source.ensure_rgba8()
	var ch := clampi(channel, 0, 3)
	var w := source.image.get_width()
	var h := source.image.get_height()
	var src: PackedByteArray = source.image.get_data()
	var dst: PackedByteArray = map.image.get_data()
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			var v := src[i + ch]
			dst[i] = v
			dst[i + 1] = 0
			dst[i + 2] = 0
			dst[i + 3] = 255
	map.image.set_data(w, h, false, Image.FORMAT_RGBA8, dst)
	map.invalidate_caches()
	return map


func invalidate_caches() -> void:
	_runtime_tex = null
	_preview_tex = null
	_preview_img = null
	_preview_src = null
	_preview_dirty = Rect2i()
	_preview_channel = -999


func to_texture() -> ImageTexture:
	return runtime_texture()


func runtime_texture() -> ImageTexture:
	if image == null:
		return null
	ensure_rgba8()
	if _runtime_tex == null:
		_runtime_tex = ImageTexture.create_from_image(image)
	else:
		_runtime_tex.update(image)
	return _runtime_tex


const PREVIEW_SIZE := 256


func to_preview_texture(channel: int = -1) -> ImageTexture:
	return preview_texture(channel)


func preview_texture(channel: int = -1) -> ImageTexture:
	if image == null or image.get_width() < 1 or image.get_height() < 1:
		return null
	ensure_rgba8()
	if _preview_img == null:
		_preview_img = Image.create(PREVIEW_SIZE, PREVIEW_SIZE, false, Image.FORMAT_RGBA8)
	if channel != _preview_channel:
		_preview_channel = channel
		_preview_dirty = Rect2i(0, 0, PREVIEW_SIZE, PREVIEW_SIZE)
	_sync_preview_channel(channel)
	if _preview_tex == null:
		_preview_tex = ImageTexture.create_from_image(_preview_img)
	else:
		_preview_tex.update(_preview_img)
	return _preview_tex


func prewarm(channel: int = -1) -> void:
	if image == null or image.get_width() < 1:
		return
	ensure_rgba8()
	sync_preview_from_image(channel)
	runtime_texture()


func sync_preview_from_image(channel: int = -1) -> void:
	if image == null or image.get_width() < 1:
		return
	ensure_rgba8()
	_preview_src = null
	_preview_dirty = Rect2i(0, 0, PREVIEW_SIZE, PREVIEW_SIZE)
	preview_texture(channel)


func patch_preview_from_stamp(x0: int, y0: int, x1: int, y1: int) -> void:
	if image == null:
		return
	_ensure_preview_src()
	if _preview_src == null:
		return
	var w := image.get_width()
	var h := image.get_height()
	if w < 1 or h < 1:
		return
	var scale_x := float(PREVIEW_SIZE) / float(w)
	var scale_y := float(PREVIEW_SIZE) / float(h)
	var px0 := clampi(int(floor(float(x0) * scale_x)), 0, PREVIEW_SIZE - 1)
	var py0 := clampi(int(floor(float(y0) * scale_y)), 0, PREVIEW_SIZE - 1)
	var px1 := clampi(int(ceil(float(x1 + 1) * scale_x)), px0 + 1, PREVIEW_SIZE)
	var py1 := clampi(int(ceil(float(y1 + 1) * scale_y)), py0 + 1, PREVIEW_SIZE)
	var rw := x1 - x0 + 1
	var rh := y1 - y0 + 1
	var patch := image.get_region(Rect2i(x0, y0, rw, rh))
	var ptw := px1 - px0
	var pth := py1 - py0
	if patch.get_width() != ptw or patch.get_height() != pth:
		patch.resize(ptw, pth, Image.INTERPOLATE_NEAREST)
	_preview_src.blit_rect(patch, Rect2i(0, 0, ptw, pth), Vector2i(px0, py0))
	_union_preview_dirty(px0, py0, px1, py1)


func _ensure_preview_src() -> void:
	if _preview_src != null:
		return
	if image == null:
		return
	_preview_src = image.duplicate()
	if _preview_src.get_width() != PREVIEW_SIZE or _preview_src.get_height() != PREVIEW_SIZE:
		_preview_src.resize(PREVIEW_SIZE, PREVIEW_SIZE, Image.INTERPOLATE_NEAREST)


func _union_preview_dirty(px0: int, py0: int, px1: int, py1: int) -> void:
	var patch := Rect2i(px0, py0, px1 - px0, py1 - py0)
	if _preview_dirty.size == Vector2i.ZERO:
		_preview_dirty = patch
		return
	var ox0 := _preview_dirty.position.x
	var oy0 := _preview_dirty.position.y
	var ox1 := ox0 + _preview_dirty.size.x
	var oy1 := oy0 + _preview_dirty.size.y
	var nx0 := mini(ox0, px0)
	var ny0 := mini(oy0, py0)
	var nx1 := maxi(ox1, px1)
	var ny1 := maxi(oy1, py1)
	_preview_dirty = Rect2i(nx0, ny0, nx1 - nx0, ny1 - ny0)


func _sync_preview_channel(channel: int) -> void:
	_ensure_preview_src()
	if _preview_src == null:
		return
	var src: PackedByteArray = _preview_src.get_data()
	if _preview_img == null:
		_preview_img = Image.create(PREVIEW_SIZE, PREVIEW_SIZE, false, Image.FORMAT_RGBA8)
	var dst: PackedByteArray = _preview_img.get_data()
	var ch := clampi(channel, 0, 3)
	var use_channel := channel >= 0
	var rect := _preview_dirty if _preview_dirty.size != Vector2i.ZERO else Rect2i(0, 0, PREVIEW_SIZE, PREVIEW_SIZE)
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.position.x + rect.size.x
	var y1 := rect.position.y + rect.size.y
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * PREVIEW_SIZE + x
			var src_base := i * 4
			var dst_base := i * 4
			var v: int
			if use_channel:
				v = src[src_base + ch]
			else:
				v = maxi(maxi(src[src_base], src[src_base + 1]), src[src_base + 2])
			dst[dst_base] = v
			dst[dst_base + 1] = v
			dst[dst_base + 2] = v
			dst[dst_base + 3] = 255
	_preview_img.set_data(PREVIEW_SIZE, PREVIEW_SIZE, false, Image.FORMAT_RGBA8, dst)
	_preview_dirty = Rect2i()


func ensure_rgba8() -> void:
	if image == null:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
		invalidate_caches()


func resize_to(resolution: int) -> void:
	resolution = maxi(resolution, 1)
	if image == null:
		image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
		image.fill(Color.BLACK)
	elif image.get_width() != resolution or image.get_height() != resolution:
		ensure_rgba8()
		image.resize(resolution, resolution, Image.INTERPOLATE_BILINEAR)
	size = Vector2i(resolution, resolution)
	invalidate_caches()


func duplicate_map() -> GodotASketchSplatMap:
	return duplicate(true) as GodotASketchSplatMap


static func self_check_from_channel() -> bool:
	var src := create_default(2)
	var data := src.image.get_data()
	data[0] = 10
	data[1] = 20
	data[2] = 30
	data[3] = 40
	data[4] = 50
	data[5] = 60
	data[6] = 70
	data[7] = 80
	src.image.set_data(2, 2, false, Image.FORMAT_RGBA8, data)
	var g := from_channel(src, 1)
	var out := g.image.get_data()
	return out[0] == 20 and out[1] == 0 and out[4] == 60 and out[5] == 0


static func self_check_resize() -> bool:
	var map := create_default(4)
	var data := map.image.get_data()
	data[0] = 255
	map.image.set_data(4, 4, false, Image.FORMAT_RGBA8, data)
	map.resize_to(2)
	return map.size == Vector2i(2, 2) and map.image.get_pixel(0, 0).r > 0.9
