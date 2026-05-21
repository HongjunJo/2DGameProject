extends Resource
class_name LevelData

@export var level_name: String = "기본 민화"
@export var artifact_texture: Texture2D
@export var grid_size: Vector2 = Vector2(3, 3)

# ✨ 보드매니저에 있던 난이도 변수를 데이터(Resource) 쪽으로 이동!
@export var shuffle_steps: int = 15 

@export var obstacles: Array[Vector2] = []

# ✨ 추가: 단방향 타일 설정
# 사용법: 인스펙터에서 Dictionary 추가 -> Key에 Vector2(좌표), Value에 Vector2(방향) 입력
# 예: Key (1,1), Value (1,0) = (1,1) 타일에서는 무조건 오른쪽(x:1, y:0)으로만 나가야 함.
@export var directional_tiles: Dictionary = {}

