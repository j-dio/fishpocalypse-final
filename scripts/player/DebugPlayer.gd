extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 9.0
@export var dodge_speed := 25.0
@export var dodge_time := 0.15
@export var gravity := 20.0

@onready var anim: AnimatedSprite3D = $Sprite3D
@onready var inventory: InventorySystem = $InventorySystem
@onready var health: HealthComponent = $HealthComponent
@onready var spotlight: SpotLight3D = $SpotLight3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

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

# Naa nako taas sa arasaka tower
var ghost_interval := 0.01
var ghost_timer := 0.0
var was_moving_before_dodge := false


func _ready() -> void:
	add_to_group("player")
	# Setup single audio player
	if audio_player:
		audio_player.volume_db = 5.0
		audio_player.pitch_scale = 1.0
		
	inventory.slot_changed.connect(func(_slot): _log_inventory())
	if spotlight: spotlight.visible = false
	
	var day_night_system = get_tree().get_first_node_in_group("day_night")
	if day_night_system:
		day_night_system.day_night_changed.connect(_on_night_changed)
		print("[DNS] Found")


func _physics_process(delta: float) -> void:
	if not is_on_floor(): velocity.y -= gravity * delta
	else: velocity.y = 0
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
			# Resume walk sound if player was moving
			if was_moving_before_dodge:
				_play_walk_sound()
		
		move_and_slide()
		_check_ocean_boundary()
		return

	# Input Direction
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

	# Dodge
	if Input.is_action_just_pressed("DODGE") and input_dir != Vector3.ZERO:
		is_dodging = true
		dodge_timer = dodge_time
		dodge_dir = input_dir
		ghost_timer = 0.0
		
		was_moving_before_dodge = (input_dir != Vector3.ZERO)
		# Play Dodge Sound (one-shot)
		_play_dodge_sound()
		
		return
	# Shoot
	if Input.is_action_just_pressed("SHOOT"):
		print("Shoot! (CombatSystem not yet wired — Phase 3)")
	_play_move_anim()
	move_and_slide()
	
	
func _on_night_changed(active: bool) -> void:
	if spotlight: spotlight.visible = active
	
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
	var is_moving = Input.is_action_pressed("W") or \
					Input.is_action_pressed("S") or \
					Input.is_action_pressed("A") or \
					Input.is_action_pressed("D")
	if Input.is_action_pressed("W"): _play_anim("walk_back")
	elif Input.is_action_pressed("S"): _play_anim("walk_front")
	elif Input.is_action_pressed("A"): _play_anim("walk_left")
	elif Input.is_action_pressed("D"): _play_anim("walk_right")
	else: _play_anim("idle")
	
	# Handle walking sound
	if audio_player:
		if is_moving and not is_dodging:
			_play_walk_sound()
		else:
			if audio_player.playing and audio_player.stream == preload("res://assets/audio/player_walk.mp3"):
				audio_player.stop()
				
				
func _play_walk_sound() -> void:
	if audio_player and not audio_player.playing:
		audio_player.stream = preload("res://assets/audio/player_walk.mp3")
		audio_player.volume_db = 1.0
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()
		
		
func _play_dodge_sound() -> void:
	if audio_player:
		audio_player.stop()
		audio_player.stream = preload("res://assets/audio/player_dodge.mp3")
		audio_player.volume_db = 10.0
		audio_player.pitch_scale = 1.5
		audio_player.play()
		
		
func _play_anim(name: String) -> void:
	if current_anim == name: return
	current_anim = name
	anim.play(name)
	
	
func _spawn_dodge_ghost() -> void:
	var ghost := Node3D.new()
	ghost.set_script(load("res://scripts/player/dodge_ghost.gd"))
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.setup(anim, anim.frame)
