class_name InventorySystem
extends Node

signal slot_changed(slot_name: String)
signal item_dropped(data: Resource)

var main_slot: FishWeaponData = null
var secondary_slot: FishWeaponData = null
var item_slot_1: HealingItemData = null
var item_slot_2: HealingItemData = null

var _active_weapon_slot: String = "main_slot"

func pickup(item_node: Node3D) -> void:
	var data: Resource = item_node.get("data")
	if data == null:
		push_warning("InventorySystem: pickup called on node with no 'data' property")
		return
	if data is FishWeaponData:
		_pickup_weapon(data, item_node)
	elif data is HealingItemData:
		_pickup_healing(data, item_node)
	elif data is FishingPoleData:
		item_node._on_picked_up()

func _pickup_weapon(data: FishWeaponData, item_node: Node3D) -> void:
	if main_slot == null:
		main_slot = data
		item_node._on_picked_up()
		slot_changed.emit("main_slot")
	elif secondary_slot == null:
		secondary_slot = data
		item_node._on_picked_up()
		slot_changed.emit("secondary_slot")
	else:
		var old_data: FishWeaponData
		if _active_weapon_slot == "main_slot":
			old_data = main_slot
			main_slot = data
		else:
			old_data = secondary_slot
			secondary_slot = data
		item_node._on_picked_up()
		slot_changed.emit(_active_weapon_slot)
		item_dropped.emit(old_data)

func _pickup_healing(data: HealingItemData, item_node: Node3D) -> void:
	if item_slot_1 == null:
		item_slot_1 = data
		item_node._on_picked_up()
		slot_changed.emit("item_slot_1")
	elif item_slot_2 == null:
		item_slot_2 = data
		item_node._on_picked_up()
		slot_changed.emit("item_slot_2")

func use_item(slot: String) -> void:
	var data: HealingItemData
	match slot:
		"item_slot_1": data = item_slot_1
		"item_slot_2": data = item_slot_2
		_: return
	if data == null:
		return
	var health: HealthComponent = get_parent().get_node_or_null("HealthComponent")
	if health:
		health.heal(data.base_heal_amount)
	else:
		push_warning("InventorySystem: HealthComponent not found on player — heal skipped")
	match slot:
		"item_slot_1": item_slot_1 = null
		"item_slot_2": item_slot_2 = null
	slot_changed.emit(slot)

func drop_item(slot: String) -> void:
	var data: Resource = null
	match slot:
		"main_slot":      data = main_slot;      main_slot = null
		"secondary_slot": data = secondary_slot; secondary_slot = null
		"item_slot_1":    data = item_slot_1;    item_slot_1 = null
		"item_slot_2":    data = item_slot_2;    item_slot_2 = null
		_: return
	if data == null:
		return
	item_dropped.emit(data)
	slot_changed.emit(slot)

func set_active_weapon_slot(slot: String) -> void:
	if slot in ["main_slot", "secondary_slot"]:
		_active_weapon_slot = slot
