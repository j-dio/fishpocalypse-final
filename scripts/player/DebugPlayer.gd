extends CharacterBody3D

@onready var inventory: InventorySystem = $COMPONENTS/InventorySystem
@onready var health: HealthComponents = $COMPONENTS/HealthComponent
@onready var combat: CombatSystem = $COMPONENTS/CombatSystem

@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var weapon_holder: Marker3D = $Kamot

var _facing_dir := Vector3.FORWARD

@export var HP := 100
@export var CP := 100
@export var SP := 100
@export var RR_CP := 20
@export var RR_SP := 20

var cp_recharge_blocked := false
var cp_recharge_timer := 0.0

@export var walk_speed := 5.0
@export var run_speed := 9.0
@export var dodge_speed := 25.0
@export var dodge_time := 0.15
@export var gravity := 20.0

@onready var anim: AnimatedSprite3D = $Sprite3D
@onready var spotlight: SpotLight3D = $SpotLight3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _fishing_prompt: Label3D = $FishingPrompt

var last_valid_position := Vector3.ZERO
var previous_valid_position := Vector3.ZERO
var has_valid_position := false

const WATER_Y_LEVEL := -1.5
const SAVE_INTERVAL := 0.5
var save_timer := 0.0

var invincibility_timer := 0.0
const INVINCIBILITY_TIME := 0.5

var is_dodging := false
var dodge_timer := 0.0
var dodge_dir := Vector3.ZERO
var current_anim := ""

var ghost_interval := 0.01
var ghost_timer := 0.0
var was_moving_before_dodge := false

const _SFX_WALK  = preload("res://assets/audio/player_walk.mp3")
const _SFX_DODGE = preload("res://assets/audio/player_dodge.mp3")
const _SFX_HURT  = preload("res://assets/audio/player_hurt.mp3")


func _ready() -> void:
	add_to_group("player")
	if audio_player:
		audio_player.volume_db = 5.0
		audio_player.pitch_scale = 1.0
	inventory.slot_changed.connect(func(_slot): _log_inventory())
	# FIX: connect equipped_weapon_changed so swapping slots calls equip_weapon
	inventory.equipped_weapon_changed.connect(_on_equipped_weapon_changed)
	if spotlight: spotlight.visible = false
	var day_night_system = get_tree().get_first_node_in_group("day_night")
	if day_night_system:
		day_night_system.day_night_changed.connect(_on_night_changed)
	if health:
		health.initialize(HP)
		health.died.connect(_on_player_died)
		health.health_changed.connect(_on_health_changed)
	combat.dodged.connect(func(): pass)
	inventory.set_health_component(health)


func _physics_process(delta: float) -> void:
	save_timer += delta
	if cp_recharge_blocked:
		cp_recharge_timer -= delta
		if cp_recharge_timer <= 0.0:
			cp_recharge_blocked = false
	if not is_on_floor(): velocity.y -= gravity * delta
	else: velocity.y = 0
	if invincibility_timer > 0.0:
		invincibility_timer -= delta

	if is_dodging:
		dodge_timer -= delta
		ghost_timer -= delta
		
		velocity.x = dodge_dir.x * dodge_speed
		velocity.z = dodge_dir.z * dodge_speed
		_play_anim("dodge")
		if ghost_timer <= 0.0:
			ghost_timer = ghost_interval
			_spawn_dodge_ghost()
		
		if dodge_timer <= 0:
			is_dodging = false
			ghost_timer = 0.0
			if was_moving_before_dodge:
				_play_walk_sound()
		
		move_and_slide()
		_check_ocean_boundary()
		return

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("D"): input_dir.x += 1
	if Input.is_action_pressed("A"): input_dir.x -= 1
	if Input.is_action_pressed("S"): input_dir.z += 1
	if Input.is_action_pressed("W"): input_dir.z -= 1

	input_dir = input_dir.normalized()
	var speed := run_speed if Input.is_action_pressed("RUN") else walk_speed
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	_play_move_anim()
	move_and_slide()
	_check_ocean_boundary()
	_update_aim()


func _process(_delta: float) -> void:
	if _fishing_prompt != null and _fishing_prompt.visible:
		var t := Time.get_ticks_msec() / 1000.0
		_fishing_prompt.modulate.a = 0.6 + 0.4 * sin(t * 3.0)


func _update_aim() -> void:
	if camera == null: return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	if abs(ray_dir.y) < 0.001: return
	var t := (global_position.y - ray_origin.y) / ray_dir.y
	var world_mouse := ray_origin + ray_dir * t
	var aim := world_mouse - global_position
	aim.y = 0.0
	if aim.length_squared() < 0.001: return
	_facing_dir = aim.normalized()
	weapon_holder.look_at(global_position + _facing_dir, Vector3.UP)


func get_facing_dir() -> Vector3:
	return _facing_dir


func _on_night_changed(active: bool) -> void:
	if spotlight: spotlight.visible = active
