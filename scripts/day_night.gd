extends Node3D

@export var sunlight:DirectionalLight3D
@export var world_env:WorldEnvironment
@export var day_duration: float = 360.0
@export var time_of_day:float = 0.5
var min_sun_energy := 0.0
var max_sun_energy := 1.0

func _ready() -> void:
	sunlight.rotation_degrees.x = time_of_day

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time_of_day += delta / day_duration
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	sunlight.rotation_degrees.x = time_of_day * 360
	update_env()
	
func update_env() -> void:
	var deg_x:float = sunlight.rotation_degrees.x
	
	if is_daytime(deg_x):
		var intensity =  _sun_intensity(deg_x)
		sunlight.light_energy = intensity
	
func is_daytime(deg_x:float) -> bool:
	return deg_x > 90.0 and deg_x < 270.0

func is_nighttime(deg_x:float) -> bool:
	return not is_daytime(deg_x)

func check_night() -> bool:
	return is_nighttime(sunlight.rotation_degrees.x)
	
func _sun_intensity(deg_x:float) -> float:
	var norm = (deg_x - 90.0) / 180.0
	return sin(norm * PI)
