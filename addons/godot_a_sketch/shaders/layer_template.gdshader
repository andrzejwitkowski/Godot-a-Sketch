shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://addons/godot_a_sketch/shaders/layer_common.gdshaderinc"

varying vec3 v_normal;
varying vec2 v_uv;

void vertex() {
	v_uv = UV * uv_scale + uv_offset;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float channel = godot_a_sketch_mask_weight(UV);
	vec3 albedo = texture(layer_albedo, v_uv).rgb;
	ALBEDO = albedo;
	ALPHA = channel;
}
