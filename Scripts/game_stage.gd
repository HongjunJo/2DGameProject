extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var ui_manager: UIManager = $UIManager
@onready var hint_timer: Timer = $HintTimer

# ✨ 추가: 힌트 버튼 활성화까지 남은 시간 추적 변수
var current_hint_time: float = 15.0
var is_hint_unlocked: bool = false # ✨ 추가: 힌트가 한 번이라도 켜졌는지 기억하는 스위치

# GameStage.gd 내부
func _ready():
	# 1. 보드 매니저가 생성이 완료되면 UI 오버레이 설정을 동기화하도록 시그널 연결
	board_manager.board_generated.connect(_on_board_generated)
	
	# 2. UI 매니저의 버튼 신호를 보드 매니저의 기능과 연결
	ui_manager.view_button_down.connect(func(): ui_manager.show_overlay())
	ui_manager.view_button_up.connect(func(): ui_manager.hide_overlay())
	ui_manager.hint_button_pressed.connect(_on_hint_pressed)

	# ✨ 1. 타이머 아웃 시 익명 함수 대신 전용 함수 연결
	hint_timer.timeout.connect(_on_hint_timer_timeout)
	
	board_manager.player_interacted.connect(_reset_idle_timer)
	# 보드에서 퍼즐이 클리어되었다고 알리면 UI 버튼 끄고 타이머 정지!
	board_manager.puzzle_cleared.connect(func():
		hint_timer.stop() # ✨ 추가: 백그라운드에서 타이머가 다시 도는 것을 원천 차단
		ui_manager.disable_all_buttons()
	)
	
	# ✨ 추가: 보드 매니저의 LevelData에서 힌트 시간을 가져와 세팅
	if board_manager.level_data:
		current_hint_time = board_manager.level_data.hint_wait_time
		hint_timer.wait_time = current_hint_time
		hint_timer.start(current_hint_time) # 타이머 최초 시작

	# ✨ 4. 통신망 연결이 다 끝났으니, 보드 매니저에게 퍼즐 생성을 명령!
	board_manager.generate_board()

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
