@tool
extends Control
class_name GodotASketchSplatCanvas

signal stroke_begin
signal stroke_uv(from_uv: Vector2, to_uv: Vector2)
signal stroke_end

@onready var _display: TextureRect = $Display

var _editable := false
var _dragging := false
var _last_uv := Vector2(-1.0, -1.0)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if _display:
		_display.mouse_filter = MOUSE_FILTER_IGNORE
		_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_editable(enabled: bool) -> void:
	if not enabled and _dragging:
		_cancel_drag()
		stroke_end.emit()
	_editable = enabled
	mouse_filter = MOUSE_FILTER_STOP if enabled else MOUSE_FILTER_IGNORE


func set_preview_texture(tex: Texture2D) -> void:
	if _display:
		_display.texture = tex


func _gui_input(event: InputEvent) -> void:
	if not _editable:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var uv := _local_to_uv(mb.position)
			if uv.x < 0.0:
				return
			_dragging = true
			_last_uv = uv
			stroke_begin.emit()
			stroke_uv.emit(Vector2(-1.0, -1.0), uv)
		elif _dragging:
			_cancel_drag()
			stroke_end.emit()
	elif event is InputEventMouseMotion and _dragging:
		var uv := _local_to_uv(event.position)
		if uv.x < 0.0:
			return
		stroke_uv.emit(_last_uv, uv)
		_last_uv = uv


func _cancel_drag() -> void:
	_dragging = false
	_last_uv = Vector2(-1.0, -1.0)


func _local_to_uv(local: Vector2) -> Vector2:
	var rect_size := size
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var tex := _display.texture as Texture2D
	var tex_size := tex.get_size() if tex else Vector2.ONE
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var scale := minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var draw_size := tex_size * scale
	var offset := (rect_size - draw_size) * 0.5
	var rel := local - offset
	if rel.x < 0.0 or rel.y < 0.0 or rel.x > draw_size.x or rel.y > draw_size.y:
		return Vector2(-1.0, -1.0)
	return Vector2(rel.x / draw_size.x, rel.y / draw_size.y)
