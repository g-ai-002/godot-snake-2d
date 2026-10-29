extends Node2D

## 贪吃蛇 2D 主控制器：状态机、网格逻辑、输入、镜头与特效调度。

const CELL := 64.0
const COUNTDOWN_TIME := 3.0
const POWERUP_CHANCE := 0.28
const BG_SHADER := preload("res://shaders/background.gdshader")
const POPUP_POOL_SIZE := 8
const BURST_POOL_SIZE := 6
const BURST_AMOUNT := 40

const EFFECT_DURATIONS := {
	"speed_up": 6.0,
	"slow_down": 5.0,
	"shield": 10.0,
	"magnet": 6.0,
	"double": 8.0,
}
const EFFECT_LABELS := {
	"speed_up": "加速",
	"slow_down": "减速",
	"shield": "护盾",
	"magnet": "磁铁",
	"double": "双倍",
}
const POWERUPS := ["speed_up", "slow_down", "shield", "magnet", "double"]
const POWERUP_COLORS := {
	"speed_up": Color("#ffd166"),
	"slow_down": Color("#6ec6ff"),
	"shield": Color("#c09bff"),
	"magnet": Color("#ff8fd1"),
	"double": Color("#ffe066"),
}

const SIZES := [15, 20, 25]
const SIZE_LABELS := ["小 15×15", "中 20×20", "大 25×25"]
const SPEEDS := [300, 200, 100]
const SPEED_LABELS := ["慢速", "中速", "快速"]

enum State { MENU, COUNTDOWN, PLAYING, PAUSED, OVER }

var state := State.MENU
var cols := 20
var rows := 20
var speed_ms := 200
var level_index := 0
var theme_id := "neon"
var colors: Dictionary

var cells: Array[Vector2i] = []
var previous_cells: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var queued: Array[Vector2i] = []
var food_cell := Vector2i(-1, -1)
var food_kind := ""
var walls := {}
var portals := {}

var score := 0
var best := 0
var effects := {}
var shield_charge := false
var tick_accum := 0.0
var countdown := 0.0
var go_timer := 0.0
var hud_accum := 0.0
var shake := 0.0
var dead := false

var rng := RandomNumberGenerator.new()

var _best_at_start := 0
var _base_zoom := 1.0
var _touch_origin := Vector2.ZERO
var _bg_material: ShaderMaterial

# 飘字与爆散粒子常驻复用，避免每次吃食物都新建节点/材质/贴图造成掉帧。
var _popup_pool: Array[Label] = []
var _popup_index := 0
var _burst_pool: Array[GPUParticles2D] = []
var _burst_index := 0

@onready var board_view: BoardView = $Board
@onready var snake_view: SnakeView = $Snake
@onready var food_view: FoodView = $Food
@onready var popups: Node2D = $Popups
@onready var camera: Camera2D = $Camera
@onready var hud: HudView = $UI/HUD


func _ready() -> void:
	rng.randomize()
	_load_settings()
	_build_background()
	_warm_effects()

	hud.start_pressed.connect(start_game)
	hud.restart_pressed.connect(start_game)
	hud.resume_pressed.connect(toggle_pause)
	hud.menu_pressed.connect(enter_menu)
	hud.pause_pressed.connect(toggle_pause)
	hud.mute_pressed.connect(_toggle_mute)
	hud.option_cycled.connect(_cycle_option)

	_apply_theme()
	_setup_board()
	_spawn_food()
	_update_menu_texts()
	hud.set_muted(SaveData.muted)
	hud.set_best(best)
	hud.update_stats(0, best, cells.size())
	hud.enter_menu()

	get_viewport().size_changed.connect(_on_viewport_resized)


func _load_settings() -> void:
	cols = SaveData.board_size
	if not SIZES.has(cols):
		cols = 20
	rows = cols
	speed_ms = SaveData.speed_ms
	if not SPEEDS.has(speed_ms):
		speed_ms = 200
	level_index = clampi(SaveData.level, 0, BoardLogic.level_count() - 1)
	theme_id = SaveData.theme_id
	if not Palette.DATA.has(theme_id):
		theme_id = "neon"
	best = SaveData.best


func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)

	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_material = ShaderMaterial.new()
	_bg_material.shader = BG_SHADER
	rect.material = _bg_material
	layer.add_child(rect)


