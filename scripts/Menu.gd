extends Control
 

@onready var play_button: BaseButton = $VBox/PlayButton
@onready var restart_button: BaseButton = $VBox/RestartButton
@onready var menu_music: AudioStreamPlayer = $MenuMusic
@onready var click_sfx: AudioStreamPlayer = $ClickSfx
@onready var girl = $Girl

# Images du titre
@onready var ball_img  = $VBox/TitleRow/BallBurstColumn/Ball
@onready var burst_img = $VBox/TitleRow/BallBurstColumn/Burst
@onready var saga_img  = $VBox/TitleRow/Saga

var screen_width: float
var girl_start_x: float
var girl_ground_y: float = 720.0

var _confirm_layer = null   # dialog confirmation restart

func _ready():
	play_button.pressed.connect(_play)
	restart_button.pressed.connect(_ask_restart_confirm)

	if menu_music.stream is AudioStreamMP3:
		menu_music.stream.loop = true
	elif menu_music.stream is AudioStreamOggVorbis:
		menu_music.stream.loop = true
	menu_music.play()

	screen_width = get_viewport().get_visible_rect().size.x
	girl_start_x = screen_width / 2.0
	girl.position = Vector2(girl_start_x, girl_ground_y)

	# Lance toutes les animations
	_animate_title_entrance()
	_animate_girl()
	_build_restart_confirm_dialog() 

# ══════════════════════════════════════════════════
#   ENTRÉE DU TITRE - Apparition en cascade
# ══════════════════════════════════════════════════
func _animate_title_entrance() -> void:
	# Cache tout au départ
	ball_img.scale  = Vector2(0.0, 0.0)
	burst_img.scale = Vector2(0.0, 0.0)
	saga_img.scale  = Vector2(0.0, 0.0)
	ball_img.modulate.a  = 0.0
	burst_img.modulate.a = 0.0
	saga_img.modulate.a  = 0.0

	# BALL : pop élastique depuis le haut
	await get_tree().create_timer(0.1).timeout
	_pop_in(ball_img, Vector2(0.0, -80), 0.0)

	# BURST : pop élastique avec délai
	await get_tree().create_timer(0.25).timeout
	_pop_in(burst_img, Vector2(0.0, 60), 0.0)

	# SAGA : pop élastique depuis la droite
	await get_tree().create_timer(0.25).timeout
	_pop_in(saga_img, Vector2(80, 0.0), 0.0)

	# Une fois apparus → boucles continues
	await get_tree().create_timer(1.0).timeout
	_ball_loop()
	_burst_loop()
	_saga_loop()

