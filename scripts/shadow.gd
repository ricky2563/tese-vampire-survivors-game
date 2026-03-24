extends Node2D

@onready var sprite = $Sprite2D

func _ready():
	create_shadow()

func create_shadow():
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x-32, y-32).length()
			if dist < 30:
				var alpha = 0.4 * (1.0 - dist/30.0)
				img.set_pixel(x, y, Color(0,0,0,alpha))
	
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	
	# forma oval (perspetiva chão)
	sprite.scale = Vector2(1.5, 0.7)
	
	# fica por baixo
	sprite.z_index = -1
