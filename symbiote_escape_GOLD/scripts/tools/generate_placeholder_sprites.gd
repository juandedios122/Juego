@tool
extends EditorScript
## Ejecuta este script desde el editor: Script > Run
## Genera spritesheets placeholder PNG para probar el sistema de sprites.
## Cada frame es un color sólido con un número, para verificar que las animaciones funcionan.

func _run() -> void:
	_gen("symbiote", "idle",   4, 128, 128, Color(0.3, 0.0, 0.8))
	_gen("symbiote", "walk",   6, 128, 128, Color(0.4, 0.0, 1.0))
	_gen("symbiote", "absorb", 6, 128, 128, Color(0.8, 0.0, 1.0))
	_gen("symbiote", "dash",   4, 128, 128, Color(0.6, 0.2, 1.0))
	_gen("guard",    "idle",   4,  64, 128, Color(0.1, 0.1, 0.5))
	_gen("guard",    "walk",   6,  64, 128, Color(0.1, 0.2, 0.7))
	_gen("guard",    "chase",  6,  64, 128, Color(0.7, 0.1, 0.1))
	_gen("guard",    "attack", 4,  64, 128, Color(1.0, 0.1, 0.0))
	_gen("guard",    "absorb", 4,  64, 128, Color(0.5, 0.0, 0.8))
	_gen("worker",   "idle",   4,  64, 128, Color(0.5, 0.4, 0.2))
	_gen("worker",   "walk",   6,  64, 128, Color(0.6, 0.5, 0.2))
	_gen("worker",   "panic",  4,  64, 128, Color(0.9, 0.7, 0.0))
	_gen("worker",   "flee",   6,  64, 128, Color(0.8, 0.4, 0.0))
	_gen("worker",   "hide",   2,  64, 128, Color(0.3, 0.3, 0.1))
	_gen("worker",   "absorb", 4,  64, 128, Color(0.5, 0.0, 0.7))
	print("✅ Sprites placeholder generados en assets/sprites/")

func _gen(char: String, anim: String, frames: int, fw: int, fh: int, base_col: Color) -> void:
	var img := Image.create(fw * frames, fh, false, Image.FORMAT_RGBA8)
	for f in frames:
		var t := float(f) / float(frames)
		var col := base_col.lightened(t * 0.3)
		col.a = 1.0
		for y in fh:
			for x in fw:
				# Silueta simple: rectángulo con cabeza circular
				var cx := fw / 2; var cy_body := fh * 3 / 4; var cy_head := fh / 4
				var in_body := abs(x - cx) < fw * 0.35 and abs(y - cy_body) < fh * 0.28
				var in_head := Vector2(x - cx, y - cy_head).length() < fw * 0.22
				if in_body or in_head:
					img.set_pixel(f * fw + x, y, col)
				else:
					img.set_pixel(f * fw + x, y, Color(0, 0, 0, 0))
	var path := "res://assets/sprites/" + char + "/" + anim + ".png"
	img.save_png(path.replace("res://", ""))
	# Reimportar
	var tex := ImageTexture.create_from_image(img)
	ResourceSaver.save(tex, path)
