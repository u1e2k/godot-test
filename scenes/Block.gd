extends StaticBody2D
class_name Block

signal block_destroyed(points: int, global_pos: Vector2)

@export var max_hp: int = 1
@export var points: int = 100
@export var base_color: Color = Color(0.95, 0.25, 0.4)
@export var block_width: float = 76.0
@export var block_height: float = 26.0

var current_hp: int = 1
var is_flashing: bool = false

func _ready() -> void:
	add_to_group("blocks")
	current_hp = max_hp
	queue_redraw()

func setup(hp: int, pts: int, color: Color) -> void:
	max_hp = hp
	current_hp = hp
	points = pts
	base_color = color
	queue_redraw()

func take_damage(damage: int = 1) -> void:
	current_hp -= damage
	if current_hp <= 0:
		_destroy()
	else:
		_flash_hit()
		SoundManager.play_block_hit()

func _flash_hit() -> void:
	is_flashing = true
	queue_redraw()
	await get_tree().create_timer(0.06).timeout
	is_flashing = false
	queue_redraw()

func _destroy() -> void:
	_spawn_particles()
	SoundManager.play_block_break()
	block_destroyed.emit(points, global_position)
	queue_free()

func _spawn_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 16
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = base_color
	particles.global_position = global_position
	
	get_parent().add_child(particles)
	
	# パーティクル終了後に自動削除
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

func _draw() -> void:
	var rect = Rect2(-block_width * 0.5, -block_height * 0.5, block_width, block_height)
	var radius = 4.0
	
	var col = base_color
	if is_flashing:
		col = Color(1.0, 1.0, 1.0, 1.0)
	elif current_hp < max_hp:
		# ダメージ時は少し暗く
		col = col.darkened(0.25)
	
	# 外枠グロー
	var style_glow = StyleBoxFlat.new()
	style_glow.bg_color = Color(col.r, col.g, col.b, 0.25)
	style_glow.corner_radius_top_left = 6
	style_glow.corner_radius_top_right = 6
	style_glow.corner_radius_bottom_left = 6
	style_glow.corner_radius_bottom_right = 6
	draw_style_box(style_glow, rect.grow(2.0))
	
	# ブロック本体
	var style_main = StyleBoxFlat.new()
	style_main.bg_color = col
	style_main.corner_radius_top_left = int(radius)
	style_main.corner_radius_top_right = int(radius)
	style_main.corner_radius_bottom_left = int(radius)
	style_main.corner_radius_bottom_right = int(radius)
	draw_style_box(style_main, rect)
	
	# 上面ハイライト
	var hl_rect = Rect2(-block_width * 0.5 + 2.0, -block_height * 0.5 + 2.0, block_width - 4.0, block_height * 0.35)
	var style_hl = StyleBoxFlat.new()
	style_hl.bg_color = Color(1.0, 1.0, 1.0, 0.35)
	style_hl.corner_radius_top_left = 3
	style_hl.corner_radius_top_right = 3
	draw_style_box(style_hl, hl_rect)
	
	# 耐久力インジケータ（複数HPブロックの場合）
	if max_hp > 1:
		var dot_radius = 2.5
		var spacing = 8.0
		var start_x = -((current_hp - 1) * spacing) * 0.5
		for i in range(current_hp):
			var dot_pos = Vector2(start_x + i * spacing, block_height * 0.2)
			draw_circle(dot_pos, dot_radius, Color(1.0, 1.0, 1.0, 0.8))
