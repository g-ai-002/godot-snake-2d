class_name HeadView
extends Node2D

## 蛇头：分层辉光 + 圆管明暗 + 高光 + 发光眼睛 + 吐信 + 护盾光环 + 死亡 X 眼。

var radius := 25.0
var colors: Dictionary = Palette.get_theme("neon")
var direction := Vector2.RIGHT
var dead := false
var shielded := false
var time := 0.0
var energy := 0.0


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func set_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	queue_redraw()


## 朝向变化必须重绘，否则 _draw 缓存的绘制指令会让眼睛停在旧方向。
func set_direction(value: Vector2) -> void:
	if direction == value:
		return
	direction = value
	queue_redraw()


func set_dead(value: bool) -> void:
	if dead == value:
		return
	dead = value
	queue_redraw()


func set_shielded(value: bool) -> void:
	if shielded == value:
		return
	shielded = value
	queue_redraw()


func set_energy(value: float) -> void:
	energy = value
	queue_redraw()


func _draw() -> void:
	var head_color: Color = colors["head"]
	var body_color: Color = colors["body"]
	var glow_color: Color = colors["glow"]
	var accent: Color = colors["accent"]
	var dark: Color = colors["bg_bottom"].darkened(0.35)

	if shielded:
		var pulse := 1.0 + sin(time * 5.0) * 0.05
		draw_circle(Vector2.ZERO, radius * 1.72 * pulse, Color(accent, 0.07))
		draw_arc(Vector2.ZERO, radius * 1.6 * pulse, 0.0, TAU, 56, Color(accent, 0.75), 2.0, true)
		draw_arc(Vector2.ZERO, radius * 1.42 * pulse, 0.0, TAU, 56, Color(accent, 0.22), 9.0, true)

	# 三层光晕，配合全屏 Bloom 形成真正的“发光体”
	draw_circle(Vector2.ZERO, radius * 2.15, Color(glow_color, 0.04 + energy * 0.03))
	draw_circle(Vector2.ZERO, radius * 1.55, Color(glow_color, 0.09 + energy * 0.05))
	draw_circle(Vector2.ZERO, radius * 1.22, Color(glow_color, 0.16))

	# 底部暗边 + 主体 + 上方高光，模拟球体受光
	draw_circle(Vector2(0.0, radius * 0.1), radius * 1.02, body_color.darkened(0.45))
	draw_circle(Vector2.ZERO, radius, body_color.darkened(0.18))
	draw_circle(Vector2(0.0, -radius * 0.06), radius * 0.86, head_color)
	draw_circle(
		Vector2(-radius * 0.24, -radius * 0.3),
		radius * 0.42,
		Color(1.0, 1.0, 1.0, 0.34)
	)
	draw_arc(
		Vector2.ZERO,
		radius * 0.97,
		PI * 1.05,
		PI * 1.85,
		30,
		Color(1.0, 1.0, 1.0, 0.5),
		2.5,
		true
	)

	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)

	if not dead and sin(time * 3.4) > 0.72:
		var origin := forward * radius * 0.92
		var tip := origin + forward * radius * 0.85
		var fork := side * radius * 0.22
		var tongue := Color(colors["danger"], 0.9)
		draw_line(origin, tip, tongue, 2.4, true)
		draw_line(tip, tip + forward * radius * 0.26 + fork, tongue, 2.0, true)
		draw_line(tip, tip + forward * radius * 0.26 - fork, tongue, 2.0, true)

	for s in [-1.0, 1.0]:
		var eye: Vector2 = forward * radius * 0.28 + side * radius * 0.42 * s
		if dead:
			var size := radius * 0.22
			draw_line(
				eye - Vector2(size, size), eye + Vector2(size, size), dark, 3.4, true
			)
			draw_line(
				eye - Vector2(size, -size), eye + Vector2(size, -size), dark, 3.4, true
			)
			continue

		draw_circle(eye, radius * 0.3, Color(accent, 0.16))
		draw_circle(eye, radius * 0.24, dark)
		draw_circle(eye + forward * radius * 0.04, radius * 0.13, accent)
		draw_circle(eye + forward * radius * 0.12, radius * 0.05, Color.WHITE)
