extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var ui_manager: UIManager = $UIManager
@onready var hint_timer: Timer = $HintTimer

var current_hint_time: float = 15.0
var is_hint_unlocked: bool = false 

# 퍼즐 진행 시간 및 상태 추적 변수
var elapsed_time: float = 0.0 
var is_game_active: bool = false 

func _ready():
	var current_level = GlobalData.get_current_level()
	board_manager.level_data = current_level
	
	board_manager.board_generated.connect(_on_board_generated)
	ui_manager.view_button_down.connect(func(): ui_manager.show_overlay())
	ui_manager.view_button_up.connect(func(): ui_manager.hide_overlay())
	ui_manager.hint_button_pressed.connect(_on_hint_pressed)
	hint_timer.timeout.connect(_on_hint_timer_timeout)
	board_manager.puzzle_cleared.connect(_on_puzzle_cleared)
	ui_manager.next_stage_pressed.connect(_on_next_stage_requested)

	current_hint_time = current_level.hint_wait_time
	hint_timer.start(current_hint_time)

	# 스테이지 본격 시작 전 타이머 활성화
	elapsed_time = 0.0
	is_game_active = true

	board_manager.generate_board()

func _process(delta: float):
	if is_game_active:
		elapsed_time += delta
		
		if not is_hint_unlocked and not hint_timer.is_stopped():
			ui_manager.update_hint_cooldown(hint_timer.time_left)

func _on_puzzle_cleared():
	# 퍼즐 클리어 시 타이머 진행을 중단하고 UI 상호작용 차단
	is_game_active = false 
	hint_timer.stop()
	ui_manager.disable_all_buttons()
	
	# 연출 완료 대기 후 레벨 데이터 및 최종 시간을 결과창으로 전달
	await get_tree().create_timer(1.5).timeout
	ui_manager.show_result_ui(GlobalData.get_current_level(), elapsed_time, GlobalData.is_last_level())

func _on_next_stage_requested():
	SoundManager.play_sfx(SoundManager.SFX.UI_CLICK)

	if GlobalData.is_last_level():
		GlobalData.current_level_index = 0
		TransitionManager.change_scene("res://Scenes/MainMenu.tscn") # 메인 메뉴로 돌아가기
	else:
		GlobalData.next_level()
		TransitionManager.reload_scene() # 다음 스테이지

func _on_hint_timer_timeout():
	is_hint_unlocked = true 
	ui_manager.play_hint_button_pulse()

func _on_hint_pressed():
	board_manager.highlight_hint_tile()

func _on_board_generated(texture: Texture2D, pos: Vector2, size: Vector2):
	ui_manager.setup_overlay(texture, pos, size)
	
	# ==========================================
	# 배경 스포트라이트(비네팅) 셰이더 동적 데이터 할당
	# ==========================================
	# 1. 시각 효과를 관장하는 Vignette 머티리얼 획득
	var vignette = $BackgroundLayer/Vignette 
	
	# 2. 현재 화면의 실제 해상도 크기 구하기
	var screen_size = get_viewport().get_visible_rect().size
	
	# 3. 보드판의 실제 화면상 좌상단 시작점(Position)과 가로세로 크기(Size) 계산
	var puzzle_size = size 
	var puzzle_pos = pos
	
	# 4. 셰이더 매니저에게 실시간으로 데이터 주입하기
	var mat = vignette.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("screen_size", screen_size)
		mat.set_shader_parameter("puzzle_size", puzzle_size)
		mat.set_shader_parameter("puzzle_pos", puzzle_pos)
