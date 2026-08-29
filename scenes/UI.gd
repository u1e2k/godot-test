extends CanvasLayer
class_name GameUI

signal start_game_pressed
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal title_pressed
signal launch_pressed

@onready var score_label: Label = $TopBar/Margin/HBox/ScoreLabel
@onready var level_label: Label = $TopBar/Margin/HBox/LevelLabel
@onready var stage_label: Label = $TopBar/Margin/HBox/StageLabel
@onready var lives_label: Label = $TopBar/Margin/HBox/LivesLabel
@onready var pause_button: Button = $TopBar/Margin/HBox/PauseButton
@onready var guide_label: Label = $BottomBar/GuideLabel
@onready var touch_launch_button: Button = $TouchControls/LaunchButton
@onready var powerup_banner: Label = $PowerupBanner

# ゲームオーバー / ステージクリア用
@onready var message_overlay: Control = $MessageOverlay
@onready var message_title: Label = $MessageOverlay/Panel/VBox/TitleLabel
@onready var message_subtitle: Label = $MessageOverlay/Panel/VBox/SubtitleLabel
@onready var action_button: Button = $MessageOverlay/Panel/VBox/ActionButton

# ポーズ用
@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/Panel/VBox/ResumeButton
@onready var restart_button: Button = $PauseOverlay/Panel/VBox/RestartButton
@onready var title_button: Button = $PauseOverlay/Panel/VBox/TitleButton

# タイトル（スタートメニュー）用
@onready var title_screen: Control = $TitleScreen
@onready var highscore_info: Label = $TitleScreen/VBox/HighscoreInfo
@onready var start_game_button: Button = $TitleScreen/VBox/StartGameButton
@onready var blink_prompt: Label = $TitleScreen/VBox/BlinkPrompt

var is_game_over: bool = false
var is_stage_cleared: bool = false
var banner_tween: Tween = null
var blink_time: float = 0.0

