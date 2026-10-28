class_name SnakeView
extends Node2D

## 蛇的渲染层：Line2D 平滑蛇身（渐变 + 锥度 + 叠加辉光），传送时自动拆分线段。

const CELL := 64.0
const SEGMENTS := 3

var cols := 20
var rows := 20
var colors: Dictionary = Palette.get_theme("neon")
var head: HeadView

var _bodies: Array[Line2D] = []
var _glows: Array[Line2D] = []


func _ready() -> void:
	for i in SEGMENTS:
		var glow := Line2D.new()
		glow.width = CELL * 1.3
		glow.joint_mode = Line2D.LINE_JOINT_ROUND
		glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
		glow.end_cap_mode = Line2D.LINE_CAP_ROUND
		glow.antialiased = true
		glow.z_index = 1
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = material
		add_child(glow)
		_glows.append(glow)

	for i in SEGMENTS:
		var body := Line2D.new()
		body.width = CELL * 0.74
		body.joint_mode = Line2D.LINE_JOINT_ROUND
		body.begin_cap_mode = Line2D.LINE_CAP_ROUND
		body.end_cap_mode = Line2D.LINE_CAP_ROUND
		body.antialiased = true
		body.z_index = 2
		add_child(body)
		_bodies.append(body)

	head = HeadView.new()
	head.z_index = 3
	add_child(head)
	apply_colors(colors)


func configure(new_cols: int, new_rows: int, new_colors: Dictionary) -> void:
	cols = new_cols
	rows = new_rows
	apply_colors(new_colors)
	head.radius = CELL * 0.4


func apply_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray([colors["head"], colors["body"], colors["tail"]])

	var glow_gradient := Gradient.new()
	glow_gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	glow_gradient.colors = PackedColorArray([
		Color(colors["glow"], 0.42),
		Color(colors["glow"], 0.14),
		Color(colors["glow"], 0.0),
	])

	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(0.55, 0.82))
	taper.add_point(Vector2(1.0, 0.5))

	for body in _bodies:
		body.gradient = gradient
		body.width_curve = taper
	for glow in _glows:
		glow.gradient = glow_gradient
		glow.width_curve = taper

	if head:
		head.set_colors(colors)


func update_snake(
	previous: Array[Vector2i],
	current: Array[Vector2i],
	progress: float,
	direction: Vector2i,
	is_dead: bool,
	shielded: bool
) -> void:
	if current.is_empty():
		return

	var points := PackedVector2Array()
	for i in current.size():
		var to := BoardLogic.cell_to_world(current[i], cols, rows, CELL)
		var from := to
		if i < previous.size():
			from = BoardLogic.cell_to_world(previous[i], cols, rows, CELL)
		elif not previous.is_empty():
			from = BoardLogic.cell_to_world(previous[previous.size() - 1], cols, rows, CELL)
		points.append(from.lerp(to, progress))

	head.position = points[0]
	head.direction = Vector2(direction)
	head.set_dead(is_dead)
	head.set_shielded(shielded)

	var segments := _split(points)
	for i in SEGMENTS:
		var show: bool = i < segments.size() and segments[i].size() >= 2
		_bodies[i].visible = show
		_glows[i].visible = show
		if not show:
			continue
		_bodies[i].points = segments[i]
		_glows[i].points = segments[i]


func _split(points: PackedVector2Array) -> Array:
	var result := []
	var current := PackedVector2Array()
	for i in points.size():
		if i > 0 and points[i].distance_to(points[i - 1]) > CELL * 1.55:
			result.append(current)
			current = PackedVector2Array()
		current.append(points[i])
	if not current.is_empty():
		result.append(current)
	return result
