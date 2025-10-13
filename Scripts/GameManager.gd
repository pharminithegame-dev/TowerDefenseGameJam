extends Node

signal health_altered(new_health: int)
signal game_over #to be attached to UI

# Starting Health. Adjust here since
# GameManager is a singleton autoload.
var health: int = 100
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#used to check health value
	health_altered.emit(health)

func add_health(num: int) -> void:
	health += num
	health_altered.emit(health)

func subtract_health(num: int) -> void:
	health -= num
	if health <= 0:
		check_game_over()
	else:
		health_altered.emit(health)

func set_health(num: int) -> void:
	health = num
	health_altered.emit(health)

func get_health() -> int:
	return health

#callable for when health <= 0
func check_game_over() -> void:
	print("Game Over!")
	get_tree().quit() #Quit for now
	#room to emit game_over for a proper screen

func _process(_delta: float) -> void:
	# K event
	if Input.is_action_just_pressed("health_plus"):
		add_health(10)
		print("Added 10 health. Total:", health)
	# L event
	if Input.is_action_just_pressed("health_minus"):
		subtract_health(10)
		print("Subtracted 10 health. Total:", health)
