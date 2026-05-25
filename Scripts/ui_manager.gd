extends CanvasLayer
class_name UIManager

signal view_button_down
signal view_button_up
signal hint_button_pressed
signal next_stage_pressed

@onready var target_overlay: TextureRect = %TargetOverlay
@onready var btn_view: Button = %BtnView
@onready var btn_hint: Button = %BtnHint

@onready var result_panel: Control = %ResultPanel
@onready var image_frame: ColorRect = %ImageFrame # ✨ 추가: 크기를 동적으로 제어할 액자 노드
@onready var result_texture: TextureRect = %ResultTexture
@onready var artifact_name_label: Label = %ArtifactNameLabel
@onready var collection_label: Label = %CollectionLabel
@onready var clear_time_label: Label = %ClearTimeLabel
@onready var btn_next_stage: Button = %BtnNextStage

var hint_tween: Tween
var is_overlay_open: bool = false 

func _ready():
	target_overlay.hide()
	result_panel.hide()
	
	btn_view.pressed.connect(_toggle_overlay)
	btn_hint.pressed.connect(func(): hint_button_pressed.emit())
	btn_next_stage.pressed.connect(func(): next_stage_pressed.emit())

	reset_hint_button()

# ✨ 픽스: 원본 보기 위치를 화면 좌측 하단 정렬 공식
func setup_overlay(texture: Texture2D, _board_pos: Vector2, scaled_size: Vector2):
	target_overlay.texture = texture
	target_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	
	# 화면 전체 해상도 크기를 구함
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = Vector2(40, 40) # 좌측과 하단에서 떨어뜨릴 여백 설정
	
	# 📐 픽스: 화면 좌측 하단 정렬 공식
	# X축은 좌측 마진(margin.x) 고정, Y축은 화면 전체 높이 - 이미지 높이 - 하단 여백
	var left_bottom_pos = Vector2(
		margin.x, 
		viewport_size.y - scaled_size.y - margin.y
	)
	
	target_overlay.reset_transform(left_bottom_pos, scaled_size)
func _toggle_overlay():
	is_overlay_open = !is_overlay_open
	if is_overlay_open:
		target_overlay.show()
	else:
		target_overlay.hide()

# ==========================================
# ✨ 결과창 띄우기 (동적 종횡비 크기 변환 적용)
# ==========================================
func show_result_ui(level_data: LevelData, time_in_seconds: float, is_last: bool):
	result_texture.texture = level_data.artifact_texture
	artifact_name_label.text = level_data.level_name
	collection_label.text = "소장처: " + level_data.collection_place
	
	var minutes = int(time_in_seconds) / 60
	var seconds = int(time_in_seconds) % 60
	clear_time_label.text = "복원 시간: %02d분 %02d초" % [minutes, seconds]
	
	if is_last:
		btn_next_stage.text = "모든 유물 복원 완료 (메인으로)"
	else:
		btn_next_stage.text = "다음 유물 복원하기"

	# --------------------------------------------------------
	# 📐 핵심: 원본 이미지 비율 가져와서 액자 크기 동적 조절하기
	# --------------------------------------------------------
	var img_size = level_data.artifact_texture.get_size()
	var aspect_ratio = img_size.x / img_size.y # 종횡비 (가로 / 세로)
	
	var max_limit: float = 550.0 # 박스 최대 크기 임계값 (원하는 대로 조절 가능)
	var dynamic_size = Vector2.ZERO
	
	if aspect_ratio > 1.0:
		# 가로로 긴 유물 그림일 때
		dynamic_size.x = max_limit
		dynamic_size.y = max_limit / aspect_ratio
	else:
		# 세로로 길거나 정사각형 유물 그림일 때
		dynamic_size.y = max_limit
		dynamic_size.x = max_limit * aspect_ratio
		
	# 테두리 여백(24픽셀)을 더해 액자의 최소 크기를 강제로 지정합니다.
	image_frame.custom_minimum_size = dynamic_size + Vector2(24, 24)
	
	result_panel.show()
	result_panel.modulate.a = 0
	create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ✨ 픽스: 클리어 시 인게임 버튼들과 함께 '원본보기' 팝업도 싹 청소
func disable_all_buttons():
	btn_view.disabled = true
	btn_hint.disabled = true
	
	# 열려있던 원본보기 오버레이 강제 종료 및 숨김
	is_overlay_open = false
	target_overlay.hide()
	
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn_view, "modulate:a", 0.0, 0.3)
	tween.tween_property(btn_hint, "modulate:a", 0.0, 0.3)
	
	tween.chain().tween_callback(func():
		btn_view.hide()
		btn_hint.hide()
	)

# ==========================================
# ✨ 추가: 힌트 쿨타임 텍스트 업데이트 함수
# ==========================================
func update_hint_cooldown(time_left: float):
	if time_left > 0:
		var seconds = int(ceil(time_left)) # 올림 처리해서 깔끔한 정수로 표시
		btn_hint.text = "힌 트 (" + str(seconds) + ")"
	else:
		btn_hint.text = "힌 트"

# 힌트 준비 완료 시 연출
func play_hint_button_pulse():
	if hint_tween and hint_tween.is_valid():
		return
	btn_hint.disabled = false 
	btn_hint.text = "힌 트" # ✨ 쿨타임 끝나면 텍스트 원상복구
	
	hint_tween = create_tween().set_loops()
	hint_tween.tween_property(btn_hint, "modulate", Color.GOLD, 0.5)
	hint_tween.tween_property(btn_hint, "modulate", Color.WHITE, 0.5)

# 힌트 초기화
func reset_hint_button():
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
	btn_hint.disabled = true
	btn_hint.modulate = Color(1, 1, 1, 0.5)
	btn_hint.text = "힌 트" # ✨ 초기화할 때도 텍스트 원상복구