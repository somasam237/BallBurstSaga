extends Node2D

@onready var board              = $Board
@onready var background         = $Background
@onready var board_bg           = $BoardBG
@onready var score_label        = $UI/HUD/ScoreLabel
@onready var moves_label        = $UI/HUD/MovesLabel
@onready var goal_label         = $UI/HUD/GoalLabel
@onready var hint_classic_button = $UI/HUD/HintClassicButton
@onready var hint_best_button    = $UI/HUD/HintBestButton
@onready var restart_button     = $UI/HUD/RestartButton
@onready var menu_button        = $UI/HUD/MenuButton
@onready var pause_button       = $UI/HUD/PauseButton
@onready var message_label      = $UI/HUD/MessageLabel
@onready var level_label        = $UI/HUD/LevelLabel
@onready var level_bg           = $UI/HUD/LevelBG
@onready var gameplay_music     = $GameplayMusic
@onready var match_sfx          = $MatchSfx
@onready var pause_ui           = $PauseUI
@onready var resume_button      = $PauseUI/PausePanel/PauseVBox/ResumeButton
@onready var quit_button        = $PauseUI/PausePanel/PauseVBox/QuitButton
@onready var end_ui             = $EndUI
@onready var end_panel          = $EndUI/EndPanel
@onready var end_icon           = $EndUI/EndPanel/EndVBox/EndIcon
@onready var end_title          = $EndUI/EndPanel/EndVBox/EndTitle
@onready var end_score          = $EndUI/EndPanel/EndVBox/EndScore
@onready var end_next_button    = $EndUI/EndPanel/EndVBox/EndNextButton
@onready var end_restart_button = $EndUI/EndPanel/EndVBox/EndRestartButton
@onready var end_menu_button    = $EndUI/EndPanel/EndVBox/EndMenuButton
@onready var win_sfx            = $WinSfx
@onready var lose_sfx           = $LoseSfx

var adaptive         = null
var total_score      = 0
var hints_used_count = 0
var moves_at_start   = 0

var _welcome_layer   = null
var _confirm_layer   = null
var _flash_overlay   = null
var _name_label_hud  = null
var _diff_label_hud  = null  

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready():
	if has_node("AdaptiveDifficulty"):
		adaptive = $AdaptiveDifficulty

	GameState.load_progress()

	var save_data = SaveSystem.new().load_game()
	if save_data.has("current_level"):
		GameState.current_level_index = save_data["current_level"]
	if save_data.has("total_score"):
		total_score = save_data["total_score"]

	_fit_background()
	board.scale = Vector2(1.2, 1.2)
	_center_board()

	board.score_gained.connect(_on_score_gained)
	board.moves_used.connect(_on_moves_used)
	board.message.connect(_on_message)
	board.game_over.connect(_on_game_over)
	board.big_match_happened.connect(_on_big_match)

	if gameplay_music.stream is AudioStreamMP3:
		gameplay_music.stream.loop = true
	elif gameplay_music.stream is AudioStreamOggVorbis:
		gameplay_music.stream.loop = true

	_create_flash_overlay()
	_setup_ui()

	if GameState.player_name == "":
		_show_welcome_screen()
	else:
		_begin_game()

#  ANIMATED WELCOME SCREEN


