extends RefCounted
class_name GodotASketchConstants

const PAINT_LAYER := 20
const PAINT_COLLISION_MASK := 1 << 19
const BRUSHABLE_META := "godot_a_sketch_brushable"
const BRUSHABLE_GROUP := "godot_a_sketch_brushable"
const TRIANGLE_MESH_META := "godot_a_sketch_triangle_mesh"
const AUTO_BODY_NAME := "_GodotASketchBody"
const AUTO_BODY_META := "godot_a_sketch_auto_body"
const SETTINGS_MODIFIER_KEY := "godot_a_sketch/input/modifier_key"
const MODIFIER_NONE := 0
const DEFAULT_MODIFIER_MASK := MODIFIER_NONE
const RAY_LENGTH := 10000.0

const GHOST_NODE_NAME := "_GodotASketchGhost"
const SETTINGS_SHOW_GHOST := "godot_a_sketch/ghost/enabled"
const SETTINGS_TOOL_ACTIVE := "godot_a_sketch/input/tool_active"
const SETTINGS_BRUSH_MODE := "godot_a_sketch/brush/mode"
const DEFAULT_SHOW_GHOST := true
const DEFAULT_TOOL_ACTIVE := false

enum BrushMode { PAINT, SCULPT }

const COLOR_PAINT := Color(0.2, 0.6, 1.0, 0.5)
const COLOR_SCULPT := Color(1.0, 0.55, 0.15, 0.5)

const SHADER_STACK_META := "godot_a_sketch_shader_stack_path"
const SHADER_STACK_DEFAULT_DIR := "res://godot_a_sketch_stacks/"
const BUNDLED_SHADER_DIR := "res://addons/godot_a_sketch/shaders/"
const LAYER_TEMPLATE_PATH := "res://addons/godot_a_sketch/shaders/layer_template.gdshader"

const SPLAT_MAP_META := "godot_a_sketch_splat_map_path"
const SPLAT_MAP_DEFAULT_DIR := "res://godot_a_sketch_splats/"
const SETTINGS_SPLAT_SIZE := "godot_a_sketch/splat/default_size"
const DEFAULT_SPLAT_SIZE := 1024
const MESH_UV_META := "godot_a_sketch_mesh_uv_cache"
const BASE_OVERRIDE_META := "godot_a_sketch_base_material_override"


static func paint_target_slug(target: Node3D) -> String:
	if target == null:
		return "unknown_mesh"
	var scene_root := EditorInterface.get_edited_scene_root()
	var scene_name := _scene_file_slug(scene_root)
	if scene_root == null:
		return "%s__%s_%d" % [scene_name, String(target.name).validate_filename(), target.get_instance_id()]
	if target == scene_root:
		return "%s__%s" % [scene_name, String(target.name).validate_filename()]
	var parts: PackedStringArray = []
	var node: Node = target
	while node and node != scene_root:
		parts.append(_safe_node_name(node.name))
		node = node.get_parent()
	if node != scene_root:
		return "%s__%s_%d" % [scene_name, String(target.name).validate_filename(), target.get_instance_id()]
	parts.reverse()
	return "%s__%s" % [scene_name, "_".join(parts)]


static func _scene_file_slug(scene_root: Node) -> String:
	if scene_root == null:
		return "scene"
	var scene_path := scene_root.scene_file_path
	if not scene_path.is_empty():
		return scene_path.get_file().get_basename()
	return String(scene_root.name).validate_filename()


static func _safe_node_name(node_name: StringName) -> String:
	var s := String(node_name).validate_filename()
	return s if not s.is_empty() else "node"


static func is_usable_resource_path(path: String) -> bool:
	if path.is_empty() or not path.begins_with("res://"):
		return false
	if path.length() > 180:
		return false
	return not path.contains("@")
