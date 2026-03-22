## ARCHIVO: symbiote_hud.gd
## Reemplaza tu HUD actual - pégalo en el Control node del HUD
## Requiere: CanvasLayer > Control > (children)

extends Control

# === REFERENCIAS A ELEMENTOS UI ===
var energy_bar: ProgressBar
var vitality_bar: ProgressBar
var level_bar: ProgressBar
var absorbidos_label: Label
var nivel_label: Label
var archivo_label: Label
var camara_label: Label
var objetivo_label: Label
var abilities_container: VBoxContainer

# Variables del juego (conectar con tu sistema)
var energy_current: float = 100.0
var energy_max: float = 100.0
var vitality_current: float = 0.0
var vitality_max: float = 100.0
var level: int = 1
var level_xp: float = 0.0
var level_xp_max: float = 100.0
var absorbidos: int = 0
var archivo_count: int = 0
var archivo_max: int = 2
var camara_count: int = 0
var camara_max: int = 3

var pulse_time: float = 0.0

func _ready():
	_build_ui()
	_apply_theme()

func _build_ui():
	# Asegurarse de tener el tamaño correcto
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# =========================================
	# PANEL SUPERIOR - OBJETIVO
	# =========================================
	var top_container = PanelContainer.new()
	top_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_container.custom_minimum_size = Vector2(480, 36)
	top_container.position = Vector2(-240, 8)
	add_child(top_container)
	
	objetivo_label = Label.new()
	objetivo_label.text = "▶ ABSORBE 2 enemigo(s) más para abrir ARCHIVO"
	objetivo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objetivo_label.add_theme_font_size_override("font_size", 13)
	top_container.add_child(objetivo_label)
	
	# =========================================
	# PANEL IZQUIERDO - STATS
	# =========================================
	var left_panel = PanelContainer.new()
	left_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_panel.custom_minimum_size = Vector2(220, 0)
	left_panel.position = Vector2(12, 12)
	add_child(left_panel)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_panel.add_child(left_vbox)
	
	# --- ENERGÍA ---
	var energy_section = _create_section("⚡ ENERGÍA", left_vbox)
	energy_bar = _create_bar(energy_current, energy_max, Color(0.0, 0.9, 0.3), left_vbox)
	var energy_counter = Label.new()
	energy_counter.name = "EnergyCounter"
	energy_counter.text = "%d / %d" % [energy_current, energy_max]
	energy_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	energy_counter.add_theme_font_size_override("font_size", 11)
	left_vbox.add_child(energy_counter)
	
	# Separador
	left_vbox.add_child(HSeparator.new())
	
	# --- VITALIDAD SIMBIONTE ---
	_create_section("◈ VITALIDAD SIMBIONTE", left_vbox)
	vitality_bar = _create_bar(vitality_current, vitality_max, Color(0.5, 0.0, 1.0), left_vbox)
	
	left_vbox.add_child(HSeparator.new())
	
	# --- NIVEL ---
	var nivel_hbox = HBoxContainer.new()
	nivel_hbox.add_theme_constant_override("separation", 6)
	left_vbox.add_child(nivel_hbox)
	
	_create_section("⬡ NIV. %d" % level, nivel_hbox)
	nivel_label = nivel_hbox.get_child(0)
	nivel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var xp_text = Label.new()
	xp_text.text = "%d / %d" % [level_xp, level_xp_max]
	xp_text.add_theme_font_size_override("font_size", 11)
	nivel_hbox.add_child(xp_text)
	
	level_bar = _create_bar(level_xp, level_xp_max, Color(0.8, 0.5, 0.0), left_vbox)
	
	left_vbox.add_child(HSeparator.new())
	
	# --- ABSORCIONES ---
	_create_section("◉ ABSORCIONES", left_vbox)
	
	absorbidos_label = Label.new()
	absorbidos_label.text = str(absorbidos)
	absorbidos_label.add_theme_font_size_override("font_size", 28)
	absorbidos_label.add_theme_color_override("font_color", Color(0.6, 0.0, 1.0))
	left_vbox.add_child(absorbidos_label)
	
	# Sub-objetivos
	var archivo_hbox = HBoxContainer.new()
	left_vbox.add_child(archivo_hbox)
	var archivo_icon = Label.new()
	archivo_icon.text = "📁 ARCHIVO"
	archivo_icon.add_theme_font_size_override("font_size", 11)
	archivo_icon.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	archivo_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archivo_hbox.add_child(archivo_icon)
	archivo_label = Label.new()
	archivo_label.text = "%d / %d" % [archivo_count, archivo_max]
	archivo_label.add_theme_font_size_override("font_size", 11)
	archivo_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	archivo_hbox.add_child(archivo_label)
	
	var camara_hbox = HBoxContainer.new()
	left_vbox.add_child(camara_hbox)
	var camara_icon = Label.new()
	camara_icon.text = "🎥 CÁMARA FRÍA"
	camara_icon.add_theme_font_size_override("font_size", 11)
	camara_icon.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	camara_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camara_hbox.add_child(camara_icon)
	camara_label = Label.new()
	camara_label.text = "%d / %d" % [camara_count, camara_max]
	camara_label.add_theme_font_size_override("font_size", 11)
	camara_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	camara_hbox.add_child(camara_label)
	
	# =========================================
	# PANEL DERECHO - HABILIDADES
	# =========================================
	var right_panel = PanelContainer.new()
	right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_panel.custom_minimum_size = Vector2(140, 0)
	right_panel.position = Vector2(-152, 12)
	add_child(right_panel)
	
	abilities_container = VBoxContainer.new()
	abilities_container.add_theme_constant_override("separation", 4)
	right_panel.add_child(abilities_container)
	
	_create_section("◆ HABILIDADES", abilities_container)
	
	var ability_colors = [Color(0.0, 0.8, 1.0), Color(0.0, 1.0, 0.4), Color(1.0, 0.6, 0.0), Color(1.0, 0.2, 0.2)]
	var ability_names = ["Absorber", "Dash", "Escudo", "Explosión"]
	
	for i in 4:
		var ab_bar = _create_ability_bar(ability_names[i], ability_colors[i], abilities_container)
	
	# =========================================
	# PANEL INFERIOR - SELECTOR NIVEL
	# =========================================
	var bottom_container = PanelContainer.new()
	bottom_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_container.custom_minimum_size = Vector2(320, 0)
	bottom_container.position = Vector2(-160, -56)
	add_child(bottom_container)
	
	var level_selector = HBoxContainer.new()
	level_selector.add_theme_constant_override("separation", 24)
	bottom_container.add_child(level_selector)
	
	for i in [2, 4, 6]:
		var btn = Button.new()
		btn.text = "Nivel %d" % i
		btn.custom_minimum_size = Vector2(80, 32)
		level_selector.add_child(btn)

