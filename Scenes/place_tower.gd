extends TextureButton

@export var draggableTower: PackedScene
@export var cursor : PackedScene
var camera : Camera3D

var ghostObject : Node
var placementCursor : Node
var is_placing : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ghostObject = draggableTower.instantiate()
	placementCursor = cursor.instantiate()
	add_child(ghostObject)
	camera = get_viewport().get_camera_3d()
	ghostObject.visible = false
	placementCursor.visible = false
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_placing:
		var space_state = ghostObject.get_world_3d().direct_space_state
		var mouse_pos:Vector2 = get_viewport().get_mouse_position()
		var origin:Vector3 = camera.project_ray_origin(mouse_pos)
		var end:Vector3 = origin + camera.project_ray_normal(mouse_pos) * 10000
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_areas = true
		var rayResult:Dictionary = space_state.intersect_ray(query)
		if rayResult.size() > 0:
			if rayResult["collider"] is GridMap:
				var gridmap: GridMap = rayResult["collider"]
				var hit_pos: Vector3 = rayResult["position"]
				var cell: Vector3i = gridmap.local_to_map(gridmap.to_local(hit_pos))
				
				var cell_origin: Vector3 = gridmap.map_to_local(cell)
				
				# Only placeable on grass tiles
				if gridmap.get_cell_item(cell) == 109 || gridmap.get_cell_item(cell) == 36 || gridmap.get_cell_item(cell) == 109 :
					ghostObject.visible = true
					ghostObject.global_position = gridmap.to_global(cell_origin)
				else:
					ghostObject.visible = false
				print("Collided with cell:", cell, "at world position:", ghostObject.global_position)
		else:
			ghostObject.visible = false	
func _toggled(toggled_on: bool) -> void:
	is_placing = toggled_on
