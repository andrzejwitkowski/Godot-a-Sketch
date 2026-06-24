shader_type spatial;
render_mode blend_sub, cull_back;

#include "res://addons/godot_a_sketch/shaders/layer_common.gdshaderinc"

varying vec2 v_uv;

void vertex() {
	v_uv = UV * uv_scale + uv_offset;
}

void fragment() {
	float w = godot_a_sketch_mask_weight(UV);
	ALBEDO = texture(layer_albedo, v_uv).rgb * w;
}
