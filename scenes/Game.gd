extends Node2D
class_name GameManager

enum State {
	TITLE,
	PLAYING,
	PAUSED,
	GAME_OVER,
	STAGE_CLEAR
}

@export var block_scene: PackedScene = preload("res://scenes/Block.tscn")
@export var item_scene: PackedScene = preload("res://scenes/Item.tscn")
@export var ball_scene: PackedScene = preload("res://scenes/Ball.tscn")
@export var shield_scene: PackedScene = preload("res://scenes/BottomShield.tscn")
@export var target_scene: PackedScene = preload("res://scenes/MovingTarget.tscn")

@onready var paddle: Paddle = $Paddle
@onready var initial_ball: Ball = $Ball
@onready var blocks_container: Node2D = $Blocks
@onready var targets_container: Node2D = $Targets
@onready var items_container: Node2D = $Items
@onready var balls_container: Node2D = $Balls
@onready var ui: GameUI = $UI
@onready var camera: Camera2D = $Camera2D

var current_state: State = State.TITLE

var score: int = 0
var high_score: int = 0
var max_level_reached: int = 1
var lives: int = 3
var current_stage: int = 1
var remaining_blocks: int = 0

# レベルシステム
var player_level: int = 1
var current_xp: int = 0
var next_level_xp: int = 150
var score_multiplier: float = 1.0
var base_item_drop_rate: float = 0.32

var active_balls: Array[Ball] = []
var active_shield: BottomShield = null

# カメラシェイク用
var shake_amount: float = 0.0

const COLOR_TIERS = [
	Color(0.25, 0.70, 0.98), # HP 1: シアンブルー (100 pts)
	Color(0.30, 0.85, 0.45), # HP 2: エメラルドグリーン (200 pts)
	Color(0.96, 0.85, 0.22), # HP 3: レモンイエロー (300 pts)
	Color(0.98, 0.55, 0.20), # HP 4: オレンジ (400 pts)
	Color(0.95, 0.25, 0.35)  # HP 5+: ルビーレッド (500 pts)
]

