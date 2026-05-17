extends Control

# O Godot vai procurar nós AudioStreamPlayer com estes nomes exatos nesta cena
var sounds_to_test = ["Attack_Meteor", "Attack_Nova", "Attack_Ring", "Attack_Stop", "Attack_Hand"]

func _ready():
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_top", 50)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "🎛️ TESTBENCH DE ÁUDIO DO DDA"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	# Cria botões dinamicamente para cada ataque que encontre na cena
	for sound_name in sounds_to_test:
		if has_node(sound_name):
			create_sound_row(vbox, sound_name)
			
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)
	
	# Botão para ligar/desligar a Chuva
	if has_node("AudioChuvaForte"):
		var btn_chuva = Button.new()
		btn_chuva.text = "⛈️ Ligar / Desligar Tempestade (Mascaramento)"
		btn_chuva.custom_minimum_size = Vector2(400, 60)
		btn_chuva.modulate = Color(0.2, 0.6, 1.0)
		btn_chuva.pressed.connect(func():
			var player = get_node("AudioChuvaForte")
			if player.playing:
				player.stop()
			else:
				player.play()
		)
		vbox.add_child(btn_chuva)

func create_sound_row(parent, sound_name):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = sound_name
	label.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(label)
	
	# Botão BASE (Normal)
	var btn_base = Button.new()
	btn_base.text = "Tocar BASE (Sem Filtro)"
	btn_base.custom_minimum_size = Vector2(200, 40)
	btn_base.pressed.connect(func(): play_with_filter(sound_name, "BASE"))
	hbox.add_child(btn_base)
	
	# Botão EASY (HighShelf - Realçado)
	var btn_easy = Button.new()
	btn_easy.text = "Tocar EASY (Agudos)"
	btn_easy.modulate = Color(0.4, 1.0, 0.4)
	btn_easy.custom_minimum_size = Vector2(200, 40)
	btn_easy.pressed.connect(func(): play_with_filter(sound_name, "EASY"))
	hbox.add_child(btn_easy)
	
	# Botão CHALLENGE (LowPass - Abafado)
	var btn_challenge = Button.new()
	btn_challenge.text = "Tocar CHALLENGE (Abafado)"
	btn_challenge.modulate = Color(1.0, 0.4, 0.4)
	btn_challenge.custom_minimum_size = Vector2(250, 40)
	btn_challenge.pressed.connect(func(): play_with_filter(sound_name, "CHALLENGE"))
	hbox.add_child(btn_challenge)

func play_with_filter(sound_name: String, mode: String):
	var bus_idx = AudioServer.get_bus_index(sound_name)
	var player = get_node(sound_name)
	
	# 1. Desliga tudo primeiro (Reset)
	AudioServer.set_bus_effect_enabled(bus_idx, 0, false) # Assumindo que 0 é o LowPass
	AudioServer.set_bus_effect_enabled(bus_idx, 1, false) # Assumindo que 1 é o HighShelf
	
	# 2. Aplica o filtro pedido
	if mode == "CHALLENGE":
		AudioServer.set_bus_effect_enabled(bus_idx, 0, true)
	elif mode == "EASY":
		AudioServer.set_bus_effect_enabled(bus_idx, 1, true)
		
	# 3. Toca o som!
	player.play()
	print("A tocar ", sound_name, " no modo: ", mode)
