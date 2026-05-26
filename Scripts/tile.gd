extends Area2D
class_name Tile

var current_grid_pos: Vector2
var target_grid_pos: Vector2
var hover_tween: Tween # ✨ 픽스: 날아갔던 트윈 변수 선언 복구!

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var highlight_border = $HighlightBorder 

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	highlight_border.hide() # 시작할 땐 테두리 숨김

func setup(texture: Texture2D, region_rect: Rect2, grid_pos: Vector2, tile_size: Vector2):
	current_grid_pos = grid_pos
	target_grid_pos = grid_pos
	
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region_rect
	sprite.show_behind_parent = true 
	
	collision.shape.size = tile_size
	
	# 테두리의 크기와 위치를 타일 크기에 맞춤
	highlight_border.size = tile_size
	highlight_border.position = -(tile_size / 2.0)

# ==========================================
# 🖱️ 마우스 호버: 테두리 + 쥬시한 스케일 업 (1.05 통일)
# ==========================================
func _on_mouse_entered():
	var board = get_parent() as BoardManager
	if board and board.frozen_piece != null: return
	if board and (board.is_locked or board.is_dragging): return
		
	highlight_border.border_color = Color.GOLD 
	highlight_border.show()
	
	if hover_tween and hover_tween.is_valid(): hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	z_index = 1

func _on_mouse_exited():
	var board = get_parent() as BoardManager
	if board and board.frozen_piece != null: return
	if board and board.is_locked: return
	
	# 드래그 중이라면 마우스가 살짝 벗어나도 절대 작아지지 않게 막음
	if board and board.is_dragging: return 
		
	highlight_border.hide()
	
	if hover_tween and hover_tween.is_valid(): hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	z_index = 0

# ==========================================
# ✨ 비상 스위치: 강제로 시각 효과(테두리, 크기) 초기화
# ==========================================
func force_unhover():
	# 얼려진(프리즈) 상태라면 건드리지 않음
	if has_meta("is_frozen") and get_meta("is_frozen"): 
		return
		
	highlight_border.hide()
	
	if hover_tween and hover_tween.is_valid(): 
		hover_tween.kill()
		
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	z_index = 0