func _show_welcome_screen():
	var vp = get_viewport_rect().size

	_welcome_layer              = CanvasLayer.new()
	_welcome_layer.name         = "WelcomeLayer"
	_welcome_layer.layer        = 5
	_welcome_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_welcome_layer)



	# ── Deep candy-purple background ─────────────────────────
	var bg        = ColorRect.new()
	bg.color      = Color(0.13, 0.07, 0.28, 1.0)   
	bg.size       = vp
	_welcome_layer.add_child(bg)

	# ── Animated sun (large pulsing circle, top-right) ───────
	var sun       = _make_oval(vp.x - 140, -60, 220, 220, Color(1.0, 0.85, 0.1))
	_welcome_layer.add_child(sun)
	# Sun glow ring
	var sun_glow  = _make_oval(vp.x - 160, -80, 260, 260, Color(1.0, 0.92, 0.3, 0.25))
	_welcome_layer.add_child(sun_glow)
	# Sun rays (8 lines fanning out)
	for i in 8:
		var angle   = deg_to_rad(i * 45.0)
		var ray     = ColorRect.new()
		ray.size    = Vector2(80, 6)
		ray.color   = Color(1.0, 0.9, 0.2, 0.55)
		ray.pivot_offset = Vector2(0, 3)
		ray.position = Vector2(vp.x - 30, 50)
		ray.rotation = angle
		_welcome_layer.add_child(ray)

	# Pulse animation for sun
	var sun_tween = create_tween().set_loops()
	sun_tween.tween_property(sun,      "scale", Vector2(1.08, 1.08), 1.1).set_trans(Tween.TRANS_SINE)
	sun_tween.tween_property(sun,      "scale", Vector2(1.0,  1.0),  1.1).set_trans(Tween.TRANS_SINE)
	var glow_tween = create_tween().set_loops()
	glow_tween.tween_property(sun_glow, "scale", Vector2(1.15, 1.15), 1.4).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(sun_glow, "scale", Vector2(1.0,  1.0),  1.4).set_trans(Tween.TRANS_SINE)

	# ── Bouncing candy balls (background decoration) ─────────
	var ball_colors = [
		Color(0.95, 0.25, 0.50),  # hot pink
		Color(0.3,  0.85, 0.4),   # green
		Color(0.25, 0.65, 1.0),   # blue
		Color(1.0,  0.75, 0.1),   # yellow
		Color(0.75, 0.25, 1.0),   # purple
		Color(1.0,  0.45, 0.1),   # orange
	]
	var ball_positions = [
		Vector2(50,  80),  Vector2(120, 500), Vector2(200, 200),
		Vector2(vp.x - 200, 400), Vector2(80, 380), Vector2(vp.x - 80, 200),
	]
	for i in ball_colors.size():
		var ball        = _make_oval(ball_positions[i].x, ball_positions[i].y, 55, 55, ball_colors[i])
		_welcome_layer.add_child(ball)
		var bt          = create_tween().set_loops()
		var bounce_h    = randf_range(18, 40)
		bt.tween_property(ball, "position:y", ball_positions[i].y - bounce_h, 0.5 + i * 0.07)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bt.tween_property(ball, "position:y", ball_positions[i].y,            0.5 + i * 0.07)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── Floating star emojis ─────────────────────────────────
	var star_data = [
		{"text": "⭐", "x": 60,        "y": 160, "size": 30},
		{"text": "✨", "x": vp.x-100,  "y": 300, "size": 26},
		{"text": "💫", "x": 160,       "y": 450, "size": 28},
		{"text": "⭐", "x": vp.x-160,  "y": 120, "size": 22},
		{"text": "✨", "x": 280,       "y": 520, "size": 24},
	]
	for sd in star_data:
		var star = Label.new()
		star.text = sd["text"]
		star.add_theme_font_size_override("font_size", sd["size"])
		star.position = Vector2(sd["x"], sd["y"])
		_welcome_layer.add_child(star)
		var st   = create_tween().set_loops()
		st.tween_property(star, "position:y", sd["y"] - 25, 1.2 + randf_range(0, 0.6))\
			.set_trans(Tween.TRANS_SINE)
		st.tween_property(star, "position:y", sd["y"],       1.2 + randf_range(0, 0.6))\
			.set_trans(Tween.TRANS_SINE)

	# ── Cute "eyes" character (top-left) ─────────────────────
	_make_eyes_character(40, 280, _welcome_layer)

	# ── Central white card ───────────────────────────────────
	var card_w   = min(560.0, vp.x - 60)
	var card_h   = 490.0
	var card_x   = vp.x / 2.0 - card_w / 2.0
	var card_y   = vp.y / 2.0 - card_h / 2.0

	# Card shadow
	var shadow   = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.size  = Vector2(card_w + 12, card_h + 12)
	shadow.position = Vector2(card_x + 6, card_y + 8)
	_welcome_layer.add_child(shadow)

	# Card background
	var card     = ColorRect.new()
	card.color   = Color(0.97, 0.95, 1.0, 1.0)
	card.size    = Vector2(card_w, card_h)
	card.position = Vector2(card_x, card_y)
	_welcome_layer.add_child(card)

	# Pink top accent bar on card
	var accent   = ColorRect.new()
	accent.color = Color(0.95, 0.25, 0.55)
	accent.size  = Vector2(card_w, 8)
	accent.position = Vector2(card_x, card_y)
	_welcome_layer.add_child(accent)

	# ── GAME TITLE (bouncy entrance) ─────────────────────────
	var title    = Label.new()
	title.text   = "BALL  BURST  SAGA"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.13, 0.07, 0.28))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size   = Vector2(card_w - 20, 60)
	title.position = Vector2(card_x + 10, card_y + 20)
	_welcome_layer.add_child(title)

	# Title bounce entrance animation
	title.scale = Vector2(0.3, 0.3)
	title.pivot_offset = Vector2((card_w - 20) / 2.0, 30)
	var title_t  = create_tween()
	title_t.tween_property(title, "scale", Vector2(1.08, 1.08), 0.5)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	title_t.tween_property(title, "scale", Vector2(1.0, 1.0), 0.2)

	# Subtitle in pink
	var subtitle = Label.new()
	subtitle.text = "🍭  Das bunte Match-3-Abenteuer!  🍭"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.2, 0.5))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(card_w - 20, 28)
	subtitle.position = Vector2(card_x + 10, card_y + 68)
	_welcome_layer.add_child(subtitle)

	# Divider line
	var divider  = ColorRect.new()
	divider.color = Color(0.85, 0.2, 0.5, 0.35)
	divider.size  = Vector2(card_w - 60, 2)
	divider.position = Vector2(card_x + 30, card_y + 100)
	_welcome_layer.add_child(divider)

	# ── Name input section ────────────────────────────────────
	var name_title = Label.new()
	name_title.text = "Wie heißt du?"
	name_title.add_theme_font_size_override("font_size", 20)
	name_title.add_theme_color_override("font_color", Color(0.13, 0.07, 0.28))
	name_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_title.size = Vector2(card_w - 20, 34)
	name_title.position = Vector2(card_x + 10, card_y + 112)
	_welcome_layer.add_child(name_title)

	# LineEdit for name
	var name_input     = LineEdit.new()
	name_input.placeholder_text = "Gib deinen Spitznamen ein…"
	name_input.max_length       = 20
	name_input.size             = Vector2(card_w - 80, 46)
	name_input.position         = Vector2(card_x + 40, card_y + 150)
	name_input.alignment        = HORIZONTAL_ALIGNMENT_CENTER
	name_input.add_theme_font_size_override("font_size", 18)
	_welcome_layer.add_child(name_input)

	# ── How to play ───────────────────────────────────────────
	var divider2 = ColorRect.new()
	divider2.color = Color(0.85, 0.2, 0.5, 0.35)
	divider2.size  = Vector2(card_w - 60, 2)
	divider2.position = Vector2(card_x + 30, card_y + 206)
	_welcome_layer.add_child(divider2)

	var how_title     = Label.new()
	how_title.text    = "Spielanleitung"
	how_title.add_theme_font_size_override("font_size", 17)
	how_title.add_theme_color_override("font_color", Color(0.13, 0.07, 0.28))
	how_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how_title.size = Vector2(card_w - 20, 30)
	how_title.position = Vector2(card_x + 10, card_y + 212)
	_welcome_layer.add_child(how_title)

	# Instruction rows with colored icons
	var instructions = [
		["🔵", "Klicke 2 benachbarte Kugeln zum Tauschen"],
		["✨", "3+ gleiche Farben = Punkte!"],
		["💥", "4+ Kugeln = Explosions-Bonus!"],
		["🏆", "Erreiche das Ziel vor dem letzten Zug"],
		["💡", "Drücke ? für einen Hinweis"],
	]
	for i in instructions.size():
		var row_y    = card_y + 248 + i * 34
		var icon_lbl = Label.new()
		icon_lbl.text = instructions[i][0]
		icon_lbl.add_theme_font_size_override("font_size", 18)
		icon_lbl.size = Vector2(34, 30)
		icon_lbl.position = Vector2(card_x + 25, row_y)
		_welcome_layer.add_child(icon_lbl)

		var txt_lbl  = Label.new()
		txt_lbl.text = instructions[i][1]
		txt_lbl.add_theme_font_size_override("font_size", 14)
		txt_lbl.add_theme_color_override("font_color", Color(0.2, 0.1, 0.35))
		txt_lbl.size = Vector2(card_w - 75, 30)
		txt_lbl.position = Vector2(card_x + 62, row_y)
		_welcome_layer.add_child(txt_lbl)

	# ── PLAY BUTTON (big, colorful, animated) ─────────────────
	var btn_bg    = ColorRect.new()
	btn_bg.color  = Color(0.95, 0.25, 0.55)
	btn_bg.size   = Vector2(220, 54)
	btn_bg.position = Vector2(card_x + card_w / 2.0 - 110, card_y + card_h - 68)
	_welcome_layer.add_child(btn_bg)

	var play_btn  = Button.new()
	play_btn.text = "LOS GEHT'S!  🎮"
	play_btn.flat = true
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	play_btn.size = Vector2(220, 54)
	play_btn.position = Vector2(card_x + card_w / 2.0 - 110, card_y + card_h - 68)
	play_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_welcome_layer.add_child(play_btn)

	# Button pulse animation
	var btn_t     = create_tween().set_loops()
	btn_t.tween_property(btn_bg, "color", Color(0.75, 0.15, 0.45), 0.8).set_trans(Tween.TRANS_SINE)
	btn_t.tween_property(btn_bg, "color", Color(0.95, 0.25, 0.55), 0.8).set_trans(Tween.TRANS_SINE)

	# Card pop-in animation
	card.scale    = Vector2(0.8, 0.8)
	card.pivot_offset = Vector2(card_w / 2.0, card_h / 2.0)
	var card_t    = create_tween()
	card_t.tween_property(card, "scale", Vector2(1.0, 1.0), 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# ── Button handler ────────────────────────────────────────
	play_btn.pressed.connect(func():
		var raw_name = name_input.text.strip_edges()
		if raw_name == "":
			raw_name = "Player"
		GameState.player_name = raw_name
		GameState._save_progress()

		var t = create_tween()
		t.tween_property(card,   "modulate:a", 0.0, 0.25)
		t.tween_property(bg,     "modulate:a", 0.0, 0.25)
		t.tween_callback(func():
			_welcome_layer.queue_free()
			_welcome_layer = null
			_begin_game()
		)
	)
	name_input.text_submitted.connect(func(_txt): play_btn.emit_signal("pressed"))

# ── Helper: create a simple colored oval (circle) ───────────
func _make_oval(x, y, w, h, color):
	var rect      = ColorRect.new()
	# We fake a circle by using a square ColorRect with a circular shader would be ideal,
	# but for simplicity we just use a ColorRect and accept it's a rectangle.
	# A true oval would need a custom drawn node, but this works well enough.
	rect.color    = color
	rect.size     = Vector2(w, h)
	rect.position = Vector2(x, y)
	return rect

# ── Helper: cute eyes character ─────────────────────────────
func _make_eyes_character(x, y, parent):
	# Body (big rounded blob)
	var body      = ColorRect.new()
	body.color    = Color(0.95, 0.25, 0.55)
	body.size     = Vector2(80, 90)
	body.position = Vector2(x, y)
	parent.add_child(body)

	# Left eye white
	var le_w      = ColorRect.new()
	le_w.color    = Color(1.0, 1.0, 1.0)
	le_w.size     = Vector2(26, 26)
	le_w.position = Vector2(x + 8, y + 20)
	parent.add_child(le_w)

	# Right eye white
	var re_w      = ColorRect.new()
	re_w.color    = Color(1.0, 1.0, 1.0)
	re_w.size     = Vector2(26, 26)
	re_w.position = Vector2(x + 46, y + 20)
	parent.add_child(re_w)

	# Left pupil
	var le_p      = ColorRect.new()
	le_p.color    = Color(0.1, 0.05, 0.2)
	le_p.size     = Vector2(12, 14)
	le_p.position = Vector2(x + 15, y + 26)
	parent.add_child(le_p)

	# Right pupil
	var re_p      = ColorRect.new()
	re_p.color    = Color(0.1, 0.05, 0.2)
	re_p.size     = Vector2(12, 14)
	re_p.position = Vector2(x + 53, y + 26)
	parent.add_child(re_p)

	# Smile
	var smile     = Label.new()
	smile.text    = "  ‿‿"
	smile.add_theme_font_size_override("font_size", 22)
	smile.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	smile.position = Vector2(x + 4, y + 55)
	parent.add_child(smile)

	# Eyes blink animation
	var blink     = create_tween().set_loops()
	blink.tween_interval(2.5)
	blink.tween_property(le_w, "scale:y", 0.1, 0.06)
	blink.tween_property(le_w, "scale:y", 1.0, 0.06)
	blink.tween_property(re_w, "scale:y", 0.1, 0.06)
	blink.tween_property(re_w, "scale:y", 1.0, 0.06)

	# Character bounce
	var char_t    = create_tween().set_loops()
	char_t.tween_property(body, "position:y", y - 12, 0.7).set_trans(Tween.TRANS_SINE)
	char_t.tween_property(body, "position:y", y,       0.7).set_trans(Tween.TRANS_SINE)

func _add_spacer(parent, height):
	var s = Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)