var pause_buttons: Array[Button] = []
var current_pause_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	message_overlay.visible = false
	pause_overlay.visible = false
	title_screen.visible = true
	powerup_banner.modulate.a = 0.0
	
	action_button.pressed.connect(_on_action_button_pressed)
	touch_launch_button.pressed.connect(_on_touch_launch_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	
	resume_button.pressed.connect(_on_resume_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	title_button.pressed.connect(_on_title_button_pressed)
	
	start_game_button.pressed.connect(_on_start_game_pressed)
	
	pause_buttons = [resume_button, restart_button, title_button]
	_setup_button_focus_styles()

func _setup_button_focus_styles() -> void:
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color(0.2, 0.5, 0.9, 0.95)
	focus_style.border_width_left = 3
	focus_style.border_width_top = 3
	focus_style.border_width_right = 3
	focus_style.border_width_bottom = 3
	focus_style.border_color = Color(1.0, 0.9, 0.3, 1.0) # 黄色ネオンフォーカス枠
	focus_style.corner_radius_top_left = 8
	focus_style.corner_radius_top_right = 8
	focus_style.corner_radius_bottom_left = 8
	focus_style.corner_radius_bottom_right = 8
	
	var focus_style_danger = StyleBoxFlat.new()
	focus_style_danger.bg_color = Color(0.6, 0.2, 0.25, 0.95)
	focus_style_danger.border_width_left = 3
	focus_style_danger.border_width_top = 3
	focus_style_danger.border_width_right = 3
	focus_style_danger.border_width_bottom = 3
	focus_style_danger.border_color = Color(1.0, 0.9, 0.3, 1.0)
	focus_style_danger.corner_radius_top_left = 8
	focus_style_danger.corner_radius_top_right = 8
	focus_style_danger.corner_radius_bottom_left = 8
	focus_style_danger.corner_radius_bottom_right = 8

	resume_button.add_theme_stylebox_override("focus", focus_style)
	resume_button.add_theme_stylebox_override("hover", focus_style)
	restart_button.add_theme_stylebox_override("focus", focus_style)
	restart_button.add_theme_stylebox_override("hover", focus_style)
	title_button.add_theme_stylebox_override("focus", focus_style_danger)
	title_button.add_theme_stylebox_override("hover", focus_style_danger)
	
	start_game_button.add_theme_stylebox_override("focus", focus_style)
	start_game_button.add_theme_stylebox_override("hover", focus_style)
	action_button.add_theme_stylebox_override("focus", focus_style)
	action_button.add_theme_stylebox_override("hover", focus_style)

func _process(delta: float) -> void:
	if title_screen.visible and blink_prompt:
		blink_time += delta * 4.0
		blink_prompt.modulate.a = 0.4 + 0.6 * abs(sin(blink_time))

func show_title_screen(high_score: int, max_level: int) -> void:
	title_screen.visible = true
	pause_overlay.visible = false
	message_overlay.visible = false
	highscore_info.text = "HIGH SCORE: %05d  |  MAX LV: %d" % [high_score, max_level]
	start_game_button.grab_focus()
	set_launch_guide_visible(false)

func hide_title_screen() -> void:
	title_screen.visible = false

func show_pause_menu() -> void:
	pause_overlay.visible = true
	current_pause_idx = 0
	_update_pause_focus()
	set_launch_guide_visible(false)

func hide_pause_menu() -> void:
	pause_overlay.visible = false

func _update_pause_focus() -> void:
	current_pause_idx = clamp(current_pause_idx, 0, pause_buttons.size() - 1)
	pause_buttons[current_pause_idx].grab_focus()

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
	if title_screen.visible:
		if _is_confirm_event(event):
			_on_start_game_pressed()
			get_viewport().set_input_as_handled()
			
	elif pause_overlay.visible:
		if event.is_action_pressed("pause_game"):
			_on_resume_button_pressed()
			get_viewport().set_input_as_handled()
		elif _is_up_event(event):
			current_pause_idx = (current_pause_idx - 1 + pause_buttons.size()) % pause_buttons.size()
			_update_pause_focus()
			get_viewport().set_input_as_handled()
		elif _is_down_event(event):
			current_pause_idx = (current_pause_idx + 1) % pause_buttons.size()
			_update_pause_focus()
			get_viewport().set_input_as_handled()
		elif _is_confirm_event(event):
			# 現在フォーカスされているボタンを実行
			if current_pause_idx == 0:
				_on_resume_button_pressed()
			elif current_pause_idx == 1:
				_on_restart_button_pressed()
			elif current_pause_idx == 2:
				_on_title_button_pressed()
			get_viewport().set_input_as_handled()
			
	elif message_overlay.visible:
		if _is_confirm_event(event):
			_on_action_button_pressed()
			get_viewport().set_input_as_handled()

func _is_confirm_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action("launch_ball") or event.is_action("restart_game") or event.is_action("ui_accept"):
		return true
	if event is InputEventJoypadButton:
		# Aボタン (0), Bボタン (1), Xボタン (2), Yボタン (3)
		if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			return true
	if event is InputEventKey:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_X, KEY_C]:
			return true
	return false

func _is_up_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action("ui_up"):
		return true
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP:
		return true
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value < -0.5:
		return true
	if event is InputEventKey and (event.keycode == KEY_UP or event.keycode == KEY_W):
		return true
	return false

func _is_down_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action("ui_down"):
		return true
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_DOWN:
		return true
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value > 0.5:
		return true
	if event is InputEventKey and (event.keycode == KEY_DOWN or event.keycode == KEY_S):
		return true
	return false

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
	message_subtitle.text = "FINAL SCORE: %d\n\n【 Ⓑ / Ⓐ ボタン または タップでリトライ 】" % final_score
	action_button.text = "RETRY (Ⓑ / Ⓐ)"
	message_overlay.visible = true
	action_button.grab_focus()
	set_launch_guide_visible(false)

func show_stage_clear(stage: int, bonus_score: int) -> void:
	is_stage_cleared = true
	is_game_over = false
	message_title.text = "STAGE %d CLEAR!" % stage
	message_title.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	message_subtitle.text = "STAGE BONUS: +%d PTS\n\n【 Ⓑ / Ⓐ ボタン または タップで次へ 】" % bonus_score
	action_button.text = "NEXT STAGE (Ⓑ / Ⓐ)"
	message_overlay.visible = true
	action_button.grab_focus()
	set_launch_guide_visible(false)

func _on_action_button_pressed() -> void:
	message_overlay.visible = false
	restart_pressed.emit()

func _on_touch_launch_pressed() -> void:
	launch_pressed.emit()

func _on_pause_button_pressed() -> void:
	pause_pressed.emit()

func _on_resume_button_pressed() -> void:
	hide_pause_menu()
	resume_pressed.emit()

func _on_restart_button_pressed() -> void:
	hide_pause_menu()
	restart_pressed.emit()

func _on_title_button_pressed() -> void:
	hide_pause_menu()
	title_pressed.emit()

func _on_start_game_pressed() -> void:
	hide_title_screen()
	start_game_pressed.emit()
