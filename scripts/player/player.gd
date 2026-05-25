class_name Player extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var run_speed: float = 9.0
@export var gravity: float = 20.0
@export var max_cp: float = 100.0
@export var cp_recharge_rate: float = 20.0
@export var max_sp: float = 100.0
@export var sp_regen_rate: float = 15.0
@export var dodge_speed: float = 18.0
@export var dodge_duration: float = 0.15

var cp: float
var sp: float

var _cp_recharge_delay: float = 0.0
var _is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _aim_dir: Vector3 = Vector3.FORWARD

@onready var _health: Health = $Health


func _ready() -> void:
	add_to_group("player")
	cp = max_cp
	sp = max_sp


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if _is_dodging:
		_tick_dodge(delta)
	else:
		_handle_movement()
	_handle_aim()
	_regen_stats(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0


func _handle_movement() -> void:
	var dir := _get_move_input()
	var speed := run_speed if Input.is_action_pressed("RUN") else walk_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _tick_dodge(delta: float) -> void:
	_dodge_timer -= delta
	velocity.x = _dodge_dir.x * dodge_speed
	velocity.z = _dodge_dir.z * dodge_speed
	if _dodge_timer <= 0.0:
		_is_dodging = false


func _handle_aim() -> void:
	var aim := _get_aim_direction()
	if aim != Vector3.ZERO:
		_aim_dir = aim
	look_at(global_position + Vector3(_aim_dir.x, 0.0, _aim_dir.z), Vector3.UP)


func _regen_stats(delta: float) -> void:
	if _cp_recharge_delay > 0.0:
		_cp_recharge_delay -= delta
	else:
		cp = minf(cp + cp_recharge_rate * delta, max_cp)
	sp = minf(sp + sp_regen_rate * delta, max_sp)


func get_aim_direction() -> Vector3:
	return _aim_dir


func deduct_cp(amount: float) -> void:
	cp = maxf(cp - amount, 0.0)


func deduct_sp(amount: float) -> void:
	sp = maxf(sp - amount, 0.0)


func block_cp_recharge(duration: float) -> void:
	_cp_recharge_delay = maxf(_cp_recharge_delay, duration)


func start_dodge(direction: Vector3) -> void:
	_is_dodging = true
	_dodge_timer = dodge_duration
	_dodge_dir = direction


func _get_move_input() -> Vector3:
	var input := Vector2.ZERO
	if Input.is_action_pressed("D"): input.x += 1.0
	if Input.is_action_pressed("A"): input.x -= 1.0
	if Input.is_action_pressed("S"): input.y += 1.0
	if Input.is_action_pressed("W"): input.y -= 1.0
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector3(input.x, 0.0, input.y).normalized()
	var cam_fwd := -camera.global_transform.basis.z
	var cam_right := camera.global_transform.basis.x
	cam_fwd.y = 0.0
	cam_right.y = 0.0
	return (cam_right * input.x + cam_fwd * input.y).normalized()


func _get_aim_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var plane := Plane(Vector3.UP, global_position.y)
	var intersection := plane.intersects_ray(ray_origin, ray_dir)
	if intersection and (intersection - global_position).length() > 0.1:
		return (intersection - global_position).normalized()
	return Vector3.ZERO
