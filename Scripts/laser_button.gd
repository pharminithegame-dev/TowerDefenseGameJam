extends TextureButton

@export var draggableTower: PackedScene
@export_node_path("GridMap") var gridmap_path: NodePath   # minimal addition so we always resolve cells via this GridMap

var camera : Camera3D
@onready var gridmap: GridMap = get_node_or_null(gridmap_path) as GridMap

var ghostObject : Node3D
var is_placing : bool

var _last_valid_world_pos: Vector3 = Vector3.ZERO
var _has_valid: bool = false

func _ready() -> void:
	ghostObject = draggableTower.instantiate() as Node3D
	add_child(ghostObject)                 # keep your parenting unchanged
	camera = get_viewport().get_camera_3d()
	ghostObject.visible = false

func _process(delta: float) -> void:
	if not is_placing or camera == null or gridmap == null:
		return
	var space_state = ghostObject.get_world_3d().direct_space_state
	var mouse_pos:Vector2 = get_viewport().get_mouse_position()
	var origin:Vector3 = camera.project_ray_origin(mouse_pos)
	var end:Vector3 = origin + camera.project_ray_normal(mouse_pos) * 10000
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	query.collide_with_areas = false  
	var exclude: Array[RID] = []
	_collect_collision_rids(ghostObject, exclude)
	query.exclude = exclude
	var rayResult:Dictionary = space_state.intersect_ray(query)
	if rayResult.size() > 0:
		var hit_pos: Vector3 = rayResult["position"]
		var cell: Vector3i = gridmap.local_to_map(gridmap.to_local(hit_pos))
		var cell_origin_local: Vector3 = gridmap.map_to_local(cell)
		var cell_origin_world: Vector3 = gridmap.to_global(cell_origin_local)
		if gridmap.get_cell_item(cell) == 109:
			_has_valid = true
			_last_valid_world_pos = cell_origin_world
			ghostObject.visible = true
			ghostObject.global_position = cell_origin_world
		else:
			if _has_valid:
				ghostObject.visible = true
				ghostObject.global_position = _last_valid_world_pos
			else:
				ghostObject.visible = false
	else:
		if _has_valid:
			ghostObject.visible = true
			ghostObject.global_position = _last_valid_world_pos
		else:
			ghostObject.visible = false
			
func _toggled(toggled_on: bool) -> void:
	is_placing = toggled_on
	if not toggled_on:
		ghostObject.visible = false
		_has_valid = false

func _collect_collision_rids(n: Node, out: Array[RID]) -> void:
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for c in n.get_children():
		_collect_collision_rids(c, out)

func _input(event: InputEvent) -> void:
	if not is_placing:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _has_valid and draggableTower:
				var inst := draggableTower.instantiate() as Node3D
				inst.global_position = _last_valid_world_pos
				add_child(inst)      # keep your parenting
				is_placing = false
				ghostObject.visible = false
