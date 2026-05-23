extends CanvasLayer
class_name UIManager

signal view_button_down
signal view_button_up
signal hint_button_pressed
signal next_stage_pressed

@onready var target_overlay: TextureRect = $TargetOverlay
@onready var btn_view: Button = $BtnView
@onready var btn_hint: Button = $BtnHint
@onready var result_panel: Control = $ResultPanel
@onready var btn_next_stage: Button = $ResultPanel/BtnNextStage

# ✨ 추가: 깜빡임 애니메이션을 추적할 변수
var hint_tween: Tween

func _ready():
	target_overlay.hide()
	
	# 내부 버튼 시그널 중계
	btn_view.button_down.connect(func(): view_button_down.emit())
	btn_view.button_up.connect(func(): view_button_up.emit())
	btn_hint.pressed.connect(func(): hint_button_pressed.emit())
	
	# 결과 패널 초기 설정
	result_panel.hide()
	btn_next_stage.pressed.connect(func(): next_stage_pressed.emit())

	# ✨ 초기 상태: 힌트 버튼 잠금!
	reset_hint_button()

func setup_overlay(texture: Texture2D, screen_pos: Vector2, scaled_size: Vector2):
	target_overlay.texture = texture
	target_overlay.position = screen_pos
	target_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	target_overlay.size = scaled_size
	target_overlay.custom_minimum_size = scaled_size

func show_overlay():
	target_overlay.show()

func hide_overlay():
	target_overlay.hide()

# 클리어 시 결과창 띄우기
func show_result_ui(is_last: bool):
	result_panel.show()
	result_panel.modulate.a = 0
	if is_last:
		btn_next_stage.text = "모든 유물 복원 완료 (메인으로)"
	
	create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.5)

# ==========================================
# ✨ 힌트 버튼 제어 로직
# ==========================================

# 15초 타이머 종료 시 호출 (GameStage가 부름)
func play_hint_button_pulse():
	print("🚨 힌트 타이머 발동! (버튼 활성화 시도)") # <- 이 줄 추가
	if hint_tween and hint_tween.is_valid():
		return
	btn_hint.disabled = false
		
	# ✨ 15초가 지났으니 버튼 클릭 허용!
	btn_hint.disabled = false 
	
	# 찰진 깜빡임 애니메이션
	hint_tween = create_tween().set_loops()
	hint_tween.tween_property(btn_hint, "modulate", Color.GOLD, 0.5)
	hint_tween.tween_property(btn_hint, "modulate", Color.WHITE, 0.5)

# 마우스 조작 시 호출 (GameStage가 부름)
func reset_hint_button():
	# 기존에 재생 중이던 깜빡임 끄기
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
		
	# ✨ 조작을 시작했으니 버튼 다시 잠금! (반투명 & 클릭 불가)
	btn_hint.disabled = true
	btn_hint.modulate = Color(1, 1, 1, 0.5)

# 퍼즐 클리어 시 호출 (GameStage가 부름)
func disable_all_buttons():
	btn_view.disabled = true
	btn_hint.disabled = true
	
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn_view, "modulate:a", 0.0, 0.3)
	tween.tween_property(btn_hint, "modulate:a", 0.0, 0.3)
	
	# ✨ 추가: 알파 값이 빠진 후 확실하게 눈 앞에서 숨기기
	tween.chain().tween_callback(func():
		btn_view.hide()
		btn_hint.hide()
	)
