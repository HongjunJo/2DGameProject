extends TextureRect

var is_dragging: bool = false
var active_resize_handle: String = "" # 현재 잡고 있는 핸들(모서리 또는 면)

var drag_start_pos: Vector2
var drag_start_size: Vector2
var drag_start_mouse: Vector2

var resize_handle_size: float = 44.0 
var aspect_ratio: float = 1.0

var min_width: float = 200.0
var max_width: float = 700.0

func _ready():
	mouse_entered.connect(func(): set_process(true))
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)

func _process(_delta):
	# 마우스 위치에 따라 8방향 커서 아이콘 지원
	if not is_dragging and active_resize_handle == "":
		var handle = _get_hovered_handle()
		if handle in ["TL", "BR"]: 
			mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE 
		elif handle in ["TR", "BL"]: 
			mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
		elif handle in ["L", "R"]: # 좌/우 면
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
		elif handle in ["T", "B"]: # 상/하 면
			mouse_default_cursor_shape = Control.CURSOR_VSIZE
		else:
			mouse_default_cursor_shape = Control.CURSOR_MOVE

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			self.move_to_front()
			active_resize_handle = _get_hovered_handle()
			
			if active_resize_handle != "":
				drag_start_pos = self.position
				drag_start_size = self.size
				drag_start_mouse = get_global_mouse_position()
			else:
				is_dragging = true
		else:
			is_dragging = false
			active_resize_handle = ""
			
	# ✨ 픽스 1: 지터링을 유발하던 중심점 보정을 빼고, 가장 심플하고 안정적인 줌으로 롤백
	elif event is InputEventMouseButton and event.pressed:
		var zoom_speed = 40.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_simple_zoom(self.size.x + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_simple_zoom(self.size.x - zoom_speed)

	elif event is InputEventMouseMotion:
		if is_dragging:
			self.position += event.relative
		elif active_resize_handle != "":
			_apply_resize()

# ==========================================
# ✨ 8방향 모서리 & 면 크기 조절 (비율 고정)
# ==========================================
func _apply_resize():
	var current_mouse = get_global_mouse_position()
	var mouse_delta = current_mouse - drag_start_mouse
	
	var target_width = drag_start_size.x
	
	# 우측(+) 방향으로 당길 때
	if active_resize_handle in ["R", "BR", "TR"]:
		target_width = drag_start_size.x + mouse_delta.x
	# 좌측(-) 방향으로 당길 때
	elif active_resize_handle in ["L", "BL", "TL"]:
		target_width = drag_start_size.x - mouse_delta.x
	# 하단 면을 당길 때는 Y축 이동량을 이용해 가로 너비 역산
	elif active_resize_handle == "B":
		var target_height = drag_start_size.y + mouse_delta.y
		target_width = target_height * aspect_ratio
	# 상단 면을 당길 때
	elif active_resize_handle == "T":
		var target_height = drag_start_size.y - mouse_delta.y
		target_width = target_height * aspect_ratio

	var new_width = clamp(target_width, min_width, max_width)
	var new_size = Vector2(new_width, new_width / aspect_ratio)
	var size_diff = new_size - drag_start_size
	
	var new_pos = drag_start_pos

	# 당기는 방향에 반대되는 축을 고정(보정)시켜 줍니다.
	if active_resize_handle in ["TR", "T"]:
		new_pos.y -= size_diff.y
	elif active_resize_handle == "BL":
		new_pos.x -= size_diff.x
	elif active_resize_handle in ["TL", "L"]:
		new_pos.x -= size_diff.x
		if active_resize_handle == "TL":
			new_pos.y -= size_diff.y

	self.position = new_pos
	self.size = new_size
	self.custom_minimum_size = new_size

# 휠 전용 심플 줌 (좌상단 앵커 기준)
func _apply_simple_zoom(target_width: float):
	var new_width = clamp(target_width, min_width, max_width)
	var new_size = Vector2(new_width, new_width / aspect_ratio)
	
	self.size = new_size
	self.custom_minimum_size = new_size

# 모서리 4개 + 면 4개 판독기
func _get_hovered_handle() -> String:
	var local = get_local_mouse_position()
	var on_left = local.x <= resize_handle_size
	var on_right = local.x >= self.size.x - resize_handle_size
	var on_top = local.y <= resize_handle_size
	var on_bottom = local.y >= self.size.y - resize_handle_size
	
	# 모서리를 우선 판정
	if on_top and on_left: return "TL"
	if on_top and on_right: return "TR"
	if on_bottom and on_left: return "BL"
	if on_bottom and on_right: return "BR"
	# 그 다음 면 판정
	if on_top: return "T"
	if on_bottom: return "B"
	if on_left: return "L"
	if on_right: return "R"
	return ""

func _on_mouse_exited():
	if active_resize_handle == "":
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		set_process(false)

func reset_transform(target_pos: Vector2, target_size: Vector2):
	if texture:
		var tex_size = texture.get_size()
		aspect_ratio = tex_size.x / tex_size.y
		
	self.scale = Vector2(1.0, 1.0)
	self.position = target_pos
	self.size = target_size
	self.custom_minimum_size = target_size