func _add_spacer_h(parent, width):
	var s = Control.new()
	s.custom_minimum_size = Vector2(width, 0)
	parent.add_child(s)

# ============================================================
#  BEGIN GAME
# ============================================================

func _begin_game():
	gameplay_music.play()
	_update_name_in_hud()
	_start_level()

# ============================================================
#  LAYOUT
# ============================================================

func _fit_background():
	var vp_size = get_viewport_rect().size
	var tex     = background.texture
	if tex == null: return
	var tex_size = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0: return
	var scale_f      = max(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	background.scale    = Vector2(scale_f, scale_f)
	background.position = vp_size * 0.5

func _center_board():
	var vp_size    = get_viewport_rect().size
	var board_size = Vector2(float(board.width)  * float(board.cell_size),
							 float(board.height) * float(board.cell_size))
	var scaled     = board_size * board.scale
	board.position    = (vp_size - scaled) / 2.0
	board_bg.position = board.position
	board_bg.size     = scaled

	# Place level badge below the board, centered on the grid.
	var level_y = board.position.y + scaled.y + 14.0
	var level_x = board.position.x + (scaled.x - level_bg.size.x) * 0.5
	level_bg.position = Vector2(level_x, level_y)
	level_label.position = level_bg.position

# ============================================================
#  BOARD SIGNALS
# ============================================================

func _on_score_gained(points):
	total_score += points
	score_label.text = "Score: " + str(total_score)
	if points > 0:
		match_sfx.play()

func _on_moves_used(remaining):
	moves_label.text = "Moves: " + str(remaining)

func _on_message(t):
	message_label.text = t

func _on_hint_classic_pressed():
	if not board.can_pay_hint_cost(1):
		message_label.text = "Not enough moves for Classic Hint."
		return
	if not board.show_classic_hint():
		message_label.text = "No classic hint found."
		return
	board.pay_hint_cost(1)
	message_label.text = "Classic hint shown. -1 move"

func _on_hint_best_pressed():
	if not board.can_pay_hint_cost(5):
		message_label.text = "Not enough moves for Best Hint."
		return
	var hint = board.show_best_hint()
	if hint.is_empty():
		message_label.text = "No best hint found."
		return
	board.pay_hint_cost(5)
	var score = int(hint.get("score", 0))
	message_label.text = "Best hint shown (-5 moves, score: " + str(score) + ")."

# ============================================================
#  UI SETUP
# ============================================================

func _setup_ui():
	score_label.visible   = true;  score_label.z_index   = 100
	moves_label.visible   = true;  moves_label.z_index   = 100
	goal_label.visible    = true;  goal_label.z_index    = 100
	message_label.visible = true;  message_label.z_index = 100

	hint_classic_button.pressed.connect(_on_hint_classic_pressed)
	hint_best_button.pressed.connect(_on_hint_best_pressed)
	restart_button.pressed.connect(_ask_full_reset_confirm)
	menu_button.pressed.connect(_on_menu_pressed)

	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_pressed)

	pause_ui.visible           = false
	pause_ui.process_mode      = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	quit_button.process_mode   = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_menu_pressed)

	end_ui.visible               = false
	end_ui.process_mode          = Node.PROCESS_MODE_WHEN_PAUSED
	win_sfx.process_mode         = Node.PROCESS_MODE_ALWAYS
	lose_sfx.process_mode        = Node.PROCESS_MODE_ALWAYS
	end_next_button.process_mode    = Node.PROCESS_MODE_WHEN_PAUSED
	end_restart_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	end_menu_button.process_mode    = Node.PROCESS_MODE_WHEN_PAUSED
	end_next_button.pressed.connect(_on_end_next_pressed)
	# ← Restart from end screen hides end_ui FIRST, then asks confirm
	end_restart_button.pressed.connect(_ask_full_reset_from_end)
	end_menu_button.pressed.connect(_on_menu_pressed)

	_build_confirm_dialog()

