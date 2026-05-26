extends Control

@onready var next_button: Button = %BtnNext
@onready var lore_label: Label = %LoreLabel

var type_tween: Tween
var is_typing: bool = true

func _ready():
	next_button.hide() # 처음엔 입장 버튼을 꽁꽁 숨겨둡니다.
	lore_label.visible_characters = 0 # 글자를 0개만 보이게 (전부 숨김) 세팅
	
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

			# 한 줄을 다 읽을 수 있도록 0.35초 동안 멈춤(Interval)
			# 이 수치를 조절해서 머무르는 시간을 마음대로 바꿀 수 있습니다.
			type_tween.tween_interval(0.35)

			# 즉시 줄바꿈 처리를 실행하여 다음 줄 시작점으로 커서를 내림
			type_tween.tween_property(lore_label, "visible_characters", accumulated_chars, 0.01)

	type_tween.finished.connect(_on_type_finished)

# 텍스트 출력이 모두 끝났을 때
func _on_type_finished():
	is_typing = false
	lore_label.visible_characters = -1 # -1은 '모든 글자 표시'를 뜻하는 엔진의 안전장치입니다.
	
	SoundManager.stop_sfx(SoundManager.SFX.TYPING) # 타이핑 사운드가 아직 재생 중이라면 즉시 정지

	# 버튼이 그냥 띡! 나타나는 것보다 페이드인으로 스르륵 나타나는 게 더 예쁩니다.
	next_button.modulate.a = 0
	next_button.show()
	create_tween().tween_property(next_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

# 화면 어디든 클릭하면 실행되는 전역 입력 감지
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