func _pop_in(node: Node, offset: Vector2, delay: float) -> void:
	var origin_pos = node.position
	node.position = origin_pos + offset

	var t = create_tween().set_parallel(true)
	# Fade in
	t.tween_property(node, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Scale pop élastique
	t.tween_property(node, "scale", Vector2(1.15, 1.15), 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Position
	t.tween_property(node, "position", origin_pos, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await t.finished

	# Petit recul au scale normal
	var t2 = create_tween()
	t2.tween_property(node, "scale", Vector2(1.0, 1.0), 0.2)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


#   BALL - Rebond 

func _ball_loop() -> void:
	var origin_y = ball_img.position.y
	var t = create_tween().set_loops()

	# Bounce vertical
	t.tween_property(ball_img, "position:y", origin_y - 18, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ball_img, "position:y", origin_y, 0.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)

	# Rotation oscillante (séparé)
	var t2 = create_tween().set_loops()
	t2.tween_property(ball_img, "rotation_degrees", -4.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(ball_img, "rotation_degrees", 4.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Flash de couleur toutes les 3 secondes
	_ball_shimmer()

func _ball_shimmer() -> void:
	await get_tree().create_timer(3.0).timeout
	var t = create_tween()
	t.tween_property(ball_img, "self_modulate", Color(1.4, 1.4, 0.6, 1.0), 0.15)
	t.tween_property(ball_img, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	_ball_shimmer()  # rappel récursif


#   BURST - Pulse scale 

func _burst_loop() -> void:
	var t = create_tween().set_loops()

	# Pulse scale dramatique
	t.tween_property(burst_img, "scale", Vector2(1.06, 1.06), 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(burst_img, "scale", Vector2(0.97, 0.97), 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(burst_img, "scale", Vector2(1.0, 1.0), 0.2)\
		.set_trans(Tween.TRANS_BOUNCE)

	
	_burst_color_cycle()

func _burst_color_cycle() -> void:
	var colors = [
		Color(1.0, 0.6, 1.0),   
		Color(0.6, 1.0, 0.6),   
		Color(1.0, 1.0, 0.5),  
		Color(0.6, 0.8, 1.0),   
		Color(1.0, 1.0, 1.0),   
	]
	var t = create_tween().set_loops()
	for c in colors:
		t.tween_property(burst_img, "self_modulate", c, 0.7)\
			.set_trans(Tween.TRANS_SINE)

# ══════════════════════════════════════════════════
#   SAGA - Rotation 3D  + scale wave
# ══════════════════════════════════════════════════
func _saga_loop() -> void:
	
	_saga_flip_loop()
	
	# Bounce  
	var origin_y = saga_img.position.y
	var t = create_tween().set_loops()
	t.tween_property(saga_img, "position:y", origin_y - 12, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(saga_img, "position:y", origin_y, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _saga_flip_loop() -> void:
	# Simulate a flip 3D every  4 secondes
	await get_tree().create_timer(4.0).timeout
	
	var t = create_tween()
	
	t.tween_property(saga_img, "scale:x", 0.0, 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	t.tween_callback(func(): saga_img.self_modulate = Color(1.5, 1.0, 1.5))
	# 
	t.tween_property(saga_img, "scale:x", 1.0, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): saga_img.self_modulate = Color(1.0, 1.0, 1.0))
	
	await t.finished
	_saga_flip_loop()

# ══════════════════════════════════════════════════
#   ANIMATION girl
# ══════════════════════════════════════════════════
func _animate_girl() -> void:
	_girl_sequence()

func _girl_sequence() -> void:
	await _girl_jump()
	await _girl_run_to(screen_width + 100, 1.8)
	girl.position.x = -100
	girl.scale.x = 1.0
	await _girl_run_to(girl_start_x, 1.5)
	await get_tree().create_timer(1.0).timeout
	_girl_sequence()

func _girl_jump() -> void:
	var t = create_tween()
	t.tween_property(girl, "position:y", girl_ground_y - 200, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(girl, "rotation_degrees", -8.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(girl, "position:y", girl_ground_y, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(girl, "rotation_degrees", 0.0, 0.4)\
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(girl, "scale", Vector2(1.2, 0.8), 0.08)
	t.tween_property(girl, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_trans(Tween.TRANS_ELASTIC)
	await t.finished

func _girl_run_to(target_x: float, duration: float) -> void:
	if target_x > girl.position.x:
		girl.scale.x = 1.0
	else:
		girl.scale.x = -1.0

	var t = create_tween()
	t.tween_property(girl, "position:x", target_x, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var bounce = create_tween().set_loops()
	bounce.tween_property(girl, "position:y", girl_ground_y - 15, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bounce.tween_property(girl, "position:y", girl_ground_y, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await t.finished
	bounce.kill()
	girl.position.y = girl_ground_y


func _play() -> void:
	click_sfx.play()
	menu_music.stop()
	GameState.load_progress()  
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	



# ══════════════════════════════════════════════════
func _ask_restart_confirm() -> void:
	click_sfx.play()
	_confirm_layer.visible = true



func _do_full_reset() -> void:

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

	
	menu_music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")




func _build_restart_confirm_dialog() -> void:
	var vp = get_viewport_rect().size

	_confirm_layer              = CanvasLayer.new()
	_confirm_layer.name         = "ConfirmLayer"
	_confirm_layer.visible      = false
	_confirm_layer.layer        = 20     
	add_child(_confirm_layer)

	
	var backdrop          = ColorRect.new()
	backdrop.color        = Color(0, 0, 0, 0.65)
	backdrop.size         = vp
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_layer.add_child(backdrop)

	
	var card              = PanelContainer.new()
	card.size             = Vector2(430, 245)
	card.position         = vp / 2.0 - card.size / 2.0
	_confirm_layer.add_child(card)

	var vbox              = VBoxContainer.new()
	vbox.alignment        = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	
	var icon              = Label.new()
	icon.text             = "⚠️"
	icon.add_theme_font_size_override("font_size", 38)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)

	var sp1               = Control.new()
	sp1.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(sp1)

	
	var title             = Label.new()
	title.text            = "Spiel komplett zurücksetzen?"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sp2               = Control.new()
	sp2.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(sp2)


	var sub               = Label.new()
	sub.text              = "⚠️  Dein Name, alle Level und\ndein KI-Profil werden dauerhaft gelöscht!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.15, 0.15))
	vbox.add_child(sub)

	var sp3               = Control.new()
	sp3.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(sp3)


	var hbox              = HBoxContainer.new()
	hbox.alignment        = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var btn_yes           = Button.new()
	btn_yes.text          = "✅  Ja, alles löschen"
	btn_yes.custom_minimum_size = Vector2(175, 48)
	btn_yes.add_theme_font_size_override("font_size", 16)
	hbox.add_child(btn_yes)

	var sp4               = Control.new()
	sp4.custom_minimum_size = Vector2(16, 0)
	hbox.add_child(sp4)

	var btn_no            = Button.new()
	btn_no.text           = "❌  Abbrechen"
	btn_no.custom_minimum_size = Vector2(135, 48)
	btn_no.add_theme_font_size_override("font_size", 16)
	hbox.add_child(btn_no)

	
	btn_yes.pressed.connect(func():
		_confirm_layer.visible = false
		_do_full_reset()
	)


	btn_no.pressed.connect(func():
		_confirm_layer.visible = false
	)
