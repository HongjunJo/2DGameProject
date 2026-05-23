extends Resource
class_name LevelData

@export var level_name: String = "기본 민화"
@export var artifact_texture: Texture2D
@export var grid_size: Vector2 = Vector2(3, 3)
@export var shuffle_steps: int = 15 

# ✨ 추가: 이 스테이지에서 힌트가 뜰 때까지 대기할 시간 (초 단위)
@export var hint_wait_time: float = 15.0 

@export var obstacles: Array[Vector2] = []
@export var directional_tiles: Dictionary = {}