extends Control

@onready var play_button: Button = $VBox/PlayButton
@onready var restart_button: Button = $VBox/RestartButton

func _ready() -> void:
	play_button.pressed.connect(_play)
	restart_button.pressed.connect(_restart)

func _play() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _restart() -> void:
	GameState.set_current_level(0)
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
