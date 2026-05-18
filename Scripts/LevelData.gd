extends Resource
class_name LevelData

@export var level_name: String = "기본 민화"
@export var artifact_texture: Texture2D
@export var grid_size: Vector2 = Vector2(3, 3) # N x M (예: 3x3, 4x3)
@export var obstacles: Array[Vector2] = [] # 장애물이 위치할 그리드 좌표들 (예: [Vector2(1,1)])