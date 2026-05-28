extends Node

# 시연용 디버그 매니저 (Autoload)
# F1: 힌트 쿨타임 무시하고 즉시 활성화
# F2: 현재 보드 완전 자동 클리어

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_debug_unlock_hint()
		elif event.keycode == KEY_F2:
			_debug_solve_puzzle()

func _debug_unlock_hint():
	var current_scene = get_tree().current_scene
	# GameStage인지 간단한 속성(HintTimer 여부)으로 확인
	if current_scene and current_scene.has_node("HintTimer"):
		var hint_timer = current_scene.get_node("HintTimer")
		var ui_manager = current_scene.get_node("UIManager")
		
		print("[Debug] F1: 힌트 즉시 활성화")
		if not hint_timer.is_stopped():
			hint_timer.stop()
		
		if "is_hint_unlocked" in current_scene:
			current_scene.is_hint_unlocked = true
			
		if ui_manager and ui_manager.has_method("play_hint_button_pulse"):
			ui_manager.play_hint_button_pulse()
			ui_manager.update_hint_cooldown(0)

func _debug_solve_puzzle():
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_node("BoardManager"):
		var board_manager = current_scene.get_node("BoardManager")
		print("[Debug] F2: 퍼즐 즉시 자동 풀기")
		
		# 이미 클리어 중이거나 잠긴 상태라면 예외 처리
		if board_manager.is_locked:
			return
			
		# 내부 퍼즐 로직을 모두 정답 위치로 맞춤
		if board_manager.has_method("_reset_board_logic"):
			board_manager._reset_board_logic()
		
		# 시각적으로 타일 위치 즉시 동기화
		if board_manager.has_method("_sync_visuals_instantly"):
			board_manager._sync_visuals_instantly()
			
		# 퍼즐 위치가 정상화되었으므로 클리어 판정 함수 호출
		if board_manager.has_method("check_win_condition"):
			board_manager.check_win_condition()
