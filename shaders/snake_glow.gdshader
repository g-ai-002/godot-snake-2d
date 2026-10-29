shader_type canvas_item;
render_mode blend_add, unshaded;

// 蛇身外辉光：加法混合的柔边光晕，配合全屏 Bloom 形成霓虹灯管效果。

uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.75, 1.0);
uniform float strength = 0.45;
uniform float energy = 0.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float halo = pow(max(0.0, 1.0 - across), 2.4);
	float pulse = 0.78 + 0.22 * sin(TIME * 3.0 - UV.x * 16.0);

	vec3 col = glow_color.rgb * (strength + energy * 0.55) * pulse;
	COLOR = vec4(col, halo * COLOR.a);
}
