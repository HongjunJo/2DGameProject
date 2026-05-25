extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var ui_manager: UIManager = $UIManager
@onready var hint_timer: Timer = $HintTimer

var current_hint_time: float = 15.0
var is_hint_unlocked: bool = false 

# ✨ 타이머 추적용 내부 변수들
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
	board_manager.player_interacted.connect(_reset_idle_timer)
	board_manager.puzzle_cleared.connect(_on_puzzle_cleared)
	ui_manager.next_stage_pressed.connect(_on_next_stage_requested)

	current_hint_time = current_level.hint_wait_time
	hint_timer.start(current_hint_time)

	# ✨ 스테이지 시작 시 내부 스톱워치 온!
	elapsed_time = 0.0
	is_game_active = true

	board_manager.generate_board()

func _process(delta: float):
	if is_game_active:
		elapsed_time += delta
		
		if not is_hint_unlocked and not hint_timer.is_stopped():
			ui_manager.update_hint_cooldown(hint_timer.time_left)

func _on_puzzle_cleared():
	# ✨ 클리어 순간 초시계 즉시 정지
	is_game_active = false 
	hint_timer.stop()
	ui_manager.disable_all_buttons()
	
	# 연출이 끝나는 타이밍에 맞춰 데이터와 기록을 통째로 넘겨 결과창 출력!
	await get_tree().create_timer(1.5).timeout
	ui_manager.show_result_ui(GlobalData.get_current_level(), elapsed_time, GlobalData.is_last_level())

func _on_next_stage_requested():
	if GlobalData.is_last_level():
		GlobalData.current_level_index = 0
		TransitionManager.change_scene("res://Scenes/MainMenu.tscn") # 메인 메뉴로 돌아가기
	else:
		GlobalData.next_level()
		TransitionManager.reload_scene() # 다음 스테이지

func _on_hint_timer_timeout():
	is_hint_unlocked = true 
	ui_manager.play_hint_button_pulse()

func _reset_idle_timer():
	if is_hint_unlocked:
		return 
		
	hint_timer.start(current_hint_time) 
	ui_manager.reset_hint_button()

func _on_board_generated(texture: Texture2D, pos: Vector2, size: Vector2):
	ui_manager.setup_overlay(texture, pos, size)

func _on_hint_pressed():
	board_manager.highlight_hint_tile()

	