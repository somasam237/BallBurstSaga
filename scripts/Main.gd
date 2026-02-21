extends Node2D

# ============================================================
#  MAIN.GD  – Ball Burst Saga
#  RESTART = reset EVERYTHING: level 1, delete saves,
#  clear player name, show welcome screen again.
# ============================================================

@onready var board              = $Board
@onready var background         = $Background
@onready var board_bg           = $BoardBG
@onready var score_label        = $UI/HUD/ScoreLabel
@onready var moves_label        = $UI/HUD/MovesLabel
@onready var goal_label         = $UI/HUD/GoalLabel
@onready var hint_button        = $UI/HUD/HintButton
@onready var restart_button     = $UI/HUD/RestartButton
@onready var menu_button        = $UI/HUD/MenuButton
@onready var pause_button       = $UI/HUD/PauseButton
@onready var message_label      = $UI/HUD/MessageLabel
@onready var level_label        = $UI/HUD/LevelLabel
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

# ============================================================
#  WELCOME SCREEN
# ============================================================

func _show_welcome_screen():
	var vp = get_viewport_rect().size

	_welcome_layer              = CanvasLayer.new()
	_welcome_layer.name         = "WelcomeLayer"
	_welcome_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_welcome_layer)

	var bg            = ColorRect.new()
	bg.color          = Color(0.96, 0.60, 0.78, 1.0)
	bg.size           = vp
	_welcome_layer.add_child(bg)

	var top_strip     = ColorRect.new()
	top_strip.color   = Color(0.55, 0.85, 0.60, 1.0)
	top_strip.size    = Vector2(vp.x, 12)
	_welcome_layer.add_child(top_strip)

	var bot_strip     = ColorRect.new()
	bot_strip.color   = Color(0.55, 0.85, 0.60, 1.0)
	bot_strip.size    = Vector2(vp.x, 12)
	bot_strip.position = Vector2(0, vp.y - 12)
	_welcome_layer.add_child(bot_strip)

	var card          = PanelContainer.new()
	var card_w        = min(560.0, vp.x - 40)
	card.size         = Vector2(card_w, 500.0)
	card.position     = vp / 2.0 - card.size / 2.0
	_welcome_layer.add_child(card)

	var vbox          = VBoxContainer.new()
	vbox.alignment    = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var logo          = Label.new()
	logo.text         = "🍭 Ball Burst Saga 🍭"
	logo.add_theme_font_size_override("font_size", 30)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_color", Color(0.2, 0.55, 0.95))
	vbox.add_child(logo)

	_add_spacer(vbox, 6)

	var sub           = Label.new()
	sub.text          = "Das bunte Match-3-Abenteuer!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	vbox.add_child(sub)

	_add_spacer(vbox, 12)
	vbox.add_child(HSeparator.new())
	_add_spacer(vbox, 10)

	var name_lbl      = Label.new()
	name_lbl.text     = "Wie heißt du? Gib deinen Spitznamen ein:"
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	_add_spacer(vbox, 8)

	var name_input    = LineEdit.new()
	name_input.placeholder_text = "Dein Spitzname…"
	name_input.max_length       = 20
	name_input.custom_minimum_size = Vector2(280, 44)
	name_input.alignment        = HORIZONTAL_ALIGNMENT_CENTER
	name_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_input)

	_add_spacer(vbox, 14)
	vbox.add_child(HSeparator.new())
	_add_spacer(vbox, 8)

	var how_title     = Label.new()
	how_title.text    = "📖 Spielanleitung"
	how_title.add_theme_font_size_override("font_size", 17)
	how_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how_title.add_theme_color_override("font_color", Color(0.2, 0.55, 0.95))
	vbox.add_child(how_title)

	_add_spacer(vbox, 6)

	var how_text      = Label.new()
	how_text.text     = (
		"🔵  Klicke eine Kugel, dann eine benachbarte Kugel zum Tauschen.\n" +
		"✨  Gleiche 3+ Kugeln gleicher Farbe ab, um Punkte zu sammeln!\n" +
		"💥  4+ Kugeln = spektakulärer Explosions-Bonus!\n" +
		"🏆  Erreiche das Ziel, bevor deine Züge aufgebraucht sind.\n" +
		"💡  Nicht weiter? Drücke ?, um einen Hinweis zu bekommen."
	)
	how_text.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	how_text.custom_minimum_size = Vector2(card_w - 40, 0)
	how_text.add_theme_font_size_override("font_size", 14)
	vbox.add_child(how_text)

	_add_spacer(vbox, 16)

	var play_btn      = Button.new()
	play_btn.text     = "🎮  Los geht's!"
	play_btn.custom_minimum_size = Vector2(200, 52)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(play_btn)

	play_btn.pressed.connect(func():
		var raw_name = name_input.text.strip_edges()
		if raw_name == "":
			raw_name = "Player"
		GameState.player_name = raw_name
		GameState._save_progress()
		var t = create_tween()
		t.tween_property(card, "modulate:a", 0.0, 0.3)
		t.tween_property(bg,   "modulate:a", 0.0, 0.3)
		t.tween_callback(func():
			_welcome_layer.queue_free()
			_welcome_layer = null
			_begin_game()
		)
	)

	name_input.text_submitted.connect(func(_txt): play_btn.emit_signal("pressed"))

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
	var board_size = Vector2(float(board.width) * float(board.cell_size),
							 float(board.height) * float(board.cell_size))
	var scaled     = board_size * board.scale
	board.position    = (vp_size - scaled) / 2.0
	board_bg.position = board.position
	board_bg.size     = scaled

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

