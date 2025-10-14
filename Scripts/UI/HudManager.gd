extends CanvasLayer

# References
@export var health_label: Label
@export var score_label: Label
@export var money_label: Label

# Visual Feedback
@onready var health_flash: TextureRect = $HBoxContainer/HealthHBox/HealthTextureRect
#Money Flash and Value Holder
@onready var money_flash: TextureRect = $HBoxContainer/MoneyHBox/MoneyTextureRect
var previous_money: int
#score var


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# Initialize label text
	set_health_label_text(GameManager.get_health())
	set_score_label_text(0)     # Temp
	# TODO - initialize score from game manager
	set_money_label_text(MoneyManager.get_money())
	
	# Connect signals
	# TODO - connect score signal game manager
	GameManager.health_altered.connect(set_health_label_text)
	MoneyManager.money_altered.connect(set_money_label_text)
	# Visual Signals
	GameManager.health_altered.connect(_on_health_altered)
	MoneyManager.money_altered.connect(_on_money_altered)
	previous_money = MoneyManager.get_money()
	


# Update the health label text to new health value
func set_health_label_text(new_health: int) -> void:
	health_label.text = str(new_health)


# Update the score label text to new score value
func set_score_label_text(new_score: int) -> void:
	score_label.text = str(new_score)


# Update the money label text to new money count
func set_money_label_text(new_money: int) -> void:
	money_label.text = str(new_money)

# Signal calls
# Health Flash (despite not using new_health, needs it for call)
func _on_health_altered(new_health: int) -> void: 
	flash_color(health_flash, Color(1, 0, 0, 1))

func _on_money_altered(new_money: int) -> void:
	if(new_money > previous_money):
		flash_color(money_flash, Color(0,1,0,1))
	elif(new_money < previous_money):
		flash_color(money_flash, Color(1,1,0,1))
	previous_money = new_money

#Allows for flash of any color
func flash_color(icon: TextureRect, color: Color) -> void:
	icon.modulate = color
	await get_tree().create_timer(0.2).timeout
	icon.modulate = Color(1, 1, 1, 1)  # reset to normal
