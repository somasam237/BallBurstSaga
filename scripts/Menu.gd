extends Control

@onready var play_button: Button = $VBox/PlayButton
@onready var restart_button: Button = $VBox/RestartButton
var bg: TextureRect
func _ready() -> void:
	bg = $TextureRect
	play_button.pressed.connect(_play)
	restart_button.pressed.connect(_restart)
	
func _on_button_hover(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.1)

func _on_button_unhover(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func _process(delta: float) -> void:
	# Fait osciller légèrement le fond
	bg.position.y = sin(Time.get_ticks_msec() * 0.001) * 10.0
	bg.position.x = cos(Time.get_ticks_msec() * 0.0007) * 8.0

func _play() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _restart() -> void:
	GameState.set_current_level(0)
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
