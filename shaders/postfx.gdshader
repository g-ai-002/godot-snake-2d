shader_type canvas_item;
render_mode unshaded;

// 全屏后处理：泛光 + 色差 + 调色 + 暗角 + 扫描线 + 胶片颗粒。
// 由 FxLayer 驱动 pulse / flash / desaturate，用于吃食物与死亡的瞬间反馈。

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float bloom_strength = 0.9;
uniform float bloom_threshold = 0.58;
uniform float bloom_radius = 24.0;
uniform float aberration = 0.0022;
uniform float exposure = 1.05;
uniform float saturation = 1.08;
uniform float contrast = 1.04;
uniform float vignette_strength = 0.5;
uniform float grain = 0.028;
uniform float scanline = 0.016;
uniform float desaturate = 0.0;
uniform float pulse = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec4 tint_shadow : source_color = vec4(0.02, 0.05, 0.12, 1.0);
uniform vec4 tint_highlight : source_color = vec4(1.0, 0.96, 0.9, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.56);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec2 cc = SCREEN_UV - 0.5;
	float r2 = dot(cc, cc);

	// 极轻微的桶形畸变，让画面像经过镜头
	vec2 uv = SCREEN_UV + cc * r2 * 0.02;

	// 边缘色差：径向偏移，平时几乎不可见，触发时放大
	float ca = (aberration + pulse * 0.006) * (0.2 + r2 * 3.4);
	vec3 col;
	col.r = texture(screen_texture, uv + cc * ca).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - cc * ca).b;

	// 泛光：对亮部做黄金角螺旋采样，低成本近似大半径模糊
	vec3 bloom = vec3(0.0);
	float weight_sum = 0.0;
	for (int i = 0; i < 14; i++) {
		float fi = float(i);
		float angle = fi * 2.39996;
		float radius = (0.18 + fi / 13.0) * bloom_radius;
		vec2 offset = vec2(cos(angle), sin(angle)) * radius * pixel;
		vec3 sample_color = texture(screen_texture, uv + offset).rgb;
		float luma = max(max(sample_color.r, sample_color.g), sample_color.b);
		float weight = 1.0 - (fi / 14.0) * 0.8;
		bloom += sample_color * smoothstep(bloom_threshold, bloom_threshold + 0.4, luma) * weight;
		weight_sum += weight;
	}
	bloom /= max(weight_sum, 0.001);
	col += bloom * (bloom_strength + pulse * 0.8);

	// 调色：轻微分离阴影/高光色相，再套 ACES 曲线
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, col * mix(tint_shadow.rgb * 8.0, tint_highlight.rgb, smoothstep(0.0, 0.7, luma)), 0.18);
	col = mix(vec3(luma), col, saturation * (1.0 - desaturate * 0.9));
	col = (col - 0.5) * contrast + 0.5;
	col = clamp(col, 0.0, 1.0);
	col = mix(col, col * (2.51 * col + 0.03) / (col * (2.43 * col + 0.59) + 0.14), 0.55);
	col *= exposure;

	// 暗角
	float vig = 1.0 - vignette_strength * smoothstep(0.1, 0.62, r2 * 1.7);
	col *= vig;

	// 扫描线（一行亮一行暗），再叠一层极细的颗粒
	float line = 0.5 + 0.5 * sin(SCREEN_UV.y / max(pixel.y, 0.000001) * 3.14159265);
	col *= 1.0 - scanline * line;

	float noise = hash21(SCREEN_UV / max(pixel, vec2(0.000001)) + fract(TIME) * 113.0) - 0.5;
	col += noise * grain;

	col = mix(col, flash_color.rgb, clamp(flash, 0.0, 1.0));

	COLOR = vec4(col, 1.0);
}
