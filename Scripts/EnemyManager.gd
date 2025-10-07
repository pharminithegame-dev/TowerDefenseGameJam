extends Node

### Enemy Spawning
@export var enemy_scene: PackedScene # UFO enemy
@export var pirate_ship_scene: PackedScene # Pirate ship enemy
@export var spawn_interval := 2.0
@export var enemies_per_wave := 5
@export var wave_delay := 5.0

### Enemy Type Distribution
@export var base_ship_percentage := 0.2 # 20% ships initially
@export var ship_percentage_increase := 0.05 # 5% more ships per wave

### Wave Progression
@export var enemy_count_increase_type := "linear" # "linear" or "exponential"
@export var enemy_count_increase := 2 # Amount to increase per wave
@export var stat_increase_per_wave := 0.05 # 5% increase per wave

### Path Configuration
@export var spawn_position := Vector3(-1, 0, 6)
@export var path_points: Array[Vector3] = []

### Private Variables
var spawn_timer := 0.0
var current_wave := 1
var enemies_spawned_this_wave := 0
var wave_timer := 0.0
var is_spawning := false
var active_enemies := 0
var base_enemy_count := 5
var ships_to_spawn := 0
var ships_spawned := 0

### Signals
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node3D)

### Initialize Manager
func _ready() -> void:
	base_enemy_count = enemies_per_wave
	setup_default_path()
	start_next_wave()

### Update spawning logic
func _process(delta: float) -> void:
	if is_spawning:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()
			spawn_timer = spawn_interval
	else:
		# Only start next wave when all enemies are defeated
		if active_enemies <= 0:
			wave_timer -= delta
			if wave_timer <= 0:
				start_next_wave()

### Spawns a single enemy
func spawn_enemy() -> void:
	var enemy_to_spawn = choose_enemy_type()
	if !enemy_to_spawn:
		push_warning("No enemy scene available!")
		return
	
	var enemy = enemy_to_spawn.instantiate()
	get_tree().root.add_child(enemy)
	
	# Set enemy position and path
	enemy.global_position = spawn_position
	if enemy.has_method("set_path"):
		enemy.set_path(path_points)
		# Reset enemy path index to ensure clean start
		enemy.current_path_index = 0
	
	# Apply wave scaling to enemy stats
	apply_wave_scaling(enemy)
	
	# Connect enemy signals
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)
	if enemy.has_signal("enemy_reached_end"):
		enemy.enemy_reached_end.connect(_on_enemy_reached_end)
	
	active_enemies += 1
	
	enemies_spawned_this_wave += 1
	enemy_spawned.emit(enemy)
	print("Spawned enemy ", enemies_spawned_this_wave, " of wave ", current_wave)
	
	# Check if wave is complete
	if enemies_spawned_this_wave >= enemies_per_wave:
		end_current_wave()

### Starts the next wave
func start_next_wave() -> void:
	is_spawning = true
	enemies_spawned_this_wave = 0
	ships_spawned = 0
	spawn_timer = 0.0
	
	# Calculate enemies for this wave
	if enemy_count_increase_type == "exponential":
		enemies_per_wave = base_enemy_count * int(pow(1.5, current_wave - 1))
	else:
		enemies_per_wave = base_enemy_count + (enemy_count_increase * (current_wave - 1))
	
	# Calculate exact number of ships for this wave
	var current_ship_percentage = base_ship_percentage + (ship_percentage_increase * (current_wave - 1))
	current_ship_percentage = clamp(current_ship_percentage, 0.0, 1.0)
	ships_to_spawn = int(enemies_per_wave * current_ship_percentage)
	
	wave_started.emit(current_wave)
	print("Starting wave ", current_wave, " with ", enemies_per_wave, " enemies (", ships_to_spawn, " ships, ", enemies_per_wave - ships_to_spawn, " UFOs)")

### Ends the current wave
func end_current_wave() -> void:
	is_spawning = false
	wave_timer = wave_delay
	
	wave_completed.emit(current_wave)
	print("Wave ", current_wave, " spawning complete")
	
	current_wave += 1

### Handles enemy death
func _on_enemy_died(enemy: Node3D, money_reward: int) -> void:
	active_enemies -= 1
	# Get money manager and add reward
	var money_manager = get_node("/root/MoneyManager")
	if money_manager and money_manager.has_method("add_money"):
		money_manager.add_money(money_reward)
		print("Enemy died, added ", money_reward, " money")

### Handles enemy reaching end
func _on_enemy_reached_end(enemy: Node3D) -> void:
	active_enemies -= 1
	print("Enemy reached the end - player takes damage!")
	# TODO: Implement player health/lives system

### Sets up default path based on your map
func setup_default_path() -> void:
	if path_points.is_empty():
		path_points = [
			Vector3(-1, 0, 6),  # Spawn off-screen
		Vector3(0, 0, 6),   # Enter map
		Vector3(6.5, 0, 6),   # First waypoint
		Vector3(6.5, 0, 8),  # Second waypoint
		Vector3(1, 0, 8),  # Turn point
		Vector3(1, 0, 11), # Final stretch
		#Vector3(28, 0, 11)
		]

### Applies wave scaling to enemy stats
func apply_wave_scaling(enemy: Node3D) -> void:
	var scale_multiplier = 1.0 + (stat_increase_per_wave * (current_wave - 1))
	
	if enemy.has_method("set") or "max_health" in enemy:
		enemy.max_health *= scale_multiplier
		enemy.current_health = enemy.max_health
	if enemy.has_method("set") or "money_reward" in enemy:
		enemy.money_reward = int(enemy.money_reward * scale_multiplier)

### Chooses enemy type based on fixed distribution
func choose_enemy_type() -> PackedScene:
	# Spawn ships first until quota is met, then spawn UFOs
	if ships_spawned < ships_to_spawn and pirate_ship_scene:
		ships_spawned += 1
		print("Spawning ship ", ships_spawned, "/", ships_to_spawn)
		return pirate_ship_scene
	else:
		print("Spawning UFO")
		return enemy_scene

### Manually trigger next wave (for testing)
func force_next_wave() -> void:
	if !is_spawning:
		start_next_wave()
