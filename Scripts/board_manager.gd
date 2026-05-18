extends Node2D

@export var level_data: LevelData
@export var tile_scene: PackedScene
@export var max_board_size: Vector2 = Vector2(800, 800) # 화면에서 보드가 차지할 수 있는 최대 크기 제한
@export var tile_spacing: float = 5.0 # 타일 사이의 틈(여백) 크기

@onready var path_line: Line2D = $PathLine # 선 긋기 노드

var tiles: Dictionary = {}
var tile_size: Vector2
var is_dragging: bool = false 
var path_stack: Array[Vector2] = [] # 지나온 궤적을 저장할 스택
var is_locked: bool = false # 애니메이션 재생 중 입력 방지용 플래그
var current_mouse_grid_pos: Vector2 = Vector2(-1, -1) # ✨ 추가: 중복 연산 방지용 변수


func _ready():
	if level_data and level_data.artifact_texture:
		generate_board()

func generate_board():
	var tex_size = level_data.artifact_texture.get_size()
	
	# 여백을 포함한 전체 보드의 실제 물리적 크기 계산
	var total_spacing = Vector2(
		(level_data.grid_size.x - 1) * tile_spacing,
		(level_data.grid_size.y - 1) * tile_spacing
	)
	var total_board_size = tex_size + total_spacing
	
	# 여백까지 포함한 보드가 화면(max_board_size)에 딱 맞게 들어가도록 스케일 계산
	var scale_factor = min(max_board_size.x / total_board_size.x, max_board_size.y / total_board_size.y)
	self.scale = Vector2(scale_factor, scale_factor)
	
	# 화면 정중앙 배치
	var viewport_size = get_viewport_rect().size
	var scaled_board_size = total_board_size * scale_factor
	self.position = (viewport_size - scaled_board_size) / 2
	
	# 타일 하나당 크기는 원본 크기 그대로 유지
	tile_size = Vector2(tex_size.x / level_data.grid_size.x, tex_size.y / level_data.grid_size.y)
	
	for y in range(level_data.grid_size.y):
		for x in range(level_data.grid_size.x):
			var grid_pos = Vector2(x, y)
			create_tile(grid_pos)

func create_tile(grid_pos: Vector2):
	var tile = tile_scene.instantiate() as Tile
	add_child(tile)
	
	# Region 사각형 영역 계산 (원본 이미지 좌표계 기준)
	var region_rect = Rect2(grid_pos * tile_size, tile_size)
	
	# 장애물 여부 확인
	var is_obs = grid_pos in level_data.obstacles
	
	# 타일 초기화
	tile.setup(level_data.artifact_texture, region_rect, grid_pos, tile_size, is_obs)
	
	# 여백(tile_spacing)을 포함한 좌표(Step) 계산
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	tile.position = grid_pos * step + (tile_size / 2)
	
	# 딕셔너리에 저장
	tiles[grid_pos] = tile

# ==========================================
# 🎮 입력 처리 (Input Handling)
# ==========================================
func _unhandled_input(event):
	if is_locked: return # ✨ 추가: 잠겨있으면 입력 무시

	# 마우스 클릭 (모바일 환경의 터치도 Godot 설정에서 마우스로 에뮬레이트 가능)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos = get_local_mouse_position()
			start_drag(local_pos)
		else:
			end_drag()
			
	# 마우스(터치) 드래그 중
	elif event is InputEventMouseMotion and is_dragging:
		var local_pos = get_local_mouse_position()
		continue_drag(local_pos)

# ==========================================
# 🧩 드래그 앤 스왑 핵심 로직
# ==========================================
func start_drag(local_pos: Vector2):
	var grid_pos = get_grid_pos_from_local(local_pos)
	if not is_valid_grid_pos(grid_pos): return
	if tiles[grid_pos].is_obstacle: return
	
	is_dragging = true
	path_stack.clear()
	path_stack.append(grid_pos)
	
	current_mouse_grid_pos = grid_pos # ✨ 마우스 시작 위치 기록

	tiles[grid_pos].z_index = 10 # 드래그 중인 타일을 최상위로 올림
	
	# ✨ 선 긋기 시작: 기존 선 초기화 후 첫 번째 점 추가
	path_line.clear_points()
	path_line.add_point(get_center_pos_from_grid(grid_pos))

func continue_drag(local_pos: Vector2):
	var grid_pos = get_grid_pos_from_local(local_pos)
	if not is_valid_grid_pos(grid_pos): return

	# 마우스가 '이전과 다른 새로운 칸'으로 넘어갔을 때만 연산 진행 (스팸 방지)
	if grid_pos == current_mouse_grid_pos: return 
	current_mouse_grid_pos = grid_pos # 위치 갱신

	var last_pos = path_stack.back()
	
	if grid_pos != last_pos:
		var diff = grid_pos - last_pos
		
		# 1. 역방향 이동 (Undo)
		if path_stack.size() >= 2 and grid_pos == path_stack[path_stack.size() - 2]:
			swap_tiles(last_pos, grid_pos)
			path_stack.pop_back()
			path_line.remove_point(path_line.get_points().size() - 1)
			
		# 2. 새로운 전진
		elif abs(diff.x) + abs(diff.y) == 1:
			# ✨ 수정: 방문한 타일이거나 장애물이면 진입을 막고 흔들기(Shake) 애니메이션 실행
			if grid_pos in path_stack or tiles[grid_pos].is_obstacle:
				shake_tile(tiles[last_pos]) 
				return 
				
			swap_tiles(last_pos, grid_pos)
			path_stack.append(grid_pos)
			
			tiles[grid_pos].z_index = 10
			tiles[last_pos].z_index = 0
			
			path_line.add_point(get_center_pos_from_grid(grid_pos))

