class_name HeadView
extends Node2D

## 蛇头：圆形 + 朝向眼睛 + 护盾光环 + 死亡 X 眼。

var radius := 25.0
var colors: Dictionary = Palette.get_theme("neon")
var direction := Vector2.RIGHT
var dead := false
var shielded := false
var time := 0.0


func _process(delta: float) -> void:
	if not shielded and not dead:
		return
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


func _draw() -> void:
	var head_color: Color = colors["head"]
	var dark: Color = colors["bg_bottom"].lightened(0.04)

	if shielded:
		var pulse := 1.0 + sin(time * 5.0) * 0.05
		draw_arc(Vector2.ZERO, radius * 1.5 * pulse, 0.0, TAU, 48, Color(colors["accent"], 0.85), 3.0, true)
		draw_arc(Vector2.ZERO, radius * 1.34 * pulse, 0.0, TAU, 48, Color(colors["accent"], 0.22), 8.0, true)

	draw_circle(Vector2.ZERO, radius * 1.14, Color(head_color, 0.12))
	draw_circle(Vector2.ZERO, radius, head_color)
	draw_circle(Vector2.ZERO, radius * 0.8, head_color.lightened(0.12))

	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	for s in [-1.0, 1.0]:
		var eye: Vector2 = forward * radius * 0.3 + side * radius * 0.4 * s
		if dead:
			var size := radius * 0.2
			draw_line(eye - Vector2(size, size), eye + Vector2(size, size), dark, 3.0, true)
			draw_line(eye - Vector2(size, -size), eye + Vector2(size, -size), dark, 3.0, true)
		else:
			draw_circle(eye, radius * 0.24, dark)
			draw_circle(eye + forward * radius * 0.09, radius * 0.1, Color.WHITE)
