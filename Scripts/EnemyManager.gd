extends Node

### Enemy Spawning
@export var enemy_scene: PackedScene
@export var spawn_interval := 2.0
@export var enemies_per_wave := 5
@export var wave_delay := 5.0

### Path Configuration
@export var spawn_position := Vector3(-1, 0, 6)
@export var path_points: Array[Vector3] = []

### Private Variables
var spawn_timer := 0.0
var current_wave := 1
var enemies_spawned_this_wave := 0
var wave_timer := 0.0
var is_spawning := false

### Signals
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node3D)

### Initialize Manager
func _ready() -> void:
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
		wave_timer -= delta
		if wave_timer <= 0:
			start_next_wave()

### Spawns a single enemy
func spawn_enemy() -> void:
	if !enemy_scene:
		push_warning("No enemy scene assigned to EnemyManager!")
		return
	
	var enemy = enemy_scene.instantiate()
	get_tree().root.add_child(enemy)
	
	# Set enemy position and path
	enemy.global_position = spawn_position
	if enemy.has_method("set_path"):
		enemy.set_path(path_points)
		# Reset enemy path index to ensure clean start
		enemy.current_path_index = 0
	
	# Connect enemy signals
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)
	if enemy.has_signal("enemy_reached_end"):
		enemy.enemy_reached_end.connect(_on_enemy_reached_end)
	
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
	spawn_timer = 0.0
	
	wave_started.emit(current_wave)
	print("Starting wave ", current_wave)

### Ends the current wave
func end_current_wave() -> void:
	is_spawning = false
	wave_timer = wave_delay
	
	wave_completed.emit(current_wave)
	print("Wave ", current_wave, " spawning complete")
	
	current_wave += 1

### Handles enemy death
func _on_enemy_died(enemy: Node3D, money_reward: int) -> void:
	# Get money manager and add reward
	var money_manager = get_node("/root/MoneyManager")
	if money_manager and money_manager.has_method("add_money"):
		money_manager.add_money(money_reward)
		print("Enemy died, added ", money_reward, " money")

### Handles enemy reaching end
func _on_enemy_reached_end(enemy: Node3D) -> void:
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

### Manually trigger next wave (for testing)
func force_next_wave() -> void:
	if !is_spawning:
		start_next_wave()
