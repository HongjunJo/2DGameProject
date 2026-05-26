extends Control

@onready var btn_start = %BtnStart

func _ready():
	# 🎵 메인 메뉴 진입 시 BGM 재생
	SoundManager.play_bgm(1.0)
	btn_start.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	SoundManager.play_sfx(SoundManager.SFX.UI_CLICK)
	TransitionManager.change_scene("res://Scenes/LoreScreen.tscn")
