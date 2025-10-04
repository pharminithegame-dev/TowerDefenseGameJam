extends Camera3D

### Settings
@export var pan_speed_with_mouse := 0.03
@export var pan_speed_with_keys := 1.5
@export var max_x_cam_dist := 15.0
@export var max_z_cam_dist := 8.0
@export var raycast_dist := 50
@export var cam_lerp_speed := 5.0  # How fast the camera accelerates to target position

### References
@onready var ray := $RayCast3D

### Private Variables
var last_drag_pos := Vector2.ZERO
var is_panning := false
var cam_min_pos_2d := Vector2.ZERO
var cam_max_pos_2d := Vector2.ZERO
var cam_target_pos := Vector3.ZERO
var is_cam_moving := false



### Called when node enters the scene for the first time
func _ready() -> void:
	cam_min_pos_2d = Vector2(position.x - max_x_cam_dist, position.z - max_z_cam_dist)
	cam_max_pos_2d = Vector2(position.x + max_x_cam_dist, position.z + max_z_cam_dist)


### Called once on input press/release
func _unhandled_input(event) -> void:
	
	# Start panning when pressing input
	if event.is_action_pressed("camera_pan_toggle"):
		is_panning = true
		last_drag_pos = get_viewport().get_mouse_position()
	
	# Stop panning when releasing input
	elif event.is_action_released("camera_pan_toggle"):
		is_panning = false
	
	# Start raycasting for buildings when pressing input
	elif event.is_action_pressed("select"):
		raycast_for_buildings()


### Called every frame, handles camera pan input
func _process(delta) -> void:
	
	# Pan camera when holding input
	if is_panning and Input.is_action_pressed("camera_pan_toggle"):
		update_camera_pan_with_mouse()
	
	# Move mouse with keys
	update_camera_pan_with_keys()
	
	if is_cam_moving:   # Smoothly move cam to target
		lerp_camera_to_target(delta)


### Called every frame where camera pan input is pressed, calculates new camera position
func update_camera_pan_with_mouse() -> void:
	# Get difference from last and current mouse position
	var new_drag_pos: Vector2 = get_viewport().get_mouse_position()
	var delta_drag_pos: Vector2 = new_drag_pos - last_drag_pos
	last_drag_pos = new_drag_pos
	
	# Move camera in opposite direction of drag
	var new_cam_pos := position - (Vector3(delta_drag_pos.x, 0, delta_drag_pos.y) * pan_speed_with_mouse)
	snap_camera_to_target(new_cam_pos)


### Called every frame, moves camera with WASD
func update_camera_pan_with_keys() -> void:
	
	# Get WASD input as a vector
	var cam_pan_input_2d := Input.get_vector("camera_pan_left", "camera_pan_right", "camera_pan_forward", "camera_pan_backward")
	
	if cam_pan_input_2d != Vector2.ZERO:   # If WASD was pressed, move cam in that direction
		var new_cam_pos: Vector3 = position + (Vector3(cam_pan_input_2d.x, 0, cam_pan_input_2d.y) * pan_speed_with_keys)
		set_camera_target_pos(new_cam_pos)


### Raycasts from camera to mouse world position and checks for collisions with buildings
func raycast_for_buildings() -> void:
	# Move raycast target to position of mouse in 3d world space
	var mouse_pos := get_viewport().get_mouse_position()
	ray.target_position = project_local_ray_normal(mouse_pos) * raycast_dist
	ray.force_raycast_update()
	ray.enabled = true
	
	if !ray.is_colliding():  # Exit if no building collision
		ray.enabled = false
		return
	
	# Display building UI TODO - put script in collider so I don't have to get parent twice
	if ray.get_collider().get_parent().get_parent().has_method("select_building"):
		ray.get_collider().get_parent().get_parent().select_building()
	
	# Move camera to building position
	set_camera_target_pos(ray.get_collider().global_position)
	ray.enabled = false


### Sets a new target position and clamps it within the min/max positions
func set_camera_target_pos(target_pos: Vector3) -> void:
	target_pos.y = global_position.y   # Don't move camera vertically
	if cam_target_pos.is_equal_approx(target_pos): return
	cam_target_pos = target_pos
	
	# Clamp target position within borders of map
	cam_target_pos.x = clamp(cam_target_pos.x, cam_min_pos_2d.x, cam_max_pos_2d.x) 
	cam_target_pos.z = clamp(cam_target_pos.z, cam_min_pos_2d.y, cam_max_pos_2d.y)
	is_cam_moving = true


### Smoothly move with lerp towards camera target position
func lerp_camera_to_target(delta: float) -> void:
	# Smoothly move to target
	global_position = global_position.lerp(cam_target_pos, cam_lerp_speed * delta)
	
	# If camera is basically at target position
	if global_position.is_equal_approx(cam_target_pos):
		global_position = cam_target_pos  # Ensure camera is exactly at target pos
		is_cam_moving = false             # Stop updating camera position


### Instantly moves camera to target position and clamps target within the min/max positions
func snap_camera_to_target(target_pos: Vector3) -> void:
	global_position.x = clamp(target_pos.x, cam_min_pos_2d.x, cam_max_pos_2d.x) 
	global_position.z = clamp(target_pos.z, cam_min_pos_2d.y, cam_max_pos_2d.y)
