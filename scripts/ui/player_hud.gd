extends Control
class_name PlayerHUD

const INVENTORY_SLOTS = preload("res://scenes/ui/InventorySlots.tscn")
const NightTransitionScreenScript = preload("res://scripts/ui/night_transition_screen.gd")

@export var hp_fill_texture: Texture2D
@export var cp_fill_texture: Texture2D
@export var sp_fill_texture: Texture2D

@onready var _hp_bar: ProgressBar = $Panel/VBoxContainer/HPRow/Control/HPBar
@onready var _cp_bar: ProgressBar = $Panel/VBoxContainer/CPRow/Control/CPBar
@onready var _sp_bar: ProgressBar = $Panel/VBoxContainer/SPRow/Control/SPBar
@onready var _wave_label: Label   = $"../EnemyCounter"

var _player = null
var _inventory: InventorySystem = null
var _night_timer_label: Label   = null


func _ready() -> void:
	_apply_textures()
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("PlayerHUD: no node in group 'player'")
		return
	var health = _player.get_node_or_null("COMPONENTS/HealthComponent")
	if health:
		health.health_changed.connect(_on_health_changed)
		_on_health_changed(health.current_hp, health.max_hp)
	_inventory = _player.get_node_or_null("COMPONENTS/InventorySystem")
	if _inventory:
		var slots: InventorySlots = INVENTORY_SLOTS.instantiate()
		get_parent().add_child(slots)
		slots.setup(_inventory)
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner:
		spawner.wave_updated.connect(_on_wave_updated)

	_setup_night_timer()
	_setup_night_transition_screen()

	var dns := get_tree().get_first_node_in_group(&"day_night")
	if dns:
		dns.time_to_night_changed.connect(_on_time_to_night_changed)
		dns.day_night_changed.connect(_on_day_night_changed)


func _setup_night_timer() -> void:
	_night_timer_label = Label.new()
	_night_timer_label.name = "NightTimer"
	get_parent().add_child(_night_timer_label)

	# Mirror EnemyCounter anchors — top-right corner, just above it.
	# Set layout properties after add_child so Godot applies them correctly.
	_night_timer_label.anchor_left     = 1.0
	_night_timer_label.anchor_right    = 1.0
	_night_timer_label.anchor_top      = 0.0
	_night_timer_label.anchor_bottom   = 0.0
	_night_timer_label.offset_left     = -1219.0
	_night_timer_label.offset_top      =  569.0
	_night_timer_label.offset_right    = -1011.0
	_night_timer_label.offset_bottom   =  609.0
	_night_timer_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_night_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_night_timer_label.add_theme_constant_override("outline_size", 5)
	_night_timer_label.add_theme_font_size_override("font_size", 22)
	_night_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_night_timer_label.text = "Night in: 4:00"


func _setup_night_transition_screen() -> void:
	var nts: Control = NightTransitionScreenScript.new()
	get_parent().add_child(nts)


func _apply_textures() -> void:
	_apply_bar_texture(_hp_bar, hp_fill_texture)
	_apply_bar_texture(_cp_bar, cp_fill_texture)
	_apply_bar_texture(_sp_bar, sp_fill_texture)


func _apply_bar_texture(bar: ProgressBar, tex: Texture2D) -> void:
	if tex == null: return
	var style := StyleBoxTexture.new()
	style.texture = tex
	bar.add_theme_stylebox_override("fill", style)


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current


func _on_wave_updated(remaining: int) -> void:
	if _wave_label:
		_wave_label.text = "Enemies: %d" % remaining


func _on_time_to_night_changed(seconds: float) -> void:
	if _night_timer_label == null: return
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	_night_timer_label.text = "Night in: %d:%02d" % [mins, secs]


func _on_day_night_changed(is_night_active: bool) -> void:
	if _night_timer_label:
		_night_timer_label.visible = not is_night_active


func _process(_delta: float) -> void:
	if _player == null: return
	_cp_bar.value = _player.CP
	_sp_bar.value = _player.SP
