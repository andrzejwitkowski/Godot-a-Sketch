shader_type spatial;

#include "res://addons/godot_a_sketch/shaders/layer_common.gdshaderinc"

varying vec3 v_normal;
varying vec2 v_uv;

void vertex() {
	v_uv = UV * uv_scale + uv_offset;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 mask = texture(splat_mask, UV);
	float channel = mask_channel == 0 ? mask.r
		: mask_channel == 1 ? mask.g
		: mask_channel == 2 ? mask.b
		: mask.a;
	vec3 albedo = texture(layer_albedo, v_uv).rgb;
	ALBEDO = albedo;
	ALPHA = channel * layer_weight;
}
