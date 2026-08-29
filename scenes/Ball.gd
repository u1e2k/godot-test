extends CharacterBody2D
class_name Ball

@export var start_speed: float = 410.0
@export var max_speed: float = 680.0
@export var ball_radius: float = 8.5

var speed: float = 410.0
var is_active: bool = false
var paddle: Paddle = null

# トレイル（残像）用
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS: int = 12

# パワーアップ状態
var is_fire_ball: bool = false
var fire_timer: float = 0.0
var is_bomb_ball: bool = false
var bomb_timer: float = 0.0

# キャッチ用オフセット
var catch_offset_x: float = 0.0

func _ready() -> void:
	add_to_group("ball")
	speed = start_speed
	queue_redraw()

func attach_to_paddle(target_paddle: Paddle) -> void:
	paddle = target_paddle
	catch_offset_x = 0.0
	recenter()

func recenter() -> void:
	is_active = false
	speed = start_speed
	velocity = Vector2.ZERO
	trail_points.clear()
	is_fire_ball = false
	fire_timer = 0.0
	is_bomb_ball = false
	bomb_timer = 0.0
	catch_offset_x = 0.0
	if paddle:
		global_position = paddle.global_position + Vector2(0, -22)
	queue_redraw()

func catch_by_paddle(offset_x: float) -> void:
	is_active = false
	catch_offset_x = offset_x
	velocity = Vector2.ZERO
	SoundManager.play_catch()
	queue_redraw()

func activate_fire_ball(duration: float = 6.0) -> void:
	is_fire_ball = true
	fire_timer = duration
	queue_redraw()

func activate_bomb_ball(duration: float = 10.0) -> void:
	is_bomb_ball = true
	bomb_timer = duration
	queue_redraw()

func slow_down() -> void:
	speed = max(start_speed * 0.85, 360.0)
	if velocity != Vector2.ZERO:
		velocity = velocity.normalized() * speed

func launch() -> void:
	if is_active:
		return
	is_active = true
	# パドルの移動速度とキャッチ位置に応じた角度
	var paddle_vx = paddle.velocity.x if paddle else 0.0
	var angle_offset = clamp((paddle_vx / 800.0) + (catch_offset_x * 0.005), -0.4, 0.4)
	if abs(angle_offset) < 0.05:
		angle_offset = randf_range(-0.35, 0.35)
	
	# 上方向（-Y）を中心としたベクトル
	var dir = Vector2(sin(angle_offset), -cos(angle_offset)).normalized()
	velocity = dir * speed
	SoundManager.play_launch()

