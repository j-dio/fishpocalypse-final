# scripts/fishSystem/shore_zone.gd
class_name ShoreZone
extends Area3D

signal player_entered_shore(player: Node3D)
signal player_exited_shore()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("shore_zones")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_entered_shore.emit(body)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_exited_shore.emit()