## 开局一次性建好飘字与爆散粒子池，运行时只改参数复用，避免吃食物时卡帧。
func _warm_effects() -> void:
	for i in POPUP_POOL_SIZE:
		var label := Label.new()
		label.add_theme_font_override("font", UiFont.get_font())
		label.add_theme_font_size_override("font_size", int(CELL * 0.46))
		label.add_theme_constant_override("outline_size", 6)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(CELL * 2.4, 0.0)
		label.z_index = 30
		label.visible = false
		popups.add_child(label)
		_popup_pool.append(label)

	var dot := FoodView._dot_texture()
	for i in BURST_POOL_SIZE:
		var particles := GPUParticles2D.new()
		particles.amount = BURST_AMOUNT
		particles.lifetime = 0.65
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.local_coords = false
		particles.z_index = 12
		particles.emitting = false
		particles.texture = dot

		var material := ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = CELL * 0.16
		material.direction = Vector3(0.0, -1.0, 0.0)
		material.spread = 180.0
		material.initial_velocity_min = 20.0
		material.initial_velocity_max = 45.0
		material.gravity = Vector3(0.0, 70.0, 0.0)
		material.scale_min = 0.1
		material.scale_max = 0.28
		particles.process_material = material

		popups.add_child(particles)
		_burst_pool.append(particles)


func _on_viewport_resized() -> void:
	_fit_camera()


func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_process_countdown(delta)
		State.PLAYING:
			_tick_effects(delta)
			tick_accum += delta
			var interval := _interval()
			var guard := 0
			while tick_accum >= interval and guard < 4:
				tick_accum -= interval
				_tick()
				guard += 1
				if state != State.PLAYING:
					break
			if state == State.PLAYING:
				var progress := clampf(tick_accum / maxf(interval, 0.001), 0.0, 1.0)
				snake_view.update_snake(
					previous_cells, cells, progress, direction, dead, shield_charge
				)
		_:
			pass

	if go_timer > 0.0:
		go_timer -= delta
		if go_timer <= 0.0:
			hud.hide_countdown()

	_update_camera(delta)
	_update_hud(delta)


# ---------------------------------------------------------------- 流程

func start_game() -> void:
	Engine.time_scale = 1.0
	dead = false
	score = 0
	_best_at_start = best
	effects.clear()
	shield_charge = false
	tick_accum = 0.0
	go_timer = 0.0
	shake = 0.0
	camera.offset = Vector2.ZERO

	_setup_board()
	_spawn_food()

	state = State.COUNTDOWN
	countdown = COUNTDOWN_TIME
	hud.enter_game()
	hud.update_stats(score, best, cells.size())
	hud.set_effects(effects)
	hud.set_best(best)
	hud.show_countdown(str(int(COUNTDOWN_TIME)))
	Sfx.play("count")
	Sfx.start_music()
	snake_view.update_snake(cells, cells, 1.0, direction, false, false)


func enter_menu() -> void:
	Engine.time_scale = 1.0
	state = State.MENU
	dead = false
	effects.clear()
	shield_charge = false
	shake = 0.0
	camera.offset = Vector2.ZERO
	SaveData.save_data()
	_setup_board()
	_spawn_food()
	_update_menu_texts()
	hud.set_best(best)
	hud.enter_menu()


func toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		hud.show_pause()
	elif state == State.PAUSED:
		state = State.PLAYING
		hud.hide_pause()


func _process_countdown(delta: float) -> void:
	var before := int(ceil(countdown))
	countdown -= delta
	if countdown <= 0.0:
		state = State.PLAYING
		tick_accum = 0.0
		hud.show_countdown("GO!")
		go_timer = 0.55
		Sfx.play("go")
		return
	var now := int(ceil(countdown))
	if now != before and now >= 1:
		hud.show_countdown(str(now))
		Sfx.play("count")


func _setup_board() -> void:
	var layout := BoardLogic.build_layout(level_index, cols, rows)
	walls = layout["walls"]
	portals = layout["portals"]
	BoardLogic.clear_spawn_row(walls, cols, rows)

	cells = BoardLogic.spawn_body(cols, rows)
	previous_cells = cells.duplicate()
	direction = Vector2i.RIGHT
	queued.clear()
	food_kind = ""
	dead = false

	board_view.configure(cols, rows, walls, portals, colors)
	snake_view.configure(cols, rows, colors)
	snake_view.update_snake(cells, cells, 1.0, direction, false, false)
	food_view.configure(CELL, food_kind, colors)
	_fit_camera()


func _spawn_food() -> void:
	var occupied := {}
	for cell in cells:
		occupied[cell] = true
	for wall in walls:
		occupied[wall] = true
	for portal in portals:
		occupied[portal] = true

	food_cell = BoardLogic.random_cell(cols, rows, occupied, rng)
	if food_cell.x < 0:
		food_cell = Vector2i.ZERO
	food_kind = ""
	if rng.randf() < POWERUP_CHANCE:
		food_kind = POWERUPS[rng.randi_range(0, POWERUPS.size() - 1)]

	food_view.configure(CELL, food_kind, colors)
	food_view.position = BoardLogic.cell_to_world(food_cell, cols, rows, CELL)


