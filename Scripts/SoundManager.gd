extends Node

var bgm_duck_tween: Tween
var base_bgm_db: float = 0.0 

# ==========================================
# 1. Enums 
# ==========================================
enum SFX {
	GRAB,       # 0: 타일 잡기 
	SWAP,       # 1: 타일 밀어내기 
	FREEZE,     # 2: 우클릭 잠금
	UNFREEZE,   # 3: 우클릭 해제 
	HINT,       # 4: 힌트 장전 
	FAIL,       # 5: 오답 판정 
	CLEAR,      # 6: 클리어 
	UI_CLICK,   # 7: 일반 UI / 원본보기 
	TYPING      # 8: 텍스트 타이핑
}

@export var bgm_clips: Array[AudioStream] 
@export var sfx_clips: Array[AudioStream]

var bgm_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 15
var sfx_play_time: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	bgm_player = _create_audio_player("BGM_Track", "BGM")
	bgm_player.finished.connect(func(): bgm_player.play()) 
	
	for i in range(pool_size):
		sfx_pool.append(_create_audio_player("SFX_Source_" + str(i), "SFX"))

func _create_audio_player(node_name: String, bus_name: String) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus_name 
	add_child(player)
	return player

# --- BGM Control ---
func play_bgm(volume_scale: float = 1.0):
	if bgm_clips.is_empty() or bgm_clips[0] == null: return
	if bgm_player.playing: return
		
	base_bgm_db = linear_to_db(volume_scale)
	bgm_player.stream = bgm_clips[0]
	bgm_player.volume_db = base_bgm_db
	bgm_player.play()

func stop_bgm():
	bgm_player.stop()

# --- SFX Control ---
func play_sfx(sfx_type: SFX, duck_bgm: bool = false, pitch_variance: float = 0.05, volume_scale: float = 1.0):
	if sfx_type >= sfx_clips.size() or sfx_clips[sfx_type] == null: return
		
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if sfx_play_time.has(sfx_type):
		var last_time = sfx_play_time[sfx_type]
		if current_time - last_time < 0.05: return 
	sfx_play_time[sfx_type] = current_time
	
	var source = _get_free_sfx_source()
	source.stream = sfx_clips[sfx_type]
	source.volume_db = linear_to_db(volume_scale)
	
	source.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	source.play()

	if duck_bgm and bgm_player.playing:
		_apply_ducking(source.stream.get_length())

# ==========================================
# ✨ 특정 SFX 즉시 정지 함수 (로어 씬 스킵용)
# ==========================================
func stop_sfx(sfx_type: SFX):
	if sfx_type >= sfx_clips.size() or sfx_clips[sfx_type] == null: return
	
	var target_stream = sfx_clips[sfx_type]
	
	# 풀을 뒤져서 현재 해당 효과음을 틀고 있는 스피커를 찾아 즉시 전원을 뽑음
	for source in sfx_pool:
		if source.playing and source.stream == target_stream:
			source.stop()

# --- Ducking & Pool ---
func _apply_ducking(sfx_duration: float):
	if bgm_duck_tween and bgm_duck_tween.is_valid():
		bgm_duck_tween.kill()
	else:
		base_bgm_db = bgm_player.volume_db 

	bgm_duck_tween = create_tween()
	bgm_duck_tween.tween_property(bgm_player, "volume_db", base_bgm_db - 5.0, 0.1) 
	bgm_duck_tween.tween_interval(sfx_duration * 0.8)
	bgm_duck_tween.tween_property(bgm_player, "volume_db", base_bgm_db, 0.25)

func _get_free_sfx_source() -> AudioStreamPlayer:
	for source in sfx_pool:
		if not source.playing: return source
			
	var new_source = _create_audio_player("SFX_Source_Expanded_" + str(sfx_pool.size()), "SFX")
	sfx_pool.append(new_source)
	return new_source