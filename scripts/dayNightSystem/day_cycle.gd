extends Node3D

signal day_night_changed(is_night_active: bool)

@export var day_length_sec: int = 360
@export var speed_factor: float = 1.0

@onready var light: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment

var time_accumulated: float = 0.0
var is_night: bool = false
var sky_material: ProceduralSkyMaterial
var _env: Environment
# ADDED: cached on _ready was fetched via world_env.environment on every state call

func _ready() -> void:
	add_to_group("day_night")
	# CHANGED: cache env once instead of re-fetching in every _set_*_state call
	_env = world_env.environment
	if _env and _env.sky and _env.sky.sky_material:
		sky_material = _env.sky.sky_material as ProceduralSkyMaterial
	_set_day_state()
	
func _process(delta: float) -> void:
	# CHANGED: was only accumulating during day but never ticking during night,
	# freezing time until return_to_day() was called. Guard removed, accumulate always.
	time_accumulated += delta * speed_factor
	# CHANGED: use >= check without is_night guard so night can trigger once per cycle
	if time_accumulated >= day_length_sec and not is_night:
		time_accumulated = 0.0
		_set_night_state()
		
		
func _set_day_state() -> void:
	is_night = false
	light.light_energy = 1.5
	light.light_color = Color("ffff9aff")
	if _env:
		# REMOVED: env.fog_enabled = false line that was immediately overwritten below it
		_env.background_mode = Environment.BG_SKY
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_env.ambient_light_sky_contribution = 1.0
		_env.fog_enabled = true
		_env.fog_mode = Environment.FOG_MODE_DEPTH
		_env.fog_light_color = Color(0.568, 0.996, 0.922, 1.0)
		_env.fog_density = 0.90
		_env.fog_sky_affect = 1.0
	day_night_changed.emit(false)
	
	
func _set_night_state() -> void:
	is_night = true
	light.light_energy = 0.0
	if _env:
		_env.background_mode = Environment.BG_SKY
		if sky_material:
			sky_material.sky_top_color = Color(0.95, 0.15, 0.15)
			sky_material.sky_horizon_color = Color(0.0,  0.0,  0.0,  1.0)
			sky_material.ground_bottom_color = Color(0.05, 0.0,  0.0)
			sky_material.ground_horizon_color  = Color(0.12, 0.02, 0.02)
			# REMOVED: env.sky.sky_material = sky_material
			# reassigning the same reference does nothing; Godot tracks property changes on the material itself
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_env.ambient_light_color = Color(0.12, 0.03, 0.03)
		_env.ambient_light_energy = 0.5
		_env.ambient_light_sky_contribution = 0.0
		_env.fog_enabled = true
		_env.fog_mode = Environment.FOG_MODE_DEPTH
		_env.fog_light_color = Color(1.0, 0.204, 0.204, 1.0)
		_env.fog_density = 0.9
		_env.fog_sky_affect  = 1.0
	day_night_changed.emit(true)
	
	
# CALL ONCE ENEMIES ARE DEAD
func return_to_day() -> void:
	if is_night:
		time_accumulated = 0.0
		_set_day_state()
