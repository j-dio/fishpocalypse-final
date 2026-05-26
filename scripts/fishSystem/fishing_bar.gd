class_name FishingBar
extends Control

var fish_pos: float = 0.5
var zone_pos: float = 0.35
var zone_size: float = 0.3

@export var bg_top_color: Color = Color(0.02, 0.05, 0.10)
@export var bg_bottom_color: Color = Color(0.06, 0.12, 0.20)
@export var bg_margin: float = 0.0

var _gradient_tex := GradientTexture1D.new()

func _ready() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([bg_top_color, bg_bottom_color])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	_gradient_tex.gradient = g


func _draw() -> void:
	var w := size.x
	var h := size.y

	draw_texture_rect(
		_gradient_tex,
		Rect2(bg_margin, bg_margin, w - bg_margin * 2.0, h - bg_margin * 2.0),
		false
	)

	var cz_y := h * 0.30
	var cz_h := h * 0.40

	draw_rect(Rect2(1.0, cz_y, w - 2.0, cz_h), Color(0.18, 0.48, 0.9, 0.15))
	draw_line(Vector2(1.0, cz_y), Vector2(w - 1.0, cz_y), Color(0.3, 0.6, 1.0, 0.7), 1.0)
	draw_line(Vector2(1.0, cz_y + cz_h), Vector2(w - 1.0, cz_y + cz_h), Color(0.3, 0.6, 1.0, 0.7), 1.0)

	var pz_top := zone_pos * h
	var pz_bot := (zone_pos + zone_size) * h

	draw_rect(Rect2(2.0, pz_top, w - 4.0, pz_bot - pz_top), Color("16ae00"))
	draw_line(Vector2(2.0, pz_top), Vector2(w - 2.0, pz_top), Color(1.0, 0.89, 0.928, 1.0), 2.0)

	var fc_y := fish_pos * h

	draw_rect(Rect2(0.0, fc_y - 3.0, w, 2.0), Color("ff002fff"))
	draw_rect(Rect2(0.0, fc_y - 1.0, w, 1.0), Color(0.778, 0.0, 0.215, 1.0))