func _on_health_changed(current: int, _maximum: int) -> void:
	HP = current
func _on_player_died() -> void:
	set_physics_process(false)


# FIX: signal now carries a Weapon node directly, no need to call get_equipped_weapon_node()
func _on_equipped_weapon_changed(weapon_node: Weapon) -> void:
	if weapon_node == null:
		for child in weapon_holder.get_children():
			child.queue_free()
		combat.equip_weapon_node(null)
		return
	for child in weapon_holder.get_children():
		if child != weapon_node:
			child.queue_free()
	if weapon_node.get_parent() != weapon_holder:
		weapon_holder.add_child(weapon_node)
	combat.equip_weapon_node(weapon_node)

func _check_ocean_boundary() -> void:
	if global_position.y <= WATER_Y_LEVEL:
		_push_back_to_land()
	else:
		if is_on_floor() and save_timer >= SAVE_INTERVAL:
			save_timer = 0.0
			previous_valid_position = last_valid_position
			last_valid_position = global_position
			has_valid_position = true


func _push_back_to_land() -> void:
	if not has_valid_position: return
	global_position = previous_valid_position
	velocity = Vector3.ZERO

func take_damage(amount: float) -> void:
	_take_damage(amount)


func _take_damage(amount: float) -> void:
	if invincibility_timer > 0.0: return
	_play_hurt_sound()
	_play_anim("hurt")
	health.take_damage(amount)
	invincibility_timer = INVINCIBILITY_TIME
	print("[Player] took %.1f damage" % amount)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		inventory.use_item("item_slot_1")
		_log_inventory()
	if event.is_action_pressed("ui_cancel"):
		inventory.drop_item("main_slot")
		_log_inventory()

func _log_inventory() -> void:
	print("[Inventory] main=%s | secondary=%s | item1=%s | item2=%s" % [
		inventory.main_slot.resource_path if inventory.main_slot else "empty",
		inventory.secondary_slot.resource_path if inventory.secondary_slot else "empty",
		inventory.item_slot_1.resource_path if inventory.item_slot_1 else "empty",
		inventory.item_slot_2.resource_path if inventory.item_slot_2 else "empty",
	])

func _play_move_anim() -> void:
	var is_moving := Input.is_action_pressed("W") or Input.is_action_pressed("S") \
		or Input.is_action_pressed("A") or Input.is_action_pressed("D")

	if Input.is_action_pressed("W"): _play_anim("walk_back")
	elif Input.is_action_pressed("S"): _play_anim("walk_front")
	elif Input.is_action_pressed("A"): _play_anim("walk_left")
	elif Input.is_action_pressed("D"): _play_anim("walk_right")
	else: _play_anim("idle")
	
	if audio_player:
		if is_moving and not is_dodging:
			_play_walk_sound()
		else:
			if audio_player.playing and audio_player.stream == preload("res://assets/audio/player_walk.mp3"):
				audio_player.stop()

func _play_walk_sound() -> void:
	if audio_player and not audio_player.playing:
		audio_player.stream = _SFX_WALK
		audio_player.volume_db = 1.0
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()

func _play_dodge_sound() -> void:
	if audio_player:
		audio_player.stop()
		audio_player.stream = _SFX_DODGE
		audio_player.volume_db = 10.0
		audio_player.pitch_scale = 1.5
		audio_player.play()

func _play_hurt_sound() -> void:
	if audio_player:
		audio_player.stream = _SFX_HURT
		audio_player.volume_db = 1.0
		audio_player.pitch_scale = 1.0
		audio_player.play()


func _play_anim(name: String) -> void:
	if current_anim == name: return
	current_anim = name
	anim.play(name)

func deduct_sp(amount: float) -> void:
	SP = max(SP - amount, 0)


func deduct_cp(amount: float) -> void:
	CP = max(CP - amount, 0)


func block_cp_recharge(duration: float) -> void:
	cp_recharge_blocked = true
	cp_recharge_timer = duration


func start_dodge(direction: Vector3) -> void:
	is_dodging = true
	dodge_timer = dodge_time
	dodge_dir = direction
	ghost_timer = 0.0
	was_moving_before_dodge = (direction != Vector3.ZERO)


func end_dodge() -> void:
	is_dodging = false
	ghost_timer = 0.0
	if was_moving_before_dodge:
		_play_walk_sound()


func show_fishing_prompt() -> void:
	if _fishing_prompt != null:
		_fishing_prompt.visible = true

func hide_fishing_prompt() -> void:
	if _fishing_prompt != null:
		_fishing_prompt.visible = false
		_fishing_prompt.modulate.a = 1.0

func play_fishing_anim(anim_name: String) -> void:
	_play_anim(anim_name)


func _spawn_dodge_ghost() -> void:
	var ghost := Node3D.new()
	ghost.set_script(load("res://scripts/player/dodge_ghost.gd"))
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.setup(anim, anim.frame)