# ── HUD: player name + AI difficulty indicator ──────────────
func _update_name_in_hud():
	var hud = $UI/HUD

	# Player name label
	if _name_label_hud == null:
		_name_label_hud = Label.new()
		_name_label_hud.add_theme_font_size_override("font_size", 15)
		_name_label_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		_name_label_hud.z_index  = 100
		_name_label_hud.position = Vector2(10, 215)
		hud.add_child(_name_label_hud)

	_name_label_hud.text = "👤 " + GameState.player_name

	# AI difficulty label — so the player can SEE it changing
	if _diff_label_hud == null:
		_diff_label_hud = Label.new()
		_diff_label_hud.add_theme_font_size_override("font_size", 13)
		_diff_label_hud.z_index  = 100
		_diff_label_hud.position = Vector2(10, 240)
		hud.add_child(_diff_label_hud)

	_update_diff_label()

func _update_diff_label():
	if _diff_label_hud == null or adaptive == null:
		return
	var label   = adaptive.get_label()
	var pct     = adaptive.get_difficulty_percent()
	# _diff_label_hud.text = "KI: " + label + " (" + str(pct) + "%)", we don't need this label.
	# Color the label: green=easy, yellow=medium, red=hard
	var d = adaptive.compute_difficulty_score()
	if   d < 0.4:  _diff_label_hud.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	elif d < 0.65: _diff_label_hud.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:          _diff_label_hud.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

