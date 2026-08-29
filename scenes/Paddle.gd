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

func _ready() -> void:
	add_to_group("paddle")
	global_position.y = PADDLE_Y
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

func _draw() -> void:
	var rect = Rect2(-paddle_width * 0.5, -paddle_height * 0.5, paddle_width, paddle_height)
	var radius = paddle_height * 0.45
	
	# 外側ネオングロー
	draw_style_box_neon(rect, radius, Color(0.15, 0.65, 1.0, 0.25), 8.0)
	# メインボディ
	draw_style_box_solid(rect, radius, Color(0.2, 0.75, 1.0, 1.0))
	# ハイライト（上面の光彩）
	var highlight_rect = Rect2(-paddle_width * 0.45, -paddle_height * 0.4, paddle_width * 0.9, paddle_height * 0.35)
	draw_style_box_solid(highlight_rect, radius * 0.6, Color(0.85, 0.95, 1.0, 0.85))

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
