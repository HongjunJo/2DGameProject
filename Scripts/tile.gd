extends Area2D
class_name Tile

var current_grid_pos: Vector2
var target_grid_pos: Vector2
var is_obstacle: bool = false
var allowed_direction: Vector2 = Vector2.ZERO 

var hover_tween: Tween # ✨ 추가: 호버링 애니메이션 제어용

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

# ✨ 추가: 마우스 감지 시그널 연결
func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(texture: Texture2D, region_rect: Rect2, grid_pos: Vector2, tile_size: Vector2, _is_obstacle: bool = false, _direction: Vector2 = Vector2.ZERO):
	current_grid_pos = grid_pos
	target_grid_pos = grid_pos
	is_obstacle = _is_obstacle
	allowed_direction = _direction 
	
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region_rect
	sprite.show_behind_parent = true 
	
	if is_obstacle:
		sprite.modulate = Color(0.3, 0.3, 0.3, 1.0)
	
	collision.shape.size = tile_size
	
	if allowed_direction != Vector2.ZERO:
		queue_redraw()

func _draw():
	if allowed_direction != Vector2.ZERO:
		var center = Vector2.ZERO 
		var arrow_end = allowed_direction * (collision.shape.size.x * 0.3)
		draw_line(center, arrow_end, Color.GOLD, 6.0)
		draw_circle(arrow_end, 6.0, Color.GOLD)

# ==========================================
# ✨ 호버링 피드백 로직
# ==========================================
func _on_mouse_entered():
	if is_obstacle: return
	
	# 부모(BoardManager)가 잠겨있거나 이미 무언가 드래그 중이라면 피드백 생략
	var board = get_parent() as BoardManager
	if board and (board.is_locked or board.is_dragging):
		return
		
	if hover_tween and hover_tween.is_valid(): 
		hover_tween.kill()
		
	hover_tween = create_tween()
	# 마우스를 올리면 0.1초 만에 1.05배로 살짝 커지며 위로 튀어 보이기 위해 z_index를 1로 조절
	hover_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	z_index = 1

func _on_mouse_exited():
	if is_obstacle: return
	
	var board = get_parent() as BoardManager
	if board and board.is_locked: 
		return
		
	if hover_tween and hover_tween.is_valid(): 
		hover_tween.kill()
		
	hover_tween = create_tween()
	# 마우스가 나가면 원래 크기(1.0)와 기본 레이어(0)로 복구
	hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	z_index = 0