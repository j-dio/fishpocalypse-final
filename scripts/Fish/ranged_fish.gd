extends "res://scripts/enemy.gd"

@export var projectile_scene: PackedScene
@export var shoot_audio: AudioStreamPlayer3D

const ATTACK_RANGE: float = 18.0
const PREFERRED_INNER: float = 10.0
const PREFERRED_OUTER: float = 14.0
const ATTACK_COOLDOWN: float = 2.5
const SHOOT_FRAME_DURATION: float = 0.4

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D

var _attack_timer: float = 0.0
var _shoot_frame_timer: float = 0.0

func _ready() -> void:
	max_health = 20
	speed = 0.8
	damage = 6
	super._ready()
	_sprite.animation = &"default"
	_sprite.frame = 0
	_sprite.pause()
	if projectile_scene != null: ProjectilePool.init_pool(projectile_scene)
	
func _physics_process(delta: float) -> void:
	if player_reference == null: return
	
	_attack_timer += delta
	
	if _shoot_frame_timer > 0.0:
		_shoot_frame_timer -= delta
		if _shoot_frame_timer <= 0.0:
			_sprite.frame = 0
			
	var player_pos: Vector3 = player_reference.global_position
	var dist: float = global_position.distance_to(player_pos)
	var dir: Vector3 = (player_pos - global_position).normalized()

	if dist > PREFERRED_OUTER:
		velocity = Vector3(dir.x * speed, velocity.y, dir.z * speed)
	elif dist < PREFERRED_INNER:
		velocity = Vector3(-dir.x * speed, velocity.y, -dir.z * speed)
	else:
		velocity = Vector3(0.0, velocity.y, 0.0)

	move_and_slide()

	for i: int in get_slide_collision_count():
		var collider: Object = get_slide_collision(i).get_collider()
		if collider.is_in_group(&"player"):
			_deal_damage_to_player(collider)

	if dist <= ATTACK_RANGE and _attack_timer >= ATTACK_COOLDOWN and ProjectilePool.can_shoot():
		_attack_timer = 0.0
		_shoot(dir)

func _shoot(dir: Vector3) -> void:
	if projectile_scene == null:
		push_warning("Ranged enemy; no projectile_scene assigned")
		return

	var proj: Node = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(dir.x * 1.5, 0.5, dir.z * 1.5)
	proj.init(dir, damage)

	if shoot_audio: shoot_audio.play()

	_sprite.frame = 1
	_shoot_frame_timer = SHOOT_FRAME_DURATION
