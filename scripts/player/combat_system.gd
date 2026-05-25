class_name CombatSystem extends Node

signal fired(weapon: FishWeaponData)
signal dodged()
signal weapon_swapped(weapon: FishWeaponData)

@export var dodge_sp_cost: float = 25.0
@export var projectile_scene: PackedScene

@onready var _player: Player = get_parent()
@onready var _inventory: InventorySystem = get_parent().get_node("InventorySystem")
@onready var _buffs: BuffSystem = get_parent().get_node("BuffSystem")

var _shot_delay_timer: float = 0.0


func _process(delta: float) -> void:
	if _shot_delay_timer > 0.0:
		_shot_delay_timer -= delta

	if Input.is_action_just_pressed("SHOOT"):
		fire()
	if Input.is_action_just_pressed("DODGE"):
		dodge()


func fire() -> void:
	var weapon := _inventory.equipped_weapon
	if weapon == null or _shot_delay_timer > 0.0:
		return
	if _player.cp < weapon.base_recharge_cost:
		return

	var shot_delay := weapon.base_shot_delay * _buffs.get_multiplier(BuffData.StatTarget.SHOT_DELAY)
	_shot_delay_timer = shot_delay
	_player.deduct_cp(weapon.base_recharge_cost)
	_player.block_cp_recharge(shot_delay)

	var count := weapon.base_projectiles_per_shot
	var aim := _player.get_aim_direction()
	for i in count:
		var angle := 0.0
		if count > 1:
			angle = deg_to_rad(10.0 * (i - (count - 1) / 2.0))
		_spawn_projectile(weapon.projectile, aim.rotated(Vector3.UP, angle))

	fired.emit(weapon)


func dodge() -> void:
	if _player.sp < dodge_sp_cost:
		return
	var move_dir := Vector3(_player.velocity.x, 0.0, _player.velocity.z).normalized()
	if move_dir == Vector3.ZERO:
		move_dir = _player.get_aim_direction()
	_player.deduct_sp(dodge_sp_cost)
	_player.start_dodge(move_dir)
	dodged.emit()


func swap_weapon() -> void:
	_inventory.cycle_weapon(1)
	if _inventory.equipped_weapon:
		weapon_swapped.emit(_inventory.equipped_weapon)


func _spawn_projectile(data: ProjectileData, direction: Vector3) -> void:
	if not projectile_scene:
		return
	var p: Projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = _player.global_position + Vector3(0.0, 0.5, 0.0)
	p.setup(data, direction)
