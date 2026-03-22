## sprite_animator.gd
## Nodo auxiliar que reemplaza el visual 3D procedural por Sprite3D animado.
## Adjunta este script como hijo de CharacterBody3D (symbiote, guard, worker).
##
## USO:
##   1. Extrae los PNG a:  res://assets/sprites/symbiote/  (guard/, worker/)
##   2. En el nodo CharacterBody3D, añade un hijo Node3D vacío llamado "SpriteAnimator"
##   3. Asigna este script a ese nodo.
##   4. Llama a:  $SpriteAnimator.play("walk")   desde el script del personaje.
## ─────────────────────────────────────────────────────────────────────────────

extends Node3D

## Tipo de personaje — cambia esto en el Inspector
@export_enum("symbiote", "guard", "worker") var character: String = "symbiote"

## FPS de la animación
@export var fps: float = 8.0

## ─── Datos de cada animación (frames en la fila horizontal del spritesheet) ──
const ANIM_DATA = {
	"symbiote": {
		"idle":   { "frames": 4, "frame_w": 128, "frame_h": 128 },
		"walk":   { "frames": 6, "frame_w": 128, "frame_h": 128 },
		"absorb": { "frames": 6, "frame_w": 128, "frame_h": 128 },
		"dash":   { "frames": 4, "frame_w": 128, "frame_h": 128 },
	},
	"guard": {
		"idle":   { "frames": 4, "frame_w": 64, "frame_h": 128 },
		"walk":   { "frames": 6, "frame_w": 64, "frame_h": 128 },
		"chase":  { "frames": 6, "frame_w": 64, "frame_h": 128 },
		"attack": { "frames": 4, "frame_w": 64, "frame_h": 128 },
		"absorb": { "frames": 4, "frame_w": 64, "frame_h": 128 },
	},
	"worker": {
		"idle":   { "frames": 4, "frame_w": 64, "frame_h": 128 },
		"walk":   { "frames": 6, "frame_w": 64, "frame_h": 128 },
		"panic":  { "frames": 4, "frame_w": 64, "frame_h": 128 },
		"flee":   { "frames": 6, "frame_w": 64, "frame_h": 128 },
		"hide":   { "frames": 2, "frame_w": 64, "frame_h": 128 },
		"absorb": { "frames": 4, "frame_w": 64, "frame_h": 128 },
	},
}

# ─── Internos ─────────────────────────────────────────────────────────────────
var _sprite      : Sprite3D = null
var _current_anim: String   = ""
var _frame       : int      = 0
var _timer       : float    = 0.0
var _textures    : Dictionary = {}   # anim_name → Texture2D

func _ready() -> void:
	_build_sprite3d()
	_preload_textures()
	play("idle")

func _build_sprite3d() -> void:
	_sprite = Sprite3D.new()
	_sprite.pixel_size      = 0.013       # 128px * 0.013 ≈ 1.66 unidades — tamaño correcto
	_sprite.billboard       = BaseMaterial3D.BILLBOARD_ENABLED   # siempre mira a la cámara
	_sprite.centered        = true
	_sprite.double_sided    = true
	_sprite.shaded          = false       # pixel art se ve mejor sin iluminación
	_sprite.position        = Vector3(0, 0.9, 0)
	add_child(_sprite)

func _preload_textures() -> void:
	var anims = ANIM_DATA.get(character, {})
	for anim_name in anims:
		var path := "res://assets/sprites/%s/%s.png" % [character, anim_name]
		if ResourceLoader.exists(path):
			_textures[anim_name] = load(path)
		else:
			push_warning("SpriteAnimator: no encontré el sprite en %s" % path)

# ─── API pública ──────────────────────────────────────────────────────────────

## Inicia una animación. Si ya está activa, no reinicia.
func play(anim: String) -> void:
	if anim == _current_anim:
		return
	if not _textures.has(anim):
		push_warning("SpriteAnimator [%s]: animación '%s' no disponible" % [character, anim])
		return
	_current_anim = anim
	_frame        = 0
	_timer        = 0.0
	_apply_frame()

## Cambia la animación y reinicia desde el frame 0.
func force_play(anim: String) -> void:
	_current_anim = ""
	play(anim)

## Voltea el sprite horizontalmente (para moverse a la izquierda).
func set_flip_h(flip: bool) -> void:
	if _sprite:
		_sprite.flip_h = flip

# ─── Loop de animación ────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _current_anim.is_empty():
		return

	_timer += delta
	if _timer >= 1.0 / fps:
		_timer = 0.0
		var data = ANIM_DATA[character][_current_anim]
		_frame = (_frame + 1) % data["frames"]
		_apply_frame()

func _apply_frame() -> void:
	if _current_anim.is_empty() or not _textures.has(_current_anim):
		return

	var data    = ANIM_DATA[character][_current_anim]
	var tex     : Texture2D = _textures[_current_anim]
	_sprite.texture      = tex
	_sprite.hframes      = data["frames"]
	_sprite.vframes      = 1
	_sprite.frame        = _frame
