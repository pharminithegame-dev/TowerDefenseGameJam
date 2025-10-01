extends CharacterBody3D

### Stats
@export var max_health := 100.0
@export var move_speed := 3.0
@export var money_reward := 10

### Money Object Spawn
@export var money_obj: PackedScene

### Path Following
@export var path_points: Array[Vector3] = []
var current_path_index := 0
var path_progress := 0.0
var path_completion_percentage := 0.0

### Private Variables
var current_health: float
var is_alive := true
@onready var health_bar: ProgressBar = $HealthBar

### Signals
signal enemy_died(enemy: Node3D, money_reward: int)
signal enemy_reached_end(enemy: Node3D)

### Initialize Enemy
func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	
	# Set up basic path if none provided
	if path_points.is_empty():
		setup_default_path()

### Movement and Health Updates
func _physics_process(delta: float) -> void:
	if !is_alive:
		return
	
	move_along_path(delta)

### Moves enemy along the defined path
func move_along_path(delta: float) -> void:
	if path_points.is_empty() or current_path_index >= path_points.size():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var target_pos = path_points[current_path_index]
	var distance_to_target = global_position.distance_to(target_pos)
	
	# Move using velocity for proper physics
	if distance_to_target > 0.1:
		var direction = (target_pos - global_position).normalized()
		velocity = direction * move_speed
	else:
		# Stop at waypoint and advance to next
		velocity = Vector3.ZERO
		global_position = target_pos
		current_path_index += 1
		
		# Check if reached end of path
		if current_path_index >= path_points.size():
			reach_end()
			return
	
	move_and_slide()
	
	# Update path completion percentage
	update_path_completion()

### Takes damage and handles death
func take_damage(damage: float) -> void:
	if !is_alive:
		return
	current_health -= damage
	update_health_bar()
	print("Enemy took ", damage, " damage. Health: ", current_health)
	
	if current_health <= 0:
		die()

### Handles enemy death
func die() -> void:
	if !is_alive:
		return
	
	is_alive = false
	#print("Enemy died! Rewarding ", money_reward, " money")
	
	#spawn_money()
	
	# Emit signal for money reward
	# Note from Alex: Will probably remove next sprint
	enemy_died.emit(self, money_reward)
	
	# Remove from scene
	queue_free()

### Handles reaching the end of path
func reach_end() -> void:
	print("Enemy reached the end!")
	var pos := global_position
	spawn_money(pos)
	enemy_reached_end.emit(self)
	queue_free()

### Sets up path based on your map layout
func setup_default_path() -> void:
	path_points = [
		Vector3(-1, 2, 6),  # Spawn off-screen
		Vector3(0, 2, 6),   # Enter map
		Vector3(9, 2, 6),   # First waypoint
		Vector3(9, 2, 8),  # Second waypoint
		#Vector3(19, 2, 6),  # Turn point
		#Vector3(19, 2, 11), # Final stretch
		#Vector3(28, 2, 11)  # Exit off-screen
	]

### Sets a custom path for the enemy
func set_path(new_path: Array[Vector3]) -> void:
	path_points = new_path
	current_path_index = 0

### Gets current health percentage
func get_health_percentage() -> float:
	return current_health / max_health

### Updates path completion percentage
func update_path_completion() -> void:
	if path_points.is_empty():
		path_completion_percentage = 0.0
		return
	
	var completed_segments = float(current_path_index)
	var total_segments = float(path_points.size() - 1)
	
	if total_segments <= 0:
		path_completion_percentage = 1.0
		return
	
	# Add partial progress within current segment
	if current_path_index < path_points.size():
		var current_target = path_points[current_path_index]
		var previous_pos = path_points[current_path_index - 1] if current_path_index > 0 else global_position
		var segment_length = previous_pos.distance_to(current_target)
		var distance_to_target = global_position.distance_to(current_target)
		
		if segment_length > 0:
			var segment_progress = 1.0 - (distance_to_target / segment_length)
			completed_segments += clamp(segment_progress, 0.0, 1.0)
	
	path_completion_percentage = completed_segments / total_segments
	print(path_completion_percentage)
func get_path_completion_percentage() -> float:
	return path_completion_percentage

### Updates the health bar display
func update_health_bar() -> void:
	if health_bar:
		health_bar.value = get_health_percentage() * 100

### Instantiate's Money to Position of Enemy and Spawns
func spawn_money(location: Vector3) -> void:
	var money = money_obj.instantiate();
	money.global_position = location
	get_tree().get_root().add_child(money)
