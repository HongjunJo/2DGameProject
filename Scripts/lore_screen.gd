extends Control

@onready var btn_next: Button = $BtnNext

func _ready():
	btn_next.pressed.connect(_on_next_pressed)

func _on_next_pressed():
	TransitionManager.change_scene("res://Scenes/game_stage.tscn")