# ============================================================
#  RESTART CONFIRMATION
#  FIX: when called from end_ui, hide end_ui first so the
#  confirm dialog is never hidden behind it.
# ============================================================

func _build_confirm_dialog():
	var vp = get_viewport_rect().size

	_confirm_layer              = CanvasLayer.new()
	_confirm_layer.name         = "ConfirmLayer"
	_confirm_layer.visible      = false
	_confirm_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	# ── KEY FIX: layer 20 is always above end_ui (which uses default layer 1) ──
	_confirm_layer.layer        = 20
	add_child(_confirm_layer)

	var backdrop           = ColorRect.new()
	backdrop.color         = Color(0, 0, 0, 0.65)
	backdrop.size          = vp
	backdrop.mouse_filter  = Control.MOUSE_FILTER_STOP
	_confirm_layer.add_child(backdrop)

	var card               = PanelContainer.new()
	card.size              = Vector2(420, 240)
	card.position          = vp / 2.0 - card.size / 2.0
	_confirm_layer.add_child(card)

	var vbox               = VBoxContainer.new()
	vbox.alignment         = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon_lbl           = Label.new()
	icon_lbl.text          = "⚠️"
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_lbl)

	_add_spacer(vbox, 6)

	var title_lbl          = Label.new()
	title_lbl.text         = "Spiel komplett zurücksetzen?"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	_add_spacer(vbox, 4)

	var sub_lbl            = Label.new()
	sub_lbl.text           = "Alle Fortschritte & dein Profil werden gelöscht."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))
	vbox.add_child(sub_lbl)

	_add_spacer(vbox, 18)

	var hbox               = HBoxContainer.new()
	hbox.alignment         = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var btn_yes            = Button.new()
	btn_yes.text           = "✅  Ja, Neustart"
	btn_yes.custom_minimum_size = Vector2(155, 48)
	btn_yes.add_theme_font_size_override("font_size", 16)
	btn_yes.process_mode   = Node.PROCESS_MODE_ALWAYS
	hbox.add_child(btn_yes)

	_add_spacer_h(hbox, 18)

	var btn_no             = Button.new()
	btn_no.text            = "❌  Abbrechen"
	btn_no.custom_minimum_size = Vector2(135, 48)
	btn_no.add_theme_font_size_override("font_size", 16)
	btn_no.process_mode    = Node.PROCESS_MODE_ALWAYS
	hbox.add_child(btn_no)

	btn_yes.pressed.connect(func():
		_confirm_layer.visible = false
		get_tree().paused      = false
		_do_full_reset()
	)
	btn_no.pressed.connect(func():
		_confirm_layer.visible = false
		get_tree().paused      = false
	)

