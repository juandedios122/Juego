extends Node3D
## SpriteBillboard — AnimatedSprite3D billboard que siempre mira a la cámara.
## Se usa para guardia y trabajador. Reemplaza los MeshInstance3D generados por código.
## Si no hay sprites cargados, el nodo queda invisible y el padre usa su visual por código.

var _sprite      : AnimatedSprite3D = null
var _character   : String           = ""   # "guard" | "worker"
var _current_anim: String           = ""
var _has_sprites : bool             = false
var _state_light : OmniLight3D      = null
var _sentido_ring : MeshInstance3D  = null

# Colisión y luces se mantienen en el padre; aquí solo el visual.

func setup(character: String, height_offset: float = 0.9) -> void:
	_character = character
	if not Engine.has_singleton("SpriteMgr"):
		return
	var mgr : Node = Engine.get_singleton("SpriteMgr")
	_has_sprites = mgr.has_sprites(character)
	if not _has_sprites: return

	_sprite = AnimatedSprite3D.new()
	_sprite.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size       = 0.012          # ajusta escala visual
	_sprite.position         = Vector3(0.0, height_offset, 0.0)
	_sprite.texture_filter   = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # pixel art nítido
	_sprite.cast_shadow      = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)

	# Cargar todas las animaciones disponibles en un solo SpriteFrames
	var sf := SpriteFrames.new()
	var anims := _get_anim_list(character)
	for anim_name in anims:
		var frames := mgr.get_frames(character, anim_name)
		if frames == null: continue
		# Copiar frames de ese SpriteFrames al sf combinado
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
			sf.set_animation_speed(anim_name, frames.get_animation_speed(anim_name))
			sf.set_animation_loop(anim_name, frames.get_animation_loop(anim_name))
			for i in frames.get_frame_count(anim_name):
				sf.add_frame(anim_name, frames.get_frame_texture(anim_name, i))
	_sprite.sprite_frames = sf
	play("idle")

func _get_anim_list(character: String) -> Array:
	match character:
		"guard":  return ["idle", "walk", "chase", "attack", "absorb"]
		"worker": return ["idle", "walk", "panic", "flee", "hide", "absorb"]
		_:        return ["idle", "walk"]

func play(anim: String) -> void:
	if not _has_sprites or _sprite == null: return
	if _current_anim == anim: return
	if _sprite.sprite_frames == null: return
	if not _sprite.sprite_frames.has_animation(anim):
		# Fallback: idle si la animación pedida no existe
		if _sprite.sprite_frames.has_animation("idle"):
			_current_anim = "idle"
			_sprite.play("idle")
		return
	_current_anim = anim
	_sprite.play(anim)

func is_ready() -> bool:
	return _has_sprites

## Tint de absorción — mezcla el color del sprite hacia violeta
func set_absorb_tint(progress: float) -> void:
	if _sprite == null: return
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(0.4, 0.0, 0.9, 1.0), progress)

func reset_tint() -> void:
	if _sprite: _sprite.modulate = Color.WHITE

func set_visible_sprite(v: bool) -> void:
	if _sprite: _sprite.visible = v
