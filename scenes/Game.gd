extends Node2D
class_name GameManager

@export var block_scene: PackedScene = preload("res://scenes/Block.tscn")
@export var item_scene: PackedScene = preload("res://scenes/Item.tscn")
@export var ball_scene: PackedScene = preload("res://scenes/Ball.tscn")
@export var shield_scene: PackedScene = preload("res://scenes/BottomShield.tscn")

@onready var paddle: Paddle = $Paddle
@onready var initial_ball: Ball = $Ball
@onready var blocks_container: Node2D = $Blocks
@onready var items_container: Node2D = $Items
@onready var balls_container: Node2D = $Balls
@onready var ui: GameUI = $UI
@onready var camera: Camera2D = $Camera2D

var score: int = 0
var high_score: int = 0
var lives: int = 3
var current_stage: int = 1
var remaining_blocks: int = 0

var active_balls: Array[Ball] = []
var active_shield: BottomShield = null

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
	
	active_balls.append(initial_ball)
	initial_ball.attach_to_paddle(paddle)
	ui.restart_pressed.connect(_on_ui_restart)
	ui.launch_pressed.connect(_on_ui_launch)
	
	start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if ui.is_game_over or ui.is_stage_cleared:
			_on_ui_restart()

func start_new_game() -> void:
	score = 0
	lives = 3
	current_stage = 1
	ui.update_score(score, high_score)
	ui.update_stage(current_stage)
	ui.update_lives(lives)
	load_stage(current_stage)

func load_stage(stage_num: int) -> void:
	# 既存ブロック・アイテム・ボール・シールドのクリア
	for child in blocks_container.get_children():
		child.queue_free()
	_clear_items()
	_clear_shield()
	_reset_to_single_ball()
	paddle.reset_powerups()
	
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
			# ステージによる形状パターン
			if stage_num % 2 == 0 and (r + c) % 4 == 0:
				continue
			
			var block = block_scene.instantiate() as Block
			block.position = Vector2(start_x + c * (block_w + gap_x), start_y + r * (block_h + gap_y))
			block.setup(hp, pts, col)
			block.block_destroyed.connect(_on_block_destroyed)
			blocks_container.add_child(block)
			remaining_blocks += 1
	
	paddle.global_position = Vector2(360.0, 640.0)
	if active_balls.size() > 0:
		active_balls[0].recenter()
	
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
	var has_ready_ball = false
	for b in active_balls:
		if is_instance_valid(b) and not b.is_active:
			has_ready_ball = true
			break
	ui.set_launch_guide_visible(has_ready_ball and not ui.message_overlay.visible)
	
	# ボール落下判定 (ミス)
	var balls_to_remove: Array[Ball] = []
	for b in active_balls:
		if is_instance_valid(b) and b.is_active and b.global_position.y > 725.0:
			balls_to_remove.append(b)
	
	for b in balls_to_remove:
		active_balls.erase(b)
		if b != initial_ball:
			b.queue_free()
	
	if active_balls.is_empty():
		_on_ball_missed()

func _on_block_destroyed(pts: int, block_pos: Vector2) -> void:
	score += pts
	if score > high_score:
		high_score = score
	ui.update_score(score, high_score)
	
	# アイテムドロップ抽選 (約 32% の確率)
	_try_drop_item(block_pos)
	
	remaining_blocks -= 1
	if remaining_blocks <= 0:
		_on_stage_cleared()

func _try_drop_item(pos: Vector2) -> void:
	if randf() > 0.32:
		return
	
	# 全12種類の重み付き抽選
	var roll = randf()
	var item_type = DropItem.Type.WIDE
	if roll < 0.14:
		item_type = DropItem.Type.WIDE
	elif roll < 0.26:
		item_type = DropItem.Type.MULTI
	elif roll < 0.38:
		item_type = DropItem.Type.LASER
	elif roll < 0.48:
		item_type = DropItem.Type.FIRE
	elif roll < 0.58:
		item_type = DropItem.Type.SLOW
	elif roll < 0.64:
		item_type = DropItem.Type.LIFE
	elif roll < 0.74:
		item_type = DropItem.Type.SHIELD
	elif roll < 0.84:
		item_type = DropItem.Type.BOMB
	elif roll < 0.90:
		item_type = DropItem.Type.CATCH
	elif roll < 0.94:
		item_type = DropItem.Type.MEGA
	elif roll < 0.98:
		item_type = DropItem.Type.MISSILE
	else:
		item_type = DropItem.Type.STAR
	
	var item = item_scene.instantiate() as DropItem
	item.global_position = pos
	item.setup(item_type)
	item.item_collected.connect(_on_item_collected)
	items_container.call_deferred("add_child", item)

