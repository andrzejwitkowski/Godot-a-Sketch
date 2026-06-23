// Godot-a-Sketch paint layer contract (#5). Include from layer .gdshader files.

#ifndef GODOT_A_SKETCH_LAYER_COMMON
#define GODOT_A_SKETCH_LAYER_COMMON

uniform sampler2D splat_mask : hint_default_white;
uniform int mask_channel = 0;
uniform float layer_weight = 1.0;
uniform sampler2D layer_albedo : hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

float godot_a_sketch_mask_weight(vec2 uv) {
	vec4 mask = texture(splat_mask, uv);
	float ch = mask.r;
	if (mask_channel == 1) {
		ch = mask.g;
	} else if (mask_channel == 2) {
		ch = mask.b;
	} else if (mask_channel == 3) {
		ch = mask.a;
	}
	return clamp(ch * layer_weight, 0.0, 1.0);
}

#endif
