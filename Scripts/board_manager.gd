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
var hint_target_tile: Tile # ✨ 픽스: 좌표(Vector2)가 아니라 타일 객체(Tile) 자체를 기억합니다!
var hint_action_tween: Tween 
var board_base_size: Vector2 

func generate_board():
	var tex_size = level_data.artifact_texture.get_size()
	
	var total_spacing = Vector2(
		(level_data.grid_size.x - 1) * tile_spacing,
		(level_data.grid_size.y - 1) * tile_spacing
	)
	var total_board_size = tex_size + total_spacing
	
	board_base_size = total_board_size 

	var scale_factor = min(max_board_size.x / total_board_size.x, max_board_size.y / total_board_size.y)
	self.scale = Vector2(scale_factor, scale_factor)
	
	var viewport_size = get_viewport_rect().size
	var scaled_board_size = total_board_size * scale_factor
	self.position = (viewport_size - scaled_board_size) / 2

	board_generated.emit(level_data.artifact_texture, self.position, scaled_board_size)

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
	tile.setup(level_data.artifact_texture, region_rect, grid_pos, tile_size) # 픽스: 기믹 변수들 제거
	
	var step = tile_size + Vector2(tile_spacing, tile_spacing)
	tile.position = grid_pos * step + (tile_size / 2)
	
	tiles[grid_pos] = tile

# ==========================================
# 🎮 입력 처리 (Input Handling)
# ==========================================
func _unhandled_input(event):
	if is_locked: return 

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos = get_local_mouse_position()
			start_drag(local_pos)
		else:
			end_drag()
			
	elif event is InputEventMouseMotion and is_dragging:
		var local_pos = get_local_mouse_position()
		continue_drag(local_pos)

# ==========================================
# 🧩 드래그 앤 스왑 핵심 로직
# ==========================================
func start_drag(local_pos: Vector2):
	var grid_pos = get_grid_pos_from_local(local_pos)
	if not is_valid_grid_pos(grid_pos): return
	
	is_dragging = true
	player_interacted.emit() 
	
	# ✨ 픽스: 좌표 비교가 아니라 '객체 자체'를 비교하여 가로채기
	if tiles[grid_pos] == hint_target_tile and hint_action_tween and hint_action_tween.is_valid():
		hint_action_tween.kill()
		hint_target_tile.scale = Vector2(1.0, 1.0)
		hint_target_tile.sprite.modulate = Color.WHITE
		hint_target_tile.z_index = 0
	
	path_stack.clear()
	path_stack.append(grid_pos)
	
	current_mouse_grid_pos = grid_pos 

	tiles[grid_pos].z_index = 10 
	
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
		
		if path_stack.size() >= 2 and grid_pos == path_stack[path_stack.size() - 2]:
			swap_tiles(last_pos, grid_pos)
			path_stack.pop_back()
			path_line.remove_point(path_line.get_points().size() - 1)
			
		elif abs(diff.x) + abs(diff.y) == 1:
			var current_tile = tiles[last_pos]
			
			if grid_pos in path_stack:
				shake_tile(current_tile) 
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
	
	path_line.clear_points()
	check_win_condition()

