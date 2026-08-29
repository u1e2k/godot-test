extends Node2D
class_name GameManager

@export var block_scene: PackedScene = preload("res://scenes/Block.tscn")

@onready var paddle: Paddle = $Paddle
@onready var ball: Ball = $Ball
@onready var blocks_container: Node2D = $Blocks
@onready var ui: GameUI = $UI
@onready var camera: Camera2D = $Camera2D

var score: int = 0
var high_score: int = 0
var lives: int = 3
var current_stage: int = 1
var remaining_blocks: int = 0

# カメラシェイク用
var shake_amount: float = 0.0

const STAGE_COLORS = [
	[Color(0.95, 0.25, 0.35), 3, 300], # 赤 (HP 3, 300点)
	[Color(0.98, 0.55, 0.20), 2, 200], # 橙 (HP 2, 200点)
	[Color(0.96, 0.85, 0.22), 2, 200], # 黄 (HP 2, 200点)
	[Color(0.30, 0.85, 0.45), 1, 100], # 緑 (HP 1, 100点)
	[Color(0.25, 0.70, 0.98), 1, 100], # 青 (HP 1, 100点)
	[Color(0.70, 0.40, 0.95), 1, 100]  # 紫 (HP 1, 100点)
]

func _ready() -> void:
	# Androidの戻るボタン（Backキー）が押された際の中断イベントを安全に処理
	get_tree().set_auto_accept_quit(false)
	
	ball.attach_to_paddle(paddle)
	ui.restart_pressed.connect(_on_ui_restart)
	ui.launch_pressed.connect(_on_ui_launch)
	
	start_new_game()

func _notification(what: int) -> void:
	# Androidのシステムバックボタン（Backキー）通知
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if ui.is_game_over or ui.is_stage_cleared:
			_on_ui_restart()
		else:
			# ポーズまたは確認
			pass

func start_new_game() -> void:
	score = 0
	lives = 3
	current_stage = 1
	ui.update_score(score, high_score)
	ui.update_stage(current_stage)
	ui.update_lives(lives)
	load_stage(current_stage)

func load_stage(stage_num: int) -> void:
	# 既存ブロックのクリア
	for child in blocks_container.get_children():
		child.queue_free()
	
	remaining_blocks = 0
	
	var cols = 8
	var rows = clamp(4 + stage_num, 5, 8)
	var block_w = 72.0
	var block_h = 22.0
	var gap_x = 8.0
	var gap_y = 8.0
	
	var total_w = cols * block_w + (cols - 1) * gap_x
	var start_x = (720.0 - total_w) * 0.5 + block_w * 0.5
	var start_y = 85.0 + block_h * 0.5
	
	for r in range(rows):
		var color_info = STAGE_COLORS[r % STAGE_COLORS.size()]
		var hp = int(color_info[1])
		var pts = int(color_info[2])
		var col = color_info[0] as Color
		
		# ステージが進むと耐久力強化
		if stage_num > 1 and r < 2:
			hp += 1
		
		for c in range(cols):
			# ステージによる形状パターン（チェッカー・ダイヤ等のバリエーション）
			if stage_num % 2 == 0 and (r + c) % 4 == 0:
				continue # 隙間を開けてデザイン変化
			
			var block = block_scene.instantiate() as Block
			block.position = Vector2(start_x + c * (block_w + gap_x), start_y + r * (block_h + gap_y))
			block.setup(hp, pts, col)
			block.block_destroyed.connect(_on_block_destroyed)
			blocks_container.add_child(block)
			remaining_blocks += 1
	
	paddle.global_position = Vector2(360.0, 640.0)
	ball.recenter()
	ui.set_launch_guide_visible(true)
	ui.update_stage(stage_num)

func _physics_process(delta: float) -> void:
	# カメラシェイク減衰
	if shake_amount > 0.0:
		shake_amount = max(0.0, shake_amount - delta * 20.0)
		camera.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	else:
		camera.offset = Vector2.ZERO
	
	# ガイドの表示切替
	ui.set_launch_guide_visible(not ball.is_active and not ui.message_overlay.visible)
	
	# ボール落下判定 (ミス)
	if ball.is_active and ball.global_position.y > 720.0:
		_on_ball_missed()

func _on_block_destroyed(pts: int, _pos: Vector2) -> void:
	score += pts
	if score > high_score:
		high_score = score
	ui.update_score(score, high_score)
	
	remaining_blocks -= 1
	if remaining_blocks <= 0:
		_on_stage_cleared()

func _on_ball_missed() -> void:
	lives -= 1
	ui.update_lives(lives)
	SoundManager.play_miss()
	apply_camera_shake(12.0)
	
	paddle.global_position = Vector2(360.0, 640.0)
	ball.recenter()
	
	if lives <= 0:
		SoundManager.play_game_over()
		ball.is_active = false
		ui.show_game_over(score)

func _on_stage_cleared() -> void:
	ball.is_active = false
	var bonus = 1000 * current_stage
	score += bonus
	if score > high_score:
		high_score = score
	ui.update_score(score, high_score)
	SoundManager.play_win()
	ui.show_stage_clear(current_stage, bonus)

func _on_ui_restart() -> void:
	if ui.is_stage_cleared:
		current_stage += 1
		load_stage(current_stage)
	else:
		start_new_game()

func _on_ui_launch() -> void:
	if not ball.is_active:
		ball.launch()

func apply_camera_shake(intensity: float) -> void:
	shake_amount = intensity
