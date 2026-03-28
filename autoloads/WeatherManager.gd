# autoload/WeatherManager.gd
extends Node

signal weather_changed(weather_name: String)

enum Weather { CLEAR, LIGHT_RAIN, MEDIUM_RAIN, HEAVY_RAIN }

var current_weather: Weather = Weather.CLEAR
var weather_remaining: float = 0.0

var rain_particles: GPUParticles2D = null
var weather_timer: Timer = null

func _ready() -> void:
	print("[WeatherManager] Ready")
	
	weather_timer = Timer.new()
	weather_timer.wait_time = 1.0
	weather_timer.timeout.connect(_on_weather_timer_tick)
	add_child(weather_timer)
	weather_timer.start()
	
	set_process_input(true)
	call_deferred("_find_particles")


func _on_scene_loaded() -> void:
	call_deferred("_find_particles")


func _find_particles() -> void:
	var current_scene = get_tree().current_scene
	if current_scene:
		rain_particles = current_scene.get_node_or_null("WeatherLayer/RainDrops")
		
		if rain_particles:
			rain_particles.emitting = false
			print("[WeatherManager] SUCCESS: Found RainDrops in WeatherLayer")
		else:
			print("[WeatherManager] No WeatherLayer/RainDrops found in current scene")


func _process(delta: float) -> void:
	if weather_remaining > 0:
		weather_remaining -= delta
		if weather_remaining <= 0:
			clear_weather()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	
	match event.keycode:
		KEY_1: force_weather(Weather.LIGHT_RAIN)
		KEY_2: force_weather(Weather.MEDIUM_RAIN)
		KEY_3: force_weather(Weather.HEAVY_RAIN)
		KEY_0: clear_weather()


func _on_weather_timer_tick() -> void:
	if current_weather == Weather.CLEAR and randf() < 0.005:
		_start_random_weather()


func _start_random_weather() -> void:
	var roll = randf()
	if roll < 0.5:
		force_weather(Weather.LIGHT_RAIN)
	elif roll < 0.8:
		force_weather(Weather.MEDIUM_RAIN)
	else:
		force_weather(Weather.HEAVY_RAIN)


func force_weather(type: Weather) -> void:
	current_weather = type
	weather_remaining = randf_range(30.0, 120.0)
	_apply_to_particles()
	weather_changed.emit(get_weather_name())


func clear_weather() -> void:
	current_weather = Weather.CLEAR
	weather_remaining = 0.0
	_apply_to_particles()
	weather_changed.emit("Clear")


func _apply_to_particles() -> void:
	if not rain_particles:
		print("[WeatherManager] No RainDrops found in current scene")
		return
	
	var amount := 0
	match current_weather:
		Weather.LIGHT_RAIN:  amount = 600
		Weather.MEDIUM_RAIN: amount = 1400
		Weather.HEAVY_RAIN:  amount = 2200
		_: amount = 0
	
	rain_particles.amount = amount
	rain_particles.emitting = (amount > 0)


func get_weather_name() -> String:
	match current_weather:
		Weather.CLEAR:       return "Clear"
		Weather.LIGHT_RAIN:  return "Light Rain"
		Weather.MEDIUM_RAIN: return "Medium Rain"
		Weather.HEAVY_RAIN:  return "Heavy Rain"
		_:                   return "Clear"
