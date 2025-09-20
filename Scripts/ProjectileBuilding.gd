extends Node3D

### References
@export var rot_target: Node3D
@export var area_3d: Area3D

### Stats
@export var projectile_speed := 5.0
@export var projectile_damage := 5.0
@export var attack_range := 20.0
@export var attack_cooldown := 0.5
@export var sell_cost := 100.0

### Private Variables
var attack_timer := 0.0
var attack_range_sqr : float



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize attack range
	area_3d.scale = Vector3(attack_range, attack_range, attack_range)

	# Initialize Variables
	attack_timer = attack_cooldown
	attack_range_sqr = pow(attack_range, 2)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	### Attack Check
	attack_timer -= delta
	if attack_timer <= 0:
		attack_timer = attack_cooldown
		shoot_projectile()


# Spawns a projectile in the direction of the closest enemy
func shoot_projectile():
	
	# Get nearest enemy in range
	var target: Node3D = get_nearest_enemy()
	if target == null:
		print("No Targets in Range!")
		return
	print("Closest Enemy Position", target.global_position)
	
	rotate_to_target(target.global_position)
	print("Shooting!")
	# TODO - Spawn projetile with same transform as ProjectileSpawnTran


# Returns the closest enemy in attack range.
func get_nearest_enemy():
	
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
		if cur_dist_sqr < closest_dist_sqr and cur_dist_sqr < attack_range_sqr:  # NOTE - range check is redundant now, but I will need it when I remove Area3D later
			closest_enemy = enemy
			closest_dist_sqr = cur_dist_sqr
	
	return closest_enemy # Return closest enemy


func rotate_to_target(target_pos: Vector3):
	
	# Get 2D direction from building to target
	var building_pos_2d := Vector2(global_position.x, global_position.z)
	var target_pos_2d := Vector2(target_pos.x, target_pos.z)
	var direction: Vector2 = target_pos_2d - building_pos_2d
	
	# Rotate on y axis in direction
	rot_target.rotation.y = atan2(direction.x, direction.y)
	print("Rotation.y: ", rotation.y)
	
