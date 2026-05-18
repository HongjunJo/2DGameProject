extends Area2D
class_name Tile

var current_grid_pos: Vector2
var target_grid_pos: Vector2 # 정답 위치 (나중에 클리어 판정 시 사용)
var is_obstacle: bool = false

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

# 타일이 생성될 때 호출될 초기화 함수
func setup(texture: Texture2D, region_rect: Rect2, grid_pos: Vector2, tile_size: Vector2, _is_obstacle: bool = false):
	current_grid_pos = grid_pos
	target_grid_pos = grid_pos
	is_obstacle = _is_obstacle
	
	# 스프라이트 동적 슬라이싱 (Region 활용)
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region_rect
	
	# 장애물 시각적 처리 (임시로 어둡게 처리, 나중에 장애물 텍스처로 교체 가능)
	if is_obstacle:
		sprite.modulate = Color(0.3, 0.3, 0.3, 1.0)
	
	# 터치 감지를 위한 콜리전 크기 세팅
	collision.shape.size = tile_size