# Called from the in-game restart button
func _ask_full_reset_confirm():
	get_tree().paused      = true
	_confirm_layer.visible = true

# Called from end_ui restart button — hides end_ui first!
func _ask_full_reset_from_end():
	end_ui.visible         = false   # ← hide the menu panel first
	get_tree().paused      = true
	_confirm_layer.visible = true

# ── Full reset: delete saves, reset everything, show welcome ─
func _do_full_reset():
	if FileAccess.file_exists("user://save.cfg"):
		DirAccess.remove_absolute("user://save.cfg")
	if FileAccess.file_exists("user://save_game.json"):
		DirAccess.remove_absolute("user://save_game.json")

	GameState.current_level_index = 0
	GameState.player_name         = ""
	GameState.player_profile      = {
		"win_rate":            0.5,
		"avg_moves_ratio":     0.7,
		"hint_usage_rate":     0.3,
		"consecutive_wins":    0,
		"consecutive_losses":  0,
		"total_sessions":      0,
	}

	total_score      = 0
	hints_used_count = 0
	moves_at_start   = 0

	gameplay_music.stop()
	end_ui.visible = false

	if _name_label_hud != null:
		_name_label_hud.queue_free()
		_name_label_hud = null
	if _diff_label_hud != null:
		_diff_label_hud.queue_free()
		_diff_label_hud = null

	_show_welcome_screen()

