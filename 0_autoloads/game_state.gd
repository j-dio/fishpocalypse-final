extends Node

signal day_started()
signal night_started()
signal wave_cleared()
signal buff_day_reached()

var day_count: int = 1


func _ready() -> void:
	call_deferred("_emit_initial_day")


func _emit_initial_day() -> void:
	day_started.emit()