# --- 10種類のステージレイアウトパターン (8列 x 8行) ---
const STAGE_PATTERNS = [
	# 1. CLASSIC STRIPES (基本ストライプ)
	[
		[3, 3, 3, 3, 3, 3, 3, 3],
		[2, 2, 2, 2, 2, 2, 2, 2],
		[2, 2, 2, 2, 2, 2, 2, 2],
		[1, 1, 1, 1, 1, 1, 1, 1],
		[1, 1, 1, 1, 1, 1, 1, 1],
	],
	# 2. PYRAMID (ピラミッド)
	[
		[0, 0, 0, 3, 3, 0, 0, 0],
		[0, 0, 2, 2, 2, 2, 0, 0],
		[0, 2, 2, 1, 1, 2, 2, 0],
		[1, 1, 1, 1, 1, 1, 1, 1],
		[1, 0, 1, 0, 0, 1, 0, 1],
	],
	# 3. DIAMOND VAULT (ダイヤモンド金庫)
	[
		[0, 0, 2, 3, 3, 2, 0, 0],
		[0, 2, 1, 4, 4, 1, 2, 0],
		[2, 1, 0, 4, 4, 0, 1, 2],
		[0, 2, 1, 4, 4, 1, 2, 0],
		[0, 0, 2, 3, 3, 2, 0, 0],
	],
	# 4. SPACE INVADER (インベーダー)
	[
		[0, 0, 2, 0, 0, 2, 0, 0],
		[0, 0, 0, 3, 3, 0, 0, 0],
		[0, 2, 2, 2, 2, 2, 2, 0],
		[2, 2, 1, 2, 2, 1, 2, 2],
		[2, 2, 2, 2, 2, 2, 2, 2],
		[2, 0, 2, 0, 0, 2, 0, 2],
		[0, 1, 0, 1, 1, 0, 1, 0],
	],
	# 5. TWIN TOWERS (ツインタワー)
	[
		[3, 3, 0, 0, 0, 0, 3, 3],
		[3, 3, 0, 0, 0, 0, 3, 3],
		[2, 2, 0, 4, 4, 0, 2, 2],
		[2, 2, 0, 4, 4, 0, 2, 2],
		[1, 1, 1, 1, 1, 1, 1, 1],
		[1, 1, 0, 0, 0, 0, 1, 1],
	],
	# 6. CASTLE FORTRESS (キャッスル要塞)
	[
		[4, 0, 4, 0, 0, 4, 0, 4],
		[4, 3, 3, 3, 3, 3, 3, 4],
		[4, 2, 0, 0, 0, 0, 2, 4],
		[4, 2, 0, 5, 5, 0, 2, 4],
		[4, 1, 1, 1, 1, 1, 1, 4],
	],
	# 7. CHECKERBOARD CHAOS (市松模様)
	[
		[2, 0, 2, 0, 0, 2, 0, 2],
		[0, 3, 0, 3, 3, 0, 3, 0],
		[2, 0, 2, 0, 0, 2, 0, 2],
		[0, 3, 0, 3, 3, 0, 3, 0],
		[1, 1, 1, 1, 1, 1, 1, 1],
	],
	# 8. NEON HEART (ハート)
	[
		[0, 3, 3, 0, 0, 3, 3, 0],
		[3, 2, 2, 3, 3, 2, 2, 3],
		[3, 2, 1, 1, 1, 1, 2, 3],
		[0, 3, 2, 1, 1, 2, 3, 0],
		[0, 0, 3, 2, 2, 3, 0, 0],
		[0, 0, 0, 3, 3, 0, 0, 0],
	],
	# 9. ZIG-ZAG MAZE (ジグザグ迷路)
	[
		[3, 3, 3, 3, 3, 3, 3, 0],
		[0, 0, 0, 0, 0, 0, 0, 2],
		[0, 2, 2, 2, 2, 2, 2, 2],
		[2, 0, 0, 0, 0, 0, 0, 0],
		[2, 2, 2, 2, 2, 2, 2, 0],
		[0, 0, 0, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 1, 1, 1],
	],
	# 10. DRONE FORTRESS (ドローン大要塞)
	[
		[4, 4, 4, 4, 4, 4, 4, 4],
		[3, 0, 3, 0, 0, 3, 0, 3],
		[2, 2, 2, 5, 5, 2, 2, 2],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[2, 2, 2, 2, 2, 2, 2, 2],
		[1, 1, 1, 1, 1, 1, 1, 1],
	]
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().set_auto_accept_quit(false)

	
	active_balls.append(initial_ball)
	initial_ball.attach_to_paddle(paddle)
	
	ui.start_game_pressed.connect(_on_start_game)
	ui.pause_pressed.connect(_toggle_pause)
	ui.resume_pressed.connect(_resume_game)
	ui.title_pressed.connect(_return_to_title)
	ui.restart_pressed.connect(_on_ui_restart)
	ui.launch_pressed.connect(_on_ui_launch)
	
	# 初回はタイトル画面を表示
	_return_to_title()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current_state == State.PLAYING:
			_toggle_pause()
		elif current_state == State.PAUSED:
			_resume_game()
		elif current_state == State.GAME_OVER or current_state == State.STAGE_CLEAR:
			_on_ui_restart()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if current_state == State.PLAYING:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif current_state == State.PAUSED:
			_resume_game()
			get_viewport().set_input_as_handled()

func _on_start_game() -> void:
	ui.hide_title_screen()
	start_new_game()

func start_new_game() -> void:
	get_tree().paused = false
	current_state = State.PLAYING
	score = 0
	lives = 3
	current_stage = 1
	player_level = 1
	current_xp = 0
	next_level_xp = 150
	score_multiplier = 1.0
	base_item_drop_rate = 0.32
	
	ui.update_score(score, high_score)
	ui.update_level(player_level, current_xp, next_level_xp)
	ui.update_stage(current_stage)
	ui.update_lives(lives)
	load_stage(current_stage)

func load_stage(stage_num: int) -> void:
	get_tree().paused = false
	current_state = State.PLAYING
	
	# 既存オブジェクトのクリア
	for child in blocks_container.get_children():
		child.queue_free()
	for child in targets_container.get_children():
		child.queue_free()
	_clear_items()
	_clear_shield()
	_reset_to_single_ball()
	paddle.reset_powerups()
	
	remaining_blocks = 0
	
	# ステージパターンの選択（10パターン循環）
	var pattern_idx = (stage_num - 1) % STAGE_PATTERNS.size()
	var pattern = STAGE_PATTERNS[pattern_idx]
	var loop_count = int((stage_num - 1) / STAGE_PATTERNS.size())
	
	var rows = pattern.size()
	var cols = 8
	var block_w = 72.0
	var block_h = 22.0
	var gap_x = 8.0
	var gap_y = 8.0
	
	var total_w = cols * block_w + (cols - 1) * gap_x
	var start_x = (720.0 - total_w) * 0.5 + block_w * 0.5
	var start_y = 80.0 + block_h * 0.5
	
	for r in range(rows):
		var row_data = pattern[r]
		for c in range(row_data.size()):
			var raw_hp = row_data[c]
			if raw_hp <= 0:
				continue
			
			# 周回ボーナスでHP微増
			var hp = raw_hp + loop_count
			var pts = hp * 100
			var col_idx = clamp(hp - 1, 0, COLOR_TIERS.size() - 1)
			var col = COLOR_TIERS[col_idx]
			
			var block = block_scene.instantiate() as Block
			block.position = Vector2(start_x + c * (block_w + gap_x), start_y + r * (block_h + gap_y))
			block.setup(hp, pts, col)
			block.block_destroyed.connect(_on_block_destroyed)
			blocks_container.add_child(block)
			remaining_blocks += 1
	
	# 動く的（UFOドローン）のスポーン（ステージ 2, 4, 6, 8, 10 等）
	_spawn_stage_targets(stage_num)
	
	paddle.global_position = Vector2(360.0, 640.0)
	if active_balls.size() > 0:
		active_balls[0].recenter()
	
	ui.set_launch_guide_visible(true)
	ui.update_stage(stage_num)

func _spawn_stage_targets(stage_num: int) -> void:
	var target_count = 0
	if stage_num >= 10:
		target_count = 2
	elif stage_num % 2 == 0 or stage_num == 3 or stage_num == 7:
		target_count = 1
	
	for i in range(target_count):
		var drone = target_scene.instantiate() as MovingTarget
		var y_pos = 320.0 + i * 45.0
		drone.position = Vector2(randf_range(120.0, 600.0), y_pos)
		drone.setup(2 + int(stage_num / 4), 130.0 + stage_num * 5.0, 1.0 if i % 2 == 0 else -1.0)
		drone.target_destroyed.connect(_on_target_destroyed)
		targets_container.call_deferred("add_child", drone)

func _toggle_pause() -> void:
	if current_state == State.PLAYING:
		get_tree().paused = true
		current_state = State.PAUSED
		ui.show_pause_menu()

func _resume_game() -> void:
	if current_state == State.PAUSED:
		get_tree().paused = false
		current_state = State.PLAYING
		ui.hide_pause_menu()

func _return_to_title() -> void:
	get_tree().paused = false
	current_state = State.TITLE
	_clear_all_game_objects()
	ui.show_title_screen(high_score, max_level_reached)

func _clear_all_game_objects() -> void:
	for child in blocks_container.get_children():
		child.queue_free()
	for child in targets_container.get_children():
		child.queue_free()
	_clear_items()
	_clear_shield()
	_reset_to_single_ball()
	paddle.reset_powerups()
	paddle.global_position = Vector2(360.0, 640.0)
	initial_ball.recenter()

func _physics_process(delta: float) -> void:
	if current_state == State.PAUSED or current_state == State.TITLE:
		return
	
	if shake_amount > 0.0:
		shake_amount = max(0.0, shake_amount - delta * 20.0)
		camera.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	else:
		camera.offset = Vector2.ZERO
	
	var has_ready_ball = false
	for b in active_balls:
		if is_instance_valid(b) and not b.is_active:
			has_ready_ball = true
			break
	ui.set_launch_guide_visible(has_ready_ball and not ui.message_overlay.visible and not ui.pause_overlay.visible and not ui.title_screen.visible)
	
	var balls_to_remove: Array[Ball] = []
	for b in active_balls:
		if is_instance_valid(b) and b.is_active and b.global_position.y > 725.0:
			balls_to_remove.append(b)
	
	for b in balls_to_remove:
		active_balls.erase(b)
		if b != initial_ball:
			b.queue_free()
	
	if active_balls.is_empty() and current_state == State.PLAYING:
		_on_ball_missed()

func _on_block_destroyed(pts: int, block_pos: Vector2) -> void:
	var earned = int(pts * score_multiplier)
	score += earned
	if score > high_score:
		high_score = score
	ui.update_score(score, high_score)
	
	add_xp(25 + int(pts * 0.1))
	_try_drop_item(block_pos, base_item_drop_rate)
	
	remaining_blocks -= 1
	if remaining_blocks <= 0 and current_state == State.PLAYING:
		_on_stage_cleared()

func _on_target_destroyed(pts: int, xp_amount: int, target_pos: Vector2) -> void:
	var earned = int(pts * score_multiplier)
	score += earned
	if score > high_score:
		high_score = score
	ui.update_score(score, high_score)
	
	add_xp(xp_amount)
	apply_camera_shake(8.0)
	_try_drop_item(target_pos, 1.0, true)

func add_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= next_level_xp:
		current_xp -= next_level_xp
		player_level += 1
		if player_level > max_level_reached:
			max_level_reached = player_level
		next_level_xp = int(next_level_xp * 1.45) + 50
		_on_level_up(player_level)
	
	ui.update_level(player_level, current_xp, next_level_xp)

func _on_level_up(lvl: int) -> void:
	SoundManager.play_level_up()
	apply_camera_shake(10.0)
	
	var perk_msg = ""
	match lvl:
		2:
			score_multiplier = 1.2
			paddle.speed = 690.0
			perk_msg = "SCORE x1.2 & SPEED UP!"
		3:
			base_item_drop_rate = 0.38
			perk_msg = "ITEM DROP RATE +6%!"
		4:
			score_multiplier = 1.5
			perk_msg = "SCORE MULTIPLIER x1.5!"
		5:
			lives = min(lives + 1, 5)
			ui.update_lives(lives)
			_deploy_shield()
			perk_msg = "EXTRA LIFE + SHIELD!"
		_:
			score_multiplier += 0.15
			score += 1500
			perk_msg = "SCORE MULTIPLIER x%.1f + 1500 PTS!" % score_multiplier
	
	ui.show_level_up_banner(lvl, perk_msg)

func _try_drop_item(pos: Vector2, drop_chance: float, is_guaranteed_rare: bool = false) -> void:
	if randf() > drop_chance:
		return
	
	var item_type = DropItem.Type.WIDE
	if is_guaranteed_rare:
		var rare_choices = [
			DropItem.Type.MEGA,
			DropItem.Type.MISSILE,
			DropItem.Type.BOMB,
			DropItem.Type.SHIELD,
			DropItem.Type.STAR,
			DropItem.Type.LIFE
		]
		item_type = rare_choices[randi() % rare_choices.size()]
	else:
		var roll = randf()
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
	score += int(200 * score_multiplier)
	add_xp(40)
	
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
			score += int(800 * score_multiplier)
			add_xp(150)
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
		current_state = State.GAME_OVER
		SoundManager.play_game_over()
		initial_ball.is_active = false
		ui.show_game_over(score)

func _on_stage_cleared() -> void:
	current_state = State.STAGE_CLEAR
	_clear_items()
	_clear_shield()
	for b in active_balls:
		if is_instance_valid(b):
			b.is_active = false
	
	var bonus = int(1000 * current_stage * score_multiplier)
	score += bonus
	add_xp(350 + current_stage * 50)
	
	if score > high_score:
		high_score = score
	ui.update_score(score, high_score)
	SoundManager.play_win()
	ui.show_stage_clear(current_stage, bonus)

func _on_ui_restart() -> void:
	if current_state == State.STAGE_CLEAR:
		current_stage += 1
		load_stage(current_stage)
	else:
		start_new_game()

func _on_ui_launch() -> void:
	if current_state != State.PLAYING:
		return
	for b in active_balls:
		if is_instance_valid(b) and not b.is_active:
			b.launch()

func apply_camera_shake(intensity: float) -> void:
	shake_amount = intensity
