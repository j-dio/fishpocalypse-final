extends Control
class_name PlayerHUD

@export var hp_fill_texture: Texture2D
@export var cp_fill_texture: Texture2D
@export var sp_fill_texture: Texture2D

@onready var _hp_bar: ProgressBar = $Panel/VBoxContainer/HPRow/Control/HPBar
@onready var _cp_bar: ProgressBar = $Panel/VBoxContainer/CPRow/Control/CPBar
@onready var _sp_bar: ProgressBar = $Panel/VBoxContainer/SPRow/Control/SPBar

const _SLOT_SIZE := 48
const _SLOT_GAP  := 6
const _COLOR_EMPTY   := Color(0.08, 0.08, 0.08, 0.85)
const _COLOR_WEAPON  := Color(0.25, 0.55, 0.95, 0.9)
const _COLOR_ACTIVE  := Color(0.35, 0.90, 0.40, 1.0)
const _COLOR_ITEM    := Color(0.85, 0.45, 0.10, 0.9)

var _player = null
var _inventory: InventorySystem = null

var _slot_main: ColorRect       = null
var _slot_secondary: ColorRect  = null
var _slot_item1: ColorRect      = null
var _slot_item2: ColorRect      = null
var _active_slot: String        = "main_slot"


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
		_inventory.slot_changed.connect(_on_slot_changed)
		_inventory.equipped_weapon_changed.connect(_on_weapon_changed)
	_build_slot_ui()


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


# ─── Slot UI ──────────────────────────────────────────────────────────────────

func _build_slot_ui() -> void:
	# Attach to the UI_HUD parent so it's unscaled relative to player_stats
	var container := get_parent()
	if container == null: return

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left  = 12.0
	row.offset_top   = -(_SLOT_SIZE + 12)
	row.offset_right = 12.0 + (_SLOT_SIZE * 4) + (_SLOT_GAP * 3)
	row.offset_bottom = -12.0
	row.add_theme_constant_override("separation", _SLOT_GAP)
	container.add_child(row)

	_slot_main      = _make_slot("1", "M")
	_slot_secondary = _make_slot("2", "S")
	_slot_item1     = _make_slot("3", "I1")
	_slot_item2     = _make_slot("4", "I2")

	row.add_child(_slot_main)
	row.add_child(_slot_secondary)
	row.add_child(_slot_item1)
	row.add_child(_slot_item2)

	_refresh_all_slots()


func _make_slot(key_label: String, slot_label: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(_SLOT_SIZE, _SLOT_SIZE)
	rect.color = _COLOR_EMPTY

	var key := Label.new()
	key.text = key_label
	key.add_theme_font_size_override("font_size", 10)
	key.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	key.offset_left  = -14
	key.offset_top   = 2
	key.offset_right = -2
	key.offset_bottom = 14
	rect.add_child(key)

	var lbl := Label.new()
	lbl.text = slot_label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.add_child(lbl)

	return rect


func _refresh_all_slots() -> void:
	if _inventory == null: return
	_update_weapon_slot(_slot_main,      _inventory.main_slot,      "main_slot")
	_update_weapon_slot(_slot_secondary, _inventory.secondary_slot, "secondary_slot")
	_update_item_slot(_slot_item1, _inventory.item_slot_1)
	_update_item_slot(_slot_item2, _inventory.item_slot_2)


func _update_weapon_slot(rect: ColorRect, data: FishWeaponData, slot_name: String) -> void:
	if rect == null: return
	if data == null:
		rect.color = _COLOR_EMPTY
	elif slot_name == _active_slot:
		rect.color = _COLOR_ACTIVE
	else:
		rect.color = _COLOR_WEAPON


func _update_item_slot(rect: ColorRect, data: HealingItemData) -> void:
	if rect == null: return
	rect.color = _COLOR_ITEM if data != null else _COLOR_EMPTY


# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_slot_changed(slot_name: String) -> void:
	match slot_name:
		"main_slot":      _update_weapon_slot(_slot_main,      _inventory.main_slot,      "main_slot")
		"secondary_slot": _update_weapon_slot(_slot_secondary, _inventory.secondary_slot, "secondary_slot")
		"item_slot_1":    _update_item_slot(_slot_item1, _inventory.item_slot_1)
		"item_slot_2":    _update_item_slot(_slot_item2, _inventory.item_slot_2)


func _on_weapon_changed(weapon_node: Weapon) -> void:
	if _inventory == null: return
	_active_slot = _inventory._active_weapon_slot
	_update_weapon_slot(_slot_main,      _inventory.main_slot,      "main_slot")
	_update_weapon_slot(_slot_secondary, _inventory.secondary_slot, "secondary_slot")
