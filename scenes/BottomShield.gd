extends StaticBody2D
class_name BottomShield

@export var max_hp: int = 2
var current_hp: int = 2
var pulse_time: float = 0.0
var is_flashing: bool = false

const SHIELD_WIDTH: float = 680.0
const SHIELD_HEIGHT: float = 12.0

func _ready() -> void:
	add_to_group("shield")
	current_hp = max_hp
	queue_redraw()

func _physics_process(delta: float) -> void:
	pulse_time += delta * 5.0
	queue_redraw()

func hit_by_ball() -> void:
	current_hp -= 1
	SoundManager.play_shield()
	_flash_hit()
	
	if current_hp <= 0:
		_break_shield()

func _flash_hit() -> void:
	is_flashing = true
	queue_redraw()
	await get_tree().create_timer(0.08).timeout
	is_flashing = false
	queue_redraw()

func _break_shield() -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 24
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.2, 0.8, 1.0)
	particles.global_position = global_position
	if get_parent():
		get_parent().call_deferred("add_child", particles)
	get_tree().create_timer(0.55).timeout.connect(particles.queue_free)
	queue_free()


func _draw() -> void:
	var rect = Rect2(-SHIELD_WIDTH * 0.5, -SHIELD_HEIGHT * 0.5, SHIELD_WIDTH, SHIELD_HEIGHT)
	var radius = 4.0
	
	var base_col = Color(0.2, 0.75, 1.0, 0.9)
	if is_flashing:
		base_col = Color(1.0, 1.0, 1.0, 1.0)
	elif current_hp == 1:
		base_col = Color(0.9, 0.4, 0.2, 0.9) # 傷ついた時はオレンジ
	
	# 外側パルスグロー
	var glow_alpha = 0.3 + 0.15 * sin(pulse_time)
	var style_glow = StyleBoxFlat.new()
	style_glow.bg_color = Color(base_col.r, base_col.g, base_col.b, glow_alpha)
	style_glow.corner_radius_top_left = 6
	style_glow.corner_radius_top_right = 6
	style_glow.corner_radius_bottom_left = 6
	style_glow.corner_radius_bottom_right = 6
	draw_style_box(style_glow, rect.grow(4.0))
	
	# シールドバー本体
	var style_main = StyleBoxFlat.new()
	style_main.bg_color = base_col
	style_main.corner_radius_top_left = int(radius)
	style_main.corner_radius_top_right = int(radius)
	style_main.corner_radius_bottom_left = int(radius)
	style_main.corner_radius_bottom_right = int(radius)
	draw_style_box(style_main, rect)
	
	# パターンライン
	var segs = 16
	var seg_w = SHIELD_WIDTH / segs
	for i in range(segs):
		var x = -SHIELD_WIDTH * 0.5 + i * seg_w + seg_w * 0.5
		draw_line(Vector2(x, -SHIELD_HEIGHT * 0.35), Vector2(x, SHIELD_HEIGHT * 0.35), Color(1.0, 1.0, 1.0, 0.5), 1.5)
