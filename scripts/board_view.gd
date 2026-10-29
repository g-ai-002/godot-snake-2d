class_name BoardView
extends Node2D

## 棋盘层：着色器地面（能量网格/扫光/节点闪烁）+ 圆角墙体 + 发光边框与四角装饰。

const CELL := 64.0

var cols := 20
var rows := 20
var walls := {}
var colors: Dictionary = Palette.get_theme("neon")
var portal_layer: PortalLayer

var _surface: ColorRect
var _surface_material: ShaderMaterial
var _wall_style: StyleBoxFlat
var _wall_style_inner: StyleBoxFlat


func _ready() -> void:
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = preload("res://shaders/board2d.gdshader")

	_surface = ColorRect.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.material = _surface_material
	_surface.z_index = -1
	add_child(_surface)

	portal_layer = PortalLayer.new()
	add_child(portal_layer)

	_build_wall_styles()
	_apply_surface()


func configure(
	new_cols: int,
	new_rows: int,
	new_walls: Dictionary,
	new_portals: Dictionary,
	new_colors: Dictionary
) -> void:
	cols = new_cols
	rows = new_rows
	walls = new_walls
	colors = new_colors
	portal_layer.configure(new_portals, cols, rows, CELL, colors)
	_build_wall_styles()
	_apply_surface()
	queue_redraw()


func set_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	portal_layer.set_colors(new_colors)
	_build_wall_styles()
	_apply_surface()
	queue_redraw()


## 吃食物/提速时抬升地面能量强度，让棋盘跟着“通电”。
func set_energy(value: float) -> void:
	_surface_material.set_shader_parameter("energy", clampf(value, 0.0, 1.0))


func _apply_surface() -> void:
	var board_size := Vector2(cols, rows) * CELL
	_surface.position = -board_size * 0.5
	_surface.size = board_size
	_surface_material.set_shader_parameter("grid_size", Vector2(cols, rows))
	_surface_material.set_shader_parameter("base_color", colors["board"])
	_surface_material.set_shader_parameter("alt_color", colors["board_alt"])
	_surface_material.set_shader_parameter("line_color", colors["grid"].lerp(colors["glow"], 0.5))
	_surface_material.set_shader_parameter("glow_color", colors["glow"])
	_surface_material.set_shader_parameter("accent_color", colors["accent_alt"])


func _build_wall_styles() -> void:
	var radius := int(CELL * 0.16)
	_wall_style = StyleBoxFlat.new()
	_wall_style.bg_color = colors["wall"]
	_wall_style.set_corner_radius_all(radius)
	_wall_style.set_border_width_all(2)
	_wall_style.border_color = Color(colors["wall_edge"], 0.9)
	_wall_style.shadow_color = Color(colors["wall_edge"], 0.22)
	_wall_style.shadow_size = 10
	_wall_style.anti_aliasing = true

	_wall_style_inner = StyleBoxFlat.new()
	_wall_style_inner.bg_color = Color(colors["wall_edge"], 0.1)
	_wall_style_inner.set_corner_radius_all(maxi(radius - 3, 2))
	_wall_style_inner.anti_aliasing = true


func _draw() -> void:
	var board_size := Vector2(cols, rows) * CELL
	var half := board_size * 0.5
	var rect := Rect2(-half, board_size)

	# 棋盘外扩的柔光与底座
	draw_rect(rect.grow(44.0), Color(colors["frame"], 0.025))
	draw_rect(rect.grow(22.0), Color(colors["frame"], 0.05))
	draw_rect(rect.grow(8.0), Color(colors["board"], 0.9))

	for cell in walls.keys():
		var center := BoardLogic.cell_to_world(cell, cols, rows, CELL)
		var inset := CELL * 0.08
		var wall_rect := Rect2(
			center - Vector2.ONE * (CELL * 0.5 - inset),
			Vector2.ONE * (CELL - inset * 2.0)
		)
		# 逐层叠加的辉光，替代单一描边
		for i in 3:
			var grow := 6.0 + i * 7.0
			draw_rect(wall_rect.grow(grow), Color(colors["wall_edge"], 0.05 - i * 0.012))
		draw_style_box(_wall_style, wall_rect)
		draw_style_box(_wall_style_inner, wall_rect.grow(-CELL * 0.11))
		draw_line(
			wall_rect.position + Vector2(7.0, 6.0),
			Vector2(wall_rect.end.x - 7.0, wall_rect.position.y + 6.0),
			Color(colors["wall_edge"], 0.75),
			2.0,
			true
		)

	# 边框：三层由细到粗的描边堆出光晕
	draw_rect(rect, Color(colors["frame"], 0.85), false, 2.0)
	draw_rect(rect.grow(4.0), Color(colors["frame"], 0.28), false, 5.0)
	draw_rect(rect.grow(10.0), Color(colors["frame"], 0.1), false, 9.0)
	draw_rect(rect.grow(18.0), Color(colors["frame"], 0.04), false, 14.0)

	var accent: Color = colors["accent"]
	var arm := 38.0
	var corners := [
		[rect.position, Vector2(1.0, 1.0)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1.0, 1.0)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1.0, -1.0)],
		[rect.end, Vector2(-1.0, -1.0)],
	]
	for corner in corners:
		var point: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		var outer: Vector2 = point + dir * 4.0
		draw_line(outer, outer + Vector2(arm * dir.x, 0.0), Color(accent, 0.9), 3.0, true)
		draw_line(outer, outer + Vector2(0.0, arm * dir.y), Color(accent, 0.9), 3.0, true)
		draw_line(
			outer + dir * 2.0,
			outer + dir * 2.0 + Vector2(arm * dir.x * 0.6, 0.0),
			Color(accent, 0.25),
			7.0,
			true
		)
		draw_line(
			outer + dir * 2.0,
			outer + dir * 2.0 + Vector2(0.0, arm * dir.y * 0.6),
			Color(accent, 0.25),
			7.0,
			true
		)
