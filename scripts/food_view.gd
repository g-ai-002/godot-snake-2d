class_name FoodView
extends Node2D

## 食物/道具：脉动光球 + 双层光环 + 环绕卫星 + 点光源 + 环绕粒子 + 地面投影。

const KIND_COLORS := {
	"speed_up": Color("#ffd166"),
	"slow_down": Color("#6ec6ff"),
	"shield": Color("#c09bff"),
	"magnet": Color("#ff8fd1"),
	"double": Color("#ffe066"),
}

var cell := 64.0
var kind := ""
var colors: Dictionary = Palette.get_theme("neon")
var time := 0.0

var light: PointLight2D
var sparkles: GPUParticles2D


func _ready() -> void:
	# 食物自身不参与 2D 光照，否则会被自己的点光源打成白色。
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded

	light = PointLight2D.new()
	light.texture = _radial_texture()
	light.texture_scale = 3.4
	light.energy = 0.8
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)

	sparkles = GPUParticles2D.new()
	sparkles.amount = 18
	sparkles.lifetime = 1.4
	sparkles.preprocess = 1.0
	sparkles.local_coords = true
	sparkles.texture = _dot_texture()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = cell * 0.3
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 26.0
	process.gravity = Vector3(0.0, -18.0, 0.0)
	process.scale_min = 0.06
	process.scale_max = 0.18
	process.lifetime_randomness = 0.55
	sparkles.process_material = process
	add_child(sparkles)


func configure(new_cell: float, new_kind: String, new_colors: Dictionary) -> void:
	cell = new_cell
	kind = new_kind
	colors = new_colors
	_apply_color()


func set_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	_apply_color()


func _apply_color() -> void:
	var color := current_color()
	light.color = color
	light.energy = 0.85 if kind == "" else 1.15
	light.texture_scale = 2.8 if kind == "" else 3.6
	sparkles.modulate = color
	queue_redraw()


func current_color() -> Color:
	if kind == "":
		return colors["food"]
	return KIND_COLORS.get(kind, colors["accent"])


func _process(delta: float) -> void:
	time += delta
	var pulse := 0.92 + sin(time * 3.4) * 0.06
	scale = Vector2(pulse, pulse)
	rotation = sin(time * 0.8) * 0.1
	light.energy = (1.15 if kind == "" else 1.6) + sin(time * 4.0) * 0.3
	queue_redraw()


func _draw() -> void:
	var color := current_color()
	var r := cell * 0.28
	var pulse := 0.5 + 0.5 * sin(time * 3.2)

	# 地面投影，让食物“浮”在棋盘上
	draw_set_transform(Vector2(0.0, r * 1.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, r * 1.1, Color(0.0, 0.0, 0.0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 多层辉光
	draw_circle(Vector2.ZERO, r * 2.6 * pulse, Color(color, 0.045))
	draw_circle(Vector2.ZERO, r * 1.95 * pulse, Color(color, 0.08))
	draw_circle(Vector2.ZERO, r * 1.45, Color(color, 0.14))

	# 旋转的双层弧线
	draw_arc(
		Vector2.ZERO, r * 1.62, time * 0.9, time * 0.9 + TAU * 0.72, 46, Color(color, 0.5), 2.0, true
	)
	draw_arc(
		Vector2.ZERO,
		r * 1.3,
		-time * 1.6,
		-time * 1.6 + TAU * 0.4,
		32,
		Color(color, 0.75),
		2.6,
		true
	)

	# 环绕的卫星光点
	for i in 3:
		var angle := time * 1.5 + TAU * float(i) / 3.0
		var orbit := Vector2(cos(angle), sin(angle) * 0.62) * r * 2.35
		draw_circle(orbit, r * 0.1, Color(color, 0.9))
		draw_circle(orbit, r * 0.22, Color(color, 0.18))

	match kind:
		"speed_up":
			_triangle(color, r)
		"slow_down":
			_diamond(color, r)
		"shield":
			_hexagon(color, r)
		"magnet":
			_magnet(color, r)
		"double":
			_double(color, r)
		_:
			_apple(color, r)


func _apple(color: Color, r: float) -> void:
	draw_circle(Vector2(0.0, r * 0.12), r * 1.02, color.darkened(0.35))
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2(-r * 0.26, -r * 0.28), r * 0.3, color.lightened(0.5))
	draw_line(Vector2(0.0, -r * 0.95), Vector2(r * 0.34, -r * 1.35), color.darkened(0.45), 3.0, true)
	draw_circle(Vector2(r * 0.6, -r * 1.15), r * 0.22, color.lightened(0.6))


func _triangle(color: Color, r: float) -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -r * 1.2),
		Vector2(r * 1.02, r * 0.92),
		Vector2(-r * 1.02, r * 0.92),
	])
	draw_colored_polygon(points, color.darkened(0.25))
	var inner := PackedVector2Array([
		Vector2(0.0, -r * 0.55),
		Vector2(r * 0.5, r * 0.55),
		Vector2(-r * 0.5, r * 0.55),
	])
	draw_colored_polygon(inner, color.lightened(0.45))


func _diamond(color: Color, r: float) -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -r * 1.15),
		Vector2(r * 1.05, 0.0),
		Vector2(0.0, r * 1.15),
		Vector2(-r * 1.05, 0.0),
	])
	draw_colored_polygon(points, color.darkened(0.25))
	var inner := PackedVector2Array([
		Vector2(0.0, -r * 0.55),
		Vector2(r * 0.5, 0.0),
		Vector2(0.0, r * 0.55),
		Vector2(-r * 0.5, 0.0),
	])
	draw_colored_polygon(inner, color.lightened(0.45))


func _hexagon(color: Color, r: float) -> void:
	var points := PackedVector2Array()
	for i in 6:
		var angle := -PI * 0.5 + TAU * i / 6.0
		points.append(Vector2(cos(angle), sin(angle)) * r * 1.05)
	draw_colored_polygon(points, color.darkened(0.28))
	draw_circle(Vector2.ZERO, r * 0.62, color)
	draw_circle(Vector2.ZERO, r * 0.4, color.lightened(0.5))


func _magnet(color: Color, r: float) -> void:
	draw_arc(Vector2.ZERO, r * 0.72, 0.0, PI, 28, color, r * 0.46, true)
	draw_line(Vector2(r * 0.72, 0.0), Vector2(r * 0.72, -r * 0.6), color, r * 0.46, true)
	draw_line(Vector2(-r * 0.72, 0.0), Vector2(-r * 0.72, -r * 0.6), color, r * 0.46, true)
	draw_circle(Vector2(r * 0.72, -r * 0.6), r * 0.23, color.lightened(0.5))
	draw_circle(Vector2(-r * 0.72, -r * 0.6), r * 0.23, color.lightened(0.5))


func _double(color: Color, r: float) -> void:
	draw_circle(Vector2(-r * 0.38, 0.0), r * 0.72, color.darkened(0.25))
	draw_circle(Vector2(r * 0.38, 0.0), r * 0.72, color.lightened(0.3))
	draw_circle(Vector2(-r * 0.55, -r * 0.28), r * 0.16, color.lightened(0.65))
	draw_circle(Vector2(r * 0.2, -r * 0.28), r * 0.16, color.lightened(0.65))


static var _dot_cache: Texture2D


static func _dot_texture() -> Texture2D:
	if _dot_cache != null:
		return _dot_cache
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var offset := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var alpha := clampf(1.0 - offset, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
	_dot_cache = ImageTexture.create_from_image(image)
	return _dot_cache


static func _radial_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.35),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture
