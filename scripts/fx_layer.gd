class_name FxLayer
extends CanvasLayer

## 屏幕后处理层：泛光、色差、调色、暗角、扫描线与胶片颗粒。
## 位于世界与 HUD 之间，界面文字不会被色差糊掉。

const POSTFX := preload("res://shaders/postfx.gdshader")

var _material: ShaderMaterial
var _pulse := 0.0
var _desaturate := 0.0
var _desaturate_target := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE


func _ready() -> void:
	layer = 1

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = POSTFX
	rect.material = _material
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	set_process(false)


func configure(colors: Dictionary) -> void:
	_material.set_shader_parameter("tint_shadow", colors["bg_top"])
	_material.set_shader_parameter("tint_highlight", colors["text"])


## 吃食物、传送等瞬时事件：短暂抬升泛光与色差。
func pulse(amount: float) -> void:
	_pulse = maxf(_pulse, amount)
	set_process(true)


func flash(color: Color, amount: float) -> void:
	_flash_color = color
	_flash = maxf(_flash, amount)
	_material.set_shader_parameter("flash_color", color)
	set_process(true)


func set_desaturate(value: float) -> void:
	_desaturate_target = clampf(value, 0.0, 1.0)
	set_process(true)


func clear() -> void:
	_pulse = 0.0
	_flash = 0.0
	_desaturate = 0.0
	_desaturate_target = 0.0
	_material.set_shader_parameter("pulse", 0.0)
	_material.set_shader_parameter("flash", 0.0)
	_material.set_shader_parameter("desaturate", 0.0)
	set_process(false)


func _process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 2.6)
	_flash = move_toward(_flash, 0.0, delta * 3.2)
	_desaturate = move_toward(_desaturate, _desaturate_target, delta * 1.6)

	_material.set_shader_parameter("pulse", _pulse)
	_material.set_shader_parameter("flash", _flash)
	_material.set_shader_parameter("desaturate", _desaturate)

	if _pulse <= 0.0 and _flash <= 0.0 and is_equal_approx(_desaturate, _desaturate_target):
		_pulse = 0.0
		_flash = 0.0
		set_process(false)
