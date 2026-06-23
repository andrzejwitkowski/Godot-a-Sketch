extends Node

const Brushable := preload("res://addons/godot_a_sketch/godot_a_sketch_brushable.gd")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_rebuild_brushable_materials")


func _rebuild_brushable_materials() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root:
		_visit(root)


func _visit(node: Node) -> void:
	if (node is MeshInstance3D or node is MultiMeshInstance3D) and Brushable.is_brushable(node):
		if Brushable.has_viewport_stack(node):
			Brushable.rebuild_material_stack(node)
	for child in node.get_children():
		_visit(child)
