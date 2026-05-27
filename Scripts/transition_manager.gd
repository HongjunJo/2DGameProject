extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready():
	color_rect.modulate.a = 0 # 시작할 땐 무조건 투명하게

# 지정된 씬 경로로 전환 (페이드 아웃 -> 씬 교체 -> 페이드 인 연출 적용)
func change_scene(path: String):
	var tween = create_tween()
	# 1. 0.5초 동안 화면 페이드 아웃
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. 페이드 아웃 완료 후 타겟 씬으로 교체
	tween.chain().tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	
	# 3. 0.5초 동안 화면 페이드 인
	tween.chain().tween_property(color_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# 현재 씬 상태를 리로드 (재시작 또는 다음 스테이지 전환 등에서 활용)
func reload_scene():
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.chain().tween_callback(func():
		get_tree().reload_current_scene()
	)
	
	tween.chain().tween_property(color_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)