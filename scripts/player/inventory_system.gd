class_name InventorySystem extends Node

signal slot_changed(slot_name: String)
signal item_dropped(data: Resource)
signal equipped_weapon_changed(weapon_node: Weapon)  # FIX: emit the node, not just data
signal equipped_pole_changed(pole: FishingPoleData)

@export var items_db: ItemsDB

var main_slot: FishWeaponData = null
var secondary_slot: FishWeaponData = null
var item_slot_1: HealingItemData = null
var item_slot_2: HealingItemData = null
var pole_slot: FishingPoleData = null

# FIX: track the actual Weapon nodes so Player can reparent them
var main_slot_node: Weapon = null
var secondary_slot_node: Weapon = null

var _active_weapon_slot: String = "main_slot"
var _health: HealthComponents = null


func set_health_component(h: HealthComponents) -> void:
	_health = h


func _ready() -> void:
	add_to_group("inventory_system")
	if items_db and not items_db.fishing_poles.is_empty():
		_equip_pole(items_db.fishing_poles[0])


# -------------------------
# PICKUP
# -------------------------
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
		_equip_pole(data)
		item_node._on_picked_up()


# -------------------------
# USE ITEM
# -------------------------
func use_item(slot: String) -> void:
	var data: HealingItemData = null
	match slot:
		"item_slot_1": data = item_slot_1
		"item_slot_2": data = item_slot_2
		_: return

	if data == null: return
	if _health == null:
		push_warning("InventorySystem: HealthComponent not injected — heal skipped")
		return

	_health.heal(data.base_heal_amount)
	print("[Inventory] Used healing item from %s (+%s HP)" % [slot, data.base_heal_amount])

	match slot:
		"item_slot_1": item_slot_1 = null
		"item_slot_2": item_slot_2 = null
	slot_changed.emit(slot)


# -------------------------
# DROP ITEM
# -------------------------
func drop_item(slot: String) -> void:
	var data: Resource = null
	match slot:
		"main_slot":
			data = main_slot
			main_slot = null
			main_slot_node = null   # FIX: clear node ref too
		"secondary_slot":
			data = secondary_slot
			secondary_slot = null
			secondary_slot_node = null
		"item_slot_1":
			data = item_slot_1
			item_slot_1 = null
		"item_slot_2":
			data = item_slot_2
			item_slot_2 = null
		_: return

	if data == null: return
	print("[Inventory] Dropped item from %s: %s" % [slot, data])
	item_dropped.emit(data)
	slot_changed.emit(slot)


# -------------------------
# WEAPON SLOT SWITCHING
# -------------------------
func set_active_weapon_slot(slot: String) -> void:
	if slot not in ["main_slot", "secondary_slot"]: return
	_active_weapon_slot = slot
	print("[Inventory] Active weapon slot: %s" % slot)

	# FIX: emit the node for whichever slot is now active
	var node := get_equipped_weapon_node()
	equipped_weapon_changed.emit(node)
	slot_changed.emit(slot)


# FIX: returns the Weapon node for the currently active slot
func get_equipped_weapon_node() -> Weapon:
	match _active_weapon_slot:
		"main_slot":      return main_slot_node
		"secondary_slot": return secondary_slot_node
	return null


# -------------------------
# WEAPON PICKUP
# -------------------------
func _pickup_weapon(data: FishWeaponData, item_node: Node3D) -> void:
	var weapon_node := item_node as Weapon
	if weapon_node == null:
		push_warning("InventorySystem: pickup item is not a Weapon node")
		return

	# FIX: defer the remove_child — physics callbacks forbid immediate reparenting
	item_node.get_parent().call_deferred("remove_child", item_node)

	if main_slot == null:
		main_slot = data
		main_slot_node = weapon_node
		print("[Inventory] Equipped MAIN: %s" % data)
		# FIX: defer the emit too so it fires after remove_child completes
		call_deferred("_emit_weapon_changed", weapon_node)
		slot_changed.emit("main_slot")
		return

	if secondary_slot == null:
		secondary_slot = data
		secondary_slot_node = weapon_node
		print("[Inventory] Equipped SECONDARY: %s" % data)
		if _active_weapon_slot == "secondary_slot":
			call_deferred("_emit_weapon_changed", weapon_node)
		slot_changed.emit("secondary_slot")
		return

	# Both slots full — swap active slot
	var old_data: FishWeaponData
	if _active_weapon_slot == "main_slot":
		old_data = main_slot
		main_slot = data
		main_slot_node = weapon_node
		print("[Inventory] Swapped MAIN: %s → %s" % [old_data, data])
	else:
		old_data = secondary_slot
		secondary_slot = data
		secondary_slot_node = weapon_node
		print("[Inventory] Swapped SECONDARY: %s → %s" % [old_data, data])

	call_deferred("_emit_weapon_changed", weapon_node)
	slot_changed.emit(_active_weapon_slot)
	item_dropped.emit(old_data)


# FIX: helper so we can call_deferred the emit safely after physics step
func _emit_weapon_changed(weapon_node: Weapon) -> void:
	equipped_weapon_changed.emit(weapon_node)


# -------------------------
# HEALING PICKUP
# -------------------------
func _pickup_healing(data: HealingItemData, item_node: Node3D) -> void:
	if item_slot_1 == null:
		item_slot_1 = data
		item_node._on_picked_up()
		print("[Inventory] Healing → SLOT 1: %s" % data)
		slot_changed.emit("item_slot_1")
		return
	if item_slot_2 == null:
		item_slot_2 = data
		item_node._on_picked_up()
		print("[Inventory] Healing → SLOT 2: %s" % data)
		slot_changed.emit("item_slot_2")
		return


# -------------------------
# POLE
# -------------------------
func _equip_pole(p: FishingPoleData) -> void:
	pole_slot = p
	print("[Inventory] Pole equipped: %s" % p)
	equipped_pole_changed.emit(p)
	slot_changed.emit("pole_slot")


func get_equipped_pole() -> FishingPoleData:
	return pole_slot
