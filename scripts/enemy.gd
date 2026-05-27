extends CharacterBody3D

@export var player_reference: CharacterBody3D
@export var max_health: int  = 30
@export var speed: float     = 1.0
@export var damage: int      = 5
@export var is_elite: bool   = false

# quantized movement; 8 compass directions = 45 degree slots
# raise to 16 if movement feels too blocky; costs nothing extra
# (2(PI)/8) rad per slot; kung ilison nimo ang DIR_SLOTS, compute pud balik SLOT_SIZE
const DIR_SLOTS: int   = 8
const SLOT_SIZE: float =  0.785  

const GRAVITY: float        = 9.8
const JUMP_FORCE: float     = 5.0
const JUMP_COOLDOWN: float  = 0.6
const STUCK_DIST_SQ: float  = 0.025
const STUCK_THRESHOLD: float = 0.3

var health: int
var _jump_timer: float   = 0.0
var _stuck_timer: float  = 0.0
var _last_pos: Vector3

# precomputed direction table; built once in _ready, read every frame
# index 0..DIR_SLOTS-1 maps slot -> unit Vector3 on XZ plane
var _dir_table: Array[Vector3] = []
func _ready() -> void:
	health = max_health
	if is_elite: _apply_elite_modifiers()
	_last_pos = global_position
	_build_dir_table()
	
func reset() -> void:
	health    = max_health
	_jump_timer  = 0.0
	_stuck_timer = 0.0
	_last_pos    = global_position
	velocity     = Vector3.ZERO
	if is_elite:
		_apply_elite_modifiers()
		
func _build_dir_table() -> void:
	_dir_table.resize(DIR_SLOTS)
	for i in DIR_SLOTS:
		var a: float = i * SLOT_SIZE
		_dir_table[i] = Vector3(cos(a), 0.0, sin(a))
		
func _apply_elite_modifiers() -> void:
	max_health  = int(max_health * 3)
	health      = max_health
	damage      = int(damage * 2)
	speed      *= 1.3
	scale      *= 1.4
	
func _physics_process(delta: float) -> void:
	if player_reference == null: return
	
	# gravity
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	else: velocity.y = 0.0
	if _jump_timer > 0.0: _jump_timer -= delta
	
	# quantized direction; atan2 + slot snap instead of .normalized()
	var diff: Vector3  = player_reference.global_position - global_position
	var angle: float   = atan2(diff.z, diff.x)
	# fposmod keeps angle in [0, TAU) before dividing into slots
	var slot: int      = int(round(fposmod(angle, TAU) / SLOT_SIZE)) % DIR_SLOTS
	var dir: Vector3   = _dir_table[slot]
	
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	
	# collision; cache is_in_group result; avoid calling it twice per collider
	var blocked: bool = false
	for i: int in get_slide_collision_count():
		var col    := get_slide_collision(i)
		var other  := col.get_collider()
		var is_player: bool = other.is_in_group(&"player")
		if is_player:
			_deal_damage_to_player(other)
			continue  # player can't block terrain; skip normal check
		if other is StaticBody3D:
			if abs(col.get_normal().y) < 0.5:
				blocked = true
				
	# stuck detection; distance_squared avoids sqrt
	var moved_sq: float = global_position.distance_squared_to(_last_pos)
	if moved_sq < STUCK_DIST_SQ and blocked:
		_stuck_timer += delta
	else: _stuck_timer = 0.0
	_last_pos = global_position
	
	if _stuck_timer >= STUCK_THRESHOLD and is_on_floor() and _jump_timer <= 0.0:
		velocity.y   = JUMP_FORCE
		_stuck_timer = 0.0
		_jump_timer  = JUMP_COOLDOWN
		
func _deal_damage_to_player(p: CharacterBody3D) -> void:
	p._take_damage(damage)
	
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0: die()
	
func die() -> void:
	# notify spawner so it returns this node to the pool
	# instead of queue_free() which breaks pooling
	var spawner := get_parent()
	if spawner.has_method(&"_release_to_pool"):
		spawner._release_to_pool(self)
	else:
		queue_free()  # fallback if not pooled
