shader_type canvas_item;

// 棋盘地面：棋盘格 + 能量网格 + 交点闪烁 + 缓慢扫光 + 内边框辉光 + 暗角。
// 所有参数由 BoardView 按当前配色注入，切换主题即时生效。

uniform vec4 base_color : source_color = vec4(0.03, 0.06, 0.12, 1.0);
uniform vec4 alt_color : source_color = vec4(0.05, 0.09, 0.17, 1.0);
uniform vec4 line_color : source_color = vec4(0.1, 0.25, 0.33, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.95, 0.74, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.24, 0.65, 1.0);
uniform vec2 grid_size = vec2(20.0, 20.0);
uniform float glow_strength = 1.0;
uniform float energy = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.56);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 cell = uv * grid_size;
	vec2 local = fract(cell);
	vec2 edge = min(local, 1.0 - local);
	float line = 1.0 - smoothstep(0.0, 0.022, min(edge.x, edge.y));
	float checker = mod(floor(cell.x) + floor(cell.y), 2.0);

	vec3 col = mix(base_color.rgb, alt_color.rgb, checker * 0.9);
	col *= 0.86 + 0.26 * (1.0 - uv.y);

	// 表面细颗粒，避免大色块死板
	col += (value_noise(uv * grid_size * 6.0) - 0.5) * 0.05;

	// 网格线随位置产生呼吸差
	float breathe = 0.72 + 0.28 * sin(TIME * 1.6 - (uv.x + uv.y) * 4.5);
	col += line_color.rgb * line * 0.58 * breathe;

	// 每个格点像通电的节点一样闪烁着
	float node = 1.0 - smoothstep(0.0, 0.055, length(local - 0.5) * 2.0);
	float twinkle = 0.5 + 0.5 * sin(TIME * 2.4 + hash21(floor(cell)) * 24.0);
	col += glow_color.rgb * node * (0.2 + 0.6 * twinkle) * glow_strength;

	// 斜向扫过的能量带
	float sweep = exp(-pow((fract(TIME * 0.05) * 1.7 - 0.35 - (uv.x * 0.62 + uv.y * 0.38)) * 5.0, 2.0));
	col += accent_color.rgb * sweep * (0.05 + 0.2 * energy);

	// 缓慢下移的扫描线
	float scan = exp(-pow((uv.y - fract(TIME * 0.085)) * 220.0, 2.0));
	col += glow_color.rgb * scan * 0.14;

	// 内边框高光
	float border = 1.0 - smoothstep(0.0, 0.018, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	col += line_color.rgb * border * 1.3;

	// 边缘压暗，把注意力收进棋盘中心
	float vig = smoothstep(0.78, 0.2, length(uv - 0.5));
	col *= mix(0.58, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
