extends Node2D
class_name Piece

@export var kind: int = 0
@export var size_px: int = 64

@onready var sprite: Sprite2D = $Sprite

var grid_x: int
var grid_y: int

func _ready() -> void:
	_update_visual()

func set_kind(new_kind: int) -> void:
	kind = new_kind
	_update_visual()

func _update_visual() -> void:
	# Generate a simple colored circle texture (no external assets needed)
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var c := _kind_to_color(kind)
	var center := Vector2(size_px / 2.0, size_px / 2.0)
	var r := size_px * 0.42

	for y in range(size_px):
		for x in range(size_px):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(center)
			if d <= r:
				# simple shading
				var t := clampf((r - d) / r, 0.0, 1.0)
				var shaded := c.lerp(Color.WHITE, 0.15 * t)
				img.set_pixel(x, y, shaded)

	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex

func _kind_to_color(k: int) -> Color:
	var colors := [
		Color(0.95, 0.25, 0.25), # red
		Color(0.25, 0.70, 0.95), # blue
		Color(0.30, 0.90, 0.45), # green
		Color(0.95, 0.85, 0.20), # yellow
		Color(0.75, 0.35, 0.95), # purple
		Color(0.95, 0.55, 0.20), # orange
	]
	return colors[k % colors.size()]
