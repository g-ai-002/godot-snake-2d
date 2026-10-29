class_name AmbientFx
extends Node2D

## 环境粒子：棋盘上方缓慢漂浮的尘埃光点 + 几颗大颗粒虚焦光斑，制造空气感与景深。

var _motes: GPUParticles2D
var _bokeh: GPUParticles2D
var _mote_material: ParticleProcessMaterial
var _bokeh_material: ParticleProcessMaterial
var _board := Vector2(20.0, 20.0) * 64.0


func _ready() -> void:
	_mote_material = _make_material(0.06, 0.16, 4.0, 16.0, 0.25)
	_motes = _make_layer(70, 7.0, _mote_material, 0.55)

	_bokeh_material = _make_material(0.5, 1.4, 2.0, 7.0, 0.05)
	_bokeh = _make_layer(26, 11.0, _bokeh_material, 0.22)

	configure(20, 20, Palette.get_theme("neon"))


func configure(cols: int, rows: int, colors: Dictionary) -> void:
	_board = Vector2(cols, rows) * 64.0
	var extents := Vector3(_board.x * 0.62, _board.y * 0.62, 1.0)
	_mote_material.emission_box_extents = extents
	_bokeh_material.emission_box_extents = extents * 1.05
	_motes.modulate = Color(colors["accent"], 0.5)
	_bokeh.modulate = Color(colors["glow"], 0.16)


func _make_material(
	scale_min: float, scale_max: float, speed_min: float, speed_max: float, gravity: float
) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 28.0
	material.initial_velocity_min = speed_min
	material.initial_velocity_max = speed_max
	material.gravity = Vector3(0.0, -gravity, 0.0)
	material.scale_min = scale_min
	material.scale_max = scale_max
	material.lifetime_randomness = 0.65
	material.angle_min = 0.0
	material.angle_max = 360.0

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.85),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = ramp
	material.color_ramp = texture
	return material


func _make_layer(
	amount: int, lifetime: float, material: ParticleProcessMaterial, alpha: float
) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = 3.0
	particles.local_coords = true
	particles.texture = FoodView._dot_texture()
	particles.process_material = material
	particles.z_index = 0
	particles.modulate = Color(1.0, 1.0, 1.0, alpha)

	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = blend
	add_child(particles)
	return particles
