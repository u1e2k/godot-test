extends CharacterBody2D
class_name Ball

@export var start_speed: float = 480.0
@export var max_speed: float = 850.0
@export var ball_radius: float = 8.5

var speed: float = 480.0
var is_active: bool = false
var paddle: Paddle = null

# トレイル（残像）用
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS: int = 12

func _ready() -> void:
	add_to_group("ball")
	speed = start_speed
	queue_redraw()

func attach_to_paddle(target_paddle: Paddle) -> void:
	paddle = target_paddle
	recenter()

func recenter() -> void:
	is_active = false
	speed = start_speed
	velocity = Vector2.ZERO
	trail_points.clear()
	if paddle:
		global_position = paddle.global_position + Vector2(0, -22)
	queue_redraw()

func launch() -> void:
	if is_active:
		return
	is_active = true
	# パドルの移動速度に応じて発射初期角度にわずかな傾きをつける
	var paddle_vx = paddle.velocity.x if paddle else 0.0
	var angle_offset = clamp(paddle_vx / 1000.0, -0.4, 0.4)
	if abs(angle_offset) < 0.05:
		angle_offset = randf_range(-0.35, 0.35)
	
	# 上方向（-Y）を中心としたベクトル
	var dir = Vector2(sin(angle_offset), -cos(angle_offset)).normalized()
	velocity = dir * speed
	SoundManager.play_launch()

func _physics_process(delta: float) -> void:
	if not is_active:
		if paddle:
			global_position = paddle.global_position + Vector2(0, -22)
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
			# パドル衝突: 当たった位置に応じて反射角を精密計算
			var paddle_node = collider as Paddle
			var half_w = (paddle_node.paddle_width * 0.5) if paddle_node else 52.5
			var offset_x = (global_position.x - collider.global_position.x) / half_w
			offset_x = clamp(offset_x, -0.92, 0.92)
			
			# 最大 ±60 度の角度で上方向に反射
			var bounce_angle = offset_x * (PI / 3.0) # -60 deg ~ +60 deg
			var new_dir = Vector2(sin(bounce_angle), -cos(bounce_angle)).normalized()
			
			velocity = new_dir * speed
			SoundManager.play_paddle(offset_x)
			
		elif collider and collider.is_in_group("blocks"):
			# ブロック衝突
			velocity = velocity.bounce(collision.get_normal())
			if collider.has_method("take_damage"):
				collider.take_damage(1)
			
			# 速度微増
			speed = min(speed + 12.0, max_speed)
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

func _draw() -> void:
	# トレイル（残光）の描画
	if is_active and trail_points.size() > 1:
		for i in range(1, trail_points.size()):
			var p_from = to_local(trail_points[i - 1])
			var p_to = to_local(trail_points[i])
			var alpha = (1.0 - float(i) / float(MAX_TRAIL_POINTS)) * 0.4
			var width = ball_radius * (1.0 - float(i) / float(MAX_TRAIL_POINTS) * 0.6)
			draw_line(p_from, p_to, Color(0.2, 0.8, 1.0, alpha), width, true)
	
	# ボール外側グロー
	draw_circle(Vector2.ZERO, ball_radius + 4.0, Color(0.2, 0.8, 1.0, 0.3))
	# ボール本体
	draw_circle(Vector2.ZERO, ball_radius, Color(0.95, 0.98, 1.0, 1.0))
	# ボールハイライト
	draw_circle(Vector2(-ball_radius * 0.25, -ball_radius * 0.25), ball_radius * 0.35, Color(1.0, 1.0, 1.0, 0.9))
