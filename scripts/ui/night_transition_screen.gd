extends Control
class_name NightTransitionScreen

# Assign a scary/horror .ttf font in the Inspector for full effect.
# Without it the label falls back to Godot's default font.
@export var scary_font: Font
@export var display_duration: float = 3.5

var _night_label: Label
var _timer: float    = 0.0
var _showing: bool   = false
var _day_cycle: Node = null
var _splats: Array   = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index      = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible      = false
	set_process(false)

	_build_label()
	_generate_splats()

	_day_cycle = get_tree().get_first_node_in_group(&"day_night")
	if _day_cycle:
		_day_cycle.night_incoming.connect(_on_night_incoming)

func _build_label() -> void:
	_night_label = Label.new()
	_night_label.set_anchor(SIDE_LEFT,   0.5)
	_night_label.set_anchor(SIDE_RIGHT,  0.5)
	_night_label.set_anchor(SIDE_TOP,    0.5)
	_night_label.set_anchor(SIDE_BOTTOM, 0.5)
	_night_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_night_label.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_night_label.offset_left   = -500.0
	_night_label.offset_top    = -120.0
	_night_label.offset_right  =  500.0
	_night_label.offset_bottom =  120.0
	_night_label.add_theme_color_override("font_color",         Color(0.90, 0.02, 0.02, 1.0))
	_night_label.add_theme_color_override("font_outline_color", Color(0.0,  0.0,  0.0,  1.0))
	_night_label.add_theme_color_override("font_shadow_color",  Color(0.4,  0.0,  0.0,  0.8))
	_night_label.add_theme_constant_override("outline_size",  10)
	_night_label.add_theme_constant_override("shadow_offset_x", 4)
	_night_label.add_theme_constant_override("shadow_offset_y", 6)
	_night_label.add_theme_font_size_override("font_size", 120)
	_night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_night_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_night_label.text = "Night 1"
	add_child(_night_label)

func _generate_splats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in 28:
		var main_r: float = rng.randf_range(12.0, 55.0)
		_splats.append({
			"px": rng.randf_range(0.02, 0.98),
			"py": rng.randf_range(0.02, 0.98),
			"r":  main_r,
			"drip_h": rng.randf_range(0.0, 90.0),
			"drip_w": rng.randf_range(5.0, main_r * 0.4),
			"color": Color(
				rng.randf_range(0.35, 0.75),
				0.0,
				0.0,
				rng.randf_range(0.75, 1.0)
			),
		})
		# scatter small satellite drops around each main splat
		for _s in rng.randi_range(1, 4):
			var angle: float = rng.randf_range(0.0, TAU)
			var dist: float  = rng.randf_range(main_r * 0.8, main_r * 2.5)
			_splats.append({
				"px": clampf(rng.randf_range(0.02, 0.98) + cos(angle) * dist / 1920.0, 0.01, 0.99),
				"py": clampf(rng.randf_range(0.02, 0.98) + sin(angle) * dist / 1080.0, 0.01, 0.99),
				"r":  rng.randf_range(3.0, 14.0),
				"drip_h": 0.0,
				"drip_w": 0.0,
				"color": Color(
					rng.randf_range(0.4, 0.8),
					0.0,
					0.0,
					rng.randf_range(0.6, 1.0)
				),
			})

func _on_night_incoming(night_number: int) -> void:
	_night_label.text = "Night %d" % night_number
	if scary_font:
		_night_label.add_theme_font_override("font", scary_font)
	visible  = true
	_timer   = 0.0
	_showing = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= display_duration:
		_showing = false
		visible  = false
		set_process(false)
		if _day_cycle:
			_day_cycle.begin_night()

func _draw() -> void:
	# Black background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 1.0))

	# Blood splatters — positions are stored as 0–1 ratios, scaled to current size
	for s in _splats:
		var pos := Vector2(s.px * size.x, s.py * size.y)
		draw_circle(pos, s.r, s.color)
		if s.drip_h > 0.0:
			var half_w: float = s.drip_w * 0.5
			draw_rect(Rect2(pos.x - half_w, pos.y, s.drip_w, s.drip_h), s.color)
