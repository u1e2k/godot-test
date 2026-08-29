extends Area2D
class_name Missile

@export var speed: float = 680.0
@export var turn_speed: float = 14.0
@export var damage: int = 2

var velocity: Vector2 = Vector2.UP
var target: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_find_target()
	queue_redraw()

func _find_target() -> void:
	var blocks = get_tree().get_nodes_in_group("blocks")
	if blocks.is_empty():
		target = null
		return
	
	var closest: Node2D = null
	var min_dist: float = 99999.0
	for b in blocks:
		if is_instance_valid(b):
			var d = global_position.distance_to(b.global_position)
			if d < min_dist:
				min_dist = d
				closest = b as Node2D
	target = closest

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		_find_target()
	
	if is_instance_valid(target):
		var target_dir = (target.global_position - global_position).normalized()
		var current_angle = velocity.angle()
		var target_angle = target_dir.angle()
		var new_angle = rotate_toward(current_angle, target_angle, turn_speed * delta)
		velocity = Vector2.RIGHT.rotated(new_angle) * speed
	else:
		velocity = velocity.move_toward(Vector2.UP * speed, speed * delta * 5.0)
	
	position += velocity * delta
	rotation = velocity.angle() + PI * 0.5
	
	if position.y < 35.0 or position.x < 10.0 or position.x > 710.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("blocks"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_explode()
	elif not body.is_in_group("paddle") and not body.is_in_group("ball"):
		_explode()

func _explode() -> void:
	SoundManager.play_explosion()
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 16
	particles.lifetime = 0.35
	particles.spread = 180.0
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = Color(1.0, 0.4, 0.1)
	particles.global_position = global_position
	if get_parent():
		get_parent().call_deferred("add_child", particles)
	get_tree().create_timer(0.4).timeout.connect(particles.queue_free)
	queue_free()


func _draw() -> void:
	# ミサイル本体
	draw_line(Vector2(0, 8), Vector2(0, -8), Color(1.0, 0.3, 0.2), 4.0)
	draw_circle(Vector2(0, -8), 3.0, Color(1.0, 0.8, 0.2))
	# 翼
	draw_line(Vector2(-4, 6), Vector2(4, 6), Color(1.0, 0.5, 0.2), 2.0)