func _create_section(title: String, parent: Node) -> Label:
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	parent.add_child(label)
	return label

func _create_bar(value: float, max_value: float, color: Color, parent: Node) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Estilo
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.08)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(bar)
	return bar

func _create_ability_bar(name_text: String, color: Color, parent: Node) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(10, 10)
	icon.color = color
	hbox.add_child(icon)
	
	var lbl = Label.new()
	lbl.text = name_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(50, 6)
	
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	hbox.add_child(bar)
	
	parent.add_child(hbox)
	return hbox

func _apply_theme():
	# Estilo de paneles oscuros estilo Venom
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.02, 0.06, 0.88)
	panel_style.border_color = Color(0.35, 0.0, 0.65, 0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.shadow_color = Color(0.3, 0.0, 0.6, 0.4)
	panel_style.shadow_size = 4
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	
	for child in get_children():
		if child is PanelContainer:
			child.add_theme_stylebox_override("panel", panel_style.duplicate())

func _process(delta: float):
	pulse_time += delta
	# Efecto de pulso en el borde de los paneles
	var pulse = sin(pulse_time * 1.5) * 0.3 + 0.7
	# (Animar border_color aquí si necesitas)

# === ACTUALIZAR VALORES ===
func update_energy(current: float, maximum: float):
	energy_current = current
	energy_max = maximum
	if energy_bar:
		energy_bar.max_value = maximum
		energy_bar.value = current

func update_vitality(current: float, maximum: float):
	vitality_current = current
	vitality_max = maximum
	if vitality_bar:
		vitality_bar.max_value = maximum
		vitality_bar.value = current

func update_absorptions(count: int, arch: int, arch_max: int, cam: int, cam_max: int):
	absorbidos = count
	archivo_count = arch
	archivo_max = arch_max
	camara_count = cam
	camara_max = cam_max
	if absorbidos_label:
		absorbidos_label.text = str(count)
	if archivo_label:
		archivo_label.text = "%d / %d" % [arch, arch_max]
	if camara_label:
		camara_label.text = "%d / %d" % [cam, cam_max]

func update_objetivo(text: String):
	if objetivo_label:
		objetivo_label.text = "▶ " + text