func _on_item_collected(item_type: DropItem.Type) -> void:
	score += 200
	
	match item_type:
		DropItem.Type.WIDE:
			paddle.expand_paddle(15.0)
			ui.show_powerup_banner("WIDE PADDLE!", Color(0.25, 0.95, 0.55))
		
		DropItem.Type.MULTI:
			_spawn_multi_balls(2)
			ui.show_powerup_banner("MULTI-BALL!", Color(0.85, 0.35, 1.0))
		
		DropItem.Type.LASER:
			paddle.activate_laser(8.0)
			ui.show_powerup_banner("LASER CANNON!", Color(1.0, 0.3, 0.25))
		
		DropItem.Type.FIRE:
			for b in active_balls:
				if is_instance_valid(b):
					b.activate_fire_ball(6.0)
			ui.show_powerup_banner("FIRE BALL!", Color(1.0, 0.7, 0.1))
		
		DropItem.Type.SLOW:
			for b in active_balls:
				if is_instance_valid(b):
					b.slow_down()
			ui.show_powerup_banner("SLOW DOWN!", Color(0.2, 0.85, 1.0))
		
		DropItem.Type.LIFE:
			lives = min(lives + 1, 5)
			ui.update_lives(lives)
			ui.show_powerup_banner("EXTRA LIFE +1!", Color(1.0, 0.35, 0.65))
		
		DropItem.Type.SHIELD:
			_deploy_shield()
			ui.show_powerup_banner("BOTTOM SHIELD!", Color(0.2, 0.75, 1.0))
		
		DropItem.Type.BOMB:
			for b in active_balls:
				if is_instance_valid(b):
					b.activate_bomb_ball(10.0)
			ui.show_powerup_banner("BOMB BALL!", Color(1.0, 0.55, 0.1))
		
		DropItem.Type.CATCH:
			paddle.activate_catch(12.0)
			ui.show_powerup_banner("CATCH PADDLE!", Color(0.4, 0.95, 0.3))
		
		DropItem.Type.MEGA:
			_spawn_multi_balls(4)
			ui.show_powerup_banner("MEGA 5-BALL!!", Color(1.0, 0.3, 0.8))
		
		DropItem.Type.MISSILE:
			paddle.launch_missiles(4)
			ui.show_powerup_banner("HOMING MISSILES!", Color(1.0, 0.25, 0.2))
		
		DropItem.Type.STAR:
			score += 800 # 合計+1000点
			SoundManager.play_star()
			_spawn_star_shower()
			ui.show_powerup_banner("BONUS +1000!", Color(1.0, 0.9, 0.2))
	
	if score > high_score:
		high_score = score
	ui.update_score(score, high_score)

func _deploy_shield() -> void:
	_clear_shield()
	active_shield = shield_scene.instantiate() as BottomShield
	active_shield.global_position = Vector2(360.0, 690.0)
	call_deferred("add_child", active_shield)

func _clear_shield() -> void:
	if is_instance_valid(active_shield):
		active_shield.queue_free()
		active_shield = null

func _spawn_multi_balls(extra_count: int = 2) -> void:
	var current_balls = active_balls.duplicate()
	for base_ball in current_balls:
		if not is_instance_valid(base_ball) or not base_ball.is_active:
			continue
		
		var angles: Array[float] = []
		if extra_count == 2:
			angles = [-30.0, 30.0]
		elif extra_count >= 4:
			angles = [-45.0, -22.0, 22.0, 45.0]
		else:
			angles = [-25.0, 25.0]
		
		for angle_deg in angles:
			var new_ball = ball_scene.instantiate() as Ball
			new_ball.global_position = base_ball.global_position
			balls_container.call_deferred("add_child", new_ball)
			
			var rotated_velocity = base_ball.velocity.rotated(deg_to_rad(angle_deg))
			if abs(rotated_velocity.y) < base_ball.speed * 0.25:
				rotated_velocity.y = -base_ball.speed * 0.4
			new_ball.velocity = rotated_velocity.normalized() * base_ball.speed
			new_ball.speed = base_ball.speed
			new_ball.is_active = true
			if base_ball.is_fire_ball:
				new_ball.activate_fire_ball(base_ball.fire_timer)
			if base_ball.is_bomb_ball:
				new_ball.activate_bomb_ball(base_ball.bomb_timer)
			
			active_balls.append(new_ball)

func _spawn_star_shower() -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 24
	particles.lifetime = 0.6
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(1.0, 0.9, 0.2)
	particles.global_position = Vector2(360.0, 360.0)
	call_deferred("add_child", particles)
	get_tree().create_timer(0.7).timeout.connect(particles.queue_free)


func _clear_items() -> void:
	for item in items_container.get_children():
		item.queue_free()

func _reset_to_single_ball() -> void:
	for child in balls_container.get_children():
		child.queue_free()
	
	active_balls.clear()
	active_balls.append(initial_ball)
	initial_ball.is_active = false
	initial_ball.is_fire_ball = false
	initial_ball.fire_timer = 0.0
	initial_ball.is_bomb_ball = false
	initial_ball.bomb_timer = 0.0

func _on_ball_missed() -> void:
	lives -= 1
	ui.update_lives(lives)
	SoundManager.play_miss()
	apply_camera_shake(12.0)
	
	_clear_items()
	_clear_shield()
	_reset_to_single_ball()
	paddle.reset_powerups()
	paddle.global_position = Vector2(360.0, 640.0)
	initial_ball.recenter()
	
	if lives <= 0:
		SoundManager.play_game_over()
		initial_ball.is_active = false
		ui.show_game_over(score)

func _on_stage_cleared() -> void:
	_clear_items()
	_clear_shield()
	for b in active_balls:
		if is_instance_valid(b):
			b.is_active = false
	
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
	for b in active_balls:
		if is_instance_valid(b) and not b.is_active:
			b.launch()

func apply_camera_shake(intensity: float) -> void:
	shake_amount = intensity
