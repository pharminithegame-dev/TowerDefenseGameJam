extends Node3D

### References
@export var rot_target: Node3D
@export var area_3d: Area3D
@export var collision_shape: CollisionShape3D
@export var projectile_tran: Node3D
@export var projectile: PackedScene
@export var audio_player: AudioStreamPlayer

### Stats
@export var projectile_damage := 5.0
@export var projectile_speed := 20.0
@export var attack_range := 30.0
@export var attack_cooldown := 1.0
@export var sell_value := 100.0

### Private Variables
var attack_timer := 0.0
var attack_range_sqr : float



### Initialize Node
func _ready() -> void:
	
	# Initialize collision radius
	if collision_shape.shape != null:
		collision_shape.shape.radius = attack_range
		print("New radius for collision shape: ", collision_shape.shape.radius)
	else:
		push_warning("ProjectileBuilding.Area3D.CollisionShape3D.Shape is null!")

	# Initialize Variables
	attack_timer = attack_cooldown
	attack_range_sqr = pow(attack_range, 2)


### Starts attack on interval
func _process(delta: float) -> void:
	
	attack_timer -= delta
	if attack_timer <= 0:
		# Start attack
		attack_timer = attack_cooldown
		shoot_projectile()


### Spawns a projectile in the direction of the closest enemy
func shoot_projectile() -> void:
	
	# Get nearest enemy in range
	var target: Node3D = get_nearest_enemy()
	if target == null:
		print("No Targets in Range For Building: ", name)
		return
	
	# Rotate ProjectileSpawnRotation towards target
	rotate_to_target(target.global_position)
	
	# Spawn projetile and setup transform and stats
	var projectile_instance = projectile.instantiate()
	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_position = projectile_tran.global_position
	projectile_instance.global_rotation = projectile_tran.global_rotation
	projectile_instance.setup_and_move(projectile_damage, projectile_speed)
	
	audio_player.play()   # Play projectile shoot sfx


### Returns the closest enemy in attack range.
func get_nearest_enemy() -> Node3D:
	
	# Get all enemies in range TODO: Grab from enemy manager instead
	var all_enemies: Array[Node3D] = area_3d.get_overlapping_bodies()
	
	# Return null if no enemies in range
	if all_enemies.size() == 0:
		return null
	
	# Get closest enemy in all enemies array
	var closest_enemy: Node3D = null
	var closest_dist_sqr: float = INF
	for enemy in all_enemies:
		# If this is the new closest enemy and is in attack range
		var cur_dist_sqr := global_position.distance_squared_to(enemy.global_position)
		if cur_dist_sqr < closest_dist_sqr and cur_dist_sqr < attack_range_sqr:   # NOTE - range check is redundant now, but I will need it when I remove Area3D later
			closest_enemy = enemy
			closest_dist_sqr = cur_dist_sqr
	
	return closest_enemy


### Rotates the ProjectileSpawnRotation node toward target
func rotate_to_target(target_pos: Vector3) -> void:
	
	# Get 2D direction from building to target
	var building_pos_2d := Vector2(global_position.x, global_position.z)
	var target_pos_2d := Vector2(target_pos.x, target_pos.z)
	var direction: Vector2 = target_pos_2d - building_pos_2d
	
	# Rotate on y axis in direction
	rot_target.rotation.y = atan2(direction.x, direction.y)


### Despawns building and returns the sell value
func sell_building() -> float:
	queue_free()   # Despawn building
	return sell_value
