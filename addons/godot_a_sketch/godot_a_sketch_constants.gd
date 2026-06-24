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
const DEFAULT_MODIFIER_MASK := KEY_MASK_ALT
const RAY_LENGTH := 10000.0

const GHOST_NODE_NAME := "_GodotASketchGhost"
const SETTINGS_SHOW_GHOST := "godot_a_sketch/ghost/enabled"
const SETTINGS_TOOL_ACTIVE := "godot_a_sketch/input/tool_active"
const SETTINGS_BRUSH_MODE := "godot_a_sketch/brush/mode"
const DEFAULT_SHOW_GHOST := true
const DEFAULT_TOOL_ACTIVE := false

enum BrushMode { PAINT, ERASE }

const COLOR_PAINT := Color(0.2, 0.6, 1.0, 0.5)
const COLOR_ERASE := Color(1.0, 0.55, 0.15, 0.5)

const SHADER_STACK_META := "godot_a_sketch_shader_stack_path"
const SHADER_STACK_DEFAULT_DIR := "res://godot_a_sketch_stacks/"
const BUNDLED_SHADER_DIR := "res://addons/godot_a_sketch/shaders/"
const LAYER_TEMPLATE_PATH := "res://addons/godot_a_sketch/shaders/layer_template.gdshader"
const STACK_PASS_MIX := "res://addons/godot_a_sketch/shaders/stack_pass_mix.gdshader"
const STACK_PASS_ADD := "res://addons/godot_a_sketch/shaders/stack_pass_add.gdshader"
const STACK_PASS_MUL := "res://addons/godot_a_sketch/shaders/stack_pass_mul.gdshader"
const STACK_PASS_SUB := "res://addons/godot_a_sketch/shaders/stack_pass_sub.gdshader"

const SPLAT_MAP_META := "godot_a_sketch_splat_map_path"
const SPLAT_MAP_DEFAULT_DIR := "res://godot_a_sketch_splats/"
const SETTINGS_SPLAT_SIZE := "godot_a_sketch/splat/default_size"
const SPLAT_SIZE_OPTIONS := [64, 128, 256, 512, 1024]
const DEFAULT_SPLAT_SIZE := 256
const MESH_UV_META := "godot_a_sketch_mesh_uv_cache"
const BASE_OVERRIDE_META := "godot_a_sketch_base_material_override"


static func paint_target_slug(target: Node3D) -> String:
	return "%s__%s" % [scene_slug(target), mesh_slug(target)]


static func scene_slug(target: Node3D) -> String:
	return _scene_file_slug(_scene_root_for(target))


static func mesh_slug(target: Node3D) -> String:
	if target == null:
		return "unknown_mesh"
	var scene_root := _scene_root_for(target)
	if scene_root == null:
		return "%s_%d" % [String(target.name).validate_filename(), target.get_instance_id()]
	if target == scene_root:
		return _safe_node_name(target.name)
	var parts: PackedStringArray = []
	var node: Node = target
	while node and node != scene_root:
		parts.append(_safe_node_name(node.name))
		node = node.get_parent()
	if node != scene_root:
		return "%s_%d" % [String(target.name).validate_filename(), target.get_instance_id()]
	parts.reverse()
	return "_".join(parts)


static func splat_layer_dir(target: Node3D) -> String:
	return SPLAT_MAP_DEFAULT_DIR.path_join(scene_slug(target)).path_join(mesh_slug(target))


static func splat_layer_path(target: Node3D, layer_index: int) -> String:
	return splat_layer_dir(target).path_join("layer_%d.tres" % layer_index)


static func _scene_root_for(target: Node3D) -> Node:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root != null:
		return scene_root
	if target != null and target.is_inside_tree():
		return target.get_tree().edited_scene_root
	return null


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
