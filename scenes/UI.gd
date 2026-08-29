extends CanvasLayer
class_name GameUI

signal restart_pressed
signal launch_pressed

@onready var score_label: Label = $TopBar/Margin/HBox/ScoreLabel
@onready var high_score_label: Label = $TopBar/Margin/HBox/HighScoreLabel
@onready var stage_label: Label = $TopBar/Margin/HBox/StageLabel
@onready var lives_label: Label = $TopBar/Margin/HBox/LivesLabel
@onready var guide_label: Label = $BottomBar/GuideLabel
@onready var touch_launch_button: Button = $TouchControls/LaunchButton
@onready var powerup_banner: Label = $PowerupBanner

@onready var message_overlay: Control = $MessageOverlay
@onready var message_title: Label = $MessageOverlay/Panel/VBox/TitleLabel
@onready var message_subtitle: Label = $MessageOverlay/Panel/VBox/SubtitleLabel
@onready var action_button: Button = $MessageOverlay/Panel/VBox/ActionButton

var is_game_over: bool = false
var is_stage_cleared: bool = false
var banner_tween: Tween = null

func _ready() -> void:
	message_overlay.visible = false
	powerup_banner.modulate.a = 0.0
	action_button.pressed.connect(_on_action_button_pressed)
	touch_launch_button.pressed.connect(_on_touch_launch_pressed)

func show_powerup_banner(banner_text: String, color: Color) -> void:
	if banner_tween:
		banner_tween.kill()
	
	powerup_banner.text = "★ %s ★" % banner_text
	powerup_banner.add_theme_color_override("font_color", color)
	powerup_banner.modulate.a = 1.0
	powerup_banner.position.y = 48.0
	
	banner_tween = create_tween()
	banner_tween.tween_property(powerup_banner, "position:y", 40.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(0.9)
	banner_tween.tween_property(powerup_banner, "modulate:a", 0.0, 0.35)



func _unhandled_input(event: InputEvent) -> void:
	if message_overlay.visible:
		if event.is_action_pressed("launch_ball") or event.is_action_pressed("restart_game"):
			_on_action_button_pressed()

func update_score(score: int, high_score: int) -> void:
	score_label.text = "SCORE: %05d" % score
	high_score_label.text = "HIGH: %05d" % high_score

func update_stage(stage: int) -> void:
	stage_label.text = "STAGE: %d" % stage

func update_lives(lives: int) -> void:
	var hearts = ""
	for i in range(max(0, lives)):
		hearts += "♥ "
	lives_label.text = "LIVES: %s" % hearts.strip_edges()

func set_launch_guide_visible(is_visible: bool) -> void:
	if is_visible:
		guide_label.text = "【 Ⓑ / Ⓐ ボタン または タッチ 】 でボール発射！"
		touch_launch_button.visible = true
	else:
		guide_label.text = "十字キー / スティック / 画面タッチ でパドル移動"
		touch_launch_button.visible = false

func show_game_over(final_score: int) -> void:
	is_game_over = true
	is_stage_cleared = false
	message_title.text = "GAME OVER"
	message_title.modulate = Color(1.0, 0.3, 0.3)
	message_subtitle.text = "FINAL SCORE: %d\n\n[ Ⓑ ] ボタン または ボタンをタップしてリトライ" % final_score
	action_button.text = "RETRY (Ⓑ)"
	message_overlay.visible = true

func show_stage_clear(stage: int, bonus: int) -> void:
	is_stage_cleared = true
	is_game_over = false
	message_title.text = "STAGE CLEAR!"
	message_title.modulate = Color(0.3, 1.0, 0.5)
	message_subtitle.text = "STAGE %d CLEARED!\nCLEAR BONUS: +%d\n\n[ Ⓑ ] ボタン または ボタンをタップして次のステージへ" % [stage, bonus]
	action_button.text = "NEXT STAGE (Ⓑ)"
	message_overlay.visible = true

func hide_overlay() -> void:
	message_overlay.visible = false

func _on_action_button_pressed() -> void:
	if message_overlay.visible:
		message_overlay.visible = false
		restart_pressed.emit()

func _on_touch_launch_pressed() -> void:
	launch_pressed.emit()
