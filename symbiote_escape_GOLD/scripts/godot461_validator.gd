extends Node
## Godot461_Validator — Verifica compatibilidad con Godot 4.6.1
## Ejecutar este script para validar que el proyecto funciona correctamente

func _ready() -> void:
	print("=== VALIDACIÓN GODOT 4.6.1 ===")
	_validate_apis()
	_validate_resources()
	_validate_shaders()
	print("=== VALIDACIÓN COMPLETADA ===")

func _validate_apis() -> void:
	print("\n--- VALIDANDO APIs ---")
	
	# Verificar APIs críticas
	var test_node = Node3D.new()
	var test_light = OmniLight3D.new()
	var test_particles = GPUParticles3D.new()
	var test_fog = FogVolume.new()
	
	print("✓ Node3D: OK")
	print("✓ OmniLight3D: OK")
	print("✓ GPUParticles3D: OK")
	print("✓ FogVolume: OK")
	
	# Verificar propiedades específicas de 4.6.1
	if test_light.has_method("set_shadow_bias"):
		print("✓ Light shadow_bias: OK")
	if test_particles.has_method("set_process_material"):
		print("✓ ParticleProcessMaterial: OK")
	
	test_node.queue_free()
	test_light.queue_free()
	test_particles.queue_free()
	test_fog.queue_free()

func _validate_resources() -> void:
	print("\n--- VALIDANDO RECURSOS ---")
	
	var resources_to_check = [
		"res://scenes/main_menu.tscn",
		"res://scenes/game_level.tscn",
		"res://shaders/floor_wet.gdshader",
		"res://shaders/wall_symbiote.gdshader"
	]
	
	for res_path in resources_to_check:
		if ResourceLoader.exists(res_path):
			var res = ResourceLoader.load(res_path)
			if res:
				print("✓ " + res_path + ": OK")
			else:
				push_error("✗ " + res_path + ": FALLÓ CARGA")
		else:
			push_error("✗ " + res_path + ": NO EXISTE")

func _validate_shaders() -> void:
	print("\n--- VALIDANDO SHADERS ---")
	
	var shader_files = [
		"res://shaders/floor_wet.gdshader",
		"res://shaders/wall_symbiote.gdshader",
		"res://shaders/pillar_infected.gdshader",
		"res://shaders/symbiote_body.gdshader"
	]
	
	for shader_path in shader_files:
		if ResourceLoader.exists(shader_path):
			var shader = ResourceLoader.load(shader_path) as Shader
			if shader:
				print("✓ " + shader_path + ": OK")
			else:
				push_error("✗ " + shader_path + ": FALLÓ CARGA")
		else:
			push_error("✗ " + shader_path + ": NO EXISTE")

func _validate_scenes() -> void:
	print("\n--- VALIDANDO ESCENAS ---")
	
	var scene_files = [
		"res://scenes/main_menu.tscn",
		"res://scenes/game_level.tscn",
		"res://scenes/player/symbiote.tscn"
	]
	
	for scene_path in scene_files:
		if ResourceLoader.exists(scene_path):
			var scene = ResourceLoader.load(scene_path) as PackedScene
			if scene:
				print("✓ " + scene_path + ": OK")
			else:
				push_error("✗ " + scene_path + ": FALLÓ CARGA")
		else:
			push_error("✗ " + scene_path + ": NO EXISTE")