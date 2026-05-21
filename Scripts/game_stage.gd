extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var ui_manager: UIManager = $UIManager
@onready var hint_timer: Timer = $HintTimer

# GameStage.gd 내부
func _ready():
	# 1. 보드 매니저가 생성이 완료되면 UI 오버레이 설정을 동기화하도록 시그널 연결
	board_manager.board_generated.connect(_on_board_generated)
    
	# 2. UI 매니저의 버튼 신호를 보드 매니저의 기능과 연결
	ui_manager.view_button_down.connect(func(): ui_manager.show_overlay())
	ui_manager.view_button_up.connect(func(): ui_manager.hide_overlay())
	ui_manager.hint_button_pressed.connect(_on_hint_pressed)
    
	# 3. 15초 타이머 아웃 시 UI 연출 재생
	hint_timer.timeout.connect(func(): ui_manager.play_hint_button_pulse())

	# ✨ 4. 통신망 연결이 다 끝났으니, 보드 매니저에게 퍼즐 생성을 명령!
	board_manager.generate_board()

func _unhandled_input(event):
	# 단순 마우스 이동(Hover)이 아니라, '클릭'이거나 '누른 채로 드래그'할 때만 타이머를 리셋하도록 조건 추가!
	if event is InputEventMouseButton or (event is InputEventMouseMotion and event.button_mask != 0):
		hint_timer.start(15.0)
		ui_manager.reset_hint_button()

func _on_board_generated(texture: Texture2D, pos: Vector2, size: Vector2):
	# 보드가 화면 어디에 어떤 크기로 배치되었는지 리포트를 받아서 UI 오버레이 맞춤
	ui_manager.setup_overlay(texture, pos, size)

func _on_hint_pressed():
	# UI에서 힌트를 누르면 보드 매니저에게 정답 시작점을 반짝이도록 명령
	board_manager.highlight_hint_tile()
