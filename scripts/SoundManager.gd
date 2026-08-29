extends Node

# プロシージャル効果音マネージャ (外部音声ファイル不要)
# ピコピコ8-bit風の高品質なレトロサウンドを動的に合成して再生します。

var audio_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 12

# 事前キャッシュ用
var snd_paddle: AudioStreamWAV
var snd_wall: AudioStreamWAV
var snd_block_hit: AudioStreamWAV
var snd_block_break: AudioStreamWAV
var snd_launch: AudioStreamWAV
var snd_miss: AudioStreamWAV
var snd_game_over: AudioStreamWAV
var snd_win: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# オーディオプレイヤーのプール作成
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_pool.append(player)
	
	# 効果音を生成・キャッシュ
	_generate_all_sounds()

func _play(stream: AudioStreamWAV, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	for player in audio_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			return
	# すべて再生中の場合は最初のプレイヤーを使用
	var p = audio_pool[0]
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

# 各種効果音の再生関数
func play_paddle(offset_ratio: float = 0.0) -> void:
	# パドルの当たり位置によってピッチがわずかに変化
	var pitch = 1.0 + clamp(offset_ratio * 0.3, -0.3, 0.3)
	_play(snd_paddle, -5.0, pitch)

func play_wall() -> void:
	_play(snd_wall, -8.0, 1.0)

func play_block_hit() -> void:
	_play(snd_block_hit, -6.0, randf_range(0.95, 1.05))

func play_block_break(combo_pitch: float = 1.0) -> void:
	_play(snd_block_break, -4.0, combo_pitch)

func play_launch() -> void:
	_play(snd_launch, -5.0, 1.0)

func play_miss() -> void:
	_play(snd_miss, -4.0, 1.0)

func play_game_over() -> void:
	_play(snd_game_over, -2.0, 1.0)

func play_win() -> void:
	_play(snd_win, -2.0, 1.0)

# --- 波形生成ルーチン ---
func _generate_all_sounds() -> void:
	snd_paddle = _synthesize_sound(480.0, 720.0, 0.07, "square", 0.05)
	snd_wall = _synthesize_sound(300.0, 220.0, 0.05, "triangle", 0.04)
	snd_block_hit = _synthesize_sound(700.0, 950.0, 0.06, "sine", 0.05)
	snd_block_break = _synthesize_sound(550.0, 1400.0, 0.14, "square", 0.12)
	snd_launch = _synthesize_sound(260.0, 850.0, 0.12, "sine", 0.1)
	snd_miss = _synthesize_sound(320.0, 110.0, 0.35, "saw", 0.3)
	snd_game_over = _synthesize_melody([240.0, 200.0, 160.0, 120.0], 0.12, "saw")
	snd_win = _synthesize_melody([440.0, 554.37, 659.25, 880.0], 0.10, "square")

func _synthesize_sound(start_freq: float, end_freq: float, duration: float, wave_type: String, decay_time: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(duration * sample_rate)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var current_freq = lerp(start_freq, end_freq, t)
		phase += (current_freq * TAU) / sample_rate
		if phase >= TAU:
			phase = fmod(phase, TAU)
		
		var sample_val: float = 0.0
		match wave_type:
			"sine":
				sample_val = sin(phase)
			"square":
				sample_val = 1.0 if sin(phase) >= 0.0 else -1.0
			"triangle":
				sample_val = (2.0 / PI) * asin(sin(phase))
			"saw":
				sample_val = (phase / PI) - 1.0
			"noise":
				sample_val = randf_range(-1.0, 1.0)
		
		# エンベロープ (減衰)
		var env: float = 1.0
		var elapsed = float(i) / float(sample_rate)
		if elapsed > (duration - decay_time):
			env = max(0.0, 1.0 - (elapsed - (duration - decay_time)) / decay_time)
		
		var val_8bit = int(clamp((sample_val * env * 0.7 * 127.0) + 128.0, 0.0, 255.0))
		byte_array[i] = val_8bit
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_array
	return wav

func _synthesize_melody(notes: Array, note_duration: float, wave_type: String) -> AudioStreamWAV:
	var sample_rate = 22050
	var samples_per_note = int(note_duration * sample_rate)
	var total_samples = samples_per_note * notes.size()
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples)
	
	var sample_idx = 0
	for freq in notes:
		var phase: float = 0.0
		for i in range(samples_per_note):
			phase += (freq * TAU) / sample_rate
			if phase >= TAU:
				phase = fmod(phase, TAU)
			
			var sample_val: float = 0.0
			match wave_type:
				"sine":
					sample_val = sin(phase)
				"square":
					sample_val = 1.0 if sin(phase) >= 0.0 else -1.0
				"triangle":
					sample_val = (2.0 / PI) * asin(sin(phase))
				"saw":
					sample_val = (phase / PI) - 1.0
			
			var env = 1.0 - (float(i) / float(samples_per_note))
			var val_8bit = int(clamp((sample_val * env * 0.7 * 127.0) + 128.0, 0.0, 255.0))
			byte_array[sample_idx] = val_8bit
			sample_idx += 1
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_array
	return wav
