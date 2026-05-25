class_name Health extends Node

signal damaged(amount: float)
signal healed(amount: float)
signal died()

@export var max_hp: float = 100.0

var current_hp: float


func _ready() -> void:
	current_hp = max_hp


func take_damage(amount: float) -> void:
	if current_hp <= 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	damaged.emit(amount)
	if current_hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if current_hp <= 0.0:
		return
	var prev := current_hp
	current_hp = minf(current_hp + amount, max_hp)
	if current_hp > prev:
		healed.emit(current_hp - prev)
