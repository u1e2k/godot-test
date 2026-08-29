extends Area2D
class_name DropItem

enum Type {
	WIDE,
	MULTI,
	LASER,
	FIRE,
	SLOW,
	LIFE,
	SHIELD,
	BOMB,
	CATCH,
	MEGA,
	MISSILE,
	STAR
}

signal item_collected(item_type: Type)

@export var item_type: Type = Type.WIDE
@export var fall_speed: float = 175.0

var pulse_time: float = 0.0
const ITEM_WIDTH: float = 34.0
const ITEM_HEIGHT: float = 18.0

const TYPE_CONFIG = {
	Type.WIDE:    {"label": "W", "color": Color(0.25, 0.95, 0.55), "name": "WIDE PADDLE"},
	Type.MULTI:   {"label": "M", "color": Color(0.85, 0.35, 1.0),  "name": "MULTI-BALL"},
	Type.LASER:   {"label": "L", "color": Color(1.0, 0.3, 0.25),   "name": "LASER CANNON"},
	Type.FIRE:    {"label": "F", "color": Color(1.0, 0.7, 0.1),    "name": "FIRE BALL"},
	Type.SLOW:    {"label": "S", "color": Color(0.2, 0.85, 1.0),   "name": "SLOW DOWN"},
	Type.LIFE:    {"label": "♥", "color": Color(1.0, 0.35, 0.65),  "name": "EXTRA LIFE"},
	Type.SHIELD:  {"label": "B", "color": Color(0.2, 0.75, 1.0),   "name": "BOTTOM SHIELD"},
	Type.BOMB:    {"label": "X", "color": Color(1.0, 0.55, 0.1),   "name": "BOMB BALL"},
	Type.CATCH:   {"label": "C", "color": Color(0.4, 0.95, 0.3),   "name": "CATCH PADDLE"},
	Type.MEGA:    {"label": "5", "color": Color(1.0, 0.3, 0.8),    "name": "MEGA 5-BALL"},
	Type.MISSILE: {"label": "R", "color": Color(1.0, 0.25, 0.2),   "name": "HOMING MISSILES"},
	Type.STAR:    {"label": "★", "color": Color(1.0, 0.9, 0.2),    "name": "STAR BONUS +1000"}
}


func _ready() -> void:
	add_to_group("items")
	body_entered.connect(_on_body_entered)
	queue_redraw()

func setup(type: Type) -> void:
	item_type = type
	queue_redraw()

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	pulse_time += delta * 6.0
	queue_redraw()
	
	if position.y > 735.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("paddle"):
		_collect()

func _collect() -> void:
	_spawn_collect_particles()
	if item_type == Type.LIFE:
		SoundManager.play_extra_life()
	else:
		SoundManager.play_powerup()
	
	item_collected.emit(item_type)
	queue_free()

func _spawn_collect_particles() -> void:
	var cfg = TYPE_CONFIG.get(item_type, TYPE_CONFIG[Type.WIDE])
	var col = cfg["color"] as Color
	
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 14
	particles.lifetime = 0.4
	particles.spread = 180.0
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.0
	particles.color = col
	if get_parent():
		get_parent().call_deferred("add_child", particles)
	get_tree().create_timer(0.45).timeout.connect(particles.queue_free)


func _draw() -> void:
	var cfg = TYPE_CONFIG.get(item_type, TYPE_CONFIG[Type.WIDE])
	var col = cfg["color"] as Color
	var label = cfg["label"] as String
	
	var rect = Rect2(-ITEM_WIDTH * 0.5, -ITEM_HEIGHT * 0.5, ITEM_WIDTH, ITEM_HEIGHT)
	var radius = ITEM_HEIGHT * 0.5
	
	# 脈動グロー
	var glow_alpha = 0.25 + 0.15 * sin(pulse_time)
	var style_glow = StyleBoxFlat.new()
	style_glow.bg_color = Color(col.r, col.g, col.b, glow_alpha)
	style_glow.corner_radius_top_left = int(radius + 4.0)
	style_glow.corner_radius_top_right = int(radius + 4.0)
	style_glow.corner_radius_bottom_left = int(radius + 4.0)
	style_glow.corner_radius_bottom_right = int(radius + 4.0)
	draw_style_box(style_glow, rect.grow(4.0))
	
	# カプセル外枠 (ピル)
	var style_pill = StyleBoxFlat.new()
	style_pill.bg_color = Color(0.08, 0.12, 0.2, 0.95)
	style_pill.border_width_left = 2
	style_pill.border_width_top = 2
	style_pill.border_width_right = 2
	style_pill.border_width_bottom = 2
	style_pill.border_color = col
	style_pill.corner_radius_top_left = int(radius)
	style_pill.corner_radius_top_right = int(radius)
	style_pill.corner_radius_bottom_left = int(radius)
	style_pill.corner_radius_bottom_right = int(radius)
	draw_style_box(style_pill, rect)
	
	# テキスト / アイコン描画
	var font = ThemeDB.fallback_font
	var font_size = 13 if label != "♥" else 15
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)
