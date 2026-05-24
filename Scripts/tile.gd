extends Area2D
class_name Tile

var current_grid_pos: Vector2
var target_grid_pos: Vector2
var hover_tween: Tween 

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(texture: Texture2D, region_rect: Rect2, grid_pos: Vector2, tile_size: Vector2):
	current_grid_pos = grid_pos
	target_grid_pos = grid_pos
	
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region_rect
	sprite.show_behind_parent = true 
	
	collision.shape.size = tile_size

func _on_mouse_entered():
	var board = get_parent() as BoardManager
	if board and (board.is_locked or board.is_dragging):
		return
		
	if hover_tween and hover_tween.is_valid(): 
		hover_tween.kill()
		
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	z_index = 1

func _on_mouse_exited():
	var board = get_parent() as BoardManager
	if board and board.is_locked: 
		return
		
	if hover_tween and hover_tween.is_valid(): 
		hover_tween.kill()
		
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	z_index = 0