# ============================================================
#  SCREEN FLASH
# ============================================================

func _create_flash_overlay():
	_flash_overlay              = ColorRect.new()
	_flash_overlay.color        = Color(1, 1, 1, 0)
	_flash_overlay.size         = get_viewport_rect().size
	_flash_overlay.position     = Vector2.ZERO
	_flash_overlay.z_index      = 300
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_overlay)

func _on_big_match(count, _center_pos):
	var flash_col
	if   count >= 7: flash_col = Color(1.0, 0.3, 0.9, 0.55)
	elif count >= 6: flash_col = Color(1.0, 0.6, 0.0, 0.45)
	elif count >= 5: flash_col = Color(0.3, 0.9, 1.0, 0.38)
	else:            flash_col = Color(1.0, 1.0, 0.3, 0.30)
	_flash_overlay.color = flash_col
	var t = create_tween()
	t.tween_property(_flash_overlay, "color:a", 0.0, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ============================================================
#  LEVEL START
# ============================================================

func _start_level():
	total_score      = 0
	hints_used_count = 0

	var level_index  = GameState.get_current_level_index()
	var base_level   = GameState.get_current_level()
	var final_moves  = int(base_level["moves"])
	var final_target = int(base_level["target"])
	var hint_delay   = 10.0

	if adaptive != null:
		var params   = adaptive.get_adapted_level(base_level)
		final_moves  = int(params["moves"])
		final_target = int(params["target"])
		hint_delay   = float(params["hint_delay"])
		# Update the HUD difficulty indicator
		_update_diff_label()

	board.configure(final_moves, final_target)
	board.new_game()

	if board.hint_timer != null:
		board.hint_timer.wait_time = hint_delay

	moves_at_start   = final_moves

	level_label.text = "Level " + str(level_index + 1)
	goal_label.text  = "Goal: "  + str(board.target_score)
	score_label.text = "Score: 0"
	moves_label.text = "Moves: " + str(board.start_moves)

	var name = GameState.player_name
	message_label.text = ("Viel Glück, " + name + "! 🍭") if name != "" else "Match 3+ to score!"

# ============================================================
#  HINT
# ============================================================

func _on_hint_pressed():
	if not board.show_hint():
		message_label.text = "Kein Hinweis gefunden."
		return
	hints_used_count  += 1
	message_label.text = "Hinweis angezeigt."

# ============================================================
#  GAME OVER
# ============================================================

func _on_game_over(won):
	gameplay_music.stop()

	var moves_used = moves_at_start - board.moves_left
	GameState.record_level_result(won, moves_used, moves_at_start, hints_used_count)

	SaveSystem.new().save_game({
		"current_level": GameState.current_level_index,
		"total_score":   total_score,
	})

	var name = GameState.player_name if GameState.player_name != "" else "Spieler"

	if won:
		var has_next = GameState.has_next_level()
		if has_next:
			end_title.text             = "🎉 Super, " + name + "!"
			end_next_button.visible    = true
			end_next_button.text       = "Nächstes Level ▶"
			end_restart_button.visible = true
			end_restart_button.text    = "Neu starten 🔄"
			end_menu_button.visible    = true
			end_menu_button.text       = "Menü"
			end_icon.texture           = load("res://assets/DesignAsset/GameIcon/stars-stack.png")
			end_icon.modulate          = Color(0.2, 0.85, 0.35, 1)
			var sfx = load("res://assets/sounds/GameSound/Succes Sound/mixkit-game-level-completed-2059.wav")
			if sfx != null: win_sfx.stream = sfx
		else:
			end_title.text             = "🏆 Champion, " + name + "!"
			end_next_button.visible    = false
			end_restart_button.visible = false
			end_menu_button.visible    = true
			end_menu_button.text       = "Hauptmenü"
			end_icon.texture           = load("res://assets/DesignAsset/GameIcon/trophy-cup.png")
			end_icon.modulate          = Color(0.2, 0.85, 0.35, 1)
			var sfx2 = load("res://assets/sounds/GameSound/Succes Sound/mixkit-game-level-music-689-pcm.wav")
			if sfx2 != null: win_sfx.stream = sfx2
		win_sfx.play()
	else:
		end_title.text             = "😢 Nicht aufgeben, " + name + "!"
		end_next_button.visible    = false
		end_restart_button.visible = true
		end_restart_button.text    = "Neu starten 🔄"
		end_menu_button.visible    = true
		end_menu_button.text       = "Menü"
		end_icon.texture           = load("res://assets/DesignAsset/GameIcon/broken-heart.png")
		end_icon.modulate          = Color(0.95, 0.2, 0.2, 1)
		lose_sfx.play()

	end_score.text    = name + "'s Punkte:  " + str(total_score)
	get_tree().paused = true
	end_ui.visible    = true
	_play_end_animation(won)

func _play_end_animation(won):
	await get_tree().process_frame
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale        = Vector2(0.7, 0.7)
	end_panel.modulate.a   = 0.0
	end_title.add_theme_color_override("font_color",
		Color(0.2, 0.85, 0.35) if won else Color(0.95, 0.2, 0.2))
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(end_panel, "modulate:a", 1.0,                 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "scale",      Vector2(1.05, 1.05), 0.50).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "scale",      Vector2(1.0,  1.0),  0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ============================================================
#  NAVIGATION
# ============================================================

func _on_end_next_pressed():
	get_tree().paused = false
	end_ui.visible    = false
	GameState.advance_level()
	gameplay_music.play()
	_start_level()

func _on_menu_pressed():
	get_tree().paused = false
	end_ui.visible    = false
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _on_pause_pressed():
	if pause_ui.visible:
		get_tree().paused = false
		pause_ui.visible  = false
	else:
		get_tree().paused = true
		pause_ui.visible  = true

func _on_resume_pressed():
	get_tree().paused = false
	pause_ui.visible  = false
