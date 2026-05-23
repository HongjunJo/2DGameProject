extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var ui_manager: UIManager = $UIManager
@onready var hint_timer: Timer = $HintTimer

# ✨ 추가: 힌트 버튼 활성화까지 남은 시간 추적 변수
var current_hint_time: float = 15.0
var is_hint_unlocked: bool = false # ✨ 추가: 힌트가 한 번이라도 켜졌는지 기억하는 스위치

# GameStage.gd 내부
# GameStage.gd 내부 수정

func _ready():
	# ✨ 핵심: 현재 스테이지 데이터 주입
	var current_level = GlobalData.get_current_level()
	board_manager.level_data = current_level
	
	# 시그널 연결
	board_manager.board_generated.connect(_on_board_generated)
	ui_manager.view_button_down.connect(func(): ui_manager.show_overlay())
	ui_manager.view_button_up.connect(func(): ui_manager.hide_overlay())
	ui_manager.hint_button_pressed.connect(_on_hint_pressed)
	hint_timer.timeout.connect(_on_hint_timer_timeout)
	board_manager.player_interacted.connect(_reset_idle_timer)
	
	# ✨ 클리어 시 처리
	board_manager.puzzle_cleared.connect(_on_puzzle_cleared)
	
	# ✨ 다음 스테이지 버튼 클릭 시 처리
	ui_manager.next_stage_pressed.connect(_on_next_stage_requested)

	# 힌트 시간 세팅
	current_hint_time = current_level.hint_wait_time
	hint_timer.start(current_hint_time)

	# 게임 시작
	board_manager.generate_board()

func _on_puzzle_cleared():
	hint_timer.stop()
	ui_manager.disable_all_buttons()
	
	# 쥬시한 연출이 끝날 때쯤 결과 UI 띄우기 (약 1.5초 뒤)
	await get_tree().create_timer(1.5).timeout
	ui_manager.show_result_ui(GlobalData.is_last_level())

func _on_next_stage_requested():
	if GlobalData.is_last_level():
		GlobalData.current_level_index = 0
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	else:
		GlobalData.next_level()
		# ✨ 같은 GameStage 씬을 다시 로드하면, _ready에서 다음 데이터를 가져옴
		get_tree().reload_current_scene()

# ==========================================
# ✨ 2. 타이머가 끝났을 때 스위치를 켜는 전용 함수
func _on_hint_timer_timeout():
	is_hint_unlocked = true # "이제부터 힌트는 영원히 켜져 있다" 도장 쾅!
	ui_manager.play_hint_button_pulse()

func _reset_idle_timer():
	# ✨ 3. 핵심: 이미 힌트가 켜진(Unlocked) 상태라면, 리셋을 무시하고 그냥 리턴(Return)합니다.
	if is_hint_unlocked:
		return 
		
	hint_timer.start(current_hint_time) 
	ui_manager.reset_hint_button()

func _on_board_generated(texture: Texture2D, pos: Vector2, size: Vector2):
	# 보드가 화면 어디에 어떤 크기로 배치되었는지 리포트를 받아서 UI 오버레이 맞춤
	ui_manager.setup_overlay(texture, pos, size)

func _on_hint_pressed():
	# UI에서 힌트를 누르면 보드 매니저에게 정답 시작점을 반짝이도록 명령
	board_manager.highlight_hint_tile()
