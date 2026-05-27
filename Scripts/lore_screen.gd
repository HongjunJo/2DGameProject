extends Control

@onready var next_button: Button = %BtnNext
@onready var lore_label: Label = %LoreLabel

var type_tween: Tween
var is_typing: bool = true

func _ready():
	next_button.hide() # 진입 시 다음 버튼(입장) 비활성화
	lore_label.visible_characters = 0 # 텍스트 초기화 (글자를 모두 숨겨 타이프라이터 효과 준비)
	
	start_typewriter_effect()
	next_button.pressed.connect(_on_next_pressed)

func start_typewriter_effect():
	is_typing = true
	lore_label.visible_characters = 0
	type_tween = create_tween()
	
	SoundManager.play_sfx(SoundManager.SFX.TYPING, false, 0.0, 1.0) # 타이핑 사운드 재생

	# 텍스트를 줄바꿈(\n) 기준으로 통째로 쪼갭니다.
	var lines = lore_label.text.split("\n")
	var accumulated_chars = 0
	
	for i in range(lines.size()):
		var line_text = lines[i]
		accumulated_chars += line_text.length()
		
		# 1. 현재 줄의 글자들을 타이핑하는 애니메이션
		var duration = line_text.length() * 0.05
		if duration > 0:
			type_tween.tween_property(lore_label, "visible_characters", accumulated_chars, duration)
		
		# 2. 마지막 줄이 아니라면, 줄바꿈 기호를 만나 고개를 돌리는 타이밍 제어
		if i < lines.size() - 1:
			accumulated_chars += 1 # \n 문자 자체의 카운트 추가

	# 한 줄을 다 읽을 수 있도록 간격을 주어 타이핑 연출 제어 (머무르는 시간)
			type_tween.tween_interval(0.35)

			# 줄바꿈 문자를 출력하여 커서를 다음 줄로 내려줌
			type_tween.tween_property(lore_label, "visible_characters", accumulated_chars, 0.01)

	type_tween.finished.connect(_on_type_finished)

# 텍스트 출력이 모두 완료되었을 때의 처리
func _on_type_finished():
	is_typing = false
	lore_label.visible_characters = -1 # 엔진의 렌더링 최적화를 이용해 모든 글자를 노출 상태로 확정
	
	SoundManager.stop_sfx(SoundManager.SFX.TYPING) 

	# UI 페이드 인: 종료 버튼을 서서히 노출 (알파값 0 -> 1 트위닝)
	next_button.modulate.a = 0
	next_button.show()
	create_tween().tween_property(next_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

# 마우스 입력 이벤트: 화면 클릭 시 현재 진행 중인 타이핑 연출 스킵
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_typing:
			# 타이핑이 진행 중일 때 클릭하면 즉시 스킵
			if type_tween and type_tween.is_valid():
				type_tween.kill()
			_on_type_finished()

func _on_next_pressed():
	SoundManager.stop_sfx(SoundManager.SFX.TYPING)
	SoundManager.play_sfx(SoundManager.SFX.UI_CLICK)
	TransitionManager.change_scene("res://Scenes/game_stage.tscn")