# ============================================================
#  UI SETUP
# ============================================================

func _setup_ui():
	score_label.visible   = true;  score_label.z_index   = 100
	moves_label.visible   = true;  moves_label.z_index   = 100
	goal_label.visible    = true;  goal_label.z_index    = 100
	message_label.visible = true;  message_label.z_index = 100

	hint_button.pressed.connect(_on_hint_pressed)
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
	end_restart_button.pressed.connect(_ask_full_reset_confirm)
	end_menu_button.pressed.connect(_on_menu_pressed)

	_build_confirm_dialog()

func _update_name_in_hud():
	if _name_label_hud != null:
		_name_label_hud.text = "👤 " + GameState.player_name
		return
	var hud = $UI/HUD
	_name_label_hud = Label.new()
	_name_label_hud.text = "👤 " + GameState.player_name
	_name_label_hud.add_theme_font_size_override("font_size", 15)
	_name_label_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_name_label_hud.z_index  = 100
	_name_label_hud.position = Vector2(10, 230)
	hud.add_child(_name_label_hud)

# ============================================================
#  FULL GAME RESET CONFIRMATION
#  Restart = wipe EVERYTHING: saves, name, level, profile
# ============================================================

func _build_confirm_dialog():
	var vp = get_viewport_rect().size

	_confirm_layer              = CanvasLayer.new()
	_confirm_layer.name         = "ConfirmLayer"
	_confirm_layer.visible      = false
	_confirm_layer.process_mode = Node.PROCESS_MODE_ALWAYS
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
	sub_lbl.text           = "Alle Fortschritte, dein Name und\ndein Profil werden gelöscht."
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

func _ask_full_reset_confirm():
	get_tree().paused      = true
	_confirm_layer.visible = true

# ── Full reset: wipe saves, reset GameState, show welcome again ──
func _do_full_reset():
	# 1. Delete both save files
	if FileAccess.file_exists("user://save.cfg"):
		DirAccess.remove_absolute("user://save.cfg")
	if FileAccess.file_exists("user://save_game.json"):
		DirAccess.remove_absolute("user://save_game.json")

	# 2. Reset GameState completely to defaults
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

	# 3. Reset local tracking
	total_score      = 0
	hints_used_count = 0
	moves_at_start   = 0

	# 4. Stop music, hide any open panels
	gameplay_music.stop()
	end_ui.visible = false

	# 5. Remove the name label from HUD
	if _name_label_hud != null:
		_name_label_hud.queue_free()
		_name_label_hud = null

	# 6. Show welcome screen so player enters a new name
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
