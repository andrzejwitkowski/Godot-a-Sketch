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
		_display.mouse_filter = MOUSE_FILTER_PASS
		_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_display.stretch_mode = TextureRect.STRETCH_SCALE
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
	var local := get_local_mouse_position()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var uv := _local_to_uv(local)
			if uv.x < 0.0:
				return
			_dragging = true
			_last_uv = uv
			stroke_begin.emit()
			stroke_uv.emit(Vector2(-1.0, -1.0), uv)
			accept_event()
		elif _dragging:
			_cancel_drag()
			stroke_end.emit()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var uv := _local_to_uv(local)
		if uv.x < 0.0:
			return
		stroke_uv.emit(_last_uv, uv)
		_last_uv = uv
		accept_event()


func _cancel_drag() -> void:
	_dragging = false
	_last_uv = Vector2(-1.0, -1.0)


func _local_to_uv(local: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	if local.x < 0.0 or local.y < 0.0 or local.x > size.x or local.y > size.y:
		return Vector2(-1.0, -1.0)
	return Vector2(local.x / size.x, local.y / size.y)
