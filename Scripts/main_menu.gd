extends Control

@onready var btn_start: Button = $BtnStart

func _ready():
	btn_start.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	TransitionManager.change_scene("res://Scenes/LoreScreen.tscn")