func _physics_process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
		if fire_timer <= 0.0:
			is_fire_ball = false
			queue_redraw()
	
	if bomb_timer > 0.0:
		bomb_timer -= delta
		if bomb_timer <= 0.0:
			is_bomb_ball = false
			queue_redraw()
	
	if not is_active:
		if paddle:
			global_position = paddle.global_position + Vector2(catch_offset_x, -22)
		# Bボタンまたは画面タップなどで発射
		if Input.is_action_just_pressed("launch_ball"):
			launch()
		return
	
	# トレイル更新
	trail_points.push_front(global_position)
	if trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_back()
	
	# 移動と衝突判定
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("paddle"):
			var paddle_node = collider as Paddle
			
			# パドルがキャッチモードの場合
			if paddle_node and paddle_node.is_catch_mode:
				var offset_from_paddle = global_position.x - collider.global_position.x
				catch_by_paddle(offset_from_paddle)
				return
			
			# 通常反射
			var half_w = (paddle_node.paddle_width * 0.5) if paddle_node else 52.5
			var offset_x = (global_position.x - collider.global_position.x) / half_w
			offset_x = clamp(offset_x, -0.92, 0.92)
			
			# 最大 ±60 度の角度で上方向に反射
			var bounce_angle = offset_x * (PI / 3.0) # -60 deg ~ +60 deg
			var new_dir = Vector2(sin(bounce_angle), -cos(bounce_angle)).normalized()
			
			velocity = new_dir * speed
			SoundManager.play_paddle(offset_x)
			
		elif collider and collider.is_in_group("shield"):
			# ボトムシールド衝突
			velocity = velocity.bounce(collision.get_normal())
			if collider.has_method("hit_by_ball"):
				collider.hit_by_ball()
			
		elif collider and collider.is_in_group("blocks"):
			# ブロック衝突
			if is_bomb_ball:
				_explode_around(global_position)
				velocity = velocity.bounce(collision.get_normal())
			elif is_fire_ball:
				# ファイヤーボール: 貫通してダメージを与える（跳ね返らない）
				if collider.has_method("take_damage"):
					collider.take_damage(2)
			else:
				velocity = velocity.bounce(collision.get_normal())
				if collider.has_method("take_damage"):
					collider.take_damage(1)
				
				# 速度微増（マイルドな+3.0）
				speed = min(speed + 3.0, max_speed)
				velocity = velocity.normalized() * speed
			
		else:
			# 壁などの衝突
			velocity = velocity.bounce(collision.get_normal())
			SoundManager.play_wall()
			
		# 速度が真横に近くなりすぎた場合の補正（スタック防止）
		if abs(velocity.y) < speed * 0.2:
			var sign_y = -1.0 if velocity.y <= 0.0 else 1.0
			velocity.y = sign_y * speed * 0.3
			velocity = velocity.normalized() * speed

	queue_redraw()

func _explode_around(center_pos: Vector2) -> void:
	SoundManager.play_explosion()
	var blocks = get_tree().get_nodes_in_group("blocks")
	var explode_radius = 85.0
	for b in blocks:
		if is_instance_valid(b):
			var dist = center_pos.distance_to(b.global_position)
			if dist <= explode_radius:
				if b.has_method("take_damage"):
					b.take_damage(2)
	
	# 爆発パーティクル
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 28
	particles.lifetime = 0.45
	particles.spread = 180.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = Color(1.0, 0.6, 0.1)
	particles.global_position = center_pos
	if get_parent():
		get_parent().add_child(particles)
		get_tree().create_timer(0.5).timeout.connect(particles.queue_free)

func _draw() -> void:
	var trail_color = Color(0.2, 0.8, 1.0)
	var glow_color = Color(0.2, 0.8, 1.0, 0.3)
	var main_color = Color(0.95, 0.98, 1.0, 1.0)
	
	if is_bomb_ball:
		trail_color = Color(1.0, 0.5, 0.1)
		glow_color = Color(1.0, 0.4, 0.1, 0.5)
		main_color = Color(1.0, 0.65, 0.2, 1.0)
	elif is_fire_ball:
		trail_color = Color(1.0, 0.3, 0.1)
		glow_color = Color(1.0, 0.2, 0.1, 0.5)
		main_color = Color(1.0, 0.85, 0.3, 1.0)
	
	# トレイル（残光）の描画
	if is_active and trail_points.size() > 1:
		for i in range(1, trail_points.size()):
			var p_from = to_local(trail_points[i - 1])
			var p_to = to_local(trail_points[i])
			var alpha = (1.0 - float(i) / float(MAX_TRAIL_POINTS)) * 0.5
			var width = ball_radius * (1.0 - float(i) / float(MAX_TRAIL_POINTS) * 0.6)
			draw_line(p_from, p_to, Color(trail_color.r, trail_color.g, trail_color.b, alpha), width, true)
	
	# ボール外側グロー
	draw_circle(Vector2.ZERO, ball_radius + (6.0 if (is_fire_ball or is_bomb_ball) else 4.0), glow_color)
	# ボール本体
	draw_circle(Vector2.ZERO, ball_radius, main_color)
	# ボールハイライト
	draw_circle(Vector2(-ball_radius * 0.25, -ball_radius * 0.25), ball_radius * 0.35, Color(1.0, 1.0, 1.0, 0.9))


