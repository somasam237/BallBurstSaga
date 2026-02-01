 extends Node2D

@onready var board: Board = $Board
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var moves_label: Label = $UI/HUD/MovesLabel
@onready var goal_label: Label = $UI/HUD/GoalLabel
@onready var hint_button: Button = $UI/HUD/HintButton
@onready var message_label: Label = $UI/HUD/MessageLabel

var total_score: int = 0

func _ready() -> void:
	board.position = Vector2(80, 80)

	board.score_gained.connect(_on_score_gained)
	board.moves_used.connect(_on_moves_used)
	board.message.connect(_on_message)

	total_score = 0
	goal_label.text = "Goal: %d".format([board.target_score])
	score_label.text = "Score: 0"
	moves_label.text = "Moves: %d".format([board.start_moves])

	hint_button.pressed.connect(_on_hint_pressed)

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
