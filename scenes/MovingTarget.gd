extends StaticBody2D
class_name MovingTarget

signal target_destroyed(points: int, xp: int, pos: Vector2)

@export var max_hp: int = 2
@export var speed: float = 130.0
@export var min_x: float = 65.0
@export var max_x: float = 655.0

var current_hp: int = 2
var move_dir: float = 1.0
var pulse_time: float = 0.0
var is_flashing: bool = false
var is_destroyed: bool = false

const TARGET_WIDTH: float = 58.0
const TARGET_HEIGHT: float = 24.0

func _ready() -> void:
	add_to_group("blocks")
	add_to_group("moving_targets")
	current_hp = max_hp
	is_destroyed = false
	queue_redraw()

func setup(hp: int, spd: float, start_dir: float = 1.0) -> void:
	max_hp = hp
	current_hp = hp
	speed = spd
	move_dir = start_dir
	is_destroyed = false
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	position.x += speed * move_dir * delta
	if position.x >= max_x:
		position.x = max_x
		move_dir = -1.0
	elif position.x <= min_x:
		position.x = min_x
		move_dir = 1.0
	
	pulse_time += delta * 7.0
	queue_redraw()

func take_damage(damage: int = 1) -> void:
	if is_destroyed:
		return
	current_hp -= damage
	if current_hp <= 0:
		_destroy()
	else:
		SoundManager.play_drone_hit()
		_flash_hit()

func _flash_hit() -> void:
	if is_destroyed:
		return
	is_flashing = true
	queue_redraw()
	await get_tree().create_timer(0.08).timeout
	is_flashing = false
	queue_redraw()

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	remove_from_group("blocks")
	remove_from_group("moving_targets")
	
	var col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	
	visible = false
	SoundManager.play_explosion()
	_spawn_particles()
	target_destroyed.emit(800, 300, global_position)
	queue_free()


func _spawn_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 28
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 3.5
	particles.scale_amount_max = 6.5
	particles.color = Color(1.0, 0.3, 0.8)
	particles.global_position = global_position
	if get_parent():
		get_parent().call_deferred("add_child", particles)
	get_tree().create_timer(0.55).timeout.connect(particles.queue_free)

func _draw() -> void:
	var rect = Rect2(-TARGET_WIDTH * 0.5, -TARGET_HEIGHT * 0.5, TARGET_WIDTH, TARGET_HEIGHT)
	var radius = TARGET_HEIGHT * 0.45
	
	var col = Color(1.0, 0.25, 0.75) # ネオンマゼンタ
	if is_flashing:
		col = Color(1.0, 1.0, 1.0)
	elif current_hp < max_hp:
		col = Color(1.0, 0.5, 0.2)
	
	# 外側グロー
	var glow_alpha = 0.25 + 0.15 * sin(pulse_time)
	var style_glow = StyleBoxFlat.new()
	style_glow.bg_color = Color(col.r, col.g, col.b, glow_alpha)
	style_glow.corner_radius_top_left = int(radius + 4.0)
	style_glow.corner_radius_top_right = int(radius + 4.0)
	style_glow.corner_radius_bottom_left = int(radius + 4.0)
	style_glow.corner_radius_bottom_right = int(radius + 4.0)
	draw_style_box(style_glow, rect.grow(4.0))
	
	# ドローン本体
	var style_main = StyleBoxFlat.new()
	style_main.bg_color = Color(0.12, 0.16, 0.28, 0.95)
	style_main.border_width_left = 2
	style_main.border_width_top = 2
	style_main.border_width_right = 2
	style_main.border_width_bottom = 2
	style_main.border_color = col
	style_main.corner_radius_top_left = int(radius)
	style_main.corner_radius_top_right = int(radius)
	style_main.corner_radius_bottom_left = int(radius)
	style_main.corner_radius_bottom_right = int(radius)
	draw_style_box(style_main, rect)
	
	# 中央アイ / コアセンサー
	var core_color = Color(1.0, 0.9, 0.2)
	draw_circle(Vector2.ZERO, 5.0, core_color)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0))
	
	# 左右のLEDインジケータ
	var led_offset = TARGET_WIDTH * 0.35
	draw_circle(Vector2(-led_offset, 0), 2.5, col)
	draw_circle(Vector2(led_offset, 0), 2.5, col)
