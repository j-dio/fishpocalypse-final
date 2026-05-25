class_name BuffSystem extends Node

signal buff_applied(buff: BuffData)
signal buff_expired(buff: BuffData)
signal stats_changed()

# Array[{data: BuffData, remaining: float}]
var _active: Array[Dictionary] = []


func _ready() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.buff_applied.connect(_on_gamestate_buff_applied)
		gs.night_started.connect(_on_night_started)


func _process(delta: float) -> void:
	var expired: Array[BuffData] = []
	for entry in _active:
		if entry.data.duration < 0.0:
			continue
		entry.remaining -= delta
		if entry.remaining <= 0.0:
			expired.append(entry.data)
	for buff in expired:
		remove_buff(buff)
		buff_expired.emit(buff)
	if not expired.is_empty():
		stats_changed.emit()


func apply_buff(buff: BuffData) -> void:
	for entry in _active:
		if entry.data == buff:
			entry.remaining = buff.duration
			buff_applied.emit(buff)
			stats_changed.emit()
			return
	_active.append({ "data": buff, "remaining": buff.duration })
	buff_applied.emit(buff)
	stats_changed.emit()


func remove_buff(buff: BuffData) -> void:
	for i in _active.size():
		if _active[i].data == buff:
			_active.remove_at(i)
			return


func get_multiplier(stat: BuffData.StatTarget) -> float:
	var result := 1.0
	for entry in _active:
		if entry.data.stat_target == stat:
			result *= entry.data.multiplier
	return result


func get_addend(stat: BuffData.StatTarget) -> float:
	var result := 0.0
	for entry in _active:
		if entry.data.stat_target == stat:
			result += entry.data.addend
	return result


func _on_gamestate_buff_applied(buff: BuffData) -> void:
	apply_buff(buff)


func _on_night_started() -> void:
	var removed := false
	for i in range(_active.size() - 1, -1, -1):
		if _active[i].data.duration >= 0.0:
			_active.remove_at(i)
			removed = true
	if removed:
		stats_changed.emit()
