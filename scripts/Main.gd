 
extends Node2D

@onready var board: Board = $Board
@onready var background: Sprite2D = $Background
@onready var board_bg: Panel = $BoardBG
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var moves_label: Label = $UI/HUD/MovesLabel
@onready var goal_label: Label = $UI/HUD/GoalLabel
@onready var hint_button: BaseButton = $UI/HUD/HintButton
@onready var restart_button: BaseButton = $UI/HUD/RestartButton
@onready var menu_button: BaseButton = $UI/HUD/MenuButton
@onready var pause_button: BaseButton = $UI/HUD/PauseButton
@onready var message_label: Label = $UI/HUD/MessageLabel
@onready var level_label: Label = $UI/HUD/LevelLabel
@onready var gameplay_music: AudioStreamPlayer = $GameplayMusic
@onready var match_sfx: AudioStreamPlayer = $MatchSfx
@onready var pause_ui: CanvasLayer = $PauseUI
@onready var resume_button: Button = $PauseUI/PausePanel/PauseVBox/ResumeButton
@onready var quit_button: Button = $PauseUI/PausePanel/PauseVBox/QuitButton
@onready var end_ui: CanvasLayer = $EndUI
@onready var end_panel: Panel = $EndUI/EndPanel
@onready var end_icon: TextureRect = $EndUI/EndPanel/EndVBox/EndIcon
@onready var end_title: Label = $EndUI/EndPanel/EndVBox/EndTitle
@onready var end_score: Label = $EndUI/EndPanel/EndVBox/EndScore
@onready var end_next_button: Button = $EndUI/EndPanel/EndVBox/EndNextButton
@onready var end_restart_button: Button = $EndUI/EndPanel/EndVBox/EndRestartButton
@onready var end_menu_button: Button = $EndUI/EndPanel/EndVBox/EndMenuButton
@onready var win_sfx: AudioStreamPlayer = $WinSfx
@onready var lose_sfx: AudioStreamPlayer = $LoseSfx

var total_score: int = 0

func _ready() -> void:
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

	_setup_ui()
	_start_level()

func _fit_background() -> void:
	var viewport_size := get_viewport_rect().size
	var tex := background.texture
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor: float = max(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	background.scale = Vector2(scale_factor, scale_factor)
	background.position = viewport_size * 0.5

func _center_board() -> void:
	var viewport_size := get_viewport_rect().size
	var board_size := Vector2(board.width, board.height) * board.cell_size
	var scaled_size := Vector2(board_size.x * board.scale.x, board_size.y * board.scale.y)
	board.position = (viewport_size - scaled_size) / 2.0
	board_bg.position = board.position
	board_bg.size = scaled_size

func _on_score_gained(points: int) -> void:
	total_score += points
	score_label.text = "Score: " + str(total_score)
	if points > 0:
		match_sfx.play()

func _on_moves_used(remaining: int) -> void:
	moves_label.text = "Moves: " + str(remaining)

func _on_message(t: String) -> void:
	message_label.text = t

func _on_hint_pressed() -> void:
	if not board.show_hint():
		message_label.text = "No hints found."
		return
	message_label.text = "Hint shown."

func _setup_ui() -> void:
	score_label.visible = true
	score_label.z_index = 100

	moves_label.visible = true
	moves_label.z_index = 100

	goal_label.visible = true
	goal_label.z_index = 100

	message_label.visible = true
	message_label.z_index = 100
	hint_button.pressed.connect(_on_hint_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_pressed)

	pause_ui.visible = false
	pause_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	quit_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_menu_pressed)

	end_ui.visible = false
	end_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	win_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	lose_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	end_next_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	end_restart_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	end_menu_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	end_next_button.pressed.connect(_on_end_next_pressed)
	end_restart_button.pressed.connect(_on_restart_pressed)
	end_menu_button.pressed.connect(_on_menu_pressed)

func _start_level() -> void:
	total_score = 0
	var level := GameState.get_current_level()
	board.configure(level["moves"], level["target"])
	board.new_game()

	level_label.text = "Level " + str(GameState.get_current_level_index() + 1)
	goal_label.text = "Goal: " + str(board.target_score)
	score_label.text = "Score: 0"
	moves_label.text = "Moves: " + str(board.start_moves)
	message_label.text = "Level " + str(GameState.current_level_index + 1)

func _on_game_over(won: bool) -> void:
	gameplay_music.stop()
	if won:
		var has_next := GameState.has_next_level()
		if has_next:
			end_title.text = "Level Complete!"
			end_next_button.visible = true
			end_next_button.text = "Next Level"
			end_restart_button.visible = true
			end_restart_button.text = "Replay Level"
			end_menu_button.visible = true
			end_menu_button.text = "Menu"
			end_icon.texture = load("res://assets/DesignAsset/GameIcon/stars-stack.png")
			end_icon.modulate = Color(0.2, 0.85, 0.35, 1)
			var win_level_sfx: AudioStream = load("res://assets/sounds/GameSound/Succes Sound/mixkit-game-level-completed-2059.wav")
			if win_level_sfx != null:
				win_sfx.stream = win_level_sfx
		else:
			end_title.text = "All Levels Complete!"
			end_next_button.visible = false
			end_restart_button.visible = false
			end_menu_button.visible = true
			end_menu_button.text = "Main Menu"
			end_icon.texture = load("res://assets/DesignAsset/GameIcon/trophy-cup.png")
			end_icon.modulate = Color(0.2, 0.85, 0.35, 1)
			var final_sfx: AudioStream = load("res://assets/sounds/GameSound/Succes Sound/mixkit-game-level-music-689-pcm.wav")
			if final_sfx != null:
				win_sfx.stream = final_sfx
		win_sfx.play()
	else:
		end_title.text = "Try Again"
		end_next_button.visible = false
		end_restart_button.visible = true
		end_restart_button.text = "Retry Level"
		end_menu_button.visible = true
		end_menu_button.text = "Menu"
		end_icon.texture = load("res://assets/DesignAsset/GameIcon/broken-heart.png")
		end_icon.modulate = Color(0.95, 0.2, 0.2, 1)
		lose_sfx.play()
	end_score.text = "Score: " + str(total_score)
	get_tree().paused = true
	end_ui.visible = true
	_play_end_animation(won)

func _play_end_animation(won: bool) -> void:
	await get_tree().process_frame
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale = Vector2(0.7, 0.7)
	end_panel.modulate.a = 0.0
	end_title.add_theme_color_override("font_color", Color(0.2, 0.85, 0.35) if won else Color(0.95, 0.2, 0.2))

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(end_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_end_next_pressed() -> void:
	get_tree().paused = false
	end_ui.visible = false
	GameState.advance_level()
	gameplay_music.play()
	_start_level()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	end_ui.visible = false
	gameplay_music.play()
	_start_level()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	end_ui.visible = false
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _on_pause_pressed() -> void:
	if pause_ui.visible:
		get_tree().paused = false
		pause_ui.visible = false
	else:
		get_tree().paused = true
		pause_ui.visible = true

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_ui.visible = false
