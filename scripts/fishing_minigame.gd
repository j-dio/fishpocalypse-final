class_name FishingMinigame
extends Control

signal caught(item: Resource)
signal failed()

enum State { IDLE, ACTIVE, RESULT_SUCCESS, RESULT_FAIL }

const RISE_ACCEL := 4.5
const FALL_GRAVITY := 3.2
const FILL_RATE := 0.35
const DRAIN_RATE := 0.22
const RESULT_DISPLAY_TIME := 0.8
const DIR_CHANGE_MIN := 0.15
const DIR_CHANGE_MAX := 0.45

@onready var _fish_bar: FishingBar = $CenterBox/ContentVBox/BarsHBox/FishBar
@onready var _catch_progress: ProgressBar = $CenterBox/ContentVBox/BarsHBox/CatchProgress

var _state: State = State.IDLE
var _fish_pos: float = 0.5
var _fish_vel: float = 0.0
var _fish_dir_timer: float = 0.0
var _zone_pos: float = 0.35
var _zone_vel: float = 0.0
var _zone_size: float = 0.25
var _fish_speed: float = 1.5
var _catch_val: float = 0.0
var _pending_item: Resource = null
var _result_timer: float = 0.0

func start(item: Resource, pole: FishingPoleData) -> void:
	_pending_item = item
	_zone_size = pole.base_bar_size
	_fish_speed = pole.base_lure_speed
	_fish_pos = 0.5
	_fish_vel = 0.0
	_zone_pos = 0.35
	_zone_vel = 0.0
	_catch_val = 0.25  # start at 25% so first drain doesn't instant-fail
	_fish_dir_timer = 0.0
	_set_state(State.ACTIVE)

func cancel() -> void:
	_set_state(State.IDLE)

func is_active() -> bool:
	return _state != State.IDLE

func _set_state(s: State) -> void:
	_state = s
	match s:
		State.IDLE:
			visible = false
		State.ACTIVE:
			visible = true
		State.RESULT_SUCCESS, State.RESULT_FAIL:
			_result_timer = RESULT_DISPLAY_TIME

func _process(delta: float) -> void:
	match _state:
		State.ACTIVE:
			_update_fish(delta)
			_update_zone(delta)
			_update_progress(delta)
			_fish_bar.fish_pos = _fish_pos
			_fish_bar.zone_pos = _zone_pos
			_fish_bar.zone_size = _zone_size
			_fish_bar.queue_redraw()
			_catch_progress.value = _catch_val
		State.RESULT_SUCCESS, State.RESULT_FAIL:
			_result_timer -= delta
			if _result_timer <= 0.0:
				var succeeded := (_state == State.RESULT_SUCCESS)
				_set_state(State.IDLE)
				if succeeded:
					caught.emit(_pending_item)
				else:
					failed.emit()

func _update_fish(delta: float) -> void:
	_fish_dir_timer -= delta
	if _fish_dir_timer <= 0.0:
		_fish_vel = randf_range(-_fish_speed, _fish_speed)
		_fish_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
	_fish_pos += _fish_vel * delta
	if _fish_pos <= 0.0:
		_fish_pos = 0.0
		_fish_vel = absf(_fish_vel)
	elif _fish_pos >= 1.0:
		_fish_pos = 1.0
		_fish_vel = -absf(_fish_vel)

func _update_zone(delta: float) -> void:
	if InputMap.has_action("INTERACT") and Input.is_action_pressed("INTERACT"):
		_zone_vel -= RISE_ACCEL * delta
	_zone_vel += FALL_GRAVITY * delta
	_zone_vel = clampf(_zone_vel, -10.0, 10.0)
	_zone_pos += _zone_vel * delta
	_zone_pos = clampf(_zone_pos, 0.0, 1.0 - _zone_size)

func _update_progress(delta: float) -> void:
	if _is_fish_in_zone():
		_catch_val += FILL_RATE * delta
	else:
		_catch_val -= DRAIN_RATE * delta
	_catch_val = clampf(_catch_val, 0.0, 1.0)
	if _catch_val >= 1.0:
		_set_state(State.RESULT_SUCCESS)
	elif _catch_val <= 0.0:
		_set_state(State.RESULT_FAIL)

func _is_fish_in_zone() -> bool:
	return _fish_pos >= _zone_pos and _fish_pos <= (_zone_pos + _zone_size)
