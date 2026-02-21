extends Control

@onready var play_button: BaseButton = $VBox/PlayButton
@onready var restart_button: BaseButton = $VBox/RestartButton
@onready var title_label: Label = $VBox/Title
@onready var menu_music: AudioStreamPlayer = $MenuMusic
@onready var click_sfx: AudioStreamPlayer = $ClickSfx

func _ready() -> void:
	play_button.pressed.connect(_play)
	restart_button.pressed.connect(_restart)
	if menu_music.stream is AudioStreamMP3:
		menu_music.stream.loop = true
	elif menu_music.stream is AudioStreamOggVorbis:
		menu_music.stream.loop = true
	menu_music.play()
	_animate_title()

func _animate_title() -> void:
	title_label.scale = Vector2(1.2, 1.2)
	var tween := create_tween()
	tween.tween_property(title_label, "scale", Vector2(1.7, 1.7), 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "scale", Vector2(1.5, 1.5), 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_loops()

func _play() -> void:
	click_sfx.play()
	menu_music.stop()
	GameState.load_progress()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _restart() -> void:
	click_sfx.play()
	menu_music.stop()
	GameState.set_current_level(0)
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")
