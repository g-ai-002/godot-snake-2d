shader_type canvas_item;

// 蛇身主体：管状明暗 + 鳞纹 + 沿身体流动的能量脉冲 + 边缘轮廓光。
// Line2D 的 UV.x 沿长度方向，UV.y 横跨宽度，正好用来做圆管与流动效果。

uniform vec4 rim_color : source_color = vec4(0.85, 1.0, 0.95, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.24, 0.65, 1.0);
uniform float stripe_strength = 0.2;
uniform float rim_strength = 0.6;
uniform float flow_speed = 0.3;
uniform float energy = 0.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float tube = 1.0 - smoothstep(0.0, 1.0, across);

	vec3 col = COLOR.rgb * (0.52 + 0.8 * tube);

	// 鳞片：横向密、纵向起伏，只压暗一点，避免变成斑马
	float scales = 0.5 + 0.5 * sin(UV.x * 130.0 + sin(UV.y * 14.0) * 1.4);
	col *= 1.0 - scales * stripe_strength * (0.45 + 0.55 * tube);

	// 从头到尾流动的能量脉冲
	float head = fract(TIME * flow_speed);
	float pulse = exp(-pow((UV.x - head) * 7.0, 2.0));
	col += accent_color.rgb * pulse * (0.22 + energy * 0.7);

	// 顶部轮廓光
	float rim = smoothstep(0.55, 1.0, across);
	col += rim_color.rgb * rim * rim_strength * (0.6 + energy * 0.5);

	COLOR = vec4(col, COLOR.a);
}
