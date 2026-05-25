# scripts/components/health_component.gd
class_name HealthComponent
extends Node

signal died()
signal health_changed(current: float, maximum: float)

@export var max_hp: float = 100.0
var current_hp: float = 0.0

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	current_hp = maxf(current_hp - amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)

func is_alive() -> bool:
	return current_hp > 0.0
