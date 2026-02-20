extends Control

@onready var play_button: BaseButton = $VBox/PlayButton
@onready var restart_button: BaseButton = $VBox/RestartButton
@onready var title_label: Label = $VBox/Title
@onready var menu_music: AudioStreamPlayer = $MenuMusic
@onready var click_sfx: AudioStreamPlayer = $ClickSfx
@onready var girl: TextureRect = $Girl  # ou Sprite2D selon ton node

var screen_width: float
var girl_start_x: float
var girl_ground_y: float = 620.0  # ajuste selon la hauteur des arbres

func _ready():
	play_button.pressed.connect(_play)
	restart_button.pressed.connect(_restart)
	
	if menu_music.stream is AudioStreamMP3:
		menu_music.stream.loop = true
	elif menu_music.stream is AudioStreamOggVorbis:
		menu_music.stream.loop = true
	menu_music.play()
	
	screen_width = get_viewport().get_visible_rect().size.x
	girl_start_x = screen_width / 2.0  # position de départ au centre
	
	# Place la fille au sol
	girl.position = Vector2(girl_start_x, girl_ground_y)
	
	_animate_title()
	_animate_girl()

# ══════════════════════════════════════════
#   ANIMATION TITRE - Effet Candy Crush
# ══════════════════════════════════════════
func _animate_title() -> void:
	title_label.scale = Vector2(0.5, 0.5)
	title_label.modulate = Color(1, 0.5, 1, 0)  # rose transparent
	
	# Apparition avec zoom + couleur
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_label, "scale", Vector2(1.1, 1.1), 0.6)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate", Color(1, 1, 1, 1), 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Après apparition → pulse infini
	await get_tree().create_timer(0.8).timeout
	_title_pulse_loop()

func _title_pulse_loop() -> void:
	var tween = create_tween().set_loops()  # boucle infinie
	
	# Pulse scale
	tween.tween_property(title_label, "scale", Vector2(1.08, 1.08), 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _title_color_loop() -> void:
	# Cycle de couleurs Candy Crush
	var colors = [
		Color(1.0, 0.3, 0.8),   # rose vif
		Color(0.3, 0.9, 0.3),   # vert lime
		Color(1.0, 0.8, 0.0),   # jaune doré
		Color(0.3, 0.7, 1.0),   # bleu ciel
	]
	var tween = create_tween().set_loops()
	for c in colors:
		tween.tween_property(title_label, "self_modulate", c, 0.6)\
			.set_trans(Tween.TRANS_SINE)

# ══════════════════════════════════════════
#   ANIMATION FILLE - Séquence complète
# ══════════════════════════════════════════
func _animate_girl() -> void:
	# Lance la séquence en boucle
	_girl_sequence()

func _girl_sequence() -> void:
	# 1. SAUT sur place depuis le centre
	await _girl_jump()
	
	# 2. COURIR vers la droite
	await _girl_run_to(screen_width + 100, 1.8)
	
	# 3. Réapparaît à gauche instantanément (flip)
	girl.position.x = -100
	girl.scale.x = 1.0  # remet dans le bon sens
	
	# 4. COURIR vers le centre
	await _girl_run_to(girl_start_x, 1.5)
	
	# 5. Petite pause puis recommence
	await get_tree().create_timer(1.0).timeout
	_girl_sequence()  # boucle

func _girl_jump() -> void:
	# Saut haut avec arc naturel
	var tween = create_tween()
	
	# Monter
	tween.tween_property(girl, "position:y", girl_ground_y - 200, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Légère rotation en l'air
	tween.parallel().tween_property(girl, "rotation_degrees", -8.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)
	
	# Redescendre
	tween.tween_property(girl, "position:y", girl_ground_y, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(girl, "rotation_degrees", 0.0, 0.4)\
		.set_trans(Tween.TRANS_SINE)
	
	# Petit squash à l'atterrissage
	tween.tween_property(girl, "scale", Vector2(1.2, 0.8), 0.08)
	tween.tween_property(girl, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_trans(Tween.TRANS_ELASTIC)
	
	await tween.finished

func _girl_run_to(target_x: float, duration: float) -> void:
	# Flip la fille selon la direction
	if target_x > girl.position.x:
		girl.scale.x = 1.0   # vers la droite
	else:
		girl.scale.x = -1.0  # vers la gauche
	
	var tween = create_tween()
	
	# Mouvement horizontal
	tween.tween_property(girl, "position:x", target_x, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Effet "bounce" vertical pendant la course
	var bounce_tween = create_tween().set_loops()
	bounce_tween.tween_property(girl, "position:y", girl_ground_y - 15, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(girl, "position:y", girl_ground_y, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	bounce_tween.kill()  # arrête le bounce quand elle arrive
	girl.position.y = girl_ground_y

# ══════════════════════════════════════════
#   BOUTONS
# ══════════════════════════════════════════
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
