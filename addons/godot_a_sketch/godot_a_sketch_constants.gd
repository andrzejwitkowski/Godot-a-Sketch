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
const SETTINGS_BRUSH_MODE := "godot_a_sketch/brush/mode"
const DEFAULT_SHOW_GHOST := true

enum BrushMode { PAINT, SCULPT }

const COLOR_PAINT := Color(0.2, 0.6, 1.0, 0.5)
const COLOR_SCULPT := Color(1.0, 0.55, 0.15, 0.5)
