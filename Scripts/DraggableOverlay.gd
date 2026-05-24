extends TextureRect

var is_dragging: bool = false
var drag_start_pos: Vector2

func _gui_input(event):
	# 1. 마우스 왼쪽 버튼 클릭으로 드래그 시작/종료
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			# 이 이미지가 그려지는 z_index를 위로 올려서 다른 UI에 안 가려지게 할 수도 있습니다.
			self.move_to_front() 
		else:
			is_dragging = false
			
	# 2. 마우스 드래그 중 위치 이동
	elif event is InputEventMouseMotion and is_dragging:
		self.position += event.relative

	# 3. 마우스 휠로 확대/축소 (줌 인/아웃)
	elif event is InputEventMouseButton and event.pressed:
		var zoom_factor = 1.1
		var min_scale = Vector2(0.5, 0.5)
		var max_scale = Vector2(3.0, 3.0)
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			self.scale = (self.scale * zoom_factor).clamp(min_scale, max_scale)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			self.scale = (self.scale / zoom_factor).clamp(min_scale, max_scale)

# 버튼으로 켰을 때 원래 위치와 크기로 깔끔하게 리셋해주는 함수
func reset_transform(target_pos: Vector2, target_size: Vector2):
	self.scale = Vector2(1.0, 1.0)
	self.position = target_pos
	self.size = target_size
	self.custom_minimum_size = target_size