extends CharacterBody2D
class_name Paddle

const PADDLE_Y: float = 640.0

@export var speed: float = 650.0
@export var paddle_width: float = 105.0
@export var paddle_height: float = 20.0
@export var min_x: float = 20.0
@export var max_x: float = 700.0

var is_touching: bool = false
var touch_target_x: float = 0.0

@export var laser_scene: PackedScene = preload("res://scenes/Laser.tscn")
@export var missile_scene: PackedScene = preload("res://scenes/Missile.tscn")

const BASE_WIDTH: float = 105.0
const WIDE_WIDTH: float = 165.0

var expand_timer: float = 0.0
var laser_timer: float = 0.0
var shoot_timer: float = 0.0
const SHOOT_INTERVAL: float = 0.32

var is_catch_mode: bool = false
var catch_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("paddle")
	global_position.y = PADDLE_Y
	_update_shape_size()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			is_touching = true
			touch_target_x = event.position.x
		else:
			is_touching = false
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and is_touching):
		touch_target_x = event.position.x

func _physics_process(delta: float) -> void:
	# タイマー更新
	if expand_timer > 0.0:
		expand_timer -= delta
		if expand_timer <= 0.0:
			paddle_width = BASE_WIDTH
			_update_shape_size()
			queue_redraw()
	
	if laser_timer > 0.0:
		laser_timer -= delta
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			_shoot_lasers()
			shoot_timer = SHOOT_INTERVAL
		if laser_timer <= 0.0:
			queue_redraw()
	
	if catch_timer > 0.0:
		catch_timer -= delta
		if catch_timer <= 0.0:
			is_catch_mode = false
			queue_redraw()
	
	var move_dir = Input.get_axis("move_left", "move_right")
	velocity.y = 0.0
	
	if move_dir != 0.0:
		# 物理ボタン / スティック / キーボード入力
		velocity.x = move_dir * speed
	elif is_touching:
		# タッチ / マウス操作によるスムーズ追従
		var diff = touch_target_x - global_position.x
		if abs(diff) > 5.0:
			velocity.x = clamp(diff * 15.0, -speed * 1.2, speed * 1.2)
		else:
			velocity.x = 0.0
	else:
		# 減速停止
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
	
	move_and_slide()
	
	# 画面枠制限 & Y座標の絶対固定（めり込みや衝突による沈み込み・消滅を完全に防ぐ）
	global_position.x = clamp(global_position.x, min_x + paddle_width * 0.5, max_x - paddle_width * 0.5)
	global_position.y = PADDLE_Y

func expand_paddle(duration: float = 15.0) -> void:
	expand_timer = duration
	paddle_width = WIDE_WIDTH
	_update_shape_size()
	queue_redraw()

func activate_laser(duration: float = 8.0) -> void:
	laser_timer = duration
	shoot_timer = 0.05 # すぐに1発目を撃つ
	queue_redraw()

func activate_catch(duration: float = 12.0) -> void:
	is_catch_mode = true
	catch_timer = duration
	queue_redraw()

func launch_missiles(count: int = 4) -> void:
	if not missile_scene or not get_parent():
		return
	
	for i in range(count):
		var missile = missile_scene.instantiate() as Missile
		var offset_ratio = lerp(-0.35, 0.35, float(i) / float(max(1, count - 1)))
		missile.global_position = global_position + Vector2(paddle_width * offset_ratio, -paddle_height * 0.8)
		get_parent().call_deferred("add_child", missile)
		await get_tree().create_timer(0.12).timeout

func reset_powerups() -> void:
	expand_timer = 0.0
	laser_timer = 0.0
	shoot_timer = 0.0
	is_catch_mode = false
	catch_timer = 0.0
	paddle_width = BASE_WIDTH
	_update_shape_size()
	queue_redraw()

func _update_shape_size() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size = Vector2(paddle_width, paddle_height)

func _shoot_lasers() -> void:
	if not laser_scene or not get_parent():
		return
	
	var offset_x = paddle_width * 0.42
	
	# 左レーザー
	var laser_left = laser_scene.instantiate() as Laser
	laser_left.global_position = global_position + Vector2(-offset_x, -paddle_height * 0.6)
	get_parent().call_deferred("add_child", laser_left)
	
	# 右レーザー
	var laser_right = laser_scene.instantiate() as Laser
	laser_right.global_position = global_position + Vector2(offset_x, -paddle_height * 0.6)
	get_parent().call_deferred("add_child", laser_right)
	
	SoundManager.play_laser()


func _draw() -> void:
	var rect = Rect2(-paddle_width * 0.5, -paddle_height * 0.5, paddle_width, paddle_height)
	var radius = paddle_height * 0.45
	
	# 状態に応じたカラーテーマ
	var theme_color = Color(0.2, 0.75, 1.0) # 通常シアン
	if laser_timer > 0.0:
		theme_color = Color(1.0, 0.35, 0.25) # レーザー（レッド）
	elif is_catch_mode:
		theme_color = Color(0.4, 0.95, 0.3) # キャッチ（ライトグリーン）
	elif expand_timer > 0.0:
		theme_color = Color(0.25, 0.95, 0.55) # ワイド（エメラルド）
	
	# 外側ネオングロー
	draw_style_box_neon(rect, radius, Color(theme_color.r, theme_color.g, theme_color.b, 0.3), 8.0)
	# メインボディ
	draw_style_box_solid(rect, radius, theme_color)
	# ハイライト（上面の光彩）
	var highlight_rect = Rect2(-paddle_width * 0.45, -paddle_height * 0.4, paddle_width * 0.9, paddle_height * 0.35)
	draw_style_box_solid(highlight_rect, radius * 0.6, Color(0.9, 0.96, 1.0, 0.85))
	
	# レーザー砲塔の描画
	if laser_timer > 0.0:
		var turret_w = 6.0
		var turret_h = 8.0
		var offset_x = paddle_width * 0.42
		# 左砲塔
		draw_rect(Rect2(-offset_x - turret_w * 0.5, -paddle_height * 0.5 - turret_h + 2.0, turret_w, turret_h), Color(1.0, 0.4, 0.2))
		# 右砲塔
		draw_rect(Rect2(offset_x - turret_w * 0.5, -paddle_height * 0.5 - turret_h + 2.0, turret_w, turret_h), Color(1.0, 0.4, 0.2))

func draw_style_box_neon(rect: Rect2, radius: float, color: Color, glow_size: float) -> void:
	var expanded = rect.grow(glow_size)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius + glow_size)
	style.corner_radius_top_right = int(radius + glow_size)
	style.corner_radius_bottom_left = int(radius + glow_size)
	style.corner_radius_bottom_right = int(radius + glow_size)
	draw_style_box(style, expanded)

func draw_style_box_solid(rect: Rect2, radius: float, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	draw_style_box(style, rect)