# ---------------------------------------------------------------- 网格推进

func _interval() -> float:
	var base := float(speed_ms) / 1000.0
	if effects.has("speed_up"):
		return maxf(0.06, base * 0.65)
	if effects.has("slow_down"):
		return minf(0.6, base * 1.5)
	return base


func _tick() -> void:
	previous_cells = cells.duplicate()

	if not queued.is_empty():
		var next_direction: Vector2i = queued.pop_front()
		if next_direction != -direction:
			direction = next_direction

	var new_head: Vector2i = cells[0] + direction
	if portals.has(new_head):
		new_head = portals[new_head]
		_burst(
			BoardLogic.cell_to_world(cells[0], cols, rows, CELL),
			colors["special"],
			12,
			34.0
		)

	if _blocked(new_head):
		if shield_charge:
			shield_charge = false
			effects.erase("shield")
			hud.set_effects(effects)
			shake = 9.0
			Sfx.play("shield")
			return
		_die()
		return

	var ate := new_head == food_cell
	if not ate and effects.has("magnet") and _manhattan(new_head, food_cell) <= 1:
		ate = true

	cells.insert(0, new_head)
	if not ate:
		cells.pop_back()

	if not ate:
		return

	var gain := 20 if effects.has("double") else 10
	score += gain
	if score > best:
		best = score
		SaveData.best = best

	var world := BoardLogic.cell_to_world(new_head, cols, rows, CELL)
	_spawn_popup("+%d" % gain, world)
	_burst(world, _food_color(), 22, 52.0)

	if food_kind == "":
		Sfx.play("eat")
	else:
		Sfx.play("powerup")
		_activate(food_kind)
		_spawn_popup(EFFECT_LABELS[food_kind], world + Vector2(0.0, CELL * 0.55))

	_spawn_food()


func _blocked(head: Vector2i) -> bool:
	if head.x < 0 or head.y < 0 or head.x >= cols or head.y >= rows:
		return true
	if walls.has(head):
		return true
	for i in range(0, cells.size() - 1):
		if cells[i] == head:
			return true
	return false


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _die() -> void:
	state = State.OVER
	dead = true
	shake = 16.0
	SaveData.best = best
	SaveData.save_data()
	Sfx.play("death")
	hud.flash(Color(colors["danger"], 0.55))
	_burst(BoardLogic.cell_to_world(cells[0], cols, rows, CELL), colors["danger"], 36, 76.0)
	snake_view.update_snake(previous_cells, cells, 1.0, direction, true, false)

	Engine.time_scale = 0.45
	await get_tree().create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	hud.show_game_over(score, best, score > _best_at_start and score > 0)


func _activate(kind: String) -> void:
	if kind == "speed_up":
		effects.erase("slow_down")
	elif kind == "slow_down":
		effects.erase("speed_up")
	effects[kind] = EFFECT_DURATIONS[kind]
	if kind == "shield":
		shield_charge = true
	hud.set_effects(effects)


