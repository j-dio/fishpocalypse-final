extends Control
class_name PlayerHUD

@export var hp_fill_texture: Texture2D
@export var cp_fill_texture: Texture2D
@export var sp_fill_texture: Texture2D

@onready var _hp_bar: ProgressBar = $Panel/VBoxContainer/HPRow/HPBar
@onready var _cp_bar: ProgressBar = $Panel/VBoxContainer/CPRow/CPBar
@onready var _sp_bar: ProgressBar = $Panel/VBoxContainer/SPRow/SPBar

var _player = null


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


func _process(_delta: float) -> void:
	if _player == null: return
	_cp_bar.value = _player.CP
	_sp_bar.value = _player.SP
