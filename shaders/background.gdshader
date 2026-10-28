shader_type canvas_item;

// 全屏背景：渐变 + 流动噪点 + 中心辉光 + 暗角 + 胶片颗粒。

uniform vec4 top_color : source_color = vec4(0.027, 0.05, 0.1, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.012, 0.024, 0.05, 1.0);
uniform vec4 glow_color : source_color = vec4(0.18, 0.85, 0.68, 1.0);
uniform float glow_strength = 0.22;
uniform float vignette = 0.7;
uniform float grain = 0.03;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
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
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

	float drift = TIME * 0.03;
	float clouds = noise2(uv * vec2(2.6, 1.8) + vec2(drift, -drift * 0.6));
	clouds = clouds * 0.65 + noise2(uv * 6.0 - vec2(drift * 1.4, drift)) * 0.35;
	col += glow_color.rgb * pow(clouds, 3.0) * glow_strength;

	float d = distance(uv, vec2(0.5));
	col += glow_color.rgb * smoothstep(0.75, 0.0, d) * 0.05;

	float vig = smoothstep(0.98, 0.2, d);
	col *= mix(1.0 - vignette, 1.0, vig);
	col += (hash21(uv * 720.0 + fract(TIME) * 37.0) - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
