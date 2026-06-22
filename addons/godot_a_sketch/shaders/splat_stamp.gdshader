shader_type canvas_item;

uniform sampler2D mask_tex;
uniform vec2 brush_uv = vec2(-1.0);
uniform float radius = 0.05;
uniform float strength = 1.0;
uniform float hardness = 0.5;
uniform int channel = 0;
uniform int blend_mode = 0;

void fragment() {
	vec4 mask = texture(mask_tex, UV);
	float dist = length(UV - brush_uv);
	float brush = 1.0 - smoothstep(mix(0.0, radius * (1.0 - hardness * 0.99), radius), radius, dist);
	brush *= strength;

	vec4 out_mask = mask;
	float channels[4];
	channels[0] = mask.r;
	channels[1] = mask.g;
	channels[2] = mask.b;
	channels[3] = mask.a;

	float old_val = channels[channel];
	float new_val = old_val;
	if (blend_mode == 0) {
		new_val = mix(old_val, 1.0, brush);
	} else if (blend_mode == 1) {
		new_val = min(1.0, old_val + brush);
	} else {
		new_val = old_val + (1.0 - old_val) * brush;
	}
	channels[channel] = new_val;

	out_mask = vec4(channels[0], channels[1], channels[2], channels[3]);
	COLOR = out_mask;
}
