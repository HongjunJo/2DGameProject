extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready():
	color_rect.modulate.a = 0 # 시작할 땐 무조건 투명하게

# 특정 씬으로 이동할 때 부르는 함수
func change_scene(path: String):
	var tween = create_tween()
	# 1. 0.5초 동안 화면을 까맣게 덮음 (Fade Out)
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. 화면이 다 까매지면 실제 씬 교체
	tween.chain().tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	
	# 3. 0.5초 동안 까만 화면을 다시 걷어냄 (Fade In)
	tween.chain().tween_property(color_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# 현재 씬을 다시 로드할 때 (다음 스테이지로 넘어갈 때) 부르는 함수
func reload_scene():
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.chain().tween_callback(func():
		get_tree().reload_current_scene()
	)
	
	tween.chain().tween_property(color_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)