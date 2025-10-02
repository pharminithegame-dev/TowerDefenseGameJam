extends Camera3D

### Export Variables
@export var pan_speed_with_mouse := 4.25
@export var pan_speed_with_keys := 15
@export var max_x_cam_dist := 15
@export var max_z_cam_dist := 8

### Private Variables
var last_drag_pos := Vector2.ZERO
var is_panning := false
var cam_min_pos_2d := Vector2.ZERO
var cam_max_pos_2d := Vector2.ZERO



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


### Called every frame, handles camera pan input
func _process(delta) -> void:
	
	# Pan camera when holding input
	if is_panning and Input.is_action_pressed("camera_pan_toggle"):
		update_camera_pan_with_mouse(delta)
	
	# Move mouse with keys
	update_camera_pan_with_keys(delta)


### Called every frame where camera pan input is pressed, calculates new camera position
func update_camera_pan_with_mouse(delta: float) -> void:
	# Get difference from last and current mouse position
	var new_drag_pos: Vector2 = get_viewport().get_mouse_position()
	var delta_drag_pos: Vector2 = new_drag_pos - last_drag_pos
	last_drag_pos = new_drag_pos
	
	# Move camera in opposite direction of drag
	var new_cam_pos_2d := Vector2(position.x, position.z) - (delta_drag_pos * pan_speed_with_mouse * delta)
	move_and_clamp_cam_pos(new_cam_pos_2d)


### Called every frame, moves camera with WASD
func update_camera_pan_with_keys(delta: float) -> void:
	
	# Get WASD input as a vector
	var cam_pan_input_2d := Input.get_vector("camera_pan_left", "camera_pan_right", "camera_pan_forward", "camera_pan_backward")
	
	if cam_pan_input_2d != Vector2.ZERO:        # If WASD was pressed
		var new_cam_pos_2d: Vector2 = Vector2(position.x, position.z) + (cam_pan_input_2d * pan_speed_with_keys * delta)
		move_and_clamp_cam_pos(new_cam_pos_2d)  # Apply movement


### Moves the camera on the XZ plane and clamps position if too far away from origin
func move_and_clamp_cam_pos(new_cam_pos_2d: Vector2) -> void: 
	position.x = clamp(new_cam_pos_2d.x, cam_min_pos_2d.x, cam_max_pos_2d.x) 
	position.z = clamp(new_cam_pos_2d.y, cam_min_pos_2d.y, cam_max_pos_2d.y)