# ==========================================
# ✨ 쥬시니스 & 헬퍼 함수들
# ==========================================
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
	
	tween.tween_property(tile1, "position", target_pos1, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile2, "position", target_pos2, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tile1.scale = Vector2(0.9, 0.9)
	tile2.scale = Vector2(0.9, 0.9)
	
	tween.tween_property(tile1, "scale", Vector2(1.0, 1.0), duration * 1.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
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
# ✨ 정답 판정 함수
# ==========================================
func check_win_condition():
	var is_clear = true
	for tile in tiles.values():
		if tile.current_grid_pos != tile.target_grid_pos:
			is_clear = false
			break
			
	if is_clear:
		print("🎉 퍼즐 클리어! (유물 복원 성공)")
		puzzle_cleared.emit() 
		play_clear_animation()
	else:
		print("❌ 오답입니다. (아직 섞여 있음)")
		rollback_path()

# ==========================================
# ✨ 피드백 및 연출
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
	if path_stack.size() <= 1:
		is_locked = false
		path_stack.clear()
		path_line.clear_points()
		return
		
	var curr_pos = path_stack.pop_back()
	var prev_pos = path_stack.back()
	
	swap_tiles(curr_pos, prev_pos, 0.05)
	
	if path_line.get_points().size() > 0:
		path_line.remove_point(path_line.get_points().size() - 1)
	
	get_tree().create_timer(0.06).timeout.connect(_rollback_step)

# ==========================================
# ✨ Phase 5: 클리어 폴리싱 (쥬시니스)
# ==========================================
func play_clear_animation():
	is_locked = true 
	var tween = create_tween().set_parallel(true)
	
	var grid = level_data.grid_size
	var total_spacing = Vector2((grid.x - 1) * tile_spacing, (grid.y - 1) * tile_spacing)
	var target_board_pos = self.position + (total_spacing * self.scale) / 2.0
	
	tween.tween_property(self, "position", target_board_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for pos in tiles.keys():
		var tile = tiles[pos]
		var target_pos = pos * tile_size + (tile_size / 2)
		
		tile.sprite.modulate = Color.WHITE 
		
		tween.tween_property(tile, "position", target_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(_play_glow_and_bounce)

func _play_glow_and_bounce():
	var tween = create_tween().set_parallel(true)
	
	var original_scale = self.scale
	var current_pos = self.position 
	var bump_scale = original_scale * 1.05
	
	var pure_tex_size = Vector2(tile_size.x * level_data.grid_size.x, tile_size.y * level_data.grid_size.y)
	var pos_offset = (original_scale - bump_scale) * (pure_tex_size / 2.0)
	var bump_pos = current_pos + pos_offset
	
	tween.tween_property(self, "scale", bump_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", bump_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_property(self, "scale", original_scale, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", current_pos, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	for tile in tiles.values():
		tile.sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		var color_tween = create_tween()
		color_tween.tween_property(tile.sprite, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ==========================================
# 🎲 오토 셔플 (클리어 보장 시뮬레이션)
# ==========================================
func shuffle_board():
	randomize() 
	var success = false
	var attempts = 0
	
	# ✨ 픽스 1. 목표는 이론상 완벽한 최대치(전체 칸 수 - 1)로 당당하게 줍니다!
	var total_tiles = level_data.grid_size.x * level_data.grid_size.y
	var max_steps = int(total_tiles) - 1 
	
	while not success and attempts < 100:
		attempts += 1
		success = _try_generate_path(max_steps) 
		
	if not success:
		print("경고: 완벽한 셔플 경로를 찾지 못했습니다.")
		
	_sync_visuals_instantly()
	print("셔플 완료! (시도 횟수: ", attempts, ")")

func _try_generate_path(max_steps: int) -> bool:
	_reset_board_logic() 
	
	# ✨ 픽스 2. 성공 커트라인을 '전체 보드판 칸 수의 70%'로 쾅! 못 박습니다.
	var total_tiles = level_data.grid_size.x * level_data.grid_size.y
	var cut_line = int(total_tiles * 0.7) 
	
	var current_pos = Vector2(randi() % int(level_data.grid_size.x), randi() % int(level_data.grid_size.y))
	var visited_path: Array[Vector2] = [current_pos]
	
	for i in range(max_steps):
		var neighbors = _get_unvisited_neighbors(current_pos, visited_path)
		
		# 막다른 길(Deadlock)에 갇혔을 때
		if neighbors.is_empty():
			hint_target_tile = tiles[current_pos] # 실패하든 성공하든 힌트는 무조건 박제
			
			# ✨ 픽스 3. 방문한 칸 수가 우리가 정한 절대 커트라인(70%)을 넘었는지만 봅니다.
			if visited_path.size() >= cut_line:
				return true
			else:
				return false
			
		var next_pos = neighbors.pick_random()
		_swap_logic_only(current_pos, next_pos)
		
		visited_path.append(next_pos)
		current_pos = next_pos
		
	# 최대 스텝까지 갇히지 않고 완벽하게 도달했을 때
	hint_target_tile = tiles[current_pos]
	return true

# --- 셔플용 헬퍼 함수들 ---
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
# ✨ 힌트 기능: 정답 타일 반짝이기
# ==========================================
func highlight_hint_tile():
	if not is_instance_valid(hint_target_tile): return
	
	if hint_action_tween and hint_action_tween.is_valid():
		return
		
	hint_action_tween = create_tween()
	hint_target_tile.z_index = 20
	hint_action_tween.tween_property(hint_target_tile.sprite, "modulate", Color.GOLD, 0.2)
	hint_action_tween.tween_property(hint_target_tile, "scale", Vector2(1.1, 1.1), 0.2)
	hint_action_tween.tween_property(hint_target_tile.sprite, "modulate", Color.WHITE, 0.2)
	hint_action_tween.tween_property(hint_target_tile, "scale", Vector2(1.0, 1.0), 0.2)
	hint_action_tween.set_loops(3)
	hint_action_tween.finished.connect(func(): hint_target_tile.z_index = 0)
