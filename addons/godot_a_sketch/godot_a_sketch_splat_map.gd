@tool
extends Resource
class_name GodotASketchSplatMap

@export var size: Vector2i = Vector2i(1024, 1024)
@export var image: Image


static func create_default(resolution: int = 1024) -> GodotASketchSplatMap:
	var map := GodotASketchSplatMap.new()
	map.size = Vector2i(resolution, resolution)
	map.image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	map.image.fill(Color.BLACK)
	return map


func to_texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)


const PREVIEW_SIZE := 256


func to_preview_texture(channel: int = -1) -> ImageTexture:
	if image == null or image.is_empty():
		return null
	ensure_rgba8()
	var vis: Image = image.duplicate()
	if vis.get_width() > PREVIEW_SIZE:
		vis.resize(PREVIEW_SIZE, PREVIEW_SIZE, Image.INTERPOLATE_NEAREST)
	var w: int = vis.get_width()
	var h: int = vis.get_height()
	for y in range(h):
		for x in range(w):
			var c: Color = vis.get_pixel(x, y)
			var v: float
			if channel < 0:
				v = maxf(maxf(c.r, c.g), c.b)
			else:
				var comps := [c.r, c.g, c.b, c.a]
				v = comps[clampi(channel, 0, 3)]
			vis.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(vis)


func ensure_rgba8() -> void:
	if image == null:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)


func duplicate_map() -> GodotASketchSplatMap:
	return duplicate(true) as GodotASketchSplatMap
