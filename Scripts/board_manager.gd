extends Node2D
class_name BoardManager

signal board_generated(texture: Texture2D, position: Vector2, scaled_size: Vector2)
signal player_interacted
signal puzzle_cleared

@export var level_data: LevelData
@export var tile_scene: PackedScene
@export var max_board_size: Vector2 = Vector2(800, 800) 
@export var tile_spacing: float = 5.0 

@onready var path_line: Line2D = $PathLine 

var tiles: Dictionary = {}
var tile_size: Vector2
var is_dragging: bool = false 
var path_stack: Array[Vector2] = [] 
var is_locked: bool = false 
var current_mouse_grid_pos: Vector2 = Vector2(-1, -1) 
var hint_target_tile: Tile # 타일 객체의 참조 저장
var hint_action_tween: Tween 
var board_base_size: Vector2 
var frozen_piece: Node2D = null

# ==========================================
# 보드 생성 및 초기화
# ==========================================
func generate_board():
	# 1. 타일 이미지 크기와 설정된 그리드(행/열) 수, 타일 간 간격을 모두 합산하여
	#    보드의 실제 전체 사이즈를 계산합니다.
	var tex_size = level_data.artifact_texture.get_size()
	var total_spacing = Vector2(
		(level_data.grid_size.x - 1) * tile_spacing,
		(level_data.grid_size.y - 1) * tile_spacing
	)
	var total_board_size = tex_size + total_spacing
	board_base_size = total_board_size 

	# 2. 화면 영역(max_board_size)을 벗어나지 않도록 스케일을 조정하고 화면 중앙에 배치합니다.
	var scale_factor = min(max_board_size.x / total_board_size.x, max_board_size.y / total_board_size.y)
	self.scale = Vector2(scale_factor, scale_factor)
	var viewport_size = get_viewport_rect().size
	var scaled_board_size = total_board_size * scale_factor
	self.position = (viewport_size - scaled_board_size) / 2

	board_generated.emit(level_data.artifact_texture, self.position, scaled_board_size)

	# 3. 각 타일의 조각 사이즈를 계산하고 그리드를 순회하며 타일 객체를 생성합니다.
	tile_size = Vector2(tex_size.x / level_data.grid_size.x, tex_size.y / level_data.grid_size.y)
	for y in range(level_data.grid_size.y):
		for x in range(level_data.grid_size.x):
			var grid_pos = Vector2(x, y)
			create_tile(grid_pos)
			
	shuffle_board()

func create_tile(grid_pos: Vector2):
	var tile = tile_scene.instantiate() as Tile
	add_child(tile)
	
	var region_rect = Rect2(grid_pos * tile_size, tile_size)
	tile.setup(level_data.artifact_texture, region_rect, grid_pos, tile_size)
	
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	tile.position = grid_pos * step + (tile_size / 2)
	
	tiles[grid_pos] = tile

# ==========================================
# 입력 처리 (Input Handling)
# ==========================================
func _unhandled_input(event):
	if is_locked: return 

	if event is InputEventMouseButton:
		var local_pos = get_local_mouse_position()
		var grid_pos = get_grid_pos_from_local(local_pos)

		# ==========================================
		# 1. 우클릭 (MOUSE_BUTTON_RIGHT) 전역 제어
		# ==========================================
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 고정된 조각이 존재할 경우 위치에 관계없이 즉시 해제
			if frozen_piece != null:
				_unfreeze_tile(frozen_piece)
				check_win_condition()
				return 
				
			# 드래그 중일 경우 현재 조각을 해당 위치에 고정
			if is_dragging and path_stack.size() > 0:
				var holding_pos = path_stack.back() # 들고 있던 조각의 그리드 위치
				if tiles.has(holding_pos):
					_freeze_tile(tiles[holding_pos])
				return

		# ==========================================
		# 2. 보드판 외곽 예외 처리
		# ==========================================
		if not is_valid_grid_pos(grid_pos):
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				end_drag()
			return

		var clicked_tile = tiles[grid_pos]

		# ==========================================
		# 3. 좌클릭 (MOUSE_BUTTON_LEFT) 제어
		# ==========================================
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if frozen_piece != null:
					if frozen_piece == clicked_tile:
						_unfreeze_tile(clicked_tile)
						is_dragging = true
						current_mouse_grid_pos = grid_pos
						clicked_tile.z_index = 10
					else:
						return
				else:
					start_drag(local_pos)
			else:
				if is_dragging:
					end_drag()
				
	elif event is InputEventMouseMotion and is_dragging:
		var local_pos = get_local_mouse_position()
		continue_drag(local_pos)

