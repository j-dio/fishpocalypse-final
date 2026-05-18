class_name FishingBar
extends Control

var fish_pos: float = 0.5
var zone_pos: float = 0.35
var zone_size: float = 0.25

func _draw() -> void:
	var w := size.x
	var h := size.y

	# Background
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.04, 0.08, 0.13))

	# Catch zone — fixed blue band (center 40% of bar)
	var cz_y := h * 0.30
	var cz_h := h * 0.40
	draw_rect(Rect2(1.0, cz_y, w - 2.0, cz_h), Color(0.18, 0.48, 0.9, 0.15))
	draw_line(Vector2(1.0, cz_y), Vector2(w - 1.0, cz_y), Color(0.3, 0.6, 1.0, 0.7), 1.0)
	draw_line(Vector2(1.0, cz_y + cz_h), Vector2(w - 1.0, cz_y + cz_h), Color(0.3, 0.6, 1.0, 0.7), 1.0)

	# Player zone (green, hold to rise)
	var pz_top := zone_pos * h
	var pz_bot := (zone_pos + zone_size) * h
	draw_rect(Rect2(2.0, pz_top, w - 4.0, pz_bot - pz_top), Color(0.71, 0.91, 0.32, 0.78))
	draw_line(Vector2(2.0, pz_top), Vector2(w - 2.0, pz_top), Color(0.83, 1.0, 0.44), 2.0)

	# Fish cursor (red, 6 px tall)
	var fc_y := fish_pos * h
	draw_rect(Rect2(0.0, fc_y - 3.0, w, 6.0), Color(1.0, 0.42, 0.42))
	draw_rect(Rect2(0.0, fc_y - 1.0, w, 2.0), Color(1.0, 0.75, 0.75))
