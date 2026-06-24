shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform vec4 brush_color : source_color = vec4(0.2, 0.6, 1.0, 0.65);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float hardness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);
	float fill = 1.0 - smoothstep(mix(0.0, 0.98, hardness), 1.0, dist);
	float ring = smoothstep(0.94, 0.90, dist) * (1.0 - smoothstep(0.90, 0.86, dist));
	vec3 rgb = mix(brush_color.rgb, vec3(1.0), ring * 0.75);
	float alpha = max(fill * opacity * brush_color.a, ring * opacity * 0.95);
	ALBEDO = rgb;
	ALPHA = alpha;
}
