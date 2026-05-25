extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 9.0
@export var dodge_speed := 18.0
@export var dodge_time := 0.15
@export var gravity := 20.0

@onready var anim: AnimatedSprite3D = $Sprite3D
@onready var inventory: InventorySystem = $InventorySystem
@onready var health: HealthComponent = $HealthComponent
@onready var spotlight: SpotLight3D = $SpotLight3D

var last_valid_position := Vector3.ZERO
var previous_valid_position := Vector3.ZERO
var has_valid_position := false
const WATER_Y_LEVEL := -1.5
const SAVE_INTERVAL := 0.5
var save_timer := 0.0

var is_dodging := false
var dodge_timer := 0.0
var dodge_dir := Vector3.ZERO
var current_anim := ""

func _ready() -> void:
	add_to_group("player")
	inventory.slot_changed.connect(func(_slot): _log_inventory())
	if spotlight:
		spotlight.visible = false
	var day_night_system = get_tree().get_first_node_in_group("day_night")
	if day_night_system:
		day_night_system.day_night_changed.connect(_on_night_changed)
		print("[DNS] Found")

func _on_night_changed(active: bool) -> void:
	if spotlight:
		spotlight.visible = active

func _physics_process(delta: float) -> void:
	save_timer += delta

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	if is_dodging:
		dodge_timer -= delta
		velocity.x = dodge_dir.x * dodge_speed
		velocity.z = dodge_dir.z * dodge_speed
		_play_anim("dodge")
		if dodge_timer <= 0:
			is_dodging = false
		move_and_slide()
		_check_ocean_boundary()
		return

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("D"): input_dir.x += 1
	if Input.is_action_pressed("A"): input_dir.x -= 1
	if Input.is_action_pressed("S"): input_dir.z += 1
	if Input.is_action_pressed("W"): input_dir.z -= 1
	input_dir = input_dir.normalized()

	var speed = walk_speed
	if Input.is_action_pressed("RUN"): speed = run_speed

	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	if Input.is_action_just_pressed("DODGE") and input_dir != Vector3.ZERO:
		is_dodging = true
		dodge_timer = dodge_time
		dodge_dir = input_dir
		move_and_slide()
		return

	if Input.is_action_just_pressed("SHOOT"):
		print("Shoot! (CombatSystem not yet wired — Phase 3)")

	_play_move_anim()
	move_and_slide()
	_check_ocean_boundary()

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
	if not has_valid_position:
		return
	global_position = previous_valid_position
	velocity = Vector3.ZERO

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
	if Input.is_action_pressed("W"):
		_play_anim("walk_back")
	elif Input.is_action_pressed("S"):
		_play_anim("walk_front")
	elif Input.is_action_pressed("A"):
		_play_anim("walk_left")
	elif Input.is_action_pressed("D"):
		_play_anim("walk_right")
	else:
		_play_anim("idle")

func _play_anim(name: String) -> void:
	if current_anim == name:
		return
	current_anim = name
	anim.play(name)
