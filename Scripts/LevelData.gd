extends Resource
class_name LevelData

@export var level_name: String = "기본 민화"
@export var collection_place: String = "소장처 (ex: 행소박물관)" # ✨ 결과창용 추가
@export var artifact_texture: Texture2D
@export var grid_size: Vector2 = Vector2(3, 3)
@export var shuffle_steps: int = 1
@export var hint_wait_time: float = 1.0