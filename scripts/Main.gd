extends Node2D

# ============================================================
#  MAIN.GD
#  Changes vs original:
#   – Calls AdaptiveDifficulty.get_adapted_level() at level start
#     so moves, target score, and hint delay are adjusted by the AI.
#   – Tracks hints_used_count each level.
#   – Calls GameState.record_level_result() when a level ends
#     so the AI profile is updated for next time.
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

# AdaptiveDifficulty node – fetched safely in _ready().
# If you forget to add it to the scene the game still works normally.
var adaptive = null

# ── Per-level tracking ──────────────────────────────────────
var total_score      = 0
var hints_used_count = 0   # incremented each time Hint is pressed
var moves_at_start   = 0   # moves budget given at level start

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready():
	# Safely grab AdaptiveDifficulty – won't crash if node is missing
	if has_node("AdaptiveDifficulty"):
		adaptive = $AdaptiveDifficulty

	GameState.load_progress()
	_fit_background()
	board.scale = Vector2(1.2, 1.2)
	_center_board()

	board.score_gained.connect(_on_score_gained)
	board.moves_used.connect(_on_moves_used)
	board.message.connect(_on_message)
	board.game_over.connect(_on_game_over)

	if gameplay_music.stream is AudioStreamMP3:
		gameplay_music.stream.loop = true
	elif gameplay_music.stream is AudioStreamOggVorbis:
		gameplay_music.stream.loop = true
	gameplay_music.play()
	
	var save_data := SaveSystem.new().load_game()

	if save_data.has("current_level"):
		GameState.current_level_index = save_data["current_level"]
	
	if save_data.has("total_score"):
		total_score = save_data["total_score"]

	if save_data.has("player_skill"):
		adaptive.player_skill = save_data["player_skill"]


	_setup_ui()
	_start_level()

# ============================================================
#  LAYOUT
# ============================================================

func _fit_background():
	var vp_size = get_viewport_rect().size
	var tex     = background.texture
	if tex == null:
		return
	var tex_size = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_f = max(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	background.scale    = Vector2(scale_f, scale_f)
	background.position = vp_size * 0.5

func _center_board():
	var vp_size    = get_viewport_rect().size
	# Convert int exports to float explicitly to avoid type errors
	var bw         = float(board.width)
	var bh         = float(board.height)
	var cs         = float(board.cell_size)
	var board_size = Vector2(bw * cs, bh * cs)
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
	restart_button.pressed.connect(_on_restart_pressed)
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
	end_restart_button.pressed.connect(_on_restart_pressed)
	end_menu_button.pressed.connect(_on_menu_pressed)

# ============================================================
#  LEVEL START  ←  where the AI does its work
# ============================================================

func _start_level():
	total_score      = 0
	hints_used_count = 0

	var level_index = GameState.get_current_level_index()
	var base_level  = GameState.get_current_level()

	# Start with raw values in case AdaptiveDifficulty is absent
	var final_moves  = int(base_level["moves"])
	var final_target = int(base_level["target"])
	var hint_delay   = 10.0

	# ── Apply AI adjustments ─────────────────────────────────
	if adaptive != null:
		var params   = adaptive.get_adapted_level(base_level)
		final_moves  = int(params["moves"])
		final_target = int(params["target"])
		hint_delay   = float(params["hint_delay"])
		# Optional: show difficulty label for 2 seconds
		message_label.text = "Difficulty: " + adaptive.get_label()

	# Give the board its (possibly adjusted) values
	board.configure(final_moves, final_target)
	board.new_game()

	# Tell the board's auto-hint timer how long to wait
	if board.hint_timer != null:
		board.hint_timer.wait_time = hint_delay

	# Remember the budget so we can compute moves_used at game-over
	moves_at_start = final_moves

	# Update HUD
	level_label.text = "Level " + str(level_index + 1)
	goal_label.text  = "Goal: "  + str(board.target_score)
	score_label.text = "Score: 0"
	moves_label.text = "Moves: " + str(board.start_moves)

# ============================================================
#  HINT  –  count every press for the AI
# ============================================================

func _on_hint_pressed():
	if not board.show_hint():
		message_label.text = "No hints found."
		return
	hints_used_count  += 1
	message_label.text = "Hint shown."

# ============================================================
#  GAME OVER  –  feed result back into AI profile
# ============================================================

func _on_game_over(won):
	gameplay_music.stop()

	# How many moves did the player actually use?
	var moves_used = moves_at_start - board.moves_left

	# Update the AI player profile (saved to disk automatically)
	GameState.record_level_result(won, moves_used, moves_at_start, hints_used_count)

	# ── Build End UI ─────────────────────────────────────────
	if won:
		var has_next = GameState.has_next_level()
		if has_next:
			end_title.text             = "Level Complete!"
			end_next_button.visible    = true
			end_next_button.text       = "Next Level"
			end_restart_button.visible = true
			end_restart_button.text    = "Replay Level"
			end_menu_button.visible    = true
			end_menu_button.text       = "Menu"
			end_icon.texture           = load("res://assets/DesignAsset/GameIcon/stars-stack.png")
			end_icon.modulate          = Color(0.2, 0.85, 0.35, 1)
			var win_level_sfx = load("res://assets/sounds/GameSound/Succes Sound/mixkit-game-level-completed-2059.wav")
			if win_level_sfx != null:
				win_sfx.stream = win_level_sfx
		else:
			end_title.text             = "All Levels Complete!"
			end_next_button.visible    = false
			end_restart_button.visible = false
			end_menu_button.visible    = true
			end_menu_button.text       = "Main Menu"
			end_icon.texture           = load("res://assets/DesignAsset/GameIcon/trophy-cup.png")
			end_icon.modulate          = Color(0.2, 0.85, 0.35, 1)
			var final_sfx = load("res://assets/sounds/GameSound/Succes Sound/mixkit-game-level-music-689-pcm.wav")
			if final_sfx != null:
				win_sfx.stream = final_sfx
		win_sfx.play()
	else:
		end_title.text             = "Try Again"
		end_next_button.visible    = false
		end_restart_button.visible = true
		end_restart_button.text    = "Retry Level"
		end_menu_button.visible    = true
		end_menu_button.text       = "Menu"
		end_icon.texture           = load("res://assets/DesignAsset/GameIcon/broken-heart.png")
		end_icon.modulate          = Color(0.95, 0.2, 0.2, 1)
		lose_sfx.play()

	end_score.text    = "Score: " + str(total_score)
	get_tree().paused = true
	end_ui.visible    = true
	
	_play_end_animation(won)
	var save_data: Dictionary = {
		"current_level": GameState.current_level_index,
		"total_score": total_score,
		"player_skill": adaptive.player_skill
	}

	SaveSystem.new().save_game(save_data)


func _play_end_animation(won):
	await get_tree().process_frame
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale        = Vector2(0.7, 0.7)
	end_panel.modulate.a   = 0.0
	end_title.add_theme_color_override(
		"font_color",
		Color(0.2, 0.85, 0.35) if won else Color(0.95, 0.2, 0.2))
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(end_panel, "modulate:a", 1.0,                 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "scale",      Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "scale",      Vector2(1.0, 1.0),   0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ============================================================
#  NAVIGATION
# ============================================================

func _on_end_next_pressed():
	get_tree().paused = false
	end_ui.visible    = false
	GameState.advance_level()
	gameplay_music.play()
	_start_level()

func _on_restart_pressed():
	get_tree().paused = false
	end_ui.visible    = false
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
