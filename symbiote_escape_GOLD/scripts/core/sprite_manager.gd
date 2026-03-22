extends Node
## SpriteMgr — Carga y cachea spritesheets para personajes.
## Si el archivo no existe, devuelve null y el personaje usa visual por código.
## NOTA: Es un autoload, acceder via SpriteMgr (no Engine.has_singleton).

# Caché: { "guard/walk" : SpriteFrames }
var _cache : Dictionary = {}

# Configuración de cada animación: [frames_x, frames_y, fps]
const ANIM_CONFIG := {
	"symbiote/idle":   [4, 1, 8],
	"symbiote/walk":   [6, 1, 12],
	"symbiote/absorb": [6, 1, 10],
	"symbiote/dash":   [4, 1, 16],

	"guard/idle":      [4, 1, 6],
	"guard/walk":      [6, 1, 10],
	"guard/chase":     [6, 1, 14],
	"guard/attack":    [4, 1, 12],
	"guard/absorb":    [4, 1, 8],

	"worker/idle":     [4, 1, 6],
	"worker/walk":     [6, 1, 10],
	"worker/panic":    [4, 1, 14],
	"worker/flee":     [6, 1, 14],
	"worker/hide":     [2, 1, 4],
	"worker/absorb":   [4, 1, 8],
}

func get_frames(character: String, anim: String) -> SpriteFrames:
	var key  := character + "/" + anim
	if _cache.has(key): return _cache[key]
	var path := "res://assets/sprites/" + key + ".png"
	if not ResourceLoader.exists(path):
		_cache[key] = null
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		_cache[key] = null
		return null
	var cfg   : Array = ANIM_CONFIG.get(key, [4, 1, 8]) as Array
	var fx    : int   = cfg[0] as int
	var fy    : int   = cfg[1] as int
	var fps   : int   = cfg[2] as int
	var sf    := SpriteFrames.new()
	sf.add_animation(anim)
	sf.set_animation_speed(anim, float(fps))
	sf.set_animation_loop(anim, true)
	var fw : int = tex.get_width()  / fx
	var fh : int = tex.get_height() / fy
	for row in fy:
		for col in fx:
			var atlas := AtlasTexture.new()
			atlas.atlas  = tex
			atlas.region = Rect2(col * fw, row * fh, fw, fh)
			sf.add_frame(anim, atlas)
	_cache[key] = sf
	return sf

## Devuelve true si hay al menos una animación disponible para el personaje
func has_sprites(character: String) -> bool:
	return get_frames(character, "idle") != null or get_frames(character, "walk") != null
