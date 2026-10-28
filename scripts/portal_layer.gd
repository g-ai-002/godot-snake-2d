class_name PortalLayer
extends Node2D

## 传送门动画层：双层旋转圆弧 + 中心脉动。

var portals := {}
var cols := 20
var rows := 20
var cell := 64.0
var colors: Dictionary = Palette.get_theme("neon")
var time := 0.0


func configure(
	new_portals: Dictionary,
	new_cols: int,
	new_rows: int,
	new_cell: float,
	new_colors: Dictionary
) -> void:
	portals = new_portals
	cols = new_cols
	rows = new_rows
	cell = new_cell
	colors = new_colors
	queue_redraw()


func set_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	queue_redraw()


func _process(delta: float) -> void:
	if portals.is_empty():
		return
	time += delta
	queue_redraw()


func _draw() -> void:
	for cell_pos in portals.keys():
		var center := BoardLogic.cell_to_world(cell_pos, cols, rows, cell)
		var radius := cell * 0.38
		var pulse := 0.9 + 0.1 * sin(time * 3.0)
		draw_circle(center, radius * 1.25 * pulse, Color(colors["special"], 0.13))
		draw_arc(center, radius * 1.12, -time * 0.7, -time * 0.7 + TAU, 40, Color(colors["special"], 0.35), 2.0, true)
		draw_arc(
			center,
			radius,
			time * 2.2,
			time * 2.2 + TAU * 0.72,
			32,
			Color(colors["special"], 1.0),
			3.5,
			true
		)
		draw_arc(
			center,
			radius * 0.68,
			-time * 1.7,
			-time * 1.7 + TAU * 0.58,
			24,
			Color(colors["accent"], 0.9),
			2.5,
			true
		)
		draw_circle(center, radius * 0.12, Color(colors["accent"], 0.9))
