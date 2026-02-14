 
extends Node2D

@onready var board: Board = $Board
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var moves_label: Label = $UI/HUD/MovesLabel
@onready var goal_label: Label = $UI/HUD/GoalLabel
@onready var hint_button: Button = $UI/HUD/HintButton
@onready var restart_button: Button = $UI/HUD/RestartButton
@onready var menu_button: Button = $UI/HUD/MenuButton
@onready var pause_button: Button = $UI/HUD/PauseButton
@onready var message_label: Label = $UI/HUD/MessageLabel
@onready var pause_ui: CanvasLayer = $PauseUI
@onready var resume_button: Button = $PauseUI/PausePanel/PauseVBox/ResumeButton
@onready var quit_button: Button = $PauseUI/PausePanel/PauseVBox/QuitButton
@onready var end_ui: CanvasLayer = $EndUI
@onready var end_title: Label = $EndUI/EndPanel/EndVBox/EndTitle
@onready var end_score: Label = $EndUI/EndPanel/EndVBox/EndScore
@onready var end_next_button: Button = $EndUI/EndPanel/EndVBox/EndNextButton
@onready var end_restart_button: Button = $EndUI/EndPanel/EndVBox/EndRestartButton
@onready var end_menu_button: Button = $EndUI/EndPanel/EndVBox/EndMenuButton

var total_score: int = 0

func _ready() -> void:
	board.scale = Vector2(1.2, 1.2)
	_center_board()

	board.score_gained.connect(_on_score_gained)
	board.moves_used.connect(_on_moves_used)
	board.message.connect(_on_message)
	board.game_over.connect(_on_game_over)

	_setup_ui()
	_start_level()

func _center_board() -> void:
	var viewport_size := get_viewport_rect().size
	var board_size := Vector2(board.width, board.height) * board.cell_size
	var scaled_size := Vector2(board_size.x * board.scale.x, board_size.y * board.scale.y)
	board.position = (viewport_size - scaled_size) / 2.0

func _on_score_gained(points: int) -> void:
	total_score += points
	score_label.text = "Score: " + str(total_score)

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
	score_label.position = Vector2(12, 10)
	score_label.size = Vector2(220, 20)
	score_label.visible = true
	score_label.z_index = 100
	score_label.add_theme_color_override("font_color", Color(1, 1, 1))
	moves_label.position = Vector2(12, 34)
	moves_label.size = Vector2(220, 20)
	moves_label.visible = true
	moves_label.z_index = 100
	moves_label.add_theme_color_override("font_color", Color(1, 1, 1))
	goal_label.position = Vector2(12, 58)
	goal_label.size = Vector2(220, 20)
	goal_label.visible = true
	goal_label.z_index = 100
	goal_label.add_theme_color_override("font_color", Color(1, 1, 1))
	message_label.position = Vector2(12, 82)
	message_label.size = Vector2(260, 20)
	message_label.visible = true
	message_label.z_index = 100
	message_label.add_theme_color_override("font_color", Color(1, 1, 1))

	hint_button.text = "Hint"
	hint_button.position = Vector2(12, 110)
	hint_button.pressed.connect(_on_hint_pressed)

	restart_button.text = "Restart"
	restart_button.position = Vector2(12, 140)
	restart_button.pressed.connect(_on_restart_pressed)

	menu_button.text = "Menu"
	menu_button.position = Vector2(12, 170)
	menu_button.pressed.connect(_on_menu_pressed)

	pause_button.text = "Options"
	pause_button.position = Vector2(12, 200)
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

	goal_label.text = "Goal: " + str(board.target_score)
	score_label.text = "Score: 0"
	moves_label.text = "Moves: " + str(board.start_moves)
	message_label.text = "Level " + str(GameState.current_level_index + 1)

func _on_game_over(won: bool) -> void:
	if won:
		if GameState.has_next_level():
			GameState.advance_level()
			end_title.text = "Victoire !"
			end_next_button.visible = true
		else:
			end_title.text = "Victoire !"
			end_next_button.visible = false
	else:
		end_title.text = "Defaite"
		end_next_button.visible = false
	end_score.text = "Score: " + str(total_score)
	get_tree().paused = true
	end_ui.visible = true

func _on_end_next_pressed() -> void:
	get_tree().paused = false
	end_ui.visible = false
	_start_level()

func _on_restart_pressed() -> void:
	_start_level()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	end_ui.visible = false
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

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
