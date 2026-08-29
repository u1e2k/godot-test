extends Area2D
class_name Laser

@export var speed: float = 950.0
@export var damage: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	position.y -= speed * delta
	if position.y < 35.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("blocks"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_spawn_hit_spark()
		queue_free()
	elif not body.is_in_group("paddle") and not body.is_in_group("ball"):
		# 壁などに当たった場合
		queue_free()

func _spawn_hit_spark() -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.3
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.3, 0.3)
	if get_parent():
		get_parent().call_deferred("add_child", particles)
	get_tree().create_timer(0.35).timeout.connect(particles.queue_free)


func _draw() -> void:
	# レーザー外側グロー
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(1.0, 0.2, 0.2, 0.4), 6.0)
	# レーザー本体
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(1.0, 0.3, 0.2, 1.0), 3.0)
	# レーザーコア（白熱）
	draw_line(Vector2(0, -8), Vector2(0, 8), Color(1.0, 0.95, 0.9, 1.0), 1.5)