func end_drag():
	if not is_dragging: return
	is_dragging = false
	
	var last_pos = path_stack.back()
	tiles[last_pos].z_index = 0
	
	# ✨ 드래그 종료 시 선 지우기 (원한다면 안 지우고 놔둬도 됩니다)
	path_line.clear_points()
	
	# ✨ 정답 판정 실행
	check_win_condition()

# ==========================================
# ✨ 쥬시니스 & 헬퍼 함수들
# ==========================================
# ✨ 수정: duration 매개변수 추가 (기본값 0.15초)
func swap_tiles(pos1: Vector2, pos2: Vector2, duration: float = 0.15):
	var tile1 = tiles[pos1]
	var tile2 = tiles[pos2]
	
	tiles[pos1] = tile2
	tiles[pos2] = tile1
	tile1.current_grid_pos = pos2
	tile2.current_grid_pos = pos1
	
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	var target_pos1 = pos2 * step + (tile_size / 2)
	var target_pos2 = pos1 * step + (tile_size / 2)
	
	var tween = create_tween().set_parallel(true)
	# ✨ 수정: 고정값 0.15 대신 duration 사용
	tween.tween_property(tile1, "position", target_pos1, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile2, "position", target_pos2, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func get_grid_pos_from_local(local_pos: Vector2) -> Vector2:
	# ✨ 수정: 마우스 좌표를 인덱스로 바꿀 때 여백이 포함된 전체 타일 간격(Step)으로 나눔
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	var x = floor(local_pos.x / step.x)
	var y = floor(local_pos.y / step.y)
	return Vector2(x, y)

# 좌표가 보드판(N x M) 안에 있는지 검사
func is_valid_grid_pos(grid_pos: Vector2) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < level_data.grid_size.x and \
		   grid_pos.y >= 0 and grid_pos.y < level_data.grid_size.y

# ✨ 추가: 그리드 좌표를 입력받아 여백이 포함된 실제 화면상의 '중앙 좌표' 반환
func get_center_pos_from_grid(grid_pos: Vector2) -> Vector2:
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	return grid_pos * step + (tile_size / 2)

# ==========================================
# ✨ 정답 판정 함수
# ==========================================
func check_win_condition():
	var is_clear = true
	
	for tile in tiles.values():
		# 하나라도 원래 자리가 아니면 오답
		if tile.current_grid_pos != tile.target_grid_pos:
			is_clear = false
			break
			
	if is_clear:
		print("🎉 퍼즐 클리어! (유물 복원 성공)")
		# TODO: 나중에 Phase 5의 클리어 폴리싱(스냅, 빛나는 연출 등)을 여기에 연결합니다.
	else:
		print("❌ 오답입니다. (아직 섞여 있음)")
		rollback_path() # ✨ 추가: 실패 시 롤백 실행		

# ==========================================
# ✨ 피드백 및 연출 (Phase 2)
# ==========================================

# 타일 거부 피드백 (좌우로 짧게 덜덜 흔들림)
func shake_tile(tile: Tile):
	# ✨ 핵심 픽스: 현재 위치(tile.position)가 아닌 '원래 있어야 할 정중앙 위치' 계산
	var center_pos = get_center_pos_from_grid(tile.current_grid_pos)
	var shake_offset = Vector2(8, 0)
	
	var tween = create_tween()
	# 흔들기가 끝나면 무조건 격자의 정중앙(center_pos)에 안착합니다.
	tween.tween_property(tile, "position", center_pos + shake_offset, 0.03)
	tween.tween_property(tile, "position", center_pos - shake_offset, 0.06)
	tween.tween_property(tile, "position", center_pos, 0.03)

# 실패 시 초고속 되감기 시작
func rollback_path():
	is_locked = true # 플레이어 조작 잠금
	_rollback_step()

# 재귀적으로(연쇄적으로) 한 칸씩 역순환
func _rollback_step():
	# 돌아갈 경로가 없으면 잠금 해제 후 종료
	if path_stack.size() <= 1:
		is_locked = false
		path_stack.clear()
		path_line.clear_points()
		return
		
	var curr_pos = path_stack.pop_back()
	var prev_pos = path_stack.back()
	
	# 매우 빠른 속도(0.05초)로 스왑
	swap_tiles(curr_pos, prev_pos, 0.05)
	
	# 궤적 선도 한 칸 지우기
	if path_line.get_points().size() > 0:
		path_line.remove_point(path_line.get_points().size() - 1)
	
	# 0.06초(스왑 시간 0.05초 + 여유 0.01초) 대기 후 다음 스텝 실행
	get_tree().create_timer(0.06).timeout.connect(_rollback_step)