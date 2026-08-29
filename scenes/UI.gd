extends CanvasLayer
class_name GameUI

signal restart_pressed
signal launch_pressed

@onready var score_label: Label = $TopBar/Margin/HBox/ScoreLabel
@onready var level_label: Label = $TopBar/Margin/HBox/LevelLabel
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

func show_level_up_banner(level: int, perk_text: String) -> void:
	if banner_tween:
		banner_tween.kill()
	
	powerup_banner.text = "🎉 LEVEL UP! LV.%d 🎉\n%s" % [level, perk_text]
	powerup_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	powerup_banner.modulate.a = 1.0
	powerup_banner.position.y = 52.0
	
	banner_tween = create_tween()
	banner_tween.tween_property(powerup_banner, "position:y", 40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(1.4)
	banner_tween.tween_property(powerup_banner, "modulate:a", 0.0, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if message_overlay.visible:
		if event.is_action_pressed("launch_ball") or event.is_action_pressed("restart_game"):
			_on_action_button_pressed()

func update_score(score: int, high_score: int) -> void:
	score_label.text = "SCORE: %05d" % score

func update_level(level: int, current_xp: int, next_xp: int) -> void:
	var pct = 0
	if next_xp > 0:
		pct = int((float(current_xp) / float(next_xp)) * 100.0)
	pct = clamp(pct, 0, 99)
	level_label.text = "LV.%d (%d%%)" % [level, pct]

func update_stage(stage: int) -> void:
	stage_label.text = "STAGE: %d" % stage

func update_lives(lives: int) -> void:
	var hearts = ""
	for i in range(max(0, lives)):
		hearts += "♥ "
	lives_label.text = "LIVES: " + hearts.strip_edges()

func set_launch_guide_visible(is_visible: bool) -> void:
	guide_label.visible = is_visible
	touch_launch_button.visible = is_visible

func show_game_over(final_score: int) -> void:
	is_game_over = true
	is_stage_cleared = false
	message_title.text = "GAME OVER"
	message_title.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	message_subtitle.text = "FINAL SCORE: %d" % final_score
	action_button.text = "RETRY (B BUTTON)"
	message_overlay.visible = true
	set_launch_guide_visible(false)

func show_stage_clear(stage: int, bonus_score: int) -> void:
	is_stage_cleared = true
	is_game_over = false
	message_title.text = "STAGE %d CLEAR!" % stage
	message_title.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	message_subtitle.text = "STAGE BONUS: +%d PTS" % bonus_score
	action_button.text = "NEXT STAGE (B BUTTON)"
	message_overlay.visible = true
	set_launch_guide_visible(false)

func _on_action_button_pressed() -> void:
	message_overlay.visible = false
	restart_pressed.emit()

func _on_touch_launch_pressed() -> void:
	launch_pressed.emit()
