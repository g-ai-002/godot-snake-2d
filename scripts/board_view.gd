class_name BoardView
extends Node2D

## 棋盘静态层：背板、棋格、网格、墙体与边框，只在配置/换色时重绘一次。

const CELL := 64.0

var cols := 20
var rows := 20
var walls := {}
var colors: Dictionary = Palette.get_theme("neon")
var portal_layer: PortalLayer


func _ready() -> void:
	portal_layer = PortalLayer.new()
	add_child(portal_layer)


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
	queue_redraw()


func set_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	portal_layer.set_colors(new_colors)
	queue_redraw()


func _draw() -> void:
	var board_size := Vector2(cols, rows) * CELL
	var half := board_size * 0.5
	var rect := Rect2(-half, board_size)

	draw_rect(rect.grow(20.0), Color(colors["frame"], 0.045))
	draw_rect(rect.grow(9.0), Color(colors["board"], 0.6))
	draw_rect(rect, colors["board"])

	for y in rows:
		for x in cols:
			if (x + y) % 2 == 0:
				continue
			var cell_rect := Rect2(
				Vector2(-half.x + x * CELL, -half.y + y * CELL),
				Vector2.ONE * CELL
			)
			draw_rect(cell_rect, Color(colors["board_alt"], 0.5))

	var grid_color := Color(colors["grid"], 0.32)
	for x in cols + 1:
		var px := -half.x + x * CELL
		draw_line(Vector2(px, -half.y), Vector2(px, half.y), grid_color, 1.0)
	for y in rows + 1:
		var py := -half.y + y * CELL
		draw_line(Vector2(-half.x, py), Vector2(half.x, py), grid_color, 1.0)

	for cell in walls.keys():
		var center := BoardLogic.cell_to_world(cell, cols, rows, CELL)
		var inset := CELL * 0.07
		var wall_rect := Rect2(
			center - Vector2.ONE * (CELL * 0.5 - inset),
			Vector2.ONE * (CELL - inset * 2.0)
		)
		draw_rect(wall_rect.grow(4.0), Color(colors["wall_edge"], 0.09))
		draw_rect(wall_rect, colors["wall"])
		draw_rect(wall_rect, Color(colors["wall_edge"], 0.5), false, 2.0)
		draw_line(
			wall_rect.position + Vector2(5.0, 5.0),
			Vector2(wall_rect.end.x - 5.0, wall_rect.position.y + 5.0),
			Color(colors["wall_edge"], 0.7),
			2.0,
			true
		)

	draw_rect(rect, Color(colors["frame"], 0.7), false, 2.0)
	draw_rect(rect.grow(6.0), Color(colors["frame"], 0.12), false, 6.0)

	var accent: Color = colors["accent"]
	var arm := 34.0
	var corners := [
		[rect.position, Vector2(1.0, 1.0)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1.0, 1.0)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1.0, -1.0)],
		[rect.end, Vector2(-1.0, -1.0)],
	]
	for corner in corners:
		var point: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		draw_line(point, point + Vector2(arm * dir.x, 0.0), Color(accent, 0.85), 3.0, true)
		draw_line(point, point + Vector2(0.0, arm * dir.y), Color(accent, 0.85), 3.0, true)
