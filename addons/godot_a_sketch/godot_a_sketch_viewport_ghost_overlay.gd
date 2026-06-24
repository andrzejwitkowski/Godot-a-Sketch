@tool
extends Control

var ring_center := Vector2(-1.0, -1.0)
var ring_radius := 0.0
var ring_color := Color(0.2, 0.6, 1.0, 0.55)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100


func clear_ring() -> void:
	ring_center = Vector2(-1.0, -1.0)
	ring_radius = 0.0
	queue_redraw()


func set_ring(center: Vector2, radius: float, color: Color) -> void:
	ring_center = center
	ring_radius = maxf(radius, 4.0)
	ring_color = color
	queue_redraw()


func _draw() -> void:
	if ring_center.x < 0.0 or ring_radius <= 0.0:
		return
	draw_circle(ring_center, ring_radius, ring_color)
	draw_arc(ring_center, ring_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.85), 2.0, true)
