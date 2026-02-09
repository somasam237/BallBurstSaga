 
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

var total_score: int = 0

func _ready() -> void:
	board.position = Vector2(80, 80)

	board.score_gained.connect(_on_score_gained)
	board.moves_used.connect(_on_moves_used)
	board.message.connect(_on_message)
	board.game_over.connect(_on_game_over)

	_setup_ui()
	_start_level()

func _on_score_gained(points: int) -> void:
	total_score += points
	score_label.text = "Score: %d".format([total_score])

func _on_moves_used(remaining: int) -> void:
	moves_label.text = "Moves: %d".format([remaining])

func _on_message(t: String) -> void:
	message_label.text = t

func _on_hint_pressed() -> void:
	var hint := board.find_hint_swap()
	if hint.is_empty():
		message_label.text = "No hints found."
		return
	var a: Piece = hint["a"]
	var b: Piece = hint["b"]
	message_label.text = "Hint: swap (%d,%d) with (%d,%d)".format([a.grid_x,a.grid_y,b.grid_x,b.grid_y])

func _setup_ui() -> void:
	score_label.position = Vector2(12, 10)
	moves_label.position = Vector2(12, 34)
	goal_label.position = Vector2(12, 58)
	message_label.position = Vector2(12, 82)

	hint_button.text = "Hint"
	hint_button.position = Vector2(12, 110)
	hint_button.pressed.connect(_on_hint_pressed)

	restart_button.text = "Restart"
	restart_button.position = Vector2(12, 140)
	restart_button.pressed.connect(_on_restart_pressed)

	menu_button.text = "Menu"
	menu_button.position = Vector2(12, 170)
	menu_button.pressed.connect(_on_menu_pressed)

	pause_button.text = "Pause"
	pause_button.position = Vector2(12, 200)
	pause_button.pressed.connect(_on_pause_pressed)

	pause_ui.visible = false
	pause_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	quit_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_menu_pressed)

func _start_level() -> void:
	total_score = 0
	var level := GameState.get_current_level()
	board.configure(level["moves"], level["target"])
	board.new_game()

	goal_label.text = "Goal: %d".format([board.target_score])
	score_label.text = "Score: 0"
	moves_label.text = "Moves: %d".format([board.start_moves])
	message_label.text = "Level %d".format([GameState.current_level_index + 1])

func _on_game_over(won: bool) -> void:
	if won:
		if GameState.has_next_level():
			GameState.advance_level()
			message_label.text = "Win! Next level unlocked."
			return
		message_label.text = "Win! All levels complete."
	else:
		message_label.text = "Game over."

func _on_restart_pressed() -> void:
	_start_level()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_pause_pressed() -> void:
	get_tree().paused = true
	pause_ui.visible = true

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_ui.visible = false
