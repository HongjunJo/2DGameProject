extends Area2D
class_name Tile

var current_grid_pos: Vector2
var target_grid_pos: Vector2
var is_obstacle: bool = false
var allowed_direction: Vector2 = Vector2.ZERO # ✨ 추가: Vector2.ZERO면 자유 이동

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

# ✨ 매개변수 끝에 _direction 추가
func setup(texture: Texture2D, region_rect: Rect2, grid_pos: Vector2, tile_size: Vector2, _is_obstacle: bool = false, _direction: Vector2 = Vector2.ZERO):
	current_grid_pos = grid_pos
	target_grid_pos = grid_pos
	is_obstacle = _is_obstacle
	allowed_direction = _direction # ✨ 방향 저장
	
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region_rect
	
	sprite.show_behind_parent = true

	if is_obstacle:
		sprite.modulate = Color(0.3, 0.3, 0.3, 1.0)
	
	collision.shape.size = tile_size
	
	# ✨ 방향이 설정되어 있으면 화면에 다시 그리도록 호출
	if allowed_direction != Vector2.ZERO:
		queue_redraw()

# ✨ 임시 화살표 그리기 (MVP용) - 나중에 스프라이트로 교체 가능
func _draw():
	if allowed_direction != Vector2.ZERO:
		var center = Vector2.ZERO # 중심점 (Area2D의 로컬 0,0)
		var arrow_end = allowed_direction * (collision.shape.size.x * 0.3)
		# 두꺼운 금색 선과 끝부분 원형으로 화살표 표현
		draw_line(center, arrow_end, Color.GOLD, 6.0)
		draw_circle(arrow_end, 6.0, Color.GOLD)