class_name Projectile extends Area3D

var _data: ProjectileData
var _direction: Vector3 = Vector3.FORWARD
var _lifetime: float = 0.0


func setup(data: ProjectileData, direction: Vector3) -> void:
	_data = data
	_direction = direction
	_lifetime = data.lifetime


func _process(delta: float) -> void:
	global_position += _direction * _data.speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_data.damage)
	queue_free()
