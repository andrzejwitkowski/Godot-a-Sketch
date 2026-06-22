// Godot-a-Sketch paint layer contract (#5). Include from layer .gdshader files.

#ifndef GODOT_A_SKETCH_LAYER_COMMON
#define GODOT_A_SKETCH_LAYER_COMMON

uniform sampler2D splat_mask : hint_default_white;
uniform int mask_channel = 0;
uniform float layer_weight = 1.0;
uniform sampler2D layer_albedo : hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

#endif