# ==========================================
# 드래그 및 스왑 (Drag & Swap)
# ==========================================
func start_drag(local_pos: Vector2):
	var grid_pos = get_grid_pos_from_local(local_pos)
	if not is_valid_grid_pos(grid_pos): return
	
	is_dragging = true
	player_interacted.emit() 
	SoundManager.play_sfx(SoundManager.SFX.GRAB)

	# 대상 타일의 참조와 비교하여 힌트 애니메이션 정지 처리
	if tiles[grid_pos] == hint_target_tile and hint_action_tween and hint_action_tween.is_valid():
		hint_action_tween.kill()
		hint_target_tile.scale = Vector2(1.0, 1.0)
		hint_target_tile.sprite.modulate = Color.WHITE
		hint_target_tile.z_index = 0
	
	# 새로운 드래그 시작 시 이동 경로를 추적하는 스택을 초기화합니다.
	path_stack.clear()
	path_stack.append(grid_pos)
	current_mouse_grid_pos = grid_pos 

	# 드래그 중인 타일이 화면의 최상단에 렌더링되게 z_index를 높여줍니다.
	tiles[grid_pos].z_index = 10 
	
	# 시각적으로 이어지는 경로선을 시작합니다.
	path_line.clear_points()
	path_line.add_point(get_center_pos_from_grid(grid_pos))

func continue_drag(local_pos: Vector2):
	var grid_pos = get_grid_pos_from_local(local_pos)
	if not is_valid_grid_pos(grid_pos): return
	if grid_pos == current_mouse_grid_pos: return 
	current_mouse_grid_pos = grid_pos
	
	var last_pos = path_stack.back()
	
	if grid_pos != last_pos:
		var diff = grid_pos - last_pos
		
		# 되돌아가기 판정: 스택의 바로 이전 위치(size-2)에 도달하면 스왑을 되돌리고 경로도 잘라냅니다.
		if path_stack.size() >= 2 and grid_pos == path_stack[path_stack.size() - 2]:
			swap_tiles(last_pos, grid_pos)
			path_stack.pop_back()
			path_line.remove_point(path_line.get_points().size() - 1)
			
		# 인접한 타일 (상하좌우 1칸)으로의 드래그일 경우 진행합니다.
		elif abs(diff.x) + abs(diff.y) == 1:
			var current_tile = tiles[last_pos]
			
			# 방문했던 곳(루프)으로 진입 시도 시 경고 피드백(흔들림)을 줍니다.
			if grid_pos in path_stack:
				shake_tile(current_tile) 
				return 
				
			# 타일 스왑 처리 및 경로 스택 추가
			swap_tiles(last_pos, grid_pos)
			path_stack.append(grid_pos)
			
			tiles[grid_pos].z_index = 10
			tiles[last_pos].z_index = 0
			path_line.add_point(get_center_pos_from_grid(grid_pos))

func end_drag():
	if not is_dragging: return
	is_dragging = false
	
	if path_stack.size() > 0:
		var last_pos = path_stack.back()
		if tiles.has(last_pos):
			tiles[last_pos].z_index = 0
			# 드래그 종료 시 타일의 hover 상태 복구
			tiles[last_pos].force_unhover() 
	
	path_line.clear_points()
	check_win_condition()

# ==========================================
# 타일 상태 제어 (Freeze)
# ==========================================
func _freeze_tile(tile: Tile):
	is_dragging = false
	frozen_piece = tile
	
	SoundManager.play_sfx(SoundManager.SFX.FREEZE, false, 0.0, 0.6)

	var snap_pos = get_center_pos_from_grid(tile.current_grid_pos)
	tile.position = snap_pos
	
	tile.scale = Vector2(1.05, 1.05) 
	
	tile.sprite.modulate = Color(0.65, 0.85, 1.0, 1.0) 
	
	var border = tile.get_node("HighlightBorder")
	border.border_color = Color(0.3, 0.6, 1.0, 1.0) # 고정 시각 효과 적용
	border.show()

	tile.z_index = 5