func _tick_effects(delta: float) -> void:
	if effects.is_empty():
		return
	var expired: Array[String] = []
	for kind in effects:
		effects[kind] = float(effects[kind]) - delta
		if effects[kind] <= 0.0:
			expired.append(kind)
	for kind in expired:
		effects.erase(kind)
		if kind == "shield":
			shield_charge = false


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_origin = event.position
		else:
			_swipe(_touch_origin, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_origin = event.position
		else:
			_swipe(_touch_origin, event.position)


func _handle_key(keycode: int) -> void:
	match keycode:
		KEY_UP, KEY_W:
			_queue(Vector2i.UP)
		KEY_DOWN, KEY_S:
			_queue(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			_queue(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			_queue(Vector2i.RIGHT)
		KEY_SPACE:
			if state == State.PLAYING or state == State.PAUSED:
				toggle_pause()
		KEY_ESCAPE:
			if state == State.PLAYING or state == State.PAUSED:
				toggle_pause()
			elif state == State.OVER:
				enter_menu()
		KEY_ENTER, KEY_KP_ENTER:
			if state == State.MENU or state == State.OVER:
				start_game()
		KEY_R:
			if state != State.MENU:
				start_game()
		KEY_M:
			_toggle_mute()


func _queue(new_direction: Vector2i) -> void:
	if state != State.COUNTDOWN and state != State.PLAYING:
		return
	var last := direction
	if not queued.is_empty():
		last = queued[queued.size() - 1]
	if new_direction == last or new_direction == -last:
		return
	if queued.size() >= 2:
		queued.pop_back()
	queued.append(new_direction)


func _swipe(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	if delta.length() < 32.0:
		return
	if absf(delta.x) > absf(delta.y):
		_queue(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
	else:
		_queue(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)


# ---------------------------------------------------------------- 设置

func _cycle_option(key: String) -> void:
	match key:
		"size":
			var size_index := SIZES.find(cols)
			size_index = (size_index + 1) % SIZES.size()
			cols = SIZES[size_index]
			rows = cols
			SaveData.board_size = cols
		"speed":
			var speed_index := SPEEDS.find(speed_ms)
			speed_index = (speed_index + 1) % SPEEDS.size()
			speed_ms = SPEEDS[speed_index]
			SaveData.speed_ms = speed_ms
		"level":
			level_index = (level_index + 1) % BoardLogic.level_count()
			SaveData.level = level_index
		"theme":
			theme_id = Palette.next_id(theme_id)
			SaveData.theme_id = theme_id
			_apply_theme()
	SaveData.save_data()
	_setup_board()
	_spawn_food()
	_update_menu_texts()
	hud.set_best(best)


func _update_menu_texts() -> void:
	var size_index := SIZES.find(cols)
	var speed_index := SPEEDS.find(speed_ms)
	hud.set_option("size", "棋盘大小 · %s" % SIZE_LABELS[maxi(size_index, 0)])
	hud.set_option("speed", "移动速度 · %s" % SPEED_LABELS[maxi(speed_index, 0)])
	hud.set_option("level", "关卡 · %s" % BoardLogic.LEVEL_NAMES[level_index])
	hud.set_option("theme", "主题 · %s" % Palette.display_name(theme_id))
	hud.set_level_description(
		"%s —— %s" % [
			BoardLogic.LEVEL_NAMES[level_index],
			BoardLogic.LEVEL_DESCRIPTIONS[level_index],
		]
	)


func _toggle_mute() -> void:
	SaveData.muted = not SaveData.muted
	SaveData.save_data()
	Sfx.set_muted(SaveData.muted)
	hud.set_muted(SaveData.muted)


func _apply_theme() -> void:
	colors = Palette.get_theme(theme_id)
	if _bg_material != null:
		_bg_material.set_shader_parameter("top_color", colors["bg_top"])
		_bg_material.set_shader_parameter("bottom_color", colors["bg_bottom"])
		_bg_material.set_shader_parameter("glow_color", colors["glow"])
	hud.apply_theme(colors)
	if is_node_ready():
		board_view.set_colors(colors)
		snake_view.apply_colors(colors)
		food_view.set_colors(colors)


# ---------------------------------------------------------------- 镜头与特效

func _fit_camera() -> void:
	var viewport := get_viewport_rect().size
	var board := Vector2(cols, rows) * CELL
	var margin := 1.28
	_base_zoom = minf(viewport.x / (board.x * margin), viewport.y / (board.y * margin))
	camera.zoom = Vector2(_base_zoom, _base_zoom)
	camera.position = Vector2(0.0, -16.0)


func _update_camera(delta: float) -> void:
	if shake > 0.05:
		shake = move_toward(shake, 0.0, delta * 36.0)
		camera.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	else:
		shake = 0.0
		camera.offset = Vector2.ZERO


func _update_hud(delta: float) -> void:
	hud_accum += delta
	if hud_accum < 0.1:
		return
	hud_accum = 0.0
	hud.update_stats(score, best, cells.size())
	hud.set_effects(effects)


func _spawn_popup(text: String, world: Vector2) -> void:
	var label := _popup_pool[_popup_index]
	_popup_index = (_popup_index + 1) % _popup_pool.size()

	if label.has_meta("fx_tween"):
		var running: Variant = label.get_meta("fx_tween")
		if running is Tween and running.is_valid():
			running.kill()

	label.text = text
	label.add_theme_color_override("font_color", colors["accent"])
	label.add_theme_color_override("font_outline_color", Color(colors["bg_bottom"], 0.95))
	label.position = world + Vector2(-CELL * 1.2, -CELL * 0.95)
	label.modulate.a = 1.0
	label.visible = true

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - CELL * 1.1, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tween.chain().tween_callback(_hide_popup.bind(label))
	label.set_meta("fx_tween", tween)


func _hide_popup(label: Label) -> void:
	label.visible = false


func _burst(world: Vector2, color: Color, amount: int, speed: float) -> void:
	var particles := _burst_pool[_burst_index]
	_burst_index = (_burst_index + 1) % _burst_pool.size()

	particles.position = world
	particles.amount = maxi(amount, 1)
	particles.emitting = true
	particles.restart()

	var material := particles.process_material as ParticleProcessMaterial
	material.initial_velocity_min = speed * 0.45
	material.initial_velocity_max = speed
	material.color = color


func _food_color() -> Color:
	if food_kind == "":
		return colors["food"]
	return POWERUP_COLORS.get(food_kind, colors["accent"])
