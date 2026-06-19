shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_test_disabled;

uniform vec4 brush_color : source_color = vec4(0.2, 0.6, 1.0, 0.5);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float hardness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float dist = length(UV * 2.0 - 1.0);
	float alpha = 1.0 - smoothstep(mix(0.0, 0.99, hardness), 1.0, dist);
	ALBEDO = brush_color.rgb;
	ALPHA = alpha * opacity * brush_color.a;
}