func _unfreeze_tile(tile: Tile):
	frozen_piece = null
	
	SoundManager.play_sfx(SoundManager.SFX.UNFREEZE, false, 0.0, 0.6)

	tile.sprite.modulate = Color.WHITE
	tile.get_node("HighlightBorder").hide()
	tile.z_index = 0

# ==========================================
# 연출 및 유틸리티
# ==========================================
func swap_tiles(pos1: Vector2, pos2: Vector2, duration: float = 0.15):
	var tile1 = tiles[pos1]
	var tile2 = tiles[pos2]
	
	# 데이터상 타일 위치 스왑 갱신
	tiles[pos1] = tile2
	tiles[pos2] = tile1
	tile1.current_grid_pos = pos2
	tile2.current_grid_pos = pos1
	
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	var target_pos1 = pos2 * step + (tile_size / 2)
	var target_pos2 = pos1 * step + (tile_size / 2)
	
	# 부드러운 위치 이동(Tween) 연출 (사인(SINE) 곡선 활용)
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(tile1, "position", target_pos1, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile2, "position", target_pos2, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 드래그 중인 부유 상태의 타일들(z_index>=10)과 
	# 밀려나는 바닥 타일들의 스케일(Scale)을 차별화하여 입체감을 더합니다.
	if tile1.z_index >= 10:
		SoundManager.play_sfx(SoundManager.SFX.SWAP, false, 0.15, 0.7)
		tween.tween_property(tile1, "scale", Vector2(1.05, 1.05), duration) 
	else:
		tile1.scale = Vector2(0.9, 0.9) 
		tween.tween_property(tile1, "scale", Vector2(1.0, 1.0), duration * 1.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	if tile2.z_index >= 10:
		SoundManager.play_sfx(SoundManager.SFX.SWAP, false, 0.15, 0.7)
		tween.tween_property(tile2, "scale", Vector2(1.05, 1.05), duration) 
	else:
		tile2.scale = Vector2(0.9, 0.9) 
		tween.tween_property(tile2, "scale", Vector2(1.0, 1.0), duration * 1.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func get_grid_pos_from_local(local_pos: Vector2) -> Vector2:
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	var x = floor(local_pos.x / step.x)
	var y = floor(local_pos.y / step.y)
	return Vector2(x, y)

func is_valid_grid_pos(grid_pos: Vector2) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < level_data.grid_size.x and \
		   grid_pos.y >= 0 and grid_pos.y < level_data.grid_size.y

func get_center_pos_from_grid(grid_pos: Vector2) -> Vector2:
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	return grid_pos * step + (tile_size / 2)

# ==========================================
# 퍼즐 클리어 판정
# ==========================================
func check_win_condition():
	var is_clear = true
	# 모든 타일이 자신의 원래 목푯값(target_grid_pos)과 일치하는지 검사
	for tile in tiles.values():
		if tile.current_grid_pos != tile.target_grid_pos:
			is_clear = false
			break
			
	if is_clear:
		SoundManager.play_sfx(SoundManager.SFX.CLEAR, true, 0.0, 1.2)
		puzzle_cleared.emit() 
		play_clear_animation()
	else:
		# 오답 시 사운드 출력 후 타일들의 위치를 원래 드래그 전으로 롤백합니다.
		SoundManager.play_sfx(SoundManager.SFX.FAIL, false, 0.0, 0.7)
		rollback_path()

# ==========================================
# 피드백 연출 (Feedback)
# ==========================================
func shake_tile(tile: Tile):
	var center_pos = get_center_pos_from_grid(tile.current_grid_pos)
	var shake_offset = Vector2(8, 0)
	
	var tween = create_tween()
	tween.tween_property(tile, "position", center_pos + shake_offset, 0.03)
	tween.tween_property(tile, "position", center_pos - shake_offset, 0.06)
	tween.tween_property(tile, "position", center_pos, 0.03)

func rollback_path():
	is_locked = true 
	_rollback_step()

func _rollback_step():
	# 스택에 기록된 경로가 없으면 롤백을 종료하고 보드를 다시 활성화합니다.
	if path_stack.size() <= 1:
		is_locked = false
		path_stack.clear()
		path_line.clear_points()
		return
		
	# LIFO(후입선출) 구조로 스택을 팝하여 마지막 위치부터 역순으로 스왑하며 롤백
	var curr_pos = path_stack.pop_back()
	var prev_pos = path_stack.back()
	
	swap_tiles(curr_pos, prev_pos, 0.05)
	
	if path_line.get_points().size() > 0:
		path_line.remove_point(path_line.get_points().size() - 1)
	
	# 일정한 시각적 간격을 두고 재귀 호출하여 부드러운 롤백 연출 구현
	get_tree().create_timer(0.06).timeout.connect(_rollback_step)

# ==========================================
# 클리어 연출
# ==========================================
func play_clear_animation():
	is_locked = true 
	
	path_line.clear_points()
	path_stack.clear()
	frozen_piece = null 
	
	var tween = create_tween().set_parallel(true)
	
	var grid = level_data.grid_size
	var total_spacing = Vector2((grid.x - 1) * tile_spacing, (grid.y - 1) * tile_spacing)
	var target_board_pos = self.position + (total_spacing * self.scale) / 2.0
	
	tween.tween_property(self, "position", target_board_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for pos in tiles.keys():
		var tile = tiles[pos]
		var target_pos = pos * tile_size + (tile_size / 2)
		
		tile.sprite.modulate = Color.WHITE 
		if tile.has_node("HighlightBorder"):
			tile.get_node("HighlightBorder").hide()
		
		# 이동 시 타일 스케일 원복
		tween.tween_property(tile, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "position", target_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(_play_glow_and_bounce)

func _play_glow_and_bounce():
	var tween = create_tween().set_parallel(true)
	
	var original_scale = self.scale
	var current_pos = self.position 
	var bump_scale = original_scale * 1.05
	
	# 보드 전체를 확대할 때 중심을 기준으로 팝업되기 위해 위치 오프셋을 계산합니다.
	var pure_tex_size = Vector2(tile_size.x * level_data.grid_size.x, tile_size.y * level_data.grid_size.y)
	var pos_offset = (original_scale - bump_scale) * (pure_tex_size / 2.0)
	var bump_pos = current_pos + pos_offset
	
	tween.tween_property(self, "scale", bump_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", bump_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 다시 원래 크기로 튕기며 축소(Bounce)
	tween.chain().tween_property(self, "scale", original_scale, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", current_pos, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 완성된 타일 전체를 밝게(Glow) 빛나게 만든 후 서서히 원래 색으로 복구
	for tile in tiles.values():
		tile.sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		var color_tween = create_tween()
		color_tween.tween_property(tile.sprite, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ==========================================
# 자동 셔플 (시뮬레이션 기반)
# ==========================================
func shuffle_board():
	randomize() 
	var success = false
	var attempts = 0
	
	# 데드락에 빠지지 않고 정답을 섞기 위해 목표 지점을 배열 크기의 최댓값으로 설정합니다.
	var total_tiles = level_data.grid_size.x * level_data.grid_size.y
	var max_steps = int(total_tiles) - 1

	while not success and attempts < 100:
		attempts += 1
		success = _try_generate_path(max_steps) 
		
	if not success:
		push_warning("완벽한 셔플 경로를 찾지 못했습니다.")
		
	_sync_visuals_instantly()
	print("셔플 완료! (시도 횟수: ", attempts, ")")

# 셔플 검증 알고리즘: 실제 보드를 섞기 전 이론적으로 풀이가 가능한 상태인지 뎁스 우선 탐색으로 시뮬레이션합니다.
func _try_generate_path(max_steps: int) -> bool:
	_reset_board_logic() 
	
	# 전체 타일 중 70% 이상의 경로를 지났다면 데드락에 걸려도 성공적인 셔플로 간주합니다.
	var total_tiles = level_data.grid_size.x * level_data.grid_size.y
	var cut_line = int(total_tiles * 0.7) 
	
	var current_pos = Vector2(randi() % int(level_data.grid_size.x), randi() % int(level_data.grid_size.y))
	var visited_path: Array[Vector2] = [current_pos]
	
	for i in range(max_steps):
		var neighbors = _get_unvisited_neighbors(current_pos, visited_path)
		
		# 탐색 가능한 인접 타일이 없는 경우 (Deadlock에 도달했을 때의 예외 처리)
		if neighbors.is_empty():
			# 막다른 길에 도달한 타일을 역추적하기 위한 힌트 타일로 지정합니다.
			hint_target_tile = tiles[current_pos]
			
			# 도달 전까지 섞인 비율이 70%를 넘었다면 그 상태로 셔플을 성공 처리합니다.
			if visited_path.size() >= cut_line:
				return true
			else:
				return false
			
		var next_pos = neighbors.pick_random()
		_swap_logic_only(current_pos, next_pos)
		
		visited_path.append(next_pos)
		current_pos = next_pos
		
	# 최대 탐색 스텝에 정상적으로 도달했다면 마지막 위치를 역추적용 힌트로 지정합니다.
	hint_target_tile = tiles[current_pos]
	return true

# --- 셔플 및 검증용 헬퍼 함수들 ---
func _reset_board_logic():
	var all_tiles = tiles.values()
	tiles.clear()
	for tile in all_tiles:
		tile.current_grid_pos = tile.target_grid_pos
		tiles[tile.target_grid_pos] = tile

func _get_unvisited_neighbors(pos: Vector2, visited: Array[Vector2]) -> Array[Vector2]:
	var neighbors: Array[Vector2] = []
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	
	for dir in directions:
		var next_pos = pos + dir
		if is_valid_grid_pos(next_pos) and not (next_pos in visited):
			neighbors.append(next_pos)
	return neighbors

func _swap_logic_only(pos1: Vector2, pos2: Vector2):
	var tile1 = tiles[pos1]
	var tile2 = tiles[pos2]
	
	tiles[pos1] = tile2
	tiles[pos2] = tile1
	tile1.current_grid_pos = pos2
	tile2.current_grid_pos = pos1

func _sync_visuals_instantly():
	for pos in tiles.keys():
		var tile = tiles[pos]
		tile.position = get_center_pos_from_grid(pos)

# ==========================================
# 힌트 시스템 (타일 강조 연출)
# ==========================================
func highlight_hint_tile():
	if not is_instance_valid(hint_target_tile): return
	
	if hint_action_tween and hint_action_tween.is_valid():
		return
	
	SoundManager.play_sfx(SoundManager.SFX.UI_CLICK, false, 0.0, 1.2)
		
	hint_action_tween = create_tween()
	hint_target_tile.z_index = 20
	
	# 기존 상태 보존을 위한 변수
	var target_color = Color.WHITE
	var target_scale = Vector2(1.0, 1.0)
	var target_z_index = 0
	
	# 타일이 고정(Freeze) 상태인 경우 상태값 오버라이드
	if frozen_piece == hint_target_tile:
		target_color = Color(0.65, 0.85, 1.0, 1.0) 
		target_scale = Vector2(1.1, 1.1)           
		target_z_index = 5
	
	# 강조 애니메이션 적용 (기본 크기 대비 1.2배로 확대)
	hint_action_tween.tween_property(hint_target_tile.sprite, "modulate", Color.GOLD, 0.2)
	hint_action_tween.tween_property(hint_target_tile, "scale", Vector2(1.2, 1.2), 0.2)
	
	# 기본 상태로 복귀하는 체인
	hint_action_tween.tween_property(hint_target_tile.sprite, "modulate", target_color, 0.2)
	hint_action_tween.tween_property(hint_target_tile, "scale", target_scale, 0.2)
	
	hint_action_tween.set_loops(3) # 3회 반복
	hint_action_tween.finished.connect(func(): hint_target_tile.z_index = target_z_index)

